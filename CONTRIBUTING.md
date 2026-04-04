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
   ```sh
   # Via Cargo (Rust toolchain required)
   cargo install stylua selene

   # Or download binaries from:
   # stylua: https://github.com/JohnnyMorganz/StyLua/releases
   # selene: https://github.com/Kampfkarren/selene/releases
   ```
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

## Architecture

focal.nvim follows a four-stage pipeline:

1. **Source** — detects the file path under the cursor for a given filetype
   (e.g. neo-tree, nvim-tree, oil, snacks). Sources export a flat
   `{ filetype, get_path }` table and are registered via
   `register_source()`.

2. **Resolver** — maps filetypes to their source adapter. When `CursorHold`
   fires, the resolver finds the matching source and calls `get_path()`.

3. **Renderer** — displays the file in the preview window. Renderers are
   registered via a `register(registry)` callback and implement the
   `FocalRenderer` interface (see `lua/focal/types.lua`). The registry
   picks the highest-priority available renderer for each extension.

4. **Window** — manages the floating window lifecycle (open, resize,
   reposition, content swap, close).

### Key patterns

- **Generation counter** — every `show()` / `hide()` / `content_swap()`
  bumps a monotonic counter. Async callbacks compare their captured
  generation to the current one; stale callbacks are discarded.

- **clear vs cleanup** — `clear()` removes the current render output and
  is called on hide, content swap, and before every new render. It must be
  safe to call even when nothing is rendered. `cleanup()` is the full
  teardown path called once on `VimLeavePre`.

- **needs_terminal** — when `true`, the preview manager opens a terminal
  channel (`nvim_open_term`) and passes `ctx.chan` to the renderer.
  The renderer writes ANSI output via `nvim_chan_send`. When `false`, the
  renderer uses a pixel protocol (image.nvim) or writes to the buffer
  directly.

- **Source flat export vs renderer register callback** — sources are simple
  `{ filetype, get_path }` tables registered directly. Renderers use a
  `register(registry)` callback so they can self-check availability before
  registering.

## Code Style

- Format with **stylua** (config in `.stylua.toml`).
- Lint with **selene** (config in `selene.toml`).
- Use **LuaCATS** annotations (`---@param`, `---@return`, `---@class`) on all public functions.
- Keep modules small and focused. Avoid global state where possible.
