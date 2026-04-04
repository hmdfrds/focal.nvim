---@mod iris.preview "Preview Manager"
---@brief [[
--- State machine brain for iris.nvim previews.
--- States: idle -> resolving -> rendering -> visible
--- All async callbacks are guarded by generation counters.
---@brief ]]

local Guard = require("iris.lib.guard")
local Geo = require("iris.lib.geometry")

local M = {}
local PM = {}
PM.__index = PM

---Create a new Preview Manager.
---@param deps { config: IrisConfig, resolver: table, renderer_registry: table, window_mgr: table, cache: table }
---@return table
function M.new(deps)
    return setmetatable({
        _state = "idle", ---@type IrisState
        _generation = 0,
        _current_path = nil, ---@type string|nil
        _current_stat = nil, ---@type table|nil
        _current_renderer = nil, ---@type IrisRenderer|nil
        _window_mgr = deps.window_mgr,
        _renderer_registry = deps.renderer_registry,
        _resolver = deps.resolver,
        _config = deps.config,
        _cache = deps.cache,
        _notified = {}, ---@type table<string, boolean>
    }, PM)
end

-- ---------------------------------------------------------------------------
-- Getters
-- ---------------------------------------------------------------------------

---Return the current state.
---@return IrisState
function PM:get_state()
    return self._state
end

---Return the current generation counter.
---@return integer
function PM:get_generation()
    return self._generation
end

---Return the path currently being previewed, or nil.
---@return string|nil
function PM:get_current_path()
    return self._current_path
end

---Return the name of the current renderer, or nil.
---@return string|nil
function PM:get_current_renderer_name()
    if self._current_renderer then
        return self._current_renderer.name
    end
    return nil
end

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

---Read cursor position and surrounding window geometry to build an anchor.
---@return IrisCursorAnchor
function PM:_create_anchor()
    return {
        screen_row = vim.fn.winline(),
        screen_col = vim.fn.wincol(),
        win_width = vim.api.nvim_win_get_width(0),
        win_height = vim.api.nvim_win_get_height(0),
    }
end

---Build the render environment from config and terminal cell size.
---@return IrisRenderEnv
function PM:_build_env()
    local avail = Geo.max_available(
        vim.o.columns,
        vim.o.lines,
        self._config.max_width_percent,
        self._config.max_height_percent,
        self._config.max_width,
        self._config.max_height,
        Geo.overflow_margin(self._config.border)
    )
    -- Determine terminal cell pixel size (fallback to common defaults).
    local cell_w = 8
    local cell_h = 16
    if vim.o.columns > 0 and vim.o.lines > 0 then
        local tw = vim.env.COLUMNS_PIXELS or (vim.o.columns * 8)
        local th = vim.env.LINES_PIXELS or (vim.o.lines * 16)
        cell_w = math.max(1, math.floor(tonumber(tw) / vim.o.columns))
        cell_h = math.max(1, math.floor(tonumber(th) / vim.o.lines))
    end
    return {
        max_width = avail.width,
        max_height = avail.height,
        cell_width = cell_w,
        cell_height = cell_h,
        config = self._config,
    }
end

---Emit a notification only once per key per session.
---@param key string Unique key for the notification
---@param msg string Message format
---@param ... any Format arguments
function PM:_notify_once(key, msg, ...)
    if self._notified[key] then
        return
    end
    self._notified[key] = true
    vim.notify(string.format(msg, ...), vim.log.levels.WARN)
end

-- ---------------------------------------------------------------------------
-- State transitions
-- ---------------------------------------------------------------------------

---Hide the preview. Increments generation to cancel in-flight work.
---Idempotent and safe from any state.
function PM:hide()
    self._generation = self._generation + 1

    -- Clear current renderer output.
    if self._current_renderer then
        pcall(self._current_renderer.clear)
    end

    -- Close the floating window.
    self._window_mgr:close()

    -- Reset state.
    self._state = "idle"
    self._current_path = nil
    self._current_stat = nil
    self._current_renderer = nil

    -- Fire user callback.
    if self._config.on_hide then
        pcall(self._config.on_hide)
    end
end

