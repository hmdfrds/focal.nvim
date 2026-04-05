---@mod focal.types "Type Definitions"
---@brief [[
--- All shared type definitions for focal.nvim.
--- This file contains no runtime code — only LuaCATS annotations.
---@brief ]]

---@alias FocalState "idle" | "resolving" | "rendering" | "visible"

---@class FocalSource
---@field filetype string
---@field get_path fun(): string?

---@class FocalRenderer
---@field name string
---@field extensions string[]
---@field priority number
---@field needs_terminal boolean   true = render writes ANSI to a terminal channel (ctx.chan). false = render uses pixel protocol or writes to buffer directly.
---@field is_available fun(): boolean
---@field get_geometry fun(path: string, stat: table, env: FocalRenderEnv): FocalGeometry
---@field render fun(ctx: FocalRenderContext, done: fun(ok: boolean, result?: FocalRenderResult))
---@field clear fun()              Remove current render output from display. Called on hide, content swap, and before new render. Must be safe to call even if nothing is rendered.
---@field cleanup fun()            Full resource teardown (VimLeavePre). Called once when shutting down. Should release all held resources.

---@class FocalRenderEnv
---@field max_width integer
---@field max_height integer
---@field cell_width number
---@field cell_height number
---@field config FocalConfig

---@class FocalGeometry
---@field width integer
---@field height integer

---@class FocalRenderContext
---@field path string
---@field stat table
---@field buf integer
---@field win integer
---@field geometry FocalGeometry
---@field config FocalConfig
---@field chan integer|nil          Terminal channel ID (from nvim_open_term). Only set when renderer.needs_terminal is true. Use nvim_chan_send(chan, data) to write ANSI output.

---@class FocalRenderResult
---@field fit? FocalGeometry
---@field output? string

---@alias FocalBackend "auto" | string

---@class FocalCursorAnchor
---@field screen_row integer  1-indexed absolute screen row (from vim.fn.screenpos)
---@field screen_col integer  1-indexed absolute screen col (from vim.fn.screenpos)

---@class FocalGuard
---@field generation integer
---@field ctx_buf integer

---Cache entry. The mtime and max_geometry are encoded in the cache key, not stored here.
---@class FocalCacheEntry
---@field output string
---@field fit_geometry FocalGeometry

---@class FocalTerminalInfo
---@field has_graphics boolean
---@field protocol string?
---@field terminal string?
---@field in_tmux boolean
---@field in_ssh boolean
---@field in_mosh boolean
