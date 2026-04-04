---@mod focal.sources.neo-tree "Neo-tree Source"

local M = {}

M.filetype = "neo-tree"

function M.get_path()
    local ok, manager = pcall(require, "neo-tree.sources.manager")
    if not ok then return nil end

    local state_ok, state = pcall(manager.get_state, "filesystem")
    if state_ok and state and state.tree then
        local node_ok, node = pcall(function() return state.tree:get_node() end)
        if node_ok and node and node.path and node.type == "file" then
            return node.path
        end
    end

    return nil
end

return M
