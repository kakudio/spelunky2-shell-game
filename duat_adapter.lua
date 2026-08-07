-- City of Gold -> Duat item/check handoff.

local placements=require "placements"
local M={}

local BACK={"ITEM_CAPE","ITEM_VLADS_CAPE","ITEM_JETPACK","ITEM_HOVERPACK","ITEM_POWERPACK","ITEM_TELEPORTER_BACKPACK"}
-- Only durable tools and the Eggplant are recovered when deliberately placed
-- near the City of Gold altar. Quest items and ordinary collectibles remain
-- excluded so this does not become general loose-item transport into Duat.
local NEAR={"ITEM_EXCALIBUR","ITEM_SCEPTER","ITEM_HOUYIBOW","ITEM_LIGHT_ARROW","ITEM_PLASMACANNON","ITEM_CLONEGUN","ITEM_TELEPORTER","ITEM_MATTOCK","ITEM_SHOTGUN","ITEM_FREEZERAY","ITEM_WEBGUN","ITEM_CAMERA","ITEM_CROSSBOW","ITEM_MACHETE","ITEM_BOOMERANG","ITEM_EGGPLANT"}

local function recovery_enabled(ctx)
    return not ctx.is_kali_item_recovery_enabled or ctx.is_kali_item_recovery_enabled()
end
local function favor_rewards_enabled(ctx)
    return not ctx.is_balanced_duat_kali_rewards_enabled or ctx.is_balanced_duat_kali_rewards_enabled()
end
local function name_of(t) local ok,name=pcall(get_entity_name,t,true); return ok and name or tostring(t) end
local function duat_altar()
    local t=placements.type_of("FLOOR_DUAT_ALTAR")
    local uid=t and get_entities_by_type(t)[1] or nil
    return uid and get_entity(uid) or nil
end

-- The Duat altar has three native favor rewards (cooked turkey, Bomb Bag, and
-- Bomb Box). The current Kali favor determines the tier, so repeated top-tier
-- rewards scale consistently even if the altar state is restored or recreated.
local function register_favor_rewards(ctx)
    local turkey=placements.type_of("ITEM_PICKUP_COOKEDTURKEY")
    local bomb_bag=placements.type_of("ITEM_PICKUP_BOMBBAG")
    local bomb_box=placements.type_of("ITEM_PICKUP_BOMBBOX")
    local player_bag=placements.type_of("ITEM_PICKUP_PLAYERBAG")
    local jelly=placements.type_of("ITEM_PICKUP_ROYALJELLY")
    if not (turkey and bomb_bag and bomb_box and player_bag and jelly) then
        ctx.log("Duat altar favor replacement unavailable: a required item type was not found")
        return
    end

    local tiers={
        [turkey]={level=1,bombs=5,ropes=5,jellies=0},
        [bomb_bag]={level=2,bombs=10,ropes=10,jellies=0},
    }

    local function spawn_player_bag(x,y,layer,bombs,ropes)
        local uid=spawn_entity_nonreplaceable(player_bag,x,y,layer,0,0)
        local entity=uid and get_entity(uid) or nil
        local bag=entity and entity:as_playerbag() or nil
        if bag then bag.bombs=bombs; bag.ropes=ropes end
        return uid
    end

    set_pre_entity_spawn(function(entity_type,x,y,layer)
        if not favor_rewards_enabled(ctx) then return nil end
        local rewards=tiers[entity_type]
        if (not rewards and entity_type~=bomb_box) or state.theme~=THEME.DUAT then return nil end
        local altar=duat_altar()
        -- Native Duat altar rewards emerge immediately above the special altar.
        -- The proximity check prevents ordinary turkeys/bags/boxes in Duat from
        -- being transformed.
        if not altar or altar.layer~=layer or math.abs(x-altar.x)>2 or math.abs(y-(altar.y+1))>2 then return nil end

        if entity_type==bomb_box then
            local favor_tier=math.floor((state.kali_favor or 0)/8)
            local jelly_count=math.max(1,favor_tier-2)
            rewards={level=math.max(3,favor_tier),bombs=10,ropes=10,jellies=jelly_count}
        end

        local replacement_uid=spawn_player_bag(x,y,layer,rewards.bombs,rewards.ropes)
        for index=1,rewards.jellies do
            spawn_entity_nonreplaceable(jelly,x+index*0.65,y,layer,0,0)
        end
        local contents=string.format("Player Bag (%d ropes, %d bombs)",rewards.ropes,rewards.bombs)
        if rewards.jellies>0 then contents=contents..", "..rewards.jellies.." Royal Jelly" end
        ctx.log("Duat altar favor level "..rewards.level.." (Kali favor "..tostring(state.kali_favor or 0)..") granted "..contents)
        return replacement_uid
    end,SPAWN_TYPE.ANY,MASK.ITEM)
end
local function held(uid)
    for _,player in ipairs(players or {}) do if entity_has_item_uid(player.uid,uid) then return true end end
    return false
end
local function allowed(ctx,t)
    if not ctx.duat_recovery_altar_types then
        local types={}
        for _,list in ipairs({BACK,NEAR}) do for _,entry in ipairs(list) do local id=placements.type_of(entry); if id then types[id]=true end end end
        ctx.duat_recovery_altar_types=types
    end
    return ctx.duat_recovery_altar_types[t] or false
end

