---@mod focal.resolver "Path Resolver"
---@brief [[
--- Adapters manager. Dispatches path resolution to the correct
--- adapter based on the current buffer's filetype.
---@brief ]]

local M = {}

-- Registry of adapters
local adapters = {
    require("focal.adapters.neo-tree"),
    require("focal.adapters.nvim-tree"),
    require("focal.adapters.oil"),
}

---Get list of supported filetypes
---@return string[]
function M.get_supported_filetypes()
    local fts = {}
    for _, adapter in ipairs(adapters) do
        table.insert(fts, adapter.filetype)
    end
    return fts
end

---Resolve the absolute path of the node under cursor
---@return string|nil path
function M.get_cursor_path()
    local ft = vim.bo.filetype
    
    for _, adapter in ipairs(adapters) do
        if adapter.filetype == ft then
            -- Found matching adapter
            local ok, path = pcall(adapter.get_path)
            if ok and path then
                return path
            end
        end
    end

	return nil
end

return M
