-- Console-runnable tests for deterministic logic and pure replacement safety.

local logic=require "logic"
local policy=require "replacement_policy"
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
    for _,seed in ipairs({1,42,867530,999999}) do
        local first=logic.generate(seed)
        local second=logic.generate(seed)
        local kali_group=logic.kali_present_target_group(seed)
        if kali_group~=2 then
            return false,"Kali Present must remain in logic group 2 at seed "..seed
        end
        local seen,count={},0
        for check_id,reward in pairs(first) do
            count=count+1
            if second[check_id]~=reward then return false,"nondeterministic fixed seed "..seed end
            if seen[reward] then return false,"duplicate reward "..reward.." at seed "..seed end
            seen[reward]=true
        end
        if count~=logic.check_count() then return false,"wrong check count at seed "..seed end
        local valid,route=logic.validate(first)
        if not valid or not route.victory then return false,"no victory route at seed "..seed end
    end
    return true
end

function M.run(fuzz_count)
    local ok,message=policy_tests()
    if not ok then return false,"policy: "..message end
    ok,message=mapping_tests()
    if not ok then return false,"mapping: "..message end
    return logic.self_test(fuzz_count or 100,1)
end

return M
