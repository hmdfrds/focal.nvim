# Changelog

## [1.0.0] - Unreleased

### Added
- Initial release: ground-up rewrite of focal.nvim as iris.nvim
- Dual registry architecture (sources + renderers)
- State machine with generation counter
- LRU render cache for instant re-hover
- Content swap for flicker-free image browsing
- image.nvim and chafa renderers
- Neo-tree, nvim-tree, oil, snacks source adapters
- Runtime toggle (:IrisEnable/:IrisDisable/:IrisToggle)
- Manual preview (:IrisShow [path])
- Configurable border, winblend, zindex, title
- :checkhealth integration
- 71 tests with mini.test
