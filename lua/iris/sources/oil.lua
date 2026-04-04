---@mod iris.sources.oil "Oil Source"

local M = {}

M.filetype = "oil"

function M.get_path()
    local ok, oil = pcall(require, "oil")
    if not ok then return nil end

    local entry = oil.get_cursor_entry()
    if not entry or entry.type == "directory" then return nil end

    local dir = oil.get_current_dir()
    if not dir then return nil end

    return vim.fs.joinpath(dir, entry.name)
end

return M
