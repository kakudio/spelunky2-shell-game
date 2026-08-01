-- Pure deterministic logic for Key Item Randomizer.
-- This file deliberately has no Overlunky API calls, so its generator and
-- validator can be exercised from the in-game console and reviewed in isolation.

local M = {}
M.LOGIC_VERSION = 12

M.LOCATIONS = {
    LOCATION_DWELLING = { parents = {} },
    LOCATION_JUNGLE = { parents = { "LOCATION_DWELLING" } },
    LOCATION_VOLCANA = { parents = { "LOCATION_DWELLING" } },
    LOCATION_OLMEC = { parents = { "LOCATION_JUNGLE", "LOCATION_VOLCANA" } },
    LOCATION_TIDE_POOL = { parents = { "LOCATION_OLMEC" } },
    LOCATION_TEMPLE = { parents = { "LOCATION_OLMEC" } },
    LOCATION_ABZU = { parents = { "LOCATION_TIDE_POOL" }, all_of = { "REWARD_ANKH" }, consumes = { "REWARD_ANKH" } },
    LOCATION_CITY_OF_GOLD = { parents = { "LOCATION_TEMPLE" }, all_of = { "REWARD_SCEPTER" }, any_of = { "REWARD_HEDJET", "REWARD_CROWN" } },
    LOCATION_DUAT = { parents = { "LOCATION_CITY_OF_GOLD" }, all_of = { "REWARD_ANKH" }, consumes = { "REWARD_ANKH" } },
    LOCATION_ICE_CAVES = { parents = { "LOCATION_TIDE_POOL", "LOCATION_TEMPLE", "LOCATION_ABZU", "LOCATION_DUAT" } },
    LOCATION_NEO_BABYLON = { parents = { "LOCATION_ICE_CAVES" }, all_of = { "REWARD_TABLET_OF_DESTINY" } },
    LOCATION_TIAMAT = { parents = { "LOCATION_NEO_BABYLON" } },
    LOCATION_SUNKEN_CITY = { parents = { "LOCATION_TIAMAT" } },
    -- Moai remains entirely vanilla. Eggplant is the shuffled gate required
    -- to use it and reach Eggplant World.
    LOCATION_EGGPLANT_WORLD = { parents = { "LOCATION_SUNKEN_CITY" }, all_of = { "REWARD_EGGPLANT" } },
    LOCATION_HUNDUN = { parents = { "LOCATION_SUNKEN_CITY" } },
    LOCATION_NONE = { parents = {} },
}

