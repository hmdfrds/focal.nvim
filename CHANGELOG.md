# Changelog

## [1.0.0] - Unreleased

### Added
- Initial release: ground-up rewrite (developed as iris.nvim, released as focal.nvim)
- Dual registry architecture (sources + renderers)
- State machine with generation counter
- LRU render cache for instant re-hover
- Content swap for flicker-free image browsing
- image.nvim and chafa renderers
- Neo-tree, nvim-tree, oil, snacks source adapters
- Runtime toggle (:FocalEnable/:FocalDisable/:FocalToggle)
- Manual preview (:FocalShow [path])
- Configurable border, winblend, zindex, title
- :checkhealth integration
- 82 tests with mini.test

### Fixed
- 50-agent review fixes:
  - pcall safety around all renderer and callback invocations
  - Generation-counter guard on every async callback
  - Process lifecycle hardening (pipe EOF, kill on overflow)
  - Window manager defensive guards and nil checks
  - Config validation with typo suggestions and range clamping
  - Health check validates live config instead of defaults
  - Terminal detection improvements for graphics capability
