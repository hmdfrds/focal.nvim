local T = MiniTest.new_set()
local Guard = require("focal.lib.guard")

T["new() creates guard with correct fields"] = function()
    local g = Guard.new(1, 42)
    MiniTest.expect.equality(g.generation, 1)
    MiniTest.expect.equality(g.ctx_buf, 42)
end

T["is_valid() returns true when generation and buf match"] = function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    local g = Guard.new(5, buf)
    MiniTest.expect.equality(Guard.is_valid(g, 5), true)
    vim.api.nvim_buf_delete(buf, { force = true })
end

T["is_valid() returns false when generation is stale"] = function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    local g = Guard.new(5, buf)
    MiniTest.expect.equality(Guard.is_valid(g, 6), false)
    vim.api.nvim_buf_delete(buf, { force = true })
end

T["is_valid() returns false when buffer changed"] = function()
    local buf1 = vim.api.nvim_create_buf(false, true)
    local buf2 = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf1)
    local g = Guard.new(5, buf1)
    vim.api.nvim_set_current_buf(buf2)
    MiniTest.expect.equality(Guard.is_valid(g, 5), false)
    vim.api.nvim_buf_delete(buf1, { force = true })
    vim.api.nvim_buf_delete(buf2, { force = true })
end

return T
