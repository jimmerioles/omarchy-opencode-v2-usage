#!/usr/bin/bash
# Re-pin the vendor checkout to the PR branch tip (or to a given commit), then
# force one collection run.
#
#   refresh.sh             re-pin to the branch tip and refresh
#   refresh.sh <sha>       pin a specific commit and refresh
set -euo pipefail

REF=${OMARCHY_PR_REF:-agents-cursor-opencode-copilot-muse}
MIRROR=${OMARCHY_OPENCODE_MIRROR:-$HOME/.local/share/omarchy-opencode-usage}
TARGET=${1:-}

[[ -d $MIRROR/.git ]] || {
  echo "refresh: no checkout at $MIRROR; run install.sh" >&2
  exit 1
}

git -C "$MIRROR" fetch --depth 1 origin "$REF"
if [[ -n $TARGET ]]; then
  SHA=$TARGET
else
  SHA=$(git -C "$MIRROR" rev-parse FETCH_HEAD)
fi

git -C "$MIRROR" sparse-checkout set --no-cone \
  '/bin/omarchy-agent-usage-*' '/bin/omarchy-agent-account-state' \
  '/shell/plugins/agents/collectors.py'
git -C "$MIRROR" checkout --quiet "$SHA"

[[ -x $MIRROR/bin/omarchy-agent-usage-opencode ]] || {
  echo "refresh: collector missing at $SHA" >&2
  exit 1
}

echo "pinned $SHA"
git -C "$MIRROR" log -1 --format='subject: %s' "$SHA"
echo "update SOURCE in the repo to record the new commit"
systemctl --user start omarchy-opencode-usage.service
