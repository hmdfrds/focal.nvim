---@mod iris.health "Health Check"
---@brief [[
--- Standard Neovim healthcheck for iris.nvim.
---@brief ]]

local M = {}

function M.check()
    vim.health.start("iris.nvim report")

    -- 1. Rendering backends
    local has_any = false
    local img_ok = pcall(require, "image")
    if img_ok then
        vim.health.ok("image.nvim is installed.")
        has_any = true
    else
        vim.health.info("image.nvim is not installed.")
    end

    if vim.fn.executable("chafa") == 1 then
        vim.health.ok("chafa is installed.")
        has_any = true
        local ver_str = vim.fn.system("chafa --version"):match("^[^\n]+") or "unknown"
        vim.health.info("chafa version: " .. ver_str)
        local major, minor = ver_str:match("(%d+)%.(%d+)")
        if major and minor then
            if tonumber(major) < 1 or (tonumber(major) == 1 and tonumber(minor) < 12) then
                vim.health.warn("chafa version < 1.12 detected. Some features may not work correctly. Consider upgrading.")
            end
        end
    else
        vim.health.info("chafa is not installed.")
    end

    if not has_any then
        vim.health.error("No rendering backend available. Install image.nvim or chafa.")
    end

    -- 2. Terminal detection
    local Terminal = require("iris.terminal")
    local term = Terminal.detect()
    if term.has_graphics then
        vim.health.ok(string.format("Terminal: %s (%s protocol)", term.terminal or "unknown", term.protocol or "unknown"))
    else
        vim.health.info(string.format("Terminal '%s' — no graphics protocol. chafa will be used.", term.terminal or "unknown"))
    end

    if term.in_tmux then
        vim.health.warn("Inside tmux. Add `set -g allow-passthrough on` to tmux.conf for image.nvim.")
    end
    if term.in_ssh then
        vim.health.info("Inside SSH session.")
    end
    if term.in_mosh then
        vim.health.info("Inside mosh. Graphics protocols not supported; chafa will be used.")
    end

    -- 3. Sources
    local Resolver = require("iris.resolver")
    local fts = Resolver.get_registered_filetypes()
    if #fts > 0 then
        vim.health.ok(string.format("Sources (%d): %s", #fts, table.concat(fts, ", ")))
    else
        vim.health.warn("No sources registered. Has setup() been called?")
    end

    -- 4. Config & updatetime
    if vim.o.updatetime > 1000 then
        vim.health.warn(string.format("updatetime is %dms. Consider lowering to 300-500ms for responsive previews.", vim.o.updatetime))
    else
        vim.health.ok(string.format("updatetime: %dms", vim.o.updatetime))
    end

    -- 5. Cache stats (if setup has been called)
    local iris_ok, iris = pcall(require, "iris")
    if iris_ok and iris.status then
        local status = iris.status()
        if status and status.cache then
            local c = status.cache
            vim.health.ok(string.format(
                "Cache: %d entries, %d bytes, %d hits, %d misses, %d evictions",
                c.entries or 0, c.bytes or 0, c.hits or 0, c.misses or 0, c.evictions or 0
            ))
        end
    end

    -- 6. Config cross-validation
    local Config = require("iris.config")
    local cfg_ok, cfg = pcall(Config.merge, {})
    if cfg_ok and cfg then
        if cfg.min_width > cfg.max_width then
            vim.health.warn(string.format("config.min_width (%d) > config.max_width (%d)", cfg.min_width, cfg.max_width))
        end
        if cfg.min_height > cfg.max_height then
            vim.health.warn(string.format("config.min_height (%d) > config.max_height (%d)", cfg.min_height, cfg.max_height))
        end
    end
end

return M
