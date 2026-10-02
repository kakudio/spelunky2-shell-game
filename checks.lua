-- Check-specific gameplay adapters. Add special quest logic here, not in main.lua.

local placements=require "placements"
local adapters=require "adapters"
local logic=require "logic"
local sparrow=require "sparrow_adapter"
local duat=require "duat_adapter"
local M={}
local materialize=adapters.materialize
local replace_native_spawn=adapters.replace_native_spawn

local ITEM_ANCHORS={
    -- The Black Market Hedjet is handled once the shop room and its owner are
    -- active, so its replacement remains a purchasable shop item.
    {source="ITEM_PICKUP_HEDJET",check="CHECK_BLACK_MARKET",theme=THEME.JUNGLE,shop_only=true,pre_spawn=false,post_generation=false},
    -- The Crown is embedded in Vlad's Castle statue.  Replacing it before the
    -- room finishes initializing can leave certain items (notably Player Bag)
    -- inside the statue, so replace it after generation and snap to ground.
    {source="ITEM_PICKUP_CROWN",check="CHECK_VLADS_CASTLE",theme=THEME.VOLCANA,pre_spawn=false,snap=true,absolute=true,layer=LAYER.BACK},
    {source="ITEM_PICKUP_ANKH",check="CHECK_OLMEC_ANKH",theme=THEME.OLMEC},
    -- Tide Pool 4-2 has a Golden Idol inside Great Humphead's cave. The
    -- level restriction keeps this distinct from Tusk's 4-1 Idol.
    {source="ITEM_IDOL",check="CHECK_HUMPHEAD_CAVE_IDOL",theme=THEME.TIDE_POOL,level=2,layer=LAYER.BACK,snap=true},
    -- Excalibur is overlaid on its stone, so use its absolute coordinates and
    -- replace only after the room has finished constructing.
    {source="ITEM_EXCALIBUR",check="CHECK_EXCALIBUR_STONE",theme=THEME.TIDE_POOL,pre_spawn=false,post_generation=false,snap=true,absolute=true,layer=LAYER.FRONT,requires_any={"ITEM_PICKUP_HEDJET","ITEM_PICKUP_CROWN"}},
    {source="ITEM_CLONEGUN",check="CHECK_STARS_CHALLENGE_TIDE_POOL",theme=THEME.TIDE_POOL},
    {source="ITEM_PICKUP_ELIXIR",check="CHECK_STARS_CHALLENGE_TEMPLE",theme=THEME.TEMPLE},
    {source="ITEM_LIGHT_ARROW",check="CHECK_SUN_CHALLENGE",theme=THEME.SUNKEN_CITY},
    -- The Mothership is part of Ice Caves 5-1. Its Plasma Cannon is in the
    -- back layer and is safe to replace directly once the room is built.
    {source="ITEM_PLASMACANNON",check="CHECK_MOTHERSHIP_PLASMA_CANNON",theme=THEME.ICE_CAVES,layer=LAYER.BACK,snap=true},
    -- Tusk's Palace Royal Jelly is a room object, while Sparrow's Player Bag
    -- is spawned only after the player completes her vault conversation.
    -- The post-generation scan handles Royal Jelly. Sparrow's Player Bag is
    -- handled after its special spawn routine finishes; replacing it during
    -- pre-spawn makes the game apply a Player Bag character texture to the
    -- mapped reward.
    -- Ordinary Royal Jelly and Player Bags remain untouched elsewhere.
    {source="ITEM_PICKUP_ROYALJELLY",check="CHECK_TUSK_PALACE_VISIT",theme=THEME.NEO_BABYLON,level=3,layer=LAYER.BACK,snap=true},
}
local NPC_ANCHORS={
    {source="MONS_YANG",check="CHECK_YANG",theme=THEME.DWELLING,layer=LAYER.BACK,snap=true},
}
-- Fixed engine DROP substitutions share one lifecycle. Theme-scoped entries
-- are cleared when leaving their theme; global quest entries remain armed but
-- only fire when the base game emits that exact DROP.
local DROP_CONFIGS={
    {drop=DROP.KINGU_TABLETOFDESTINY,check="CHECK_KINGU",theme=THEME.ABZU,label="Kingu Tablet"},
    -- Queen Bee can be created outside Jungle by test tools or custom level
    -- setups. Her engine DROP is specific to her, so keep the replacement
    -- armed globally rather than silently falling back to Royal Jelly there.
    {drop=DROP.QUEENBEE_ROYALJELLY,check="CHECK_QUEEN_BEE",label="Queen Bee Royal Jelly"},
    {drop=DROP.OLMEC_SISTERS_BOMBBOX,check="CHECK_SISTERS_OLMEC_REWARD",theme=THEME.OLMEC,label="Sisters Bomb Box"},
    {drop=DROP.OSIRIS_TABLETOFDESTINY,check="CHECK_OSIRIS",theme=THEME.DUAT,label="Osiris Tablet"},
    {drop=DROP.ANUBIS2_JETPACK,check="CHECK_ANUBIS_II",theme=THEME.DUAT,label="Anubis II Jetpack"},
    {drop=DROP.VAN_HORSING_COMPASS,check="CHECK_ALIEN_COMPASS",theme=THEME.TEMPLE,label="Van Alien Compass"},
    {drop=DROP.SPARROW_ROPEPILE,check="CHECK_SPARROW",label="Sparrow Rope Pile"},
    {drop=DROP.BEG_BOMBBAG,check="CHECK_BEG_FIRST_MEETING",label="Beg Bomb Bag"},
    {drop=DROP.BEG_TRUECROWN,check="CHECK_BEG_TRUE_CROWN",label="Beg True Crown"},
    {drop=DROP.ALTAR_KAPALA,check="CHECK_KALI_ALTAR_2",label="Kali Kapala",run_flag="kali_second_gift_completed"},
}
local YANG_DOOR_TYPES={"FLOOR_DOOR_LOCKED_PEN"}
local YANG_FAILURE_ENTITY_TYPES={"FLOOR_DOOR_LAYER","FLOOR_DOOR_LOCKED_PEN","LOGICAL_DOOR","BG_SHOP_BACKDOOR","BG_DOOR_FRONT_LAYER","BG_DOOR_BACK_LAYER"}

local function players_have_any(named_types)
    if not named_types or #named_types==0 then return true end
    for _,name in ipairs(named_types or {}) do
        local ent_type=placements.type_of(name)
        if ent_type then
            for _,player in ipairs(players or {}) do
                if entity_has_item_type(player.uid,ent_type) then return true end
            end
        end
    end
    return false
end
local function remove_moon_arrows(ctx, bow, x, y, layer)
    local metal_arrow_type=placements.type_of("ITEM_METAL_ARROW")
    if not metal_arrow_type then return end
    -- The included arrow can be held by the Bow or spawned separately.
    for _,uid in ipairs(bow:get_items()) do
        local item=get_entity(uid)
        if item and item.type.id==metal_arrow_type then item:destroy() end
    end
    -- Catch the separately spawned arrow after level generation has finished.
    ctx.defer(1,"moon-arrow cleanup",function()
        for _,uid in ipairs(get_entities_by_type(metal_arrow_type)) do
            local item=get_entity(uid)
            if item and item.layer==layer and math.abs(item.x-x)+math.abs(item.y-y)<=4 then
                item:destroy()
                ctx.log("Removed Moon Challenge metal arrow uid "..uid)
            end
        end
    end)
end
local function replace_van_reward(ctx, items)
    if state.theme~=THEME.VOLCANA or ctx.randomizer_state.level_materialized.CHECK_VAN_HORSING_RESCUE then return end
    local van_type,diamond_type=placements.type_of("MONS_OLD_HUNTER"),placements.type_of("ITEM_DIAMOND")
    if not van_type or not diamond_type then return end
    local vans=get_entities_by_type(van_type)
    local van=vans[1] and get_entity(vans[1]) or nil
    if not van then return end
    local closest,closest_distance=nil,math.huge
    for _,uid in ipairs(items) do
        local item=get_entity(uid)
        if item and item.type.id==diamond_type and item.layer==van.layer then
            local distance=math.abs(item.x-van.x)+math.abs(item.y-van.y)
            if distance<closest_distance then closest,closest_distance=item,distance end
        end
    end
    if closest and closest_distance<=8 then
        ctx.log(string.format("Van reward Diamond found at %.1f, %.1f (distance %.1f)",closest.x,closest.y,closest_distance))
        materialize(ctx,"CHECK_VAN_HORSING_RESCUE",closest.x,closest.y,closest.layer,closest.uid)
    end
end
local function configure_drop_substitutions(ctx)
    ctx.drop_configured=ctx.drop_configured or {}
    for _,config in ipairs(DROP_CONFIGS) do
        local active=(not config.theme or state.theme==config.theme) and not (config.run_flag and ctx[config.run_flag])
        local reward,ent_type=nil,nil
        if active then reward,ent_type=placements.reward_type(ctx.randomizer_state,config.check) end
        if active and ent_type then
            replace_drop(config.drop,ent_type)
            if ctx.drop_configured[config.drop]~=reward then
                ctx.drop_configured[config.drop]=reward
                ctx.log(config.label.." drop configured: "..config.check.." -> "..reward)
            end
        elseif ctx.drop_configured[config.drop] then
            replace_drop(config.drop,0)
            ctx.drop_configured[config.drop]=nil
        end
    end
