---@mod iris.sources.nvim-tree "Nvim-tree Source"

local M = {}

M.filetype = "NvimTree"

function M.get_path()
    local ok, api = pcall(require, "nvim-tree.api")
    if not ok then return nil end

    local node = api.tree.get_node_under_cursor()
    if node and node.absolute_path and node.type ~= "directory" then
        return node.absolute_path
    end

    return nil
end

return M
