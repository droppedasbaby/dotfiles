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
            "lua_ls",

            "gopls",
            "ts_ls",
            "pyright",
            "ruff",

            "bashls",

            "jsonls",
            "yamlls",
            "taplo",
            "terraformls",

            "marksman",
            "html",
            "cssls",

            "dockerls",
        }

        local capabilities = vim.lsp.protocol.make_client_capabilities()

        require("mason-lspconfig").setup({
            ensure_installed = servers,
            automatic_enable = {
                exclude = { "lua_ls" },
            },
        })

        local lspconfig = require("lspconfig")

        lspconfig.lua_ls.setup({
            capabilities = capabilities,
            settings = {
                Lua = {
                    diagnostics = { globals = { "vim" } },
                },
            },
        })
    end,
}
