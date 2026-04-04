.PHONY: test lint format

test:
	nvim --headless -u tests/minimal_init.lua -c "lua MiniTest.run()"

lint:
	stylua --check lua/ tests/
	selene lua/

format:
	stylua lua/ tests/
