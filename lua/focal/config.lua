---@mod focal.config "Configuration"
---@brief [[
--- Config schema, validation, and merging for focal.nvim.
---@brief ]]

---@class FocalChafaConfig
---@field format string
---@field color_space string?
---@field animate boolean
---@field max_output_bytes integer

---@class FocalConfig
---@field enabled boolean
---@field border string|string[]|string[][]
---@field winblend integer
---@field zindex integer
---@field title boolean
---@field min_width integer
---@field min_height integer
---@field max_width integer
---@field max_height integer
---@field max_width_percent number
---@field max_height_percent number
---@field max_file_size_mb number
---@field debounce_ms integer
---@field col_offset integer
---@field row_offset integer
---@field backend FocalBackend?
---@field chafa FocalChafaConfig
---@field extensions string[]?
---@field render_timeout_ms integer
---@field on_show fun(path: string, renderer_name: string)?
---@field on_hide fun()?

local M = {}

---@type FocalConfig
M.defaults = {
    enabled = true,
    border = "rounded",
    winblend = 0,
    zindex = 100,
    title = true,
    min_width = 10,
    min_height = 5,
    max_width = 80,
    max_height = 40,
    max_width_percent = 50,
    max_height_percent = 50,
    max_file_size_mb = 5,
    debounce_ms = 0,
    col_offset = 4,
    row_offset = 1,
    backend = nil,
    chafa = {
        format = "symbols",
        color_space = nil,
        animate = false,
        max_output_bytes = 1048576,
    },
    extensions = nil,
    render_timeout_ms = 10000,
    on_show = nil,
    on_hide = nil,
}

--- Expected types for each top-level config key.
---@type table<string, string>
local expected_types = {
    enabled = "boolean",
    border = "string|table",
    winblend = "number",
    zindex = "number",
    title = "boolean",
    min_width = "number",
    min_height = "number",
    max_width = "number",
    max_height = "number",
    max_width_percent = "number",
    max_height_percent = "number",
    max_file_size_mb = "number",
    debounce_ms = "number",
    col_offset = "number",
    row_offset = "number",
    backend = "string",
    chafa = "table",
    extensions = "table",
    render_timeout_ms = "number",
    on_show = "function",
    on_hide = "function",
}

--- Count shared characters between two strings (simple similarity metric).
---@param a string
---@param b string
---@return integer
local function char_overlap(a, b)
    local count = 0
    local used = {}
    for i = 1, #b do
        used[i] = false
    end
    for i = 1, #a do
        local ca = a:sub(i, i)
        for j = 1, #b do
            if not used[j] and b:sub(j, j) == ca then
                used[j] = true
                count = count + 1
                break
            end
        end
    end
    return count
end

