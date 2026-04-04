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
---@field needs_terminal boolean
---@field is_available fun(): boolean
---@field get_geometry fun(path: string, stat: table, env: FocalRenderEnv): FocalGeometry
---@field render fun(ctx: FocalRenderContext, done: fun(ok: boolean, result?: FocalRenderResult))
---@field clear fun()
---@field cleanup fun()

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
---@field chan integer|nil

---@class FocalRenderResult
---@field fit? FocalGeometry
---@field output? string

---@alias FocalBackend "auto" | string

---@class FocalCursorAnchor
---@field screen_row integer
---@field screen_col integer
---@field win_width integer
---@field win_height integer

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
