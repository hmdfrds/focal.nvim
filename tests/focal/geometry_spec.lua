local T = MiniTest.new_set()
local Geo = require("focal.lib.geometry")

T["scale_to_fit() preserves aspect ratio for wide image"] = function()
    local g = Geo.scale_to_fit(800, 400, 10, 20, 40, 20, 10, 5)
    MiniTest.expect.equality(g.width, 40)
    MiniTest.expect.equality(g.height, 10)
end

T["scale_to_fit() preserves aspect ratio for tall image"] = function()
    local g = Geo.scale_to_fit(400, 800, 10, 20, 40, 20, 10, 5)
    MiniTest.expect.equality(g.width, 20)
    MiniTest.expect.equality(g.height, 20)
end

T["scale_to_fit() respects min dimensions"] = function()
    local g = Geo.scale_to_fit(10, 10, 10, 20, 40, 20, 15, 15)
    MiniTest.expect.equality(g.width, 15)
    MiniTest.expect.equality(g.height, 15)
end

T["scale_to_fit() guards against zero dimensions"] = function()
    local g = Geo.scale_to_fit(0, 0, 10, 20, 40, 20, 10, 5)
    MiniTest.expect.equality(g.width, 10)
    MiniTest.expect.equality(g.height, 5)
end

T["max_available() computes from config + terminal"] = function()
    local g = Geo.max_available(100, 50, 50, 50, 80, 40)
    MiniTest.expect.equality(g.width, 48)
    MiniTest.expect.equality(g.height, 23)
end

T["max_available() with zero margin"] = function()
    local g = Geo.max_available(100, 50, 50, 50, 80, 40, 0)
    MiniTest.expect.equality(g.width, 50)
    MiniTest.expect.equality(g.height, 25)
end

T["adaptive_position() places right and below by default"] = function()
    local pos = Geo.adaptive_position(20, 10, { screen_row = 5, screen_col = 10, win_width = 80, win_height = 40 }, 4, 1, 80)
    MiniTest.expect.equality(pos.col, 4)
    MiniTest.expect.equality(pos.row, 1)
end

T["adaptive_position() flips left when overflow right"] = function()
    local pos = Geo.adaptive_position(20, 10, { screen_row = 5, screen_col = 70, win_width = 80, win_height = 40 }, 4, 1, 80)
    MiniTest.expect.equality(pos.col, -24)
end

T["adaptive_position() flips above when overflow below"] = function()
    local pos = Geo.adaptive_position(20, 10, { screen_row = 35, screen_col = 10, win_width = 80, win_height = 40 }, 4, 1, 80)
    MiniTest.expect.equality(pos.row, -11)
end

T["overflow_margin() returns 2 for bordered, 0 for none"] = function()
    MiniTest.expect.equality(Geo.overflow_margin("rounded"), 2)
    MiniTest.expect.equality(Geo.overflow_margin("single"), 2)
    MiniTest.expect.equality(Geo.overflow_margin("none"), 0)
end

T["tabline_offset() returns -1 when tabline visible"] = function()
    local orig = vim.o.showtabline
    vim.o.showtabline = 2
    MiniTest.expect.equality(Geo.tabline_offset(), -1)
    vim.o.showtabline = orig
end

T["extract_extension() gets last extension"] = function()
    MiniTest.expect.equality(Geo.extract_extension("/foo/bar.png"), "png")
    MiniTest.expect.equality(Geo.extract_extension("/foo/bar.tar.gz"), "gz")
    MiniTest.expect.equality(Geo.extract_extension("/foo/.gitignore"), "gitignore")
    MiniTest.expect.equality(Geo.extract_extension("/foo/noext"), nil)
end

return T
