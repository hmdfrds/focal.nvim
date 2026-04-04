# Contributing to focal.nvim

Thanks for your interest in contributing! This document covers the basics.

## Development Setup

1. Clone the repo and work on a feature branch:
   ```sh
   git clone https://github.com/hmdfrds/focal.nvim.git
   cd focal.nvim
   git checkout -b my-feature
   ```

2. Install tooling:
   - [stylua](https://github.com/JohnnyMorganz/StyLua) for formatting
   - [selene](https://github.com/Kampfkarren/selene) for linting
   - Neovim >= 0.10 for running tests

## Running Tests

Tests use [mini.test](https://github.com/echasnovski/mini.test). Run the full suite with:

```sh
make test
```

## Linting and Formatting

```sh
make lint      # check formatting (stylua) and lint (selene)
make format    # auto-format with stylua
```

Both must pass before merging.

## Adding a Source Adapter

1. Create `lua/focal/sources/<name>.lua`.
2. Export `filetype` (string) and `get_path` (function returning `string|nil`).
3. Add the module path to `builtin_modules` in `lua/focal/resolver.lua`.
4. Add tests in `tests/focal/`.

## Adding a Renderer

1. Create `lua/focal/renderers/<name>.lua`.
2. Implement the `FocalRenderer` interface (see `lua/focal/types.lua`).
3. Export a `register(registry)` function.
4. Add the module path to `builtin_paths` in `lua/focal/renderer.lua`.
5. Add tests in `tests/focal/`.

## Code Style

- Format with **stylua** (config in `.stylua.toml`).
- Lint with **selene** (config in `selene.toml`).
- Use **LuaCATS** annotations (`---@param`, `---@return`, `---@class`) on all public functions.
- Keep modules small and focused. Avoid global state where possible.
