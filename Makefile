.PHONY: test test-file lint format deps

deps:
	@mkdir -p tests/deps
	@test -d tests/deps/mini.test || git clone --depth=1 https://github.com/echasnovski/mini.test tests/deps/mini.test

test: deps
	nvim --headless -u tests/minimal_init.lua -c "lua MiniTest.run({ collect = { find_files = function() return vim.fn.globpath('tests/focal', '*_spec.lua', false, true) end } })"

# Run a single test file: make test-file FILE=tests/focal/cache_spec.lua
test-file: deps
	nvim --headless -u tests/minimal_init.lua -c "lua MiniTest.run({ collect = { find_files = function() return { '$(FILE)' } end } })"

lint:
	stylua --check lua/ tests/
	selene lua/

format:
	stylua lua/ tests/
