# macOS constraints

The platform facts that shaped this setup. Most were discovered the hard way;
none are preferences.

## Permissions can never be automated

TCC grants — **Full Disk Access**, **Accessibility**, **Automation** — cannot be
granted by any process, including an agent. There will always be a manual
boundary. Design for it: `dot doctor` reports what's missing and exactly where
to click, rather than pretending or working around it.

In practice that means AeroSpace needs Accessibility, or it reports success and
moves nothing.

Nothing here needs **Full Disk Access** any more. A Focus indicator used to,
because `~/Library/DoNotDisturb/DB` is TCC-protected, and it forced an awkward
arrangement: SketchyBar held the grant and published state to a file for
everything else to read. Removing the feature removed the requirement. The
wallpaper store, despite living under Application Support, is readable without
it.

## The wallpaper store has no API for half of itself

macOS 14 replaced the desktop-picture defaults with one store holding both the
desktop image and the screen saver, per display and per space:

```
~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
```

`NSWorkspace.setDesktopImageURL` writes the desktop half. **Nothing public
writes the screen saver half**, so `dot theme wallpaper` edits the store — but
it never builds an entry by hand: it copies the desktop entry macOS itself just
wrote, so the schema is always the OS's own. The whole store is copied to
`~/.local/state/aerospace/wallpaper/Index.plist.before-dot` before the first
edit, and `--restore` puts it back.

Three things that cost real time here:

- **The API lies, in both directions.** `setDesktopImageURL` returns success
  whether or not anything changed, and `desktopImageURL(for:)` goes on
  reporting `DefaultDesktop.heic` after a successful change. The store on disk
  is the only truth; `dot theme wallpaper --show` prints it.
- **WallpaperAgent writes the store asynchronously**, a moment after the call
  returns. Reading it too early gets the old contents, and *writing* it too
  early loses the change — which is how the screen saver first ended up
  pointing at a stale image. The capability waits for the desktop entry to
  appear before touching anything, then restarts the agent so it reloads the
  file rather than overwriting it from memory.
- **Entries survive their displays.** The store accumulates a node per display
  UUID ever attached, and the API only reaches the connected ones, so a
  disconnected monitor keeps serving the image it last saw. The capability
  copies one canonical choice over every node, present or not.

A still image is a valid screen saver as far as the store is concerned — the
screen simply keeps showing the wallpaper. The alternatives were not close:
every built-in module (Drift, Flurry, Arabesque, Hello, Shell) is a dark
animation, and none of them take a colour from the theme.

## Window shadows can't be turned off from here

macOS exposes no setting for the drop shadow it draws on every window, and
AeroSpace has no key for it — `aerospace config --all-keys` has neither
`shadow` nor `border`. SkyLight does have the state, and it is readable:

```c
SLSGetWindowShadowAndRimParameters(cid, wid, &std_dev, &density, &x, &y, ...)
```

An ordinary macOS 26 window reads `std_dev=32.94, density=0.4, offset=(0,18)`.

**Writing it does nothing.** Three separate routes were tried against that
getter, on windows belonging to Chrome, Ghostty, Telegram and System Settings:

| Call | Result | Parameters after |
|---|---|---|
| `SLSWindowSetShadowProperties(wid, {density: 0})` | returns 0 | unchanged |
| `SLSSetWindowShadowParameters(cid, wid, 0, 0, 0, 0)` | returns 0 | unchanged |
| `SLSTransactionSetWindow[System]ShadowProperties` + commit | returns 0 | unchanged |

Every one of them reports success. This is the sharpest example in the whole
setup of why **exit codes are not verification** — without the getter, all
three look like they worked, and the only contrary evidence is that the screen
doesn't change.

The one process whose windows *do* read `density=0.0` is `borders`, on windows
it owns itself. Shadow writes appear to be honoured only for a connection's own
windows, which is consistent with yabai needing its scripting addition — an
injection into Dock.app that requires SIP to be partially disabled — to manage
shadows for other applications.

