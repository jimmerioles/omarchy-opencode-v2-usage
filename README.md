# Temporary OpenCode v2 usage for the Omarchy agents panel

Omarchy `4.0.5` ships an agents panel that renders any record in
`~/.local/state/omarchy/agents/usage/`, but collects only Claude, Codex, and
Fireworks. This shim produces the missing `opencode.json` until
[omarchy#14040](https://github.com/omacom/omarchy/pull/14040) lands, then
retires itself.

## Why it works this way

The agents panel is a pure file consumer — `Agent.qml` says "a record that
appears in the usage directory is an agent, whoever wrote it", and an id that
isn't in settings is enabled by default. So making OpenCode work is only a
matter of writing a correct `opencode.json`. No `/usr/share` edits, no plugin,
no QML.

The panel's own refresh loop (`omarchy-agent-usage-update`) only iterates
`$OMARCHY_PATH/bin/omarchy-agent-usage-*` under root-owned `/usr/share/omarchy`,
so a user cannot plug into it — a user timer is the only seam in 4.0.5.

Rather than reimplement the collector, this shim runs **upstream's own**:

- a pinned, sparse git checkout of the PR branch (`SOURCE` records the commit)
- the unit sets `OMARCHY_PATH` to that checkout and runs upstream's
  `bin/omarchy-agent-usage-update opencode`
- the record is therefore authored by the exact code path that will ship, with
  the same id (`opencode`), the same file name, and the same labels

That is what makes the hand-off a no-op instead of a migration: when upstream
lands, its collector writes the same file, so nothing in the panel changes.

Why not a small hand-written collector: a correct one has to handle both
message stores, fork-copy exclusion, message-id dedup, two endpoint payload
spellings, the Console `x-opencode-org-id` header, token expiry, and the
credential precedence chain. On a machine whose only credential is an OAuth
Console token, that is exactly the code you would be guessing at — and its
output would still relabel the tab at transition.

## Install

```bash
./install.sh          # pin, install, and remove the old opencode-go solution
./install.sh --keep-old
```

It is idempotent. The new producer is installed and run *before* the old
`opencode-go` solution is removed, so the OpenCode tab never disappears — only
the duplicate "OpenCode Go" tab does. The old collector and record are copied
to `backup/` (gitignored) first.

## Operate

```bash
~/.local/lib/omarchy-opencode-usage/status.sh     # who owns the record
~/.local/lib/omarchy-opencode-usage/refresh.sh    # re-pin to the branch tip
~/.local/lib/omarchy-opencode-usage/refresh.sh <sha>
systemctl --user list-timers omarchy-opencode-usage.timer
```

## How it retires

Two independent triggers, both calling `uninstall.sh --retire`:

1. `lib/run.sh` checks the **real** `/usr/share/omarchy/bin/omarchy-agent-usage-opencode`
   before every run (never `$OMARCHY_PATH` — the checkout has its own copy).
2. `~/.config/omarchy/hooks/post-update.d/opencode-usage-retire.hook` fires on
   the same `omarchy update` that installs upstream's collector.

Retirement disables and removes the unit, the checkout, the hook, and the lib
directory, and **leaves `opencode.json` alone** for upstream to keep writing.

```bash
~/.local/lib/omarchy-opencode-usage/uninstall.sh            # full removal
~/.local/lib/omarchy-opencode-usage/uninstall.sh --retire   # hand off
```

## Notes

- Refresh cadence is 900 s, mirroring upstream's panel default.
- 4.0.5's settings schema doesn't know `providers.opencode`, so the tab can't
  be toggled from the Settings UI; edit `~/.config/omarchy/shell.json` instead.
- Upstream correctly excludes forked-session copies. The community collector
  this replaces double-counted them (~17M tokens on 2026-10-19).
- `--filter=blob:none` fetches blobs on demand, so an offline re-install needs
  a plain `--depth 1` clone instead.
