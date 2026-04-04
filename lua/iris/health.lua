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
        local ver = vim.fn.system("chafa --version"):match("^[^\n]+") or "unknown"
        vim.health.info("chafa version: " .. ver)
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
end

return M
