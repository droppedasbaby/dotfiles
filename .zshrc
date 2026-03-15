# Secrets (tokens, API keys — not checked into git)
if [ -f "$HOME/.secrets.zsh" ]; then
  source "$HOME/.secrets.zsh" || print -P "%F{red}[zshrc] failed to source .secrets.zsh%f" >&2
fi

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

# brew shellenv — cached (regenerate: rm ~/.cache/zsh/brew.zsh)
() {
  local cache="$HOME/.cache/zsh/brew.zsh"
  [[ -d "${cache:h}" ]] || mkdir -p "${cache:h}"
  if [[ ! -f "$cache" ]]; then
    local brew_bin
    if command -v brew >/dev/null 2>&1; then brew_bin=brew
    elif [[ -x /opt/homebrew/bin/brew ]]; then brew_bin=/opt/homebrew/bin/brew
    elif [[ -x /usr/local/bin/brew ]]; then brew_bin=/usr/local/bin/brew
    fi
    [[ -n "$brew_bin" ]] && "$brew_bin" shellenv > "$cache" 2>/dev/null
  fi
  [[ -f "$cache" ]] && source "$cache"
}

export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
export PATH="$PYENV_ROOT/shims:$PATH"
pyenv() {
  unfunction pyenv
  eval "$(command pyenv init --path)"
  eval "$(command pyenv init -)"
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

# aliases — modern replacements
alias ls="eza --icons --group-directories-first"
alias ll="eza -lh --icons --group-directories-first"
alias la="eza -lah --icons --group-directories-first"
alias lt="eza -lah --icons --tree --level=2"
alias cat="bat -pp"
alias grep="rg"
alias du="dust"
alias diff="delta"
alias top="htop"

# shortcuts
alias vim="nvim"
alias n="nvim"
alias c="clear"
alias yolo="claude --dangerously-skip-permissions"

# search everything (hidden + ignored)
alias fdh="fd -H -I"
alias rgh="rg --hidden --no-ignore"

# path changes
export GOPATH="${GOPATH:-$HOME/go}"
export PATH="$PATH:$GOPATH/bin"
export KUBECONFIG=~/.kube/config
export TALOSCONFIG=~/.talos/config

# integrations — cached eval outputs (regenerate: rm ~/.cache/zsh/*)
() {
  local cache_dir="$HOME/.cache/zsh"
  [[ -d "$cache_dir" ]] || mkdir -p "$cache_dir"

  _cached_eval() {
    local name=$1 bin=$2; shift 2
    local cache="$cache_dir/$name.zsh"
    local bin_path="${commands[$bin]:-}"
    if [[ -z "$bin_path" ]]; then
      print -P "%F{red}[zshrc] $bin not found%f" >&2; return 1
    fi
    if [[ ! -f "$cache" ]] || [[ "$bin_path" -nt "$cache" ]]; then
      "$@" > "$cache" 2>/dev/null || { print -P "%F{red}[zshrc] $name init failed%f" >&2; return 1; }
    fi
    source "$cache"
  }

  # Pure zsh prompt — tokyonight storm colors, zero subprocesses
  setopt PROMPT_SUBST
  autoload -Uz vcs_info
  zstyle ':vcs_info:*' enable git
  zstyle ':vcs_info:git:*' formats '%b'
  zstyle ':vcs_info:git:*' actionformats '%b|%a'

  _prompt_precmd() {
    vcs_info
    local git_info=""
    [[ -n "${vcs_info_msg_0_}" ]] && git_info=$' %F{#7dcfff}\ue725 '"${vcs_info_msg_0_}%f"
    local py_info=""
    [[ -n "$VIRTUAL_ENV" ]] && py_info=$' %F{#e0af68}\ue235 ['"${VIRTUAL_ENV:t}]%f"
    PS1=$'%F{#7aa2f7}\u25b6%f %F{#bb9af7}%~%f'"${git_info}${py_info}"$'\n%F{#9ece6a}\u279c%f '
  }
  autoload -Uz add-zsh-hook
  add-zsh-hook precmd _prompt_precmd

  _cached_eval fzf fzf                fzf --zsh

  unfunction _cached_eval
}
alias update="brew update && brew upgrade"

# Shell functions (cc, ds, wt, _lib — from dotfiles)
for f in ~/.config/zsh/*.zsh(N); do
  [[ -f "$f" ]] && { source "$f" || print -P "%F{red}[zshrc] failed to source ${f:t}%f" >&2; }
done

# Syntax Highlighting
zinit light zsh-users/zsh-syntax-highlighting

# Warn if machine-local config dir is missing
if [[ -n "${DEV_DIR:-}" && ! -d "$DEV_DIR/configs" ]]; then
  print -P "%F{yellow}[setup] \$DEV_DIR/configs not found — run: mkdir -p $DEV_DIR/configs/repo%f" >&2
fi

# zoxide — must be last (overrides cd)
() {
  local cache="$HOME/.cache/zsh/zoxide.zsh"
  local bin_path="${commands[zoxide]:-}"
  [[ -z "$bin_path" ]] && return
  if [[ ! -f "$cache" ]] || [[ "$bin_path" -nt "$cache" ]]; then
    zoxide init --cmd cd zsh > "$cache" 2>/dev/null || return
  fi
  source "$cache"
}