---Show a preview. If path is nil, resolve from the current source adapter.
---@param path? string Explicit file path to preview
function PM:show(path)
    -- Check if previewing is enabled.
    if not self._config.enabled then
        return
    end

    -- Resolve path from source adapter if not provided.
    if not path then
        local ft = vim.bo.filetype
        local source = self._resolver.resolve(ft)
        if not source then
            return
        end
        path = source.get_path()
        if not path then
            return
        end
    end

    -- Extract extension and find a renderer.
    local ext = Geo.extract_extension(path)
    if not ext then
        return
    end
    ext = ext:lower()

    local renderer
    if self._config.backend and self._config.backend ~= "auto" then
        renderer = self._renderer_registry.find_by_name(self._config.backend)
        if renderer and not renderer.is_available() then
            self:_notify_once(
                "backend_unavail_" .. self._config.backend,
                "[iris] Backend '%s' is not available, falling back to auto",
                self._config.backend
            )
            renderer = nil
        end
    end
    if not renderer then
        renderer = self._renderer_registry.find_renderer(ext)
    end
    if not renderer then
        return
    end

    -- If already visible with an open window, use content swap for speed.
    if self._state == "visible" and self._window_mgr:is_open() then
        self:_content_swap(path, ext, renderer)
        return
    end

    -- Begin async resolve: bump generation, set state, create guard.
    self._generation = self._generation + 1
    self._state = "resolving"

    local guard = Guard.new(
        self._generation,
        vim.api.nvim_get_current_buf(),
        vim.api.nvim_win_get_cursor(0)
    )

    -- Async stat the file.
    local uv = vim.uv or vim.loop
    uv.fs_stat(path, function(err, stat)
        vim.schedule(function()
            if not Guard.is_valid(guard, self._generation) then
                self._state = "idle"
                return
            end
            if err or not stat then
                self._state = "idle"
                return
            end

            -- Check file size limit.
            local max_bytes = self._config.max_file_size_mb * 1024 * 1024
            if stat.size and stat.size > max_bytes then
                self:_notify_once(
                    "filesize_" .. path,
                    "[iris] File too large: %s (%.1f MB > %d MB limit)",
                    path,
                    stat.size / 1024 / 1024,
                    self._config.max_file_size_mb
                )
                self._state = "idle"
                return
            end

            self:_render(path, stat, renderer, guard)
        end)
    end)
end

---Internal render pipeline. Called after stat succeeds.
---@param path string
---@param stat table
---@param renderer IrisRenderer
---@param guard IrisGuard
function PM:_render(path, stat, renderer, guard)
    self._state = "rendering"

    local env = self:_build_env()
    local geometry = renderer.get_geometry(path, stat, env)
    local mtime = stat.mtime and stat.mtime.sec or 0
    local max_geo = { width = env.max_width, height = env.max_height }

    -- Check cache first.
    local cached = self._cache:get(path, mtime, max_geo)
    if cached and cached.fit_geometry then
        geometry = cached.fit_geometry
    end

    -- Create anchor and open window.
    local anchor = self:_create_anchor()

    local title = nil
    if self._config.title then
        local fname = vim.fn.fnamemodify(path, ":t")
        title = " " .. fname .. " "
    end

    local buf, win = self._window_mgr:open(geometry, anchor, title)

    -- If cached output is available for a terminal renderer, replay it.
    if cached and cached.output and renderer.needs_terminal then
        local chan_ok, chan = pcall(vim.api.nvim_open_term, buf, {})
        if chan_ok and chan then
            pcall(vim.api.nvim_chan_send, chan, cached.output)
        end
        -- Tight-fit to cached geometry.
        if cached.fit_geometry then
            self._window_mgr:resize(cached.fit_geometry)
        end
        self._state = "visible"
        self._current_path = path
        self._current_stat = stat
        self._current_renderer = renderer
        if self._config.on_show then
            pcall(self._config.on_show, path, renderer.name)
        end
        return
    end

    -- Build render context.
    local ctx = {
        path = path,
        stat = stat,
        buf = buf,
        win = win,
        geometry = geometry,
        config = self._config,
    }

    -- Invoke the renderer.
    renderer.render(ctx, function(ok, result)
        vim.schedule(function()
            if not Guard.is_valid(guard, self._generation) then
                self._state = "idle"
                self._window_mgr:close()
                return
            end
            if not ok then
                self._state = "idle"
                self._window_mgr:close()
                return
            end

            result = result or {}

            -- Tight-fit: resize window to actual rendered content size.
            if result.fit then
                self._window_mgr:resize(result.fit)
            end

            -- Cache the output for terminal renderers.
            if result.output and renderer.needs_terminal then
                self._cache:put(path, mtime, max_geo, result.output, result.fit or geometry)
            end

            self._state = "visible"
            self._current_path = path
            self._current_stat = stat
            self._current_renderer = renderer

            if self._config.on_show then
                pcall(self._config.on_show, path, renderer.name)
            end
        end)
    end)
end

