-- Run report header checks, driven through run_report.begin against a recording io.open_data.

local M={}

local function header_for(build)
    local written={}
    local saved_open_data=io.open_data
    local saved_build_config=package.loaded.build_config
    io.open_data=function()
        return {write=function(_,...) for _,part in ipairs({...}) do table.insert(written,part) end end,close=function() end}
    end
    package.loaded.build_config={developer_options=false,default_overlay_runtime_logs=false,build=build}
    package.loaded.run_report=nil
    local ok,err=pcall(function()
        require("run_report").begin({seed=1,mapping={}},{LOGIC_VERSION=1,CHECKS={}},true,true)
    end)
    io.open_data=saved_open_data
    package.loaded.build_config=saved_build_config
    package.loaded.run_report=nil
    if not ok then error(err,0) end
    return table.concat(written)
end

local function build_line(header)
    return header:match("\nBuild: ([^\n]*)\n")
end

local checks={
    {"a packaged build names its commit, version and variant",function()
        local sha=string.rep("a",40)
        local line=build_line(header_for({commit=sha,dirty=false,version="1.2.3",variant="release"}))
        return line=="version 1.2.3, release variant, commit "..sha,"got "..tostring(line)
    end},
    {"a dirty packaged build says so",function()
        local sha=string.rep("b",40)
        local line=build_line(header_for({commit=sha,dirty=true,version="1.2.3",variant="dev"}))
        return line=="version 1.2.3, dev variant, commit "..sha.." with uncommitted changes","got "..tostring(line)
    end},
    {"an unpackaged checkout says so in place of commit and version",function()
        local line=build_line(header_for(nil))
        return line=="unpackaged checkout (no commit or version stamp)","got "..tostring(line)
    end},
    {"the checked-in build configuration carries no build stamp",function()
        package.loaded.build_config=nil
        local build=require("build_config").build
        package.loaded.build_config=nil
        return build==nil,"build_config.lua has a build stamp"
    end},
}

function M.run()
    local failures={}
    for _,check in ipairs(checks) do
        local ok,passed,message=pcall(check[2])
        if not ok then table.insert(failures,check[1]..": "..tostring(passed))
        elseif not passed then table.insert(failures,check[1]..": "..tostring(message)) end
    end
    if #failures>0 then return false,#failures.." of "..#checks.." checks failed\n  "..table.concat(failures,"\n  ") end
    return true,"passed "..#checks.." checks"
end

return M
