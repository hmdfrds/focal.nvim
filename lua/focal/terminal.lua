---@mod focal.terminal "Terminal Capability Detection"
---@brief [[
--- Detects the terminal's graphics protocol support via environment variables.
--- Used by auto-detection to decide whether image.nvim can actually render.
---@brief ]]

local M = {}

---@class FocalTerminalInfo
---@field has_graphics boolean Whether the terminal supports a graphics protocol
---@field protocol string|nil "kitty"|"sixel"|nil
---@field terminal string|nil Detected terminal name (for diagnostics)
---@field in_tmux boolean Whether running inside tmux
---@field in_ssh boolean Whether running inside an SSH session

---@type FocalTerminalInfo|nil
local _cached = nil

---Detect terminal graphics capability from environment variables.
---Result is cached for the lifetime of the Neovim session.
---@return FocalTerminalInfo
function M.detect()
    if _cached then
        return _cached
    end

    local env = vim.fn.environ()

    local info = {
        has_graphics = false,
        protocol = nil,
        terminal = nil,
        in_tmux = env.TMUX ~= nil,
        in_ssh = env.SSH_CLIENT ~= nil or env.SSH_TTY ~= nil,
    }

    -- Kitty Graphics Protocol
    local is_kitty = env.KITTY_PID ~= nil or env.TERM == "xterm-kitty"
    local is_wezterm = env.TERM_PROGRAM == "WezTerm"
    local is_ghostty = env.TERM_PROGRAM == "ghostty"

    -- Sixel-capable terminals
    local is_iterm = env.TERM_PROGRAM == "iTerm.app"
    local is_foot = env.TERM ~= nil and env.TERM:find("^foot") ~= nil
    local is_konsole = env.KONSOLE_VERSION ~= nil

    if is_kitty then
        info.terminal = "kitty"
        info.protocol = "kitty"
        info.has_graphics = true
    elseif is_wezterm then
        info.terminal = "WezTerm"
        info.protocol = "kitty"
        info.has_graphics = true
    elseif is_ghostty then
        info.terminal = "ghostty"
        info.protocol = "kitty"
        info.has_graphics = true
    elseif is_iterm then
        info.terminal = "iTerm2"
        info.protocol = "sixel"
        info.has_graphics = true
    elseif is_foot then
        info.terminal = "foot"
        info.protocol = "sixel"
        info.has_graphics = true
    elseif is_konsole then
        info.terminal = "Konsole"
        info.protocol = "sixel"
        info.has_graphics = true
    end

    _cached = info
    return _cached
end

---Clear the cached detection result.
function M.reset_cache()
    _cached = nil
end

return M
