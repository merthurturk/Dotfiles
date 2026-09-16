# Architecture

Five moving parts and three agents, plus a repo that owns all of their config.

`borders` is the quiet one: it takes no commands and publishes no state, it
just reads `bordersrc` and outlines whatever AeroSpace put on screen.

```
        AeroSpace  ──events──▶  event-bridge  ──triggers──▶  SketchyBar
      (tiling WM)                (launchd)                    (the bar)
           ▲                                                      │
           │ commands                                    scripts   │ publishes
           │                                                      ▼
          dot  ◀──── palette / keys / bar buttons ────  ~/.local/state/aerospace/
     (the surface)                                     (scenes, next event, …)
                                                              ▲
                              theme-auto  ────────────────────┤
                              calendar    ────────────────────┘
                              (launchd, resident)
```

The two resident agents never talk to the bar. They **publish files**, and the
bar reads them — which is what keeps the repaint path free of permissions,
AppleScript and network calls. See "Why the agents publish files".

## Who owns what

| Part | Role |
|---|---|
| **AeroSpace** | tiles windows, owns workspaces and keybindings |
| **event-bridge** | a launchd agent translating AeroSpace events into bar triggers |
| **SketchyBar** | draws the bar |
| **borders** | draws the outline around each window (JankyBorders) |
| **dot** | the command surface everything else calls into |
| **theme-auto** | a resident agent that switches the theme at sunrise and sunset |
| **calendar** | a resident agent that publishes the next event and today, from EventKit |

## Why the bridge exists

`aerospace.toml` used to carry ~40 copies of
`exec-and-forget sketchybar --trigger …` — one on every workspace-move binding,
plus the workspace-change callback, plus one per service-mode binding. Every new
binding had to remember to bolt one on.

`config/aerospace/event-bridge.sh` subscribes to AeroSpace's event stream once
and does it centrally. It also catches `window-detected`, which no binding could
provide: a window opening without its app becoming frontmost was invisible.

**AeroSpace's complete event list** — there is nothing else to subscribe to:

```
focus-changed   focused-monitor-changed   focused-workspace-changed
mode-changed    window-detected           binding-triggered
```

Note what's missing: **no window-closed, no window-moved**. Moving the *focused*
window emits `focus-changed` as a side effect, which covers the common case, but
closing a window and moving one by id from a script emit nothing at all. That's
why `spaces_watcher` in `sketchybarrc` also polls every 5s. The poll is the
backstop, not the mechanism.

The agent runs under launchd with `KeepAlive`, because the event stream ends
whenever AeroSpace restarts.

`theme-auto` and `calendar` are resident for different reasons: the first
sleeps until the next sunrise or sunset rather than polling 144 times a day,
and the second waits on `EKEventStoreChanged` so an edit in Calendar reaches
the bar at once.

It pipes the stream through **one long-lived `jq`** rather than parsing each
line with its own; `focus-changed` fires constantly, and a process spawn per
event is not free.

## Why the agents publish files

The bar repaints on every workspace switch and the palette opens on every
`⌥space`, so neither can afford to ask an expensive question. Two of the
answers they need are very expensive:

- **Calendars** need a TCC grant, and TCC attributes a permission to the
  process *responsible* for launching one — so the same helper run by
  SketchyBar, by a terminal and by the launcher would be three identities
  needing three grants. A launchd agent is its own responsible process, so the
  grant belongs to one bundle and nothing else needs one.
- **Now playing** is an AppleScript round-trip to Music, ~130ms. The bar was
  already paying it for the chip; `dot music focus` was paying it *again* on
  every palette open, which made it the slowest descriptor of all thirty.

So the rule: whatever is slow or privileged is asked once, by whoever owns it,
and written to a file. Everything downstream reads the file.

## Sourceable libraries

Not executables. Four files exist to be `source`d, so asking their owner costs
nothing — which is what let the merge, the ledger and the profile list each
collapse to a single implementation instead of a copy per caller.

| File | Owns |
|---|---|
| `config/aerospace/scenes-lib.sh` | the `scenes.json` + `scenes.local.json` merge, its tombstones, and the caches derived from it |
| `config/aerospace/ledger-lib.sh` | the open-scene ledger: its format, its pruning, and its most-recently-used order |
| `config/aerospace/split-lib.sh` | window sizing, gaps, and monitor width |
| `config/aerospace/chrome-lib.sh` | Chrome profiles and asking which one |

`libexec/dot/_lib.sh` is the fifth, shared by every capability; it sources the
first, second and fourth **on first use**, because two thirds of the
capabilities never ask about a scene and parsing the files in all of them cost
more than it saved in the few that do.

## State, and who writes it

Everything lives in `~/.local/state/aerospace/` — none of it is in the repo.

| File | Written by | Read by |
|---|---|---|
| `scenes` | `ledger-lib.sh` | `dot scene *`, the workspace pills, `dot scene last` |
| `scenes-previous` | `ledger-lib.sh`, at the first touch after a reboot | `dot scene restore` |
| `scenes-merged.json` · `scenes-defs.tsv` · `scenes-summary.tsv` | `scenes-lib.sh` | the launcher, the bar — caches, rebuilt when either source file or the lib is newer |
| `next-event.tsv` · `agenda.tsv` | the calendar agent | the clock chip, `dot calendar agenda` |
| `now-playing` | the bar's `music.sh` | `dot music focus` (instead of its own AppleScript) |
| `theme` | `dot theme set` | `dot theme list`, `doctor` |
| `theme-auto` · `sun` | `dot theme auto` | the theme-auto agent — which themes, and the sun times, cached per day |
| `log` | `logging.sh` | you, `doctor` |
| `audit.log` | `dot` capabilities | you |
| `*.err` | launchd, per agent | you, `doctor` |
| `picker-*.history` | the picker | the picker (frecency) |
| `fonts` | `fonts.sh` | every plugin that sets a font (a ~70ms probe, cached) |
| `monitor-width/` | `split-lib.sh` | split sizing (a ~180ms AppKit query, cached per monitor) |
| `wallpaper/*.png` | `dot theme wallpaper` | macOS (the wallpaper store points at it) |
| `wallpaper/Index.plist.before-dot` | `dot theme wallpaper`, once | `dot theme wallpaper --restore` |

## Symlinks

`install.sh` links the repo into place, so editing either path edits one file:

```
aerospace.toml              -> ~/.aerospace.toml
config/<name>/              -> ~/.config/<name>/
bin/dot                     -> ~/.local/bin/dot
launchd/*.plist             -> ~/Library/LaunchAgents/   (copied, $HOME substituted)
```

Within the repo, two more point at the active theme:

```
config/sketchybar/colors.sh -> themes/<active>/colors.sh
config/ghostty/theme.conf   -> themes/<active>/ghostty.conf
```

## Read next

- [capabilities.md](capabilities.md) — the `dot` surface and how to extend it
- [bar.md](bar.md) — SketchyBar items, plugins and events
- [scenes.md](scenes.md) · [themes.md](themes.md) · [picker.md](picker.md)
- [macos.md](macos.md) — the platform constraints that shaped all of this
- [troubleshooting.md](troubleshooting.md)
