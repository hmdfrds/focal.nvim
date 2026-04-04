---@mod iris.window "Window Manager"
---@brief [[
--- Manages the floating preview window. All float-related Neovim API
--- calls are centralized here.
---@brief ]]

local Geo = require("iris.lib.geometry")

local M = {}

local WM = {}
WM.__index = WM

-- Define highlight groups with default = true so users can override.
vim.api.nvim_set_hl(0, "IrisFloat", { default = true, link = "NormalFloat" })
vim.api.nvim_set_hl(0, "IrisBorder", { default = true, link = "FloatBorder" })

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
---@param geometry IrisGeometry
---@param anchor IrisCursorAnchor
---@param title? string
---@return integer buf, integer win
function WM:open(geometry, anchor, title)
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
    local pos = Geo.adaptive_position(
        width,
        height,
        anchor,
        self._config.col_offset,
        self._config.row_offset
    )

    -- Create scratch buffer.
    local buf = vim.api.nvim_create_buf(false, true)

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
    }

    if title then
        win_config.title = title
    end

    -- Open the float.
    local win = vim.api.nvim_open_win(buf, false, win_config)

    -- Apply highlight groups and winblend.
    vim.api.nvim_set_option_value("winhighlight", "Normal:IrisFloat,FloatBorder:IrisBorder", { win = win })
    vim.api.nvim_set_option_value("winblend", self._config.winblend, { win = win })

    self._buf = buf
    self._win = win

    return buf, win
end

---Resize the current window.
---@param geometry IrisGeometry
function WM:resize(geometry)
    if not self:is_open() then
        return
    end
    local current = vim.api.nvim_win_get_config(self._win)
    vim.api.nvim_win_set_config(self._win, {
        relative = current.relative,
        row = current.row,
        col = current.col,
        width = geometry.width,
        height = geometry.height,
    })
end

---Reposition the window based on a new anchor.
---@param anchor IrisCursorAnchor
function WM:reposition(anchor)
    if not self:is_open() then
        return
    end
    local current = vim.api.nvim_win_get_config(self._win)
    local pos = Geo.adaptive_position(
        current.width,
        current.height,
        anchor,
        self._config.col_offset,
        self._config.row_offset
    )
    vim.api.nvim_win_set_config(self._win, {
        relative = "cursor",
        row = pos.row,
        col = pos.col,
        width = current.width,
        height = current.height,
    })
end

---Replace the current buffer with a fresh scratch buffer.
---Closes any active terminal channel, deletes the old buffer.
---@return integer new_buf
function WM:replace_buffer()
    local old_buf = self._buf

    -- Close terminal channel if active.
    if self._chan then
        pcall(vim.fn.chanclose, self._chan)
        self._chan = nil
    end

    -- Create new scratch buffer.
    local new_buf = vim.api.nvim_create_buf(false, true)

    -- Swap buffer in the window.
    vim.api.nvim_win_set_buf(self._win, new_buf)

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
---@return integer channel
function WM:open_terminal()
    local chan = vim.api.nvim_open_term(self._buf, {})
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
