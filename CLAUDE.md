# Working in this repo

macOS tiling setup: AeroSpace + SketchyBar, Catppuccin Latte, Ghostty.
`readme.md` is the user-facing documentation; this file is the working contract.

---

## The launcher is the main entry point

`config/aerospace/launcher.sh`, bound to **⌥space**, is the canonical way into
everything this setup does. It is not a convenience layer bolted on the side —
it is the discovery surface. A user who remembers only ⌥space must be able to
reach every capability from it, and to learn its keybinding while doing so.

**This is a maintenance obligation, not a suggestion.**

### Whenever you add an action

Add a keybinding, a bar button, or a new script that does something a user
would want to invoke → **register it in `launcher.sh` in the same change**.

```bash
add "<label>" "<detail>" "<command>"
```

- `label` — imperative and plain: `Balance window sizes`, not `balance-sizes`.
- `detail` — **the keybinding**, e.g. `⌥⇧space`. This column is what makes the
  launcher a discovery tool rather than just a menu. If there's no binding, use
  context instead (`workspace 3`, `Do Not Disturb is on`) or leave it empty.
- `command` — what to run. Quote paths containing `$DIR`.

Put it in the section it belongs to (scenes / focus / windows / workspaces /
music / system), and keep state-dependent entries state-dependent: only offer
*Close scene* for scenes that are open, only list *occupied* workspaces.

### Whenever you remove or rename an action

Remove or update its launcher entry in the same change. A palette entry that
fails is worse than a missing one.

### Whenever you change a keybinding

Update the `detail` column. A stale binding hint actively misleads.

### Verify

```sh
bin/check-launcher.sh      # fails if a binding or bar button has no entry
launcher.sh --dry-run      # prints the menu without a GUI
```

`check-launcher.sh` is the backstop, not the goal — it proves a binding is
*mentioned*, not that the entry is good. Read the rendered menu.

---

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
| `config/aerospace/launcher.sh` | **the palette — keep in sync** |
| `config/aerospace/scene.sh` | named window layouts; `--list` feeds the palette |
| `config/aerospace/split-lib.sh` | shared window sizing |
| `config/aerospace/src/picker.swift` | the chooser, compiled to `bin/picker` (gitignored) |
| `bin/check-launcher.sh` | the launcher completeness check |

After editing: `aerospace reload-config`, `sketchybar --reload`, and rebuild the
picker with `swiftc -O -o config/aerospace/bin/picker
config/aerospace/src/picker.swift -framework AppKit`.
