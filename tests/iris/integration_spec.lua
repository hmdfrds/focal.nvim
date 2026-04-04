local H = require("tests.iris.helpers")

-- Helper to reset all iris modules between tests
local function reset_iris()
    for key in pairs(package.loaded) do
        if key == "iris" or key:find("^iris%.") then
            package.loaded[key] = nil
        end
    end
end

-- Helper to create a fully wired preview manager with mock renderer
local function make_test_env(opts)
    opts = opts or {}
    reset_iris()
    local Config = require("iris.config")
    local Resolver = require("iris.resolver")
    local Renderer = require("iris.renderer")
    local Window = require("iris.window")
    local Preview = require("iris.preview")
    local Cache = require("iris.lib.cache")

    Resolver._reset()
    Renderer._reset()

    local config = Config.merge(opts.config or {})
    local wm = Window.new({
        border = config.border,
        winblend = config.winblend,
        zindex = config.zindex,
        col_offset = config.col_offset,
        row_offset = config.row_offset,
    })

    local pm = Preview.new({
        config = config,
        resolver = Resolver,
        renderer_registry = Renderer,
        window_mgr = wm,
        cache = Cache.new(),
    })

    -- Register mock source
    if opts.source then
        Resolver.register_source(opts.source)
    end

    -- Register mock renderer
    if opts.renderer then
        Renderer.register_renderer(opts.renderer)
    end

    return { pm = pm, wm = wm, config = config, resolver = Resolver, renderer = Renderer }
end

local T = MiniTest.new_set()

-- ============================================================
-- Existing tests
-- ============================================================

T["setup() with defaults does not error"] = function()
    reset_iris()
    require("iris").setup({})
end

T["setup() with invalid config warns and uses defaults"] = function()
    reset_iris()
    local check = H.expect_notify("config.min_width must be")
    require("iris").setup({ min_width = "banana" })
    MiniTest.expect.equality(check(), true)
end

T["enable/disable toggle works"] = function()
    reset_iris()
    local iris = require("iris")
    iris.setup({})
    MiniTest.expect.equality(iris.is_enabled(), true)
    iris.disable()
    MiniTest.expect.equality(iris.is_enabled(), false)
    iris.enable()
    MiniTest.expect.equality(iris.is_enabled(), true)
end

T["status() returns structured data"] = function()
    reset_iris()
    local iris = require("iris")
    iris.setup({})
    local s = iris.status()
    MiniTest.expect.equality(type(s.state), "string")
    MiniTest.expect.equality(type(s.generation), "number")
    MiniTest.expect.equality(type(s.terminal), "table")
end

-- ============================================================
-- New tests for spec coverage
-- ============================================================

T["on_show hook receives path and renderer name"] = function()
    local captured_path, captured_renderer
    local rendered = false

    local env = make_test_env({
        config = {
            on_show = function(path, rname)
                captured_path = path
                captured_renderer = rname
            end,
        },
        source = H.mock_source({ filetype = "mock_ft" }),
        renderer = H.mock_renderer({
            name = "test-renderer",
            render = function(ctx, done)
                rendered = true
                done(true)
            end,
        }),
    })

    -- Write a real temp file so fs_stat succeeds
    local tmpfile = vim.fn.tempname() .. ".png"
    vim.fn.writefile({ "fake" }, tmpfile)

    -- Directly call the preview manager's show with a path
    env.pm:show(tmpfile)

    -- Wait for async stat + render
    vim.wait(2000, function()
        return rendered
    end)

    MiniTest.expect.equality(captured_path, tmpfile)
    MiniTest.expect.equality(captured_renderer, "test-renderer")

    env.pm:hide()
    os.remove(tmpfile)
end

T["on_hide hook fires on hide"] = function()
    local hide_called = false

    local env = make_test_env({
        config = {
            on_hide = function()
                hide_called = true
            end,
        },
        renderer = H.mock_renderer(),
    })

    -- Force state to visible so hide triggers the hook
    env.pm._state = "visible"
    env.pm._current_renderer = H.mock_renderer()
    env.pm:hide()

    MiniTest.expect.equality(hide_called, true)
end

T["max_file_size_mb rejects large files"] = function()
    local rendered = false

    local env = make_test_env({
        config = { max_file_size_mb = 0.0001 }, -- ~100 bytes limit
        renderer = H.mock_renderer({
            render = function(ctx, done)
                rendered = true
                done(true)
            end,
        }),
    })

    -- Create a file larger than the limit
    local tmpfile = vim.fn.tempname() .. ".png"
    local big_content = string.rep("x", 1000) -- 1KB, well over 0.0001MB
    vim.fn.writefile({ big_content }, tmpfile)

    env.pm:show(tmpfile)

    -- Wait a bit for async to complete
    vim.wait(1000, function()
        return env.pm:get_state() ~= "resolving"
    end)

    -- Should NOT have rendered (file too large)
    MiniTest.expect.equality(rendered, false)
    MiniTest.expect.equality(env.pm:get_state(), "idle")

    os.remove(tmpfile)
end

T["hide() cleans up window"] = function()
    local env = make_test_env({
        renderer = H.mock_renderer(),
    })

    local tmpfile = vim.fn.tempname() .. ".png"
    vim.fn.writefile({ "fake" }, tmpfile)

    env.pm:show(tmpfile)
    vim.wait(2000, function()
        return env.pm:get_state() == "visible"
    end)

    -- Window should be open
    MiniTest.expect.equality(env.wm:is_open(), true)

    -- Hide should close it
    env.pm:hide()
    MiniTest.expect.equality(env.wm:is_open(), false)
    MiniTest.expect.equality(env.pm:get_state(), "idle")

    os.remove(tmpfile)
