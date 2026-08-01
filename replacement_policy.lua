-- Pure replacement safety rules. This module intentionally has no game API
-- dependencies so its behavior can be tested from the console test suite.

local M={}

-- A level transition can reconstruct an item before level-generation scans
-- run. Such an item is player-owned, not a native check source.
function M.can_replace_source(source_uid, player_list, owns_item)
    if not source_uid then return true end
    for _,player in ipairs(player_list or {}) do
        if owns_item(player.uid,source_uid) then
            return false, "player_carried"
        end
    end
    return true
end

return M
