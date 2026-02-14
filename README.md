# dotfiles

macOS dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).

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

