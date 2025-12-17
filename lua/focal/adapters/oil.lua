local Utils = require("focal.utils")

---@mod focal.adapters.oil "Oil.nvim Adapter"
local M = {}

M.filetype = "oil"

---Resolve path from oil
---@return string|nil
function M.get_path()
	local ok, oil = Utils.safe_require("oil")
	if not ok then return nil end

    -- Oil entries are relative to the directory being edited
	local entry = oil.get_cursor_entry()
    if not entry then return nil end
    
    -- Oil treats everything as an entry, check type
    if entry.type == "directory" then return nil end

	local dir = oil.get_current_dir()
    if not dir then return nil end
    
    -- Ensure dir ends with separator
    if not dir:match("/$") then
        dir = dir .. "/"
    end

	return dir .. entry.name
end

return M
