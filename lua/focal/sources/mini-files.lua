---@mod focal.sources.mini-files "mini.files Source"

local M = {}

M.filetype = "minifiles"

function M.get_path()
    local ok, mini_files = pcall(require, "mini.files")
    if not ok then
        return nil
    end

    local entry_ok, entry = pcall(mini_files.get_fs_entry)
    if not entry_ok or not entry or entry.fs_type ~= "file" then
        return nil
    end

    return entry.path
end

return M
