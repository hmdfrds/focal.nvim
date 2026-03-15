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

    -- 1. Check Rendering Backends
    local has_any_backend = false

    -- image.nvim
    local image_pkg_ok = pcall(require, "image")
    if image_pkg_ok then
        ok("image.nvim is installed.")
        has_any_backend = true

        local backend_ok, is_initialized = pcall(function()
            local api = require("image")
            api.get_images()
            return api.is_enabled()
        end)
        if backend_ok and is_initialized then
            ok("image.nvim is initialized and enabled.")
        else
            warn("image.nvim is NOT initialized or disabled. focal.nvim will attempt auto-init.")
        end
    else
        info("image.nvim is not installed.")
    end

    -- chafa
    if vim.fn.executable("chafa") == 1 then
        ok("chafa is installed.")
        has_any_backend = true

        local chafa_version = vim.fn.system("chafa --version"):match("^[^\n]+") or "unknown"
        info("chafa version: " .. chafa_version)
    else
        info("chafa is not installed.")
    end

    if not has_any_backend then
        error("No rendering backend available. Install image.nvim (with a supported terminal) or chafa.")
    end

    -- Terminal Graphics Protocol Detection
    local Terminal = require("focal.terminal")
    local term_info = Terminal.detect()

    if term_info.has_graphics then
        ok(
            string.format(
                "Terminal supports graphics: %s (%s protocol)",
                term_info.terminal or "unknown",
                term_info.protocol or "unknown"
            )
        )
    else
        info(
            string.format(
                "Terminal does not support graphics protocols (terminal: %s). chafa will be used as fallback.",
                term_info.terminal or "unknown"
            )
        )
    end

    if term_info.in_tmux then
        info("Running inside tmux. Graphics passthrough depends on tmux allow-passthrough setting.")
    end

    if term_info.in_ssh then
        info("Running inside SSH session. Graphics protocol support may be limited.")
    end

    -- Report active backend
    local focal_opts = require("focal").opts
    if focal_opts then
        info(string.format("Configured backend: '%s'", focal_opts.backend or "auto"))
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
