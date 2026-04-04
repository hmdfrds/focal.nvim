---@mod focal.sources.oil "Oil Source"

local M = {}

M.filetype = "oil"

function M.get_path()
    local ok, oil = pcall(require, "oil")
    if not ok then
        return nil
    end

    local entry_ok, entry = pcall(oil.get_cursor_entry)
    if not entry_ok or not entry or (entry.type ~= "file" and entry.type ~= "link") then
        return nil
    end

    local dir_ok, dir = pcall(oil.get_current_dir)
    if not dir_ok or not dir then
        return nil
    end

    local full = vim.fs.joinpath(dir, entry.name)

    -- Symlinks could point to directories — filter those out.
    if entry.type == "link" and vim.fn.isdirectory(full) == 1 then
        return nil
    end

    return full
end

return M