local function scan_altar_items(ctx)
    local recovered={}
    local altar_type=placements.type_of("FLOOR_ALTAR"); local seen={}
    for _,altar_uid in ipairs(altar_type and get_entities_by_type(altar_type) or {}) do
        local altar=get_entity(altar_uid)
        if altar then for _,uid in ipairs(get_entities_by(0,MASK.ITEM,LAYER.BOTH)) do
            local item=get_entity(uid)
            -- Capture a 9-by-1.5-tile band immediately above the altar. This
            -- gives dropped items room to settle or bounce without preserving
            -- items that were only briefly in the altar area.
            if not seen[uid] and item and item.type and allowed(ctx,item.type.id) and item.layer==altar.layer and not held(uid)
                and math.abs(item.x-altar.x)<=4.5 and math.abs(item.y-(altar.y+1))<=0.75 then
                seen[uid]=true; table.insert(recovered,{type=item.type.id,kind="near Kali altar",player=0,uid=uid})
            end
        end end
    end
    return recovered
end

local function labels_for(items)
    local labels={}
    for _,item in ipairs(items) do
        table.insert(labels,string.format("%s (type %s, uid %s)",name_of(item.type),tostring(item.type),tostring(item.uid)))
    end
    return labels
end

local function scan_signature(items)
    local entries={}
    for _,item in ipairs(items) do table.insert(entries,tostring(item.uid)..":"..tostring(item.type)) end
    table.sort(entries)
    return table.concat(entries,";")
end

local function tracked_item_statuses(ctx,recovered)
    ctx.duat_recovery_seen_items=ctx.duat_recovery_seen_items or {}
    local eligible={}
    for _,item in ipairs(recovered) do
        ctx.duat_recovery_seen_items[item.uid]={type=item.type,uid=item.uid}
        eligible[item.uid]=true
    end
    local uids={}
    for uid in pairs(ctx.duat_recovery_seen_items) do table.insert(uids,uid) end
    table.sort(uids)
    local statuses={}
    for _,uid in ipairs(uids) do
        local tracked=ctx.duat_recovery_seen_items[uid]
        local item=get_entity(uid)
        if item then
            table.insert(statuses,string.format("%s uid %s at %.1f, %.1f layer %s held=%s eligible=%s",name_of(tracked.type),tostring(uid),item.x,item.y,tostring(item.layer),tostring(held(uid)),tostring(eligible[uid] or false)))
        else
            table.insert(statuses,string.format("%s uid %s no longer exists eligible=false",name_of(tracked.type),tostring(uid)))
        end
    end
    return statuses
end

local function log_altar_scan_changes(ctx)
    if not recovery_enabled(ctx) or state.theme~=THEME.CITY_OF_GOLD then return end
    local recovered=scan_altar_items(ctx)
    local signature=scan_signature(recovered)
    if ctx.duat_recovery_scan_signature==signature then return end
    ctx.duat_recovery_scan_signature=signature
    -- This is the authoritative snapshot.  A later scan replaces it when an
    -- item is picked up or leaves the altar band, so it cannot accumulate
    -- stale items.  Do not rescan at ON.TRANSITION: the game removes altar
    -- items as part of that transition before the callback runs.
    ctx.duat_recovery=recovered
    ctx.duat_recovery_empty_logged=#recovered==0
    local labels=labels_for(recovered)
    local statuses=tracked_item_statuses(ctx,recovered)
    local detail=#statuses>0 and "; tracked items: "..table.concat(statuses,"; ") or ""
    ctx.log((#labels>0 and "Duat recovery altar scan changed; cached snapshot: "..table.concat(labels,"; ") or "Duat recovery altar scan changed; cached snapshot is empty")..detail)
end

local function restore_items(ctx)
    if not recovery_enabled(ctx) then ctx.duat_recovery=nil; return end
    if state.theme~=THEME.DUAT or ctx.duat_recovery_spawned then return end
    ctx.duat_recovery_spawned=true; local recovered=ctx.duat_recovery
    if not recovered or #recovered==0 then ctx.log("Duat item recovery reached Duat: no captured items to restore"); return end
    local altar=duat_altar()
    if not altar then ctx.log("Duat item recovery found no FLOOR_DUAT_ALTAR; leaving snapshot pending"); ctx.duat_recovery_spawned=false; return end
    ctx.log("Duat item recovery reached Duat with "..#recovered.." captured item(s); searching for the Duat altar")
    for index,item in ipairs(recovered) do
        local uid=spawn_entity_snapped_to_floor(item.type,altar.x+(index-1)*0.65,altar.y+1,altar.layer)
        ctx.log(string.format("Duat recovery restored P%d %s %s (type %s) at Duat altar (uid %s)",item.player or 0,item.kind,name_of(item.type),tostring(item.type),tostring(uid)))
    end
    ctx.duat_recovery=nil
end

function M.register(ctx)
    register_favor_rewards(ctx)
    set_callback(function()
        if state.theme==THEME.CITY_OF_GOLD and state.theme_next==THEME.DUAT then
            local recovered=ctx.duat_recovery or {}
            local labels=labels_for(recovered)
            local statuses=tracked_item_statuses(ctx,recovered)
            local detail=#statuses>0 and "; tracked items: "..table.concat(statuses,"; ") or ""
            ctx.log((#labels>0 and "Duat recovery ON.TRANSITION at frame "..tostring(get_frame and get_frame() or -1).."; preserving cached altar snapshot: "..table.concat(labels,"; ") or "Duat recovery ON.TRANSITION at frame "..tostring(get_frame and get_frame() or -1).."; cached altar snapshot is empty")..detail)
        end
    end,ON.TRANSITION)
    set_callback(function() log_altar_scan_changes(ctx) end,ON.FRAME)
end
function M.on_post_level_generation(ctx)
    if state.theme==THEME.DUAT then restore_items(ctx)
    elseif state.theme~=THEME.CITY_OF_GOLD then ctx.duat_recovery=nil end
end
return M
