---@mod focal.utils "Utilities"
---@brief [[
--- Common utility functions for safe requirements and notifications.
---@brief ]]

local M = {}

---Safe generic require wrapper
---@param module string
---@return boolean ok
---@return any|string result
function M.safe_require(module)
	return pcall(require, module)
end

---Notify user
---@param msg string
---@param level? number vim.log.levels
function M.notify(msg, level)
	vim.notify(string.format("[focal] %s", msg), level or vim.log.levels.INFO)
end

return M