So the shadow stays, and this setup outlines instead. The two shadows that
*aren't* window-server state are off: the bar's (`shadow=off` in
`sketchybarrc`) and the one macOS bakes into window screenshots
(`com.apple.screencapture disable-shadow`, set by `install.sh`). `dot doctor`
checks both.

## awk is not gawk

macOS ships the one-true-awk, so `strtonum` doesn't exist —
`bin/check-themes.sh` parses hex by hand with `index()` into a digit string.
Same family of surprise as bash 3.2: the script looks portable, and fails only
on the machine it was written for.

## Ghostty has no IPC on macOS

`ghostty +new-window` answers "not supported on this platform", and there is no
reload action in the CLI at all — `reload_config` is a keybind and nothing
else. Anything outside Ghostty that wants it to re-read its config has to press
a key.

The way out isn't a macOS API at all: it's the terminal protocol. OSC 10, 11,
12 and 4 set foreground, background, cursor and palette on a live pane, and
writing them to the pane's tty repaints it instantly — no permission, no
keystroke, no focus change. `dot theme set` does that for every open pane.

Two other things about it, learned the hard way: `-e <cmd>` opens a window
running a command and `--working-directory` sets its cwd, but Ghostty **doesn't
answer AppleScript** and ignores `aerospace close` on a window whose command has
already exited — those have to be closed with ⌘W.

The approach this replaced registered a global hotkey for `reload_config` and
pressed it from outside. Two things sank it: a running Ghostty only knows the
keybinds it launched with, so the chord did nothing until the config had
already been reloaded by hand, and the check gating it was `pgrep` — see
below.

### Ghostty's CLI is inside the app bundle

`ghostty` lives at `/Applications/Ghostty.app/Contents/MacOS/ghostty`, and is
on `PATH` only because its shell integration puts it there for interactive
shells. Nothing AeroSpace execs has it, so `ghostty +show-config` worked
perfectly from a terminal and failed from the palette. `_lib.sh` resolves it
once, with the bundle path as the fallback.

### pgrep cannot see an app bundle's process

`pgrep` lists 658 processes on this machine and Ghostty is in none of them,
under any name:

```sh
pgrep -x ghostty      # 0 matches
pgrep ghostty         # 0 matches
pgrep -f ghostty      # 0 matches
pgrep -f Ghostty.app  # 0 matches
ps -Ao comm= | grep -i 'Ghostty\.app'   # found, pid and all
```

Meanwhile `ps -p <pid> -o comm=` prints `/Applications/Gh` and `-o ucomm=`
prints `ghostty` — the same process reported three different ways by three
tools. (The `/Applications/Gh` is `ps` truncating a display column, not the
kernel truncating a name; `ps -Ao comm=` prints the path in full.)

I could not establish *why* pgrep misses it, so treat this as measured
behaviour rather than an explained one: **match app-bundle processes with
`ps -Ao comm=`, not pgrep.** The reload above was gated on `pgrep -x ghostty`,
which answered "not running" for a Ghostty in the foreground, so `dot theme
set` skipped the work and reported success. Same family as WhatsApp's invisible
character: matching a process or app by name is harder than it looks.

## The light/dark appearance has no CLI

Like Focus, macOS exposes no command for it. The supported route is System
Events over AppleScript:

```sh
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
```

which needs **Automation** permission the first time it runs. `dot theme set`
uses it to match the system to the theme's `appearance`, and reads the value
back afterwards rather than trusting the call.

## bash is 3.2

`/bin/bash` is 3.2 from 2007. **No associative arrays**: `declare -A` fails and
string subscripts silently collapse to index `0`. A pill-rendering bug hid here
for a while — numeric workspaces worked by accident while every letter
workspace shared one bucket. Group with `awk`. Test with `/bin/bash`, never a
Homebrew bash.

## Window corners are squircles

macOS 26 draws window corners as superellipses, not circular arcs. Measured off
a real window by decoding a screenshot: superellipse fit n≈4.55, **6× better**
than the circular fit. SketchyBar draws circular corners, so **16pt** is the
value that visually matches.

