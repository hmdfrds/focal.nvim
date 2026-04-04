local T = MiniTest.new_set()
local H = require("tests.iris.helpers")

T["setup() with defaults does not error"] = function()
    -- Reset module state
    package.loaded["iris"] = nil
    package.loaded["iris.resolver"] = nil
    package.loaded["iris.renderer"] = nil
    package.loaded["iris.config"] = nil
    package.loaded["iris.preview"] = nil
    package.loaded["iris.window"] = nil
    require("iris").setup({})
end

T["setup() with invalid config warns and uses defaults"] = function()
    package.loaded["iris"] = nil
    package.loaded["iris.resolver"] = nil
    package.loaded["iris.renderer"] = nil
    package.loaded["iris.config"] = nil
    package.loaded["iris.preview"] = nil
    package.loaded["iris.window"] = nil
    local check = H.expect_notify("config.min_width must be")
    require("iris").setup({ min_width = "banana" })
    MiniTest.expect.equality(check(), true)
end

T["enable/disable toggle works"] = function()
    package.loaded["iris"] = nil
    package.loaded["iris.resolver"] = nil
    package.loaded["iris.renderer"] = nil
    package.loaded["iris.config"] = nil
    package.loaded["iris.preview"] = nil
    package.loaded["iris.window"] = nil
    local iris = require("iris")
    iris.setup({})
    MiniTest.expect.equality(iris.is_enabled(), true)
    iris.disable()
    MiniTest.expect.equality(iris.is_enabled(), false)
    iris.enable()
    MiniTest.expect.equality(iris.is_enabled(), true)
end

T["status() returns structured data"] = function()
    package.loaded["iris"] = nil
    package.loaded["iris.resolver"] = nil
    package.loaded["iris.renderer"] = nil
    package.loaded["iris.config"] = nil
    package.loaded["iris.preview"] = nil
    package.loaded["iris.window"] = nil
    local iris = require("iris")
    iris.setup({})
    local s = iris.status()
    MiniTest.expect.equality(type(s.state), "string")
    MiniTest.expect.equality(type(s.generation), "number")
    MiniTest.expect.equality(type(s.terminal), "table")
end

return T
