---@mod focal.health "Health Checks"
---@brief [[
--- Standard Neovim healthcheck for Focal.
--- Verifies dependencies (image.nvim) and valid adapter configurations.
---@brief ]]

local M = {}

local start = vim.health.start or vim.health.report_start
local ok = vim.health.ok or vim.health.report_ok
local warn = vim.health.warn or vim.health.report_warn
local error = vim.health.error or vim.health.report_error
local info = vim.health.info or vim.health.report_info

function M.check()
    start("focal.nvim report")

    -- 1. Check Dependencies
    local image_pkg_ok = pcall(require, "image")
    if image_pkg_ok then
        ok("image.nvim is installed.")

        -- Check Backend
        local backend_ok, backend_state = pcall(function()
            return require("image.state").backend
        end)
        if backend_ok and backend_state then
            ok("image.nvim backend is initialized: " .. (backend_state.name or "unknown"))
        else
            warn("image.nvim backend is NOT initialized. focal.nvim will attempt auto-init.")
        end
    else
        error("image.nvim is not installed. This plugin is required for rendering.")
    end

    -- 2. Check Adapters
    local Resolver = require("focal.resolver")
    local registered_fts = Resolver.get_supported_filetypes()

    if #registered_fts > 0 then
        ok(string.format("Registered adapters (%d): %s", #registered_fts, table.concat(registered_fts, ", ")))
    else
        warn("No adapters registered. Has setup() been called?")
    end

    local explorer_pkgs = {
        ["neo-tree"] = "neo-tree",
        ["nvim-tree"] = "nvim-tree.api",
        ["oil"] = "oil",
        ["snacks"] = "snacks",
    }

    local active_explorers = 0
    for name, pkg in pairs(explorer_pkgs) do
        if pcall(require, pkg) then
            ok(string.format("Explorer: '%s' is installed.", name))
            active_explorers = active_explorers + 1
        else
            info(string.format("Explorer: '%s' not found.", name))
        end
    end

    if active_explorers == 0 then
        warn("No supported file explorer found. focal.nvim will not trigger.")
    end

    -- 3. Check Configuration
    local focal_opts = require("focal").opts

    if focal_opts then
        ok("Configuration loaded.")
    else
        warn("Configuration not loaded (setup() not called?). Using defaults.")
    end
end

return M
