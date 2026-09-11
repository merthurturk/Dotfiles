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

Query commands — `dot scene list`, `dot window list`, `dot focus status` —
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
kb="$(keysym "$(keybinding 'dot scene open')")"   # -> ⌥⇧space, or empty
```

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
source "$(dirname "${BASH_SOURCE[0]}")/_lib.sh"

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

`_lib.sh` also gives you `audit`, which appends to
`~/.local/state/aerospace/audit.log`. Anything that mutates state should call it.
