# macOS constraints

The platform facts that shaped this setup. Most were discovered the hard way;
none are preferences.

## Permissions can never be automated

TCC grants — **Full Disk Access**, **Accessibility**, **Automation** — cannot be
granted by any process, including an agent. There will always be a manual
boundary. Design for it: `dot doctor` reports what's missing and exactly where
to click, rather than pretending or working around it.

Consequences:

- **Only SketchyBar has Full Disk Access**, so it alone can read the Focus
  database. It publishes state to `~/.local/state/aerospace/focus` for everyone
  else. Anything under AeroSpace has no FDA and must read that file.
- AeroSpace needs Accessibility or it reports success and moves nothing.

## Focus has no CLI

macOS exposes no command to change Focus. The Shortcuts "Set Focus" action is
the only supported route, and Shortcuts can't be created from a script either.
So the user must make a shortcut by hand. `focus_click.sh` accepts either a
`Focus On`/`Focus Off` pair (preferred — the bar picks the direction from state
it already reads) or a single `Toggle Focus`.

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

## AeroSpace quirks

- **It lies about success.** `layout tiling` returns 0 and reports "already
  tiling" for a window `resize` then calls floating. Verify against the world.
- **`resize` refuses floating windows** *and* an accordion root. A split asserts
  both `tiling` and `tiles` first; each is a no-op when already true.
- **`resize width` sets the node width**, which carries half the inner gap — the
  visible window lands `inner_gap/2` narrower than asked. `split-lib.sh` adds it
  back.
- **No geometry in the CLI.** `%{monitor-width}` doesn't parse; monitor size
  comes from `NSScreen`, matched by name.
- **`[exec]` must be the last table in `aerospace.toml`** — a TOML table
  captures every key after it. It sets `PATH`, because GUI apps launched at
  login inherit a bare launchd `PATH` with no Homebrew.
- **`$HOME` expands in `exec-and-forget`** (it runs through a shell); `~` does
  not.

## Ghostty

- `-e <cmd>` opens a window running a command; `--working-directory` sets cwd.
- **No CLI config reload** — `reload_config` is a keybind action (⌘⇧,).
- **Doesn't answer AppleScript**, and ignores `aerospace close` on a window
  whose command has exited. Such a window has to be closed with ⌘W.
