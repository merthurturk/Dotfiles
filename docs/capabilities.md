# Capabilities — the `dot` surface

`bin/dot` is the single entry point. Each capability is one script in
`libexec/dot/` named `<group>-<verb>`, and **every one describes itself**.

```sh
dot                        # grouped list with summaries
dot scene open chill       # <group> <verb> [args]
dot doctor                 # single-word commands work too
dot capabilities --json    # every descriptor, assembled
```

## The descriptor is the only registration

A capability answers `--describe` with JSON. That single fact drives everything:

- the ⌥space palette renders from it
- `dot help` lists from it
- `dot capabilities --json` is what an agent reads
- `bin/check-capabilities.sh` validates it

There is deliberately **no second place** to register a command. An earlier
design had a hand-written palette plus a checker whose whole job was catching
drift between it and reality; both are gone.

## Fields

| Field | Required | Meaning |
|---|---|---|
| `id` | yes | stable dotted identifier, e.g. `scene.close` |
| `summary` | yes | one line, imperative |
| `destructive` | yes | does this destroy state the user can't trivially recreate |
| `guard` | **when destructive** | what stops it firing at the wrong target |
| `verify` | for mutations | a command proving the change landed |
| `args` | — | `[{name, required, choices, default}]` |
| `instances` | — | menu rows; see below |
| `keys` | — | chords this capability wants; see below |

`check-capabilities.sh` **fails** if a destructive capability declares no
`guard`. That convention is the only thing between an agent and a mistake it
can't undo.

## `instances` decide what's in the palette

A capability appears in the ⌥space palette exactly when it declares instances,
one row each:

```json
"instances": [
  {"label": "Close scene: chill", "detail": "workspace 3", "args": ["3"]}
]
```

Query commands — `dot scene list`, `dot window list`, `dot theme list` —
declare none on purpose. Printing JSON into a GUI picker helps nobody; they are
CLI and agent surface.

Instances are computed at `--describe` time, so they track live state: only
*open* scenes offer a Close, only *occupied* workspaces are listed.

## Never hardcode a keybinding

`_lib.sh` provides `keybinding <substring>` and `keysym`, which read
`aerospace.toml`. A hint written by hand drifts from the binding it describes —
that happened, and every scene claimed `⌥⇧space` including ones with no binding
at all.

```sh
kb="$(keysym "$(keybinding "dot scene open $name")")"   # -> ⌥⇧space, or empty
```

## `keys` — asking for a chord

Most capabilities should ask for none. `⌥⇧space` is a leader and its letters
open the launcher *filtered*, so anything with an `instances` entry is already
reachable in two keystrokes. Declare a chord only when something earns a
dedicated one.

When it does:

```json
"keys": [{"chord": "ctrl-alt-c", "args": ["chill"]}]
```

`dot keys --apply` collects every declared chord and writes them into a marked
block that `aerospace.toml` ships **empty**:

```toml
    # --- declared keys: managed by `dot keys --apply` -----------------------
    ctrl-alt-c = 'exec-and-forget $HOME/.local/bin/dot scene open chill'
    # --- end declared keys --------------------------------------------------
```

Because the block ships empty, applying only ever *replaces between markers* —
there is no insertion point to compute and get wrong.

This is the one thing a descriptor could not say for itself, and until it could,
a dedicated chord meant hand-editing `aerospace.toml` — the last place in this
repo where adding something meant touching a second file. Note what did *not*
change: `aerospace.toml` is still the only source of truth for what is bound,
and `dot keys` still renders the map by reading it. A descriptor is now one more
thing allowed to write to that file, not a second copy of its contents.

### What stops it going wrong

| | |
|---|---|
| `check-capabilities.sh` | rejects a chord with no modifier (`c = '…'` takes the C key from every app), an unknown modifier, or the same chord declared twice |
| `dot keys --apply` | refuses a chord already bound elsewhere in the config, naming both sides, and changes nothing |
| | requires everything outside the block to come out byte-identical |
| | writes, runs `aerospace reload-config --dry-run`, and restores the old file if AeroSpace won't parse it |
| `dot doctor` | warns when a declared chord is not in the config — nothing applies it for you |

