local M = {}

--- @type table<string, table>
local ft_map = {}

local builtin_modules = {
    "iris.sources.neo-tree",
    "iris.sources.nvim-tree",
    "iris.sources.oil",
    "iris.sources.snacks",
}

--- Validate and register a source adapter.
--- @param source table must have `filetype` (non-empty string) and `get_path` (function)
--- @return boolean
function M.register_source(source)
    if type(source) ~= "table" then
        return false
    end
    if type(source.filetype) ~= "string" or source.filetype == "" then
        return false
    end
    if type(source.get_path) ~= "function" then
        return false
    end
    ft_map[source.filetype] = source
    return true
end

--- O(1) lookup of a registered source by filetype.
--- @param filetype string
--- @return table|nil
function M.resolve(filetype)
    return ft_map[filetype]
end

--- Return an array of all registered filetype strings.
--- @return string[]
function M.get_registered_filetypes()
    local fts = {}
    for ft, _ in pairs(ft_map) do
        fts[#fts + 1] = ft
    end
    return fts
end

--- Load built-in source modules. Missing modules are silently skipped.
--- Only adds a source if its filetype is not already registered.
function M.load_builtins()
    for _, mod_name in ipairs(builtin_modules) do
        local ok, source = pcall(require, mod_name)
        if ok and type(source) == "table" and source.filetype then
            if not ft_map[source.filetype] then
                M.register_source(source)
            end
        end
    end
end

--- Clear the registry (for testing only).
function M._reset()
    ft_map = {}
end

return M
