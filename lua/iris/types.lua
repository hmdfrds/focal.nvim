---@mod iris.types "Type Definitions"
---@brief [[
--- All shared type definitions for iris.nvim.
--- This file contains no runtime code — only LuaCATS annotations.
---@brief ]]

---@alias IrisState "idle" | "resolving" | "rendering" | "visible"

---@class IrisSource
---@field filetype string
---@field get_path fun(): string?

---@class IrisRenderer
---@field name string
---@field extensions string[]
---@field priority number
---@field needs_terminal boolean
---@field is_available fun(): boolean
---@field get_geometry fun(path: string, stat: table, env: IrisRenderEnv): IrisGeometry
---@field render fun(ctx: IrisRenderContext, done: fun(ok: boolean, result?: IrisRenderResult))
---@field clear fun()
---@field cleanup fun()

---@class IrisRenderEnv
---@field max_width integer
---@field max_height integer
---@field cell_width number
---@field cell_height number
---@field config IrisConfig

---@class IrisGeometry
---@field width integer
---@field height integer

---@class IrisRenderContext
---@field path string
---@field stat table
---@field buf integer
---@field win integer
---@field geometry IrisGeometry
---@field config IrisConfig
---@field chan integer|nil

---@class IrisRenderResult
---@field fit? IrisGeometry
---@field output? string

---@alias IrisBackend "auto" | string

---@class IrisCursorAnchor
---@field screen_row integer
---@field screen_col integer
---@field win_width integer
---@field win_height integer

---@class IrisGuard
---@field generation integer
---@field ctx_buf integer
---@field ctx_cursor integer[]

---@class IrisCacheEntry
---@field output string
---@field fit_geometry IrisGeometry

---@class IrisTerminalInfo
---@field has_graphics boolean
---@field protocol string?
---@field terminal string?
---@field in_tmux boolean
---@field in_ssh boolean
---@field in_mosh boolean
