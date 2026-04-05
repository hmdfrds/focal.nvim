local Window = require("focal.window")

local wm

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            wm = Window.new({
                border = "rounded",
                winblend = 0,
                zindex = 100,
                col_offset = 4,
                row_offset = 1,
            })
        end,
        post_case = function()
            if wm then
                pcall(wm.close, wm)
            end
            wm = nil
        end,
    },
})

T["open() creates valid buffer and window"] = function()
    local anchor = { screen_row = 5, screen_col = 10 }
    local geometry = { width = 30, height = 15 }
    local buf, win = wm:open(geometry, anchor)
    MiniTest.expect.equality(vim.api.nvim_buf_is_valid(buf), true)
    MiniTest.expect.equality(vim.api.nvim_win_is_valid(win), true)
end

T["close() is idempotent"] = function()
    local anchor = { screen_row = 5, screen_col = 10 }
    local geometry = { width = 30, height = 15 }
    wm:open(geometry, anchor)
    wm:close()
    wm:close()
    MiniTest.expect.equality(wm:is_open(), false)
end

T["is_open() tracks window state"] = function()
    MiniTest.expect.equality(wm:is_open(), false)
    local anchor = { screen_row = 5, screen_col = 10 }
    local geometry = { width = 30, height = 15 }
    wm:open(geometry, anchor)
    MiniTest.expect.equality(wm:is_open(), true)
    wm:close()
    MiniTest.expect.equality(wm:is_open(), false)
end

T["replace_buffer() swaps buffer in existing window"] = function()
    local anchor = { screen_row = 5, screen_col = 10 }
    local geometry = { width = 30, height = 15 }
    wm:open(geometry, anchor)
    local buf1 = wm:get_buf()
    local new_buf = wm:replace_buffer()
    local buf2 = wm:get_buf()
    MiniTest.expect.equality(buf2, new_buf)
    MiniTest.expect.no_equality(buf2, buf1)
    MiniTest.expect.equality(vim.api.nvim_win_get_buf(wm:get_win()), buf2)
    MiniTest.expect.equality(vim.api.nvim_buf_is_valid(buf1), false)
end

T["get_buf() and get_win() return current handles"] = function()
    local anchor = { screen_row = 5, screen_col = 10 }
    local geometry = { width = 30, height = 15 }
    local buf, win = wm:open(geometry, anchor)
    MiniTest.expect.equality(wm:get_buf(), buf)
    MiniTest.expect.equality(wm:get_win(), win)
    wm:close()
    MiniTest.expect.equality(wm:get_buf(), nil)
    MiniTest.expect.equality(wm:get_win(), nil)
end

T["open() clamps geometry to terminal size"] = function()
    local anchor = { screen_row = 5, screen_col = 10 }
    local geometry = { width = 9999, height = 9999 }
    local _, win = wm:open(geometry, anchor)
    local win_config = vim.api.nvim_win_get_config(win)
    MiniTest.expect.equality(win_config.width < 9999, true)
    MiniTest.expect.equality(win_config.height < 9999, true)
end

return T
