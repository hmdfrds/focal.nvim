local Utils = require("focal.utils")

local M = {}

---@class UIState
---@field win integer|nil Window ID of the preview float
---@field img table|nil Image object (from image.nvim)
---@field buf integer|nil Buffer ID where the preview is active

---@type UIState
M.state = {
    win = nil,
    img = nil,
    buf = nil,
}

---Hide the preview window
function M.hide()
	-- Safe image clear
	if M.state.img and M.state.img.clear then
		pcall(M.state.img.clear, M.state.img)
	end
	M.state.img = nil

	-- Safe window close
	if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
		pcall(vim.api.nvim_win_close, M.state.win, true)
	end
	M.state.win = nil
	M.state.buf = nil
end

---Calculate window geometry based on image and editor size
---@param img_w number Image width in pixels
---@param img_h number Image height in pixels
---@param opts FocalConfig
---@return table config Window config for nvim_open_win
---@return number cols content width
---@return number rows content height
function M._calc_geometry(img_w, img_h, opts)
	local term_utils = require("image.utils.term")
	local term_size = term_utils.get_size()

	-- Fallback if term size detection fails
	local cell_w = term_size.cell_width > 0 and term_size.cell_width or 10
	local cell_h = term_size.cell_height > 0 and term_size.cell_height or 20

	-- Convert Image Pixels -> Terminal Cells
	local img_cols = img_w / cell_w
	local img_rows = img_h / cell_h

	-- Max constraints (in Cells)
	local error_margin = 2
	local max_cols = math.min(math.floor(vim.o.columns * (opts.max_width_pct / 100)), opts.max_cells or 999) - error_margin
	local max_rows = math.min(math.floor(vim.o.lines * (opts.max_height_pct / 100)), opts.max_cells or 999) - error_margin

	-- Scale factor calculation
	local scale = 1.0
	if img_cols > max_cols then
		scale = math.min(scale, max_cols / img_cols)
	end
	if img_rows > max_rows then
		scale = math.min(scale, max_rows / img_rows)
	end

	-- Final dimensions
	local final_cols = math.floor(img_cols * scale)
	local final_rows = math.floor(img_rows * scale)

	final_cols = math.max(opts.min_width, final_cols)
	final_rows = math.max(opts.min_height, final_rows)

	-- Window Positioning (Adaptive)
	local cur_pos = vim.api.nvim_win_get_cursor(0)
	local cur_col = cur_pos[2]
	local col = 4

	if (cur_col + final_cols + col > vim.o.columns) then
		col = -final_cols - 4
	end

	local row = 1
	local win_line = vim.fn.winline()
	local win_height = vim.api.nvim_win_get_height(0)

	if (win_line + final_rows + row > win_height) then
		row = -final_rows - 1
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
		zindex = 50,
	}, final_cols, final_rows
end

---Show preview for the given path
---@param path string
---@param opts FocalConfig
function M.show(path, opts)
    -- Capture context for cancellation check
    local ctx_buf = vim.api.nvim_get_current_buf()
    local ctx_cursor = vim.api.nvim_win_get_cursor(0)

	-- 1. Async File Check (Non-blocking)
    -- Use vim.uv (Nvim 0.10+) or vim.loop (Older)
    local uv = vim.uv or vim.loop
	uv.fs_stat(path, function(err, stat)
        -- Jump back to main thread
        vim.schedule(function()
            if err or not stat then return end
            
            -- [OPTIMIZATION] Cancellation Check
            -- If user moved cursor or changed buffer while we were stating the file, abort.
            local cur_buf = vim.api.nvim_get_current_buf()
            if cur_buf ~= ctx_buf then return end
            
            local cur_cursor = vim.api.nvim_win_get_cursor(0)
            if cur_cursor[1] ~= ctx_cursor[1] or cur_cursor[2] ~= ctx_cursor[2] then
                return -- ABORT: "Cancel on Move"
            end

            -- [Size Guard]
            -- stat.size is in bytes. Check against limit to prevent freezes.
            if stat.size > (opts.max_file_size_mb * 1024 * 1024) then
                if opts.debug then
                    Utils.notify(string.format("Image too large: %s", path), vim.log.levels.WARN)
                end
                return
            end

            -- 2. Load Image
            -- NOTE: image.nvim loaders can be synchronous. Pacing is handled by the async check above.
            local ok_img, image_api = Utils.safe_require("image")
            if not ok_img then return end

            local img = image_api.from_file(path, {
                id = path .. "-focal-preview",
                max_width_window_percentage = 100,
                max_height_window_percentage = 100,
            })

            if not img or not img.image_width or not img.image_height then
                if opts.debug then Utils.notify("Failed to load image: " .. path, vim.log.levels.WARN) end
                return
            end

            -- 3. Calculate Geometry
            local win_cfg, w, h = M._calc_geometry(img.image_width, img.image_height, opts)
            
            -- Double check context before touching UI (paranoia check)
            if vim.api.nvim_get_current_buf() ~= ctx_buf then return end

            -- 4. Create/Update Window
            if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
                pcall(vim.api.nvim_win_set_config, M.state.win, win_cfg)
            else
                local buf = vim.api.nvim_create_buf(false, true)
                M.state.win = vim.api.nvim_open_win(buf, false, win_cfg)
                M.state.buf = ctx_buf
            end

            -- 5. Render
            img.window = M.state.win
            
            if M.state.img and M.state.img ~= img then
                 pcall(M.state.img.clear, M.state.img)
            end
            
            -- [FIX] Tabline Offset Compensation
            -- When showtabline=2 or tabs>1, the global grid shifts.
            -- image.nvim < 1.3.0 sometimes misapplies this offset, creating a 1-cell gap.
            -- We apply y = -1 to pull it back up if a tabline is detected.
            local showtabline = vim.o.showtabline
            local has_tabs = #vim.api.nvim_list_tabpages() > 1
            local has_tabline = showtabline == 2 or (showtabline == 1 and has_tabs)
            
            local y_offset = 0
            if has_tabline then
                y_offset = -1
            end

            img:render({
                width = w,
                height = h,
                x = 0,
                y = y_offset,
            })
            
            M.state.img = img
        end)
    end)
end

return M
