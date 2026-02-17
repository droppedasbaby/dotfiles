# zinit download and load
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions

# brew needs to add the paths
if command -v brew >/dev/null 2>&1; then
  eval "$(brew shellenv)"
elif [ -x /opt/homebrew/bin/brew ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"
export PYENV_SHELL=zsh

_pyenv_lazy_init() {
  unset -f pyenv
  eval "$(command pyenv init - zsh)"
  if command -v brew >/dev/null 2>&1; then
    local pyenv_comp
    pyenv_comp="$(brew --prefix pyenv 2>/dev/null)/completions/pyenv.zsh"
    [ -f "$pyenv_comp" ] && source "$pyenv_comp"
  fi
}

pyenv() {
  _pyenv_lazy_init
  pyenv "$@"
}

# history
HISTSIZE=100000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
# bindings for history
bindkey '^K' history-beginning-search-backward
bindkey '^J' history-beginning-search-forward

# completion styling
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select

# Prompts for confirmation after 'rm *' etc.
setopt RM_STAR_WAIT

# Improved globbing
setopt EXTENDED_GLOB
setopt GLOB_DOTS

# load zsh-completions
autoload -U compinit && compinit
zinit cdreplay -q

# aliases
alias ls='ls -glah'
alias vim='nvim'
alias c='clear'
alias d='dev'

# path changes
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$PATH:$GOPATH/bin"
export KUBECONFIG=~/.kube/config
export TALOSCONFIG=~/.talos/config

# integrations
eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/tokyonight_storm.omp.json)" # oh-my-posh
eval "$(fzf --zsh)" #fzf
eval "$(zoxide init --cmd cd zsh)" #zoxide
alias update='brew update && brew upgrade'

# Dev session launcher
source ~/.config/zsh/dev.zsh

# Secrets (tokens, API keys — not checked into git)
[ -f "$HOME/.dotfiles/.secrets" ] && source "$HOME/.dotfiles/.secrets"
