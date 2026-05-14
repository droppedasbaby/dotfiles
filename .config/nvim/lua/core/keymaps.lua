-- lua/core/keymaps.lua

local keymap = vim.keymap.set

-- General navigation

-- Better escape
keymap("i", "jj", "<ESC>", { desc = "Exit insert mode" })

-- Clear search highlights
keymap("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- mini.files
keymap("n", "<leader>e", function()
    local mf = require("mini.files")
    if not mf.close() then
        local buf_name = vim.api.nvim_buf_get_name(0)
        local path = vim.fn.filereadable(buf_name) == 1 and buf_name or vim.fn.getcwd()
        mf.open(path, true)
    end
end, { desc = "Toggle file explorer at current file" })

-- mini.pick
keymap("n", "<leader>ff", function() require("mini.pick").builtin.files() end, { desc = "Find files" })
keymap("n", "<leader>fg", function() require("mini.pick").builtin.grep_live() end, { desc = "Live grep" })
keymap("n", "<leader>fb", function() require("mini.pick").builtin.buffers() end, { desc = "Find buffers" })
keymap("n", "<leader>fr", function() require("mini.pick").builtin.resume() end, { desc = "Resume last picker" })

-- mini.sessions
keymap("n", "<leader>fs", function() require("mini.sessions").select() end, { desc = "Select session" })
keymap("n", "<leader>sw", function()
    local name = vim.fn.input("Session name: ")
    if name ~= "" then require("mini.sessions").write(name) end
end, { desc = "Write session" })
keymap("n", "<leader>sd", function()
    local sessions = require("mini.sessions")
    local name = vim.fn.getcwd():gsub("[/\\]", " | "):gsub("^ | ", "")
    if sessions.detected[name] then
        sessions.delete(name, { force = true })
    end
    vim.cmd("%bdelete!")
    require("mini.starter").open()
    print("Session wiped - fresh start")
end, { desc = "Wipe session and start fresh" })

-- mini.extra
keymap("n", "<leader>jl", function() require("mini.extra").pickers.list({ scope = 'jump' }) end, { desc = "Jump List Picker" })

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

keymap("n", "qq", "<cmd>bprevious<CR>", { desc = "Previous buffer" })
keymap("n", "rr", "<cmd>bnext<CR>", { desc = "Next buffer" })

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

-- Git
keymap("n", "<leader>ggb", function() require("mini.git").show_at_cursor() end, { desc = "Git: Show commit at cursor" })
keymap("n", "<leader>ggd", "<cmd>DiffviewOpen HEAD<cr>",     { desc = "Git: Diff uncommitted changes" })
keymap("n", "<leader>ggq", "<cmd>DiffviewClose<cr>",         { desc = "Git: Close diffview" })
keymap("n", "<leader>ggf", "<cmd>DiffviewFileHistory %<cr>", { desc = "Git: File history (current)" })
keymap("n", "<leader>ggl", "<cmd>DiffviewFileHistory<cr>",   { desc = "Git: Log (all files)" })

-- Quality of Life
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selected line down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selected line up" })
keymap("n", "<leader>u", "<cmd>Lazy<cr>", { desc = "Update plugins" })
