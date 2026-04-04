---@mod focal.sources.nvim-tree "Nvim-tree Source"

local M = {}

M.filetype = "NvimTree"

function M.get_path()
    local ok, api = pcall(require, "nvim-tree.api")
    if not ok then
        return nil
    end

    local node_ok, node = pcall(api.tree.get_node_under_cursor)
    if not node_ok or not node then
        return nil
    end

    if node.absolute_path and (node.type == "file" or node.type == "link") then
        return node.absolute_path
    end

    return nil
end

return M
