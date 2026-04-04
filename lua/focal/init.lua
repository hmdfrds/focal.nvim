---@mod focal "focal.nvim — Universal File Preview"
---@brief [[
--- Hover over a file in any explorer, see a preview.
---@brief ]]

local M = {}
M.version = "1.0.0"

-- ---------------------------------------------------------------------------
-- Private state
-- ---------------------------------------------------------------------------

local _pending_sources = {}
local _pending_renderers = {}
local _preview_mgr = nil ---@type table|nil
local _setup_done = false
local _debounce_timer = nil ---@type uv_timer_t|nil
local _resize_timer = nil ---@type uv_timer_t|nil
local _oneshot_autocmd_id = nil ---@type integer|nil

-- Deferred-require holders — populated lazily in setup().
local _config_mod = nil -- the focal.config module (schema/merge logic)
local _resolver = nil
local _renderer = nil
local _window = nil
local _preview = nil
local _cache_mod = nil
local _geometry = nil

-- Merged config table (the result of _config_mod.merge()).
local _cfg = nil

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---Cancel the debounce timer if running.
local function cancel_debounce()
    if _debounce_timer then
        _debounce_timer:stop()
        if not _debounce_timer:is_closing() then
            _debounce_timer:close()
        end
        _debounce_timer = nil
    end
end

---Cancel the resize debounce timer if running.
local function cancel_resize_debounce()
    if _resize_timer then
        _resize_timer:stop()
        if not _resize_timer:is_closing() then
            _resize_timer:close()
        end
        _resize_timer = nil
    end
end

---Resolve the path under the cursor via the source adapter.
---@return string|nil path, string|nil ext
local function resolve_cursor_path()
    local ft = vim.bo.filetype
    local source = _resolver.resolve(ft)
    if not source then
        return nil, nil
    end
    local ok, path = pcall(source.get_path)
    if not ok or type(path) ~= "string" then
        return nil, nil
    end
    local ext = _geometry.extract_extension(path)
    if ext then
        ext = ext:lower()
    end
    return path, ext
end

-- ---------------------------------------------------------------------------
-- Public API: register_source / register_renderer
-- ---------------------------------------------------------------------------

