---@mod focal.lib.process "Process — Managed Subprocess Spawning"
---@brief [[
--- Spawns subprocesses with proper handle lifecycle.
--- All handles (process, pipes) are always closed. SIGKILL escalation on timeout.
--- Pipe EOF is tracked separately from process exit to prevent data loss.
---@brief ]]

local M = {}

-- Cache at module load time — vim.fn.has() is unsafe from libuv callbacks.
local is_windows = vim.fn.has("win32") == 1

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

    -- Guard for fd exhaustion: new_pipe() can return nil.
    if not stdout_pipe then
        if stderr_pipe then
            stderr_pipe:close()
        end
        vim.schedule(function()
            opts.on_exit(false, "", "failed to create stdout pipe")
        end)
        return nil
    end
    if not stderr_pipe then
        stdout_pipe:close()
        vim.schedule(function()
            opts.on_exit(false, "", "failed to create stderr pipe")
        end)
        return nil
    end

    local stdout_chunks = {}
    local stderr_chunks = {}
    local stdout_bytes = 0
    local stderr_bytes = 0
    local max_stderr = 65536 -- 64KB cap for stderr

    -- Track all three completion signals independently.
    local stdout_done = false
    local stderr_done = false
    local exit_code = nil
    local finished = false

    local handle -- forward declaration for use in callbacks

    --- Called when any of the three conditions completes.
    --- Only fires on_exit once all three are done.
    local function maybe_finish()
        if finished then
            return
        end
        if not stdout_done or not stderr_done or exit_code == nil then
            return
        end
        finished = true

        if handle and not handle:is_closing() then
            handle:close()
        end

        vim.schedule(function()
            opts.on_exit(exit_code == 0, table.concat(stdout_chunks), table.concat(stderr_chunks))
        end)
    end

    local err
    handle, err = vim.uv.spawn(cmd, {
        args = args,
        stdio = { nil, stdout_pipe, stderr_pipe },
    }, function(code)
        exit_code = code
        maybe_finish()
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
        if data then
            if stdout_bytes < max_bytes then
                local remaining = max_bytes - stdout_bytes
                if #data > remaining then
                    data = data:sub(1, remaining)
                end
                stdout_chunks[#stdout_chunks + 1] = data
                stdout_bytes = stdout_bytes + #data
            end

            if stdout_bytes >= max_bytes then
                if not stdout_pipe:is_closing() then
                    stdout_pipe:close()
                end
                stdout_done = true
                -- Kill the process since we're discarding its output.
                -- Include SIGKILL escalation in case SIGTERM is ignored.
                if exit_code == nil and handle and not handle:is_closing() then
                    pcall(function()
                        handle:kill("sigterm")
                    end)
                    local esc_timer = vim.uv.new_timer()
                    if esc_timer then
                        esc_timer:start(kill_timeout, 0, function()
                            esc_timer:close()
                            if exit_code == nil and handle and not handle:is_closing() then
                                pcall(function()
                                    handle:kill(is_windows and "sigterm" or "sigkill")
                                end)
                            end
                        end)
                    end
                end
                maybe_finish()
                return
            end
        else
            -- EOF: close pipe and mark done.
            if not stdout_pipe:is_closing() then
                stdout_pipe:close()
            end
            stdout_done = true
            maybe_finish()
        end
    end)

    stderr_pipe:read_start(function(_, data)
        if data then
            if stderr_bytes < max_stderr then
                local remaining = max_stderr - stderr_bytes
                if #data > remaining then
                    data = data:sub(1, remaining)
                end
                stderr_chunks[#stderr_chunks + 1] = data
                stderr_bytes = stderr_bytes + #data
            end
        else
            -- EOF: close pipe and mark done.
            if not stderr_pipe:is_closing() then
                stderr_pipe:close()
            end
            stderr_done = true
            maybe_finish()
        end
    end)

    local killed = false

    return {
        kill = function()
            if killed then
                return
            end
            killed = true
            if exit_code == nil and handle and not handle:is_closing() then
                pcall(function()
                    handle:kill("sigterm")
                end)
                local timer = vim.uv.new_timer()
                if not timer then
                    return
                end
                timer:start(kill_timeout, 0, function()
                    timer:close()
                    if exit_code == nil and handle and not handle:is_closing() then
                        if not is_windows then
                            pcall(function()
                                handle:kill("sigkill")
                            end)
                        else
                            pcall(function()
                                handle:kill("sigterm")
                            end) -- TerminateProcess again
                        end
                    end
                end)
            end
        end,
    }
end

return M
