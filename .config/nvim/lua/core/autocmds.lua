-- lua/core/autocmds.lua

local lsp_augroup = vim.api.nvim_create_augroup("LspConfig", { clear = true })

vim.api.nvim_create_autocmd("LspAttach", {
    group = lsp_augroup,
    callback = function(args)
        local bufnr = args.buf
        local client = vim.lsp.get_client_by_id(args.data.client_id)

        -- Enable completion triggered by <c-x><c-o>
        vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

        local keymap = vim.keymap.set
        local opts = function(desc)
            return { noremap = true, silent = true, buffer = bufnr, desc = desc }
        end

        -- ===================================================================
        -- LSP: Navigation & Information
        -- ===================================================================
        keymap('n', 'gD', vim.lsp.buf.declaration, opts('LSP: Go to declaration'))
        keymap('n', 'gd', vim.lsp.buf.definition, opts('LSP: Go to definition'))
        keymap('n', 'gI', vim.lsp.buf.implementation, opts('LSP: Go to implementation'))
        keymap('n', 'gy', vim.lsp.buf.type_definition, opts('LSP: Go to type definition'))
        keymap('n', 'gr', vim.lsp.buf.references, opts('LSP: Show references'))

        keymap('n', 'K', function() vim.lsp.buf.hover({ border = 'rounded' }) end, opts('LSP: Hover documentation'))
        keymap('n', '<C-k>', function() vim.lsp.buf.signature_help({ border = 'rounded' }) end, opts('LSP: Signature help'))
        keymap('i', '<C-k>', function() vim.lsp.buf.signature_help({ border = 'rounded' }) end, opts('LSP: Signature help'))

        -- ===================================================================
        -- LSP: Code Actions & Refactoring
        -- ===================================================================
        keymap('n', '<leader>rn', vim.lsp.buf.rename, opts('LSP: Rename symbol'))
        keymap('n', '<leader>ca', vim.lsp.buf.code_action, opts('LSP: Code action'))
        keymap('v', '<leader>ca', vim.lsp.buf.code_action, opts('LSP: Code action (visual)'))

        -- ===================================================================
        -- LSP: Workspace Management
        -- ===================================================================
        keymap('n', '<leader>wa', vim.lsp.buf.add_workspace_folder, opts('LSP: Add workspace folder'))
        keymap('n', '<leader>wr', vim.lsp.buf.remove_workspace_folder, opts('LSP: Remove workspace folder'))
        keymap('n', '<leader>wl', function()
            print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
        end, opts('LSP: List workspace folders'))
        keymap('n', '<leader>ws', vim.lsp.buf.workspace_symbol, opts('LSP: Workspace symbols'))

        if vim.lsp.buf.document_symbol then
            keymap('n', '<leader>ds', vim.lsp.buf.document_symbol, opts('LSP: Document symbols'))
        end

        -- ===================================================================
        -- LSP: Code Lens
        -- ===================================================================
        if client and client.supports_method('textDocument/codeLens') then
            if vim.lsp.codelens then
                keymap('n', '<leader>cl', vim.lsp.codelens.run, opts('LSP: Run code lens'))
                keymap('n', '<leader>cL', vim.lsp.codelens.refresh, opts('LSP: Refresh code lens'))

                -- Auto-refresh code lens on buffer changes
                vim.api.nvim_create_autocmd({ 'BufEnter', 'CursorHold', 'InsertLeave' }, {
                    buffer = bufnr,
                    callback = vim.lsp.codelens.refresh,
                    group = lsp_augroup,
                    desc = 'LSP: Auto-refresh code lens',
                })
            end
        end

        -- ===================================================================
        -- LSP: Inlay Hints (Neovim 0.10+)
        -- ===================================================================
        if vim.lsp.inlay_hint and client and client.supports_method('textDocument/inlayHint') then
            keymap('n', '<leader>ih', function()
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = bufnr }), { bufnr = bufnr })
            end, opts('LSP: Toggle inlay hints'))

            -- Enable inlay hints by default
            vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
        end

        -- ===================================================================
        -- LSP: Document Highlighting
        -- ===================================================================
        if client and client.supports_method('textDocument/documentHighlight') then
            local highlight_augroup = vim.api.nvim_create_augroup('LspDocumentHighlight', { clear = false })

            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                buffer = bufnr,
                group = highlight_augroup,
                callback = vim.lsp.buf.document_highlight,
                desc = 'LSP: Highlight references under cursor',
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                buffer = bufnr,
                group = highlight_augroup,
                callback = vim.lsp.buf.clear_references,
                desc = 'LSP: Clear reference highlights',
            })

            vim.api.nvim_create_autocmd('LspDetach', {
                group = highlight_augroup,
                callback = function(event)
                    vim.lsp.buf.clear_references()
                    vim.api.nvim_clear_autocmds({ group = highlight_augroup, buffer = event.buf })
                end,
                desc = 'LSP: Cleanup highlights on detach',
            })
        end

        -- ===================================================================
        -- LSP: Type Hierarchy (Neovim 0.11+)
        -- ===================================================================
        if vim.lsp.buf.typehierarchy and client and client.supports_method('textDocument/prepareTypeHierarchy') then
            keymap('n', '<leader>th', vim.lsp.buf.typehierarchy, opts('LSP: Type hierarchy'))
        end

        -- ===================================================================
        -- LSP: Call Hierarchy
        -- ===================================================================
        if client and client.supports_method('textDocument/prepareCallHierarchy') then
            if vim.lsp.buf.incoming_calls then
                keymap('n', '<leader>ci', vim.lsp.buf.incoming_calls, opts('LSP: Incoming calls'))
            end
            if vim.lsp.buf.outgoing_calls then
                keymap('n', '<leader>co', vim.lsp.buf.outgoing_calls, opts('LSP: Outgoing calls'))
            end
        end
    end,
})

