#!/usr/bin/bash
# Report which producer owns the OpenCode record for the Omarchy agents panel.
set -uo pipefail

MIRROR=${OMARCHY_OPENCODE_MIRROR:-$HOME/.local/share/omarchy-opencode-usage}
HOOK=$HOME/.config/omarchy/hooks/post-update.d/opencode-usage-retire.hook
USAGE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage
RECORD=$USAGE_DIR/opencode.json

echo "== upstream (real Omarchy) =="
if [[ -x /usr/share/omarchy/bin/omarchy-agent-usage-opencode ]]; then
  echo "present  /usr/share/omarchy/bin/omarchy-agent-usage-opencode"
  echo "         -> upstream owns the record; the shim should be retired"
else
  echo "absent   shim owns the record"
fi

echo "== checkout =="
if [[ -d $MIRROR/.git ]]; then
  echo "path     $MIRROR"
  echo "sha      $(git -C "$MIRROR" rev-parse HEAD 2>/dev/null)"
  echo "subject  $(git -C "$MIRROR" log -1 --format=%s 2>/dev/null)"
else
  echo "missing  $MIRROR"
fi

echo "== systemd =="
echo "enabled  $(systemctl --user is-enabled omarchy-opencode-usage.timer 2>/dev/null || echo no)"
echo "active   $(systemctl --user is-active omarchy-opencode-usage.timer 2>/dev/null || echo no)"
systemctl --user list-timers omarchy-opencode-usage.timer --all --no-legend 2>/dev/null | sed 's/^/         /'

echo "== hook =="
[[ -f $HOOK ]] && echo "installed $HOOK" || echo "absent"

echo "== record =="
if [[ -f $RECORD ]]; then
  jq -r '"id=\(.id) name=\(.name) tier=\(.tierLabel) limits=\(.limits|length) stale=\(.limitsStale) updatedAt=\(.updatedAt)"' "$RECORD"
  echo "age      $(( $(date +%s) - $(stat -c %Y "$RECORD") ))s"
else
  echo "missing  $RECORD"
fi

echo "== old solution leftovers =="
[[ -f $USAGE_DIR/opencode-go.json ]] && echo "WARNING  $USAGE_DIR/opencode-go.json still present" || echo "clean    no opencode-go.json"
[[ -e $HOME/.local/share/opencode-go-usage ]] && echo "WARNING  ~/.local/share/opencode-go-usage still present" || echo "clean    no community collector checkout"
[[ -e $HOME/.config/systemd/user/opencode-go-usage.timer ]] && echo "WARNING  opencode-go-usage.timer still installed" || echo "clean    no opencode-go-usage.timer"
