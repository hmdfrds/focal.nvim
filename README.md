# focal.nvim 👁️

> **Fo**cused **Ca**lm **L**ook for Neovim images.

`focal.nvim` provides an image preview experience for your file explorer. It is designed to be a "set and forget" plugin that just works.

![Demo](./assets/bruh.gif)

---

## ✨ Features

-   **Zero-Friction Hover**: Automatically previews images when your cursor hovers over them.
-   **Multi-Explorer Support**: Works out of the box with:
    -   `nvim-neo-tree/neo-tree.nvim`
    -   `nvim-tree/nvim-tree.lua`
    -   `stevearc/oil.nvim`
    -   `folke/snacks.nvim` (explorer)
-   **Pixel-Perfect Scaling**: Calculates terminal cell geometry to ensure images fill the preview window 100% without distortion or wasted space.
-   **Performance Guard**: Automatically skips huge files (`>5MB` by default) to prevent your editor from freezing.
-   **Window Pooling**: Reuses preview windows to eliminate flicker and reduce overhead.

## 📦 Requirements

-   **Neovim** >= 0.9.0
-   **Image Backend**:
    -   [3rd/image.nvim](https://github.com/3rd/image.nvim) (Required)
    -   **System Deps**: `magick` (ImageMagick) is required by `image.nvim`.
        -   MacOS: `brew install imagemagick`
    -   **System Deps**: `magick` (ImageMagick) is required by `image.nvim`.
        -   MacOS: `brew install imagemagick`
        -   Linux: `sudo apt-get install imagemagick` / `sudo pacman -S imagemagick`
-   **Terminals**:
    -   Kitty, WezTerm, Ghostty, Konsole, Foot, iTerm2.
    -   Any terminal supporting **Kitty Graphics Protocol** or **Sixel**.
    -   _Note: Standard Windows Terminal or GNOME Terminal (older versions) may not work without extensive config._
-   **File Explorer**:
    -   Any supported explorer (Neo-tree, Nvim-tree, Oil, Snacks).

## 🚀 Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "hmdfrds/focal.nvim",
  dependencies = {
    "3rd/image.nvim",
  },
  -- ⚠️ IMPORTANT: You MUST set 'opts = {}' or 'config = true'
  -- because this plugin requires setup() to be called.
  opts = {
    -- See "Configuration" below for full list of options
  },
}
```

## ⚙️ Configuration

You can customize `focal.nvim` by passing a table to `setup()` or `opts`.
Here are the default values:

```lua
opts = {
  -- Enable debug notifications (useful for troubleshooting)
  debug = false,

  -- Minimum dimensions for the preview window (in terminal cells)
  min_width = 10,
  min_height = 5,

  -- Maximum dimensions relative to the editor window (percentage)
  max_width_pct = 50,
  max_height_pct = 50,

  -- Absolute maximum height limit (in cells) to prevent vertical overflow
  max_cells = 60,

  -- 🛡️ Performance Guard: Skip images larger than this size (in MB)
  -- Setting this too high (>20) WILL freeze Neovim during loading.
  max_file_size_mb = 5,

  -- Supported extensions. Files not matching these will be ignored.
  extensions = { "png", "jpg", "jpeg", "webp", "gif", "bmp" },
}
```

## 🩺 Diagnostics & Troubleshooting

`focal.nvim` comes with built-in diagnostic tools compliant with Neovim standards.

### 1. Health Check

Run the standard health check to verify your installation, dependencies, and adapter status:

```vim
:checkhealth focal
```

**Common issues checked:**

-   Is `image.nvim` installed?
-   Is the image backend (kitty/ueberzug) initialized?
-   Are any supported file explorer plugins active?

### 2. Debug Command

If you are hovering an image but nothing shows up, move your cursor over the node and run:

```vim
:FocalDebug
```

This will print the internal state, active adapter, and terminal geometry to `:messages`.

## ❓ FAQ

**Q: Why doesn't it work if I remove `opts = {}`?**  
A: `lazy.nvim` only calls `require("focal").setup()` if you provide `opts` or set `config = true`. Without it, the plugin is installed but never started.

**Q: Why do huge images freeze my editor?**  
A: Image processing (resizing/converting) is CPU/IO intensive. `image.nvim` waits for this process to finish to ensure the image is ready, which pauses the main thread. Use `max_file_size_mb` to protect yourself.

**Q: My images are small/distorted?**  
A: Ensure your terminal supports the graphics protocol you are using (Kitty/Sixel). `focal.nvim` does the math correctly, but the terminal must support the render output.
