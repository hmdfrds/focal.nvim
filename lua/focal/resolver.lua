---@mod focal.resolver "Path Resolver"
---@brief [[
--- Adapter manager. Dispatches path resolution to the correct
--- adapter based on the current buffer's filetype.
--- Supports lazy-loading, O(1) filetype lookup, and custom adapter registration.
---@brief ]]

local Utils = require("focal.utils")

local M = {}

---@class FocalAdapter
---@field filetype string The filetype this adapter handles
---@field get_path fun(): string|nil Resolve absolute path under cursor

--- Hashmap: filetype -> adapter (O(1) lookup)
---@type table<string, FocalAdapter>
local ft_map = {}

--- Built-in adapter module paths (lazy-loaded on setup)
local builtin_modules = {
    "focal.adapters.neo-tree",
    "focal.adapters.nvim-tree",
    "focal.adapters.oil",
    "focal.adapters.snacks",
}

---Validate that an adapter conforms to the FocalAdapter interface.
---@param adapter table
---@param source string Description of where this adapter came from (for error messages)
---@return boolean
local function validate_adapter(adapter, source)
    if type(adapter.filetype) ~= "string" or adapter.filetype == "" then
        Utils.notify(
            string.format("Invalid adapter from '%s': 'filetype' must be a non-empty string", source),
            vim.log.levels.WARN
        )
        return false
    end
    if type(adapter.get_path) ~= "function" then
        Utils.notify(
            string.format("Invalid adapter from '%s': 'get_path' must be a function", source),
            vim.log.levels.WARN
        )
        return false
    end
    return true
end

---Load all built-in adapters. Called once from setup().
function M._load_builtins()
    ft_map = {}
    for _, mod_path in ipairs(builtin_modules) do
        local ok, adapter = pcall(require, mod_path)
        if ok and validate_adapter(adapter, mod_path) then
            ft_map[adapter.filetype] = adapter
        end
    end
end

---Register a custom adapter. Validates the interface before adding.
---@param adapter FocalAdapter
---@return boolean success
function M.register_adapter(adapter)
    if not validate_adapter(adapter, "custom") then
        return false
    end
    ft_map[adapter.filetype] = adapter
    return true
end

---Get list of supported filetypes from all registered adapters.
---@return string[]
function M.get_supported_filetypes()
    local fts = {}
    for ft, _ in pairs(ft_map) do
        fts[#fts + 1] = ft
    end
    return fts
end

---Resolve the absolute path of the node under cursor (O(1) filetype lookup).
---@return string|nil path
function M.get_cursor_path()
    local ft = vim.bo.filetype
    local adapter = ft_map[ft]
    if not adapter then return nil end

    local ok, path = Utils.safe_call(adapter.get_path)
    if ok and path and type(path) == "string" then
        return path
    end
    return nil
end

--- Extensions lookup table, set by init.lua during setup.
---@type table<string, boolean>
M._extensions_lookup = {}

---Resolve image path: adapter dispatch + extension filtering combined.
---@return string|nil path
function M.resolve_image_path()
    local path = M.get_cursor_path()
    if not path then return nil end

    local ext = path:match("^.+%.(.+)$")
    if ext and M._extensions_lookup[ext:lower()] then
        return path
    end
    return nil
end

return M
