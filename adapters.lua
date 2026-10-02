-- Shared adapters used by check-specific gameplay wiring.

local placements=require "placements"
local policy=require "replacement_policy"
local M={}

local function spawn_reward(ctx,reward,ent_type,x,y,layer,snap_to_floor)
    if reward~="REWARD_EGGPLANT" then return placements.spawn(ent_type,x,y,layer,snap_to_floor) end
    -- A Present safely carries the fragile Eggplant through every delivery
    -- path, including native boss drops that apply their own toss physics.
    local present_type=placements.type_of("ITEM_PRESENT")
    local eggplant_type=placements.type_of("ITEM_EGGPLANT")
    if not (present_type and eggplant_type) then
        ctx.log("Eggplant Present adapter unavailable; spawning a direct Eggplant")
        return placements.spawn(ent_type,x,y,layer,snap_to_floor)
    end
    local uid=placements.spawn(present_type,x,y,layer,snap_to_floor)
    local present=uid and get_entity(uid) or nil
    if present then
        present.inside=eggplant_type
        ctx.log(string.format("Eggplant reward spawned as Present uid %d at %.2f, %.2f layer %s",uid,present.x,present.y,tostring(present.layer)))
    end
    return uid
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
        -- place, but deliver it in a Present rather than as a fragile drop.
        if source_uid then local source=get_entity(source_uid); if source then source:destroy() end end
        spawned_uid=spawn_reward(ctx,reward,placements.type_of("ITEM_EGGPLANT"),x,y,layer,snap)
        ctx.randomizer_state.level_materialized[check]=true
        ctx.log(string.format("CHECK %s -> %s at %.1f, %.1f layer %s",check,reward,x,y,tostring(layer)))
    else
        spawned_uid=placements.materialize(ctx.randomizer_state,ctx.log,check,x,y,layer,source_uid,snap)
    end
    ctx.materializing=false
    if spawned_uid then
        ctx.placed_rewards[spawned_uid]=true
        ctx.lifecycle:mark(check,"materialized")
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
    if uid then
        ctx.placed_rewards[uid]=true
        ctx.lifecycle:mark(check,"materialized")
    end
    return uid
end

return M
