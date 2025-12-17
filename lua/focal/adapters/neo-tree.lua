local Utils = require("focal.utils")

---@mod focal.adapters.neo-tree "Neo-tree Adapter"
local M = {}

M.filetype = "neo-tree"

---Resolve path from neo-tree
---@return string|nil
function M.get_path()
	local ok_mgr, manager = Utils.safe_require("neo-tree.sources.manager")
	if not ok_mgr then return nil end

	-- get_state expects (source_name, tabid, winid).
	-- We must use "filesystem" source for image previews.
	local ok_state, state = pcall(manager.get_state, "filesystem")
	if ok_state and state and state.tree then
		local ok_node, node = pcall(function() return state.tree:get_node() end)
		if ok_node and node and node.path and node.type ~= "directory" then
			return node.path
		end
	end
	return nil
end

return M
