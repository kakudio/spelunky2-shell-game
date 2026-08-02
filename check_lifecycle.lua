-- Per-level check lifecycle and guarded deferred work.
--
-- Runtime adapters may observe an event several frames after a level has
-- changed.  Capturing the level epoch here prevents a stale callback from
-- materializing a reward in a later visit to the same theme.

local M={}

function M.new(log, schedule)
    return setmetatable({epoch=0, states={}, failures={}, log=log, schedule=schedule or set_timeout},{__index=M})
end

function M:begin_level()
    self.epoch=self.epoch+1
    self.states={}
    self.failures={}
end

function M:mark(check, state, detail)
    self.states[check]={state=state,detail=detail}
end

function M:fail(check, detail)
    self.failures[check]=detail
    self:mark(check,"failed",detail)
    self.log("CHECK "..check.." failed: "..detail)
end

function M:defer(frames, label, callback)
    local epoch=self.epoch
    self.schedule(function()
        if self.epoch~=epoch then
            self.log("Cancelled stale deferred action "..label.." (level changed)")
            return
        end
        callback()
    end,frames)
end

function M:summary()
    local materialized,failed=0,0
    for _,entry in pairs(self.states) do
        if entry.state=="materialized" then materialized=materialized+1 end
        if entry.state=="failed" then failed=failed+1 end
    end
    return self.epoch,materialized,failed,self.failures
end

return M
