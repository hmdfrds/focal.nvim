local Utils = require("focal.utils")
local Chafa = require("focal.chafa")

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

-- Detected backend: "image" | "chafa" | nil
local _backend = nil
-- Whether we've already warned about no backend
local _warned_no_backend = false

---@return table|nil
local function get_image_api()
    if not _image_api then
        local ok, api = Utils.safe_require("image")
        if ok then
            _image_api = api
        end
    end
    return _image_api
end

---@return table|nil
local function get_term_utils()
    if not _term_utils then
        local ok, tu = Utils.safe_require("image.utils.term")
        if ok then
            _term_utils = tu
        end
    end
    return _term_utils
end

---Detect which rendering backend to use.
---@param opts FocalConfig
---@return string|nil backend "image" or "chafa" or nil
local function detect_backend(opts)
    if _backend then
        return _backend
    end

    local requested = opts.backend or "auto"

    if requested == "image" then
        if get_image_api() then
            _backend = "image"
        else
            Utils.notify("Backend 'image' requested but image.nvim is not available.", vim.log.levels.ERROR)
        end
    elseif requested == "chafa" then
        if Chafa.is_available() then
            _backend = "chafa"
        else
            Utils.notify("Backend 'chafa' requested but chafa is not installed.", vim.log.levels.ERROR)
        end
    else
        -- Auto-detect: prefer image.nvim, fallback to chafa
        local image_api = get_image_api()
        if image_api then
            -- Check if backend is actually initialized
            local initialized = false
            pcall(function()
                if image_api.is_enabled and image_api.is_enabled() then
                    image_api.get_images()
                    initialized = true
                end
            end)

            if initialized then
                _backend = "image"
            end
        end

        if not _backend and Chafa.is_available() then
            _backend = "chafa"
        end

        if not _backend and not _warned_no_backend then
            Utils.notify(
                "No rendering backend available. Install image.nvim (with a supported terminal) or chafa.",
                vim.log.levels.ERROR
            )
            _warned_no_backend = true
        end
    end

    return _backend
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
    -- Kill any in-flight chafa process
    Chafa.kill_process()

    -- Clear image.nvim image
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
    Chafa.cleanup()
    _image_api = nil
    _term_utils = nil
    _backend = nil
end

---Calculate window geometry for image.nvim backend (pixel-based).
---@param img_w number Image width in pixels
---@param img_h number Image height in pixels
---@param opts FocalConfig
---@return table config Window config for nvim_open_win
---@return number cols content width
---@return number rows content height
function M._calc_geometry(img_w, img_h, opts)
    local term_utils = get_term_utils()
    if not term_utils then
        return {}, 0, 0
    end

    local term_size = term_utils.get_size()

    -- Fallback if term size detection fails
    local cell_w = term_size.cell_width > 0 and term_size.cell_width or CELL_WIDTH_FALLBACK
    local cell_h = term_size.cell_height > 0 and term_size.cell_height or CELL_HEIGHT_FALLBACK

    -- Convert Image Pixels -> Terminal Cells
    local img_cols = img_w / cell_w
    local img_rows = img_h / cell_h

    -- Max constraints (in Cells)
    local max_cols = math.min(math.floor(vim.o.columns * (opts.max_width_pct / 100)), opts.max_cells or 999)
        - OVERFLOW_MARGIN
    local max_rows = math.min(math.floor(vim.o.lines * (opts.max_height_pct / 100)), opts.max_cells or 999)
        - OVERFLOW_MARGIN

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

    local win_cfg = M._build_win_config(final_cols, final_rows)
    return win_cfg, final_cols, final_rows
end

---Calculate window geometry for chafa backend (character-cell based).
---Chafa handles aspect ratio internally via --size=WxH.
---@param opts FocalConfig
---@return table config Window config for nvim_open_win
---@return number cols content width
---@return number rows content height
function M._calc_chafa_geometry(opts)
    local max_cols = math.min(math.floor(vim.o.columns * (opts.max_width_pct / 100)), opts.max_cells or 999)
        - OVERFLOW_MARGIN
    local max_rows = math.min(math.floor(vim.o.lines * (opts.max_height_pct / 100)), opts.max_cells or 999)
        - OVERFLOW_MARGIN

    local final_cols = math.max(opts.min_width, max_cols)
    local final_rows = math.max(opts.min_height, max_rows)

    local win_cfg = M._build_win_config(final_cols, final_rows)
    return win_cfg, final_cols, final_rows
end

---Build a floating window config with adaptive cursor-relative positioning.
---@param width number Window width in cells
---@param height number Window height in cells
---@return table config nvim_open_win config
function M._build_win_config(width, height)
    local cur_pos = vim.api.nvim_win_get_cursor(0)
    local cur_col = cur_pos[2]
    local col = WINDOW_COL_OFFSET

    if cur_col + width + col > vim.o.columns then
        col = -width - WINDOW_COL_OFFSET
    end

    local row = WINDOW_ROW_OFFSET
    local win_line = vim.fn.winline()
    local win_height = vim.api.nvim_win_get_height(0)

    if win_line + height + row > win_height then
        row = -height - WINDOW_ROW_OFFSET
    end

    return {
        relative = "cursor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        focusable = false,
        zindex = FLOAT_ZINDEX,
    }
