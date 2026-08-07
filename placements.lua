-- Runtime reward materialization. This module owns entity-ID lookups and the
-- one-per-level guard; it does not know where individual checks are anchored.

local M = {}

local REWARD_ENTITY_NAMES = {
    REWARD_UDJAT_EYE="ITEM_PICKUP_UDJATEYE", REWARD_BOMB_BAG="ITEM_PICKUP_BOMBBAG",
    REWARD_HEDJET="ITEM_PICKUP_HEDJET", REWARD_BOMB_BOX="ITEM_PICKUP_BOMBBOX",
    REWARD_CROWN="ITEM_PICKUP_CROWN", REWARD_VLADS_CAPE="ITEM_VLADS_CAPE",
    REWARD_HOU_YIS_BOW="ITEM_HOUYIBOW", REWARD_ANKH="ITEM_PICKUP_ANKH",
    REWARD_EXCALIBUR="ITEM_EXCALIBUR", REWARD_SKELETON_KEY="ITEM_PICKUP_SKELETON_KEY",
    REWARD_TUSK_IDOL="ITEM_MADAMETUSK_IDOL", REWARD_TABLET_OF_DESTINY="ITEM_PICKUP_TABLETOFDESTINY",
    REWARD_SCEPTER="ITEM_SCEPTER", REWARD_ALIEN_COMPASS="ITEM_PICKUP_SPECIALCOMPASS",
    REWARD_JETPACK="ITEM_JETPACK", REWARD_CLONE_GUN="ITEM_CLONEGUN",
    REWARD_ELIXIR="ITEM_PICKUP_ELIXIR",
    REWARD_SPIKE_SHOES="ITEM_PICKUP_SPIKESHOES", REWARD_COMPASS="ITEM_PICKUP_COMPASS",
    REWARD_PLASMA_CANNON="ITEM_PLASMACANNON", REWARD_ROYAL_JELLY="ITEM_PICKUP_ROYALJELLY",
    REWARD_PLAYER_BAG_ROPES="ITEM_PICKUP_PLAYERBAG", REWARD_PLAYER_BAG_ROPES_BOMBS="ITEM_PICKUP_PLAYERBAG", REWARD_ARROW_OF_LIGHT="ITEM_LIGHT_ARROW",
    REWARD_EGGPLANT_CROWN="ITEM_PICKUP_EGGPLANTCROWN", REWARD_ROPE_PILE="ITEM_PICKUP_ROPEPILE",
    REWARD_TURKEY_LEG="ITEM_PICKUP_COOKEDTURKEY",
    REWARD_EGGPLANT="ITEM_EGGPLANT", REWARD_KAPALA="ITEM_PICKUP_KAPALA",
    REWARD_TRUE_CROWN="ITEM_PICKUP_TRUECROWN",
    REWARD_TELEPACK="ITEM_TELEPORTER_BACKPACK", REWARD_MATTOCK="ITEM_MATTOCK",
    REWARD_CLIMBING_GLOVES="ITEM_PICKUP_CLIMBINGGLOVES", REWARD_PITCHERS_MITT="ITEM_PICKUP_PITCHERSMITT", REWARD_PASTE="ITEM_PICKUP_PASTE", REWARD_SPRING_SHOES="ITEM_PICKUP_SPRINGSHOES",
    REWARD_TELEPORTER="ITEM_TELEPORTER", REWARD_POWERPACK="ITEM_POWERPACK",
    REWARD_HOVERPACK="ITEM_HOVERPACK", REWARD_FREEZE_RAY="ITEM_FREEZERAY",
    REWARD_SHOTGUN="ITEM_SHOTGUN", REWARD_SPECTACLES="ITEM_PICKUP_SPECTACLES", REWARD_CAPE="ITEM_CAPE",
}

function M.type_of(name) return ENT_TYPE and ENT_TYPE[name] or nil end

function M.reward_type(randomizer_state, check_id)
    local reward=randomizer_state.mapping and randomizer_state.mapping[check_id]
    return reward, reward and M.type_of(REWARD_ENTITY_NAMES[reward]) or nil
end

function M.reward_entity_types()
    local seen,types={},{}
    for _,name in pairs(REWARD_ENTITY_NAMES) do
        local entity_type=M.type_of(name)
        if entity_type and not seen[entity_type] then
            seen[entity_type]=true
            table.insert(types,entity_type)
        end
    end
    return types
end

function M.spawn(ent_type,x,y,layer,snap_to_floor)
    if snap_to_floor then return spawn_entity_snapped_to_floor(ent_type,x,y,layer) end
    return spawn_entity(ent_type,x,y,layer,0,0)
end

local PLAYER_BAG_CONTENTS={
    REWARD_PLAYER_BAG_ROPES={bombs=0,ropes=12},
    REWARD_PLAYER_BAG_ROPES_BOMBS={bombs=12,ropes=12},
}

function M.configure_reward(uid,reward)
    local contents=PLAYER_BAG_CONTENTS[reward]
    if not contents or not uid or uid<0 then return end
    local entity=get_entity(uid)
    local bag=entity and entity:as_playerbag() or nil
    if bag then
        bag.bombs=contents.bombs
        bag.ropes=contents.ropes
    end
end

function M.materialize(randomizer_state, log, check_id, x, y, layer, source_uid, snap_to_floor)
    if randomizer_state.level_materialized[check_id] then return false end
    local reward, ent_type=M.reward_type(randomizer_state, check_id)
    if not reward or not ent_type then
        log("Cannot materialize "..check_id..": no known entity for "..tostring(reward))
        return false
    end
    if source_uid then
        local source=get_entity(source_uid)
        if source then source:destroy() end
    end
    local spawned_uid=M.spawn(ent_type,x,y,layer,snap_to_floor)
    M.configure_reward(spawned_uid,reward)
    randomizer_state.level_materialized[check_id]=true
    log(string.format("CHECK %s -> %s at %.1f, %.1f layer %s", check_id, reward, x, y, tostring(layer)))
    return spawned_uid
end

function M.print_missing_anchors()
    for reward, name in pairs(REWARD_ENTITY_NAMES) do
        if not M.type_of(name) then print("[KIR] Missing entity name: "..reward.." = "..name) end
    end
end

return M
