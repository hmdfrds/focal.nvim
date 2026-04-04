---@mod iris "iris.nvim — Universal File Preview"
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

-- Deferred-require holders — populated lazily in setup().
local _config = nil
local _resolver = nil
local _renderer = nil
local _window = nil
local _preview = nil
local _cache_mod = nil
local _geometry = nil

-- Merged config table (the result of config.merge()).
local _cfg = nil

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

---Cancel the debounce timer if running.
local function cancel_debounce()
    if _debounce_timer then
        _debounce_timer:stop()
        _debounce_timer:close()
        _debounce_timer = nil
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
    local path = source.get_path()
    if not path then
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
---@param source IrisSource
---@return boolean
function M.register_source(source)
    if not _setup_done then
        _pending_sources[#_pending_sources + 1] = source
        return true
    end
    return _resolver.register_source(source)
end

---Register a renderer. Before setup(), queued and drained later.
---@param renderer IrisRenderer
---@return boolean
function M.register_renderer(renderer)
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
    if _cfg then
        _cfg.enabled = true
    end
end

---Disable previews at runtime and hide any active preview.
function M.disable()
    if _cfg then
        _cfg.enabled = false
    end
    if _preview_mgr then
        _preview_mgr:hide()
    end
end

---Toggle enabled state.
function M.toggle()
    if _cfg and _cfg.enabled then
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
    if not _preview_mgr then
        return
    end
    _preview_mgr:show(path)
    if path then
        local buf = vim.api.nvim_get_current_buf()
        vim.api.nvim_create_autocmd("CursorMoved", {
            buffer = buf,
            once = true,
            callback = function()
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
    local Terminal = require("iris.terminal")
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
        _debounce_timer:start(_cfg.debounce_ms, 0, vim.schedule_wrap(function()
            cancel_debounce()
            if not _cfg or not _cfg.enabled then
                return
            end
            -- Re-read cursor position at fire time, not capture time.
            _preview_mgr:show()
        end))
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

---Cleanup handler for VimLeavePre.
local function on_vim_leave()
    cancel_debounce()
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
    vim.api.nvim_create_user_command("IrisToggle", function()
        M.toggle()
    end, { desc = "Toggle iris.nvim preview on/off" })

    vim.api.nvim_create_user_command("IrisEnable", function()
        M.enable()
    end, { desc = "Enable iris.nvim previews" })

    vim.api.nvim_create_user_command("IrisDisable", function()
        M.disable()
    end, { desc = "Disable iris.nvim previews" })

    vim.api.nvim_create_user_command("IrisShow", function(opts)
        local path = opts.args ~= "" and opts.args or nil
        M.show(path)
    end, { nargs = "?", complete = "file", desc = "Show iris.nvim preview" })

    vim.api.nvim_create_user_command("IrisHide", function()
        M.hide()
    end, { desc = "Hide iris.nvim preview" })

    vim.api.nvim_create_user_command("IrisStatus", function()
        local st = M.status()
        if st then
            vim.notify(vim.inspect(st), vim.log.levels.INFO)
        else
            vim.notify("[iris] Not initialized", vim.log.levels.WARN)
        end
    end, { desc = "Show iris.nvim status" })
end

-- ---------------------------------------------------------------------------
-- Autocmd registration
-- ---------------------------------------------------------------------------

local function register_autocmds()
    local group = vim.api.nvim_create_augroup("IrisAutoCmds", { clear = true })

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

            vim.api.nvim_create_autocmd({ "VimResized", "WinScrolled" }, {
                group = group,
                buffer = buf,
                callback = on_resize,
            })
        end,
    })

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = on_vim_leave,
    })
end

-- ---------------------------------------------------------------------------
-- setup()
-- ---------------------------------------------------------------------------

---Initialize iris.nvim. Idempotent — safe to call multiple times.
---@param user_opts? table
function M.setup(user_opts)
    -- Deferred requires — only loaded on first setup().
    _config = require("iris.config")
    _resolver = require("iris.resolver")
    _renderer = require("iris.renderer")
    _window = require("iris.window")
    _preview = require("iris.preview")
    _cache_mod = require("iris.lib.cache")
    _geometry = require("iris.lib.geometry")

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
                    if pr.name == r.name then exists = true; break end
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
    _cfg = _config.merge(user_opts)

    -- Load built-in sources and renderers.
    _resolver.load_builtins()
    _renderer.load_builtins()

    -- Drain pending source queue.
    for _, source in ipairs(_pending_sources) do
        _resolver.register_source(source)
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
        vim.notify(
            "[iris] No renderers available. Previews will not work.",
            vim.log.levels.WARN
        )
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

    -- Register user commands (idempotent — nvim overwrites on name collision).
    register_commands()

    _setup_done = true
end

return M