-- `locations` is used only for the Sisters reward, which needs both Jungle and Olmec.
M.CHECKS = {
    { id="CHECK_UDJAT_CHEST", location="LOCATION_DWELLING", layer="BACKGROUND", base_reward="REWARD_UDJAT_EYE" },
    { id="CHECK_YANG", location="LOCATION_DWELLING", layer="BACKGROUND", base_reward="NONE" },
    { id="CHECK_QUILLBACK", location="LOCATION_DWELLING", layer="FOREGROUND", base_reward="REWARD_BOMB_BAG" },
    { id="CHECK_BLACK_MARKET", location="LOCATION_JUNGLE", layer="BACKGROUND", all_of={"REWARD_UDJAT_EYE"}, base_reward="REWARD_HEDJET" },
    { id="CHECK_SISTERS_OLMEC_REWARD", locations={"LOCATION_JUNGLE", "LOCATION_OLMEC"}, layer="FOREGROUND", base_reward="REWARD_BOMB_BOX" },
    { id="CHECK_VAN_HORSING_RESCUE", location="LOCATION_VOLCANA", layer="BACKGROUND", base_reward="REWARD_DIAMOND" },
    { id="CHECK_VLADS_CASTLE", location="LOCATION_VOLCANA", layer="BACKGROUND", all_of={"REWARD_UDJAT_EYE"}, base_reward="REWARD_CROWN" },
    { id="CHECK_VLAD", location="LOCATION_VOLCANA", layer="BACKGROUND", all_of={"REWARD_UDJAT_EYE"}, base_reward="REWARD_VLADS_CAPE" },
    { id="CHECK_MOON_CHALLENGE_JUNGLE", location="LOCATION_JUNGLE", layer="BACKGROUND", base_reward="REWARD_HOU_YIS_BOW" },
    { id="CHECK_MOON_CHALLENGE_VOLCANA", location="LOCATION_VOLCANA", layer="BACKGROUND", base_reward="REWARD_HOU_YIS_BOW" },
    { id="CHECK_OLMEC_ANKH", location="LOCATION_OLMEC", layer="BACKGROUND", base_reward="REWARD_ANKH" },
    { id="CHECK_TUSK_DICE_HOUSE", location="LOCATION_TIDE_POOL", layer="BACKGROUND", base_reward="NONE" },
    { id="CHECK_HUMPHEAD_CAVE_IDOL", location="LOCATION_TIDE_POOL", layer="BACKGROUND", base_reward="REWARD_IDOL" },
    { id="CHECK_EXCALIBUR_STONE", location="LOCATION_TIDE_POOL", layer="FOREGROUND", any_of={"REWARD_HEDJET","REWARD_CROWN"}, base_reward="REWARD_EXCALIBUR" },
    { id="CHECK_TUSK_IDOL", location="LOCATION_TIDE_POOL", layer="BACKGROUND", all_of={"REWARD_SKELETON_KEY"}, base_reward="REWARD_TUSK_IDOL" },
    { id="CHECK_KINGU", location="LOCATION_ABZU", layer="FOREGROUND", all_of={"REWARD_EXCALIBUR"}, base_reward="REWARD_TABLET_OF_DESTINY" },
    { id="CHECK_ANUBIS_SCEPTER", location="LOCATION_TEMPLE", layer="FOREGROUND", base_reward="REWARD_SCEPTER" },
    { id="CHECK_ALIEN_COMPASS", location="LOCATION_TEMPLE", layer="BACKGROUND", all_of={"CHECK_VAN_HORSING_RESCUE","CHECK_VLAD"}, base_reward="REWARD_ALIEN_COMPASS" },
    { id="CHECK_OSIRIS", location="LOCATION_DUAT", layer="BACKGROUND", base_reward="REWARD_TABLET_OF_DESTINY" },
    { id="CHECK_ANUBIS_II", location="LOCATION_DUAT", layer="BACKGROUND", base_reward="REWARD_JETPACK" },
    { id="CHECK_STARS_CHALLENGE_TIDE_POOL", location="LOCATION_TIDE_POOL", layer="BACKGROUND", any_of={"REWARD_CAPE","REWARD_VLADS_CAPE","REWARD_JETPACK"}, base_reward="REWARD_CLONE_GUN" },
    { id="CHECK_STARS_CHALLENGE_TEMPLE", location="LOCATION_TEMPLE", layer="BACKGROUND", any_of={"REWARD_CAPE","REWARD_VLADS_CAPE","REWARD_JETPACK"}, base_reward="REWARD_ELIXIR" },
    { id="CHECK_YETI_QUEEN", location="LOCATION_ICE_CAVES", layer="BACKGROUND", base_reward="REWARD_SPIKE_SHOES" },
    { id="CHECK_YETI_KING", location="LOCATION_ICE_CAVES", layer="BACKGROUND", base_reward="REWARD_COMPASS" },
    { id="CHECK_LAHAMU", location="LOCATION_ICE_CAVES", layer="BACKGROUND", all_of={"REWARD_ALIEN_COMPASS"}, base_reward="NONE" },
    { id="CHECK_MOTHERSHIP_PLASMA_CANNON", location="LOCATION_ICE_CAVES", layer="BACKGROUND", all_of={"REWARD_ALIEN_COMPASS"}, base_reward="REWARD_PLASMA_CANNON" },
    { id="CHECK_TUSK_PALACE_VISIT", location="LOCATION_NEO_BABYLON", layer="BACKGROUND", all_of={"CHECK_TUSK_DICE_HOUSE"}, base_reward="REWARD_ROYAL_JELLY" },
    { id="CHECK_SPARROW_VAULT", location="LOCATION_NEO_BABYLON", layer="BACKGROUND", base_reward="REWARD_PLAYER_BAG_ROPES" },
    { id="CHECK_TIAMAT", location="LOCATION_TIAMAT", layer="FOREGROUND", base_reward="NONE" },
    { id="CHECK_SUN_CHALLENGE", location="LOCATION_SUNKEN_CITY", layer="BACKGROUND", base_reward="REWARD_ARROW_OF_LIGHT" },
    { id="CHECK_EGGPLANT_KING", location="LOCATION_EGGPLANT_WORLD", layer="FOREGROUND", base_reward="REWARD_EGGPLANT_CROWN" },
    { id="CHECK_SPARROW", location="LOCATION_NONE", layer="NONE", base_reward="REWARD_ROPE_PILE" },
    -- Humphead's present/reward is the eggplant-chain check. The game labels
    -- its native drop HUMPHEAD_HIREDHAND, but the randomized check is the
    -- present the player receives after defeating Humphead.
    { id="CHECK_HUMPHEAD", location="LOCATION_TIDE_POOL", layer="FOREGROUND", base_reward="REWARD_EGGPLANT" },
    { id="CHECK_KALI_ALTAR_1", location="LOCATION_NONE", layer="FOREGROUND", base_reward="NONE" },
    -- A Present is injected beside a Kali altar by the runtime adapter, so
    -- this check has no shuffled-item prerequisite.
    { id="CHECK_KALI_PRESENT", location="LOCATION_NONE", layer="FOREGROUND", base_reward="NONE" },
    { id="CHECK_KALI_ALTAR_2", location="LOCATION_NONE", layer="FOREGROUND", all_of={"CHECK_KALI_ALTAR_1"}, base_reward="REWARD_KAPALA" },
    { id="CHECK_BEG_FIRST_MEETING", location="LOCATION_NONE", layer="FOREGROUND", base_reward="REWARD_BOMB_BAG" },
    { id="CHECK_BEG_TRUE_CROWN", location="LOCATION_NONE", layer="FOREGROUND", all_of={"CHECK_BEG_FIRST_MEETING"}, base_reward="REWARD_TRUE_CROWN" },
}

