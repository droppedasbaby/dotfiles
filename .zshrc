# zinit download and load
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d "$ZINIT_HOME" ] && mkdir -p "$(dirname "$ZINIT_HOME")"
[ ! -d "$ZINIT_HOME/.git" ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh" || {
  print -P "%F{red}[zshrc] fatal: failed to source zinit.zsh — aborting remaining config%f" >&2
  return 1
}

# zsh plugins
zinit light zsh-users/zsh-completions
zinit light zsh-users/zsh-autosuggestions
zinit light Aloxaf/fzf-tab

# snippets
zinit snippet OMZP::command-not-found

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
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups
# bindings for history
bindkey "^K" history-beginning-search-backward
bindkey "^J" history-beginning-search-forward

# completion styling
zstyle ":completion:*" matcher-list "m:{a-z}={A-Za-z}"
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
if command -v gls >/dev/null 2>&1; then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'gls --color=auto "$realpath"'
  zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'gls --color=auto "$realpath"'
elif [[ "$(uname)" == "Darwin" ]]; then
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -G "$realpath"'
  zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls -G "$realpath"'
else
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls --color=auto "$realpath"'
  zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'ls --color=auto "$realpath"'
fi

# Prompts for confirmation after 'rm *' etc.
setopt RM_STAR_WAIT

# Improved globbing
setopt EXTENDED_GLOB
setopt GLOB_DOTS

# load zsh-completions
autoload -U compinit && compinit
zinit cdreplay -q

# aliases
if command -v gls >/dev/null 2>&1; then
  alias ls="gls -glah --color=auto"
elif [[ "$(uname)" == "Darwin" ]]; then
  alias ls="ls -glah -G"
else
  alias ls="ls -glah --color=auto"
fi
alias vim="nvim"
alias n="nvim"
alias c="clear"
alias yolo="claude --dangerously-skip-permissions"

# path changes
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$PATH:$GOPATH/bin"
export KUBECONFIG=~/.kube/config
export TALOSCONFIG=~/.talos/config

# integrations
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init zsh --config ~/.config/ohmyposh/tokyonight_storm_extra.omp.json)" \
    || print -P "%F{red}[zshrc] oh-my-posh init failed%f" >&2
else
  print -P "%F{red}[zshrc] oh-my-posh not found — prompt will be unstyled%f" >&2
fi
if command -v fzf >/dev/null 2>&1; then
  eval "$(fzf --zsh)" || print -P "%F{red}[zshrc] fzf init failed%f" >&2
else
  print -P "%F{red}[zshrc] fzf not found%f" >&2
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init --cmd cd zsh)" || print -P "%F{red}[zshrc] zoxide init failed%f" >&2
else
  print -P "%F{red}[zshrc] zoxide not found%f" >&2
fi
alias update="brew update && brew upgrade"

# Shell functions (cc, ds, wt, _lib — from dotfiles)
for f in ~/.config/shell/*.zsh(N); do
  [[ -f "$f" ]] && { source "$f" || print -P "%F{red}[zshrc] failed to source ${f:t}%f" >&2; }
done

# Syntax Highlighting
zinit light zsh-users/zsh-syntax-highlighting

# Secrets (tokens, API keys — not checked into git)
if [ -f "$HOME/.dotfiles/.secrets" ]; then
  source "$HOME/.dotfiles/.secrets" || print -P "%F{red}[zshrc] failed to source .secrets%f" >&2
fi

# Warn if machine-local config dir is missing
if [[ -n "${DEV_DIR:-}" && ! -d "$DEV_DIR/configs" ]]; then
  print -P "%F{yellow}[setup] \$DEV_DIR/configs not found — run: mkdir -p $DEV_DIR/configs/repo%f" >&2
fi
