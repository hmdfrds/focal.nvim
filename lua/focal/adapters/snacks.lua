---@mod focal.adapters.snacks "Snacks Adapter"

local M = {}

M.filetype = "snacks_picker_list"

---Resolve path from Snacks picker
---@return string|nil path Absolute path or nil
function M.get_path()
    -- Guard: Verify Snacks is loaded
    if not package.loaded["snacks"] then
        return nil
    end

    -- Access active pickers list
    local pickers = Snacks.picker.get()
    if not pickers or #pickers == 0 then
        return nil
    end

    -- Get the most recent/active picker
    local picker = pickers[1]
    if not picker then return nil end

    -- Get current item
    local item = picker:current()
    if not item then return nil end

    -- Return absolute path (.file or ._path check)
    return item.file or item._path
end

return M
