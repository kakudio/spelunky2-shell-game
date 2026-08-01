-- Shared adapters used by check-specific gameplay wiring.

local placements=require "placements"
local policy=require "replacement_policy"
local M={}

-- Reward-specific delivery belongs here rather than in individual checks.
-- `safe_delivery=false` is used for shop slots, where immediate pickup would
-- bypass the base-game purchase gate.
local DELIVERY_POLICIES={REWARD_EGGPLANT="player_hand"}

local function prepare_delivery(reward, x, y, layer, safe_delivery)
    if safe_delivery==false or DELIVERY_POLICIES[reward]~="player_hand" then return x,y,layer,nil end
    local player=players and players[1] or nil
    if not player then return x,y,layer,nil end
    return player.x,player.y,player.layer,player
end
local function finish_delivery(ctx, reward, player, uid, check)
    if DELIVERY_POLICIES[reward]=="player_hand" and player and uid then
        pick_up(player.uid,uid)
        ctx.log("Safely delivered "..reward.." for "..check.." to player uid "..player.uid)
    end
end

function M.materialize(ctx, check, x, y, layer, source_uid, snap)
    local allowed,reason=policy.can_replace_source(source_uid,players or {},entity_has_item_uid)
    if not allowed then
        ctx.log("Ignored "..reason.." source uid "..source_uid.." for "..check)
        return nil
    end
    local reward=ctx.randomizer_state.mapping and ctx.randomizer_state.mapping[check]
    local delivery_player
    x,y,layer,delivery_player=prepare_delivery(reward,x,y,layer,true)
    if delivery_player then snap=false end
    -- Spawn callbacks are synchronous. Mark this short window so a mapped
    -- reward (for example, a Clone Gun from Excalibur's stone) cannot be
    -- mistaken for another check's native reward.
    ctx.materializing=true
    local spawned_uid=placements.materialize(ctx.randomizer_state,ctx.log,check,x,y,layer,source_uid,snap)
    ctx.materializing=false
    finish_delivery(ctx,reward,delivery_player,spawned_uid,check)
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
    local delivery_player
    x,y,layer,delivery_player=prepare_delivery(reward,x,y,layer,safe_delivery)
    ctx.spawn_replacements[check]=true
    ctx.randomizer_state.level_materialized[check]=true
    ctx.log("CHECK "..check.." -> "..reward.." (native reward spawn hook)")
    local uid=spawn_entity(ent_type,x,y,layer,0,0)
    ctx.spawn_replacements[check]=nil
    finish_delivery(ctx,reward,delivery_player,uid,check)
    return uid
end

return M
