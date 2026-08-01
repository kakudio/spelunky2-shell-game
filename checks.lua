-- Check-specific gameplay adapters. Add special quest logic here, not in main.lua.

local placements=require "placements"
local adapters=require "adapters"
local logic=require "logic"
local M={}
local materialize=adapters.materialize
local replace_native_spawn=adapters.replace_native_spawn

local ITEM_ANCHORS={
    -- Black Market's Hedjet must be substituted at spawn so the game keeps it
    -- as a shop item. Restrict that hook to an active shop room: Sparrow can
    -- legitimately produce a Hedjet elsewhere in Jungle.
    {source="ITEM_PICKUP_HEDJET",check="CHECK_BLACK_MARKET",theme=THEME.JUNGLE,shop_only=true,post_generation=false},
    -- The Crown is embedded in Vlad's Castle statue.  Replacing it before the
    -- room finishes initializing can leave certain items (notably Player Bag)
    -- inside the statue, so replace it after generation and snap to ground.
    {source="ITEM_PICKUP_CROWN",check="CHECK_VLADS_CASTLE",theme=THEME.VOLCANA,pre_spawn=false,snap=true,absolute=true,layer=LAYER.BACK},
    {source="ITEM_VLADS_CAPE",check="CHECK_VLAD",theme=THEME.VOLCANA},
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
    -- The post-generation scan handles the former; the same tightly scoped
    -- pre-spawn hook handles the latter at the moment Sparrow grants it.
    -- Ordinary Royal Jelly and Player Bags remain untouched elsewhere.
    {source="ITEM_PICKUP_ROYALJELLY",check="CHECK_TUSK_PALACE_VISIT",theme=THEME.NEO_BABYLON,level=3,layer=LAYER.BACK,snap=true},
    {source="ITEM_PICKUP_PLAYERBAG",check="CHECK_SPARROW_VAULT",theme=THEME.NEO_BABYLON,level=3,layer=LAYER.BACK,snap=true},
}
local NPC_ANCHORS={
    {source="MONS_YANG",check="CHECK_YANG",theme=THEME.DWELLING,layer=LAYER.BACK,snap=true},
    {source="MONS_TIAMAT",check="CHECK_TIAMAT",theme=THEME.TIAMAT},
}
-- Fixed engine DROP substitutions share one lifecycle. Theme-scoped entries
-- are cleared when leaving their theme; global quest entries remain armed but
-- only fire when the base game emits that exact DROP.
local DROP_CONFIGS={
    {drop=DROP.KINGU_TABLETOFDESTINY,check="CHECK_KINGU",theme=THEME.ABZU,label="Kingu Tablet"},
    {drop=DROP.OLMEC_SISTERS_BOMBBOX,check="CHECK_SISTERS_OLMEC_REWARD",theme=THEME.OLMEC,label="Sisters Bomb Box"},
    {drop=DROP.OSIRIS_TABLETOFDESTINY,check="CHECK_OSIRIS",theme=THEME.DUAT,label="Osiris Tablet"},
    {drop=DROP.VAN_HORSING_COMPASS,check="CHECK_ALIEN_COMPASS",theme=THEME.TEMPLE,label="Van Alien Compass"},
    {drop=DROP.SPARROW_ROPEPILE,check="CHECK_SPARROW",label="Sparrow Rope Pile"},
    {drop=DROP.BEG_BOMBBAG,check="CHECK_BEG_FIRST_MEETING",label="Beg Bomb Bag"},
    {drop=DROP.BEG_TRUECROWN,check="CHECK_BEG_TRUE_CROWN",label="Beg True Crown"},
    {drop=DROP.ALTAR_KAPALA,check="CHECK_KALI_ALTAR_2",label="Kali Kapala"},
}
local YANG_DOOR_TYPES={"BG_DOOR_BACK_LAYER","FLOOR_DOOR_ENTRANCE","FLOOR_DOOR_EXIT","FLOOR_DOOR_LAYER","FLOOR_DOOR_LOCKED"}

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
    set_timeout(function()
        for _,uid in ipairs(get_entities_by_type(metal_arrow_type)) do
            local item=get_entity(uid)
            if item and item.layer==layer and math.abs(item.x-x)+math.abs(item.y-y)<=4 then
                item:destroy()
                ctx.log("Removed Moon Challenge metal arrow uid "..uid)
            end
        end
    end,1)
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
local function replace_tusk_idol_room(ctx)
    if state.theme~=THEME.TIDE_POOL or ctx.randomizer_state.level_materialized.CHECK_TUSK_IDOL then return end
    local source_type=placements.type_of("ITEM_MADAMETUSK_IDOL")
    for _,uid in ipairs(source_type and get_entities_by_type(source_type) or {}) do
        local entity=get_entity(uid)
        if entity then
            materialize(ctx,"CHECK_TUSK_IDOL",entity.abs_x,entity.abs_y,entity.layer,uid,true)
            return
        end
    end
