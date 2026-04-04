# Changelog

## [1.0.0] - Unreleased

### Added
- Initial release: ground-up rewrite (developed as iris.nvim, released as focal.nvim)
- Dual registry architecture (sources + renderers)
- State machine with generation counter for async safety
- LRU render cache for instant re-hover
- Content swap for flicker-free image browsing
- image.nvim (pixel-perfect) and chafa (universal fallback) renderers
- Neo-tree, nvim-tree, oil, snacks source adapters
- Runtime toggle (:FocalEnable/:FocalDisable/:FocalToggle)
- Manual preview (:FocalShow [path])
- Configurable border, winblend, zindex, title
- :checkhealth integration with diagnostics
- 102 tests with mini.test

### Fixed
- ~48 bugs found and fixed across 175 automated review passes:
  - pcall safety around all renderer, callback, and Neovim API invocations
  - Generation-counter guard on every async callback (stale callbacks silently discarded)
  - Process lifecycle hardening (pipe EOF tracking, SIGKILL escalation, kill on overflow)
  - Window manager defensive guards (pcall nvim_open_win/create_buf/set_buf, nil checks)
  - Config validation (NaN/infinity rejection, typo suggestions, range clamping)
  - Health check validates live config instead of defaults
  - Terminal detection (Konsole kitty protocol, Alacritty socket, tmux prefix, mosh)
  - Content swap race condition prevention (generation-first ordering, _pending_path)
  - Source adapter symlink filtering (directory symlinks excluded)
  - Cache double-byte-subtraction fix on entry update
  - Re-entry guard on hide() preventing stack overflow from callbacks
  - Geometry type validation (reject non-numeric width/height from third-party renderers)
