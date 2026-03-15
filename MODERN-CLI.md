# Modern CLI replacements

Commands that behave differently from stock macOS due to aliases, plugins, or shell init.

## Aliased commands

| You type | Runs | Replaces | Key differences |
|----------|------|----------|-----------------|
| `ls` | `eza --icons --group-directories-first` | `/bin/ls` | File-type icons, dirs listed first |
| `ll` | `eza -lh --icons ...` | `ls -lh` | Long listing with icons |
| `la` | `eza -lah --icons ...` | `ls -lah` | Includes hidden files |
| `lt` | `eza -lah --icons --tree --level=2` | `ls` + `tree` | 2-level tree view |
| `cat` | `bat -pp` | `/bin/cat` | Syntax highlighting, plain pager mode |
| `grep` | `rg` (ripgrep) | `/usr/bin/grep` | Faster, respects `.gitignore`, regex by default |
| `du` | `dust` | `/usr/bin/du` | Visual bar chart of disk usage |
| `diff` | `delta` | `/usr/bin/diff` | Side-by-side, syntax highlighted, line numbers |
| `top` | `htop` | `/usr/bin/top` | Interactive process viewer with color |
| `vim` | `nvim` | `/usr/bin/vim` | Neovim with full LSP/treesitter config |
| `n` | `nvim` | — | Shorthand for neovim |

## Shell overrides (not aliases)

| You type | Runs | Replaces | How |
|----------|------|----------|-----|
| `cd` | `zoxide` | builtin `cd` | `zoxide init --cmd cd` replaces `cd` with frecency-based jump. `cd foo` finds the most-used directory matching `foo`. Falls back to normal `cd` for explicit paths. |
| `git diff` | `delta` (as pager) | default git pager | `core.pager = delta` in gitconfig. All git diffs, logs, and blames render through delta with side-by-side + line numbers. |
| `git diff` (interactive) | `delta --color-only` | — | `interactive.diffFilter` in gitconfig for `git add -p`. |

## Available but not aliased

| Command | Replaces | Notes |
|---------|----------|-------|
| `fd` | `find` | Faster, simpler syntax, respects `.gitignore`. Not aliased — use `fd` directly. |
| `sd` | `sed` | Simpler find-and-replace syntax. Not aliased — use `sd` directly. |
| `glow` | — | Terminal markdown renderer. |
| `bat` | `cat` | Aliased as `cat`, but `bat` with full options (line numbers, paging) is available directly. |
| `hyperfine` | `time` | CLI benchmarking tool with statistical output. |
| `entr` | — | Run commands when files change. `ls *.go \| entr go test` |
| `watchexec` | — | Similar to `entr` but watches directories recursively. |
| `tldr` | `man` | Community-driven simplified man pages. |

## Extra aliases

| Alias | Expands to | Purpose |
|-------|-----------|---------|
| `fdh` | `fd -H -I` | Search including hidden and gitignored files |
| `rgh` | `rg --hidden --no-ignore` | Grep including hidden and gitignored files |
| `c` | `clear` | Clear terminal |
| `update` | `brew update && brew upgrade` | Update all brew packages |

## Reverting to stock commands

Use the full path to bypass:

```sh
/bin/ls        # stock ls
/bin/cat       # stock cat
/usr/bin/grep  # stock grep
/usr/bin/diff  # stock diff
/usr/bin/du    # stock du
/usr/bin/vim   # stock vim
```

Or prefix with `command` (bypasses aliases but not shell functions):

```sh
command ls
command cat
```

For `cd` (overridden by zoxide as a shell function), use `builtin cd` to get the original.