end
local function configure_drop_substitutions(ctx)
    ctx.drop_configured=ctx.drop_configured or {}
    for _,config in ipairs(DROP_CONFIGS) do
        local active=not config.theme or state.theme==config.theme
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
    local altar_type=placements.type_of("FLOOR_ALTAR")
    local best,best_distance=nil,math.huge
    for _,uid in ipairs(altar_type and get_entities_by_type(altar_type) or {}) do
        local altar=get_entity(uid)
        if altar and altar.layer==layer then
            local distance=math.abs(altar.x-x)+math.abs(altar.y-y)
            if distance<best_distance then best,best_distance=altar,distance end
        end
    end
    return best
end
local function place_kali_present_source(ctx)
    if ctx.kali_present_source_placed or ctx.kali_present_completed then return end
    local target_group=logic.kali_present_target_group(ctx.randomizer_state.seed)
    local world=state.world or 0
    local current_group=world<=1 and 1 or world<=3 and 2 or world<=4 and 3 or world==5 and 4 or world==6 and 5 or 6
    if current_group<target_group then return end
    local altar_type=placements.type_of("FLOOR_ALTAR")
    local present_type=placements.type_of("ITEM_PRESENT")
    if not altar_type or not present_type then
        ctx.log("Kali Present source adapter unavailable: altar or Present entity is missing")
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
                local present_uid=spawn_entity_nonreplaceable(present_type,x,y,layer,0,0)
                pet:destroy()
                ctx.kali_present_source_placed=true
                ctx.kali_present_source_uid=present_uid
                ctx.kali_present_source_location={world=world,level=state.level,theme=state.theme,x=x,y=y,layer=layer}
                ctx.log(string.format("Kali Present source: group %d target met at %d-%d; replaced %s uid %d with Present uid %s at %.1f, %.1f",target_group,world,state.level,pet_name,uid,tostring(present_uid),x,y))
                return
            end
        end
    end
    ctx.log("Kali Present target group "..target_group.." has an altar but no pet; will try the next level")
end
local function replace_first_kali_gift(ctx,existing_items)
    local player=players and players[1]
    if not player then return end
    local altar=nearest_kali_altar(player.x,player.y,player.layer)
    if not altar then ctx.log("Kali first-gift check could not find an altar") return end
    local candidate,candidate_distance=nil,math.huge
    for _,uid in ipairs(get_entities_by(0,MASK.ITEM,LAYER.BOTH)) do
        local item=get_entity(uid)
        if item and not existing_items[uid] and item.layer==altar.layer then
            local distance=math.abs(item.x-altar.x)+math.abs(item.y-altar.y)
            if distance<=3 and distance<candidate_distance then candidate,candidate_distance=item,distance end
        end
    end
    if candidate then
        local expected=ctx.randomizer_state.mapping and ctx.randomizer_state.mapping.CHECK_KALI_ALTAR_1
        ctx.log(string.format("Kali first-gift candidate uid %d type %d at %.1f, %.1f; mapped reward %s",candidate.uid,candidate.type.id,candidate.x,candidate.y,tostring(expected)))
        local replacement_uid=materialize(ctx,"CHECK_KALI_ALTAR_1",candidate.x,candidate.y,candidate.layer,candidate.uid,true)
        ctx.log("Kali first-gift replacement result uid "..tostring(replacement_uid))
    else
        ctx.log("Kali first-gift check found no generated reward item near altar")
    end