--- Find the closest known key to an unknown key.
---@param unknown string
---@return string?
local function closest_key(unknown)
    local best_key = nil
    local best_score = 0
    for key, _ in pairs(expected_types) do
        local score = char_overlap(unknown, key)
        if score > best_score then
            best_score = score
            best_key = key
        end
    end
    -- Only suggest if the overlap is meaningful (at least half the shorter string)
    local min_len = math.min(#unknown, #(best_key or ""))
    if best_key and best_score >= math.ceil(min_len / 2) then
        return best_key
    end
    return nil
end

--- Warn the user via vim.notify at WARN level.
---@param msg string
local function warn(msg)
    vim.notify(msg, vim.log.levels.WARN)
end

--- Validate type of a single option, returning the value or the default.
---@param key string
---@param value any
---@param default any
---@return any
local function validate_type(key, value, default)
    local expect = expected_types[key]
    if expect == nil then
        return value
    end
    -- nil values are allowed (keep default via deep_extend behavior)
    if value == nil then
        return default
    end
    local valid = false
    for part in expect:gmatch("[^|]+") do
        if type(value) == part then
            valid = true
            break
        end
    end
    if not valid then
        warn(string.format("[focal] config.%s must be %s (got %s), using default", key, expect, type(value)))
        return default
    end
    return value
end

--- Swap min/max if min > max and warn.
---@param cfg table
---@param min_key string
---@param max_key string
local function validate_min_max(cfg, min_key, max_key)
    if cfg[min_key] and cfg[max_key] and cfg[min_key] > cfg[max_key] then
        warn(
            string.format(
                "[focal] config.%s (%d) > config.%s (%d), swapping",
                min_key,
                cfg[min_key],
                max_key,
                cfg[max_key]
            )
        )
        cfg[min_key], cfg[max_key] = cfg[max_key], cfg[min_key]
    end
end

--- Merge user options with defaults, validate, and return a complete FocalConfig.
---@param user_opts table?
---@return FocalConfig
function M.merge(user_opts)
    user_opts = user_opts or {}

    -- Warn about unknown keys and suggest closest match.
    for key, _ in pairs(user_opts) do
        if expected_types[key] == nil then
            local suggestion = closest_key(key)
            if suggestion then
                warn(string.format("[focal] Unknown config key '%s'. Did you mean '%s'?", key, suggestion))
            else
                warn(string.format("[focal] Unknown config key '%s'.", key))
            end
        end
    end

    -- Type-validate each known top-level key; replace invalid values with nil
    -- so that deep_extend will pick up the default instead.
    local clean = {}
    for key, _ in pairs(user_opts) do
        if expected_types[key] ~= nil then
            local validated = validate_type(key, user_opts[key], M.defaults[key])
            if validated ~= M.defaults[key] or user_opts[key] ~= nil then
                clean[key] = validated
            end
        end
    end

    -- Deep-extend defaults with cleaned user opts.
    local cfg = vim.tbl_deep_extend("force", {}, M.defaults, clean)

    -- Array fields: replace rather than merge.
    if clean.extensions ~= nil then
        cfg.extensions = clean.extensions
    end

    -- Cross-field validation.
    validate_min_max(cfg, "min_width", "max_width")
    validate_min_max(cfg, "min_height", "max_height")

    -- Guard against NaN and infinity for all numeric keys.
    for key, expect in pairs(expected_types) do
        if expect:find("number") and type(cfg[key]) == "number" then
            if cfg[key] ~= cfg[key] or cfg[key] == math.huge or cfg[key] == -math.huge then
                warn(string.format("[focal] config.%s is NaN or infinite, using default", key))
                cfg[key] = M.defaults[key]
            end
        end
    end

    -- Range clamping.
    for _, dim_key in ipairs({ "min_width", "min_height", "max_width", "max_height" }) do
        if cfg[dim_key] and cfg[dim_key] < 1 then
            warn(string.format("[focal] config.%s clamped to 1 (was %d)", dim_key, cfg[dim_key]))
            cfg[dim_key] = 1
        end
    end
    if cfg.winblend then
        cfg.winblend = math.max(0, math.min(100, cfg.winblend))
    end
    if cfg.max_width_percent then
        cfg.max_width_percent = math.max(1, math.min(100, cfg.max_width_percent))
    end
    if cfg.max_height_percent then
        cfg.max_height_percent = math.max(1, math.min(100, cfg.max_height_percent))
    end
    if cfg.zindex and cfg.zindex < 1 then
        warn("[focal] config.zindex must be >= 1, using default")
        cfg.zindex = M.defaults.zindex
    end
    if cfg.debounce_ms and cfg.debounce_ms < 0 then
        cfg.debounce_ms = 0
    end
    if cfg.render_timeout_ms and cfg.render_timeout_ms < 100 then
        warn("[focal] config.render_timeout_ms must be >= 100, using default")
        cfg.render_timeout_ms = M.defaults.render_timeout_ms
    end
    if cfg.max_file_size_mb and cfg.max_file_size_mb <= 0 then
        warn("[focal] config.max_file_size_mb must be > 0, using default")
        cfg.max_file_size_mb = M.defaults.max_file_size_mb
    end

    -- Warn about unknown chafa sub-keys.
    if type(user_opts.chafa) == "table" then
        local chafa_known = { format = true, color_space = true, animate = true, max_output_bytes = true }
        for key, _ in pairs(user_opts.chafa) do
            if not chafa_known[key] then
                local best_key = nil
                local best_score = 0
                for known_key, _ in pairs(chafa_known) do
                    local score = char_overlap(key, known_key)
                    if score > best_score then
                        best_score = score
                        best_key = known_key
                    end
                end
                local min_len = math.min(#key, #(best_key or ""))
                if best_key and best_score >= math.ceil(min_len / 2) then
                    warn(string.format("[focal] Unknown chafa key '%s'. Did you mean '%s'?", key, best_key))
                else
                    warn(string.format("[focal] Unknown chafa key '%s'.", key))
                end
            end
        end
    end

    -- Validate chafa sub-table fields.
    if type(cfg.chafa.format) ~= "string" then
        warn("[focal] config.chafa.format must be string, using default")
        cfg.chafa.format = M.defaults.chafa.format
    end
    if type(cfg.chafa.animate) ~= "boolean" then
        warn("[focal] config.chafa.animate must be boolean, using default")
        cfg.chafa.animate = M.defaults.chafa.animate
    end
    if type(cfg.chafa.max_output_bytes) ~= "number" then
        warn("[focal] config.chafa.max_output_bytes must be number, using default")
        cfg.chafa.max_output_bytes = M.defaults.chafa.max_output_bytes
    elseif
        cfg.chafa.max_output_bytes ~= cfg.chafa.max_output_bytes
        or cfg.chafa.max_output_bytes == math.huge
        or cfg.chafa.max_output_bytes == -math.huge
        or cfg.chafa.max_output_bytes <= 0
    then
        warn("[focal] config.chafa.max_output_bytes is invalid, using default")
        cfg.chafa.max_output_bytes = M.defaults.chafa.max_output_bytes
    end
    if cfg.chafa.color_space ~= nil and type(cfg.chafa.color_space) ~= "string" then
        warn("[focal] config.chafa.color_space must be string or nil, using default")
        cfg.chafa.color_space = M.defaults.chafa.color_space
    end

    return cfg
end

return M
