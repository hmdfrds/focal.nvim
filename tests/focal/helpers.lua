local H = {}

function H.mock_renderer(overrides)
    return vim.tbl_extend("force", {
        name = "mock",
        extensions = { "png" },
        priority = 50,
        needs_terminal = false,
        is_available = function()
            return true
        end,
        get_geometry = function(_, _, env)
            return { width = 20, height = 10 }
        end,
        render = function(_, done)
            done(true, { output = "mock output" })
        end,
        clear = function() end,
        cleanup = function() end,
    }, overrides or {})
end

function H.mock_renderer_terminal(overrides)
    return vim.tbl_extend("force", H.mock_renderer(), {
        name = "mock-terminal",
        needs_terminal = true,
        render = function(_, done)
            done(true, { output = "mock ansi", fit = { width = 20, height = 8 } })
        end,
    }, overrides or {})
end

function H.mock_source(overrides)
    return vim.tbl_extend("force", {
        filetype = "mock_ft",
        get_path = function()
            return "/tmp/test.png"
        end,
    }, overrides or {})
end

function H.expect_notify(pattern, level)
    local captured = {}
    local orig = vim.notify
    vim.notify = function(msg, lvl)
        table.insert(captured, { msg = msg, level = lvl })
    end
    return function()
        vim.notify = orig
        for _, n in ipairs(captured) do
            if n.msg:find(pattern) and (level == nil or n.level == level) then
                return true
            end
        end
        return false
    end
end

return H