The method was validated against a known control first — the bar's own corner,
set to 10pt, recovered as 11.00pt. An earlier attempt recovered 18pt for that
same 10pt corner because the threshold was catching the drop shadow. Measure,
then check the measurement against something you already know.

## Notched displays reserve 38pt

Even with the menu bar auto-hidden, `NSScreen.visibleFrame` on a notched
built-in excludes 38pt (`safeAreaInsets.top`). AeroSpace measures
`gaps.outer.top` from the *visible* frame, so the built-in needs ~38 less than
an external monitor — hence

```toml
gaps.outer.top = [{ monitor."built-in" = 12 }, 50]
```

## App names can carry invisible characters

WhatsApp reports as `‎WhatsApp` — a leading left-to-right mark. `$2 ==
"WhatsApp"` never matches, so callers conclude it isn't running and then hang
waiting for a window that already exists. `find_app_window` in `split-lib.sh`
compares with non-alphanumerics stripped.

## MediaRemote was restricted in 15.4

SketchyBar's `media_change` event is built on it and can't be relied on. The
now-playing chip reads Apple Music over AppleScript instead, polling on a 5s
`update_freq`, with `media_change` still subscribed as a bonus trigger.

## Native fullscreen loses the layout

macOS native fullscreen moves the window to a **Space of its own**. AeroSpace
has to re-adopt it on the way back, and the tiling order is not reliably what it
was — intermittently, windows come back in a different order.

`aerospace fullscreen` is a different thing: the window fills its workspace and
never leaves it, so the layout is untouched. Verified — order identical before
and after.

`ctrl-cmd-f` is therefore bound to `fullscreen`, taking over the shortcut macOS
uses for the native one. The green traffic-light button still does native
fullscreen when that is genuinely what you want (a video, say).

## AeroSpace quirks

- **It lies about success.** `layout tiling` returns 0 and reports "already
  tiling" for a window `resize` then calls floating. Verify against the world.
- **`resize` refuses floating windows** *and* an accordion root. A split asserts
  both `tiling` and `tiles` first; each is a no-op when already true.
- **`resize width` sets the node width**, which carries half the inner gap — the
  visible window lands `inner_gap/2` narrower than asked. `split-lib.sh` adds it
  back. It is also **absolute points**, so a split is wrong on a different-sized
  display and nothing re-flows it; `dot window reflow` restores the ratio.
- **A hidden workspace has no geometry.** Its windows sit parked off-screen at
  whatever size they last had — two windows of a 60/40 scene measured 1852pt
  and 626pt on a 1710pt display while hidden. So a `resize` aimed at one is
  aimed at nothing. This file used to claim the opposite, which is why
  `dot window reflow` spent a long time appearing to work; it now reflows the
  visible workspaces and queues the rest for the moment you arrive on them.
  `dot window geometry` is what made this visible.
- **No geometry in the CLI.** `%{monitor-width}` doesn't parse; monitor size
  comes from `NSScreen`, matched by name. Window frames come from
  `CGWindowListCopyWindowInfo`, which needs no permission and whose
  `kCGWindowNumber` is the same id AeroSpace uses.
- **`[exec]` must be the last table in `aerospace.toml`** — a TOML table
  captures every key after it. It sets `PATH`, because GUI apps launched at
  login inherit a bare launchd `PATH` with no Homebrew.
- **`$HOME` expands in `exec-and-forget`** (it runs through a shell); `~` does
  not.
- **An empty workspace can't hold focus.** Activating an app moves focus, and
  with no window to hold it AeroSpace falls back to the previously focused
  window — so a new window is born on the *old* workspace. Capture the target
  before opening anything and move windows by id; never switch first and trust
  focus to stay. This has caused three separate bugs: scenes opening on the
  wrong workspace, `dot ai` doing the same, and `chrome-split` waiting for a
  window on a workspace it was no longer on.
