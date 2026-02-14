-- lua/core/keymaps.lua

local keymap = vim.keymap.set

-- General navigation

-- Better escape
keymap("i", "jj", "<ESC>", { desc = "Exit insert mode" })

-- Clear search highlights
keymap("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- mini.files
keymap("n", "<leader>e", require("mini.files").open, { desc = "Open file explorer" })

-- mini.pick
keymap("n", "<leader>ff", require("mini.pick").builtin.files, { desc = "Find files" })
keymap("n", "<leader>fg", require("mini.pick").builtin.grep_live, { desc = "Live grep" })
keymap("n", "<leader>fb", require("mini.pick").builtin.buffers, { desc = "Find buffers" })
keymap("n", "<leader>fr", require("mini.pick").builtin.resume, { desc = "Resume last picker" })

-- mini.extra
keymap("n", "<leader>jl", function() require("mini.extra").pickers.list({ scope = 'jump' }) end, { desc = "Jump List Picker" })

-- mini.completion
keymap("i", "<Tab>", function()
    return vim.fn.pumvisible() == 1 and "<C-n>" or "<Tab>"
end, { expr = true, desc = "Next completion item or tab" })

keymap("i", "<S-Tab>", function()
    return vim.fn.pumvisible() == 1 and "<C-p>" or "<S-Tab>"
end, { expr = true, desc = "Previous completion item" })

keymap("i", "<CR>", function()
    return vim.fn.pumvisible() == 1 and "<C-y>" or "<CR>"
end, { expr = true, desc = "Confirm completion or newline" })

-- Window Management
keymap("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
keymap("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

keymap("n", "<leader>h", "<C-w>h", { desc = "Navigate to the split on the left" })
keymap("n", "<leader>j", "<C-w>j", { desc = "Navigate to the split below" })
keymap("n", "<leader>k", "<C-w>k", { desc = "Navigate to the split above" })
keymap("n", "<leader>l", "<C-w>l", { desc = "Navigate to the split on the right" })

-- Buffer Management
keymap("n", "<leader>bd", function()
    require("mini.bufremove").delete(0, false)
end, { desc = "Close current buffer" })

-- harpoon
local harpoon = require("harpoon")

keymap("n", "<leader>a", function() harpoon:list():add() end, { desc = "Add file to harpoon" })
keymap("n", "<leader>m", function() harpoon.ui:toggle_quick_menu(harpoon:list()) end, { desc = "Toggle harpoon menu" })
keymap("n", "<leader>hc", function() harpoon:list():clear() print("Harpoon list cleared") end, { desc = "Clear harpoon list" })

-- Navigate to harpooned files
keymap("n", "<leader>1", function() harpoon:list():select(1) end, { desc = "Harpoon file 1" })
keymap("n", "<leader>2", function() harpoon:list():select(2) end, { desc = "Harpoon file 2" })
keymap("n", "<leader>3", function() harpoon:list():select(3) end, { desc = "Harpoon file 3" })
keymap("n", "<leader>4", function() harpoon:list():select(4) end, { desc = "Harpoon file 4" })
keymap("n", "<leader>5", function() harpoon:list():select(5) end, { desc = "Harpoon file 5" })

-- Navigate between harpooned files
keymap("n", "<C-S-P>", function() harpoon:list():prev() end, { desc = "Previous harpoon file" })
keymap("n", "<C-S-N>", function() harpoon:list():next() end, { desc = "Next harpoon file" })

-- Quality of Life
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selected line down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selected line up" })
keymap("n", "<leader>u", "<cmd>Lazy<cr>", { desc = "Update plugins" })
