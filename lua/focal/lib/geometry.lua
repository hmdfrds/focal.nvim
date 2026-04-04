---@mod focal.lib.geometry "Geometry — Pure Math Functions"
---@brief [[
--- All geometry calculations for focal.nvim.
--- Pure functions with zero Neovim UI side effects (except tabline_offset).
---@brief ]]

local M = {}

---Scale image dimensions to fit within max constraints, preserving aspect ratio.
---@param img_w number Image width in pixels
---@param img_h number Image height in pixels
---@param cell_w number Terminal cell width in pixels
---@param cell_h number Terminal cell height in pixels
---@param max_cols integer Max width in cells
---@param max_rows integer Max height in cells
---@param min_w integer Min width in cells
---@param min_h integer Min height in cells
---@return FocalGeometry
function M.scale_to_fit(img_w, img_h, cell_w, cell_h, max_cols, max_rows, min_w, min_h)
    if img_w <= 0 or img_h <= 0 or cell_w <= 0 or cell_h <= 0 then
        return { width = min_w, height = min_h }
    end
    local img_cols = img_w / cell_w
    local img_rows = img_h / cell_h
    local scale = 1.0
    if img_cols > max_cols then
        scale = math.min(scale, max_cols / img_cols)
    end
    if img_rows > max_rows then
        scale = math.min(scale, max_rows / img_rows)
    end
    return {
        width = math.max(min_w, math.floor(img_cols * scale)),
        height = math.max(min_h, math.floor(img_rows * scale)),
    }
end

---Compute max available preview dimensions.
---@param columns integer vim.o.columns
---@param lines integer vim.o.lines
---@param max_w_pct number Max width percentage (1-100)
---@param max_h_pct number Max height percentage (1-100)
---@param max_w integer Absolute max width in cells
---@param max_h integer Absolute max height in cells
---@param margin? integer Border margin (default 2)
---@return FocalGeometry
function M.max_available(columns, lines, max_w_pct, max_h_pct, max_w, max_h, margin)
    margin = margin or 2
    local w = math.min(math.floor(columns * max_w_pct / 100), max_w) - margin
    local h = math.min(math.floor(lines * max_h_pct / 100), max_h) - margin
    return { width = math.max(1, w), height = math.max(1, h) }
end

---Compute adaptive float position relative to cursor.
---@param width integer Window width
---@param height integer Window height
---@param anchor FocalCursorAnchor
---@param col_offset integer Horizontal gap
---@param row_offset integer Vertical gap
---@param editor_cols integer Editor column count (vim.o.columns)
---@return { row: integer, col: integer }
function M.adaptive_position(width, height, anchor, col_offset, row_offset, editor_cols)
    local col = col_offset
    if anchor.screen_col + width + col_offset > editor_cols then
        col = -width - col_offset
    end
    local row = row_offset
    if anchor.screen_row + height + row_offset > anchor.win_height then
        row = -height - row_offset
    end
    return { row = row, col = col }
end

---Compute overflow margin from border style.
---@param border string|string[]
---@return integer
function M.overflow_margin(border)
    if border == "none" then
        return 0
    end
    return 2
end

---Compute tabline y-offset for image.nvim rendering.
---@return integer
function M.tabline_offset()
    local showtabline = vim.o.showtabline
    local has_tabs = #vim.api.nvim_list_tabpages() > 1
    if showtabline == 2 or (showtabline == 1 and has_tabs) then
        return -1
    end
    return 0
end

---Extract file extension from a path.
---Uses non-greedy pattern to match only the final extension.
---@param path string
---@return string|nil
function M.extract_extension(path)
    return path:match("%.([^%.]+)$")
end

return M
