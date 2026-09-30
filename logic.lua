-- Pure deterministic logic for Shell Game.
-- This file deliberately has no Overlunky API calls, so its generator and
-- validator can be exercised from the in-game console and reviewed in isolation.

local M = {}
M.LOGIC_VERSION = 25

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
    LOCATION_NEO_BABYLON = { parents = { "LOCATION_ICE_CAVES" } },
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
    -- Queen Bee is optional and can be bypassed, so it can never receive a
    -- progression-key reward.
    { id="CHECK_QUEEN_BEE", location="LOCATION_JUNGLE", layer="FOREGROUND", base_reward="REWARD_ROYAL_JELLY", non_key=true },
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
    { id="CHECK_OSIRIS", location="LOCATION_DUAT", layer="BACKGROUND", all_of={"REWARD_SCEPTER","REWARD_ANKH"}, any_of={"REWARD_HEDJET","REWARD_CROWN"}, base_reward="REWARD_TABLET_OF_DESTINY" },
    { id="CHECK_ANUBIS_II", location="LOCATION_DUAT", layer="BACKGROUND", all_of={"REWARD_SCEPTER","REWARD_ANKH"}, any_of={"REWARD_HEDJET","REWARD_CROWN"}, base_reward="REWARD_JETPACK" },
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
    -- Completing the Sun Challenge also awards a Player Bag containing ropes
    -- and bombs. It is a distinct native reward and therefore its own check.
    { id="CHECK_SUN_CHALLENGE_SUPPLIES", location="LOCATION_SUNKEN_CITY", layer="BACKGROUND", base_reward="REWARD_PLAYER_BAG_ROPES_BOMBS" },
    { id="CHECK_EGGPLANT_KING", location="LOCATION_EGGPLANT_WORLD", layer="FOREGROUND", all_of={"REWARD_EGGPLANT"}, base_reward="REWARD_EGGPLANT_CROWN" },
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
 "REWARD_UDJAT_EYE","REWARD_HEDJET","REWARD_BOMB_BOX","REWARD_CROWN","REWARD_VLADS_CAPE","REWARD_HOU_YIS_BOW","REWARD_ANKH","REWARD_EXCALIBUR","REWARD_SKELETON_KEY","REWARD_TUSK_IDOL","REWARD_TABLET_OF_DESTINY","REWARD_SCEPTER","REWARD_ALIEN_COMPASS","REWARD_JETPACK","REWARD_CLONE_GUN","REWARD_ELIXIR","REWARD_SPIKE_SHOES","REWARD_COMPASS","REWARD_PLASMA_CANNON","REWARD_ROYAL_JELLY","REWARD_PLAYER_BAG_ROPES","REWARD_PLAYER_BAG_ROPES_BOMBS","REWARD_ARROW_OF_LIGHT","REWARD_EGGPLANT_CROWN","REWARD_EGGPLANT","REWARD_KAPALA","REWARD_TRUE_CROWN","REWARD_TELEPACK","REWARD_MATTOCK",
 "REWARD_CLIMBING_GLOVES","REWARD_PITCHERS_MITT","REWARD_PASTE","REWARD_SPRING_SHOES","REWARD_TELEPORTER","REWARD_POWERPACK","REWARD_HOVERPACK","REWARD_FREEZE_RAY","REWARD_SHOTGUN","REWARD_SPECTACLES","REWARD_CAPE",
}

-- Used only after every unique pool reward has been assigned. These common
-- consumables are repeated in a balanced rotation and never displace a
-- unique reward in the main pool.
M.OVERFLOW_REWARDS={"REWARD_BOMB_BAG","REWARD_ROPE_PILE","REWARD_TURKEY_LEG"}