end
local function configure_humphead_drop(ctx)
    -- This enum creates a script-owned Hired Hand. Replacing it with an item
    -- corrupts Humphead's death sequence; the resulting Present is handled
    -- after the native sequence instead.
    if ctx.humphead_drop_configured then
        replace_drop(DROP.HUMPHEAD_HIREDHAND,0)
        ctx.humphead_drop_configured=false
    end
end
function M.on_pre_level_generation(ctx)
    configure_drop_substitutions(ctx)
    configure_humphead_drop(ctx)
end
local function nearest_kali_altar(x,y,layer)
    local best,best_distance=nil,math.huge
    for _,name in ipairs({"FLOOR_ALTAR","FLOOR_DUAT_ALTAR"}) do
        local altar_type=placements.type_of(name)
        for _,uid in ipairs(altar_type and get_entities_by_type(altar_type) or {}) do
            local altar=get_entity(uid)
            if altar and altar.layer==layer then
                local distance=math.abs(altar.x-x)+math.abs(altar.y-y)
                if distance<best_distance then best,best_distance=altar,distance end
            end
        end
    end
    return best
end
local function duat_altar()
    local altar_type=placements.type_of("FLOOR_DUAT_ALTAR")
    local altar_uid=altar_type and get_entities_by_type(altar_type)[1] or nil
    return altar_uid and get_entity(altar_uid) or nil
end

-- The Duat entrance consumes the Ankh and discards equipped/held items. Keep
-- a current snapshot only while the player is in the City of Gold, then place
-- fresh copies on Duat's Kali altar after the transition. Entity UIDs cannot
-- survive the level change, so this intentionally restores item types rather
-- than trying to preserve the destroyed entities themselves.
local DUAT_BACK_ITEM_NAMES={
    "ITEM_CAPE", "ITEM_VLADS_CAPE", "ITEM_JETPACK", "ITEM_HOVERPACK",
    "ITEM_POWERPACK", "ITEM_TELEPORTER_BACKPACK",
}
-- Items that can plausibly have been dropped by the player at the City of
-- Gold altar. Do not recover arbitrary MASK.ITEM entities: blood, leaves,
-- pots, and room machinery share that mask and are not player equipment.
local DUAT_NEAR_ALTAR_ITEM_NAMES={
    "ITEM_EXCALIBUR", "ITEM_SCEPTER", "ITEM_HOUYIBOW", "ITEM_LIGHT_ARROW",
    "ITEM_PLASMACANNON", "ITEM_CLONEGUN", "ITEM_TELEPORTER", "ITEM_MATTOCK",
    "ITEM_SHOTGUN", "ITEM_FREEZERAY", "ITEM_WEBGUN", "ITEM_CAMERA",
    "ITEM_CROSSBOW", "ITEM_MACHETE", "ITEM_BOOMERANG", "ITEM_MADAMETUSK_IDOL",
    "ITEM_IDOL", "ITEM_PICKUP_ELIXIR", "ITEM_PICKUP_TABLETOFDESTINY",
    "ITEM_PICKUP_UDJATEYE", "ITEM_PICKUP_ANKH", "ITEM_PICKUP_HEDJET",
    "ITEM_PICKUP_CROWN", "ITEM_PICKUP_SKELETON_KEY",
    "ITEM_PICKUP_SPECIALCOMPASS", "ITEM_PICKUP_COMPASS",
}
local function duat_recovery_enabled(ctx)
    return not ctx.is_duat_recovery_enabled or ctx.is_duat_recovery_enabled()
end
local function duat_recovery_type_name(entity_type)
    local ok,name=pcall(get_entity_name,entity_type,true)
    return ok and name or tostring(entity_type)
end
local function held_by_any_player(uid)
    for _,player in ipairs(players or {}) do
        if entity_has_item_uid(player.uid,uid) then return true end
    end
    return false
end
local function is_duat_recoverable_altar_item(ctx,entity_type)
    if not ctx.duat_recovery_altar_types then
        local types={}
        for _,name in ipairs(DUAT_BACK_ITEM_NAMES) do
            local item_type=placements.type_of(name)
            if item_type then types[item_type]=true end
        end
        for _,name in ipairs(DUAT_NEAR_ALTAR_ITEM_NAMES) do
            local item_type=placements.type_of(name)
            if item_type then types[item_type]=true end
        end
        ctx.duat_recovery_altar_types=types
    end
    return ctx.duat_recovery_altar_types[entity_type] or false
end
local function snapshot_duat_recovery(ctx)
    if not duat_recovery_enabled(ctx) then return end
    if state.theme~=THEME.CITY_OF_GOLD then return end
    local recovered={}
    for player_index,player in ipairs(players or {}) do
        local held=player:get_held_entity()
        if held and held.type then table.insert(recovered,{type=held.type.id,kind="held",player=player_index}) end
        for _,name in ipairs(DUAT_BACK_ITEM_NAMES) do
            local item_type=placements.type_of(name)
            if item_type and entity_has_item_type(player.uid,item_type) then
                table.insert(recovered,{type=item_type,kind="back",player=player_index})
                break
            end
        end
    end
    -- A self-sacrifice or fall can make the carried gear leave the player a
    -- few frames before the level transition. Preserve any unheld item that
    -- lands at Kali's altar as well, rather than requiring it to remain in a
    -- player inventory until the final City of Gold frame.
    local altar_type=placements.type_of("FLOOR_ALTAR")
    local nearby_seen={}
    for _,altar_uid in ipairs(altar_type and get_entities_by_type(altar_type) or {}) do
        local altar=get_entity(altar_uid)
        if altar then
            for _,uid in ipairs(get_entities_by(0,MASK.ITEM,LAYER.BOTH)) do
                local item=get_entity(uid)
                if not nearby_seen[uid] and item and item.type and is_duat_recoverable_altar_item(ctx,item.type.id) and item.layer==altar.layer and not held_by_any_player(uid)
                    and math.abs(item.x-altar.x)+math.abs(item.y-altar.y)<=4 then
                    nearby_seen[uid]=true
                    table.insert(recovered,{type=item.type.id,kind="near Kali altar",player=0,uid=uid})
                end
            end
        end
    end
    local labels={}
    for _,item in ipairs(recovered) do
        table.insert(labels,string.format("P%d %s=%s (type %s)",item.player,item.kind,duat_recovery_type_name(item.type),tostring(item.type)))
    end
    local signature=table.concat(labels,"; ")
    if signature~="" and signature~=ctx.duat_recovery_signature then
        ctx.duat_recovery=recovered
        ctx.duat_recovery_signature=signature
        ctx.duat_recovery_empty_logged=false
        ctx.log("Duat recovery snapshot detected in City of Gold: "..signature)
    elseif signature=="" and not ctx.duat_recovery_empty_logged then
        ctx.duat_recovery_empty_logged=true
        if ctx.duat_recovery and #ctx.duat_recovery>0 then
            ctx.log("Duat recovery snapshot in City of Gold: no item currently detected; retaining the last non-empty snapshot for the transition")
        else
            ctx.log("Duat recovery snapshot in City of Gold: no held or supported back item detected")
        end
    end
