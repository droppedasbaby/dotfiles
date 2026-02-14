#!/bin/bash
set -e

DOTFILES_DIR="$HOME/.dotfiles"
DOTFILES_REPO="https://github.com/droppedasbaby/dotfiles.git"

# Clone dotfiles if not present
if [ ! -d "$DOTFILES_DIR" ]; then
	echo "Cloning dotfiles..."
	git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Check if Homebrew is installed, install if it isn't
if ! command -v brew &>/dev/null; then
	echo "Homebrew not installed. Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
if command -v brew &>/dev/null; then
	eval "$(brew shellenv)"
elif [ -x /opt/homebrew/bin/brew ]; then
	eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
	eval "$(/usr/local/bin/brew shellenv)"
fi

# Install tools from Brewfile
echo "Installing software from Brewfile..."
brew bundle --file="$DOTFILES_DIR/Brewfile"

# Symlink dotfiles with Stow (--restow makes it safe to re-run)
echo "Using Stow to manage dotfiles..."
cd "$DOTFILES_DIR"
stow --target="$HOME" --restow .

# Authenticate GitHub CLI
if ! gh auth status &>/dev/null; then
	echo "Authenticating GitHub CLI..."
	gh auth login
fi

# Install TPM if not present
if [ ! -d ~/.tmux/plugins/tpm ]; then
	git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi
~/.tmux/plugins/tpm/bin/install_plugins

# macOS defaults
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10
mkdir -p ~/Screenshots
defaults write com.apple.screencapture location ~/Screenshots
defaults write com.apple.Accessibility ReduceMotionEnabled -int 1

# Restart affected apps
killall Dock || true
killall SystemUIServer || true

echo "Please restart the computer for everything to take effect."