end
local function yang_position(ctx, yang)
    local best,best_name,best_distance,best_priority=nil,nil,math.huge,math.huge
    ctx.log(string.format("Yang is at %.1f, %.1f layer %s; scanning candidate doors",yang.x,yang.y,tostring(yang.layer)))
    for _,name in ipairs(YANG_DOOR_TYPES) do
        local kind=placements.type_of(name)
        if kind then
            for _,uid in ipairs(get_entities_by_type(kind)) do
                local door=get_entity(uid)
                if door then
                    local distance=math.abs(door.x-yang.x)+math.abs(door.y-yang.y)
                    -- Door subclasses differ; query the lock flag defensively
                    -- so ordinary background doors remain valid candidates.
                    local lock_flag=nil
                    local ok,value=pcall(function() return door.unlocked end)
                    if ok and type(value)=="boolean" then lock_flag=not value end
                    local lock_text=lock_flag==nil and "unknown" or lock_flag and "locked" or "unlocked"
                    ctx.log(string.format("Yang door candidate %s uid %d at %.1f, %.1f layer %s distance %.1f %s",name,uid,door.x,door.y,tostring(door.layer),distance,lock_text))
                    -- Yang's treasure-room door is always below him (smaller
                    -- world Y). `FLOOR_DOOR_ENTRANCE` can sit just as close,
                    -- but is above him. Prefer a lower actual background
                    -- door, then another lower back-layer door; all others
                    -- are fallback-only if a generated layout is unusual.
                    local below_yang=door.y<yang.y
                    -- The treasure door begins locked. A confirmed locked
                    -- door wins before all spatial tie-breakers.
                    local lock_priority=lock_flag and 0 or 10
                    local door_priority=below_yang and name=="BG_DOOR_BACK_LAYER" and 1 or below_yang and door.layer==LAYER.BACK and 2 or 3
                    local priority=lock_priority+door_priority
                    if priority<best_priority or (priority==best_priority and distance<best_distance) then
                        best,best_name,best_distance,best_priority=door,name,distance,priority
                    end
                end
            end
        end
    end
    if best and best_distance<=12 then
        local direction=best.x>=yang.x and 1 or -1
        ctx.log(string.format("Yang reward anchor uses %s at %.1f, %.1f (priority %d)",best_name,best.x,best.y,best_priority))
        return best.x+direction,best.y,LAYER.BACK
    end
    ctx.log("Yang reward anchor did not find a nearby back-layer door; using fallback coordinate")
    return yang.x-1,yang.y,LAYER.BACK
end

