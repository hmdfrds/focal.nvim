---@mod focal.renderers.image "image.nvim Renderer"
---@brief [[
--- Pixel-perfect image renderer via image.nvim.
--- Requires a terminal with graphics protocol support (kitty/sixel).
---@brief ]]

local Geo = require("focal.lib.geometry")

local M = {}

---@type table|nil  image.nvim API handle
local _image_api = nil

---@type table|nil  current image object
local _img = nil

---Check whether image.nvim is available and the terminal supports graphics.
---@return boolean
function M.is_available()
    local term = require("focal.terminal").detect()
    if not term.has_graphics then
        return false
    end

    local ok, api = pcall(require, "image")
    if not ok then return false end

    -- image.nvim must be initialized (setup() called) to expose from_file.
    if type(api.from_file) ~= "function" then
        return false
    end

    -- Verify image.nvim has actually been set up.
    -- image.nvim exposes from_file even before setup(), but it throws
    -- "image.nvim is not setup" when called. Guard against this.
    if type(api.setup) == "function" then
        local probe_ok, probe_err = pcall(api.from_file, "", { id = "focal-setup-probe" })
        if not probe_ok and type(probe_err) == "string" and probe_err:find("not setup") then
            return false
        end
    end

    _image_api = api
    return true
end

---Compute geometry for the image at the given path.
---@param path string
---@param stat table
---@param env FocalRenderEnv
---@return FocalGeometry
function M.get_geometry(path, stat, env)
    if not _image_api then return { width = env.max_width, height = env.max_height } end

    -- Clear any previous image to avoid leaks (e.g. when cache hit skips render()).
    M.clear()

    local img_ok, img = pcall(_image_api.from_file, path, {
        id = path .. "-focal-" .. (stat.mtime and stat.mtime.sec or 0),
    })
    if not img_ok or not img then
        return { width = env.max_width, height = env.max_height }
    end

    _img = img

    -- image.nvim handles its own pixel-level scaling internally via ioctl
    -- terminal dimensions. We just provide the max available cell window size
    -- and let image.nvim fill it with correct aspect ratio.
    return { width = env.max_width, height = env.max_height }
end

---Render the image into the preview window.
---@param ctx FocalRenderContext
---@param done fun(ok: boolean, result?: FocalRenderResult)
function M.render(ctx, done)
    if not _img then
        done(false)
        return
    end

    -- Set buffer/window on the image object so image.nvim renders into the float.
    _img.buffer = ctx.buf
    _img.window = ctx.win

    local ok, err = pcall(function()
        _img:render({
            x = 0,
            y = 0,
            width = ctx.geometry.width,
            height = ctx.geometry.height,
            with_virtual_padding = true,
            inline = false,
            y_offset = Geo.tabline_offset(),
        })
    end)

    if ok then
        done(true)
    else
        vim.notify("[focal] image.nvim render failed: " .. tostring(err), vim.log.levels.DEBUG)
        done(false)
    end
end

---Clear the current image from display.
function M.clear()
    if _img then
        pcall(function() _img:clear() end)
        _img = nil
    end
end

---Full cleanup: clear image and release the API reference.
function M.cleanup()
    M.clear()
    _image_api = nil
end

---Register this renderer with the renderer registry.
---@param registry table
function M.register(registry)
    registry.register_renderer({
        name = "image.nvim",
        extensions = { "png", "jpg", "jpeg", "webp", "gif", "bmp", "tiff", "tif", "avif" },
        priority = 100,
        needs_terminal = false,
        is_available = M.is_available,
        get_geometry = M.get_geometry,
        render = M.render,
        clear = M.clear,
        cleanup = M.cleanup,
    })
end

return M
