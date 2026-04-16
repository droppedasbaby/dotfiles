# block: website blocker via /etc/hosts with timer lock
#
# Usage:
#   block              - block sites (unlockable any time)
#   block <duration>   - block sites for duration (e.g. 2h, 30m) with timer lock
#   block off          - unblock (respects timer lock)
#   block break        - 15 min escape hatch (once per session, after 2h)
#   block status       - show current state + remaining time
#
# Config:
#   $CONFIGS_DIR/block/domains.txt   one domain per line, # comments ok
#
# Dependencies: sudo (for /etc/hosts edits)

_block_config="${CONFIGS_DIR:-$DEV_DIR/configs}/block/domains.txt"
_block_state_dir="$HOME/.local/state/block"
_block_hosts="/etc/hosts"
_block_start="########## BLOCKED:START ##########"
_block_end="########## BLOCKED:END ##########"

_block_is_active() {
  grep -q "$_block_start" "$_block_hosts" 2>/dev/null
}

_block_human_remaining() {
  local sec="$1"
  local h=$((sec / 3600)) m=$(((sec % 3600) / 60))
  if (( h > 0 )); then
    echo "${h}h ${m}m"
  else
    echo "${m}m"
  fi
}

_block_parse_duration() {
  local input="$1"
  local val="${input%[hm]}"
  local unit="${input: -1}"
  case "$unit" in
    h) echo $(( val * 3600 )) ;;
    m) echo $(( val * 60 )) ;;
    *) echo "block: invalid duration '$input' — use e.g. 2h or 30m" >&2; return 1 ;;
  esac
}

_block_state_read() {
  local key="$1"
  local file="$_block_state_dir/state"
  [[ -f "$file" ]] || return 1
  grep "^${key}=" "$file" 2>/dev/null | cut -d= -f2
}

_block_state_write() {
  mkdir -p "$_block_state_dir"
  local file="$_block_state_dir/state"
  local key="$1" val="$2"
  if [[ -f "$file" ]] && grep -q "^${key}=" "$file" 2>/dev/null; then
    sed -i '' "s/^${key}=.*/${key}=${val}/" "$file"
  else
    echo "${key}=${val}" >> "$file"
  fi
}

_block_state_clear() {
  rm -f "$_block_state_dir/state"
}

_block_remove() {
  local tmp
  tmp=$(mktemp) || return 1
  sudo awk -v start="$_block_start" -v end="$_block_end" \
    '$0 == start {skip=1; next} $0 == end {skip=0; next} !skip' \
    "$_block_hosts" \
    | awk 'NF {p=1} p' \
    | awk '{lines[NR]=$0} END {while(lines[NR]=="") NR--; for(i=1;i<=NR;i++) print lines[i]}' \
    | sudo tee "$tmp" >/dev/null || { rm -f "$tmp"; return 1; }
  sudo cp "$tmp" "$_block_hosts"
  rm -f "$tmp"
}

_block_flush_dns() {
  sudo dscacheutil -flushcache 2>/dev/null
  sudo killall -HUP mDNSResponder 2>/dev/null
}

_block_apply() {
  _block_remove

  if [[ ! -f "$_block_config" ]]; then
    mkdir -p "${_block_config:h}"
    cat > "$_block_config" <<'EOF'
# Domains to block — one per line
youtube.com
www.youtube.com
EOF
    echo "block: created template config at $_block_config — edit it, then re-run."
    return 1
  fi

  {
    printf '\n\n'
    echo "$_block_start"
    while IFS= read -r domain || [[ -n "$domain" ]]; do
      domain="${domain%%\#*}"
      domain="${domain// /}"
      [[ -z "$domain" ]] && continue
      echo "127.0.0.1 $domain"
      echo "::1 $domain"
    done < "$_block_config"
    echo "$_block_end"
  } | sudo tee -a "$_block_hosts" >/dev/null
}

function block() {
  local cmd="${1:-}"

  case "$cmd" in
    status)
      if ! _block_is_active; then
        echo "Not blocking."
        return 0
      fi
      local unlock_at started_at break_used
      unlock_at=$(_block_state_read unlock_at)
      started_at=$(_block_state_read started_at)
      break_used=$(_block_state_read break_used)
      local now=$(date +%s)

      if [[ -n "$unlock_at" ]] && (( now < unlock_at )); then
        echo "Blocking — $(_block_human_remaining $((unlock_at - now))) remaining."
      elif [[ -n "$unlock_at" ]]; then
        echo "Blocking — timer expired. Run: block off"
      else
        echo "Blocking indefinitely."
      fi

      if [[ -n "$started_at" ]]; then
        local active_for=$(( now - started_at ))
        if (( active_for >= 7200 )) && [[ "$break_used" != "1" ]]; then
          echo "Escape hatch available: block break"
        fi
      fi
      ;;

    off)
      if ! _block_is_active; then
        echo "Not blocking."
        return 0
      fi
      local unlock_at=$(_block_state_read unlock_at)
      if [[ -n "$unlock_at" ]]; then
        local now=$(date +%s)
        if (( now < unlock_at )); then
          local remain=$((unlock_at - now))
          echo "Refused — $(_block_human_remaining "$remain") remaining."
          return 1
        fi
      fi
      _block_remove
      _block_state_clear
      _block_flush_dns
      echo "Unblocked."
      ;;

    break)
      if ! _block_is_active; then
        echo "Not blocking."
        return 0
      fi

      local break_used=$(_block_state_read break_used)
      if [[ "$break_used" == "1" ]]; then
        echo "Refused — break already used this session."
        return 1
      fi

      local started_at=$(_block_state_read started_at)
      if [[ -z "$started_at" ]]; then
        echo "Refused — no session start time recorded."
        return 1
      fi

      local now=$(date +%s)
      local active_for=$(( now - started_at ))
      if (( active_for < 7200 )); then
        local need=$(( 7200 - active_for ))
        echo "Refused — need 2h of blocking first. $(_block_human_remaining "$need") to go."
        return 1
      fi

      _block_state_write break_used 1

      # Build the block entries now so the background process doesn't need to read config
      local entries=""
      while IFS= read -r domain || [[ -n "$domain" ]]; do
        domain="${domain%%\#*}"
        domain="${domain// /}"
        [[ -z "$domain" ]] && continue
        entries+="127.0.0.1 $domain\n::1 $domain\n"
      done < "$_block_config"

      _block_remove
      _block_flush_dns
      echo "Break — 15 minutes. Enjoy it."

      # Re-block after 15 min in a disowned root process
      sudo bash -c "
        sleep 900
        printf '\n\n$_block_start\n${entries}$_block_end\n' >> '$_block_hosts'
        dscacheutil -flushcache 2>/dev/null
        killall -HUP mDNSResponder 2>/dev/null
      " &!
      ;;

    on|"")
      _block_apply || return 1
      _block_state_clear
      mkdir -p "$_block_state_dir"
      _block_state_write started_at "$(date +%s)"
      _block_flush_dns
      echo "Blocked."
      ;;

    *)
      local seconds
      seconds=$(_block_parse_duration "$cmd") || return 1
      _block_apply || return 1
      _block_state_clear
      mkdir -p "$_block_state_dir"
      _block_state_write started_at "$(date +%s)"
      _block_state_write unlock_at "$(( $(date +%s) + seconds ))"
      _block_flush_dns
      echo "Blocked for $cmd."
      ;;
  esac
}
