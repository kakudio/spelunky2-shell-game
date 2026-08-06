-- Per-run diagnostic reports for player issue submissions.

local REPORT_LIMIT=30
local M={pending_logs={},run_number=0,filename=nil,enabled=true,write_logs=true,write_failed=false}

local function append(line)
    if not M.enabled or not M.filename then return end
    local file=io.open_data(M.filename,"a")
    if not file then M.write_failed=true; return end
    file:write(line,"\n")
    file:close()
end

local function game_seed()
    if not get_adventure_seed then return "unavailable" end
    local ok,first,second=pcall(get_adventure_seed,true)
    if not ok then return "unavailable" end
    return tostring(first)..","..tostring(second)
end

local function prune_old_reports()
    if not list_data_dir or not os.remove_data then return end
    local reports={}
    for _,path in ipairs(list_data_dir("run_reports") or {}) do
        if path:match("^run_reports/.+%-KeyItemRandomizer%-.+%.txt$") then table.insert(reports,path) end
    end
    table.sort(reports)
    while #reports>REPORT_LIMIT do
        os.remove_data(table.remove(reports,1))
    end
end

function M.log(message)
    local line=string.format("[%d] %s",os.time(),message)
    if M.filename then
        if M.enabled and M.write_logs then append(line) end
    else
        table.insert(M.pending_logs,line)
    end
end

function M.begin(randomizer_state,logic,write_spoiler,write_logs)
    write_spoiler=write_spoiler~=false
    M.write_logs=write_logs~=false
    M.enabled=write_spoiler or M.write_logs
    M.filename=nil
    M.write_failed=false
    if not M.enabled then M.pending_logs={}; return nil end

    M.run_number=M.run_number+1
    local run_seed=game_seed():gsub("[^%w%-_,]","_")
    local timestamp=os.date("%Y%m%d-%H%M%S")
    M.filename=string.format("run_reports/%s-KeyItemRandomizer-randomizer-%s-run-%s-%d.txt",timestamp,tostring(randomizer_state.seed or "unknown"),run_seed,M.run_number)
    local file=io.open_data(M.filename,"w")
    if not file then M.write_failed=true; return nil end
    file:write("Key Item Randomizer run report\n")
    file:write("Randomizer seed: ",tostring(randomizer_state.seed),"\n")
    file:write("Game adventure run seed: ",game_seed(),"\n")
    file:write("Logic version: ",tostring(logic.LOGIC_VERSION),"\n")
    file:write("Generated: ",tostring(os.time()),"\n\n")
    if write_spoiler then
        file:write("Spoiler mapping:\n")
        for _,check in ipairs(logic.CHECKS) do
            if check.shuffle~=false then
                file:write(string.format("  %s -> %s\n",check.id,randomizer_state.mapping and randomizer_state.mapping[check.id] or "NONE"))
            end
        end
    end
    if M.write_logs then
        file:write("\nMod log:\n")
        for _,line in ipairs(M.pending_logs) do file:write(line,"\n") end
    end
    M.pending_logs={}
    file:close()
    prune_old_reports()
    return M.filename
end

function M.path() return M.filename end
function M.failed() return M.write_failed end

return M
