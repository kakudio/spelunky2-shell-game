-- Shared adapters used by check-specific gameplay wiring.

local placements=require "placements"
local policy=require "replacement_policy"
local M={}

local function liquid_directly_below(x,y,layer)
    if not get_liquids_at then return false end
    local ok,water,lava=pcall(get_liquids_at,x,y-1,layer)
    return ok and ((water or 0)>0 or (lava or 0)>0)
end

local function ground_below(x,y,layer)
    if not get_grid_entity_at then return nil end
    -- Grid coordinates use tile centres. Start with the tile directly below
    -- the source, then find the first actual block below it.
    for ground_y=math.floor(y-0.5),0,-1 do
        local uid=get_grid_entity_at(x,ground_y,layer)
        if uid and uid~=-1 then return ground_y end
    end
    return nil
end

local function spawn_reward(ctx,reward,ent_type,x,y,layer,snap_to_floor)
    if reward~="REWARD_EGGPLANT" then return placements.spawn(ent_type,x,y,layer,snap_to_floor) end

    -- Eggplant must not take a small spawn fall, which breaks it. Make its
    -- behavior global, rather than depending on individual check adapters.
    -- Liquids directly under the source are the deliberate exception: retain
    -- the normal fall so water/lava can consume it just like other items.
    if liquid_directly_below(x,y,layer) then
        ctx.log("Eggplant spawn above liquid; leaving it unsnapped at its source")
        return placements.spawn(ent_type,x,y,layer,false)
    end
    local ground_y=ground_below(x,y,layer)
    if ground_y then
        ctx.log(string.format("Eggplant snapped to ground below source at %.1f, %.1f",x,ground_y+1))
        return placements.spawn(ent_type,x,ground_y+1,layer,true)
    end
    ctx.log("Eggplant spawn found no ground below source; leaving it unsnapped")
    return placements.spawn(ent_type,x,y,layer,false)
end

function M.materialize(ctx, check, x, y, layer, source_uid, snap, safe_delivery)
    if ctx.randomizer_state.level_materialized[check] then return false end
    local allowed,reason=policy.can_replace_source(source_uid,players or {},entity_has_item_uid)
    if not allowed then
        ctx.log("Ignored "..reason.." source uid "..source_uid.." for "..check)
        return nil
    end
    local reward=ctx.randomizer_state.mapping and ctx.randomizer_state.mapping[check]
    -- Spawn callbacks are synchronous. Mark this short window so a mapped
    -- reward (for example, a Clone Gun from Excalibur's stone) cannot be
    -- mistaken for another check's native reward.
    ctx.materializing=true
    local spawned_uid
    if reward=="REWARD_EGGPLANT" then
        -- Keep source destruction and materialization bookkeeping in one
        -- place, but use the global Eggplant ground/liquid placement rule.
        if source_uid then local source=get_entity(source_uid); if source then source:destroy() end end
        spawned_uid=spawn_reward(ctx,reward,placements.type_of("ITEM_EGGPLANT"),x,y,layer,snap)
        ctx.randomizer_state.level_materialized[check]=true
        ctx.log(string.format("CHECK %s -> %s at %.1f, %.1f layer %s",check,reward,x,y,tostring(layer)))
    else
        spawned_uid=placements.materialize(ctx.randomizer_state,ctx.log,check,x,y,layer,source_uid,snap)
    end
    ctx.materializing=false
    if spawned_uid then ctx.lifecycle:mark(check,"materialized") end
    local flag=reward=="REWARD_CROWN" and "crown" or reward=="REWARD_HEDJET" and "hedjet" or nil
    if spawned_uid and flag then
        ctx.progression.pending_gate_items[spawned_uid]=flag
        ctx.log("Tracking "..flag.." pickup for Excalibur progression (uid "..spawned_uid..")")
    end
    return spawned_uid
end

function M.replace_native_spawn(ctx,check,reward,x,y,layer,safe_delivery)
    if ctx.materializing then return nil end
    if ctx.spawn_replacements[check] then return nil end
    local _,ent_type=placements.reward_type(ctx.randomizer_state,check)
    if not ent_type then return nil end
    ctx.spawn_replacements[check]=true
    ctx.randomizer_state.level_materialized[check]=true
    ctx.log("CHECK "..check.." -> "..reward.." (native reward spawn hook)")
    local uid=spawn_reward(ctx,reward,ent_type,x,y,layer,false)
    ctx.spawn_replacements[check]=nil
    placements.configure_reward(uid,reward)
    if uid then ctx.lifecycle:mark(check,"materialized") end
    return uid
end

return M
