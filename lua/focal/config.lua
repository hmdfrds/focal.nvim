---@mod focal.config "Configuration Module"
---@brief [[
--- Handles user configuration merging and validation.
---@brief ]]

local Utils = require("focal.utils")

local M = {}

---@class FocalConfig
---@field debug boolean Enable debug notifications
---@field min_width number Minimum width of preview window (cells)
---@field min_height number Minimum height of preview window (cells)
---@field max_width_pct number Max width as % of editor
---@field max_height_pct number Max height as % of editor
---@field max_cells number Absolute max cells to prevent overflow
---@field extensions string[] List of supported image extensions
---@field max_file_size_mb number Max file size in MB to preview
---@field on_show? fun(path: string) Called after image preview is shown
---@field on_hide? fun() Called after image preview is hidden

---@type FocalConfig
M.defaults = {
    debug = false,
    min_width = 10,
    min_height = 5,
    max_width_pct = 50,
    max_height_pct = 50,
    max_cells = 60,
    max_file_size_mb = 5,
    extensions = { "png", "jpg", "jpeg", "webp", "gif", "bmp" },
    on_show = nil,
    on_hide = nil,
}

---@class FocalConfigRule
---@field check fun(val: any): boolean
---@field msg string

---@type table<string, FocalConfigRule>
local rules = {
    debug = {
        check = function(v)
            return type(v) == "boolean"
        end,
        msg = "must be a boolean",
    },
    min_width = {
        check = function(v)
            return type(v) == "number" and v > 0 and math.floor(v) == v
        end,
        msg = "must be a positive integer",
    },
    min_height = {
        check = function(v)
            return type(v) == "number" and v > 0 and math.floor(v) == v
        end,
        msg = "must be a positive integer",
    },
    max_width_pct = {
        check = function(v)
            return type(v) == "number" and v >= 1 and v <= 100
        end,
        msg = "must be a number between 1 and 100",
    },
    max_height_pct = {
        check = function(v)
            return type(v) == "number" and v >= 1 and v <= 100
        end,
        msg = "must be a number between 1 and 100",
    },
    max_cells = {
        check = function(v)
            return type(v) == "number" and v > 0
        end,
        msg = "must be a positive number",
    },
    max_file_size_mb = {
        check = function(v)
            return type(v) == "number" and v > 0
        end,
        msg = "must be a positive number",
    },
    extensions = {
        check = function(v)
            if type(v) ~= "table" then
                return false
            end
            for _, ext in ipairs(v) do
                if type(ext) ~= "string" then
                    return false
                end
            end
            return true
        end,
        msg = "must be a table of strings",
    },
    on_show = {
        check = function(v)
            return v == nil or type(v) == "function"
        end,
        msg = "must be a function or nil",
    },
    on_hide = {
        check = function(v)
            return v == nil or type(v) == "function"
        end,
        msg = "must be a function or nil",
    },
}

---Validate opts, warn and fallback to default for invalid fields.
---@param opts FocalConfig
---@return FocalConfig
local function validate(opts)
    for key, rule in pairs(rules) do
        if opts[key] ~= nil and not rule.check(opts[key]) then
            Utils.notify(
                string.format("config.%s %s (got %s), using default", key, rule.msg, type(opts[key])),
                vim.log.levels.WARN
            )
            opts[key] = M.defaults[key]
        end
    end
    return opts
end

---Validate and merge user options
---@param user_opts? FocalConfig
---@return FocalConfig
function M.merge(user_opts)
    local opts = vim.tbl_deep_extend("force", M.defaults, user_opts or {})

    -- Fix array merging for extensions (replace instead of merge)
    if user_opts and user_opts.extensions then
        opts.extensions = user_opts.extensions
    end

    return validate(opts)
end

return M