-- =======================================================================
-- DIAGNOSTICS
-- =======================================================================

-- Diagnostic configuration
vim.diagnostic.config({
    virtual_text = {
        prefix = '●',
        source = 'if_many',
    },
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = '󰅚 ',
            [vim.diagnostic.severity.WARN] = '󰀪 ',
            [vim.diagnostic.severity.HINT] = '󰌶 ',
            [vim.diagnostic.severity.INFO] = ' ',
        },
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
    float = {
        border = 'rounded',
        source = 'always',
        header = '',
        prefix = '',
        focusable = false,
    },
})

-- Diagnostic keymaps (global, not buffer-local)
local keymap = vim.keymap.set
local opts = function(desc)
    return { noremap = true, silent = true, desc = desc }
end

-- Navigate diagnostics
local function diag_jump(jump_opts)
    vim.diagnostic.jump(jump_opts)
    vim.diagnostic.open_float()
end

keymap('n', '[d', function() diag_jump({ count = -1 }) end, opts('Diagnostic: Go to previous'))
keymap('n', ']d', function() diag_jump({ count = 1 }) end, opts('Diagnostic: Go to next'))
keymap('n', '[e', function()
    diag_jump({ count = -1, severity = vim.diagnostic.severity.ERROR })
end, opts('Diagnostic: Go to previous error'))
keymap('n', ']e', function()
    diag_jump({ count = 1, severity = vim.diagnostic.severity.ERROR })
end, opts('Diagnostic: Go to next error'))
keymap('n', '[w', function()
    diag_jump({ count = -1, severity = vim.diagnostic.severity.WARN })
end, opts('Diagnostic: Go to previous warning'))
keymap('n', ']w', function()
    diag_jump({ count = 1, severity = vim.diagnostic.severity.WARN })
end, opts('Diagnostic: Go to next warning'))

-- Jump to first/last diagnostic in buffer
keymap('n', '[D', function()
    diag_jump({ count = -1, wrap = false })
end, opts('Diagnostic: Go to first in buffer'))
keymap('n', ']D', function()
    diag_jump({ count = 1, wrap = false })
end, opts('Diagnostic: Go to last in buffer'))

-- Diagnostic display
keymap('n', '<leader>d', vim.diagnostic.open_float, opts('Diagnostic: Show line diagnostics'))
keymap('n', '<leader>q', function()
    vim.diagnostic.setloclist()
    vim.cmd('lopen')
end, opts('Diagnostic: Open location list'))
keymap('n', '<leader>Q', function()
    vim.diagnostic.setqflist()
    vim.cmd('copen')
end, opts('Diagnostic: Open quickfix list'))

