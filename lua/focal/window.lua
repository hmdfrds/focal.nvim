---@mod focal.window "Window Manager"
---@brief [[
--- Manages the floating preview window. All float-related Neovim API
--- calls are centralized here.
---@brief ]]

local Geo = require("focal.lib.geometry")

local M = {}

local WM = {}
WM.__index = WM

---Create a new window manager instance.
---@param config table
---@return table
function M.new(config)
    return setmetatable({
        _win = nil,
        _buf = nil,
        _chan = nil,
        _config = config,
    }, WM)
end

---Open a floating window with the given geometry and anchor.
---Closes any existing window first. Clamps geometry to terminal dimensions.
---@param geometry FocalGeometry
---@param anchor FocalCursorAnchor
---@param title? string
---@return integer|nil buf, integer|nil win
function WM:open(geometry, anchor, title)
    vim.api.nvim_set_hl(0, "FocalFloat", { default = true, link = "NormalFloat" })
    vim.api.nvim_set_hl(0, "FocalBorder", { default = true, link = "FloatBorder" })

    -- Close existing window if open.
    if self:is_open() then
        self:close()
    end

    -- Clamp geometry to terminal size minus border margin.
    local margin = Geo.overflow_margin(self._config.border)
    local max_w = math.max(1, vim.o.columns - margin)
    local max_h = math.max(1, vim.o.lines - margin)
    local width = math.min(geometry.width, max_w)
    local height = math.min(geometry.height, max_h)

    -- Compute adaptive position.
    local pos =
        Geo.adaptive_position(width, height, anchor, self._config.col_offset, self._config.row_offset, vim.o.columns)

    -- Create scratch buffer.
    local buf_ok, buf = pcall(vim.api.nvim_create_buf, false, true)
    if not buf_ok or not buf then
        return nil, nil
    end

    -- Build window config.
    local win_config = {
        relative = "cursor",
        row = pos.row,
        col = pos.col,
        width = width,
        height = height,
        border = self._config.border,
        style = "minimal",
        focusable = false,
        zindex = self._config.zindex,
        noautocmd = true,
    }

    -- Title requires a visible border; skip when border is "none".
    if title and self._config.border ~= "none" then
        win_config.title = title
    end

    -- Open the float.
    local ok, win = pcall(vim.api.nvim_open_win, buf, false, win_config)
    if not ok then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
        return nil, nil
    end

    -- Apply highlight groups and winblend.
    vim.api.nvim_set_option_value("winhighlight", "Normal:FocalFloat,FloatBorder:FocalBorder", { win = win })
    vim.api.nvim_set_option_value("winblend", self._config.winblend, { win = win })

    self._buf = buf
    self._win = win

    return buf, win
end

---Resize the current window. Clamps geometry to terminal size.
---@param geometry FocalGeometry
function WM:resize(geometry)
    if not self:is_open() then
        return
    end
    -- Clamp geometry the same way open() does.
    local margin = Geo.overflow_margin(self._config.border)
    local max_w = math.max(1, vim.o.columns - margin)
    local max_h = math.max(1, vim.o.lines - margin)
    local width = math.min(geometry.width, max_w)
    local height = math.min(geometry.height, max_h)

    -- Only pass width and height; Neovim preserves unspecified keys.
    pcall(vim.api.nvim_win_set_config, self._win, {
        width = width,
        height = height,
    })
end

---Set the window title. Requires a visible border.
---@param title string
function WM:set_title(title)
    if not self:is_open() then
        return
    end
    if self._config.border == "none" then
        return
    end
    pcall(vim.api.nvim_win_set_config, self._win, { title = title })
end

---Reposition the window based on a new anchor.
---Recomputes position from scratch instead of reading boxed values.
---@param anchor FocalCursorAnchor
function WM:reposition(anchor)
    if not self:is_open() then
        return
    end
    local cfg_ok, current = pcall(vim.api.nvim_win_get_config, self._win)
    if not cfg_ok then
        return
    end
    -- Unbox width/height safely: nvim_win_get_config may return boxed {false, N} values.
    local raw_w = current.width
    local raw_h = current.height
    local width = type(raw_w) == "table" and raw_w[2] or raw_w
    local height = type(raw_h) == "table" and raw_h[2] or raw_h
    if type(width) ~= "number" or type(height) ~= "number" then
        return
    end
    local pos =
        Geo.adaptive_position(width, height, anchor, self._config.col_offset, self._config.row_offset, vim.o.columns)
    pcall(vim.api.nvim_win_set_config, self._win, {
        relative = "cursor",
        row = pos.row,
        col = pos.col,
        width = width,
        height = height,
    })
end

---Replace the current buffer with a fresh scratch buffer.
---Closes any active terminal channel, deletes the old buffer.
---@return integer new_buf
function WM:replace_buffer()
    if not self:is_open() then
        return self._buf
    end

    local old_buf = self._buf

    -- Close terminal channel if active.
    if self._chan then
        pcall(vim.fn.chanclose, self._chan)
        self._chan = nil
    end

    -- Create new scratch buffer.
    local buf_ok, new_buf = pcall(vim.api.nvim_create_buf, false, true)
    if not buf_ok or not new_buf then
        return self._buf
    end

    -- Swap buffer in the window (pcall guards TOCTOU with is_open check).
    local swap_ok = pcall(vim.api.nvim_win_set_buf, self._win, new_buf)
    if not swap_ok then
        pcall(vim.api.nvim_buf_delete, new_buf, { force = true })
        return self._buf
    end

    -- Delete old buffer.
    if old_buf and vim.api.nvim_buf_is_valid(old_buf) then
        pcall(vim.api.nvim_buf_delete, old_buf, { force = true })
    end

    self._buf = new_buf
    return new_buf
end

---Close the window. Idempotent and safe — all errors are silenced.
function WM:close()
    -- Close terminal channel.
    if self._chan then
        pcall(vim.fn.chanclose, self._chan)
        self._chan = nil
    end

    -- Close window.
    if self._win and vim.api.nvim_win_is_valid(self._win) then
        pcall(vim.api.nvim_win_close, self._win, true)
    end

    -- Delete buffer.
    if self._buf and vim.api.nvim_buf_is_valid(self._buf) then
        pcall(vim.api.nvim_buf_delete, self._buf, { force = true })
    end

    self._win = nil
    self._buf = nil
end

---Open a terminal in the current buffer.
---@return integer|nil channel
function WM:open_terminal()
    if not self:is_open() or not self._buf or not vim.api.nvim_buf_is_valid(self._buf) then
        return nil
    end
    local ok, chan = pcall(vim.api.nvim_open_term, self._buf, {})
    if not ok or not chan or chan <= 0 then
        return nil
    end
    self._chan = chan
    return chan
end

---Check whether the window is currently open and valid.
---@return boolean
function WM:is_open()
    return self._win ~= nil and vim.api.nvim_win_is_valid(self._win)
end

---Get the current buffer handle, or nil if closed.
---@return integer|nil
function WM:get_buf()
    if self._buf and vim.api.nvim_buf_is_valid(self._buf) then
        return self._buf
    end
    return nil
end

---Get the current window handle, or nil if closed.
---@return integer|nil
function WM:get_win()
    if self._win and vim.api.nvim_win_is_valid(self._win) then
        return self._win
    end
    return nil
end

return M