-- The sword-in-stone can appear after POST_LEVEL_GENERATION, while a test
-- Crown is granted at START. Check both conditions here rather than deciding
-- while the room is still being assembled.
function M.replace_excalibur_if_gated(ctx, attempt)
    -- Excalibur's stone only exists in Tide Pool 4-2. Restricting this avoids
    -- scanning player-carried swords (and retrying) on Tide Pool 4-1/4-3.
    if state.theme~=THEME.TIDE_POOL or state.level~=2 or ctx.randomizer_state.level_materialized.CHECK_EXCALIBUR_STONE then return end
    if not (ctx.progression.crown or ctx.progression.hedjet) then
        ctx.log("Excalibur gate is closed: no collected Crown or Hedjet")
        return
    end
    local excalibur_type=placements.type_of("ITEM_EXCALIBUR")
    local swords=excalibur_type and get_entities_by_type(excalibur_type) or {}
    ctx.log(string.format("Excalibur gate is open (Crown=%s Hedjet=%s); found %d sword-in-stone entities",tostring(ctx.progression.crown),tostring(ctx.progression.hedjet),#swords))
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
        set_timeout(function() M.replace_excalibur_if_gated(ctx,attempt+1) end,5)
    else
        ctx.log("Excalibur gate stayed open but no native sword-in-stone appeared after retries")
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
            boss:set_pre_kill(function(self)
                local pending={x=self.x,y=self.y,layer=self.layer}
                ctx[pending_field]=pending
                set_timeout(function()
                    if ctx[pending_field]==pending then
                        ctx[pending_field]=nil
                        materialize(ctx,check,pending.x,pending.y,pending.layer,nil,true)
                    end
                end,2)
            end)
            ctx.log("Attached "..label.." reward hook to uid "..uid)
        end
    end
end

function M.on_post_level_generation(ctx)
    -- Present identities are level-local. Clearing them here prevents an item
    -- left on a prior level from being mistaken for a sacrifice on this one.
    ctx.kali_presents={}
    local theme=state.theme
    local items=get_entities_by(0,MASK.ITEM,LAYER.BOTH)
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
        set_timeout(function()
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
        end,20)
    end
    replace_van_reward(ctx,items)
    replace_tusk_idol_room(ctx)
    place_kali_present_source(ctx)
    if theme==THEME.TIDE_POOL then
        -- Delay beyond room construction; this also covers a Crown granted by
        -- the optional test-resources callback at ON.START.
        set_timeout(function() M.replace_excalibur_if_gated(ctx) end,10)
    end
    for _,anchor in ipairs(NPC_ANCHORS) do
        if theme==anchor.theme then
            local source_type=placements.type_of(anchor.source)
            local entities=source_type and get_entities_by_type(source_type) or {}
            local entity=entities[1] and get_entity(entities[1]) or nil
            if entity then
                local x,y,layer=entity.x-1,entity.y,anchor.layer or entity.layer
                if anchor.check=="CHECK_YANG" then x,y,layer=yang_position(ctx,entity) end
                materialize(ctx,anchor.check,x,y,layer,nil,anchor.snap)
            end
        end
    end
    if theme==THEME.DWELLING then
        attach_delayed_death_reward(ctx,"MONS_CAVEMAN_BOSS","CHECK_QUILLBACK","quillback_hooks","pending_quillback_drop","Quillback death")
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
                        set_timeout(function()
                            if ctx.pending_yeti_drops[native_drop]==pending then
                                ctx.pending_yeti_drops[native_drop]=nil
                                materialize(ctx,check,pending.x,pending.y,pending.layer,nil,true)
                            end
                        end,2)
                    end)
                    ctx.log("Attached "..check.." death-drop hook to uid "..uid)
                end
            end
        end
        attach_yeti("MONS_YETIQUEEN","CHECK_YETI_QUEEN",placements.type_of("ITEM_PICKUP_SPIKESHOES"))
        attach_yeti("MONS_YETIKING","CHECK_YETI_KING",placements.type_of("ITEM_PICKUP_COMPASS"))

        -- Lahamu has no ordinary item drop. Its death is the check, so place
        -- the mapped reward at the death position after the native sequence.
        attach_delayed_death_reward(ctx,"MONS_LAHAMU","CHECK_LAHAMU","lahamu_hooks","pending_lahamu_drop","Lahamu death")
    end
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
    -- Anubis II's Jetpack is created when he dies.  Do not use a generic
    -- Jetpack scan: Duat can contain other Jetpacks from player actions.
    if theme==THEME.DUAT then
        attach_delayed_death_reward(ctx,"MONS_ANUBIS2","CHECK_ANUBIS_II","anubis2_hooks","pending_anubis2_drop","Anubis II Jetpack")
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

function M.register_spawn_hooks(ctx)
    local present_type=placements.type_of("ITEM_PRESENT")
    -- `touch` becomes zero on a player pickup. We only track the particular
    -- Crown/Hedjet entities this randomizer materialized, so other items do
    -- not accidentally satisfy the logic gate.
    set_callback(function()
        for uid,flag in pairs(ctx.progression.pending_gate_items) do
            local item=get_entity(uid)
            if item and item.touch==0 then
                ctx.progression[flag]=true
                ctx.progression.pending_gate_items[uid]=nil
                ctx.log("Collected "..flag.."; Excalibur gate is now open")
            elseif not item then
                ctx.progression.pending_gate_items[uid]=nil
            end
        end
    end,ON.FRAME)

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

    local jetpack_type=placements.type_of("ITEM_JETPACK")
    if jetpack_type then
        set_pre_entity_spawn(function(entity_type,x,y,layer)
            local pending=ctx.pending_anubis2_drop
            if entity_type~=jetpack_type or not pending then return nil end
            ctx.pending_anubis2_drop=nil
            local reward=placements.reward_type(ctx.randomizer_state,"CHECK_ANUBIS_II")
            return replace_native_spawn(ctx,"CHECK_ANUBIS_II",reward,x,y,layer,true)
        end,SPAWN_TYPE.ANY,MASK.ITEM,jetpack_type)
    end

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
            set_timeout(function()
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
                materialize(ctx,check,x,y,layer,nil,false)
                ctx.moon_handoff_spawning=false
                ctx.log("Moon Challenge native Bow moved to limbo; mapped reward placed at its location (uid "..bow_uid..")")
            end,1)
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
            set_timeout(function()
                materialize(ctx,"CHECK_HUMPHEAD",x,y,layer,present_uid,true)
                ctx.log("Humphead native Present replaced (uid "..present_uid..")")
            end,1)
        end,SPAWN_TYPE.ANY,MASK.ITEM,present_type)
    end

    -- Tusk's fifth successful seven is the final prize. At four prizes won,
    -- substitute only an item emitted beside her prize dispenser; ordinary
    -- shop spawns and the first four prizes remain vanilla.
    set_pre_entity_spawn(function(entity_type,x,y,layer)
        if state.theme~=THEME.TIDE_POOL or ctx.randomizer_state.level_materialized.CHECK_TUSK_DICE_HOUSE then return nil end
        local dice=state.logic and state.logic.diceshop
        if not dice or dice.won_prizes_count~=4 or not dice.prize_dispenser or dice.prize_dispenser<0 then return nil end
        local dispenser=get_entity(dice.prize_dispenser)
        if not dispenser or dispenser.layer~=layer or math.abs(dispenser.x-x)+math.abs(dispenser.y-y)>3 then return nil end
        local reward=placements.reward_type(ctx.randomizer_state,"CHECK_TUSK_DICE_HOUSE")
        return replace_native_spawn(ctx,"CHECK_TUSK_DICE_HOUSE",reward,x,y,layer,true)
    end,SPAWN_TYPE.ANY,MASK.ITEM)

    -- `kali_gifts` changes only after Kali awards a gift. The first normal
    -- gift is not a fixed drop type, so replace the newly generated item at
    -- the nearest altar one frame later. Kapala itself uses DROP.ALTAR_KAPALA.
    set_callback(function()
        -- Kali does not produce a fixed native item when a Present is
        -- sacrificed. Track presents that are sitting on an altar, then place
        -- the mapped reward when that specific present is consumed.
        local current_presents={}
        for _,uid in ipairs(present_type and get_entities_by_type(present_type) or {}) do
            local present=get_entity(uid)
            if present then
                current_presents[uid]={x=present.x,y=present.y,layer=present.layer}
            end
        end
        for uid,last in pairs(ctx.kali_presents or {}) do
            if uid==ctx.kali_present_source_uid and not current_presents[uid] and not ctx.kali_present_completed and not ctx.randomizer_state.level_materialized.CHECK_KALI_PRESENT then
                local altar=nearest_kali_altar(last.x,last.y,last.layer)
                if altar and math.abs(last.x-altar.x)+math.abs(last.y-altar.y)<=2 then
                    local reward_x,reward_y,reward_layer=altar.x,altar.y,altar.layer
                    -- Sacrificing a Present can also advance kali_gifts. Mark
                    -- it before the reward spawns so the normal first-gift
                    -- adapter cannot mistake this check's reward for Kali's
                    -- separate altar-1 reward.
                    ctx.kali_present_sacrifice_pending=true
                    ctx.kali_present_source_uid=nil
                    -- A generated Present can emit its own native Eggplant
                    -- contents as it is consumed. Remove only that fragile
                    -- native item near this altar before placing the mapped
                    -- check reward; the actual mapped Eggplant, if any, is
                    -- materialized later through the safe delivery policy.
                    set_timeout(function()
                        local eggplant_type=placements.type_of("ITEM_EGGPLANT")
                        for _,eggplant_uid in ipairs(eggplant_type and get_entities_by_type(eggplant_type) or {}) do
                            local eggplant=get_entity(eggplant_uid)
                            if eggplant and eggplant.layer==reward_layer and math.abs(eggplant.x-reward_x)+math.abs(eggplant.y-reward_y)<=3 then
                                eggplant:destroy()
                                ctx.log("Removed native Eggplant content from Kali Present uid "..uid)
                            end
                        end
                    end,2)
                    set_timeout(function()
                        if not ctx.randomizer_state.level_materialized.CHECK_KALI_PRESENT then
                            -- The altar tile is occupied geometry. Snapping a
                            -- reward there can leave it hidden inside the
                            -- altar, even though the spawn call succeeds.
                            -- Place it on the sacrificing player's tile
                            -- instead, without a floor snap.
                            local player=players and players[1]
                            local spawn_x,spawn_y,spawn_layer=reward_x,reward_y,reward_layer
                            if player and player.layer==reward_layer then
                                spawn_x,spawn_y,spawn_layer=player.x,player.y,player.layer
                            end
                            local reward_uid=materialize(ctx,"CHECK_KALI_PRESENT",spawn_x,spawn_y,spawn_layer,nil,false)
                            if reward_uid then
                                ctx.kali_present_completed=true
                                ctx.log(string.format("Kali Present sacrifice detected (uid %d); reward spawned at %.1f, %.1f layer %s",uid,spawn_x,spawn_y,tostring(spawn_layer)))
                            end
                        end
                        ctx.kali_present_sacrifice_pending=false
                    end,4)
                end
            end
        end
        ctx.kali_presents=current_presents

        local gifts=state.kali_gifts or 0
        local current_items={}
        for _,uid in ipairs(get_entities_by(0,MASK.ITEM,LAYER.BOTH)) do current_items[uid]=true end
        if ctx.kali_last_gifts==nil then
            ctx.kali_last_gifts=gifts
            ctx.kali_known_items=current_items
            return
        end
        if gifts>ctx.kali_last_gifts then
            if ctx.kali_last_gifts<1 and gifts>=1 and not ctx.kali_present_sacrifice_pending then
                local items_before=ctx.kali_known_items or {}
                set_timeout(function() replace_first_kali_gift(ctx,items_before) end,1)
            elseif ctx.kali_last_gifts<1 and gifts>=1 then
                ctx.log("Kali Present sacrifice advanced kali_gifts; preserving CHECK_KALI_PRESENT reward")
            end
            ctx.kali_last_gifts=gifts
        end
        ctx.kali_known_items=current_items
    end,ON.FRAME)
end

return M
