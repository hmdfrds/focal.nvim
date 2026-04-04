.PHONY: test lint format

test:
	nvim --headless -u tests/minimal_init.lua -c "lua MiniTest.run({ collect = { find_files = function() return vim.fn.globpath('tests/iris', '*_spec.lua', false, true) end } })" -c "qa!"

lint:
	stylua --check lua/ tests/
	selene lua/

format:
	stylua lua/ tests/