-- A check's group is the latest progression window in which it is normally
-- available.  Branch-exclusive checks remain in the pool: validation tests
-- every route independently rather than discarding the other branch.
M.CHECK_GROUPS = {
    CHECK_UDJAT_CHEST=1, CHECK_YANG=1, CHECK_QUILLBACK=1,
    CHECK_BLACK_MARKET=2, CHECK_QUEEN_BEE=2, CHECK_SISTERS_OLMEC_REWARD=2,
    CHECK_VAN_HORSING_RESCUE=2, CHECK_VLADS_CASTLE=2, CHECK_VLAD=2,
    CHECK_MOON_CHALLENGE_JUNGLE=2, CHECK_MOON_CHALLENGE_VOLCANA=2,
    CHECK_OLMEC_ANKH=2, CHECK_KALI_ALTAR_1=3,
    CHECK_KALI_PRESENT=2, CHECK_BEG_FIRST_MEETING=2, CHECK_SPARROW=2,
    CHECK_TUSK_DICE_HOUSE=3, CHECK_HUMPHEAD_CAVE_IDOL=3, CHECK_EXCALIBUR_STONE=3,
    CHECK_TUSK_IDOL=3, CHECK_ANUBIS_SCEPTER=3,
    CHECK_ALIEN_COMPASS=3, CHECK_STARS_CHALLENGE_TIDE_POOL=3,
    CHECK_STARS_CHALLENGE_TEMPLE=3, CHECK_HUMPHEAD=3,
    CHECK_YETI_QUEEN=4, CHECK_YETI_KING=4,
    CHECK_KINGU=4, CHECK_OSIRIS=4, CHECK_ANUBIS_II=4,
    CHECK_LAHAMU=5, CHECK_MOTHERSHIP_PLASMA_CANNON=5,
    CHECK_TUSK_PALACE_VISIT=6, CHECK_SPARROW_VAULT=6,
    CHECK_KALI_ALTAR_2=6, CHECK_BEG_TRUE_CROWN=6,
    CHECK_TIAMAT=7, CHECK_SUN_CHALLENGE=7, CHECK_SUN_CHALLENGE_SUPPLIES=7, CHECK_EGGPLANT_KING=7,
}

-- Exactly one of these is selected per seed as the guaranteed early mobility
-- reward for the Stars Challenge gate. The other two remain normal pool items.
M.STARS_MOBILITY_REWARDS={"REWARD_CAPE","REWARD_VLADS_CAPE","REWARD_JETPACK"}

-- Taking the special Tusk Idol through any exit advances Sparrow into the
-- second half of her quest. It must therefore appear after Sparrow's first
-- encounter window (groups 1-2) but before the group-7 endgame checks.
M.REWARD_PLACEMENT_WINDOWS={
    REWARD_TUSK_IDOL={minimum_group=3, maximum_group=6},
}

-- A branch-only key may not be placed behind the opposite branch.  Excalibur
-- opens Abzu/Kingu on the Tide Pool route, while the Scepter opens City of
-- Gold/Duat on the Temple route.  Group timing alone cannot express this,
-- since checks in both routes share group 3.
M.REWARD_EXCLUDED_LOCATIONS={
    REWARD_EXCALIBUR={LOCATION_TEMPLE=true},
    REWARD_SCEPTER={LOCATION_TIDE_POOL=true},
}

-- The Tusk Idol advances Sparrow's quest when it is carried through an exit.
-- Kali-related rewards can be delayed, relocated to Duat, or consumed by an
-- altar interaction, so the Idol must never be assigned to one of them.
M.REWARD_EXCLUDED_CHECKS={
    REWARD_TUSK_IDOL={
        CHECK_KALI_PRESENT=true,
        CHECK_KALI_ALTAR_1=true,
        CHECK_KALI_ALTAR_2=true,
    },
}

local function is_stars_mobility_reward(value)
    for _,mobility in ipairs(M.STARS_MOBILITY_REWARDS) do if value==mobility then return true end end
    return false
end

local function add_group_requirement(deadlines, values, group)
    -- A group summarizes what is needed to access its checks. A required item
    -- must therefore be placed in an earlier group, while group 1 remains the
    -- earliest possible placement window.
    local deadline=math.max(1,group-1)
    for _,value in ipairs(values or {}) do
        -- The Stars gate needs any one mobility reward. Keep its existing
        -- one-per-seed behavior rather than forcing all three early merely
        -- because this summary takes a union of requirement alternatives.
        if value:sub(1,7)=="REWARD_" and not is_stars_mobility_reward(value) and (not deadlines[value] or deadline<deadlines[value]) then
            deadlines[value]=deadline
        end
    end
