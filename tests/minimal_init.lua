vim.opt.rtp:prepend(".")
vim.opt.rtp:prepend("tests/deps/mini.test")
vim.o.swapfile = false
vim.o.backup = false
vim.o.undofile = false
require("mini.test").setup()
