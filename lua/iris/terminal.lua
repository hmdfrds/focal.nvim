---@mod iris.terminal "Terminal Capability Detection"
---@brief [[
--- Detects terminal graphics protocol support via environment variables.
--- Table-driven: adding a terminal = adding one table entry.
---@brief ]]

local M = {}

---@type IrisTerminalInfo|nil
local _cached = nil

local terminals = {
    { env_key = "KITTY_PID", terminal = "kitty", protocol = "kitty" },
    { env_key = "TERM", value = "xterm-kitty", terminal = "kitty", protocol = "kitty" },
    { env_key = "TERM_PROGRAM", value = "WezTerm", terminal = "WezTerm", protocol = "kitty" },
    { env_key = "TERM_PROGRAM", value = "ghostty", terminal = "ghostty", protocol = "kitty" },
    { env_key = "TERM_PROGRAM", value = "iTerm.app", terminal = "iTerm2", protocol = "sixel" },
    { env_key = "KONSOLE_VERSION", terminal = "Konsole", protocol = "sixel" },
    { env_key = "TERM", prefix = "foot", terminal = "foot", protocol = "sixel" },
    { env_key = "WT_SESSION", terminal = "Windows Terminal", protocol = "sixel" },
    { env_key = "TERM_PROGRAM", value = "rio", terminal = "Rio", protocol = "kitty" },
    { env_key = "TERMINAL_EMULATOR", value = "contour", terminal = "Contour", protocol = "sixel" },
    { env_key = "MOSH_CONNECTION", terminal = "mosh", protocol = nil },
}

---Detect terminal graphics capability. Cached for session lifetime.
---@return IrisTerminalInfo
function M.detect()
    if _cached then
        return _cached
    end

    local info = {
        has_graphics = false,
        protocol = nil,
        terminal = nil,
        in_tmux = vim.env.TMUX ~= nil,
        in_ssh = vim.env.SSH_CLIENT ~= nil or vim.env.SSH_TTY ~= nil,
        in_mosh = vim.env.MOSH_CONNECTION ~= nil,
    }

    for _, entry in ipairs(terminals) do
        local env_val = vim.env[entry.env_key]
        if env_val then
            local match = false
            if entry.value then
                match = (env_val == entry.value)
            elseif entry.prefix then
                match = (env_val:find("^" .. entry.prefix) ~= nil)
            else
                match = true
            end
            if match then
                info.terminal = entry.terminal
                info.protocol = entry.protocol
                info.has_graphics = entry.protocol ~= nil
                break
            end
        end
    end

    _cached = info
    return _cached
end

---Clear cached detection result.
function M.reset_cache()
    _cached = nil
end

return M
