# dotfiles

macOS setup: [AeroSpace](https://nikitabobko.github.io/AeroSpace/) tiling driving
[SketchyBar](https://felixkratz.github.io/SketchyBar/), themed
[Catppuccin Latte](https://github.com/catppuccin/catppuccin) (light). Ghostty
uses the same palette, so terminal and bar are one surface.

## Install on a new Mac

```sh
git clone https://github.com/merthurturk/Dotfiles.git ~/.dotfiles
~/.dotfiles/install.sh
```

`install.sh` installs Homebrew and the `Brewfile`, symlinks every config,
compiles the Swift picker, starts the services, and prints the GUI-only steps
that remain. It is re-runnable: anything it would overwrite is moved to
`~/.dotfiles-backup/<timestamp>/` first.

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
| `⌥⇧\` | `balance-sizes` — reset the workspace to even splits |
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

The palette only works as a discovery surface if it stays complete, so **every
new keybinding or bar button must be registered in
`config/aerospace/launcher.sh`**, and removed ones must be deregistered:

```bash
add "<label>" "<detail: its keybinding>" "<command>"
```

Two tools enforce and inspect this:

```sh
bin/check-launcher.sh      # fails if a binding or bar button has no entry
launcher.sh --dry-run      # print the menu without a GUI
```

`CLAUDE.md` carries the full contract, including for AI sessions working here.

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

## Notes worth keeping

Things that cost real time to work out, recorded so they don't have to be
rediscovered:

- **macOS ships bash 3.2**, which has no associative arrays — string subscripts
  silently collapse to index `0`. Scripts here group with `awk` instead.
- **Notched displays reserve 38pt** at the top even with the menu bar hidden, and
  AeroSpace measures `gaps.outer.top` from the *visible* frame. Hence the
  per-monitor gap: `[{ monitor."built-in" = 12 }, 50]`.
- **macOS 26 draws window corners as squircles** (superellipse n≈4.5). SketchyBar
  draws circular corners, so 16pt is the matching radius. Nested radii follow
  `inner = outer - inset`, with the inset kept *uniform* on all four sides.
- **`resize width` sets the node width**, which carries half the inner gap — the
  visible window lands `inner_gap/2` narrower than asked. `split-lib.sh` adds it
  back.
- **`[exec]` must be the last table in `aerospace.toml`** — a TOML table captures
  every key after it. It sets `PATH` so bindings can find Homebrew binaries,
  since GUI apps launched at login inherit a bare launchd `PATH`.
- **An empty workspace can't hold focus.** `open -a` activates the app, which
  moves focus; with no window on the workspace AeroSpace falls back to the
  previously focused window, so new windows are born on the *old* workspace.
  `scene.sh` therefore opens windows wherever they land and moves them by
  window id, rather than switching first and trusting focus to stay.
- **Only sketchybar has Full Disk Access**, so it's the only process that can
  read the Focus database. `focus.sh` publishes what it reads to
  `~/.local/state/aerospace/focus`; the launcher (run by AeroSpace, which has no
  FDA) reads that file instead of the database.
- **App names can carry invisible characters.** WhatsApp reports as
  `\u200eWhatsApp` (a leading left-to-right mark), so `$2 == "WhatsApp"` never
  matches and callers wrongly conclude it isn't running. `find_app_window` in
  `split-lib.sh` compares with non-alphanumerics stripped.
- **MediaRemote was restricted in macOS 15.4**, so SketchyBar's `media_change`
  event is unreliable; the now-playing chip uses AppleScript.
- No `/Users/<name>` or `/opt/homebrew` paths in the configs — `$HOME` and the
  `[exec]` `PATH` keep them portable across machines and CPU architectures.
