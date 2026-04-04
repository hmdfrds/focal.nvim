local H = require("tests.focal.helpers")
local Registry = require("focal.renderer")

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            Registry._reset()
        end,
    },
})

T["register_renderer() accepts valid renderer"] = function()
    MiniTest.expect.equality(Registry.register_renderer(H.mock_renderer()), true)
end

T["register_renderer() rejects empty name"] = function()
    MiniTest.expect.equality(Registry.register_renderer(H.mock_renderer({ name = "" })), false)
end

T["register_renderer() rejects empty extensions"] = function()
    MiniTest.expect.equality(Registry.register_renderer(H.mock_renderer({ extensions = {} })), false)
end

T["find_renderer() returns highest priority available"] = function()
    Registry.register_renderer(H.mock_renderer({ name = "low", priority = 10 }))
    Registry.register_renderer(H.mock_renderer({ name = "high", priority = 100 }))
    MiniTest.expect.equality(Registry.find_renderer("png").name, "high")
end

T["find_renderer() skips unavailable"] = function()
    Registry.register_renderer(H.mock_renderer({ name = "dead", priority = 100, is_available = function() return false end }))
    Registry.register_renderer(H.mock_renderer({ name = "alive", priority = 50 }))
    MiniTest.expect.equality(Registry.find_renderer("png").name, "alive")
end

T["find_renderer() returns nil for unknown extension"] = function()
    Registry.register_renderer(H.mock_renderer({ extensions = { "jpg" } }))
    MiniTest.expect.equality(Registry.find_renderer("pdf"), nil)
end

T["find_by_name() returns matching renderer"] = function()
    Registry.register_renderer(H.mock_renderer({ name = "chafa" }))
    MiniTest.expect.equality(Registry.find_by_name("chafa").name, "chafa")
end

T["find_by_name() returns nil for unknown name"] = function()
    MiniTest.expect.equality(Registry.find_by_name("nope"), nil)
end

T["get_supported_extensions() returns union"] = function()
    Registry.register_renderer(H.mock_renderer({ extensions = { "png", "jpg" } }))
    Registry.register_renderer(H.mock_renderer({ name = "r2", extensions = { "jpg", "svg" } }))
    local exts = Registry.get_supported_extensions()
    table.sort(exts)
    MiniTest.expect.equality(exts, { "jpg", "png", "svg" })
end

T["find_renderer() respects extensions whitelist"] = function()
    Registry.register_renderer(H.mock_renderer({ extensions = { "png", "svg" } }))
    Registry.set_whitelist({ "png" })
    MiniTest.expect.no_equality(Registry.find_renderer("png"), nil)
    MiniTest.expect.equality(Registry.find_renderer("svg"), nil)
    Registry.set_whitelist(nil)
end

return T