end

-- Derive progression deadlines from the union of each group's direct check
-- requirements and that check's location gates. This leaves check-level logic
-- authoritative while groups continue to define placement pacing.
function M.derive_key_reward_deadlines()
    local deadlines={}
    for _,check in ipairs(M.CHECKS) do
        local group=M.check_group(check.id,1)
        add_group_requirement(deadlines,check.all_of,group)
        add_group_requirement(deadlines,check.any_of,group)
        local location_ids={}
        if check.location then table.insert(location_ids,check.location) end
        for _,location_id in ipairs(check.locations or {}) do table.insert(location_ids,location_id) end
        for _,location_id in ipairs(location_ids) do
            local location=M.LOCATIONS[location_id]
            if location then
                add_group_requirement(deadlines,location.all_of,group)
                add_group_requirement(deadlines,location.any_of,group)
            end
        end
    end
    -- These are runtime/goal constraints rather than a normal check gate.
    -- Eggplant must be safely available by group 4. The Tablet is a
    -- custom victory-path requirement available by group 5; Bow/Arrow can
    -- be found late.
    deadlines.REWARD_EGGPLANT=math.min(deadlines.REWARD_EGGPLANT or math.huge,4)
    deadlines.REWARD_TABLET_OF_DESTINY=5
    deadlines.REWARD_HOU_YIS_BOW=7
    deadlines.REWARD_ARROW_OF_LIGHT=7
    return deadlines
end

local function has_all(state, values)
    for _, v in ipairs(values or {}) do if not state[v] then return false end end
    return true
end
local function has_any(state, values)
    if not values or #values == 0 then return true end
    for _, v in ipairs(values) do if state[v] then return true end end
    return false
end
local function contains(values, wanted)
    for _,value in ipairs(values or {}) do if value==wanted then return true end end
    return false
