#!/usr/bin/bash
# Refresh the OpenCode record for the Omarchy agents panel from the pinned
# upstream collector checkout, and retire this shim the moment upstream ships
# its own collector.
set -uo pipefail

# The real Omarchy install — never $OMARCHY_PATH: the checkout below contains
# its own copy of omarchy-agent-usage-opencode, so testing $OMARCHY_PATH would
# find it and retire immediately.
REAL_OMARCHY=${OMARCHY_REAL_PATH:-/usr/share/omarchy}
MIRROR=${OMARCHY_OPENCODE_MIRROR:-$HOME/.local/share/omarchy-opencode-usage}
LIB=$HOME/.local/lib/omarchy-opencode-usage

if [[ -x $REAL_OMARCHY/bin/omarchy-agent-usage-opencode ]] ||
  [[ -n $(command -v omarchy-agent-usage-opencode 2>/dev/null) ]]; then
  "$LIB/uninstall.sh" --retire
  exit 0
fi

[[ -x $MIRROR/bin/omarchy-agent-usage-opencode ]] || {
  echo "omarchy-opencode-usage: checkout missing at $MIRROR; run $LIB/refresh.sh" >&2
  exit 1
}

# Upstream's own update script writes the record: same jq validation, same
# mktemp + atomic mv, and the last good record is left in place on failure.
OMARCHY_PATH="$MIRROR" exec "$MIRROR/bin/omarchy-agent-usage-update" opencode
