local T = MiniTest.new_set()
local Process = require("focal.lib.process")

T["spawn() runs command and collects stdout"] = function()
    local done = false
    local result_ok, result_stdout
    Process.spawn("echo", { "hello" }, {
        on_exit = function(ok, stdout, stderr)
            result_ok = ok
            result_stdout = stdout
            done = true
        end,
    })
    vim.wait(2000, function()
        return done
    end)
    MiniTest.expect.equality(result_ok, true)
    MiniTest.expect.equality(vim.trim(result_stdout), "hello")
end

T["spawn() collects stderr"] = function()
    local done = false
    local result_stderr
    Process.spawn("sh", { "-c", "echo err >&2" }, {
        on_exit = function(ok, stdout, stderr)
            result_stderr = stderr
            done = true
        end,
    })
    vim.wait(2000, function()
        return done
    end)
    MiniTest.expect.equality(vim.trim(result_stderr), "err")
end

T["spawn() reports failure on non-zero exit"] = function()
    local done = false
    local result_ok
    Process.spawn("sh", { "-c", "exit 1" }, {
        on_exit = function(ok, stdout, stderr)
            result_ok = ok
            done = true
        end,
    })
    vim.wait(2000, function()
        return done
    end)
    MiniTest.expect.equality(result_ok, false)
end

T["spawn() returns nil and calls back on spawn failure"] = function()
    local done = false
    local result_ok
    local handle = Process.spawn("nonexistent_binary_xyz_123", {}, {
        on_exit = function(ok, stdout, stderr)
            result_ok = ok
            done = true
        end,
    })
    vim.wait(2000, function()
        return done
    end)
    MiniTest.expect.equality(handle, nil)
    MiniTest.expect.equality(result_ok, false)
end

T["kill() is idempotent"] = function()
    local done = false
    local handle = Process.spawn("sleep", { "10" }, {
        on_exit = function()
            done = true
        end,
        kill_timeout_ms = 100,
    })
    MiniTest.expect.no_equality(handle, nil)
    handle.kill()
    handle.kill()
    vim.wait(3000, function()
        return done
    end)
    MiniTest.expect.equality(done, true)
end

return T
