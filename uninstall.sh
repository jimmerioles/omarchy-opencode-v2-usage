#!/usr/bin/bash
# Remove the temporary OpenCode-usage shim. This is the single cleanup
# implementation: install.sh, the post-update hook, and the user all call it.
#
#   uninstall.sh            remove everything, including our record when no
#                           upstream collector will take it over
#   uninstall.sh --retire   upstream has landed; stop writing and leave
#                           opencode.json for upstream's own update
set -uo pipefail

RETIRE=false
[[ ${1:-} == "--retire" ]] && RETIRE=true

MIRROR=${OMARCHY_OPENCODE_MIRROR:-$HOME/.local/share/omarchy-opencode-usage}
LIB=$HOME/.local/lib/omarchy-opencode-usage
UNITS=$HOME/.config/systemd/user
HOOK=$HOME/.config/omarchy/hooks/post-update.d/opencode-usage-retire.hook
USAGE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/agents/usage

systemctl --user disable --now omarchy-opencode-usage.timer 2>/dev/null || true
rm -f "$UNITS/omarchy-opencode-usage.timer" "$UNITS/omarchy-opencode-usage.service"
systemctl --user daemon-reload 2>/dev/null || true

rm -rf "$MIRROR"

# On retire, upstream owns opencode.json and will rewrite it on its own
# schedule. Otherwise drop our record only when nothing else would write one.
if ! $RETIRE && [[ ! -x /usr/share/omarchy/bin/omarchy-agent-usage-opencode ]]; then
  rm -f "$USAGE_DIR/opencode.json"
fi

rm -f "$HOOK"
# Last: this script lives in $LIB, and deleting a running script's directory is
# safe on Linux (the descriptor stays open); nothing follows this line.
rm -rf "$LIB"
