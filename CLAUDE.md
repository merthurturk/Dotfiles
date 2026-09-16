# Working in this repo

A macOS tiling setup: AeroSpace + SketchyBar + Ghostty, all driven by one
command, `dot`. `readme.md` is user-facing; this file is the working contract.

**Read [`docs/architecture.md`](docs/architecture.md) first.** It explains how
the four moving parts fit together and is the index for everything else.

| Doc | For |
|---|---|
| [personas](docs/personas.md) | who this is for, and where it still falls short |
| [backlog](docs/backlog.md) | what's next, ordered by daily impact |
| [principles](docs/principles.md) | the rules, and what each one cost to learn |
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

### Everything is a search path

Five things can live outside this repo, and each defaults to
`~/.config/dot/...` ahead of the shipped copy. Earlier entries win, so adding
*or overriding* one never means editing a tracked file:

| | |
|---|---|
| `DOT_PATH` | capabilities — `libexec/` |
| `DOT_THEME_PATH` | themes |
| `SKETCHY_ITEM_PATH` | bar items |
| `SPEC_PATH` | scene window-spec handlers |
| `~/.config/dot/*.tsv` | world clocks, scene icons |

When you add something new that a user might reasonably want to replace, give
it a path rather than a constant. And write `source "${DOT_LIB:?}"` in a
capability — a path relative to the file only works inside this repo.

### Ask the owner, don't copy it

Four files exist to be `source`d, not executed, so asking costs nothing:

| | |
|---|---|
| `config/aerospace/scenes-lib.sh` | the scenes merge, its tombstones, its caches |
| `config/aerospace/ledger-lib.sh` | the open-scene ledger: format, pruning, MRU order |
| `config/aerospace/split-lib.sh` | window sizing, gaps, monitor width |
| `config/aerospace/chrome-lib.sh` | Chrome profiles, and asking which one |

The scenes merge was written out in four places before this; the ledger's
tab-separated format was parsed by five capabilities, which made its column
count public API. Both are one implementation now. **Do not add a fifth
reader.** `libexec/dot/_lib.sh` sources them on first use.

### Verify against the world, not the exit code

AeroSpace returns 0 and does nothing, routinely. A font string that doesn't
resolve falls back silently and looks correct. Measure, query, re-read — don't
assert. Several bugs here survived precisely because something reported success.

### Destructive actions need a ledger, not a prompt

`ledger-lib.sh` records what a scene opened and refuses to close anything else. A
confirmation dialog is too easy to click through, and focus drifts on its own,
so "act on the focused thing" will eventually act on the wrong thing. It already
did once.

### Never hardcode a keybinding

Read it from `aerospace.toml` with `keybinding()` in `_lib.sh`. A hand-written
hint drifts from the binding it describes. `dot keys` renders the whole map
from that file for the same reason — there is no cheat sheet to keep in step.

New commands usually need **no key at all**: `⌥⇧space` is a leader, and its
letters open the launcher *filtered* (`dot menu --filter scene`), so anything
with an `instances` entry is already reachable. Add a chord only when something
is worth a dedicated one — and when it is, declare `keys` in the descriptor and
run `dot keys --apply`, which owns a marked block in `aerospace.toml` the way
`dot window pin` owns one. Do not hand-edit a binding for a `dot` command; that
is the second registration this repo spent a long time removing.

### The launcher's PATH is not your shell's

Anything AeroSpace execs — the palette, every keybinding — gets the `[exec]`
`PATH` table in `aerospace.toml`, which has no `~/.local/bin` and no app
bundles. A capability must reach its tools by a resolved path, not by hoping
they are on `PATH`: `_lib.sh` does this for `aerospace` and `ghostty`, and
every keybinding spells out `$HOME/.local/bin/dot`.

Three bugs have come from forgetting it, all with the same signature — works
perfectly in a terminal, silently does nothing from the launcher. `dot doctor`
now checks the tools against that PATH.

### No absolute paths

No `/Users/<name>`, no `/opt/homebrew`. Use `$HOME`, and the `[exec]` `PATH`
table in `aerospace.toml` — which must stay the last table **carrying bare
keys**, because a TOML table captures every key after it. A later table
*header* is fine and ends it: that is where `dot window pin` appends its
`[[on-window-detected]]` rules.

### Data over code

Scenes are `scenes.json`. Themes are `themes/<name>/`. Adding either should not
mean editing a script.

### Outlines, not shadows

Surfaces are separated by drawing their edge — the bar, the chips, the windows
(JankyBorders) and screenshots. `shadow=on` is not a thing this setup does.
`WINDOW_BORDER_ACTIVE` and `WINDOW_BORDER_INACTIVE` are theme data like
everything else; a future theme is free to disagree, but it has to say so in
its own `colors.sh`.

### Contrast is measured, not chosen

Every colour a theme puts text on is checked by `bin/check-themes.sh`, which
the pre-commit hook runs. It was written after the hand-checked palette turned
out to ship a focused workspace pill at 4.34:1. Don't add a theme by eye.

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
bin/check-themes.sh          # every theme's text clears 4.5:1
githooks/pre-commit          # syntax + shellcheck + the above two
```

The hook runs on commit. Don't `--no-verify` past it without saying why.

Keep the docs true: if you change how something works, the doc describing it is
part of the change.
