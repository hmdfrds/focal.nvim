---@mod iris.sources.snacks "Snacks Source"

local M = {}

M.filetype = "snacks_picker_list"

function M.get_path()
    local ok, snacks = pcall(require, "snacks")
    if not ok then return nil end

    local pickers = snacks.picker.get()
    if not pickers or #pickers == 0 then return nil end

    local picker = pickers[1]
    if not picker then return nil end

    local item = picker:current()
    if not item then return nil end

    return item.file or item._path
end

return M
