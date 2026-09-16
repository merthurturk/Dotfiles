# The bar

SketchyBar, configured by `config/sketchybar/sketchybarrc`. Plugins live in
`config/sketchybar/plugins/`.

## Adding an item

Every item is a file, sourced from every directory on `SKETCHY_ITEM_PATH`:

```
~/.config/dot/sketchybar/items : <repo>/config/sketchybar/items
```

Files are sourced in **filename order across all directories**, so a `55-` of
yours runs between the shipped `50-` and `60-`; directory order decides which
file wins when two share a name. `sketchybarrc` keeps the bar, the defaults and
the geometry — what is *in* the bar is a directory.

Everything is already in scope: `$PLUGIN_DIR`, the geometry, every colour from
`colors.sh`, every font from `fonts.sh`. To join an existing pill rather than
float alone, append your item to the bracket variable:

```sh
sketchybar --add item hello right --set hello label="mine"
BRACKET_status="$BRACKET_status hello"
```

Brackets are collected as items declare themselves and materialised once at the
end, which is what lets an item in one file join a pill declared in another.

## Items, left to right

Deliberately not listed here. `config/sketchybar/sketchybarrc` is the list, and
a copy of it in prose is a second registry to keep in step — which this one was
not: it described four items the bar no longer had in that arrangement.

```sh
sketchybar --query bar | jq -r '.items[]'    # what is actually there
```

## One script repaints all the pills

`spaces_watcher` is a hidden item whose script is `aerospace.sh`. It rebuilds
every `space.*` pill in **one** batched `sketchybar --set` call, from a single
`aerospace list-windows` query. Individual pills have no update logic.

It runs on `aerospace_workspace_change` (fired by the event bridge),
`front_app_switched`, `space_windows_change`, `display_change`, and a 5s poll.

**It is on the latency path for every workspace switch**, so it is deliberately
subprocess-frugal: everything is gathered once and a single `awk` pass emits the
entire argument list. Keep it that way — an earlier version looped in shell and
forked `awk` plus `sort` per workspace, costing 270ms of visible lag.

`fonts.sh` is cached for the same reason: its Berkeley Mono presence check asks
AppKit and costs ~70ms. `sketchybarrc` clears the cache on reload so a newly
installed font is still picked up.

## Geometry is derived, not hardcoded

```
BAR_HEIGHT=36   BAR_RADIUS=16
PILL_HEIGHT=26  PILL_INSET=(36-26)/2=5   PILL_RADIUS=16-5=11
ITEM_PADDING=4  BAR_PADDING=PILL_INSET-ITEM_PADDING=1
```

Two rules produced those numbers:

**Concentric rounding.** A nested radius is the outer radius minus the gap
between the edges, so the curves stay parallel.

**The inset must be uniform.** Chips originally sat 5pt from the top and 12pt
from the sides, which broke the concentric relationship and read as wrong. A
chip's distance from the bar edge is `bar padding + item padding`, so the bar's
own padding is whatever is left after the per-item padding that spaces chips
from each other.

