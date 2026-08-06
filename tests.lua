-- Console-runnable tests for deterministic logic and pure replacement safety.

local logic=require "logic"
local policy=require "replacement_policy"
local lifecycle=require "check_lifecycle"
local M={}

local function expect(condition,message)
    if not condition then return false,message end
    return true
end

local function policy_tests()
    local players={{uid=10},{uid=20}}
    local function owns(player_uid,item_uid)
        return player_uid==10 and item_uid==99
    end
    local ok,reason=policy.can_replace_source(99,players,owns)
    local valid,message=expect(not ok and reason=="player_carried","carried source was allowed")
    if not valid then return false,message end
    ok=policy.can_replace_source(100,players,owns)
    valid,message=expect(ok,"unowned source was rejected")
    if not valid then return false,message end
    ok=policy.can_replace_source(nil,players,owns)
    return expect(ok,"source-less replacement was rejected")
end

local function mapping_tests()
    local expected_deadlines={
        REWARD_UDJAT_EYE=1, REWARD_CROWN=2, REWARD_HEDJET=2,
        REWARD_SKELETON_KEY=2, REWARD_ANKH=3, REWARD_EXCALIBUR=3,
        REWARD_SCEPTER=3, REWARD_ALIEN_COMPASS=4, REWARD_EGGPLANT=4,
        REWARD_TABLET_OF_DESTINY=5, REWARD_HOU_YIS_BOW=7,
        REWARD_ARROW_OF_LIGHT=7,
    }
    for reward,deadline in pairs(expected_deadlines) do
        if logic.KEY_REWARD_DEADLINES[reward]~=deadline then
            return false,"wrong derived deadline for "..reward
        end
    end
    for _,reward in ipairs(logic.STARS_MOBILITY_REWARDS) do
        if logic.KEY_REWARD_DEADLINES[reward] then
            return false,"Stars mobility should remain one-per-seed: "..reward
        end
    end
    for _,seed in ipairs({1,42,867530,999999}) do
        local first=logic.generate(seed)
        local second=logic.generate(seed)
        local kali_group=logic.kali_present_target_group(seed)
        if kali_group~=2 then
            return false,"Kali Present must remain in logic group 2 at seed "..seed
        end
        local seen,overflow_counts,count={}, {}, 0
        for check_id,reward in pairs(first) do
            count=count+1
            if second[check_id]~=reward then return false,"nondeterministic fixed seed "..seed end
            local is_overflow=false
            for _,overflow_reward in ipairs(logic.OVERFLOW_REWARDS) do if reward==overflow_reward then is_overflow=true; overflow_counts[reward]=(overflow_counts[reward] or 0)+1; break end end
            if seen[reward] and not is_overflow then return false,"duplicate reward "..reward.." at seed "..seed end
            seen[reward]=true
            if check_id=="CHECK_QUEEN_BEE" and logic.KEY_REWARD_DEADLINES[reward] then return false,"Queen Bee received key reward "..reward.." at seed "..seed end
            if reward=="REWARD_TUSK_IDOL" then
                local group=logic.check_group(check_id,seed)
                if group<3 or group>6 then return false,"Tusk Idol placed outside groups 3-6 at seed "..seed end
                if logic.REWARD_EXCLUDED_CHECKS[reward] and logic.REWARD_EXCLUDED_CHECKS[reward][check_id] then return false,"Tusk Idol placed at excluded Kali check "..check_id.." at seed "..seed end
            end
            local excluded=logic.REWARD_EXCLUDED_LOCATIONS[reward]
            if excluded then
                local check
                for _,candidate in ipairs(logic.CHECKS) do
                    if candidate.id==check_id then check=candidate break end
                end
                if check and ((check.location and excluded[check.location]) or (check.locations and excluded[check.locations[1]])) then
                    return false,reward.." placed on its excluded route at "..check_id
                end
            end
        end
        if count~=logic.check_count() then return false,"wrong check count at seed "..seed end
        local least,most=math.huge,0
        for _,reward in ipairs(logic.OVERFLOW_REWARDS) do local count=overflow_counts[reward] or 0; least=math.min(least,count); most=math.max(most,count) end
        if most-least>1 then return false,"unbalanced overflow rewards at seed "..seed end
        local valid,route=logic.validate(first)
        if not valid or not route.victory then return false,"no victory route at seed "..seed end
    end
    return true
end

local function lifecycle_tests()
    local messages={}
    local scheduled=nil
    local state=lifecycle.new(function(message) table.insert(messages,message) end,function(callback) scheduled=callback end)
    state:begin_level()
    state:mark("CHECK_TEST","materialized","test source")
    local epoch,materialized,failed=state:summary()
    local ok,message=expect(epoch==1 and materialized==1 and failed==0,"materialized check was not summarized")
    if not ok then return false,message end
    state:fail("CHECK_FAILED","test failure")
    _,materialized,failed=state:summary()
    ok,message=expect(materialized==1 and failed==1 and #messages==1,"failed check was not retained")
    if not ok then return false,message end
    state:begin_level()
    epoch,materialized,failed=state:summary()
    ok,message=expect(epoch==2 and materialized==0 and failed==0,"new level did not clear lifecycle state")
    if not ok then return false,message end
    local ran=false
    state:defer(1,"stale-test",function() ran=true end)
    state:begin_level()
    scheduled()
    return expect(not ran and #messages==2,"stale deferred callback was not cancelled")
end

function M.run(fuzz_count)
    local ok,message=policy_tests()
    if not ok then return false,"policy: "..message end
    ok,message=mapping_tests()
    if not ok then return false,"mapping: "..message end
    ok,message=lifecycle_tests()
    if not ok then return false,"lifecycle: "..message end
    return logic.self_test(fuzz_count or 100,1)
end

return M