end

---Check if user context (buffer + cursor) is still valid.
---@param ctx_buf integer
---@param ctx_cursor integer[]
---@return boolean
local function context_valid(ctx_buf, ctx_cursor)
    if vim.api.nvim_get_current_buf() ~= ctx_buf then
        return false
    end
    local cur = vim.api.nvim_win_get_cursor(0)
    return cur[1] == ctx_cursor[1] and cur[2] == ctx_cursor[2]
end

---Create or reuse the float window.
---@param win_cfg table
---@param ctx_buf integer
local function ensure_window(win_cfg, ctx_buf)
    if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
        Utils.safe_call(vim.api.nvim_win_set_config, M.state.win, win_cfg)
    else
        if not M.state.buf or not vim.api.nvim_buf_is_valid(M.state.buf) then
            M.state.buf = vim.api.nvim_create_buf(false, true)
        end
        M.state.win = vim.api.nvim_open_win(M.state.buf, false, win_cfg)
        M.state.ctx_buf = ctx_buf
    end
end

---Show preview using image.nvim backend.
---@param path string
---@param opts FocalConfig
---@param ctx_buf integer
---@param ctx_cursor integer[]
---@param stat table uv.fs_stat result
local function show_image(path, opts, ctx_buf, ctx_cursor, stat)
    -- Size guard
    if stat.size > (opts.max_file_size_mb * 1024 * 1024) then
        if opts.debug then
            Utils.notify(string.format("Image too large: %s", path), vim.log.levels.WARN)
        end
        return
    end

    local image_api = get_image_api()
    if not image_api then
        return
    end

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

    local win_cfg, w, h = M._calc_geometry(img.image_width, img.image_height, opts)

    -- Double check context before touching UI
    if not context_valid(ctx_buf, ctx_cursor) then
        return
    end

    ensure_window(win_cfg, ctx_buf)

    -- Render
    img.window = M.state.win

    if M.state.img and M.state.img ~= img then
        Utils.safe_call(M.state.img.clear, M.state.img)
    end

    -- Tabline Offset Compensation
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
end

---Show preview using chafa backend.
---@param path string
---@param opts FocalConfig
---@param ctx_buf integer
---@param ctx_cursor integer[]
---@param stat table uv.fs_stat result
local function show_chafa(path, opts, ctx_buf, ctx_cursor, stat)
    -- Size guard
    if stat.size > (opts.max_file_size_mb * 1024 * 1024) then
        if opts.debug then
            Utils.notify(string.format("Image too large: %s", path), vim.log.levels.WARN)
        end
        return
    end

    local win_cfg, w, h = M._calc_chafa_geometry(opts)

    if not context_valid(ctx_buf, ctx_cursor) then
        return
    end

    -- Chafa needs a fresh buffer each time (terminal channel is one-shot)
    M.hide()
    M.state.buf = vim.api.nvim_create_buf(false, true)
    M.state.win = vim.api.nvim_open_win(M.state.buf, false, win_cfg)
    M.state.ctx_buf = ctx_buf

    local chafa_opts = opts.chafa or {}
    Chafa.render(path, M.state.buf, w, h, {
        format = chafa_opts.format,
        color_space = chafa_opts.color_space,
    }, function(render_ok, actual_rows)
        if not render_ok then
            return
        end

        -- Tight-fit: resize window height to match actual chafa output
        if actual_rows and actual_rows < h and M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
            local tight_height = math.max(opts.min_height, actual_rows)
            Utils.safe_call(vim.api.nvim_win_set_config, M.state.win, {
                relative = "cursor",
                row = win_cfg.row,
                col = win_cfg.col,
                width = w,
                height = tight_height,
            })
        end
    end)
end

---Show preview for the given path.
---@param path string
---@param opts FocalConfig
function M.show(path, opts)
    local backend = detect_backend(opts)
    if not backend then
        return
    end

    -- Capture context for cancellation check
    local ctx_buf = vim.api.nvim_get_current_buf()
    local ctx_cursor = vim.api.nvim_win_get_cursor(0)

    -- Async File Check (Non-blocking)
    local uv = vim.uv or vim.loop
    uv.fs_stat(path, function(err, stat)
        vim.schedule(function()
            if err or not stat then
                return
            end

            if not context_valid(ctx_buf, ctx_cursor) then
                return
            end

            if backend == "image" then
                show_image(path, opts, ctx_buf, ctx_cursor, stat)
            elseif backend == "chafa" then
                show_chafa(path, opts, ctx_buf, ctx_cursor, stat)
            end
        end)
    end)
end

return M
