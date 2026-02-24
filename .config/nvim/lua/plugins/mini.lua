-- lua/plugins/mini.lua

return {
    "echasnovski/mini.nvim",
    lazy = false,
    config = function()
        -- Basics
        require("mini.basics").setup({
            options = {
                extra_ui = true,
            },
            mappings = {
                windows = true,
            },
        })
        require("mini.bufremove").setup()
        -- File management
        require("mini.files").setup()

        -- Fuzzy finder
        require("mini.pick").setup()

        -- Completion
        require("mini.completion").setup()

        -- Keymap hints (replaces which-key)
        require("mini.clue").setup({
            triggers = {
                -- Leader triggers
                { mode = "n", keys = "<leader>" },
                { mode = "x", keys = "<leader>" },
                { mode = "v", keys = "<leader>" },

                -- Built-in completion
                { mode = "i", keys = "<C-x>" },

                -- `g` key
                { mode = "n", keys = "g" },
                { mode = "x", keys = "g" },

                -- Marks
                { mode = "n", keys = "'" },
                { mode = "n", keys = "`" },
                { mode = "x", keys = "'" },
                { mode = "x", keys = "`" },

                -- Registers
                { mode = "n", keys = '"' },
                { mode = "x", keys = '"' },
                { mode = "i", keys = "<C-r>" },
                { mode = "c", keys = "<C-r>" },

                -- Window commands
                { mode = "n", keys = "<C-w>" },

                -- `z` key
                { mode = "n", keys = "z" },
                { mode = "x", keys = "z" },

                -- Brackets (navigation)
                { mode = "n", keys = "[" },
                { mode = "n", keys = "]" },
            },
        })

        -- UI
        require("mini.starter").setup()
        require("mini.statusline").setup()
        require("mini.icons").setup()
        require("mini.indentscope").setup()
        require("mini.extra").setup()

        -- Sessions (auto-managed by cwd, see core/autocmds.lua)
        require("mini.sessions").setup({
            autoread = false,
            autowrite = true,
            directory = vim.fn.stdpath("data") .. "/sessions",
        })

        -- Git
        require("mini.diff").setup()
        require("mini.git").setup()

        -- Highlight patterns (TODO, FIXME, etc.)
        local hipatterns = require("mini.hipatterns")
        hipatterns.setup({
            highlighters = {
                fixme = { pattern = "%f[%w]()FIXME()%f[%W]", group = "MiniHipatternsFixme" },
                hack  = { pattern = "%f[%w]()HACK()%f[%W]",  group = "MiniHipatternsHack" },
                todo  = { pattern = "%f[%w]()TODO()%f[%W]",   group = "MiniHipatternsTodo" },
                note  = { pattern = "%f[%w]()NOTE()%f[%W]",   group = "MiniHipatternsNote" },
            },
        })

        -- Text editing
        require("mini.comment").setup()
        require("mini.pairs").setup()
    end,
}
