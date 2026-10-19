#!/usr/bin/bash
# Install the temporary OpenCode-usage shim for the Omarchy agents panel.
#
#   install.sh              install/refresh the shim and remove the old
#                           community opencode-go solution
#   install.sh --keep-old   leave the old solution running alongside
#
# Idempotent: re-running re-pins the checkout, reinstalls the files, and
# restarts the timer.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REF=${OMARCHY_PR_REF:-agents-cursor-opencode-copilot-muse}
SHA=${OMARCHY_PR_SHA:-f2e5624075dd9d82c08fe6699535bf5557064e33}
URL=${OMARCHY_URL:-https://github.com/omacom/omarchy}

MIRROR=${OMARCHY_OPENCODE_MIRROR:-$HOME/.local/share/omarchy-opencode-usage}
LIB=$HOME/.local/lib/omarchy-opencode-usage
UNITS=$HOME/.config/systemd/user
HOOK_DIR=$HOME/.config/omarchy/hooks/post-update.d
HOOK=$HOOK_DIR/opencode-usage-retire.hook
USAGE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage

KEEP_OLD=false
for arg in "$@"; do
  case $arg in
  --keep-old) KEEP_OLD=true ;;
  *)
    echo "install: unknown argument: $arg" >&2
    exit 2
    ;;
  esac
done

ensure_mirror() {
  if [[ ! -d $MIRROR/.git ]]; then
    rm -rf "$MIRROR"
    git clone --depth 1 --filter=blob:none --sparse --branch "$REF" "$URL" "$MIRROR"
  fi
  git -C "$MIRROR" sparse-checkout set --no-cone \
    '/bin/omarchy-agent-usage-*' '/bin/omarchy-agent-account-state' \
    '/shell/plugins/agents/collectors.py'
  git -C "$MIRROR" cat-file -e "${SHA}^{commit}" 2>/dev/null ||
    git -C "$MIRROR" fetch --depth 1 origin "$REF"
  git -C "$MIRROR" checkout --quiet "$SHA"
  [[ -x $MIRROR/bin/omarchy-agent-usage-opencode ]] || {
    echo "install: collector missing after checkout of $SHA" >&2
    exit 1
  }
  echo "checkout  $MIRROR @ $(git -C "$MIRROR" rev-parse --short HEAD)"
}

install_files() {
  mkdir -p "$LIB" "$UNITS" "$HOOK_DIR"
  install -m 755 "$REPO/lib/run.sh" "$LIB/run.sh"
  install -m 755 "$REPO/uninstall.sh" "$LIB/uninstall.sh"
  install -m 755 "$REPO/status.sh" "$LIB/status.sh"
  install -m 755 "$REPO/refresh.sh" "$LIB/refresh.sh"
  install -m 644 "$REPO/systemd/omarchy-opencode-usage.service" \
    "$UNITS/omarchy-opencode-usage.service"
  install -m 644 "$REPO/systemd/omarchy-opencode-usage.timer" \
    "$UNITS/omarchy-opencode-usage.timer"
  install -m 755 "$REPO/hooks/post-update.d/opencode-usage-retire.hook" "$HOOK"
}

remove_old_solution() {
  if $KEEP_OLD; then
    echo "keeping   old opencode-go solution (--keep-old)"
    return 0
  fi
  systemctl --user disable --now opencode-go-usage.timer 2>/dev/null || true
  rm -f "$UNITS/opencode-go-usage.timer" "$UNITS/opencode-go-usage.service"
  systemctl --user daemon-reload 2>/dev/null || true
  mkdir -p "$REPO/backup"
  if [[ -d $HOME/.local/share/opencode-go-usage ]]; then
    rm -rf "$REPO/backup/opencode-go-usage"
    cp -a "$HOME/.local/share/opencode-go-usage" "$REPO/backup/"
    rm -rf "$HOME/.local/share/opencode-go-usage"
    echo "removed   ~/.local/share/opencode-go-usage (backed up in repo/backup/)"
  fi
  if [[ -f $USAGE_DIR/opencode-go.json ]]; then
    cp "$USAGE_DIR/opencode-go.json" "$REPO/backup/"
    rm -f "$USAGE_DIR/opencode-go.json"
    echo "removed   opencode-go.json (backed up in repo/backup/)"
  fi
}

# The new producer is installed and run before the old one is removed, so the
# OpenCode tab never disappears — only the duplicate "OpenCode Go" tab does.
ensure_mirror
install_files
systemctl --user daemon-reload
systemctl --user enable --now omarchy-opencode-usage.timer
systemctl --user start omarchy-opencode-usage.service

RECORD=$USAGE_DIR/opencode.json
if [[ -f $RECORD ]]; then
  echo "record    $(jq -c '{id, name, tier: .tierLabel, limits: (.limits | length), todayTotalTokens}' "$RECORD")"
else
  echo "warning   no record yet at $RECORD" >&2
  echo "          check: systemctl --user status omarchy-opencode-usage.service" >&2
fi

remove_old_solution
echo "done      $LIB/status.sh"
