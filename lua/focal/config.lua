---@mod focal.config "Configuration Module"
---@brief [[
--- Handles user configuration merging and validation.
---@brief ]]

local M = {}

---@class FocalConfig
---@field debug boolean Enable debug notifications
---@field min_width number Minimum width of preview window (cells)
---@field min_height number Minimum height of preview window (cells)
---@field max_width_pct number Max width as % of editor
---@field max_height_pct number Max height as % of editor
---@field max_cells number Absolute max cells to prevent overflow
---@field extensions string[] List of supported image extensions
---@field max_file_size_mb number Max file size in MB to preview

---@type FocalConfig
M.defaults = {
	debug = false,
	min_width = 10,
	min_height = 5,
	max_width_pct = 50,
	max_height_pct = 50,
	max_cells = 60,
	max_file_size_mb = 5,
	extensions = { "png", "jpg", "jpeg", "webp", "gif", "bmp" },
}

---Validate and merge user options
---@param user_opts? FocalConfig
---@return FocalConfig
function M.merge(user_opts)
	local opts = vim.tbl_deep_extend("force", M.defaults, user_opts or {})

	-- Fix array merging for extensions (replace instead of merge)
	if user_opts and user_opts.extensions then
		opts.extensions = user_opts.extensions
	end

	return opts
end

return M
