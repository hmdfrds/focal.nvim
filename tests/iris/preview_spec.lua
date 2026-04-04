local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            require("iris.resolver")._reset()
            require("iris.renderer")._reset()
        end,
        post_case = function()
            if _G._test_pm then
                pcall(_G._test_pm.hide, _G._test_pm)
                _G._test_pm = nil
            end
        end,
    },
})

local H = require("tests.iris.helpers")
local Preview = require("iris.preview")
local Window = require("iris.window")
local Resolver = require("iris.resolver")
local Renderer = require("iris.renderer")
local Cache = require("iris.lib.cache")
local Config = require("iris.config")

local function make_pm()
    local config = Config.merge({})
    local wm = Window.new({ border = "rounded", winblend = 0, zindex = 100, col_offset = 4, row_offset = 1 })
    local pm = Preview.new({
        config = config,
        resolver = Resolver,
        renderer_registry = Renderer,
        window_mgr = wm,
        cache = Cache.new(),
    })
    _G._test_pm = pm
    return pm
end

T["initial state is idle"] = function()
    local pm = make_pm()
    MiniTest.expect.equality(pm:get_state(), "idle")
end

T["generation starts at 0"] = function()
    local pm = make_pm()
    MiniTest.expect.equality(pm:get_generation(), 0)
end

T["hide() increments generation"] = function()
    local pm = make_pm()
    pm:hide()
    MiniTest.expect.equality(pm:get_generation(), 1)
end

T["hide() is idempotent"] = function()
    local pm = make_pm()
    pm:hide()
    pm:hide()
    MiniTest.expect.equality(pm:get_state(), "idle")
end

T["hide() from any state returns to idle"] = function()
    local pm = make_pm()
    pm._state = "rendering"
    pm:hide()
    MiniTest.expect.equality(pm:get_state(), "idle")
end

T["status() returns structured data"] = function()
    local pm = make_pm()
    local s = pm:status()
    MiniTest.expect.equality(s.state, "idle")
    MiniTest.expect.equality(type(s.generation), "number")
    MiniTest.expect.equality(type(s.cache), "table")
end

return T