---Register a source adapter. Before setup(), queued and drained later.
---@param source FocalSource
---@return boolean
function M.register_source(source)
    if type(source) ~= "table" then
        vim.notify("[focal] register_source: expected table, got " .. type(source), vim.log.levels.WARN)
        return false
    end
    if not _setup_done then
        _pending_sources[#_pending_sources + 1] = source
        return true
    end
    return _resolver.register_source(source)
end

---Register a renderer. Before setup(), queued and drained later.
---@param renderer FocalRenderer
---@return boolean
function M.register_renderer(renderer)
    if type(renderer) ~= "table" then
        vim.notify("[focal] register_renderer: expected table, got " .. type(renderer), vim.log.levels.WARN)
        return false
    end
    if not _setup_done then
        _pending_renderers[#_pending_renderers + 1] = renderer
        return true
    end
    return _renderer.register_renderer(renderer)
end

-- ---------------------------------------------------------------------------
-- Enable / disable / toggle
-- ---------------------------------------------------------------------------

---Enable previews at runtime.
function M.enable()
    if not _cfg or not _preview_mgr then
        vim.notify("[focal] setup() has not been called", vim.log.levels.WARN)
        return
    end
    _cfg.enabled = true
end

---Disable previews at runtime and hide any active preview.
function M.disable()
    cancel_debounce()
    cancel_resize_debounce()
    if _cfg then
        _cfg.enabled = false
    end
    if _preview_mgr then
        _preview_mgr:hide()
    end
end

---Toggle enabled state.
function M.toggle()
    if not _cfg or not _preview_mgr then
        vim.notify("[focal] setup() has not been called", vim.log.levels.WARN)
        return
    end
    if _cfg.enabled then
        M.disable()
    else
        M.enable()
    end
end

---Return whether previews are currently enabled.
---@return boolean
function M.is_enabled()
    return _cfg ~= nil and _cfg.enabled
end

-- ---------------------------------------------------------------------------
-- Show / hide
-- ---------------------------------------------------------------------------

---Show a preview. If path is given, also creates a one-shot CursorMoved
---autocmd on the current buffer so the preview auto-dismisses on move.
---@param path? string
function M.show(path)
    if not _cfg or not _preview_mgr then
        vim.notify("[focal] setup() has not been called", vim.log.levels.WARN)
        return
    end
    _preview_mgr:show(path)
    if path then
        -- Clear any previous one-shot autocmd to prevent accumulation.
        if _oneshot_autocmd_id then
            pcall(vim.api.nvim_del_autocmd, _oneshot_autocmd_id)
            _oneshot_autocmd_id = nil
        end
        local buf = vim.api.nvim_get_current_buf()
        _oneshot_autocmd_id = vim.api.nvim_create_autocmd("CursorMoved", {
            buffer = buf,
            once = true,
            callback = function()
                _oneshot_autocmd_id = nil
                M.hide()
            end,
        })
    end
end

---Hide the active preview.
function M.hide()
    cancel_debounce()
    if _preview_mgr then
        _preview_mgr:hide()
    end
end

---Return structured diagnostic data.
---@return table|nil
function M.status()
    if not _preview_mgr then
        return nil
    end
    local s = _preview_mgr:status()
    local Terminal = require("focal.terminal")
    s.terminal = Terminal.detect()
    return s
end

-- ---------------------------------------------------------------------------
-- Autocmd handlers
-- ---------------------------------------------------------------------------

---CursorHold handler — triggers preview after optional debounce.
local function on_cursor_hold()
    if not _cfg or not _cfg.enabled or not _preview_mgr then
        return
    end
    if _cfg.debounce_ms > 0 then
        cancel_debounce()
        _debounce_timer = vim.uv.new_timer()
        if not _debounce_timer then
            return
        end
        _debounce_timer:start(
            _cfg.debounce_ms,
            0,
            vim.schedule_wrap(function()
                cancel_debounce()
                if not _cfg or not _cfg.enabled then
                    return
                end
                -- Re-read cursor position at fire time, not capture time.
                _preview_mgr:show()
            end)
        )
    else
        _preview_mgr:show()
    end
end

---CursorMoved handler — reposition, content-swap, or hide.
local function on_cursor_moved()
    if not _cfg or not _cfg.enabled or not _preview_mgr then
        return
    end
    cancel_debounce()
    local path, ext = resolve_cursor_path()
    if path then
        _preview_mgr:on_cursor_moved(path, ext)
    else
        _preview_mgr:hide()
    end
end

---Hide handler — unconditional hide for WinLeave, BufLeave, etc.
local function on_hide()
    cancel_debounce()
    if _preview_mgr then
        _preview_mgr:hide()
    end
end

---Resize handler.
local function on_resize()
    if _preview_mgr then
        _preview_mgr:on_resize()
    end
end

---Debounced resize/scroll handler (50ms).
local function on_resize_debounced()
    cancel_resize_debounce()
    _resize_timer = vim.uv.new_timer()
    if not _resize_timer then
        return
    end
    _resize_timer:start(
        50,
        0,
        vim.schedule_wrap(function()
            cancel_resize_debounce()
            on_resize()
        end)
    )
end

---Cleanup handler for VimLeavePre.
local function on_vim_leave()
    cancel_debounce()
    cancel_resize_debounce()
    if _preview_mgr then
        _preview_mgr:hide()
    end
    -- Call cleanup() on all registered renderers to release resources.
    if _renderer then
        for _, r in ipairs(_renderer.get_all_renderers()) do
            pcall(r.cleanup)
        end
    end
end

-- ---------------------------------------------------------------------------
-- User commands
-- ---------------------------------------------------------------------------

local function register_commands()
    vim.api.nvim_create_user_command("FocalToggle", function()
        M.toggle()
    end, { desc = "Toggle focal.nvim preview on/off" })

    vim.api.nvim_create_user_command("FocalEnable", function()
        M.enable()
    end, { desc = "Enable focal.nvim previews" })

    vim.api.nvim_create_user_command("FocalDisable", function()
        M.disable()
    end, { desc = "Disable focal.nvim previews" })

    vim.api.nvim_create_user_command("FocalShow", function(opts)
        local path = opts.args ~= "" and opts.args or nil
        M.show(path)
    end, { nargs = "?", complete = "file", desc = "Show focal.nvim preview" })

    vim.api.nvim_create_user_command("FocalHide", function()
        M.hide()
    end, { desc = "Hide focal.nvim preview" })

    vim.api.nvim_create_user_command("FocalStatus", function()
        local st = M.status()
        if st then
            vim.notify(vim.inspect(st), vim.log.levels.INFO)
        else
            vim.notify("[focal] Not initialized", vim.log.levels.WARN)
        end
    end, { desc = "Show focal.nvim status" })
end

-- ---------------------------------------------------------------------------
-- Autocmd registration
-- ---------------------------------------------------------------------------

local function register_autocmds()
    local group = vim.api.nvim_create_augroup("FocalAutoCmds", { clear = true })

    local filetypes = _resolver.get_registered_filetypes()
    if #filetypes == 0 then
        return
    end

    -- FileType event creates buffer-local autocmds for each registered filetype.
    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = filetypes,
        callback = function(ev)
            local buf = ev.buf

            -- Clear any existing buffer-local autocmds in this group to prevent
            -- accumulation on repeated FileType events for the same buffer.
            vim.api.nvim_clear_autocmds({ group = group, buffer = buf })

            vim.api.nvim_create_autocmd("CursorHold", {
                group = group,
                buffer = buf,
                callback = on_cursor_hold,
            })

            vim.api.nvim_create_autocmd("CursorMoved", {
                group = group,
                buffer = buf,
                callback = on_cursor_moved,
            })

            vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave", "BufHidden", "TabLeave" }, {
                group = group,
                buffer = buf,
                callback = on_hide,
            })

            vim.api.nvim_create_autocmd("WinClosed", {
                group = group,
                buffer = buf,
                callback = on_hide,
            })

            vim.api.nvim_create_autocmd("WinScrolled", {
                group = group,
                buffer = buf,
                callback = on_resize_debounced,
            })
        end,
    })

    -- VimResized is a global event (not buffer-local).
    vim.api.nvim_create_autocmd("VimResized", {
        group = group,
        callback = on_resize_debounced,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = on_vim_leave,
    })
