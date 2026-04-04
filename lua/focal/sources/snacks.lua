---@mod focal.sources.snacks "Snacks Source"

local M = {}

M.filetype = "snacks_picker_list"

function M.get_path()
    local ok, snacks = pcall(require, "snacks")
    if not ok then return nil end

    local pickers_ok, pickers = pcall(snacks.picker.get)
    if not pickers_ok or not pickers or #pickers == 0 then return nil end

    local picker = pickers[1]
    if not picker then return nil end

    local item_ok, item = pcall(picker.current, picker)
    if not item_ok or not item then return nil end

    if item.type == "directory" then return nil end

    local path = item.file or item._path
    if not path then return nil end

    return path
end

return M
