---@mod focal.renderer "Renderer Registry"

local M = {}

--- @type FocalRenderer[]
local renderers = {}

--- @type table<string, FocalRenderer[]>  extension -> renderers sorted by priority desc
local ext_map = {}

--- @type table<string, boolean>|nil  nil means all extensions allowed
local whitelist = nil

local builtin_paths = {
    "focal.renderers.image",
    "focal.renderers.chafa",
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
    local function fail(reason)
        vim.notify(
            string.format("[focal] Renderer validation failed for '%s': %s", tostring(renderer.name), reason),
            vim.log.levels.WARN
        )
        return false
    end
    if type(renderer.name) ~= "string" or renderer.name == "" then
        return fail("name must be a non-empty string")
    end
    if type(renderer.extensions) ~= "table" or #renderer.extensions == 0 then
        return fail("extensions must be a non-empty table")
    end
    if type(renderer.priority) ~= "number" then
        return fail("priority must be a number")
    end
    if type(renderer.is_available) ~= "function" then
        return fail("is_available must be a function")
    end
    if type(renderer.get_geometry) ~= "function" then
        return fail("get_geometry must be a function")
    end
    if type(renderer.render) ~= "function" then
        return fail("render must be a function")
    end
    if type(renderer.clear) ~= "function" then
        return fail("clear must be a function")
    end
    if type(renderer.cleanup) ~= "function" then
        return fail("cleanup must be a function")
    end
    if type(renderer.needs_terminal) ~= "boolean" then
        return fail("needs_terminal must be a boolean")
    end
    return true
end

--- Register a renderer. Returns true on success, false on validation failure.
--- @param renderer FocalRenderer
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
--- @return FocalRenderer|nil
function M.find_renderer(extension)
    if whitelist and not whitelist[extension] then
        return nil
    end
    local candidates = ext_map[extension]
    if not candidates then
        return nil
    end
    for _, r in ipairs(candidates) do
        local avail_ok, avail = pcall(r.is_available)
        if avail_ok and avail then
            return r
        end
    end
    return nil
end

--- Find a renderer by its name.
--- @param name string
--- @return FocalRenderer|nil
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

--- Return all registered renderers (deduplicated by name).
--- @return FocalRenderer[]
function M.get_all_renderers()
    local seen = {}
    local result = {}
    for _, r in ipairs(renderers) do
        if not seen[r.name] then
            seen[r.name] = true
            result[#result + 1] = r
        end
    end
    return result
end

--- Load built-in renderer modules. Skips already-registered names.
function M.load_builtins()
    for _, path in ipairs(builtin_paths) do
        local ok, mod = pcall(require, path)
        if ok and mod and type(mod.register) == "function" then
            -- Temporarily wrap register_renderer to prevent duplicates.
            local orig = M.register_renderer
            M.register_renderer = function(renderer)
                local exists = false
                for _, r in ipairs(renderers) do
                    if r.name == renderer.name then
                        exists = true
                        break
                    end
                end
                if not exists then
                    return orig(renderer)
                end
                return true
            end
            local reg_ok, reg_err = pcall(mod.register, M)
            M.register_renderer = orig
            if not reg_ok then
                vim.notify(
                    string.format("[focal] Failed to load builtin renderer '%s': %s", path, tostring(reg_err)),
                    vim.log.levels.WARN
                )
            end
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
