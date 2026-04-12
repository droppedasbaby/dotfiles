-- lua/plugins/treesitter.lua

return {
    {
        "nvim-treesitter/nvim-treesitter",
        event = { "BufReadPre", "BufNewFile" },
        build = ":TSUpdate",
        config = function()
            vim.treesitter.language.register("bash", "zsh")
        end,
    },
    {
        "nvim-treesitter/nvim-treesitter-textobjects",
        event = { "BufReadPre", "BufNewFile" },
        dependencies = { "nvim-treesitter/nvim-treesitter" },
        config = function()
            require("nvim-treesitter-textobjects").setup({
                select = { lookahead = true },
                move = { set_jumps = true },
            })

            local select = require("nvim-treesitter-textobjects.select")
            local move = require("nvim-treesitter-textobjects.move")
            local swap = require("nvim-treesitter-textobjects.swap")

            -- Select
            for _, m in ipairs({
                { "af", "@function.outer" },
                { "if", "@function.inner" },
                { "ac", "@class.outer" },
                { "ic", "@class.inner" },
                { "aa", "@parameter.outer" },
                { "ia", "@parameter.inner" },
            }) do
                vim.keymap.set({ "x", "o" }, m[1], function()
                    select.select_textobject(m[2], "textobjects")
                end)
            end

            -- Move
            vim.keymap.set({ "n", "x", "o" }, "]f", function() move.goto_next_start("@function.outer", "textobjects") end)
            vim.keymap.set({ "n", "x", "o" }, "]c", function() move.goto_next_start("@class.outer", "textobjects") end)
            vim.keymap.set({ "n", "x", "o" }, "[f", function() move.goto_previous_start("@function.outer", "textobjects") end)
            vim.keymap.set({ "n", "x", "o" }, "[c", function() move.goto_previous_start("@class.outer", "textobjects") end)

            -- Swap
            vim.keymap.set("n", "<leader>ts", function() swap.swap_next("@parameter.inner") end)
            vim.keymap.set("n", "<leader>tS", function() swap.swap_previous("@parameter.inner") end)
        end,
    },
}