-- Toggle diagnostics
local diagnostics_active = true
keymap('n', '<leader>td', function()
    diagnostics_active = not diagnostics_active
    if diagnostics_active then
        vim.diagnostic.enable()
        print("Diagnostics enabled")
    else
        vim.diagnostic.disable()
        print("Diagnostics disabled")
    end
end, opts('Diagnostic: Toggle diagnostics'))

-- =======================================================================
-- INDENTATION EXCEPTIONS (vim-sleuth handles existing files)
-- =======================================================================
local indent_augroup = vim.api.nvim_create_augroup("IndentExceptions", { clear = true })

-- Tabs (required by tooling)
vim.api.nvim_create_autocmd("FileType", {
    group = indent_augroup,
    pattern = { "go", "gomod", "gosum", "make" },
    callback = function()
        vim.opt_local.expandtab = false
        vim.opt_local.tabstop = 4
        vim.opt_local.shiftwidth = 4
    end,
})

-- 2 spaces (strong ecosystem conventions)
vim.api.nvim_create_autocmd("FileType", {
    group = indent_augroup,
    pattern = { 
        -- Web/JS ecosystem
        "javascript", "typescript", "javascriptreact", "typescriptreact",
        "html", "css", "json", 
        -- Config files
        "yaml", "lua",
        -- Infrastructure
        "terraform", "hcl"
    },
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.shiftwidth = 2
        vim.opt_local.softtabstop = 2
    end,
})

-- =======================================================================
-- SESSIONS (auto-managed by cwd via mini.sessions)
-- =======================================================================
local session_augroup = vim.api.nvim_create_augroup("AutoSessions", { clear = true })

local function session_name_from_cwd()
    return vim.fn.getcwd():gsub("/", "%%")
end

vim.api.nvim_create_autocmd("VimEnter", {
    group = session_augroup,
    nested = true,
    callback = function()
        -- Skip if nvim was opened with file args or stdin
        if vim.fn.argc() > 0 then return end

        local name = session_name_from_cwd()
        local sessions = require("mini.sessions")
        if sessions.detected[name] then
            sessions.read(name, { verbose = false })
        else
            sessions.write(name, { verbose = false })
        end

        -- Session restore doesn't trigger BufRead events, so treesitter,
        -- LSP, and other lazy-loaded plugins never attach. Re-edit all
        -- buffers to replay the full event chain.
        vim.schedule(function()
            local current = vim.api.nvim_get_current_buf()
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
                if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buflisted then
                    local bufname = vim.api.nvim_buf_get_name(buf)
                    if bufname ~= "" and vim.fn.filereadable(bufname) == 1 then
                        vim.api.nvim_buf_call(buf, function()
                            vim.cmd("edit")
                        end)
                    end
                end
            end
            vim.api.nvim_set_current_buf(current)
            vim.cmd.colorscheme("tokyonight-night")
        end)
    end,
    desc = "Auto-load or create session based on cwd",
})

-- =======================================================================
-- ADDITIONAL SETTINGS
-- =======================================================================
-- Decrease update time for better UX
vim.opt.updatetime = 250

-- wrap text and markdown files
vim.api.nvim_create_autocmd("FileType", {
    pattern = { "markdown", "text" },
    callback = function()
        vim.opt_local.wrap = true
        vim.opt_local.linebreak = true -- break at words, not characters
    end,
})

-- autosave on focus lost or buffer leave
local autosave_timer = nil
local delay = 2500 -- Debounce delay in milliseconds (2.5 second)

vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "FocusLost", "BufLeave" }, {
    pattern = "*",
    callback = function(args)
        local bufnr = args.buf

        if autosave_timer then
            autosave_timer:stop()
            autosave_timer = nil
        end

        autosave_timer = vim.defer_fn(function()
            if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].modified then
                vim.api.nvim_buf_call(bufnr, function() vim.cmd("silent! update") end)
            end
            autosave_timer = nil
        end, delay)
    end,
    desc = "Debounced autosave on changes or leaving mode",
})

