-- Sparrow/Tusk quest adapter: quest-state diagnostics and special reward timing.

local placements=require "placements"
local materialize=require("adapters").materialize
local M={}

local function replace_tusk_idol_room(ctx)
    if state.theme~=THEME.TIDE_POOL or state.level~=1 or ctx.randomizer_state.level_materialized.CHECK_TUSK_IDOL then return end
    local source_type=placements.type_of("ITEM_MADAMETUSK_IDOL")
    for _,uid in ipairs(source_type and get_entities_by_type(source_type) or {}) do
        local entity=get_entity(uid)
        if entity then
            materialize(ctx,"CHECK_TUSK_IDOL",entity.abs_x,entity.abs_y,entity.layer,uid,true)
            return
        end
    end
end

local function observe_hideout(ctx)
    if state.theme~=THEME.NEO_BABYLON or state.level~=1 then return end
    local sparrow_type=placements.type_of("MONS_SPARROW")
    if not sparrow_type then
        ctx.log("Sparrow 6-1 diagnostic unavailable: MONS_SPARROW entity type missing")
        return
    end
    local found={}
    for _,uid in ipairs(get_entities_by_type(sparrow_type) or {}) do
        local sparrow=get_entity(uid)
        if sparrow then table.insert(found,string.format("uid %d at %.1f, %.1f layer %s",uid,sparrow.x,sparrow.y,tostring(sparrow.layer))) end
    end
    if #found>0 then
        ctx.log("Sparrow 6-1 hideout entity detected: "..table.concat(found,"; "))
    elseif state.quests and state.quests.sparrow_state>=6 then
        ctx.log("WARNING: Sparrow quest state is "..tostring(state.quests.sparrow_state).." in 6-1, but no Sparrow entity was found")
    end
end

function M.on_post_level_generation(ctx)
    replace_tusk_idol_room(ctx)
    observe_hideout(ctx)
end

function M.register(ctx)
    set_callback(function()
        local quests=state.quests
        local sparrow_state=quests and quests.sparrow_state
        if sparrow_state==nil then return end
        if ctx.sparrow_last_state==nil then
            ctx.sparrow_last_state=sparrow_state
            ctx.log("Sparrow quest state initialized: "..tostring(sparrow_state))
        elseif ctx.sparrow_last_state~=sparrow_state then
            local previous=ctx.sparrow_last_state
            ctx.sparrow_last_state=sparrow_state
            ctx.sparrow_last_transition={from=previous,to=sparrow_state,world=state.world,level=state.level,theme=state.theme}
            ctx.log(string.format("Sparrow quest state changed: %s -> %s at %d-%d (theme %s)",tostring(previous),tostring(sparrow_state),state.world,state.level,tostring(state.theme)))
        end
    end,ON.FRAME)

    local playerbag_type=placements.type_of("ITEM_PICKUP_PLAYERBAG")
    if not playerbag_type then
        ctx.log("Sparrow vault adapter unavailable: ITEM_PICKUP_PLAYERBAG entity type missing")
        return
    end
    set_post_entity_spawn(function(entity)
        if state.theme~=THEME.NEO_BABYLON or state.level~=3 or entity.layer~=LAYER.BACK or ctx.randomizer_state.level_materialized.CHECK_SPARROW_VAULT then return end
        local uid,x,y,layer=entity.uid,entity.x,entity.y,entity.layer
        -- Let Sparrow's special Player Bag setup complete before replacing it;
        -- otherwise the game applies the bag's character texture to the reward.
        ctx.defer(1,"Sparrow vault Player Bag replacement",function()
            if ctx.randomizer_state.level_materialized.CHECK_SPARROW_VAULT then return end
            -- Keep the reward on the floor block directly left of Sparrow's
            -- native bag position, rather than overlapping her tile.
            local replacement_uid=materialize(ctx,"CHECK_SPARROW_VAULT",x-1,y,layer,uid,true)
            ctx.log("Sparrow vault Player Bag replaced left of Sparrow after native setup (uid "..tostring(replacement_uid)..")")
            if replacement_uid then
                ctx.defer(1,"Sparrow vault replacement visibility",function()
                    local replacement=get_entity(replacement_uid)
                    if replacement then
                        replacement.flags=clr_flag(replacement.flags,ENT_FLAG.INVISIBLE)
                        if replacement.color then replacement.color.a=1 end
                    end
                end)
            end
        end)
    end,SPAWN_TYPE.ANY,MASK.ITEM,playerbag_type)
end

return M
