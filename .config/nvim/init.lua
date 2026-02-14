-- ~/.config/nvim/init.lua

-- Load core options FIRST (including mapleader)
require("core.options")

-- THEN load lazy-config
require("lazy-config")

-- Load keymaps
require("core.keymaps")
require("core.autocmds")
