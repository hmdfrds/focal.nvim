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
        local backend_ok, backend_state = pcall(function() return require("image.state").backend end)
        if backend_ok and backend_state then
            ok("image.nvim backend is initialized: " .. (backend_state.name or "unknown"))
        else
            warn("image.nvim backend is NOT initialized. focal.nvim will attempt auto-init.")
        end
    else
        error("image.nvim is not installed. This plugin is required for rendering.")
    end

    -- 2. Check Adapters
    local adapters = {
        ["neo-tree"] = "neo-tree",
        ["nvim-tree"] = "nvim-tree.api",
        ["oil"] = "oil"
    }

    local active_adapters = 0
    for name, pkg in pairs(adapters) do
        if pcall(require, pkg) then
            ok(string.format("Adapter: '%s' is active (plugin installed).", name))
            active_adapters = active_adapters + 1
        else
            info(string.format("Adapter: '%s' not found (plugin not installed).", name))
        end
    end

    if active_adapters == 0 then
        warn("No supported file explorer found. focal.nvim will not trigger.")
    end

    -- 3. Check Configuration
    local config = require("focal.config")
    local focal_opts = require("focal").opts
    
    if focal_opts then
        ok("Configuration loaded.")
    else
        warn("Configuration not loaded (setup() not called?). Using defaults.")
    end
end

return M