end

-- ---------------------------------------------------------------------------
-- setup()
-- ---------------------------------------------------------------------------

---Initialize focal.nvim. Idempotent — safe to call multiple times.
---@param user_opts? table
function M.setup(user_opts)
    -- Deferred requires — only loaded on first setup().
    _config_mod = require("focal.config")
    _resolver = require("focal.resolver")
    _renderer = require("focal.renderer")
    _window = require("focal.window")
    _preview = require("focal.preview")
    _cache_mod = require("focal.lib.cache")
    _geometry = require("focal.lib.geometry")

    -- Cancel any in-flight timers before re-initialization.
    cancel_debounce()
    cancel_resize_debounce()

    -- If re-setup: hide active preview, snapshot current registries into pending.
    if _setup_done and _preview_mgr then
        _preview_mgr:hide()

        -- Snapshot live registrations so they survive the reset.
        for _, ft in ipairs(_resolver.get_registered_filetypes()) do
            local source = _resolver.resolve(ft)
            if source then
                _pending_sources[#_pending_sources + 1] = source
            end
        end

        -- Snapshot renderer registrations too
        for _, r_ext in ipairs(_renderer.get_supported_extensions()) do
            local r = _renderer.find_renderer(r_ext)
            if r then
                local exists = false
                for _, pr in ipairs(_pending_renderers) do
                    if pr.name == r.name then
                        exists = true
                        break
                    end
                end
                if not exists then
                    table.insert(_pending_renderers, r)
                end
            end
        end
    end

    -- Reset registries for a clean slate.
    _resolver._reset()
    _renderer._reset()

    -- Merge config.
    _cfg = _config_mod.merge(user_opts)

    -- Load built-in sources and renderers.
    _resolver.load_builtins()
    _renderer.load_builtins()

    -- Drain pending source queue (silent to suppress re-setup overwrite warnings).
    for _, source in ipairs(_pending_sources) do
        _resolver.register_source(source, true)
    end
    _pending_sources = {}

    -- Drain pending renderer queue.
    for _, rend in ipairs(_pending_renderers) do
        _renderer.register_renderer(rend)
    end
    _pending_renderers = {}

    -- Set extension whitelist from config.
    _renderer.set_whitelist(_cfg.extensions)

    -- Warn if zero renderers available.
    local supported = _renderer.get_supported_extensions()
    if #supported == 0 then
        vim.notify("[focal] No renderers available. Previews will not work.", vim.log.levels.WARN)
    end

    -- Create fresh WindowManager and PreviewManager.
    local window_mgr = _window.new(_cfg)
    local cache = _cache_mod.new()

    _preview_mgr = _preview.new({
        config = _cfg,
        resolver = _resolver,
        renderer_registry = _renderer,
        window_mgr = window_mgr,
        cache = cache,
    })

    -- Register autocmds (clears previous group on re-setup).
    register_autocmds()

    -- Re-trigger FileType for already-open explorer buffers so they get
    -- buffer-local autocmds (the augroup clear removed them).
    local filetypes = _resolver.get_registered_filetypes()
    local ft_set = {}
    for _, ft in ipairs(filetypes) do
        ft_set[ft] = true
    end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and ft_set[vim.bo[buf].filetype] then
            vim.api.nvim_exec_autocmds("FileType", {
                group = "FocalAutoCmds",
                buffer = buf,
            })
        end
    end

    -- Register user commands (idempotent — nvim overwrites on name collision).
    register_commands()

    _setup_done = true
end

return M
