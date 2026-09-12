# dotfiles

macOS setup: [AeroSpace](https://nikitabobko.github.io/AeroSpace/) tiling driving
[SketchyBar](https://felixkratz.github.io/SketchyBar/), themed **Opal** — pale
surfaces, colour kept for the things that carry meaning, and edges drawn rather
than shadows cast.

```sh
dot theme set opal-white    # the pale one (derives from Catppuccin Latte)
dot theme set opal-fire     # warm surfaces, terracotta accent
dot theme set opal-black    # dark; takes macOS dark mode with it
dot theme set synthwave     # neon, and the wallpaper has a sun and a grid
```

Switching takes the whole desk with it: the bar, the window outlines, the
wallpaper and screen saver, macOS's own light/dark setting, and the terminal —
Ghostty has no IPC on macOS, so open panes are repainted with OSC escape
sequences written to their ttys. Every colour that carries text is measured
against 4.5:1 by `bin/check-themes.sh`.

## Install on a new Mac

```sh
git clone https://github.com/merthurturk/Dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` installs Homebrew and the `Brewfile`, symlinks every config,
compiles the Swift picker, starts the services, and prints the GUI-only steps
that remain. It is re-runnable: anything it would overwrite is moved to
`~/.dotfiles-backup/<timestamp>/` first.

## Documentation

| Doc | For |
|---|---|
| [architecture](docs/architecture.md) | how the parts fit together |
| [capabilities](docs/capabilities.md) | the `dot` surface |
| [bar](docs/bar.md) | SketchyBar items, geometry, fonts |
| [scenes](docs/scenes.md) · [themes](docs/themes.md) · [picker](docs/picker.md) | the pieces |
| [macos](docs/macos.md) | platform constraints worth knowing |
| [troubleshooting](docs/troubleshooting.md) | when something misbehaves |

## Layout

| Path | Links to |
|---|---|
| `aerospace.toml` | `~/.aerospace.toml` |
| `config/aerospace/` | `~/.config/aerospace/` |
| `config/sketchybar/` | `~/.config/sketchybar/` |
| `config/ghostty/` | `~/.config/ghostty/` |

Anything added under `config/` is linked to `~/.config/<name>` automatically —
no edit to `install.sh` needed.

## What's in the bar

Left: AeroSpace workspace pills (drawn only when occupied or focused, with
per-app glyphs), binding-mode badge, front app.
Right: now-playing, volume/battery/clock cluster, Focus chip.

- **Focus chip** — left click toggles, right click opens Focus settings. Reads
  live state from `~/Library/DoNotDisturb/DB`.
- **Now playing** — Apple Music; click focuses its window *through AeroSpace*,
  so it switches to the right workspace. Hidden when Music isn't running.
- **Hover** — clickable items (workspace pills, ☕, Focus, now-playing) take a
  blue ring on `mouse.entered`. Only the *border* changes, never the fill, so it
  reads correctly over every state colour.

SketchyBar has no cursor property, so the pointer can't change to a hand over
clickable items — the ring is the whole affordance available.

## Keybindings on top of the AeroSpace defaults

| Key | Action |
|---|---|
| `⌥space` | **Command palette** — every action, searchable, with its keybinding shown |
| `⌥⇧↩` | New Chrome window beside the focused one at 3/5–2/5, asking which profile |
| ⇧↩ *in that picker* | …open it on a fresh workspace instead of beside |
| `⌥⇧\` | `balance-sizes` — reset the workspace to even splits |
| `⌃⌘F` | Fill the workspace with this window — **not** macOS fullscreen, so the layout survives |
| `⌥⇧space` | Open the `chill` scene on an empty workspace (also left-click the ☕ button) |
| `⌥⇧⌫` | Close the scene on the focused workspace (also right-click ☕) |

`config/aerospace/split-with.sh "<App>" <ratio>` does the same for any app but
summons an existing window instead of opening a new one. Bind more with:

```toml
alt-shift-g = 'exec-and-forget $HOME/.config/aerospace/chrome-split.sh 0.6 "Relote"'
```

Passing a profile name skips the picker.

## Fonts

All **text** is Berkeley Mono — terminal, bar labels, picker. Hack Nerd Font is
used only for **icon glyphs** (battery, volume, clock, focus, music), because
Berkeley Mono carries no Nerd Font glyphs.

Berkeley Mono is commercial and cannot ship here. Install it from your
[Berkeley Graphics](https://berkeleygraphics.com/) account on a new machine;
until then everything falls back to Hack Nerd Font automatically.

Two traps worth remembering:

- Each Berkeley Mono weight installs as its **own family** with style
  `Regular`. Asking sketchybar for `Berkeley Mono:Bold:13.0` silently falls back
  to the system font — it looks fine but renders no Berkeley at all. Weight must
  be chosen by family name: `Berkeley Mono Bold SemiCondensed:Regular`.
- For the same reason Ghostty needs `font-family-bold` / `font-family-italic`
  named explicitly, or it synthesises them.

## `dot` — one command for everything

Every capability of this setup is a `dot` command, and every `dot` command
describes itself. That descriptor is the single source of truth: the ⌥space
palette renders from it, `dot help` lists from it, and an agent reads it to
find out what it can do. Nothing is registered twice.

```sh
dot                        # what can I do?
dot scene open chill       dot theme set rose-pine-dawn
dot scene close 3          dot focus toggle
dot window split 0.6       dot doctor
dot capabilities --json    # the whole surface, machine-readable
```

A descriptor looks like this, and lives next to the code it describes:

```json
{
  "id": "scene.close",
  "summary": "Close every window on a scene's workspace",
  "destructive": true,
  "guard": "refuses any workspace the scene script did not open; --force overrides",
  "verify": "dot scene list --json",
  "instances": [{"label": "Close scene: chill", "detail": "workspace 3", "args": ["3"]}]
}
```

`instances` are what put a capability in the palette — query commands like
`dot scene list` declare none, because printing JSON into a picker is useless.

### Asking in plain language

```sh
dot ai "why isn't my focus chip toggling?"
```

Opens a real Claude Code session in a Ghostty window **beside** the focused one,
in this repo, with your request as the opening message. It has the full toolkit:
it can read the configs, run `dot`, check what actually happened and iterate —
which a one-shot planner can't.

```sh
dot ai --plan "turn on do not disturb and open my messaging scene"
```

The constrained path instead: Claude gets only the capability manifest, may emit
only `dot` commands, and the plan is shown with destructive steps flagged before
anything runs. Without a terminal it requires an explicit confirmation and
**fails closed** on anything else. Use it when you want a deterministic action
rather than a conversation.

## The command palette — ⌥space

**This is the main entry point.** If you remember one shortcut, remember this
one: everything below is reachable from it, and each entry shows its own
keybinding, so it doubles as the place to rediscover a binding you've forgotten.

```
Open scene: chill          ⌥⇧space
Close scene: chill         workspace 3
Focus: turn off            Do Not Disturb is on
Focus settings             right-click the bar chip
Chrome beside this window  ⌥⇧↩
Balance window sizes       ⌥⇧\
Reset workspace layout     ⌥⇧; then r
Toggle floating / tiling   ⌥⇧; then f
Toggle fullscreen
Close focused window
Go to workspace 2          Google Chrome
Go to workspace 4          Music
Focus Music                Philip Sayce — Once
Reload AeroSpace config
Reload SketchyBar
```

The menu is rebuilt on every invocation, so it reflects current state: Focus
reads on or off with the live mode name, only *open* scenes offer a Close, only
*occupied* workspaces are listed and they're labelled with the apps on them.

### Keeping it complete

It stays complete on its own: the palette *is* the capability list. Adding a
capability adds a menu entry; removing one removes it. There is nothing to keep
in sync.

```sh
dot menu --dry-run           # print the palette without a GUI
bin/check-capabilities.sh    # every capability describes itself correctly
```

`CLAUDE.md` and `.claude/skills/dot/` carry the contract for AI sessions.

## Scenes

`config/aerospace/scene.sh <scene>` opens a named window layout on the first
**empty** workspace: a wide Chrome window with several tabs, plus a narrower one
beside it. The side window uses Chrome's `--app` flag, which drops the tab strip
and toolbar — what you want for a chat panel living in ~500pt.

| Scene | Windows |
|---|---|
| `chill` | YouTube / X / Instagram at 70%, Context Engine chat at 30% |
| `messaging` | WhatsApp and Telegram, 50/50 |

A scene is a list of window specs, left to right:

A workspace running a scene shows the scene's **badge** — its glyph and name in
its own colour — instead of the usual app icons, because "chill" says more than
three browser glyphs do.

| Field | Purpose |
|---|---|
| `icon` | Nerd Font glyph shown in the pill |
| `label` | Short name for the bar; defaults to the scene's key |
| `badge` | `PEACH`, `TEAL`, `MAUVE`, `BLUE` or `GREEN` from `colors.sh` |

`label` matters more than it looks: the pill's width is almost entirely its text,
so `messaging` → `chat` took that pill from 107pt to 73pt and brought it back
into line with the app-icon pills.

| Spec | Opens |
|---|---|
| `app:<App Name>` | summons that app's window, launching it only if needed |
| `chrome:<urls…>` | a new Chrome window with those tabs |
| `chrome-app:<url>` | a Chrome `--app` window: no tab strip, no toolbar |

`RATIO` is the share of width given to the first window. Add a scene by adding
a `case` branch, then optionally bind it:

```toml
alt-shift-period = 'exec-and-forget $HOME/.config/aerospace/scene.sh work'
```

A second argument picks the Chrome profile by display name, defaulting to
`Default`.

Closing:

```sh
scene.sh close            # the focused workspace
scene.sh close 5          # a specific one
scene.sh close --force 5  # one it didn't open
```

`scene.sh` records the workspaces it opens in
`~/.local/state/aerospace/scenes` and **refuses to close anything else**,
listing the open scenes instead. That guard matters: focus drifts on its own as
apps activate, so a plain "close the focused workspace" will eventually fire at
the wrong one.

## The picker

`config/aerospace/src/picker.swift` compiles to a standalone chooser:
auto-focused search field, fuzzy filter, arrows + enter, esc to cancel. Generic —
reads lines on stdin, prints the choice on stdout:

```sh
ls ~/Projects | PICKER_PROMPT="Open project" ~/.config/aerospace/bin/picker
```

Lines may be `label` or `label<TAB>detail`; the detail renders dimmed on the
right and is matched against as well as the label:

```sh
printf 'api	go
web	typescript
' | ~/.config/aerospace/bin/picker
```

Rebuild after editing:

```sh
swiftc -O -o ~/.config/aerospace/bin/picker \
          ~/.config/aerospace/src/picker.swift -framework AppKit
```

## Updating the Brewfile

```sh
brew bundle dump --file=~/.dotfiles/Brewfile --force
```

Note that a dump is unsorted and uncommented — the checked-in `Brewfile` groups
entries by purpose, so prefer editing it by hand.

## How the bar gets its updates

A launchd agent, `config/aerospace/event-bridge.sh`, subscribes to AeroSpace's
event stream and translates it into SketchyBar triggers. It replaced ~40
`exec-and-forget sketchybar --trigger` calls that previously had to be repeated
on every binding, and it picks up `window-detected`, which no binding could
provide.

AeroSpace emits no event for a window *closing* or for one moved by id from a
script, so `spaces_watcher` also polls every 5s as a backstop.

Scripts run by `exec-and-forget` or a `click_script` have their stderr thrown
away, so anything user-facing sources `config/aerospace/logging.sh`, which
diverts stderr to `~/.local/state/aerospace/log` — but only when no terminal is
attached, so running by hand still shows your errors.

## Themes

```sh
dot theme list
dot theme set rose-pine-dawn
```

A theme is a directory under `themes/` holding `colors.sh` (the bar palette),
`ghostty.conf` (the terminal) and `meta.json`. `config/sketchybar/colors.sh` and
`config/ghostty/theme.conf` are symlinks into the active one, so the bar and the
terminal can't drift apart.

Both shipped themes are light. Accents are **darkened from their upstream
palettes** until white text on them clears 4.5:1 — Latte's peach measures 2.64:1
as a fill, and Rosé Pine Dawn's gold 2.05:1. Beautiful for syntax highlighting,
unusable for a chip with a label on it.

Ghostty picks up a theme change on its next config reload (⌘⇧, in a terminal).

The desktop picture and the screen saver follow too. There is no image file in
the repo: one is rendered from the theme's own `colors.sh` at your display's
pixel size — a light wash of the theme's accents, quiet in the middle where the
windows go — and set as both the wallpaper and the screen saver.

```sh
dot theme wallpaper            # re-render for the current theme
dot theme wallpaper --show     # what macOS actually has set
dot theme wallpaper --restore  # back to what you had before
```

macOS 14 moved both into one store and left the screen saver half with no
public API, so the first run copies that store aside before editing it.

### Outlines, not shadows

Nothing here floats above anything else. The bar draws a 1px border with its
shadow off, chips outline themselves when they mean something, and
[JankyBorders](https://github.com/FelixKratz/JankyBorders) outlines each window
— focused windows in the same accent as the focused workspace pill, so "where
am I" is one colour wherever you look. Screenshot drop shadows are off too.

macOS's own window drop shadow is the one that stays. It can be read but not
written from an unprivileged process — three different SkyLight calls all
report success and change nothing. Removing it needs yabai's scripting
addition, which requires partially disabling SIP.

## Development

```sh
dot doctor                   # is everything actually working?
bin/check-capabilities.sh    # every capability describes itself correctly
dot menu --dry-run           # print the palette without a GUI
```

`githooks/pre-commit` runs shell syntax, shellcheck and the launcher check;
`install.sh` points `core.hooksPath` at it. Skip with `--no-verify`.

## Notes worth keeping

The things that cost real time here — TCC, bash 3.2's missing associative
arrays, squircle corners, notch insets, invisible characters in app names,
AeroSpace reporting success while doing nothing — are recorded in
[docs/macos.md](docs/macos.md) rather than repeated here, so there is one copy
to keep true.