---Swap content in an already-open window (fast path for cursor movement).
---@param path string
---@param ext string
---@param renderer IrisRenderer
function PM:_content_swap(path, ext, renderer)
    -- Clear old renderer output.
    if self._current_renderer then
        pcall(self._current_renderer.clear)
    end

    -- Replace buffer if the renderer type changes.
    local needs_new_buf = (self._current_renderer ~= renderer)
    if needs_new_buf then
        self._window_mgr:replace_buffer()
    end

    -- Bump generation for the new content.
    self._generation = self._generation + 1

    local guard = Guard.new(
        self._generation,
        vim.api.nvim_get_current_buf(),
        vim.api.nvim_win_get_cursor(0)
    )

    -- Async stat for the new path.
    local uv = vim.uv or vim.loop
    uv.fs_stat(path, function(err, stat)
        vim.schedule(function()
            if not Guard.is_valid(guard, self._generation) then
                return
            end
            if err or not stat then
                self:hide()
                return
            end

            -- Check file size limit.
            local max_bytes = self._config.max_file_size_mb * 1024 * 1024
            if stat.size and stat.size > max_bytes then
                self:hide()
                return
            end

            self._state = "rendering"
            local env = self:_build_env()
            local geometry = renderer.get_geometry(path, stat, env)
            local mtime = stat.mtime and stat.mtime.sec or 0
            local max_geo = { width = env.max_width, height = env.max_height }

            -- Check cache.
            local cached = self._cache:get(path, mtime, max_geo)
            if cached and cached.output and renderer.needs_terminal then
                local buf = self._window_mgr:get_buf()
                if buf then
                    local chan_ok, chan = pcall(vim.api.nvim_open_term, buf, {})
                    if chan_ok and chan then
                        pcall(vim.api.nvim_chan_send, chan, cached.output)
                    end
                end
                if cached.fit_geometry then
                    self._window_mgr:resize(cached.fit_geometry)
                end
                self._state = "visible"
                self._current_path = path
                self._current_stat = stat
                self._current_renderer = renderer
                return
            end

            -- Resize window to new geometry.
            self._window_mgr:resize(geometry)

            -- If we need a fresh buffer for a terminal renderer, replace.
            if renderer.needs_terminal and not needs_new_buf then
                self._window_mgr:replace_buffer()
            end

            local buf = self._window_mgr:get_buf()
            local win = self._window_mgr:get_win()
            if not buf or not win then
                self:hide()
                return
            end

            local ctx = {
                path = path,
                stat = stat,
                buf = buf,
                win = win,
                geometry = geometry,
                config = self._config,
            }

            renderer.render(ctx, function(ok, result)
                vim.schedule(function()
                    if not Guard.is_valid(guard, self._generation) then
                        return
                    end
                    if not ok then
                        self:hide()
                        return
                    end

                    result = result or {}

                    if result.fit then
                        self._window_mgr:resize(result.fit)
                    end

                    if result.output and renderer.needs_terminal then
                        self._cache:put(path, mtime, max_geo, result.output, result.fit or geometry)
                    end

                    self._state = "visible"
                    self._current_path = path
                    self._current_stat = stat
                    self._current_renderer = renderer
                end)
            end)
        end)
    end)
end

---Handle cursor movement to a new file.
---Same path: reposition. Different previewable: content swap. Otherwise: hide.
---@param new_path? string
---@param new_extension? string
function PM:on_cursor_moved(new_path, new_extension)
    if not new_path then
        if self._state ~= "idle" then
            self:hide()
        end
        return
    end

    -- Same path: just reposition the window.
    if new_path == self._current_path then
        if self._window_mgr:is_open() then
            local anchor = self:_create_anchor()
            self._window_mgr:reposition(anchor)
        end
        return
    end

    -- Different path: check if the new file is previewable.
    local ext = new_extension or Geo.extract_extension(new_path)
    if not ext then
        self:hide()
        return
    end
    ext = ext:lower()

    local renderer
    if self._config.backend and self._config.backend ~= "auto" then
        renderer = self._renderer_registry.find_by_name(self._config.backend)
        if renderer and not renderer.is_available() then
            renderer = nil
        end
    end
    if not renderer then
        renderer = self._renderer_registry.find_renderer(ext)
    end

    if not renderer then
        self:hide()
        return
    end

    -- If window is open, use fast content swap.
    if self._state == "visible" and self._window_mgr:is_open() then
        self:_content_swap(new_path, ext, renderer)
    else
        self:show(new_path)
    end
end

---Handle terminal resize. Visible: reposition. Rendering: cancel and restart.
function PM:on_resize()
    if self._state == "visible" and self._window_mgr:is_open() then
        local anchor = self:_create_anchor()
        self._window_mgr:reposition(anchor)
    elseif self._state == "rendering" then
        local path = self._current_path
        self:hide()
        if path then
            self:show(path)
        end
    end
end

---Return structured diagnostic data about the preview manager state.
---@return { state: IrisState, generation: integer, current_path: string|nil, renderer: string|nil, cache: table }
function PM:status()
    return {
        state = self._state,
        generation = self._generation,
        current_path = self._current_path,
        renderer = self:get_current_renderer_name(),
        cache = self._cache:stats(),
    }
end

return M