-- Exactly one pool reward per check. Diamond is a vanilla reward, but is not in
-- the shuffle pool; Skeleton Key is included because it is an explicit gate.
M.REWARDS = {
 "REWARD_UDJAT_EYE","REWARD_BOMB_BAG","REWARD_HEDJET","REWARD_BOMB_BOX","REWARD_CROWN","REWARD_VLADS_CAPE","REWARD_HOU_YIS_BOW","REWARD_ANKH","REWARD_EXCALIBUR","REWARD_SKELETON_KEY","REWARD_TUSK_IDOL","REWARD_TABLET_OF_DESTINY","REWARD_SCEPTER","REWARD_ALIEN_COMPASS","REWARD_JETPACK","REWARD_CLONE_GUN","REWARD_ELIXIR","REWARD_SPIKE_SHOES","REWARD_COMPASS","REWARD_PLASMA_CANNON","REWARD_ROYAL_JELLY","REWARD_PLAYER_BAG_ROPES","REWARD_ARROW_OF_LIGHT","REWARD_EGGPLANT_CROWN","REWARD_ROPE_PILE","REWARD_EGGPLANT","REWARD_KAPALA","REWARD_TRUE_CROWN","REWARD_TELEPACK","REWARD_MATTOCK",
 "REWARD_CLIMBING_GLOVES","REWARD_SPRING_SHOES","REWARD_TELEPORTER","REWARD_POWERPACK","REWARD_HOVERPACK","REWARD_FREEZE_RAY","REWARD_SHOTGUN","REWARD_SPECTACLES","REWARD_CAPE",
}

