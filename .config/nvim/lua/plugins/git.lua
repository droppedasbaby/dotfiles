-- lua/plugins/git.lua

return {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    -- use_icons = true (default): mini.icons provides the nvim-web-devicons compat shim
    opts = {},
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
}
