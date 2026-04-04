local M = {}

--- @type IrisRenderer[]
local renderers = {}

--- @type table<string, IrisRenderer[]>  extension -> renderers sorted by priority desc
local ext_map = {}

--- @type table<string, boolean>|nil  nil means all extensions allowed
local whitelist = nil

local builtin_paths = {
    "iris.renderers.image",
    "iris.renderers.chafa",
}

--- Rebuild ext_map from the current renderers list.
local function rebuild_ext_map()
    ext_map = {}
    for _, r in ipairs(renderers) do
        for _, ext in ipairs(r.extensions) do
            if not ext_map[ext] then
                ext_map[ext] = {}
            end
            table.insert(ext_map[ext], r)
        end
    end
    -- Sort each extension's renderer list by priority descending
    for _, list in pairs(ext_map) do
        table.sort(list, function(a, b)
            return a.priority > b.priority
        end)
    end
end

--- Validate that a renderer has all required fields with correct types.
--- @param renderer table
--- @return boolean
local function validate(renderer)
    if type(renderer.name) ~= "string" or renderer.name == "" then
        return false
    end
    if type(renderer.extensions) ~= "table" or #renderer.extensions == 0 then
        return false
    end
    if type(renderer.priority) ~= "number" then
        return false
    end
    if type(renderer.is_available) ~= "function" then
        return false
    end
    if type(renderer.get_geometry) ~= "function" then
        return false
    end
    if type(renderer.render) ~= "function" then
        return false
    end
    if type(renderer.clear) ~= "function" then
        return false
    end
    if type(renderer.cleanup) ~= "function" then
        return false
    end
    return true
end

--- Register a renderer. Returns true on success, false on validation failure.
--- @param renderer IrisRenderer
--- @return boolean
function M.register_renderer(renderer)
    if not validate(renderer) then
        return false
    end
    table.insert(renderers, renderer)
    rebuild_ext_map()
    return true
end

--- Find the highest-priority available renderer for a given extension.
--- Respects the whitelist if set.
--- @param extension string
--- @return IrisRenderer|nil
function M.find_renderer(extension)
    if whitelist and not whitelist[extension] then
        return nil
    end
    local candidates = ext_map[extension]
    if not candidates then
        return nil
    end
    for _, r in ipairs(candidates) do
        if r.is_available() then
            return r
        end
    end
    return nil
end

--- Find a renderer by its name.
--- @param name string
--- @return IrisRenderer|nil
function M.find_by_name(name)
    for _, r in ipairs(renderers) do
        if r.name == name then
            return r
        end
    end
    return nil
end

--- Return a sorted unique array of all supported extensions across all renderers.
--- @return string[]
function M.get_supported_extensions()
    local seen = {}
    local result = {}
    for _, r in ipairs(renderers) do
        for _, ext in ipairs(r.extensions) do
            if not seen[ext] then
                seen[ext] = true
                table.insert(result, ext)
            end
        end
    end
    table.sort(result)
    return result
end

--- Set the extension whitelist. Pass nil to allow all extensions.
--- @param exts string[]|nil
function M.set_whitelist(exts)
    if exts == nil then
        whitelist = nil
        return
    end
    whitelist = {}
    for _, ext in ipairs(exts) do
        whitelist[ext] = true
    end
end

--- Load built-in renderer modules.
function M.load_builtins()
    for _, path in ipairs(builtin_paths) do
        local ok, mod = pcall(require, path)
        if ok and mod and type(mod.register) == "function" then
            mod.register(M)
        end
    end
end

--- Reset all state. For testing only.
function M._reset()
    renderers = {}
    ext_map = {}
    whitelist = nil
end

return M
