local T = MiniTest.new_set()
local Cache = require("focal.lib.cache")

T["new() creates empty cache"] = function()
    local c = Cache.new()
    local s = c:stats()
    MiniTest.expect.equality(s.hits, 0)
    MiniTest.expect.equality(s.misses, 0)
    MiniTest.expect.equality(s.entries, 0)
end

T["put() and get() round-trip"] = function()
    local c = Cache.new()
    local geo = { width = 40, height = 20 }
    local fit = { width = 40, height = 15 }
    c:put("/tmp/a.png", 1000, geo, "ansi output", fit)
    local entry = c:get("/tmp/a.png", 1000, geo)
    MiniTest.expect.no_equality(entry, nil)
    MiniTest.expect.equality(entry.output, "ansi output")
    MiniTest.expect.equality(entry.fit_geometry.height, 15)
end

T["get() returns nil on mtime mismatch"] = function()
    local c = Cache.new()
    local geo = { width = 40, height = 20 }
    c:put("/tmp/a.png", 1000, geo, "old", { width = 40, height = 15 })
    MiniTest.expect.equality(c:get("/tmp/a.png", 2000, geo), nil)
end

T["get() returns nil on geometry mismatch"] = function()
    local c = Cache.new()
    c:put("/tmp/a.png", 1000, { width = 40, height = 20 }, "old", { width = 40, height = 15 })
    MiniTest.expect.equality(c:get("/tmp/a.png", 1000, { width = 80, height = 40 }), nil)
end

T["evicts oldest when max_entries exceeded"] = function()
    local c = Cache.new({ max_entries = 2 })
    local geo = { width = 10, height = 10 }
    c:put("/a.png", 1, geo, "a", geo)
    c:put("/b.png", 1, geo, "b", geo)
    c:put("/c.png", 1, geo, "c", geo)
    MiniTest.expect.equality(c:get("/a.png", 1, geo), nil)
    MiniTest.expect.no_equality(c:get("/b.png", 1, geo), nil)
    MiniTest.expect.no_equality(c:get("/c.png", 1, geo), nil)
end

T["evicts when max_bytes exceeded"] = function()
    local c = Cache.new({ max_bytes = 10 })
    local geo = { width = 10, height = 10 }
    c:put("/a.png", 1, geo, "12345", geo)
    c:put("/b.png", 1, geo, "12345", geo)
    c:put("/c.png", 1, geo, "12345", geo)
    MiniTest.expect.equality(c:get("/a.png", 1, geo), nil)
end

T["invalidate() removes specific path"] = function()
    local c = Cache.new()
    local geo = { width = 10, height = 10 }
    c:put("/a.png", 1, geo, "a", geo)
    c:invalidate("/a.png")
    MiniTest.expect.equality(c:get("/a.png", 1, geo), nil)
end

T["clear() removes everything and resets stats"] = function()
    local c = Cache.new()
    local geo = { width = 10, height = 10 }
    c:put("/a.png", 1, geo, "a", geo)
    c:get("/a.png", 1, geo)
    c:clear()
    local s = c:stats()
    MiniTest.expect.equality(s.entries, 0)
    MiniTest.expect.equality(s.hits, 0)
end

T["stats() tracks hits, misses, evictions"] = function()
    local c = Cache.new({ max_entries = 1 })
    local geo = { width = 10, height = 10 }
    c:put("/a.png", 1, geo, "a", geo)
    c:get("/a.png", 1, geo)
    c:get("/b.png", 1, geo)
    c:put("/b.png", 1, geo, "b", geo)
    local s = c:stats()
    MiniTest.expect.equality(s.hits, 1)
    MiniTest.expect.equality(s.misses, 1)
    MiniTest.expect.equality(s.evictions, 1)
end

return T
