# dotfiles

macOS dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

> **Platform:** macOS only. Requires Homebrew. Tools like Ghostty, Raycast, and oh-my-posh are macOS-specific and have no Linux equivalents here.

## AFTER SETUP: Swap Caps Lock and Ctrl

System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys

---

## What's included

- **zsh** — zinit plugins, pyenv, oh-my-posh, fzf, zoxide
- **neovim** — lazy.nvim config with LSP, treesitter, harpoon, flash
- **tmux** — TPM, tokyo-night theme, vim-tmux-navigator
- **gh** — GitHub CLI config
- **git** — global gitignore
- **Brewfile** — all brew packages, casks, and taps

## Shell utilities

Custom tools loaded from `~/.config/shell/`. **These are in active development, heavily AI-assisted, and experimental** — shell scripting isn't my strong suit so I lean on AI here. They work well for my workflow but may be rough around the edges and will improve over time. The rest of the repo (nvim, tmux, zsh config) is mostly hand-written — AI used mainly for cleanup, formatting, and best practice nudges.

| Command | Description |
|---------|-------------|
| `cc` | Pick and resume Claude / Codex conversations using fzf |
| `ds` | Open or attach a tmux session for a project directory (zoxide + fzf) |
| `wt` | Git worktree manager with per-repo post-create hooks |
| `sync-repos` | Batch-sync personal repos: fetch, rebase, commit, push with a secret guard |

Each script has a usage header with flags and config vars. See `.secrets.example` for required environment variables.

## Fresh machine setup

```bash
bash <(curl -s https://raw.githubusercontent.com/droppedasbaby/dotfiles/main/setup.sh)
```

Or manually:

```bash
git clone https://github.com/droppedasbaby/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./setup.sh
```

## Re-sync after changes

```bash
cd ~/.dotfiles && stow --restow .
```

## Update Brewfile from current installs

```bash
brew bundle dump --file=~/.dotfiles/Brewfile --force
```