The block travels to `awk` through a *file*, never `-v`: macOS awk rejects a
literal newline in a `-v` assignment and fails by writing nothing, which copied
over `aerospace.toml` is an empty config — and AeroSpace parses an empty config
as valid, so the dry run would not have caught it either. That is not
hypothetical; see [macos](macos.md).

### Where the chord comes from

It does not have to be hardcoded in the descriptor either. A scene's chord is a
`key` field in `scenes.json`, so `scene-open` emits one `keys` entry per scene
that has one — and `dot scene edit` sets it from the launcher, then applies.
Data, all the way down.

## `DOT_ORIG_WS` / `DOT_ORIG_WID`

The menu captures the focused workspace and window **before** it shows the
picker, and exports them. A capability that wants to act "beside what I was
looking at" must prefer those over asking:

```bash
ORIG_WS="${DOT_ORIG_WS:-$($AEROSPACE list-workspaces --focused)}"
```

Asking afterwards is a race: the picker panel taking and releasing focus means
the answer is sometimes a different workspace entirely. `dot ai` opened its
session on the wrong workspace because of exactly this.

## Verify, don't trust exit codes

AeroSpace will accept `layout tiling`, return 0, and move nothing. It reports
"already tiling" for a window its own `resize` then calls floating. Exit codes
here are not evidence — that is what `verify` is for.

```sh
dot scene open chill && dot scene list --json
```

## Adding one

Create `libexec/dot/<group>-<verb>`:

```bash
#!/usr/bin/env bash
set -u
source "${DOT_LIB:?}"

if [ "${1:-}" = "--describe" ]; then
  jq -n '{id:"group.verb", summary:"…", args:[], destructive:false,
          instances:[{label:"…", detail:"", args:[]}]}'
  exit 0
fi

audit "group verb ${*:-}"
exec …
```

Then `bin/check-capabilities.sh`. Nothing else to update — not the palette, not
`dot help`, not the docs index.

## Where capabilities can live

`DOT_PATH` is a search path, defaulting to:

```
~/.config/dot/libexec : <repo>/libexec/dot
```

Earlier entries win, so **a capability of your own never needs to go in this
repo** — and dropping your own `window-split` into `~/.config/dot/libexec`
overrides the shipped one without touching a tracked file. `dot help`, the
palette, the dispatcher and `check-capabilities.sh` all resolve through the
same path, so an override is what gets listed, run *and* validated.

A package is a directory on that path. Nothing else is needed: the descriptor
already carries everything anything downstream reads.

Two consequences worth knowing:

- Write `source "${DOT_LIB:?}"`, not a path relative to your file. `dot`
  exports `DOT_LIB`, which is what lets an out-of-tree capability reach the
  library at all.
- Each `--describe` is under a **3-second watchdog**. Without one a single slow
  descriptor hangs ⌥space for ever with no window and no error — survivable
  while every capability is ours, not once the path is open.

## What `_lib.sh` already does for you

Reach for these before writing your own — most of them exist because the same
few lines had been copy-pasted into four capabilities and the copies had
started to differ.

| | |
|---|---|
| `audit "…"` | append to `~/.local/state/aerospace/audit.log`. Anything that mutates state should call it |
| `keybinding` / `keysym` | read the real binding out of `aerospace.toml` |
| `scenes_json` | the merged `scenes.json` + `scenes.local.json`, cached |
| `scene_exists <name>` | ask that, rather than re-deriving it |
| `slug <text>` | a scene name you can still type on the command line |
| `orig_ws` / `orig_wid` | what you were looking at *before* the palette took focus |
| `pick` / `ask` / `confirm` | the picker, in its three shapes |
| `workspace_rows <exclude>` | occupied workspaces plus the first empty one, annotated |
| `json_update <file> <jq args…>` | atomic read-modify-write through `mktemp` |
| `repaint` | nudge the bar so a change shows now, not on the next switch |
| `theme_dir` / `theme_names` | resolve a theme through `DOT_THEME_PATH` |
| `_ledger_lib` / `_chrome_lib` | source the ledger or Chrome-profile owner, once, on first use — then `ledger_rows`, `scene_of`, `ids_of`, `workspaces_of`, `chrome_pick_profile` and the rest are yours |

Two things deliberately *not* there: `SCENES_JSON`, because the shipped file
must never be read without the local one merged over it; and any helper that
generates a whole descriptor, because that was tried and reverted —
[principles](principles.md) has the reasoning.