-- A check's group is the latest progression window in which it is normally
-- available.  Branch-exclusive checks remain in the pool: validation tests
-- every route independently rather than discarding the other branch.
M.CHECK_GROUPS = {
    CHECK_UDJAT_CHEST=1, CHECK_YANG=1, CHECK_QUILLBACK=1,
    CHECK_BLACK_MARKET=2, CHECK_SISTERS_OLMEC_REWARD=2,
    CHECK_VAN_HORSING_RESCUE=2, CHECK_VLADS_CASTLE=2, CHECK_VLAD=2,
    CHECK_MOON_CHALLENGE_JUNGLE=2, CHECK_MOON_CHALLENGE_VOLCANA=2,
    CHECK_OLMEC_ANKH=2, CHECK_KALI_ALTAR_1=2,
    CHECK_KALI_PRESENT=2, CHECK_BEG_FIRST_MEETING=2, CHECK_SPARROW=2,
    CHECK_TUSK_DICE_HOUSE=3, CHECK_HUMPHEAD_CAVE_IDOL=3, CHECK_EXCALIBUR_STONE=3,
    CHECK_TUSK_IDOL=3, CHECK_ANUBIS_SCEPTER=3,
    CHECK_ALIEN_COMPASS=3, CHECK_STARS_CHALLENGE_TIDE_POOL=3,
    CHECK_STARS_CHALLENGE_TEMPLE=3, CHECK_HUMPHEAD=3,
    CHECK_BEG_TRUE_CROWN=3,
    CHECK_YETI_QUEEN=4, CHECK_YETI_KING=4,
    CHECK_LAHAMU=4, CHECK_MOTHERSHIP_PLASMA_CANNON=4,
    CHECK_KINGU=5, CHECK_OSIRIS=5, CHECK_ANUBIS_II=5,
    CHECK_TUSK_PALACE_VISIT=5, CHECK_SPARROW_VAULT=5,
    CHECK_KALI_ALTAR_2=5,
    CHECK_TIAMAT=6, CHECK_SUN_CHALLENGE=6, CHECK_EGGPLANT_KING=6,
}

-- Every entry here is guaranteed to appear. The number is its latest legal
-- group; a reward may be placed in any earlier compatible group.
M.KEY_REWARD_DEADLINES = {
    REWARD_UDJAT_EYE=1,
    REWARD_CROWN=2, REWARD_HEDJET=2,
    REWARD_ANKH=3, REWARD_EXCALIBUR=3, REWARD_SCEPTER=3,
    REWARD_EGGPLANT=3,
    REWARD_SKELETON_KEY=4, REWARD_ALIEN_COMPASS=4,
    REWARD_TABLET_OF_DESTINY=5,
    REWARD_HOU_YIS_BOW=6, REWARD_ARROW_OF_LIGHT=6,
}

-- Exactly one of these is selected per seed as the guaranteed early mobility
-- reward for the Stars Challenge gate. The other two remain normal pool items.
M.STARS_MOBILITY_REWARDS={"REWARD_CAPE","REWARD_VLADS_CAPE","REWARD_JETPACK"}

local function has_all(state, values)
    for _, v in ipairs(values or {}) do if not state[v] then return false end end
    return true
end
local function has_any(state, values)
    if not values or #values == 0 then return true end
    for _, v in ipairs(values) do if state[v] then return true end end
    return false
end
local function copy(a) local b={} for k,v in pairs(a) do b[k]=v end return b end

function M.check_count() return #M.CHECKS end
function M.reward_count() return #M.REWARDS end

-- Park-Miller is stable across Lua/Overlunky versions and does not touch math.random.
local function rng(seed)
    local state = math.floor(tonumber(seed) or 1) % 2147483647
    if state <= 0 then state = 1 end
    return function(max)
        state = (state * 16807) % 2147483647
        return (state % max) + 1
    end
