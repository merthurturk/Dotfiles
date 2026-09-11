# Working in this repo

A macOS tiling setup: AeroSpace + SketchyBar + Ghostty, all driven by one
command, `dot`. `readme.md` is user-facing; this file is the working contract.

**Read [`docs/architecture.md`](docs/architecture.md) first.** It explains how
the four moving parts fit together and is the index for everything else.

| Doc | For |
|---|---|
| [architecture](docs/architecture.md) | how it fits together, state files, symlinks |
| [capabilities](docs/capabilities.md) | the `dot` surface, descriptors, adding one |
| [bar](docs/bar.md) | SketchyBar items, plugins, geometry, fonts, colour |
| [scenes](docs/scenes.md) | `scenes.json`, window specs, the close ledger |
| [themes](docs/themes.md) | theme structure, the generated wallpaper, outlines, why accents get darkened |
| [picker](docs/picker.md) | the Swift chooser, modes, frecency |
| [macos](docs/macos.md) | platform constraints — TCC, bash 3.2, AeroSpace quirks |
| [troubleshooting](docs/troubleshooting.md) | symptom → cause |

---

## Rules

### `dot` is the entry point

Everything goes through `bin/dot`. Don't edit a config to do something `dot`
can do, and don't add a keybinding or bar button with no `dot` command behind
it.

### One capability, one file, one registration

A capability is `libexec/dot/<group>-<verb>` answering `--describe` with JSON.
That descriptor is the *only* registration — the palette, `dot help`,
`dot capabilities --json` and the validator all read it.

There was once a hand-written palette plus a checker whose job was catching
drift between it and reality. Both are gone. **Do not reintroduce a second place
to register things.**

Required: `id`, `summary`, `destructive`. Plus `guard` whenever destructive
(the validator fails without it), `verify` for anything that mutates, and
`instances` to appear in the palette. Details in
[capabilities](docs/capabilities.md).

### Verify against the world, not the exit code

AeroSpace returns 0 and does nothing, routinely. A font string that doesn't
resolve falls back silently and looks correct. Measure, query, re-read — don't
assert. Several bugs here survived precisely because something reported success.

### Destructive actions need a ledger, not a prompt

`scene.sh` records what it opened and refuses to close anything else. A
confirmation dialog is too easy to click through, and focus drifts on its own,
so "act on the focused thing" will eventually act on the wrong thing. It already
did once.

### Never hardcode a keybinding

Read it from `aerospace.toml` with `keybinding()` in `_lib.sh`. A hand-written
hint drifts from the binding it describes.

### No absolute paths

No `/Users/<name>`, no `/opt/homebrew`. Use `$HOME`, and the `[exec]` `PATH`
table in `aerospace.toml` — which must stay the **last** table in the file,
because a TOML table captures every key after it.

### Data over code

Scenes are `scenes.json`. Themes are `themes/<name>/`. Adding either should not
mean editing a script.

### Outlines, not shadows

Surfaces are separated by drawing their edge — the bar, the chips, the windows
(JankyBorders) and screenshots. `shadow=on` is not a thing this setup does.
`WINDOW_BORDER_ACTIVE` and `WINDOW_BORDER_INACTIVE` are theme data like
everything else; a future theme is free to disagree, but it has to say so in
its own `colors.sh`.

macOS's own window shadow is the exception: it cannot be written from an
unprivileged process. Don't try again — three SkyLight routes are measured in
[macos](docs/macos.md), and all three return success while changing nothing.

### Stderr is discarded

By both `exec-and-forget` and `click_script`. Anything user-facing sources
`config/aerospace/logging.sh`.

---

## Before you finish

```sh
dot doctor                   # the live system, including GUI-only steps
bin/check-capabilities.sh    # every descriptor is valid
githooks/pre-commit          # syntax + shellcheck + the above
```

The hook runs on commit. Don't `--no-verify` past it without saying why.

Keep the docs true: if you change how something works, the doc describing it is
part of the change.
