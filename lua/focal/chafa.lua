---@mod focal.chafa "Chafa Renderer"
---@brief [[
--- Renders images as colored Unicode text via the chafa CLI.
--- Works in any terminal that supports 256-color or truecolor.
--- Uses nvim_open_term() + nvim_chan_send() for native ANSI rendering.
---@brief ]]

local Utils = require("focal.utils")

local M = {}

---@type boolean|nil tri-state: nil=unchecked, true=available, false=not available
M._available = nil

---@type userdata|nil in-flight uv.spawn handle
M._handle = nil

---Check if chafa is installed. Caches result after first call.
---@return boolean
function M.is_available()
    if M._available == nil then
        M._available = vim.fn.executable("chafa") == 1
    end
    return M._available
end

---Kill any in-flight chafa process.
function M.kill_process()
    if M._handle and not M._handle:is_closing() then
        M._handle:kill("sigterm")
    end
    M._handle = nil
end

---Render an image into a buffer using chafa.
---Creates a terminal channel in the buffer and sends chafa's ANSI output to it.
---@param path string Absolute path to the image file
---@param buf integer Buffer ID to render into (must be a valid, empty scratch buffer)
---@param width integer Target width in character cells
---@param height integer Target height in character cells
---@param opts? table { format?: string, color_space?: string }
---@param callback? fun(ok: boolean) Called when rendering completes
function M.render(path, buf, width, height, opts, callback)
    opts = opts or {}
    callback = callback or function() end

    -- Kill any previous in-flight render
    M.kill_process()

    local format = opts.format or "symbols"
    local args = {
        "--size=" .. width .. "x" .. height,
        "--animate=off",
        "--format=" .. format,
    }

    if opts.color_space then
        args[#args + 1] = "--color-space=" .. opts.color_space
    end

    args[#args + 1] = path

    local stdout = vim.uv.new_pipe(false)
    local stderr = vim.uv.new_pipe(false)
    local chunks = {}

    local handle, err = vim.uv.spawn("chafa", {
        args = args,
        stdio = { nil, stdout, stderr },
    }, function(code, _signal)
        -- Close pipes
        if stdout then
            stdout:read_stop()
            stdout:close()
        end
        if stderr then
            stderr:read_stop()
            stderr:close()
        end

        M._handle = nil

        vim.schedule(function()
            if code ~= 0 then
                if Utils._debug then
                    Utils.notify("chafa exited with code " .. code, vim.log.levels.DEBUG)
                end
                callback(false)
                return
            end

            -- Guard: buffer may have been deleted during async execution
            if not vim.api.nvim_buf_is_valid(buf) then
                callback(false)
                return
            end

            local output = table.concat(chunks)
            if output == "" then
                callback(false)
                return
            end

            -- Create terminal channel and send ANSI output
            local chan = vim.api.nvim_open_term(buf, {})
            vim.api.nvim_chan_send(chan, output)

            callback(true)
        end)
    end)

    if not handle then
        if Utils._debug then
            Utils.notify("Failed to spawn chafa: " .. tostring(err), vim.log.levels.DEBUG)
        end
        callback(false)
        return
    end

    M._handle = handle

    -- Collect stdout
    stdout:read_start(function(_read_err, data)
        if data then
            chunks[#chunks + 1] = data
        end
    end)

    -- Discard stderr (but stop reading on close)
    stderr:read_start(function() end)
end

---Clean up all chafa state.
function M.cleanup()
    M.kill_process()
    M._available = nil
end

return M
