# Working in this repo

macOS tiling setup: AeroSpace + SketchyBar, Catppuccin Latte, Ghostty.
`readme.md` is the user-facing documentation; this file is the working contract.

---

## `dot` is the entry point

`bin/dot` is the single, supported surface for everything this setup does.
**Do not edit config files to make a change `dot` can make**, and do not add a
keybinding or bar button that has no `dot` command behind it.

### Every capability describes itself

A capability is a script in `libexec/dot/<group>-<verb>` that answers
`--describe` with a JSON descriptor. That descriptor is the *only* registration:

- the ⌥space palette renders from it
- `dot help` lists from it
- `dot capabilities --json` is what an agent reads
- `bin/check-capabilities.sh` validates it

This replaced a hand-maintained launcher list plus a checker that policed drift
between it and reality. Don't reintroduce a second place to register things.

### Required fields

`id`, `summary`, `destructive`. Plus:

- **`instances`** — put the capability in the palette, one row each (a scene
  each, a workspace each). Omit for query-only commands; printing JSON into a
  picker helps nobody.
- **`guard`** — mandatory when `destructive: true`. The check fails without it.
  State what stops it firing at the wrong target.
- **`verify`** — a command that proves the change landed. Provide one for
  anything that mutates state.
- **`keybinding`** — never hardcode it. Read it from `aerospace.toml` with
  `keybinding()` in `_lib.sh`, so a hint can't drift from the binding.

### Verify, never trust exit codes

AeroSpace will accept `layout tiling` and report success while moving nothing —
this cost hours in one session. Anything that mutates state must be checked
against the world, which is what `verify` is for.

### Adding a capability

One file. No second registration. Then `bin/check-capabilities.sh`.

## Before you finish

```sh
dot doctor                   # verifies the live system, including GUI-only steps
bin/check-capabilities.sh    # every capability describes itself correctly
githooks/pre-commit          # syntax + shellcheck + capability validation
```

The hook runs automatically on commit. Don't `--no-verify` past it without
saying why.

## Conventions

**No absolute paths.** No `/Users/<name>`, no `/opt/homebrew`. Use `$HOME`, and
the `[exec]` `PATH` table in `aerospace.toml` (which must stay the **last** table
in the file — a TOML table captures every key after it).

**macOS ships bash 3.2.** No associative arrays: `declare -A` fails and string
subscripts silently collapse to index `0`. Group with `awk` instead. Test with
`/bin/bash`, not a Homebrew bash.

**Only sketchybar has Full Disk Access.** It is the sole process that can read
the Focus database, so it *publishes* state to `~/.local/state/aerospace/focus`
for everything else. Anything running under AeroSpace must read that file, not
the database.

**Don't trust focus to stay put.** `open -a` activates an app and moves focus;
an empty workspace has no window to hold it. Target windows and workspaces by
id, not by "whatever is focused". This has caused two real bugs.

**Destructive actions need a ledger, not a prompt.** `scene.sh` records what it
opens and refuses to close anything else. A confirmation dialog is too easy to
fire at the wrong target.

**Themes are data.** A theme is `themes/<name>/` with `colors.sh`,
`ghostty.conf` and `meta.json`. `dot theme set` repoints the symlinks. Accents
must be darkened until white text on them clears 4.5:1 — measure, don't eyeball;
both upstream palettes shipped accents that fail badly on a light background.

**Scenes are data.** They live in `config/aerospace/scenes.json`, not in a
`case` statement. `scene.sh --list` and `--describe` feed the launcher, so a new
scene appears in the palette on its own.

**Don't hand-wire triggers into `aerospace.toml`.** The event bridge
(`config/aerospace/event-bridge.sh`, a launchd agent) subscribes to AeroSpace's
event stream and drives the bar. The only events that exist are
`focus-changed`, `focused-monitor-changed`, `focused-workspace-changed`,
`mode-changed`, `window-detected` and `binding-triggered` — there is **no**
window-closed or window-moved event, which is why `spaces_watcher` also polls.

**Stderr is discarded** by both `exec-and-forget` and `click_script`. Anything
user-facing should source `config/aerospace/logging.sh`.

**Verify against the running system.** `sketchybar --query <item>`,
`aerospace list-windows`, `--dry-run`. Font and geometry claims in particular
should be measured, not asserted — a font string that doesn't resolve silently
falls back and looks like it worked.

---

## Layout

| Path | Purpose |
|---|---|
| `aerospace.toml` | → `~/.aerospace.toml` |
| `config/<name>/` | → `~/.config/<name>/` (auto-linked by `install.sh`) |
| `bin/dot` | the dispatcher — **the entry point** |
| `libexec/dot/<group>-<verb>` | one capability each, self-describing |
| `themes/<name>/` | `colors.sh` + `ghostty.conf` + `meta.json` |
| `config/aerospace/scene.sh` | named window layouts; `--list` feeds the palette |
| `config/aerospace/split-lib.sh` | shared window sizing |
| `config/aerospace/src/picker.swift` | the chooser, compiled to `bin/picker` (gitignored) |
| `bin/check-capabilities.sh` | validates every descriptor |

After editing: `aerospace reload-config`, `sketchybar --reload`, and rebuild the
picker with `swiftc -O -o config/aerospace/bin/picker
config/aerospace/src/picker.swift -framework AppKit`.
