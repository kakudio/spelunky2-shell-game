local script_dir=(arg and arg[0] or ""):match("^(.*)[/\\]") or "."
package.path=script_dir.."/../?.lua;"..package.path

local fuzz_count=tonumber(arg[1] or "1000")
if not fuzz_count or fuzz_count<1 then
    io.stderr:write("Usage: lua scripts/run_tests.lua [fuzz_count]\n")
    os.exit(2)
end

local suites={
    {name="logic",run=function() return require("tests").run(fuzz_count) end},
    {name="adapters",run=function() return require("tests.adapter_tests").run() end},
}

print(_VERSION)
local failed=false
for _,suite in ipairs(suites) do
    local ok,message=suite.run()
    print(suite.name.." "..(ok and "passed: " or "FAILED: ")..tostring(message))
    failed=failed or not ok
end
os.exit(not failed)
