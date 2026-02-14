-- lua/plugins/treesitter.lua

return {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPre", "BufNewFile" },
    build = ":TSUpdate",
    dependencies = {
        "nvim-treesitter/nvim-treesitter-textobjects",
    },
    config = function()
        require("nvim-treesitter.configs").setup({
            ensure_installed = {
                -- Essential for Neovim
                "lua", "vim", "vimdoc", "query",

                -- Programming Languages
                "c",          -- .c, .h
                "cpp",        -- .cc, .h
                "go",         -- .go
                "gomod",      -- go.mod
                "gosum",      -- go.sum
                "java",       -- .java
                "javascript", -- .js
                "typescript", -- .ts
                "python",     -- .py, .pyi
                "rust",       -- .rs
                -- Shell/Scripting
                "bash",   -- .sh, .bash, .zsh (zsh uses bash parser)

                -- Config/Data Formats
                "json", -- .json
                "yaml", -- .yaml, .yml
                "toml", -- .toml
                "xml",  -- .xml
                "csv",  -- .csv
                "ini",  -- .ini, .cfg, .conf
                "hcl",  -- .hcl, .tf, .tfvars (Terraform)
                -- Documentation
                "markdown",        -- .md
                "markdown_inline", -- for markdown code blocks

                -- Web
                "html", -- .html
                "css",  -- .css

                -- Infrastructure/DevOps
                "dockerfile", -- .dockerfile, Dockerfile
                "terraform",  -- .tf (alias for hcl)
                "proto",      -- .proto

            },
            auto_install = true,
            highlight = { enable = true },
            indent = { enable = true },
            -- Incremental selection (built into treesitter core)
            incremental_selection = {
                enable = true,
                keymaps = {
                    init_selection = "<C-space>",
                    node_incremental = "<C-space>",
                    node_decremental = "<bs>",
                },
            },
            textobjects = {
                select = {
                    enable = true,
                    lookahead = true,
                    keymaps = {
                        ["af"] = "@function.outer",
                        ["if"] = "@function.inner",
                        ["ac"] = "@class.outer",
                        ["ic"] = "@class.inner",
                        ["aa"] = "@parameter.outer",
                        ["ia"] = "@parameter.inner",
                    },
                },
                move = {
                    enable = true,
                    set_jumps = true,
                    goto_next_start = {
                        ["]f"] = "@function.outer",
                        ["]c"] = "@class.outer",
                    },
                    goto_previous_start = {
                        ["[f"] = "@function.outer",
                        ["[c"] = "@class.outer",
                    },
                },
                swap = {
                    enable = true,
                    swap_next = {
                        ["<leader>sa"] = "@parameter.inner",
                    },
                    swap_previous = {
                        ["<leader>sA"] = "@parameter.inner",
                    },
                },
            },
        })
    end,
}
