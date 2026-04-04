---@mod focal.lib.guard "Guard — Async Context Validation"
---@brief [[
--- Generation counter and context validation for async operations.
--- Guards capture state at dispatch time and validate it at callback time.
---@brief ]]

local M = {}

---Create a new guard capturing the current context.
---@param generation integer Current generation counter value
---@param buf integer Buffer ID at dispatch time
---@param cursor integer[] Cursor position {row, col} at dispatch time
---@return FocalGuard
function M.new(generation, buf, cursor)
    return {
        generation = generation,
        ctx_buf = buf,
        ctx_cursor = { cursor[1], cursor[2] },
    }
end

---Check if a guard is still valid.
---@param guard FocalGuard
---@param current_generation integer
---@return boolean
function M.is_valid(guard, current_generation)
    if guard.generation ~= current_generation then
        return false
    end
    if vim.api.nvim_get_current_buf() ~= guard.ctx_buf then
        return false
    end
    return true
end

return M
