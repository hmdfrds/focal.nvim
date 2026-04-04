# Changelog

## [1.0.0] - Unreleased

### Added
- Initial release: ground-up rewrite of focal.nvim as iris.nvim, now renamed back to focal.nvim
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
- 71 tests with mini.test
