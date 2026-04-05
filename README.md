# focal.nvim

[![CI](https://github.com/hmdfrds/focal.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/hmdfrds/focal.nvim/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-green.svg)](https://neovim.io)

> Universal file preview for Neovim. Hover over a file in any explorer, see a preview.

![focal.nvim demo](assets/demo.gif)

focal.nvim is an extensible preview framework with dual backends (pixel-perfect via image.nvim, Unicode fallback via chafa) and a plugin adapter system that works with any file explorer.

---

## Features

- **Zero-Friction Hover** — automatically previews images when your cursor rests on them
- **Multi-Explorer Support** — works out of the box with neo-tree, nvim-tree, oil.nvim, snacks.nvim, mini.files
- **Dual Backend** — pixel-perfect rendering via image.nvim on supported terminals, with automatic chafa fallback for universal Unicode/ANSI preview on any terminal
- **Extensible Sources** — register your own adapters for unsupported file explorers
- **Extensible Renderers** — register custom renderers for new file types (PDF, video thumbnails, etc.)
- **Content Swap** — moving between images keeps the window open and swaps content in-place (no flicker)
- **Render Cache** — LRU cache makes re-hovering the same image instant
- **Runtime Control** — enable, disable, toggle previews without restarting
- **Manual Trigger** — `:FocalShow [path]` previews any file on demand
- **Configurable** — border, transparency, position, size constraints, file size limits
- **Performance Guard** — automatically skips large files to prevent editor freezes
- **Diagnostics** — `:checkhealth focal` and `:FocalStatus` for troubleshooting

## Requirements

- **Neovim** >= 0.10
- **At least one rendering backend:**
  - [image.nvim](https://github.com/3rd/image.nvim) — pixel-perfect graphics (Kitty, WezTerm, Ghostty, iTerm2, foot, Konsole)
  - [chafa](https://hpjansson.org/chafa/) — universal Unicode/ANSI fallback (any terminal with 256-color or truecolor)
- **A file explorer:** neo-tree, nvim-tree, oil.nvim, snacks.nvim, or mini.files

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hmdfrds/focal.nvim",
  event = "VeryLazy",
  dependencies = {
    "3rd/image.nvim", -- optional if using chafa backend
  },
  opts = {
    -- See Configuration below
  },
}
```

Generic:

```lua
require("focal").setup({})
```

> **Tip:** Neovim's default `updatetime` is 4000ms, which means previews take 4 seconds to appear. Most users set it lower for responsive LSP diagnostics, which also makes focal snappier:
> ```lua
> vim.o.updatetime = 300
> ```

## Configuration

All options with their defaults:

```lua
require("focal").setup({
  -- Runtime toggle
  enabled = true,

  -- Window appearance
  border = "rounded",       -- border style (any valid nvim_open_win border)
  winblend = 0,             -- transparency (0-100)
  zindex = 100,             -- float stacking order
  title = true,             -- show filename in border

  -- Size constraints (in terminal cells)
  min_width = 10,
  min_height = 5,
  max_width = 80,
  max_height = 40,
  max_width_percent = 50,   -- max width as % of editor
  max_height_percent = 50,  -- max height as % of editor

  -- Performance
  max_file_size_mb = 5,     -- skip files larger than this
  debounce_ms = 0,          -- additional delay after CursorHold (0 = use updatetime)

  -- Position
  col_offset = 4,           -- horizontal gap from cursor
  row_offset = 1,           -- vertical gap from cursor

  -- Renderer override
  backend = nil,            -- nil/"auto" = auto, "image.nvim", or "chafa"

  -- Extension whitelist (nil = all renderer-declared extensions)
  extensions = nil,         -- e.g., { "png", "jpg" } to restrict

  -- Chafa-specific options
  chafa = {
    format = "symbols",     -- chafa --format flag
    color_space = nil,      -- nil = auto, "rgb", "din99d"
    animate = false,        -- allow GIF animation
    max_output_bytes = 1048576, -- stdout cap (1MB)
  },

  -- Render timeout (ms). Auto-hides if render takes too long.
  render_timeout_ms = 10000,

  -- Lifecycle hooks
  on_show = nil,  -- fun(path: string, renderer: string)
  on_hide = nil,  -- fun()
})
```

> **Note:** `updatetime` controls how quickly previews appear (it's Neovim's CursorHold delay). Many users set it to 300-500ms for responsive LSP diagnostics, which also makes focal more responsive. The default (4000ms) will feel slow.

## Custom Sources

Register adapters for unsupported file explorers:

```lua
require("focal").register_source({
  filetype = "my_explorer",
  get_path = function()
    -- return the absolute path of the file under cursor, or nil
    return "/path/to/image.png"
  end,
})
```

## Custom Renderers

Register renderers for new file types:

```lua
require("focal").register_renderer({
  name = "my-pdf-renderer",
  extensions = { "pdf" },
  priority = 80,
  needs_terminal = true,
  is_available = function()
    return vim.fn.executable("pdftoppm") == 1
  end,
  get_geometry = function(path, stat, env)
    return { width = env.max_width, height = env.max_height }
  end,
  render = function(ctx, done)
    -- render PDF page 1 as image, display in ctx.buf
    done(true, { output = "...", fit = { width = 40, height = 30 } })
  end,
  clear = function() end,
  cleanup = function() end,
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:FocalToggle` | Toggle previews on/off |
| `:FocalEnable` | Enable previews |
| `:FocalDisable` | Disable previews |
| `:FocalShow [path]` | Preview file under cursor, or a specific file |
| `:FocalHide` | Dismiss current preview |
| `:FocalStatus` | Print diagnostic info |
| `:checkhealth focal` | Full health check |

## Troubleshooting

1. **Previews not showing?** Run `:checkhealth focal` to verify backends and terminal support.
2. **Previews feel slow?** Lower your `updatetime` (e.g., `vim.o.updatetime = 300`).
3. **Wrong backend?** Set `backend = "chafa"` or `backend = "image.nvim"` explicitly.
4. **Inside tmux?** Add `set -g allow-passthrough on` to your `tmux.conf`.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, testing, and how to add sources/renderers.

## License

MIT