16pt was measured off a real macOS 26 window, not guessed — see
[macos.md](macos.md#window-corners-are-squircles).

## Fonts

`config/sketchybar/fonts.sh`, shared with the plugins that set fonts themselves.

- **Text** is Berkeley Mono — bar labels, picker, terminal.
- **Icon glyphs** are Hack Nerd Font, because Berkeley Mono has no Nerd glyphs.
- **App glyphs** in the pills are `sketchybar-app-font`, via `icon_map.sh`.

The trap: every Berkeley Mono weight installs as its **own family** with style
`Regular`. `Berkeley Mono:Bold:13.0` silently falls back to the system font —
it looks fine and renders no Berkeley at all. Weight comes from the family name:
`Berkeley Mono Bold SemiCondensed:Regular`.

Berkeley Mono is commercial and can't ship here, so `fonts.sh` probes for it and
falls back to Hack.

## Date, time and what is next

Two items sharing the status bracket, so they read as one pill:

```
󰅐 Wed 16 Sep  06:47                              nothing on
󰃰 Wed 16 Sep  06:47  →  13:00 Relote Work Session later today
󰃰 Wed 16 Sep  06:47  →  40m LTVplus Weekly       within the hour
󰃰 Wed 16 Sep  06:47  →  3m Standup               imminent, icon amber
󰃰 Wed 16 Sep  06:47  →  now Standup              running, icon green
```

This was two chips, and they were cut along the wrong seam: the clock carried
the *date* while the calendar chip carried a *time*. Both are "when". Now the
whole of "when" is one sentence and the status group keeps the machine's own
state — volume, battery — beside it.

**The clock is bold and full-strength; the event is dim.** That is why it is
two items rather than one label — sketchybar styles an item, not part of a
label, and with a single label the eye went to the *meeting* time and read it
as the current time.

The icon is the state. A clock when there is nothing ahead, a calendar when
there is, and its colour says how soon. Only the **title** truncates, never the
date or the time: the part that is always true should not be the part that gets
cut. An all-day event is not "what is next" at a time, so it does not displace
the clock.

Clicking opens today in the picker — which does two more things.

**Joining.** Every event that has a call shows `󰕧`, and choosing it asks which
Chrome profile and opens the link there rather than opening Calendar. It asks
because a meeting link is only signed in under one account, and letting Chrome
choose means landing on the wrong one and being invited to switch — the same
reason `dot window split` asks. Profiles come from
`config/aerospace/chrome-lib.sh`, which `window split` shares, so the two can
never disagree about which profile is which. Google and Zoom both bury that link in the event
*notes* and leave `url` empty — every event on this machine did — so the helper
searches `url`, `location` and `notes`, in that order, for Meet, Zoom, Teams,
Webex, Jitsi and Whereby. The picker is shown the service name; the URL travels
in a third column it never sees, because a raw meeting link is forty characters
of noise in a column meant to be read at a glance.

**World clocks**, in the header rather than as rows — they are context for the
list, not things you can choose. Edit `config/aerospace/world-clocks.tsv`:

```
San Francisco	America/Los_Angeles
New York	America/New_York
```

Your own time is already in the bar, so this is for the people you work with.

The events come from **EventKit**, the local store macOS Calendar syncs into.
That is the whole reason for the route: a Google account added under *System
Settings > Internet Accounts* appears there with no OAuth flow, no client
secret in this repo, and no refresh token to keep alive. The alternative —
talking to the Google Calendar API — would mean every person who forked this
creating their own Google Cloud project.

**Not AppleScript.** `tell application "Calendar" to get every event whose start
date ≥ …` takes **five seconds** on this machine; EventKit answers in 40ms off a
local database. The music chip can afford a 130ms AppleScript round trip once
every five seconds, and this could not.

### Why it is an agent, and why the helper is a .app

Both come from the same fact: **TCC attributes a permission to the process
*responsible* for launching one.** The helper run by SketchyBar is asking with
SketchyBar's grant; the same binary run from Ghostty is asking with Ghostty's.
Three callers, three identities, three different answers — and a `writeOnly`
grant on one of them looks exactly like success until every read comes back
empty.

So the helper does not get run by the bar at all. `launchd/sh.dotfiles.calendar`
runs it resident, where it is its own responsible process, and it publishes two
files into `~/.local/state/aerospace/`:

| | |
|---|---|
| `next-event.tsv` | one row, or empty. What the chip draws |
| `agenda.tsv` | today. What `dot calendar agenda` reads |

The bar and the launcher only read those, so the repaint path forks nothing and
neither needs a permission of its own. It waits on `EKEventStoreChanged`, so an
edit in Calendar shows up at once, with a 60-second timer as the backstop —
events become "now" through the passage of time, which fires no notification.

`DotCalendar.app` is a bundle rather than a bare binary like the picker and the
geometry helper because **the Calendars pane in System Settings has no "+"
button**: an app only appears there once it has asked. The bundle gives it a
name in that list you can recognise, *dot calendar*.

Three things learned building it, all of which cost time:

`authorizationStatus` and `requestFullAccessToEvents` disagree. A process can
read a status of `fullAccess` and still get `false` back from a request, and
then refuse to do work it was entitled to do. Check the status first and only
ask when it is `notDetermined`.

`EKAuthorizationStatus` is easy to misread: **3 is `fullAccess`, 4 is
`writeOnly`**. An "Add Events Only" grant looks like success to anyone who
assumes the last constant is the best one, and then every read comes back
empty.

macOS will not prompt when there are no calendar accounts configured at all —
it returns `granted=false` with no error and records nothing. Add the account
first, then ask. The first attempt here looked like a permission the user had
refused, and was actually a question never put to them.

## y_offset belongs with the font

`sketchybarrc` sets each workspace pill up once, including `label.y_offset=-1`,
which is tuned for the app-glyph font. But `plugins/aerospace.sh` swaps
`label.font` per state — app glyphs on an ordinary workspace, text on one
running a scene — and for a long time it left the offset behind. Scene text sat
1.75pt below the workspace number beside it.

Measured off a screenshot rather than guessed: the ink centre of "DEV" was at
51.5 where the "1" next to it was at 48.0, and the pill centre at 47.5. Setting
`label.y_offset` alongside `label.font` puts all three within half a pixel.

Anything the plugin varies per state has to be set by the plugin. A property
set once at creation is a property tuned for exactly one of the states.

## Colour

`config/sketchybar/colors.sh` is a **symlink into the active theme** — see
[themes.md](themes.md). Semantic names (`WS_ACTIVE_BG`, `GROUP_BG`,
`BADGE_PEACH_DEEP`) are separate from raw palette values, so plugins never name
a colour directly.

## Hover

`hover.sh` gives clickable items a blue ring on `mouse.entered`. It changes
**only the border**, never the fill: these items have state-driven backgrounds,
so a ring reads correctly over all of them without knowing which state it is
interrupting. On exit the item's own updater re-runs, restoring the right state
colour rather than a hardcoded one.

SketchyBar has no cursor property — the pointer can't become a hand.