end
local function restore_duat_recovery(ctx)
    if not duat_recovery_enabled(ctx) then
        ctx.duat_recovery=nil
        return
    end
    if state.theme~=THEME.DUAT or ctx.duat_recovery_spawned then return end
    ctx.duat_recovery_spawned=true
    local recovered=ctx.duat_recovery
    if not recovered or #recovered==0 then
        ctx.log("Duat item recovery reached Duat: no captured items to restore")
        return
    end
    ctx.log("Duat item recovery reached Duat with "..#recovered.." captured item(s); searching for the Duat altar")
    local altar=duat_altar()
    if not altar then
        ctx.log("Duat item recovery found no FLOOR_DUAT_ALTAR; leaving snapshot pending")
        ctx.duat_recovery_spawned=false
        return
    end
    for index,item in ipairs(recovered) do
        local offset=(index-1)*0.65
        local uid=spawn_entity_snapped_to_floor(item.type,altar.x+offset,altar.y+1,altar.layer)
        ctx.log(string.format("Duat recovery restored P%d %s %s (type %s) at Duat altar (uid %s)",item.player or 0,item.kind,duat_recovery_type_name(item.type),tostring(item.type),tostring(uid)))
    end
    ctx.duat_recovery=nil
end
local function scan_kali_present_eggplants(ctx, pending, attempt)
    ctx.defer(1,"Kali Present payload scan",function()
        if ctx.pending_kali_present_payload~=pending then return end
        local eggplant_type=placements.type_of("ITEM_EGGPLANT")
        local found=false
        for _,uid in ipairs(eggplant_type and get_entities_by_type(eggplant_type) or {}) do
            if not pending.existing_eggplants[uid] then
                local eggplant=get_entity(uid)
                -- Only the payload created at this exact sacrifice position
                -- belongs to this check. A wider scan can steal an unrelated
                -- Eggplant reward that happened to spawn elsewhere nearby.
                if eggplant and eggplant.layer==pending.layer and math.abs(eggplant.x-pending.x)<=1.25 and math.abs(eggplant.y-pending.y)<=1.25 then
                    found=true
                    ctx.log(string.format("Kali Present scan found new Eggplant uid %d at %.1f, %.1f layer %s after %d frame(s)",uid,eggplant.x,eggplant.y,tostring(eggplant.layer),attempt))
                    -- Kali creates this Eggplant outside the generic entity
                    -- spawn callback. Now that its exact uid and coordinates
                    -- are known, replace this one native item in place.
                    -- Kali already creates its Eggplant at a stable altar
                    -- reward position, so preserve that anchor.
                    local replacement_uid=materialize(ctx,"CHECK_KALI_PRESENT",eggplant.x,eggplant.y,eggplant.layer,uid,false,false)
                    if replacement_uid then
                        ctx.kali_present_completed=true
                        ctx.log("Kali Present Eggplant uid "..uid.." replaced in place with mapped reward uid "..replacement_uid)
                    end
                    break
                end
            end
        end
        if found or attempt>=10 then
            if not found then
                -- Destruction callbacks cannot distinguish a sacrifice from a
                -- Present that was broken beside the altar. Only the native
                -- Eggplant payload proves a successful sacrifice; never award
                -- a fallback here, or a broken Present would grant a check.
                ctx.log("Kali Present scan found no native Eggplant after 10 frames; treating the Present as broken/not sacrificed and awarding no check")
            end
            -- End this short, source-scoped diagnostic window; later ordinary
            -- Eggplants must remain untouched.
            ctx.pending_kali_present_payload=nil
            ctx.kali_present_sacrifice_pending=false
            return
        end
        scan_kali_present_eggplants(ctx,pending,attempt+1)
    end)
end
local function shop_owner_at_item(item)
    if not is_inside_active_shop_room or not is_inside_active_shop_room(item.x,item.y,item.layer) then return nil end
    local owner_type=placements.type_of("MONS_SHOPKEEPER")
    local best,best_distance=nil,math.huge
    for _,uid in ipairs(owner_type and get_entities_by_type(owner_type) or {}) do
        local owner=get_entity(uid)
        if owner and owner.layer==item.layer and is_inside_active_shop_room(owner.x,owner.y,owner.layer) then
            local distance=math.abs(owner.x-item.x)+math.abs(owner.y-item.y)
            if distance<best_distance then best,best_distance=owner,distance end
        end
    end
    return best
end
local function native_shop_owner(item)
    local owned_items=state.room_owners and state.room_owners.owned_items
    local ownership=owned_items and owned_items[item.uid] or nil
    local owner=ownership and ownership.owner_uid and get_entity(ownership.owner_uid) or nil
    if owner then return owner end
    return nil
end
local function replace_black_market_hedjet(ctx,attempt)
    if state.theme~=THEME.JUNGLE or ctx.randomizer_state.level_materialized.CHECK_BLACK_MARKET then return end
    local hedjet_type=placements.type_of("ITEM_PICKUP_HEDJET")
    local saw_hedjet=false
    for _,uid in ipairs(hedjet_type and get_entities_by_type(hedjet_type) or {}) do
        local hedjet=get_entity(uid)
        if hedjet then saw_hedjet=true end
        -- The Black Market contains several shopkeepers. Use the Hedjet's
        -- registered owner, not the nearest one, or the sale label can appear
        -- without an actual purchase/steal relationship.
        local owner=hedjet and native_shop_owner(hedjet) or nil
        if owner then
            local reward,reward_type=placements.reward_type(ctx.randomizer_state,"CHECK_BLACK_MARKET")
            if not reward_type then
                ctx.lifecycle:fail("CHECK_BLACK_MARKET","mapped reward has no entity type: "..tostring(reward))
                return
            end
            local price=hedjet.price
            local replacement_uid=spawn_entity_nonreplaceable(reward_type,hedjet.x,hedjet.y,hedjet.layer,0,0)
            local added,err=pcall(add_item_to_shop,replacement_uid,owner.uid)
            if not added then
                local replacement=get_entity(replacement_uid)
                if replacement then replacement:destroy() end
                ctx.lifecycle:fail("CHECK_BLACK_MARKET","replacement could not be registered as a shop item: "..tostring(err))
                return
            end
            local replacement=get_entity(replacement_uid)
            if replacement and price then replacement.price=price end
            hedjet:destroy()
            ctx.randomizer_state.level_materialized.CHECK_BLACK_MARKET=true
            ctx.lifecycle:mark("CHECK_BLACK_MARKET","materialized","native shop ownership")
            ctx.log("CHECK CHECK_BLACK_MARKET -> "..reward.." owned by native Shopkeeper uid "..owner.uid.." (price "..tostring(price)..")")
            return
        end
    end
    -- A normal Jungle level has no Hedjet at all. Ownership can be late on a
    -- real Black Market Hedjet, but do not schedule retries or report a
    -- failure merely because this is an ordinary Jungle level.
    if saw_hedjet and attempt<20 then
        ctx.defer(1,"Black Market ownership retry",function() replace_black_market_hedjet(ctx,attempt+1) end)
    elseif saw_hedjet then
        ctx.lifecycle:fail("CHECK_BLACK_MARKET","no native shop ownership record after 20 frames; native Hedjet left unchanged")
    end
end
local function place_kali_present_source(ctx)
    if ctx.kali_present_completed then return end
    local world=state.world or 0
    -- A source from a save/load of this same level is still valid. A stale UID
    -- from a prior level is discarded, allowing the next altar level to offer
    -- a fresh Present until this check has actually been collected.
    if ctx.kali_present_source_placed then
        local source=ctx.kali_present_source_location
        local same_level=source and source.world==world and source.level==state.level and source.theme==state.theme
        local existing=same_level and ctx.kali_present_source_uid and get_entity(ctx.kali_present_source_uid) or nil
        if existing and existing.type.id==placements.type_of("ITEM_PRESENT") then return end
        ctx.kali_present_source_placed=false
        ctx.kali_present_source_uid=nil
        ctx.kali_present_source_location=nil
    end
    local altar_type=placements.type_of("FLOOR_ALTAR")
    local present_type=placements.type_of("ITEM_PRESENT")
    local diamond_type=placements.type_of("ITEM_DIAMOND")
    if not altar_type or not present_type or not diamond_type then
        ctx.log("Kali Present source adapter unavailable: altar, Present, or Diamond entity is missing")
        return
    end
    local altars=get_entities_by_type(altar_type)
    if #altars==0 then return end
    -- The source is deliberately created in the same level as the first Kali
    -- altar the run encounters. Presents are dropped at exits, so making it a
    -- shuffled reward elsewhere could make this check impossible to reach.
    for _,pet_name in ipairs({"MONS_PET_DOG","MONS_PET_CAT","MONS_PET_HAMSTER"}) do
        local pet_type=placements.type_of(pet_name)
        for _,uid in ipairs(pet_type and get_entities_by_type(pet_type) or {}) do
            local pet=get_entity(uid)
            if pet then
                local x,y,layer=pet.x,pet.y,pet.layer
                local shop_owner=shop_owner_at_item(pet)
                local pet_price=pet.price
                -- Claim the source before spawning. Spawn callbacks can
                -- re-enter adapter code while this function is still active;
                -- without this claim the same pet can become two Presents.
                ctx.kali_present_source_placed=true
                ctx.kali_present_source_seen=false
                ctx.kali_present_source_location={world=world,level=state.level,theme=state.theme,x=x,y=y,layer=layer}
                local present_uid=spawn_entity_nonreplaceable(present_type,x,y,layer,0,0)
                if not present_uid then
                    ctx.kali_present_source_placed=false
                    ctx.kali_present_source_location=nil
                    ctx.lifecycle:fail("CHECK_KALI_PRESENT","could not spawn Present source")
                    return
                end
                if shop_owner then
                    local added,err=pcall(add_item_to_shop,present_uid,shop_owner.uid)
                    if added then
                        local shop_present=get_entity(present_uid)
                        if shop_present and pet_price then shop_present.price=pet_price end
                        ctx.log("Kali Present source is a shop item owned by Shopkeeper uid "..shop_owner.uid.." (price "..tostring(pet_price)..")")
                    else
                        ctx.log("Kali Present could not be added to Shopkeeper uid "..shop_owner.uid..": "..tostring(err))
                    end
                end
                pet:destroy()
                ctx.kali_present_source_uid=present_uid
                local present=get_entity(present_uid)
                if present then
                    -- The game fills a freshly spawned Present on its next
                    -- update. Configure its payload after that initialization
                    -- frame; assigning `inside` immediately is overwritten by
                    -- the vanilla random Present roll.
                    ctx.defer(1,"Kali Present Diamond payload",function()
                        local source=get_entity(present_uid)
                        if source and source.type.id==present_type then
                            source.inside=diamond_type
                            ctx.log("Kali Present source uid "..present_uid.." payload forced to Diamond")
                        end
                    end)
                    present:set_pre_destroy(function(self)
                        if ctx.kali_present_completed or ctx.randomizer_state.level_materialized.CHECK_KALI_PRESENT then return end
                        local altar=nearest_kali_altar(self.x,self.y,self.layer)
                        if not altar or math.abs(self.x-altar.x)+math.abs(self.y-altar.y)>2 then
                            ctx.log("Kali Present source uid "..self.uid.." was destroyed away from an altar")
                            return
                        end
                        local existing_eggplants={}
                        local eggplant_type=placements.type_of("ITEM_EGGPLANT")
                        for _,eggplant_uid in ipairs(eggplant_type and get_entities_by_type(eggplant_type) or {}) do existing_eggplants[eggplant_uid]=true end
                        local pending={x=self.x,y=self.y,layer=self.layer,altar_x=altar.x,altar_y=altar.y,source_uid=self.uid,existing_eggplants=existing_eggplants}
                        ctx.pending_kali_present_payload=pending
                        ctx.kali_present_sacrifice_pending=true
                        ctx.kali_present_source_uid=nil
                        ctx.log(string.format("Kali Present source uid %d destroyed at altar %.1f, %.1f; waiting for native payload at %.1f, %.1f layer %s",self.uid,altar.x,altar.y,self.x,self.y,tostring(self.layer)))
                        scan_kali_present_eggplants(ctx,pending,1)
                    end)
                else
                    ctx.log("Kali Present source uid "..tostring(present_uid).." could not be hooked for destruction")
                end
                ctx.log(string.format("Kali Present source: first eligible altar at %d-%d; replaced %s uid %d with Present uid %s at %.1f, %.1f",world,state.level,pet_name,uid,tostring(present_uid),x,y))
                return
            end
        end
    end
    ctx.log("Kali Present altar level has no pet; will try the next eligible level")
end
local function player_owned(item)
    for _,player in ipairs(players or {}) do
        if item.last_owner_uid==player.uid or (item.overlay and item.overlay.uid==player.uid) then return true end
    end
    return false
end
-- Mod-placed rewards are excluded by uid, whatever order same-frame scans run in.
local function new_kali_altar_items(ctx,altar,existing_items)
    local candidates={}
    local observed={}
    local pending_present=ctx.pending_kali_present_payload
    local eggplant_type=placements.type_of("ITEM_EGGPLANT")
    local kapala_type=placements.type_of("ITEM_PICKUP_KAPALA")
    for _,uid in ipairs(get_entities_by(0,MASK.ITEM,LAYER.BOTH)) do
        local item=get_entity(uid)
        if item and not existing_items[uid] and item.layer==altar.layer then
            local distance=math.abs(item.x-altar.x)+math.abs(item.y-altar.y)
            -- A Present sacrificed at the altar creates its own native
            -- Eggplant payload. When Kali grants a normal favor in the same
            -- window, that payload belongs to CHECK_KALI_PRESENT, not the
            -- first normal-favor check.
            local is_pending_present_payload=pending_present and item.type and item.type.id==eggplant_type
                and item.layer==pending_present.layer
                and math.abs(item.x-pending_present.x)<=1.25
                and math.abs(item.y-pending_present.y)<=1.25
            local is_placed_reward=ctx.placed_rewards[uid]
            local is_player_owned=player_owned(item)
            if distance<=3 then
                table.insert(observed,string.format("uid %d type %s at %.1f, %.1f%s%s%s",uid,tostring(item.type and item.type.id),item.x,item.y,
                    is_placed_reward and " (mod-placed reward)" or "",
                    is_player_owned and " (player-owned)" or "",
                    is_pending_present_payload and " (pending Present payload)" or ""))
            end
            -- Kapala is the separate second Kali check, replaced through its
            -- dedicated native DROP hook. Never let the first-gift scan claim
            -- it when the counter jumps across the Kapala threshold.
            if distance<=3 and not is_placed_reward and not is_player_owned and not is_pending_present_payload and item.type.id~=kapala_type then
                table.insert(candidates,{entity=item,distance=distance})
            end
        end
    end
    table.sort(candidates,function(a,b) return a.distance<b.distance end)
    return candidates,observed
end
local function remove_extra_kali_gifts(ctx,extras)
    for _,entry in ipairs(extras) do
        entry.entity:destroy()
        ctx.log("Removed extra native Kali first-gift item uid "..entry.entity.uid)
    end
end
-- Kali can emit a late native item; runs after the check is already complete.
local function clean_up_first_kali_gift(ctx,altar,existing_items,pass)
    ctx.defer(1,"Kali first-gift cleanup",function()
        remove_extra_kali_gifts(ctx,(new_kali_altar_items(ctx,altar,existing_items)))
        if pass<3 then clean_up_first_kali_gift(ctx,altar,existing_items,pass+1) end
    end)
end
local function replace_first_kali_gift(ctx,existing_items)
    if ctx.kali_first_gift_completed then return end
    local player=players and players[1]
    if not player then return end
    local altar=nearest_kali_altar(player.x,player.y,player.layer)
    if not altar then ctx.log("Kali first-gift check could not find an altar") return end
    local candidates,observed=new_kali_altar_items(ctx,altar,existing_items)
    local first=table.remove(candidates,1)
    local candidate=first and first.entity
    if not candidate then
        ctx.log("Kali first-gift check found no generated reward item near altar; new nearby items: "..(#observed>0 and table.concat(observed,"; ") or "none"))
        return
    end
    local expected=ctx.randomizer_state.mapping and ctx.randomizer_state.mapping.CHECK_KALI_ALTAR_1
    ctx.log(string.format("Kali first-gift candidate uid %d type %d at %.1f, %.1f; mapped reward %s",candidate.uid,candidate.type.id,candidate.x,candidate.y,tostring(expected)))
    local replacement_uid=materialize(ctx,"CHECK_KALI_ALTAR_1",candidate.x,candidate.y,candidate.layer,candidate.uid,true,false)
    ctx.log("Kali first-gift replacement result uid "..tostring(replacement_uid))
    if not replacement_uid then return end
    ctx.kali_first_gift_completed=true
    remove_extra_kali_gifts(ctx,candidates)
    clean_up_first_kali_gift(ctx,altar,existing_items,1)
end
local function log_yang_anchor_failure(ctx)
    ctx.log("Yang native locked-pen anchor missing; nearby door diagnostics follow")
    for _,type_name in ipairs(YANG_FAILURE_ENTITY_TYPES) do
        local entity_type=placements.type_of(type_name)
        for _,uid in ipairs(entity_type and get_entities_by_type(entity_type) or {}) do
            local entity=get_entity(uid)
            if entity then
                ctx.log(string.format("Yang anchor diagnostic %s uid %d at %.1f, %.1f layer %s",type_name,uid,entity.x,entity.y,tostring(entity.layer)))
            end
        end
    end
end

local function yang_position(ctx, yang)
    local best,best_name,best_distance=nil,nil,math.huge
    ctx.log(string.format("Yang is at %.1f, %.1f layer %s; scanning native locked-pen door",yang.x,yang.y,tostring(yang.layer)))
    for _,name in ipairs(YANG_DOOR_TYPES) do
        local kind=placements.type_of(name)
        if kind then
            for _,uid in ipairs(get_entities_by_type(kind)) do
                local door=get_entity(uid)
                if door then
                    local horizontal_distance=math.abs(door.x-yang.x)
                    if horizontal_distance<best_distance then
                        best,best_name,best_distance=door,name,horizontal_distance
                    end
                end
            end
        end
    end
    if best then
        local direction=best.x>=yang.x and 1 or -1
        ctx.log(string.format("Yang reward anchor uses native locked pen %s at %.1f, %.1f (horizontal distance %.1f)",best_name,best.x,best.y,best_distance))
        return best.x+direction,best.y,LAYER.BACK
    end
    ctx.log("Yang reward anchor found no native locked-pen door; Yang check was not placed")
    log_yang_anchor_failure(ctx)
    return nil
end

-- The sword-in-stone can appear after POST_LEVEL_GENERATION, while a test
-- Crown is granted at START. Check both conditions here rather than deciding
-- while the room is still being assembled.
function M.replace_excalibur_if_gated(ctx, attempt)
    -- Excalibur's stone only exists in Tide Pool 4-2. Restricting this avoids
    -- scanning player-carried swords (and retrying) on Tide Pool 4-1/4-3.
    if state.theme~=THEME.TIDE_POOL or state.level~=2 or ctx.randomizer_state.level_materialized.CHECK_EXCALIBUR_STONE then return end
    local has_crown=players_have_any({"ITEM_PICKUP_CROWN"})
    local has_hedjet=players_have_any({"ITEM_PICKUP_HEDJET"})
    if not (has_crown or has_hedjet) then
        ctx.log("Excalibur gate is closed: no player holds a Crown or Hedjet")
        return
    end
    local excalibur_type=placements.type_of("ITEM_EXCALIBUR")
    local swords=excalibur_type and get_entities_by_type(excalibur_type) or {}
    ctx.log(string.format("Excalibur gate is open (Crown=%s Hedjet=%s); found %d sword-in-stone entities",tostring(has_crown),tostring(has_hedjet),#swords))
    for _,uid in ipairs(swords) do
        local sword=get_entity(uid)
        if sword then
            materialize(ctx,"CHECK_EXCALIBUR_STONE",sword.abs_x,sword.abs_y,LAYER.FRONT,sword.uid,true)
            -- A carried source is ignored by materialize; keep scanning in
            -- case the native sword-in-stone is also present.
            if ctx.randomizer_state.level_materialized.CHECK_EXCALIBUR_STONE then return end
        end
    end
    attempt=attempt or 0
    if attempt<30 then
        if attempt==0 then ctx.log("Excalibur gate is open, but the sword has not spawned yet; retrying") end
        ctx.defer(5,"Excalibur stone retry",function() M.replace_excalibur_if_gated(ctx,attempt+1) end)
    else
        ctx.lifecycle:fail("CHECK_EXCALIBUR_STONE","gate was open but no native sword-in-stone appeared after retries")
    end
end

-- Most boss checks have the same lifecycle: remember the boss death position,
-- let a narrowly scoped spawn hook replace its native drop when possible, and
-- use a short fallback if that native event is not exposed by this game/API
-- version. Only the source, check, and state keys vary.
local function attach_delayed_death_reward(ctx, source, check, hook_field, pending_field, label)
    local boss_type=placements.type_of(source)
    local hooks=ctx[hook_field]
    for _,uid in ipairs(boss_type and get_entities_by_type(boss_type) or {}) do
        local boss=get_entity(uid)
        if boss and not hooks[uid] then
            hooks[uid]=true
            local queued=false
            local function queue_reward(self, trigger)
                if queued then return end
                queued=true
                local pending={x=self.x,y=self.y,layer=self.layer}
                ctx[pending_field]=pending
                ctx.log(string.format("%s reward queued from %s at %.1f, %.1f layer %s",label,trigger,pending.x,pending.y,tostring(pending.layer)))
                ctx.defer(2,label.." fallback",function()
                    if ctx[pending_field]==pending then
                        ctx[pending_field]=nil
                        local reward_uid=materialize(ctx,check,pending.x,pending.y,pending.layer,nil,true)
                        ctx.log(label.." fallback materialization result uid "..tostring(reward_uid))
                    end
                end)
            end
            boss:set_pre_kill(function(self)
                queue_reward(self,"pre-kill")
            end)
            ctx.log("Attached "..label.." reward hook to uid "..uid)
        end
    end
end
local function queue_lahamu_reward(ctx, uid, watch, trigger)
    if watch.queued then return end
    watch.queued=true
    ctx.log(string.format("Lahamu uid %d %s; scheduling check reward at %.1f, %.1f layer %s",uid,trigger,watch.x,watch.y,tostring(watch.layer)))
    ctx.defer(2,"Lahamu "..trigger.." materialization",function()
        -- A disappearance during a level transition is not a death. The
        -- level identity is more reliable than assuming Mothership always
        -- reports the Ice Caves theme.
        if state.world~=watch.world or state.level~=watch.level or state.theme~=watch.theme or ctx.randomizer_state.level_materialized.CHECK_LAHAMU then return end
        local reward_uid=materialize(ctx,"CHECK_LAHAMU",watch.x,watch.y,watch.layer,nil,true)
        ctx.log("Lahamu "..trigger.." materialization result uid "..tostring(reward_uid))
    end)
end

local LAHAMU_TYPE_NAMES={"MONS_LAHAMU","MONS_LAMASSU"}
local function is_mothership_level()
    return state.world==5 and state.level==1
end
local function lahamu_types()
    local types={}
    for _,name in ipairs(LAHAMU_TYPE_NAMES) do
        local entity_type=placements.type_of(name)
        if entity_type then table.insert(types,entity_type) end
    end
    return types
end
local function attach_lahamu(ctx, uid, lahamu)
    if not lahamu or ctx.lahamu_hooks[uid] then return end
    local watch={x=lahamu.x,y=lahamu.y,layer=lahamu.layer,world=state.world,level=state.level,theme=state.theme,queued=false}
    ctx.lahamu_hooks[uid]=watch
    -- Most kills take this direct path. The frame watcher below still covers
    -- Lahamu's scripted removal path, which can skip it.
    lahamu:set_pre_kill(function(self)
        watch.x,watch.y,watch.layer=self.x,self.y,self.layer
        queue_lahamu_reward(ctx,uid,watch,"pre-kill")
    end)
    ctx.log("Attached Lahamu death hook and entity watcher to uid "..uid)
end

local function observe_lahamu(ctx)
    if not is_mothership_level() then return end
    local types=lahamu_types()
    local found=0
    for _,uid in ipairs(#types>0 and get_entities_by_type(types) or {}) do
        attach_lahamu(ctx,uid,get_entity(uid))
        found=found+1
    end
    -- Enum aliases have differed between Overlunky releases. The Mothership
    -- contains one uniquely named Lahamu, so fall back to the live entity
    -- name rather than silently missing her when an enum lookup changes.
    if found==0 then
        for _,uid in ipairs(get_entities_by(0,MASK.MONSTER,LAYER.BOTH)) do
            local monster=get_entity(uid)
            if monster and monster.type then
                local ok,name=pcall(get_entity_name,monster.type.id,true)
                if ok and name=="Lahamu" then
                    attach_lahamu(ctx,uid,monster)
                    found=found+1
                    ctx.log("Attached Lahamu through Mothership name fallback (type "..tostring(monster.type.id)..", uid "..uid..")")
                end
            end
        end
    end
    if found==0 and not ctx.lahamu_diagnostic_logged then
        ctx.lahamu_diagnostic_logged=true
        local monsters={}
        for _,uid in ipairs(get_entities_by(0,MASK.MONSTER,LAYER.BOTH)) do
            local monster=get_entity(uid)
            if monster and monster.type then
                local ok,name=pcall(get_entity_name,monster.type.id,true)
                monsters[name or tostring(monster.type.id)]=true
            end
        end
        local names={}
        for name in pairs(monsters) do table.insert(names,name) end
        table.sort(names)
        ctx.log("Mothership Lahamu scan found no known entity; monsters present: "..table.concat(names,", "))
    end
end

local function is_cursed(player)
    local ok,value=pcall(function() return player:is_cursed() end)
    if ok and type(value)=="boolean" then return value end
    ok,value=pcall(function() return player.cursed end)
    if ok and type(value)=="boolean" then return value end
    ok,value=pcall(function() return test_flag(player.flags,ENT_FLAG.CURSED) end)
    return ok and value or false
end

local function restore_true_crown_players(ctx)
    if ctx.is_true_crown_restoration_enabled and not ctx.is_true_crown_restoration_enabled() then return end
    local cured=0
    for _,player in ipairs(players or {}) do
        if is_cursed(player) then
            player:set_cursed(false)
            player.health=math.max(player.health,4)
            cured=cured+1
        end
    end
    ctx.log("True Crown reward delivered: cured "..cured.." player(s) and restored each to at least 4 HP")
end

-- The native DROP replacement is reliable, whereas Beg's entity lifecycle is
-- not: this quest NPC can deliver its reward without a Lua spawn or pre-kill
-- callback. State 4 is the pre-delivery True Crown encounter; its 4 -> 5
-- transition is authoritative confirmation that the reward sequence ended.
local BEG_TRUE_CROWN_DELIVERED_STATE=5
local function watch_beg_true_crown_quest(ctx)
    local quests=state.quests
    local current=quests and quests.beg_state
    if current==nil then return end
    local previous=ctx.beg_last_state
    if previous==nil then
        ctx.beg_last_state=current
        ctx.log("Beg quest state initialized: "..tostring(current))
        return
    end
    if previous==current then return end
    ctx.beg_last_state=current
    ctx.log(string.format("Beg quest state changed: %s -> %s at %d-%d (theme %s)",tostring(previous),tostring(current),state.world,state.level,tostring(state.theme)))
    if previous==BEG_TRUE_CROWN_DELIVERED_STATE-1 and current==BEG_TRUE_CROWN_DELIVERED_STATE then
        -- The state changes as the native delivery sequence completes. Give
        -- that sequence two frames to apply curse effects before curing every
        -- currently cursed player.
        ctx.defer(2,"True Crown quest-state restoration",function()
            ctx.log("Beg True Crown quest completion detected; restoring cursed players")
            restore_true_crown_players(ctx)
        end)
    end
end

local function reset_beg_intermediate_state(ctx)
    local quests=state.quests
    if not quests or quests.beg_state~=2 then return end
    quests.beg_state=1
    ctx.beg_last_state=1
    ctx.log("Beg quest state reset: 2 -> 1 at level transition")
end

local function attach_queen_bee_diagnostics(ctx)
    local queen_type=placements.type_of("MONS_QUEENBEE")
    for _,uid in ipairs(queen_type and get_entities_by_type(queen_type) or {}) do
        local queen=get_entity(uid)
        if queen and not ctx.queen_bee_hooks[uid] then
            ctx.queen_bee_hooks[uid]=true
            queen:set_pre_kill(function(self)
                local reward=ctx.drop_configured[DROP.QUEENBEE_ROYALJELLY]
                local pending={x=self.x,y=self.y,layer=self.layer}
                ctx.pending_queen_bee_drop=pending
                ctx.log(string.format("Queen Bee uid %s pre-kill at %.1f, %.1f layer %s; configured reward=%s",tostring(self.uid),pending.x,pending.y,tostring(pending.layer),tostring(reward)))
                ctx.defer(30,"Queen Bee reward diagnostic window",function()
                    if ctx.pending_queen_bee_drop==pending then
                        ctx.pending_queen_bee_drop=nil
                        ctx.log("Queen Bee reward diagnostic: no native Royal Jelly or mapped reward observed within 30 frames")
                    end
                end)
            end)
            ctx.log("Attached Queen Bee reward diagnostics to uid "..uid)
        end
    end
end

local function observe_pending_quest_reward(ctx,entity)
    local queen_pending=ctx.pending_queen_bee_drop
    if queen_pending and entity and entity.layer==queen_pending.layer and math.abs(entity.x-queen_pending.x)+math.abs(entity.y-queen_pending.y)<=12 then
        local reward,mapped_type=placements.reward_type(ctx.randomizer_state,"CHECK_QUEEN_BEE")
        local jelly_type=placements.type_of("ITEM_PICKUP_ROYALJELLY")
        if entity.type.id==jelly_type or entity.type.id==mapped_type then
            ctx.pending_queen_bee_drop=nil
            local kind=entity.type.id==jelly_type and "native Royal Jelly" or "mapped reward "..tostring(reward)
            ctx.log("Queen Bee reward observed: "..kind.." uid "..entity.uid.." (type "..entity.type.id..")")
        end
    end
end

function M.on_post_level_generation(ctx)
    -- Present identities are level-local. Clearing them here prevents an item
    -- left on a prior level from being mistaken for a sacrifice on this one.
    ctx.kali_presents={}
    local theme=state.theme
    local items=get_entities_by(0,MASK.ITEM,LAYER.BOTH)
    -- Sun Challenge's supplies bag has special player-texture setup. Capture
    -- bags already present when the level is built so the post-spawn adapter
    -- below handles only the reward emitted after challenge completion.
    ctx.sun_challenge_bags={}
    if theme==THEME.SUNKEN_CITY then
        local playerbag_type=placements.type_of("ITEM_PICKUP_PLAYERBAG")
        for _,uid in ipairs(playerbag_type and get_entities_by_type(playerbag_type) or {}) do ctx.sun_challenge_bags[uid]=true end
    end
    ctx.log(string.format("Scanning %d item entities in theme %s",#items,tostring(theme)))
    for _,anchor in ipairs(ITEM_ANCHORS) do
        if anchor.post_generation~=false and theme==anchor.theme and (not anchor.level or state.level==anchor.level) and players_have_any(anchor.requires_any) then
            local source_type=placements.type_of(anchor.source)
            if source_type then
                local source_uids=anchor.absolute and get_entities_by_type(source_type) or items
                for _,uid in ipairs(source_uids) do
                local entity=get_entity(uid)
                if entity and entity.type.id==source_type and (not anchor.layer or entity.layer==anchor.layer) then
                    local x,y=entity.x,entity.y
                    if anchor.absolute then x,y=entity.abs_x,entity.abs_y end
                    materialize(ctx,anchor.check,x,y,anchor.layer or entity.layer,uid,anchor.snap)
                end
            end end
        end
    end
    if theme==THEME.TIDE_POOL and state.level==2 and not ctx.randomizer_state.level_materialized.CHECK_HUMPHEAD_CAVE_IDOL then
        -- The clam's Idol can be created after the first item scan. Recheck
        -- after its cave has completed construction.
        ctx.defer(20,"Humphead cave Idol retry",function()
            if ctx.randomizer_state.level_materialized.CHECK_HUMPHEAD_CAVE_IDOL then return end
            local idol_type=placements.type_of("ITEM_IDOL")
            local idols=idol_type and get_entities_by_type(idol_type) or {}
            ctx.log("Humphead cave Idol retry found "..#idols.." ITEM_IDOL entities")
            for _,uid in ipairs(idols) do
                local idol=get_entity(uid)
                if idol and idol.layer==LAYER.BACK then
                    materialize(ctx,"CHECK_HUMPHEAD_CAVE_IDOL",idol.x,idol.y,LAYER.BACK,uid,true)
                    return
                end
            end
        end)
    end
    replace_van_reward(ctx,items)
    sparrow.on_post_level_generation(ctx)
    replace_black_market_hedjet(ctx,1)
    place_kali_present_source(ctx)
    if theme==THEME.TIDE_POOL then
        -- Delay beyond room construction; this also covers a Crown granted by
        -- the optional test-resources callback at ON.START.
        ctx.defer(10,"Excalibur stone initial scan",function() M.replace_excalibur_if_gated(ctx) end)
    end
    for _,anchor in ipairs(NPC_ANCHORS) do
        if theme==anchor.theme then
            local source_type=placements.type_of(anchor.source)
            local entities=source_type and get_entities_by_type(source_type) or {}
            local entity=entities[1] and get_entity(entities[1]) or nil
            if entity then
                local x,y,layer=entity.x-1,entity.y,anchor.layer or entity.layer
                if anchor.check=="CHECK_YANG" then x,y,layer=yang_position(ctx,entity) end
                if x then materialize(ctx,anchor.check,x,y,layer,nil,anchor.snap) end
            end
        end
    end
    if theme==THEME.DWELLING then
        attach_delayed_death_reward(ctx,"MONS_CAVEMAN_BOSS","CHECK_QUILLBACK","quillback_hooks","pending_quillback_drop","Quillback death")
    end
    attach_queen_bee_diagnostics(ctx)
    -- Tiamat has no item drop to intercept. Her check is earned on death, so
    -- wait for her death animation rather than materializing at level start.
    if theme==THEME.TIAMAT then
        attach_delayed_death_reward(ctx,"MONS_TIAMAT","CHECK_TIAMAT","tiamat_hooks","pending_tiamat_reward","Tiamat death")
    end
    -- Vlad's Cape is a death reward, not a room item.  Never scan all Capes
    -- in Volcana: a carried Cape is reconstructed during level transitions.
    if theme==THEME.VOLCANA then
        local vlad_type=placements.type_of("MONS_VLAD")
        for _,uid in ipairs(vlad_type and get_entities_by_type(vlad_type) or {}) do
            local vlad=get_entity(uid)
            if vlad and not ctx.vlad_hooks[uid] then
                ctx.vlad_hooks[uid]=true
                vlad:set_pre_kill(function(self)
                    ctx.pending_vlad_cape={x=self.x,y=self.y,layer=self.layer}
                    ctx.log(string.format("Vlad death detected at %.1f, %.1f layer %s; waiting for native Cape",self.x,self.y,tostring(self.layer)))
                end)
                ctx.log("Attached Vlad Cape death hook to uid "..uid)
            end
        end
    end
    -- Yeti royalty checks replace their exact death drops. Spawning a reward
    -- beside the boss left the native Spike Shoes/Compass in the item pool.
    if theme==THEME.ICE_CAVES then
        local function attach_yeti(source,check,native_drop)
            if not native_drop then
                ctx.log(check.." adapter unavailable: native drop entity is missing")
                return
            end
            local boss_type=placements.type_of(source)
            for _,uid in ipairs(boss_type and get_entities_by_type(boss_type) or {}) do
                local boss=get_entity(uid)
                if boss and not ctx.yeti_hooks[uid] then
                    ctx.yeti_hooks[uid]=true
                    boss:set_pre_kill(function(self)
                        local pending={check=check,native_drop=native_drop,x=self.x,y=self.y,layer=self.layer}
                        ctx.pending_yeti_drops[native_drop]=pending
                        ctx.defer(2,check.." native-drop fallback",function()
                            if ctx.pending_yeti_drops[native_drop]==pending then
                                ctx.pending_yeti_drops[native_drop]=nil
                                materialize(ctx,check,pending.x,pending.y,pending.layer,nil,true)
                            end
                        end)
                    end)
                    ctx.log("Attached "..check.." death-drop hook to uid "..uid)
                end
            end
        end
        attach_yeti("MONS_YETIQUEEN","CHECK_YETI_QUEEN",placements.type_of("ITEM_PICKUP_SPIKESHOES"))
        attach_yeti("MONS_YETIKING","CHECK_YETI_KING",placements.type_of("ITEM_PICKUP_COMPASS"))

    end
    -- Do not assume a particular theme for Mothership's internal room state.
    -- The entity type is the authoritative scope for this adapter.
    observe_lahamu(ctx)
    -- Humphead's DROP entry is a script-owned Hired Hand, so it cannot be
    -- substituted directly. Wait for its native Present and replace that
    -- independent item instead.
    if theme==THEME.TIDE_POOL then
        -- Great Humphead is represented by Overlunky's GiantFish entity.
        local humphead_type=placements.type_of("MONS_GIANTFISH")
        for _,uid in ipairs(humphead_type and get_entities_by_type(humphead_type) or {}) do
            local boss=get_entity(uid)
            if boss and not ctx.humphead_hooks[uid] then
                ctx.humphead_hooks[uid]=true
                boss:set_pre_kill(function(self)
                    ctx.pending_humphead_present={x=self.x,y=self.y,layer=self.layer}
                    ctx.log("Humphead death detected; waiting for native Present")
                end)
                ctx.log("Attached Humphead Present hook to uid "..uid)
            end
        end
    end
    -- First Anubis's Scepter is likewise a death reward. Its spawn does not
    -- have an exposed DROP constant, so bind the replacement to this boss.
    if theme==THEME.TEMPLE then
        attach_delayed_death_reward(ctx,"MONS_ANUBIS","CHECK_ANUBIS_SCEPTER","anubis_hooks","pending_anubis_scepter_drop","Anubis Scepter")
    end
    -- Yama (the Eggplant King) drops an Eggplant Crown on death. Bind to the
    -- boss rather than doing a generic crown scan, which would touch crowns
    -- from unrelated sources. Eggplant World has its own theme, so detect the
    -- boss type directly instead of depending on a theme enum.
    attach_delayed_death_reward(ctx,"MONS_YAMA","CHECK_EGGPLANT_KING","eggplant_king_hooks","pending_eggplant_crown","Eggplant King Crown")
end

function M.on_balance_post_level_generation(ctx)
    duat.on_post_level_generation(ctx)
end

function M.register_spawn_hooks(ctx)
    sparrow.register(ctx)
    duat.register(ctx)
    local present_type=placements.type_of("ITEM_PRESENT")
    local anubis2_type=placements.type_of("MONS_ANUBIS2")
    if anubis2_type then
        -- Anubis II is created only after the player reaches the top of Duat.
        -- The drop replacement is already armed in PRE level generation; this
        -- log confirms the delayed boss arrived under that configuration.
        set_post_entity_spawn(function(entity)
            if state.theme==THEME.DUAT then
                ctx.log("Anubis II spawned uid "..entity.uid.."; direct Jetpack replacement armed="..tostring(ctx.drop_configured[DROP.ANUBIS2_JETPACK]~=nil))
            end
        end,SPAWN_TYPE.ANY,0,anubis2_type)
    else
        ctx.log("Anubis II spawn diagnostic unavailable: MONS_ANUBIS2 entity type missing")
    end
    local types=lahamu_types()
    if #types>0 then
        -- Mothership can finish creating Lahamu after the normal level scan.
        -- Attach at her actual spawn as well as scanning after generation.
        for _,entity_type in ipairs(types) do
            set_post_entity_spawn(function(entity)
                if is_mothership_level() then attach_lahamu(ctx,entity.uid,entity) end
            end,SPAWN_TYPE.ANY,0,entity_type)
        end
    end
    -- `DROP.BEG_TRUECROWN` is configured directly in the engine. Watch the
    -- quest-state transition instead of Beg's unreliable entity lifecycle.
    set_callback(function() watch_beg_true_crown_quest(ctx) end,ON.FRAME)
    set_callback(function() reset_beg_intermediate_state(ctx) end,ON.TRANSITION)
    local queen_type=placements.type_of("MONS_QUEENBEE")
    if queen_type then
        set_post_entity_spawn(function(entity)
            ctx.log(string.format("Queen Bee spawned uid %s at %.1f, %.1f layer %s; drop replacement armed=%s",tostring(entity.uid),entity.x,entity.y,tostring(entity.layer),tostring(ctx.drop_configured[DROP.QUEENBEE_ROYALJELLY]~=nil)))
            attach_queen_bee_diagnostics(ctx)
        end,SPAWN_TYPE.ANY,0,queen_type)
    else
        ctx.log("Queen Bee diagnostics unavailable: MONS_QUEENBEE entity type missing")
    end
    -- A type value of 0 does not act as an all-entity post-spawn listener in
    -- every Playlunky build. Register the same narrowly scoped observer for
    -- each possible reward entity type instead, so direct DROP replacements
    -- can be observed reliably.
    for _,reward_type in ipairs(placements.reward_entity_types()) do
        set_post_entity_spawn(function(entity)
            observe_pending_quest_reward(ctx,entity)
        end,SPAWN_TYPE.ANY,0,reward_type)
    end
    local udjat_type=placements.type_of("ITEM_PICKUP_UDJATEYE")
    if not udjat_type then return end
    set_pre_entity_spawn(function(entity_type,x,y,layer)
        -- The native chest Eye is in the back layer. A mapped Udjat Eye from
        -- Quillback is a foreground boss reward and must not be rerouted.
        if entity_type~=udjat_type or state.theme~=THEME.DWELLING or layer~=LAYER.BACK then return nil end
        ctx.initialize()
        local reward=placements.reward_type(ctx.randomizer_state,"CHECK_UDJAT_CHEST")
        return replace_native_spawn(ctx,"CHECK_UDJAT_CHEST",reward,x,y,layer,true)
    end,SPAWN_TYPE.ANY,MASK.ITEM,udjat_type)

    local bomb_bag_type=placements.type_of("ITEM_PICKUP_BOMBBAG")
    if bomb_bag_type then
        set_pre_entity_spawn(function(entity_type,x,y,layer)
            local pending=ctx.pending_quillback_drop
            if entity_type~=bomb_bag_type or not pending then return nil end
            ctx.pending_quillback_drop=nil
            local reward=placements.reward_type(ctx.randomizer_state,"CHECK_QUILLBACK")
            return replace_native_spawn(ctx,"CHECK_QUILLBACK",reward,x,y,layer,true)
        end,SPAWN_TYPE.ANY,MASK.ITEM,bomb_bag_type)
    end

    local vlads_cape_type=placements.type_of("ITEM_VLADS_CAPE")
    if vlads_cape_type then
        set_pre_entity_spawn(function(entity_type,x,y,layer)
            local pending=ctx.pending_vlad_cape
            if entity_type~=vlads_cape_type or not pending or layer~=pending.layer then return nil end
            if math.abs(x-pending.x)+math.abs(y-pending.y)>8 then return nil end
            ctx.pending_vlad_cape=nil
            local reward=placements.reward_type(ctx.randomizer_state,"CHECK_VLAD")
            ctx.log("Replacing Vlad's native Cape death reward")
            return replace_native_spawn(ctx,"CHECK_VLAD",reward,x,y,layer,true)
        end,SPAWN_TYPE.ANY,MASK.ITEM,vlads_cape_type)
    end

    -- Yeti Queen and King have distinct fixed death drops. Intercept only an
    -- item spawned after their respective death hooks, preserving unrelated
    -- Spike Shoes and Compasses elsewhere in the Ice Caves.
    set_pre_entity_spawn(function(entity_type,x,y,layer)
        local pending=ctx.pending_yeti_drops and ctx.pending_yeti_drops[entity_type]
        if not pending or layer~=pending.layer then return nil end
        if math.abs(x-pending.x)+math.abs(y-pending.y)>8 then return nil end
        ctx.pending_yeti_drops[entity_type]=nil
        local reward=placements.reward_type(ctx.randomizer_state,pending.check)
        return replace_native_spawn(ctx,pending.check,reward,x,y,layer,true)
    end,SPAWN_TYPE.ANY,MASK.ITEM)

    local scepter_type=placements.type_of("ITEM_SCEPTER")
    if scepter_type then
        set_pre_entity_spawn(function(entity_type,x,y,layer)
            local pending=ctx.pending_anubis_scepter_drop
            if entity_type~=scepter_type or not pending then return nil end
            ctx.pending_anubis_scepter_drop=nil
            local reward=placements.reward_type(ctx.randomizer_state,"CHECK_ANUBIS_SCEPTER")
            return replace_native_spawn(ctx,"CHECK_ANUBIS_SCEPTER",reward,x,y,layer,true)
        end,SPAWN_TYPE.ANY,MASK.ITEM,scepter_type)
    end

    local eggplant_crown_type=placements.type_of("ITEM_PICKUP_EGGPLANTCROWN")
    if eggplant_crown_type then
        set_pre_entity_spawn(function(entity_type,x,y,layer)
            local pending=ctx.pending_eggplant_crown
            if entity_type~=eggplant_crown_type or not pending or layer~=pending.layer then return nil end
            if math.abs(x-pending.x)+math.abs(y-pending.y)>12 then return nil end
            ctx.pending_eggplant_crown=nil
            local reward=placements.reward_type(ctx.randomizer_state,"CHECK_EGGPLANT_KING")
            return replace_native_spawn(ctx,"CHECK_EGGPLANT_KING",reward,x,y,layer,true)
        end,SPAWN_TYPE.ANY,MASK.ITEM,eggplant_crown_type)
    else
        ctx.log("Eggplant King adapter unavailable: ITEM_PICKUP_EGGPLANTCROWN is missing")
    end

    -- These native rewards can be created after ON.POST_LEVEL_GENERATION.
    -- Replacing them at spawn time preserves their vanilla challenge/room gate.
    for _,anchor in ipairs(ITEM_ANCHORS) do
        local source_type=placements.type_of(anchor.source)
        if source_type and anchor.pre_spawn~=false then
            set_pre_entity_spawn(function(entity_type,x,y,layer)
                if entity_type~=source_type or state.theme~=anchor.theme or (anchor.level and state.level~=anchor.level) or (anchor.layer and layer~=anchor.layer) or not players_have_any(anchor.requires_any) then return nil end
                if anchor.shop_only and (not is_inside_active_shop_room or not is_inside_active_shop_room(x,y,layer)) then return nil end
                ctx.initialize()
                local reward=placements.reward_type(ctx.randomizer_state,anchor.check)
                return replace_native_spawn(ctx,anchor.check,reward,x,y,layer,not anchor.shop_only)
            end,SPAWN_TYPE.ANY,MASK.ITEM,source_type)
        end
    end
    -- Van's Diamond may be created after the level callback. Replace only a
    -- Diamond that spawns close to Van's room anchor.
    local van_type,diamond_type=placements.type_of("MONS_OLD_HUNTER"),placements.type_of("ITEM_DIAMOND")
    if van_type and diamond_type then
        set_pre_entity_spawn(function(entity_type,x,y,layer)
            if entity_type~=diamond_type or state.theme~=THEME.VOLCANA or ctx.randomizer_state.level_materialized.CHECK_VAN_HORSING_RESCUE then return nil end
            for _,uid in ipairs(get_entities_by_type(van_type)) do
                local van=get_entity(uid)
                if van and van.layer==layer and math.abs(van.x-x)+math.abs(van.y-y)<=8 then
                    local reward=placements.reward_type(ctx.randomizer_state,"CHECK_VAN_HORSING_RESCUE")
                    return replace_native_spawn(ctx,"CHECK_VAN_HORSING_RESCUE",reward,x,y,layer,true)
                end
            end
            return nil
        end,SPAWN_TYPE.ANY,MASK.ITEM,diamond_type)
    end

    -- Tun keeps a script reference to the native Hou Yi's Bow. Substituting it
    -- in a pre-spawn hook leaves that reference invalid and can crash on
    -- pickup. The Bow is generated in its brick pocket at level creation (not
    -- on challenge completion), so retain that exact entity, hide it in the
    -- back layer, and place the mapped reward at its original location.
    local bow_type=placements.type_of("ITEM_HOUYIBOW")
    if bow_type then
        set_post_entity_spawn(function(entity)
            -- A carried Bow is reconstructed in the foreground during route
            -- transitions (including Dwelling -> Volcana).  The Moon
            -- Challenge's native Bow only exists in its back-layer room.
            if entity.type.id~=bow_type or entity.layer~=LAYER.BACK or (state.theme~=THEME.JUNGLE and state.theme~=THEME.VOLCANA) then return end
            if ctx.moon_handoff_spawning then return end
            -- Native Hou Yi Bows in these two routes are the Moon reward.
            -- Ignore Bow entities created by our own replacement hook.
            for _ in pairs(ctx.spawn_replacements) do return end
            local check=state.theme==THEME.JUNGLE and "CHECK_MOON_CHALLENGE_JUNGLE" or "CHECK_MOON_CHALLENGE_VOLCANA"
            local bow_uid=entity.uid
            -- The game finishes setting up the Bow after this callback. Delay
            -- one frame, then move it to limbo (not merely the back layer) so
            -- it remains a valid entity for Tun but cannot be seen or picked.
            ctx.defer(1,"Moon Challenge Bow handoff",function()
                local bow=get_entity(bow_uid)
                if not bow then
                    ctx.log("Moon Challenge Bow uid "..bow_uid.." disappeared before it could be hidden")
                    return
                end
                -- A carried Bow can be reconstructed while entering the
                -- challenge. After one frame it is attached to its player;
                -- it is not the native reward Bow and must remain untouched.
                for _,player in ipairs(players or {}) do
                    if entity_has_item_uid(player.uid,bow_uid) then
                        ctx.log("Moon Challenge ignored player-carried Bow uid "..bow_uid)
                        return
                    end
                end
                local x,y,layer=bow.x,bow.y,bow.layer
                remove_moon_arrows(ctx,bow,x,y,layer)
                bow:remove()
                ctx.moon_hidden_bows[bow_uid]=true
                ctx.moon_handoff_spawning=true
                -- The Moon Challenge reward is safely contained in Tun's
                -- challenge room. Keep an Eggplant at this native reward
                -- position instead of forcing it into a player's hands.
                materialize(ctx,check,x,y,layer,nil,false,false)
                ctx.moon_handoff_spawning=false
                ctx.log("Moon Challenge native Bow moved to limbo; mapped reward placed at its location (uid "..bow_uid..")")
            end)
        end,SPAWN_TYPE.ANY,MASK.ITEM,bow_type)
    else
        ctx.log("Moon Challenge deferred adapter unavailable: ITEM_HOUYIBOW is missing")
    end

    -- Keep Humphead's required Hired Hand untouched, then replace the Present
    -- the native death sequence emits. Doing this after the Present exists
    -- preserves every script reference used by the boss's death animation.
    if present_type then
        set_post_entity_spawn(function(entity)
            local pending=ctx.pending_humphead_present
            if entity.type.id~=present_type or state.theme~=THEME.TIDE_POOL or not pending or entity.layer~=pending.layer then return end
            if math.abs(entity.x-pending.x)+math.abs(entity.y-pending.y)>12 then return end
            ctx.pending_humphead_present=nil
            local present_uid=entity.uid
            local x,y,layer=entity.x,entity.y,entity.layer
            ctx.defer(1,"Humphead Present replacement",function()
                -- Humphead's reward is contained underwater, which is a safe
                -- anchor for Eggplant rather than a volatile death drop.
                materialize(ctx,"CHECK_HUMPHEAD",x,y,layer,present_uid,true,false)
                ctx.log("Humphead native Present replaced (uid "..present_uid..")")
            end)
        end,SPAWN_TYPE.ANY,MASK.ITEM,present_type)
    end

    -- Do not use DROP.CHALLENGESUN_PLAYERBAG here. The native Sun Challenge
    -- applies Player Bag-specific texture logic to its output, which is unsafe
    -- when a direct DROP replacement changes it into an arbitrary reward.
    -- Let that setup finish, then replace the exact newly emitted bag.
    local sun_playerbag_type=placements.type_of("ITEM_PICKUP_PLAYERBAG")
    if sun_playerbag_type then
        set_post_entity_spawn(function(entity)
            if entity.type.id~=sun_playerbag_type or state.theme~=THEME.SUNKEN_CITY or ctx.randomizer_state.level_materialized.CHECK_SUN_CHALLENGE_SUPPLIES then return end
            if ctx.sun_challenge_bags and ctx.sun_challenge_bags[entity.uid] then return end
            local sun_challenge=state.logic and state.logic.tun_sun_challenge
            if not sun_challenge then return end
            local uid,x,y,layer=entity.uid,entity.x,entity.y,entity.layer
            ctx.sun_challenge_bags=ctx.sun_challenge_bags or {}
            ctx.sun_challenge_bags[uid]=true
            ctx.defer(1,"Sun Challenge supplies Player Bag replacement",function()
                if ctx.randomizer_state.level_materialized.CHECK_SUN_CHALLENGE_SUPPLIES then return end
                local replacement_uid=materialize(ctx,"CHECK_SUN_CHALLENGE_SUPPLIES",x,y,layer,uid,true)
                ctx.log("Sun Challenge supplies Player Bag replaced after native setup (uid "..tostring(replacement_uid)..")")
            end)
        end,SPAWN_TYPE.ANY,MASK.ITEM,sun_playerbag_type)
    else
        ctx.log("Sun Challenge supplies adapter unavailable: ITEM_PICKUP_PLAYERBAG is missing")
    end

    -- The game increments won_prizes_count before spawning the associated
    -- prize. Wait for five so only Tusk's fifth successful seven is replaced;
    -- the first four prizes remain vanilla.
    set_pre_entity_spawn(function(entity_type,x,y,layer)
        if state.theme~=THEME.TIDE_POOL or ctx.randomizer_state.level_materialized.CHECK_TUSK_DICE_HOUSE then return nil end
        local dice=state.logic and state.logic.diceshop
        if not dice or dice.won_prizes_count~=5 or not dice.prize_dispenser or dice.prize_dispenser<0 then return nil end
        local dispenser=get_entity(dice.prize_dispenser)
        if not dispenser or dispenser.layer~=layer or math.abs(dispenser.x-x)+math.abs(dispenser.y-y)>3 then return nil end
        local reward=placements.reward_type(ctx.randomizer_state,"CHECK_TUSK_DICE_HOUSE")
        return replace_native_spawn(ctx,"CHECK_TUSK_DICE_HOUSE",reward,x,y,layer,true)
    end,SPAWN_TYPE.ANY,MASK.ITEM)

    -- `kali_gifts` changes only after Kali awards a gift. The first normal
    -- gift is not a fixed drop type, so replace the newly generated item at
    -- the nearest altar one frame later. Kapala itself uses DROP.ALTAR_KAPALA.
    set_callback(function()
        -- This confirms the generated source exists before its pre-destroy
        -- hook is expected to replace the native sacrifice payload.
        for _,uid in ipairs(present_type and get_entities_by_type(present_type) or {}) do
            local present=get_entity(uid)
            if present then
                if uid==ctx.kali_present_source_uid and not ctx.kali_present_source_seen then
                    ctx.kali_present_source_seen=true
                    ctx.log("Kali Present source uid "..uid.." is now being tracked")
                end
            end
        end
        local gifts=state.kali_gifts or 0
        local current_items={}
        for _,uid in ipairs(get_entities_by(0,MASK.ITEM,LAYER.BOTH)) do current_items[uid]=true end
        if ctx.kali_last_gifts==nil then
            ctx.kali_last_gifts=gifts
            ctx.kali_known_items=current_items
            return
        end
        if gifts>ctx.kali_last_gifts then
            ctx.log(string.format("Kali gift counter changed: %s -> %s (Present pending=%s completed=%s)",tostring(ctx.kali_last_gifts),tostring(gifts),tostring(ctx.kali_present_sacrifice_pending),tostring(ctx.kali_present_completed)))
            -- The Present check is independent of normal Kali favor. A
            -- counter change only tells us to inspect for a native altar
            -- reward; if this was a Present-only event, the scan finds none
            -- and the first normal altar check remains available.
            if not ctx.kali_first_gift_completed then
                local items_before=ctx.kali_known_items or {}
                if ctx.kali_present_sacrifice_pending then
                    ctx.log("Kali normal gift occurred while the Present replacement was pending; resolving both rewards separately")
                end
                ctx.log("Kali first-gift replacement scheduled with "..tostring(next(items_before) and "a prior item snapshot" or "an empty prior item snapshot"))
                ctx.defer(1,"Kali first-gift replacement",function() replace_first_kali_gift(ctx,items_before) end)
            end
            if ctx.kali_last_gifts<3 and gifts>=3 then
                -- Kapala is a direct DROP replacement, so its native reward
                -- has already been substituted by the time kali_gifts moves
                -- past the threshold. Disable that substitution next level.
                ctx.kali_second_gift_completed=true
                ctx.log("Kali Kapala check completed; direct replacement disarmed for the rest of this run")
            end
            ctx.kali_last_gifts=gifts
        end
        ctx.kali_known_items=current_items
    end,ON.FRAME)

    -- Lahamu may be removed by its level logic rather than a standard kill.
    -- Watch the real entity each frame, retain its last known position, and
    -- add the check reward only after it has died or disappeared.
    set_callback(function()
        if ctx.randomizer_state.level_materialized.CHECK_LAHAMU then return end
        for uid,watch in pairs(ctx.lahamu_hooks or {}) do
            if state.world==watch.world and state.level==watch.level and state.theme==watch.theme then
                local lahamu=get_entity(uid)
                if lahamu then
                    watch.x,watch.y,watch.layer=lahamu.x,lahamu.y,lahamu.layer
                    if lahamu.health and lahamu.health<=0 then
                        queue_lahamu_reward(ctx,uid,watch,"zero-health watcher")
                    end
                else
                    queue_lahamu_reward(ctx,uid,watch,"disappearance watcher")
                end
            end
        end
    end,ON.FRAME)
end

return M
