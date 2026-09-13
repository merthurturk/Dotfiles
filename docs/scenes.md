# Scenes

A scene is a named window layout opened onto a fresh workspace.

```sh
dot scene open chill       dot scene list
dot scene close 3          dot scene close --force 5
```

Definitions live in `config/aerospace/scenes.json` — **data, not code**:

```json
"chill": {
  "icon": "󰅶", "label": "chill", "badge": "PEACH", "ratio": 0.70,
  "windows": [
    "chrome:https://www.youtube.com https://x.com https://www.instagram.com",
    "chrome-app:https://chat.openai.com"
  ]
}
```

| Field | Meaning |
|---|---|
| `windows` | specs, left to right |
| `ratio` | share of width for the first window |
| `icon` | Nerd Font glyph for the workspace pill |
| `label` | short name for the bar; defaults to the key |
| `badge` | `PEACH`/`TEAL`/`MAUVE`/`BLUE`/`GREEN` from the theme |

## Window specs

| Spec | Opens |
|---|---|
| `app:<App Name>` | summons that app's window, launching it only if none exists |
| `chrome:<urls…>` | a new Chrome window with those tabs |
| `chrome-app:<url>` | a Chrome `--app` window — no tab strip, no toolbar |

`chrome-app` matters for a narrow panel: at ~500pt the tab strip and toolbar are
most of the window. Native apps are *summoned* rather than duplicated — a second
Telegram isn't a thing anyone wants.

## Never trust focus

`scene.sh` opens its windows wherever they land and then **moves them by window
id**, switching to the workspace last. It does not switch first.

The reason: `open -a` activates the app, which moves focus, and an empty
workspace has no window to hold focus — so AeroSpace falls back to the
previously focused window and the new windows are born on *that* workspace. The
first version did switch first, and opened scenes onto whatever workspace you
happened to be on.

## Opening one that is already open

`dot scene open` switches to the existing scene rather than building a second
copy on another workspace. Pressing the shortcut twice should land you on your
scene, not leave two of them around.

## The ledger

`scene.sh` records what it opens in `~/.local/state/aerospace/scenes` as
`<workspace>\t<scene>`, and **`close` refuses any workspace not in that file**.

This is not caution for its own sake. The first version defaulted to "close the
focused workspace" behind a confirmation dialog, and closed the wrong window
during testing, because focus drifts on its own as apps activate. A dialog is
too easy to click through; a ledger is not. `--force` exists for the rest.

The ledger records **which windows** the scene opened, not just the workspace,
and `close` only ever closes those. An earlier version recorded the workspace
alone and pruned an entry only once that workspace was completely empty — so if
the scene's own windows were gone but you had since put your own there, `close`
destroyed them. That happened during testing. An entry is pruned when none of
its windows are still open — keyed on the scene's own windows, not on the
workspace having anything at all, since an entry that outlives its windows is
exactly how `close` ends up destroying whatever you put there next.

`--force` still closes everything on the workspace, for when that is what you
mean.

## Badges

A workspace running a scene shows the scene's glyph and name in its colour
instead of app icons — "chill" says more than three browser glyphs. Unfocused is
a pale tint with deep text; focused flips to the deep colour as a fill.

Why a tint rather than a solid: see
[themes.md](themes.md#accents-must-be-darkened).

## Your own scenes

`scenes.json` holds examples and is version-controlled.
`config/aerospace/scenes.local.json` is yours, gitignored, and **merged over**
the shipped file — so a fork gets sensible defaults, and your own scenes survive
a `git pull`. Same shape; only the keys you set are overridden:

```json
{ "chill": { "windows": ["chrome-app:https://your-chat.example.com"] } }
```

## Adding one

Add an entry to `scenes.json`, or to `scenes.local.json` to keep it to yourself. It reaches the palette immediately — `dot scene
open --describe` enumerates the file. No code, and no second registration.

To bind it to a key, add to `aerospace.toml`:

```toml
alt-shift-m = 'exec-and-forget $HOME/.local/bin/dot scene open messaging'
```

The palette's keybinding hint picks it up automatically.