end
-- Kali's Present is a runtime source rather than a shuffled reward. Its
-- check still participates in key placement, so give it a seed-stable group
-- and use that same group when selecting a legal reward location.
function M.kali_present_target_group(seed)
    return rng((math.floor(tonumber(seed) or 1) + 918273) % 2147483647)(6)
end
function M.check_group(check_id, seed)
    if check_id=="CHECK_KALI_PRESENT" then return M.kali_present_target_group(seed) end
    return M.CHECK_GROUPS[check_id]
end
local function shuffled(values, next_int)
    local out={} for i,v in ipairs(values) do out[i]=v end
    for i=#out,2,-1 do local j=next_int(i); out[i],out[j]=out[j],out[i] end
    return out
end

local function route_locations(route)
    return {
      LOCATION_DWELLING=true, LOCATION_NONE=true, LOCATION_OLMEC=true,
      [route.early]=true, [route.mid]=true, LOCATION_ICE_CAVES=true,
      LOCATION_NEO_BABYLON=true, LOCATION_TIAMAT=true, LOCATION_SUNKEN_CITY=true,
      LOCATION_EGGPLANT_WORLD=true, LOCATION_HUNDUN=true,
      LOCATION_ABZU=route.mid=="LOCATION_TIDE_POOL", LOCATION_CITY_OF_GOLD=route.mid=="LOCATION_TEMPLE",
      LOCATION_DUAT=route.mid=="LOCATION_TEMPLE",
    }
end

local ROUTES = {
 {early="LOCATION_JUNGLE",mid="LOCATION_TIDE_POOL"}, {early="LOCATION_JUNGLE",mid="LOCATION_TEMPLE"},
 {early="LOCATION_VOLCANA",mid="LOCATION_TIDE_POOL"}, {early="LOCATION_VOLCANA",mid="LOCATION_TEMPLE"},
}

function M.solve(mapping, route)
    local allowed, inventory, visited, entered = route_locations(route), {}, {}, {}
    local trace, changed = {}, true
    while changed do
        changed=false
        for id, loc in pairs(M.LOCATIONS) do
            if allowed[id] and not entered[id] then
                local parent_ok = #loc.parents == 0
                for _, parent in ipairs(loc.parents) do if entered[parent] then parent_ok=true end end
                if parent_ok and has_all(inventory, loc.all_of) and has_any(inventory, loc.any_of) then
                    entered[id]=true; changed=true
                    for _, item in ipairs(loc.consumes or {}) do inventory[item]=nil end
                    table.insert(trace, "ENTER "..id)
                end
            end
        end
        for _, check in ipairs(M.CHECKS) do
            if not visited[check.id] then
                local loc_ok = entered[check.location or "LOCATION_NONE"]
                for _, loc in ipairs(check.locations or {}) do if not entered[loc] then loc_ok=false end end
                if loc_ok and has_all(inventory, check.all_of) and has_any(inventory, check.any_of) then
                    visited[check.id]=true; inventory[check.id]=true
                    local reward=mapping[check.id]
                    if reward then inventory[reward]=true end
                    changed=true
                    table.insert(trace, "CHECK "..check.id.." -> "..(reward or "NONE"))
                end
            end
        end
    end
    local victory = entered.LOCATION_HUNDUN and inventory.REWARD_TABLET_OF_DESTINY and inventory.REWARD_HOU_YIS_BOW and inventory.REWARD_ARROW_OF_LIGHT
    if victory then table.insert(trace, "VICTORY_COSMIC_OCEAN") end
    return { victory=victory, inventory=inventory, visited=visited, entered=entered, trace=trace, route=route }
end

function M.validate(mapping)
    local results, reachable_checks, victory_result={}, {}, nil
    for _, route in ipairs(ROUTES) do
        local result=M.solve(mapping, route)
        table.insert(results, result)
        if result.victory and not victory_result then victory_result=result end
        for check_id in pairs(result.visited) do reachable_checks[check_id]=true end
    end
    for _, check in ipairs(M.CHECKS) do
        if not reachable_checks[check.id] then
            return false, nil, results, "unreachable check "..check.id
        end
    end
    if not victory_result then return false, nil, results, "no Cosmic Ocean route" end
    return true, victory_result, results
