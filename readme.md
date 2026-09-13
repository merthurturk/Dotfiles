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

New here? [docs/personas.md](docs/personas.md) describes who this suits and
what it does for them — including where it still asks too much.

MIT licensed.

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
| [personas](docs/personas.md) | who this is for, and where it still falls short |
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

`dot window summon "<App>" <ratio>` does the same for any app, summoning an
existing window instead of opening a new one. Bind more with:

```toml
alt-shift-g = 'exec-and-forget $HOME/.config/aerospace/chrome-split.sh 0.6 "Relote"'
```

Passing a profile name skips the picker.

## Fonts

All **text** is Berkeley Mono — terminal, bar labels, picker. Hack Nerd Font is
used only for **icon glyphs**, because Berkeley Mono carries none.

Berkeley Mono is commercial and can't ship here; install it from your
[Berkeley Graphics](https://berkeleygraphics.com/) account and everything falls
back to Hack until you do.

There are two traps in how its weights install — see
[docs/bar.md](docs/bar.md#fonts).

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

`dot capabilities --json` is the manifest an agent reads — every command, its
arguments, whether it is destructive and how it is guarded.

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

A scene is a named window layout opened onto a fresh workspace.

```sh
dot scene open chill      dot scene list
dot scene close 3         dot scene close --force 5
```

| Scene | Windows |
|---|---|
| `chill` | YouTube / X / Instagram at 70%, Context Engine chat at 30% |
| `messaging` | WhatsApp and Telegram, 50/50 |

Definitions are **data**, in `config/aerospace/scenes.json` — adding one needs
no code, and it reaches the palette immediately. A workspace running a scene
shows the scene's badge instead of app icons.

Window specs, the close ledger and why windows are moved by id rather than by
switching workspace: [docs/scenes.md](docs/scenes.md).

## The picker

`config/aerospace/src/picker.swift` compiles to a standalone chooser —
auto-focused search, fuzzy filter, arrows, enter. Generic: reads lines on stdin,
prints the choice on stdout.

```sh
ls ~/Projects | PICKER_PROMPT="Open project" ~/.config/aerospace/bin/picker
```

Detail columns, text-input mode, the alternate ⇧↵ action and frecency:
[docs/picker.md](docs/picker.md).

## Updating the Brewfile

```sh
brew bundle dump --file=~/.dotfiles/Brewfile --force
```

Note that a dump is unsorted and uncommented — the checked-in `Brewfile` groups
entries by purpose, so prefer editing it by hand.

## How the bar gets its updates

A launchd agent, `config/aerospace/event-bridge.sh`, subscribes to AeroSpace's
event stream and turns it into SketchyBar triggers, replacing ~40 per-binding
`--trigger` calls. AeroSpace emits nothing when a window *closes*, so
`spaces_watcher` also polls every 5s as a backstop.

Full picture, including which process writes which state file:
[docs/architecture.md](docs/architecture.md).

## Themes

```sh
dot theme list
dot theme set opal-fire
```

Five themes — **Opal White**, **Opal Fire** and **Rosé Pine Dawn** light,
**Opal Black** and **Synthwave** dark. A theme is a directory under `themes/`
holding `colors.sh`, `ghostty.conf` and `meta.json`; the bar's palette and the
terminal's theme are symlinks into the active one, so they can't drift apart.

Open terminal panes repaint **immediately** — `dot theme set` writes OSC escape
sequences to each pane rather than waiting for a config reload, which Ghostty
has no CLI for.

The desktop picture and screen saver follow too, rendered from the theme's own
`colors.sh` at your display's pixel size, so there's no image in the repo:

```sh
dot theme wallpaper            # re-render for the current theme
dot theme wallpaper --show     # what macOS actually has set
dot theme wallpaper --restore  # back to what you had before
```

Accents are darkened from their upstream palettes until text on them clears
4.5:1, and `bin/check-themes.sh` enforces that in the pre-commit hook. Why that
is necessary, and how the wallpaper store is edited safely:
[docs/themes.md](docs/themes.md).

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

## Uninstalling

```sh
./uninstall.sh          # say what would happen
./uninstall.sh --yes    # do it
```

Removes the symlinks, stops the services, unloads the agent and restores the
one global macOS setting `install.sh` changed. Your backups in
`~/.dotfiles-backup/` are left alone — restoring them automatically could
overwrite something you have since changed. Permissions have to be revoked in
System Settings; nothing can do that for you.

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