end

T["generation increments prevent stale callbacks"] = function()
    local env = make_test_env({
        renderer = H.mock_renderer(),
    })

    local gen_before = env.pm:get_generation()
    env.pm:hide()
    local gen_after = env.pm:get_generation()

    MiniTest.expect.equality(gen_after > gen_before, true)

    -- Double hide still increments
    env.pm:hide()
    MiniTest.expect.equality(env.pm:get_generation() > gen_after, true)
end

T["custom source registered before setup survives"] = function()
    reset_iris()
    local iris = require("iris")
    iris.register_source(H.mock_source({ filetype = "custom_pre_setup" }))
    iris.setup({})
    local Resolver = require("iris.resolver")
    local source = Resolver.resolve("custom_pre_setup")
    MiniTest.expect.no_equality(source, nil)
    MiniTest.expect.equality(source.filetype, "custom_pre_setup")
end

T["extension extraction: .gitignore has no renderer match"] = function()
    local Geo = require("iris.lib.geometry")
    -- .gitignore extracts to "gitignore" which won't match any renderer
    MiniTest.expect.equality(Geo.extract_extension("/home/user/.gitignore"), "gitignore")

    local env = make_test_env({
        renderer = H.mock_renderer({ extensions = { "png" } }),
    })
    local Renderer = require("iris.renderer")
    MiniTest.expect.equality(Renderer.find_renderer("gitignore"), nil)
end

T["extension extraction: file.tar.gz matches gz"] = function()
    local Geo = require("iris.lib.geometry")
    MiniTest.expect.equality(Geo.extract_extension("/tmp/archive.tar.gz"), "gz")
end

T["cache hit avoids re-render"] = function()
    local render_count = 0

    local env = make_test_env({
        renderer = H.mock_renderer({
            needs_terminal = true,
            render = function(ctx, done)
                render_count = render_count + 1
                done(true, { output = "cached ansi output", fit = { width = 20, height = 8 } })
            end,
        }),
    })

    local tmpfile = vim.fn.tempname() .. ".png"
    vim.fn.writefile({ "fake" }, tmpfile)

    -- First show: renders
    env.pm:show(tmpfile)
    vim.wait(2000, function()
        return env.pm:get_state() == "visible"
    end)
    MiniTest.expect.equality(render_count, 1)

    -- Hide
    env.pm:hide()

    -- Second show of same file: should use cache
    env.pm:show(tmpfile)
    vim.wait(2000, function()
        return env.pm:get_state() == "visible"
    end)

    -- Cache hit means render was NOT called again
    MiniTest.expect.equality(render_count, 1)

    env.pm:hide()
    os.remove(tmpfile)
end

T["content swap keeps window, changes content"] = function()
    local render_calls = {}

    local env = make_test_env({
        renderer = H.mock_renderer({
            name = "swap-renderer",
            render = function(ctx, done)
                table.insert(render_calls, ctx.path)
                done(true)
            end,
        }),
    })

    local tmpA = vim.fn.tempname() .. ".png"
    local tmpB = vim.fn.tempname() .. ".png"
    vim.fn.writefile({ "imageA" }, tmpA)
    vim.fn.writefile({ "imageB" }, tmpB)

    -- Show image A
    env.pm:show(tmpA)
    vim.wait(2000, function()
        return env.pm:get_state() == "visible"
    end)
    MiniTest.expect.equality(env.pm:get_current_path(), tmpA)
    local win_before = env.wm:get_win()

    -- Content swap to image B via on_cursor_moved
    env.pm:on_cursor_moved(tmpB, "png")
    vim.wait(2000, function()
        return env.pm:get_current_path() == tmpB
    end)

    -- Window should still be open (same window, swapped content)
    MiniTest.expect.equality(env.wm:is_open(), true)
    MiniTest.expect.equality(env.pm:get_current_path(), tmpB)

    -- Both files should have been rendered
    MiniTest.expect.equality(#render_calls, 2)
    MiniTest.expect.equality(render_calls[1], tmpA)
    MiniTest.expect.equality(render_calls[2], tmpB)

    env.pm:hide()
    os.remove(tmpA)
    os.remove(tmpB)
end

T["on_resize repositions visible preview"] = function()
    local env = make_test_env({
        renderer = H.mock_renderer(),
    })

    local tmpfile = vim.fn.tempname() .. ".png"
    vim.fn.writefile({ "fake" }, tmpfile)

    env.pm:show(tmpfile)
    vim.wait(2000, function()
        return env.pm:get_state() == "visible"
    end)
    MiniTest.expect.equality(env.pm:get_state(), "visible")

    -- Simulate VimResized — should reposition, not crash, stay visible
    env.pm:on_resize()
    MiniTest.expect.equality(env.pm:get_state(), "visible")
    MiniTest.expect.equality(env.wm:is_open(), true)

    env.pm:hide()
    os.remove(tmpfile)
end

T["iris.show(path) works from public API"] = function()
    reset_iris()
    local iris = require("iris")
    iris.setup({})

    -- Register a mock renderer that handles png
    local Renderer = require("iris.renderer")
    local rendered = false
    Renderer.register_renderer(H.mock_renderer({
        name = "show-test",
        render = function(ctx, done)
            rendered = true
            done(true)
        end,
    }))

    local tmpfile = vim.fn.tempname() .. ".png"
    vim.fn.writefile({ "fake" }, tmpfile)

    iris.show(tmpfile)
    vim.wait(2000, function()
        return rendered
    end)
    MiniTest.expect.equality(rendered, true)

    iris.hide()
    os.remove(tmpfile)
end

return T