end
-- A check may explicitly repeat a requirement that its own location consumes
-- on entry (Duat's Ankh, for example). It was required to reach the check,
-- despite no longer being in inventory after the transition.
local function has_check_all(inventory, check, entered)
    local location=M.LOCATIONS[check.location or "LOCATION_NONE"]
    for _,item in ipairs(check.all_of or {}) do
        local consumed_by_its_location=location and entered[check.location] and contains(location.consumes,item) and (contains(location.all_of,item) or contains(location.any_of,item))
        if not inventory[item] and not consumed_by_its_location then return false end
    end
    return true
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
-- Kali's Present is a runtime source rather than a shuffled reward. It is
-- offered at the first eligible altar level in play, while group 2 keeps its
-- shuffled reward out of the initial Dwelling placement window.
function M.kali_present_target_group(_seed)
    return 2
end
function M.check_group(check_id, seed)
    if check_id=="CHECK_KALI_PRESENT" then return M.kali_present_target_group(seed) end
    return M.CHECK_GROUPS[check_id]
end
-- Derived once from the definitions above; this is intentionally not a
-- hand-maintained list of item-placement deadlines.
M.KEY_REWARD_DEADLINES=M.derive_key_reward_deadlines()
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
                if loc_ok and has_check_all(inventory, check, entered) and has_any(inventory, check.any_of) then
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
local function compatible_check(check, reward, deadline, seed, minimum_group)
    if check.non_key and M.KEY_REWARD_DEADLINES[reward] then return false end
    if M.REWARD_EXCLUDED_CHECKS[reward] and M.REWARD_EXCLUDED_CHECKS[reward][check.id] then return false end
    local group=M.check_group(check.id,seed) or math.huge
    if group>deadline or group<(minimum_group or 1) then return false end
    local excluded=M.REWARD_EXCLUDED_LOCATIONS[reward]
    if excluded then
        if check.location and excluded[check.location] then return false end
        for _,location_id in ipairs(check.locations or {}) do
            if excluded[location_id] then return false end
        end
    end
    return not reward_is_requirement(check,reward)
end

-- Fill deadline-bound rewards first. Every remaining check receives a unique
-- randomly sampled fill reward; extra fill rewards are intentionally unused.
function M.generate(seed)
    local next_int=rng(seed)
    local keys={}
    for reward,deadline in pairs(M.KEY_REWARD_DEADLINES) do table.insert(keys,{reward=reward,deadline=deadline}) end
    local stars_mobility=M.STARS_MOBILITY_REWARDS[next_int(#M.STARS_MOBILITY_REWARDS)]
    -- Stars is a group-3 gate, so its selected mobility reward must be in an
    -- earlier placement group just like the rest of the derived requirements.
    table.insert(keys,{reward=stars_mobility,deadline=2})
    for reward,window in pairs(M.REWARD_PLACEMENT_WINDOWS) do
        table.insert(keys,{reward=reward,deadline=window.maximum_group,minimum_group=window.minimum_group})
    end
    table.sort(keys,function(a,b) return a.deadline<b.deadline or (a.deadline==b.deadline and a.reward<b.reward) end)
    for _=1,500 do
        local map, used_check, used_reward={}, {}, {}
        local placed=true
        for _, key in ipairs(keys) do
            local candidates={}
            for _, check in ipairs(M.CHECKS) do
                if check.shuffle~=false and not used_check[check.id] and compatible_check(check,key.reward,key.deadline,seed,key.minimum_group) then table.insert(candidates,check) end
            end
            if #candidates==0 then placed=false break end
            local check=shuffled(candidates,next_int)[1]
            map[check.id]=key.reward; used_check[check.id]=true; used_reward[key.reward]=true
        end
        if placed then
            local remaining_checks, fill_rewards={},{}
            for _, check in ipairs(shuffled(M.CHECKS,next_int)) do if check.shuffle~=false and not used_check[check.id] then table.insert(remaining_checks,check.id) end end
            for _, reward in ipairs(shuffled(M.REWARDS,next_int)) do if not used_reward[reward] then table.insert(fill_rewards,reward) end end
            local overflow=shuffled(M.OVERFLOW_REWARDS,next_int)
            for i,check_id in ipairs(remaining_checks) do
                -- Each pass uses each option once, keeping counts within one.
                map[check_id]=fill_rewards[i] or overflow[((i-#fill_rewards-1)%#overflow)+1]
            end
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
        local seen, overflow_counts, entries={}, {}, 0
        for check_id, reward in pairs(first) do
            entries=entries+1
            local is_overflow=false
            for _,overflow_reward in ipairs(M.OVERFLOW_REWARDS) do if reward==overflow_reward then is_overflow=true; overflow_counts[reward]=(overflow_counts[reward] or 0)+1; break end end
            if seen[reward] and not is_overflow then return false, "duplicate reward "..reward.." at seed "..seed end
            seen[reward]=true
            if second[check_id] ~= reward then return false, "nondeterministic mapping at seed "..seed end
        end
        local shuffled_check_count=0
        for _,check in ipairs(M.CHECKS) do if check.shuffle~=false then shuffled_check_count=shuffled_check_count+1 end end
        if entries ~= shuffled_check_count then return false, "wrong shuffled check count at seed "..seed end
        for reward in pairs(M.KEY_REWARD_DEADLINES) do if not seen[reward] then return false, "missing key reward "..reward.." at seed "..seed end end
        local least,most=math.huge,0
        for _,reward in ipairs(M.OVERFLOW_REWARDS) do local count=overflow_counts[reward] or 0; least=math.min(least,count); most=math.max(most,count) end
        if most-least>1 then return false, "unbalanced overflow rewards at seed "..seed end
        if not route.victory then return false, "no Cosmic Ocean route at seed "..seed end
    end
    return true, string.format("passed %d seeds starting at %d", count, first_seed)
end

function M.format_route(result)
    return table.concat(result.trace, "\n")
end

return M
