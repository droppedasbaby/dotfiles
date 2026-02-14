-- lua/plugins/lsp.lua

return {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
        "williamboman/mason.nvim",
        "williamboman/mason-lspconfig.nvim",
    },
    config = function()
        local servers = {
            -- Essentials
            "lua_ls",
            "vimls",

            -- Programming Languages
            "clangd",
            "gopls",
            "jdtls",
            "ts_ls",
            "pyright",
            "ruff",
            "rust_analyzer",

            -- Shell
            "bashls",

            -- Data & Config
            "jsonls",
            "yamlls",
            "taplo",
            "lemminx",
            "terraformls",

            -- Docs & Web
            "marksman",
            "html",
            "cssls",

            -- DevOps
            "dockerls",
        }


        local capabilities = vim.lsp.protocol.make_client_capabilities()

        require("mason-lspconfig").setup({
            ensure_installed = servers,
            automatic_installation = true,
            handlers = {
                -- Default handler for all servers
                function(server_name)
                    require("lspconfig")[server_name].setup({
                        capabilities = capabilities,
                        flags = {
                            debounce_text_changes = 150,
                        },
                    })
                end,
                -- lua_ls: tell it about neovim's vim global
                ["lua_ls"] = function()
                    require("lspconfig").lua_ls.setup({
                        capabilities = capabilities,
                        settings = {
                            Lua = {
                                diagnostics = { globals = { "vim" } },
                            },
                        },
                    })
                end,
            },
        })
    end,
}
