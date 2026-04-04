---@mod iris.renderers.chafa "Chafa Renderer"
---@brief [[
--- Unicode/ANSI image renderer via the chafa CLI tool.
--- Works in any terminal that supports Unicode and colors.
---@brief ]]

local Process = require("iris.lib.process")

local M = {}

---@type boolean|nil  cached availability result
local _available = nil

---@type { kill: fun() }|nil  in-flight process handle
local _proc = nil

---Check whether chafa is installed.
---@return boolean
function M.is_available()
    if _available ~= nil then
        return _available
    end
    _available = vim.fn.executable("chafa") == 1
    return _available
end

---Compute geometry for chafa output.
---Chafa renders to the full available area; actual fit is determined after render.
---@param _path string
---@param _stat table
---@param env IrisRenderEnv
---@return IrisGeometry
function M.get_geometry(_path, _stat, env)
    return { width = env.max_width, height = env.max_height }
end

---Build the chafa CLI argument list.
---@param path string
---@param width integer
---@param height integer
---@param config IrisConfig
---@return string[]
local function build_args(path, width, height, config)
    local args = {
        "--size=" .. width .. "x" .. height,
        "--format=" .. config.chafa.format,
    }

    if not config.chafa.animate then
        args[#args + 1] = "--animate=off"
    end

    if config.chafa.color_space then
        args[#args + 1] = "--color-space=" .. config.chafa.color_space
    end

    args[#args + 1] = path
    return args
end

---Render the image via chafa into the preview window's terminal buffer.
---@param ctx IrisRenderContext
---@param done fun(ok: boolean, result?: IrisRenderResult)
function M.render(ctx, done)
    -- Kill any in-flight render.
    if _proc then
        _proc.kill()
        _proc = nil
    end

    local args = build_args(ctx.path, ctx.geometry.width, ctx.geometry.height, ctx.config)

    local this_proc
    this_proc = Process.spawn("chafa", args, {
        max_output_bytes = ctx.config.chafa.max_output_bytes,
        on_exit = function(ok, stdout, stderr)
            -- Only clear _proc if it's still OUR process
            if _proc == this_proc then
                _proc = nil
            end

            if not ok then
                if stderr ~= "" then
                    vim.notify("[iris] chafa failed: " .. stderr, vim.log.levels.DEBUG)
                end
                done(false)
                return
            end

            if not vim.api.nvim_buf_is_valid(ctx.buf) then
                done(false)
                return
            end

            -- Send chafa output to the terminal channel provided by the preview manager.
            if not ctx.chan then
                done(false)
                return
            end
            pcall(vim.api.nvim_chan_send, ctx.chan, stdout)

            -- Count actual output lines for tight-fit height.
            local line_count = 1
            for _ in stdout:gmatch("\n") do
                line_count = line_count + 1
            end
            local fit_height = math.min(line_count, ctx.geometry.height)

            done(true, {
                fit = { width = ctx.geometry.width, height = fit_height },
                output = stdout,
            })
        end,
    })
    _proc = this_proc
end

---Clear any in-flight render process.
function M.clear()
    if _proc then
        _proc.kill()
        _proc = nil
    end
end

---Full cleanup: clear process and reset cached availability.
function M.cleanup()
    M.clear()
    _available = nil
end

---Register this renderer with the renderer registry.
---@param registry table
function M.register(registry)
    registry.register_renderer({
        name = "chafa",
        extensions = { "png", "jpg", "jpeg", "webp", "gif", "bmp", "tiff", "avif", "svg" },
        priority = 50,
        needs_terminal = true,
        is_available = M.is_available,
        get_geometry = M.get_geometry,
        render = M.render,
        clear = M.clear,
        cleanup = M.cleanup,
    })
end

return M
