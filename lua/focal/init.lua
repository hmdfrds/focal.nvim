---@mod focal "Focal.nvim: Neovim Image Previewer"
---@brief [[
--- Image previewer for Neovim file explorers.
---
--- Features:
--- - Pixel-perfect rendering
--- - Window pooling for flicker-free updates
--- - Async I/O for non-blocking performance
--- - Multi-adapter support (Neo-tree, Nvim-tree, Oil)
---@brief ]]

local Config = require("focal.config")
local Resolver = require("focal.resolver")
local UI = require("focal.ui")
local Utils = require("focal.utils")

local M = {}

---@type FocalConfig
M.opts = Config.defaults

---@type table<string, boolean>
local extensions_lookup = {}

---Setup focal.nvim
---@param user_opts? FocalConfig
function M.setup(user_opts)
	-- 1. Configuration
	M.opts = Config.merge(user_opts)

	-- 2. Extensions Lookup (Optimization)
	extensions_lookup = {}
	if M.opts.extensions then
		for _, ext in ipairs(M.opts.extensions) do
			extensions_lookup[ext:lower()] = true
		end
	end

	-- 3. Ensure Dependencies
	local ok, image_api = Utils.safe_require("image")
	if not ok then
		Utils.notify("image.nvim is required.", vim.log.levels.ERROR)
		return
	end

	-- Auto-init image.nvim if needed
	local initialized = pcall(image_api.create_report)
	if not initialized then
		pcall(image_api.setup, {})
	end

	-- 4. AutoCommands
	local augroup = vim.api.nvim_create_augroup("FocalAutoCmds", { clear = true })
	local supported_filetypes = Resolver.get_supported_filetypes()

	vim.api.nvim_create_autocmd("FileType", {
		group = augroup,
		pattern = supported_filetypes,
		callback = function()
			local b = vim.api.nvim_get_current_buf()
			vim.api.nvim_clear_autocmds({ group = augroup, buffer = b })

			-- Hover Trigger
			vim.api.nvim_create_autocmd("CursorHold", {
				group = augroup,
				buffer = b,
				callback = function()
					local current_cursor = vim.api.nvim_win_get_cursor(0)
					vim.schedule(function()
						-- Race condition check
						if vim.api.nvim_get_current_buf() ~= b then return end
						local new_cursor = vim.api.nvim_win_get_cursor(0)
						if new_cursor[1] ~= current_cursor[1] or new_cursor[2] ~= current_cursor[2] then
							return
						end

						local path = Resolver.get_cursor_path()
						if path then
							local ext = path:match("^.+%.(.+)$")
							if ext and extensions_lookup[ext:lower()] then
								UI.show(path, M.opts)
							end
						end
					end)
				end,
			})

			-- Clear Trigger
			vim.api.nvim_create_autocmd({ "CursorMoved", "WinLeave", "BufLeave", "BufHidden" }, {
				group = augroup,
				buffer = b,
				callback = UI.hide,
			})
		end,
	})

	-- Debug Command
	vim.api.nvim_create_user_command("FocalDebug", function()
		print(vim.inspect({
			plugin = "focal.nvim",
			opts = M.opts,
			state = require("focal.ui").state,
		}))
	end, {})
end

return M
