---@mod focal.utils "Utilities"
---@brief [[
--- Common utility functions for safe requirements, notifications, and error handling.
---@brief ]]

local M = {}

---@type boolean
M._debug = false

---Safe generic require wrapper. Logs failures when debug mode is on.
---@param module string
---@return boolean ok
---@return any|string result
function M.safe_require(module)
    local ok, result = pcall(require, module)
    if not ok and M._debug then
        M.notify("require('" .. module .. "') failed: " .. tostring(result), vim.log.levels.DEBUG)
    end
    return ok, result
end

---Safe pcall wrapper that surfaces errors in debug mode instead of swallowing them.
---@param fn function
---@param ... any
---@return boolean ok
---@return any result
function M.safe_call(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok and M._debug then
        M.notify("pcall failed: " .. tostring(result), vim.log.levels.DEBUG)
    end
    return ok, result
end

---Notify user
---@param msg string
---@param level? number vim.log.levels
function M.notify(msg, level)
    vim.notify(string.format("[focal] %s", msg), level or vim.log.levels.INFO)
end

return M
