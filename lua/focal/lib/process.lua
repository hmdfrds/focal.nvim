---@mod focal.lib.process "Process — Managed Subprocess Spawning"
---@brief [[
--- Spawns subprocesses with proper handle lifecycle.
--- All handles (process, pipes) are always closed. SIGKILL escalation on timeout.
---@brief ]]

local M = {}

---Spawn a subprocess with managed lifecycle.
---@param cmd string
---@param args string[]
---@param opts { on_exit: fun(ok: boolean, stdout: string, stderr: string), max_output_bytes?: integer, kill_timeout_ms?: integer }
---@return { kill: fun() }|nil handle
function M.spawn(cmd, args, opts)
    local max_bytes = opts.max_output_bytes or (1024 * 1024)
    local kill_timeout = opts.kill_timeout_ms or 2000

    local stdout_pipe = vim.uv.new_pipe(false)
    local stderr_pipe = vim.uv.new_pipe(false)
    local stdout_chunks = {}
    local stderr_chunks = {}
    local stdout_bytes = 0
    local stderr_bytes = 0
    local max_stderr = 65536 -- 64KB cap for stderr
    local exited = false

    local handle, err = vim.uv.spawn(cmd, {
        args = args,
        stdio = { nil, stdout_pipe, stderr_pipe },
    }, function(code)
        exited = true
        stdout_pipe:read_stop()
        stdout_pipe:close()
        stderr_pipe:read_stop()
        stderr_pipe:close()
        if not handle:is_closing() then
            handle:close()
        end
        vim.schedule(function()
            opts.on_exit(code == 0, table.concat(stdout_chunks), table.concat(stderr_chunks))
        end)
    end)

    if not handle then
        stdout_pipe:close()
        stderr_pipe:close()
        vim.schedule(function()
            opts.on_exit(false, "", tostring(err))
        end)
        return nil
    end

    stdout_pipe:read_start(function(_, data)
        if data and stdout_bytes < max_bytes then
            local remaining = max_bytes - stdout_bytes
            if #data > remaining then
                data = data:sub(1, remaining)
            end
            stdout_chunks[#stdout_chunks + 1] = data
            stdout_bytes = stdout_bytes + #data
        end
    end)

    stderr_pipe:read_start(function(_, data)
        if data and stderr_bytes < max_stderr then
            local remaining = max_stderr - stderr_bytes
            if #data > remaining then
                data = data:sub(1, remaining)
            end
            stderr_chunks[#stderr_chunks + 1] = data
            stderr_bytes = stderr_bytes + #data
        end
    end)

    local killed = false

    return {
        kill = function()
            if killed then return end
            killed = true
            if not exited and handle and not handle:is_closing() then
                handle:kill("sigterm")
                local timer = vim.uv.new_timer()
                timer:start(kill_timeout, 0, function()
                    timer:close()
                    if not exited and handle and not handle:is_closing() then
                        if vim.fn.has("win32") == 0 then
                            pcall(function() handle:kill("sigkill") end)
                        else
                            pcall(function() handle:kill("sigterm") end) -- TerminateProcess again
                        end
                    end
                end)
            end
        end,
    }
end

return M
