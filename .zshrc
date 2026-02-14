# zinit download and load
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# zsh plugins
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# brew needs to add the paths
eval "$(/opt/homebrew/bin/brew shellenv)"

# pyenv (cached init for faster startup)
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/shims:$PYENV_ROOT/bin:$PATH"
export PYENV_SHELL=zsh
source "$(brew --prefix pyenv)/completions/pyenv.zsh"
pyenv() {
  local command=${1:-}
  [ "$#" -gt 0 ] && shift
  case "$command" in
  rehash|shell)
    eval "$(command pyenv "sh-$command" "$@")"
    ;;
  *)
    command pyenv "$command" "$@"
    ;;
  esac
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
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color $realpath'
zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color $realpath'

# snippets
zinit snippet OMZP::command-not-found
zinit snippet OMZP::dotenv
zinit snippet OMZP::gitignore
zinit snippet OMZP::sudo

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

# path changes
export PATH="$PATH:$(go env GOPATH)/bin"
export KUBECONFIG=~/.kube/config
export TALOSCONFIG=~/.talos/config

# integrations
eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/tokyonight_storm.omp.json)" # oh-my-posh
eval "$(fzf --zsh)" #fzf
eval "$(zoxide init --cmd cd zsh)" #zoxide
alias update='brew update && brew upgrade'
