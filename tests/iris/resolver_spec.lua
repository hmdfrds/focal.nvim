local H = require("tests.iris.helpers")
local Resolver = require("iris.resolver")

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            Resolver._reset()
        end,
    },
})

T["register_source() accepts valid source"] = function()
    MiniTest.expect.equality(Resolver.register_source(H.mock_source()), true)
end

T["register_source() rejects missing filetype"] = function()
    MiniTest.expect.equality(Resolver.register_source({ get_path = function() end }), false)
end

T["register_source() rejects missing get_path"] = function()
    MiniTest.expect.equality(Resolver.register_source({ filetype = "ft" }), false)
end

T["resolve() returns registered source"] = function()
    Resolver.register_source(H.mock_source({ filetype = "neo-tree" }))
    local source = Resolver.resolve("neo-tree")
    MiniTest.expect.no_equality(source, nil)
    MiniTest.expect.equality(source.filetype, "neo-tree")
end

T["resolve() returns nil for unknown filetype"] = function()
    MiniTest.expect.equality(Resolver.resolve("unknown"), nil)
end

T["get_registered_filetypes() returns all keys"] = function()
    Resolver.register_source(H.mock_source({ filetype = "a" }))
    Resolver.register_source(H.mock_source({ filetype = "b" }))
    local fts = Resolver.get_registered_filetypes()
    MiniTest.expect.equality(#fts, 2)
end

T["register_source() overwrites on collision with warning"] = function()
    local check = H.expect_notify("overwritten", vim.log.levels.WARN)
    Resolver.register_source(H.mock_source({ filetype = "ft", get_path = function() return "/old" end }))
    Resolver.register_source(H.mock_source({ filetype = "ft", get_path = function() return "/new" end }))
    local source = Resolver.resolve("ft")
    MiniTest.expect.equality(source.get_path(), "/new")
    MiniTest.expect.equality(check(), true)
end

return T