end

local function check_by_id(id)
    for _, check in ipairs(M.CHECKS) do if check.id==id then return check end end
end
local function reward_is_requirement(check, reward)
    for _, value in ipairs(check.all_of or {}) do if value==reward then return true end end
    for _, value in ipairs(check.any_of or {}) do if value==reward then return true end end
    return false
end
local function compatible_check(check, reward, deadline, seed)
    if (M.check_group(check.id,seed) or math.huge)>deadline then return false end
    return not reward_is_requirement(check,reward)
end

-- Fill deadline-bound rewards first. Every remaining check receives a unique
-- randomly sampled fill reward; extra fill rewards are intentionally unused.
function M.generate(seed)
    local next_int=rng(seed)
    local keys={}
    for reward,deadline in pairs(M.KEY_REWARD_DEADLINES) do table.insert(keys,{reward=reward,deadline=deadline}) end
    local stars_mobility=M.STARS_MOBILITY_REWARDS[next_int(#M.STARS_MOBILITY_REWARDS)]
    table.insert(keys,{reward=stars_mobility,deadline=3})
    table.sort(keys,function(a,b) return a.deadline<b.deadline or (a.deadline==b.deadline and a.reward<b.reward) end)
    for _=1,500 do
        local map, used_check, used_reward={}, {}, {}
        local placed=true
        for _, key in ipairs(keys) do
            local candidates={}
            for _, check in ipairs(M.CHECKS) do
                if check.shuffle~=false and not used_check[check.id] and compatible_check(check,key.reward,key.deadline,seed) then table.insert(candidates,check) end
            end
            if #candidates==0 then placed=false break end
            local check=shuffled(candidates,next_int)[1]
            map[check.id]=key.reward; used_check[check.id]=true; used_reward[key.reward]=true
        end
        if placed then
            local remaining_checks, fill_rewards={},{}
            for _, check in ipairs(shuffled(M.CHECKS,next_int)) do if check.shuffle~=false and not used_check[check.id] then table.insert(remaining_checks,check.id) end end
            for _, reward in ipairs(shuffled(M.REWARDS,next_int)) do if not used_reward[reward] then table.insert(fill_rewards,reward) end end
            for i,check_id in ipairs(remaining_checks) do map[check_id]=fill_rewards[i] end
            local ok, result=M.validate(map)
            if ok then return map, result end
        end
    end
    error("could not construct a valid grouped mapping for seed "..tostring(seed))
end

-- Returns false plus a useful diagnostic instead of relying on a playthrough.
function M.self_test(count, first_seed)
    count=math.max(1, math.floor(count or 100))
    first_seed=math.floor(first_seed or 1)
    for seed=first_seed, first_seed+count-1 do
        local first, route=M.generate(seed)
        local second=M.generate(seed)
        local seen, entries={},0
        for check_id, reward in pairs(first) do
            entries=entries+1
            if seen[reward] then return false, "duplicate reward "..reward.." at seed "..seed end
            seen[reward]=true
            if second[check_id] ~= reward then return false, "nondeterministic mapping at seed "..seed end
        end
        local shuffled_check_count=0
        for _,check in ipairs(M.CHECKS) do if check.shuffle~=false then shuffled_check_count=shuffled_check_count+1 end end
        if entries ~= shuffled_check_count then return false, "wrong shuffled check count at seed "..seed end
        for reward in pairs(M.KEY_REWARD_DEADLINES) do if not seen[reward] then return false, "missing key reward "..reward.." at seed "..seed end end
        if not route.victory then return false, "no Cosmic Ocean route at seed "..seed end
    end
    return true, string.format("passed %d seeds starting at %d", count, first_seed)
end

function M.format_route(result)
    return table.concat(result.trace, "\n")
end

return M
