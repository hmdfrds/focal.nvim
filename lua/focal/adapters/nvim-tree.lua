local Utils = require("focal.utils")

---@mod focal.adapters.nvim-tree "Nvim-tree Adapter"
local M = {}

M.filetype = "NvimTree"

---Resolve path from nvim-tree
---@return string|nil
function M.get_path()
	local ok, api = Utils.safe_require("nvim-tree.api")
	if not ok then return nil end

	local node = api.tree.get_node_under_cursor()
	if node and node.absolute_path and node.type ~= "directory" then
		return node.absolute_path
	end
	return nil
end

return M
