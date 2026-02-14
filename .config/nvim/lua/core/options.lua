-- lua/core/options.lua

-- Set leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Display
vim.opt.relativenumber = true
vim.opt.number = true              -- Show absolute line number on cursor line
vim.opt.signcolumn = "yes"         -- Always show sign column (prevents UI jumping)
vim.opt.cursorline = true          -- Highlight current line
vim.opt.scrolloff = 8              -- Keep 8 lines visible above/below cursor
vim.opt.sidescrolloff = 8          -- Keep 8 columns visible left/right

-- System integration
vim.opt.clipboard = "unnamedplus"
vim.g.loaded_ruby_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0

-- Splits
vim.opt.splitright = true          -- New vertical splits go right
vim.opt.splitbelow = true          -- New horizontal splits go below

-- Search
vim.opt.ignorecase = true          -- Case-insensitive search...
vim.opt.smartcase = true           -- ...unless query has uppercase

-- Persistent undo
vim.opt.undofile = true            -- Save undo history across sessions
vim.opt.undodir = vim.fn.stdpath("state") .. "/undo"

-- Better completion
vim.opt.completeopt = "menu,menuone,noselect"

-- Treesitter-based folding
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldenable = false         -- Don't fold by default
vim.opt.foldlevel = 99             -- But keep high fold level

-- Show whitespace (useful for debugging)
vim.opt.list = true
vim.opt.listchars = { 
    tab = "→ ", 
    trail = "·", 
    nbsp = "␣",
    extends = "⟩",
    precedes = "⟨",
}

-- Optional: Line length guide (uncomment if you want it)
-- vim.opt.colorcolumn = "120"

-- Indentation defaults
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
