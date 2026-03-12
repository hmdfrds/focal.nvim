local Utils = require("focal.utils")

local M = {}

-- Named constants
local WINDOW_COL_OFFSET = 4
local WINDOW_ROW_OFFSET = 1
local OVERFLOW_MARGIN = 2
local FLOAT_ZINDEX = 50
local TABLINE_Y_OFFSET = -1
local CELL_WIDTH_FALLBACK = 10
local CELL_HEIGHT_FALLBACK = 20

-- Cached module references (populated on first use)
local _image_api = nil
local _term_utils = nil

---@return table|nil
local function get_image_api()
    if not _image_api then
        local ok, api = Utils.safe_require("image")
        if ok then _image_api = api end
    end
    return _image_api
end

---@return table|nil
local function get_term_utils()
    if not _term_utils then
        local ok, tu = Utils.safe_require("image.utils.term")
        if ok then _term_utils = tu end
    end
    return _term_utils
end

---@class UIState
---@field win integer|nil Float window ID
---@field img table|nil Image object (from image.nvim)
---@field buf integer|nil Scratch buffer ID for the float
---@field ctx_buf integer|nil Explorer buffer that triggered the preview

---@type UIState
M.state = {
    win = nil,
    img = nil,
    buf = nil,
    ctx_buf = nil,
}

---Hide the preview window and clean up resources.
function M.hide()
    -- Clear image
    if M.state.img and M.state.img.clear then
        Utils.safe_call(M.state.img.clear, M.state.img)
    end
    M.state.img = nil

    -- Close window
    if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
        Utils.safe_call(vim.api.nvim_win_close, M.state.win, true)
    end
    M.state.win = nil

    -- Delete scratch buffer to prevent leak
    if M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
        Utils.safe_call(vim.api.nvim_buf_delete, M.state.buf, { force = true })
    end
    M.state.buf = nil
    M.state.ctx_buf = nil
end

---Clean up all resources. Called on VimLeavePre.
function M.cleanup()
    M.hide()
    _image_api = nil
    _term_utils = nil
end

---Calculate window geometry based on image and editor size.
---@param img_w number Image width in pixels
---@param img_h number Image height in pixels
---@param opts FocalConfig
---@return table config Window config for nvim_open_win
---@return number cols content width
---@return number rows content height
function M._calc_geometry(img_w, img_h, opts)
    local term_utils = get_term_utils()
    if not term_utils then return {}, 0, 0 end

    local term_size = term_utils.get_size()

    -- Fallback if term size detection fails
    local cell_w = term_size.cell_width > 0 and term_size.cell_width or CELL_WIDTH_FALLBACK
    local cell_h = term_size.cell_height > 0 and term_size.cell_height or CELL_HEIGHT_FALLBACK

    -- Convert Image Pixels -> Terminal Cells
    local img_cols = img_w / cell_w
    local img_rows = img_h / cell_h

    -- Max constraints (in Cells)
    local max_cols = math.min(
        math.floor(vim.o.columns * (opts.max_width_pct / 100)),
        opts.max_cells or 999
    ) - OVERFLOW_MARGIN
    local max_rows = math.min(
        math.floor(vim.o.lines * (opts.max_height_pct / 100)),
        opts.max_cells or 999
    ) - OVERFLOW_MARGIN

    -- Scale factor calculation
    local scale = 1.0
    if img_cols > max_cols then
        scale = math.min(scale, max_cols / img_cols)
    end
    if img_rows > max_rows then
        scale = math.min(scale, max_rows / img_rows)
    end

    -- Final dimensions
    local final_cols = math.max(opts.min_width, math.floor(img_cols * scale))
    local final_rows = math.max(opts.min_height, math.floor(img_rows * scale))

    -- Window Positioning (Adaptive)
    local cur_pos = vim.api.nvim_win_get_cursor(0)
    local cur_col = cur_pos[2]
    local col = WINDOW_COL_OFFSET

    if cur_col + final_cols + col > vim.o.columns then
        col = -final_cols - WINDOW_COL_OFFSET
    end

    local row = WINDOW_ROW_OFFSET
    local win_line = vim.fn.winline()
    local win_height = vim.api.nvim_win_get_height(0)

    if win_line + final_rows + row > win_height then
        row = -final_rows - WINDOW_ROW_OFFSET
    end

    return {
        relative = "cursor",
        row = row,
        col = col,
        width = final_cols,
        height = final_rows,
        style = "minimal",
        border = "rounded",
        focusable = false,
        zindex = FLOAT_ZINDEX,
    }, final_cols, final_rows
end

---Show preview for the given path.
---@param path string
---@param opts FocalConfig
function M.show(path, opts)
    -- Capture context for cancellation check
    local ctx_buf = vim.api.nvim_get_current_buf()
    local ctx_cursor = vim.api.nvim_win_get_cursor(0)

    -- 1. Async File Check (Non-blocking)
    local uv = vim.uv or vim.loop
    uv.fs_stat(path, function(err, stat)
        vim.schedule(function()
            if err or not stat then return end

            -- Cancellation: user moved cursor or changed buffer during async stat
            local cur_buf = vim.api.nvim_get_current_buf()
            if cur_buf ~= ctx_buf then return end

            local cur_cursor = vim.api.nvim_win_get_cursor(0)
            if cur_cursor[1] ~= ctx_cursor[1] or cur_cursor[2] ~= ctx_cursor[2] then
                return
            end

            -- Size guard
            if stat.size > (opts.max_file_size_mb * 1024 * 1024) then
                if opts.debug then
                    Utils.notify(string.format("Image too large: %s", path), vim.log.levels.WARN)
                end
                return
            end

            -- 2. Load Image
            local image_api = get_image_api()
            if not image_api then return end

            local img = image_api.from_file(path, {
                id = path .. "-focal-preview",
                max_width_window_percentage = 100,
                max_height_window_percentage = 100,
            })

            if not img or not img.image_width or not img.image_height then
                if opts.debug then
                    Utils.notify("Failed to load image: " .. path, vim.log.levels.WARN)
                end
                return
            end

            -- 3. Calculate Geometry
            local win_cfg, w, h = M._calc_geometry(img.image_width, img.image_height, opts)

            -- Double check context before touching UI
            if vim.api.nvim_get_current_buf() ~= ctx_buf then return end

            -- 4. Create/Update Window
            if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
                Utils.safe_call(vim.api.nvim_win_set_config, M.state.win, win_cfg)
            else
                -- Reuse existing scratch buffer or create a new one
                if not M.state.buf or not vim.api.nvim_buf_is_valid(M.state.buf) then
                    M.state.buf = vim.api.nvim_create_buf(false, true)
                end
                M.state.win = vim.api.nvim_open_win(M.state.buf, false, win_cfg)
                M.state.ctx_buf = ctx_buf
            end

            -- 5. Render
            img.window = M.state.win

            if M.state.img and M.state.img ~= img then
                Utils.safe_call(M.state.img.clear, M.state.img)
            end

            -- Tabline Offset Compensation
            -- When showtabline=2 or tabs>1, the global grid shifts.
            -- image.nvim < 1.3.0 sometimes misapplies this offset, creating a 1-cell gap.
            local showtabline = vim.o.showtabline
            local has_tabs = #vim.api.nvim_list_tabpages() > 1
            local has_tabline = showtabline == 2 or (showtabline == 1 and has_tabs)

            img:render({
                width = w,
                height = h,
                x = 0,
                y = has_tabline and TABLINE_Y_OFFSET or 0,
            })

            M.state.img = img
        end)
    end)
end

return M
