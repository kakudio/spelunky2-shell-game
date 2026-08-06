-- City of Gold -> Duat item/check handoff.

local placements=require "placements"
local M={}

local BACK={"ITEM_CAPE","ITEM_VLADS_CAPE","ITEM_JETPACK","ITEM_HOVERPACK","ITEM_POWERPACK","ITEM_TELEPORTER_BACKPACK"}
local NEAR={"ITEM_EXCALIBUR","ITEM_SCEPTER","ITEM_HOUYIBOW","ITEM_LIGHT_ARROW","ITEM_PLASMACANNON","ITEM_CLONEGUN","ITEM_TELEPORTER","ITEM_MATTOCK","ITEM_SHOTGUN","ITEM_FREEZERAY","ITEM_WEBGUN","ITEM_CAMERA","ITEM_CROSSBOW","ITEM_MACHETE","ITEM_BOOMERANG","ITEM_MADAMETUSK_IDOL","ITEM_IDOL","ITEM_PICKUP_ELIXIR","ITEM_PICKUP_TABLETOFDESTINY","ITEM_PICKUP_UDJATEYE","ITEM_PICKUP_ANKH","ITEM_PICKUP_HEDJET","ITEM_PICKUP_CROWN","ITEM_PICKUP_SKELETON_KEY","ITEM_PICKUP_SPECIALCOMPASS","ITEM_PICKUP_COMPASS"}

local function enabled(ctx) return not ctx.is_duat_recovery_enabled or ctx.is_duat_recovery_enabled() end
local function name_of(t) local ok,name=pcall(get_entity_name,t,true); return ok and name or tostring(t) end
local function duat_altar()
    local t=placements.type_of("FLOOR_DUAT_ALTAR")
    local uid=t and get_entities_by_type(t)[1] or nil
    return uid and get_entity(uid) or nil
end

-- The Duat altar has three native favor rewards (cooked turkey, Bomb Bag, and
-- Bomb Box). The Bomb Box is the repeating top-tier event, so use it to scale
-- the Royal Jelly portion of later rewards.
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
        local rewards=tiers[entity_type]
        if (not rewards and entity_type~=bomb_box) or state.theme~=THEME.DUAT then return nil end
        local altar=duat_altar()
        -- Native Duat altar rewards emerge immediately above the special altar.
        -- The proximity check prevents ordinary turkeys/bags/boxes in Duat from
        -- being transformed.
        if not altar or altar.layer~=layer or math.abs(x-altar.x)>2 or math.abs(y-(altar.y+1))>2 then return nil end

        if entity_type==bomb_box then
            ctx.duat_altar_top_tier_count=(ctx.duat_altar_top_tier_count or 0)+1
            local jelly_count=ctx.duat_altar_top_tier_count
            rewards={level=2+jelly_count,bombs=10,ropes=10,jellies=jelly_count}
        end

        local replacement_uid=spawn_player_bag(x,y,layer,rewards.bombs,rewards.ropes)
        for index=1,rewards.jellies do
            spawn_entity_nonreplaceable(jelly,x+index*0.65,y,layer,0,0)
        end
        local contents=string.format("Player Bag (%d ropes, %d bombs)",rewards.ropes,rewards.bombs)
        if rewards.jellies>0 then contents=contents..", "..rewards.jellies.." Royal Jelly" end
        ctx.log("Duat altar favor level "..rewards.level.." granted "..contents)
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

local function snapshot(ctx)
    if not enabled(ctx) or state.theme~=THEME.CITY_OF_GOLD then return end
    local recovered={}
    for index,player in ipairs(players or {}) do
        local item=player:get_held_entity()
        if item and item.type then table.insert(recovered,{type=item.type.id,kind="held",player=index}) end
        for _,entry in ipairs(BACK) do
            local t=placements.type_of(entry)
            if t and entity_has_item_type(player.uid,t) then table.insert(recovered,{type=t,kind="back",player=index}); break end
        end
    end
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
                seen[uid]=true; table.insert(recovered,{type=item.type.id,kind="near Kali altar",player=0})
            end
        end end
    end
    local labels={}; for _,item in ipairs(recovered) do table.insert(labels,string.format("P%d %s=%s (type %s)",item.player,item.kind,name_of(item.type),tostring(item.type))) end
    local signature=table.concat(labels,"; ")
    if signature~="" and signature~=ctx.duat_recovery_signature then
        ctx.duat_recovery=recovered; ctx.duat_recovery_signature=signature; ctx.duat_recovery_empty_logged=false
        ctx.log("Duat recovery snapshot detected in City of Gold: "..signature)
    elseif signature=="" and not ctx.duat_recovery_empty_logged then
        ctx.duat_recovery_empty_logged=true
        ctx.log(ctx.duat_recovery and #ctx.duat_recovery>0 and "Duat recovery snapshot in City of Gold: no item currently detected; retaining the last non-empty snapshot for the transition" or "Duat recovery snapshot in City of Gold: no held or supported back item detected")
    end
end

local function restore_items(ctx)
    if not enabled(ctx) then ctx.duat_recovery=nil; return end
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
    set_callback(function() snapshot(ctx) end,ON.FRAME)
end
function M.on_post_level_generation(ctx)
    if state.theme==THEME.DUAT then restore_items(ctx)
    elseif state.theme~=THEME.CITY_OF_GOLD then ctx.duat_recovery=nil end
end
return M
