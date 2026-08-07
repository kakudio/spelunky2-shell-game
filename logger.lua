-- Central runtime logging policy. Gameplay adapters receive `logger.log`
-- through runtime state, so changing destinations happens here only.

local run_report=require "run_report"
-- Keep file reports for sharing, but also surface live diagnostics in the
-- Playlunky overlay while we investigate runtime behavior.
local M={overlay_runtime_logs=false}

function M.set_overlay_runtime_logs(enabled)
    M.overlay_runtime_logs=enabled and true or false
end

function M.log(message)
    run_report.log(message)
    if M.overlay_runtime_logs then print("[KeyItemRandomizer] "..message) end
end

function M.begin_run(randomizer_state,logic,write_spoiler,write_logs)
    return run_report.begin(randomizer_state,logic,write_spoiler,write_logs)
end

function M.report_path() return run_report.path() end

return M
