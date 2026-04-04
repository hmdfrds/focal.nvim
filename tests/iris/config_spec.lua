local T = MiniTest.new_set()
local Config = require("iris.config")

T["defaults returned when no user opts"] = function()
    local cfg = Config.merge({})
    MiniTest.expect.equality(cfg.enabled, true)
    MiniTest.expect.equality(cfg.debug, false)
    MiniTest.expect.equality(cfg.border, "rounded")
    MiniTest.expect.equality(cfg.zindex, 100)
    MiniTest.expect.equality(cfg.min_width, 10)
    MiniTest.expect.equality(cfg.max_file_size_mb, 5)
end

T["user opts override defaults"] = function()
    local cfg = Config.merge({ zindex = 200, debug = true })
    MiniTest.expect.equality(cfg.zindex, 200)
    MiniTest.expect.equality(cfg.debug, true)
    MiniTest.expect.equality(cfg.border, "rounded")
end

T["invalid types fallback to default"] = function()
    local cfg = Config.merge({ min_width = "banana" })
    MiniTest.expect.equality(cfg.min_width, 10)
end

T["cross-field validation swaps min > max"] = function()
    local cfg = Config.merge({ min_width = 100, max_width = 10 })
    MiniTest.expect.equality(cfg.min_width, 10)
    MiniTest.expect.equality(cfg.max_width, 100)
end

T["nil opts returns valid config"] = function()
    local cfg = Config.merge(nil)
    MiniTest.expect.equality(cfg.enabled, true)
end

T["nested chafa config merges correctly"] = function()
    local cfg = Config.merge({ chafa = { format = "sixels" } })
    MiniTest.expect.equality(cfg.chafa.format, "sixels")
    MiniTest.expect.equality(cfg.chafa.animate, false)
end

T["extensions whitelist preserved as-is"] = function()
    local cfg = Config.merge({ extensions = { "png", "jpg" } })
    MiniTest.expect.equality(#cfg.extensions, 2)
    MiniTest.expect.equality(cfg.extensions[1], "png")
end

return T
