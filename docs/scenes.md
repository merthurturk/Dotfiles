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
| `quit` | quit the apps this scene leaves with no windows; default `false` |

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

## Changing one

```sh
dot scene edit                       # guided, from the launcher
dot scene edit chill --badge GREEN
dot scene edit chill --icon 󰅶 --label "Chill" --ratio 0.7
dot scene edit chill --rename evening
dot scene delete chill               # the definition; no windows are closed
```

From the palette it is one row, *"Edit a scene…"*: pick the scene, pick what to
change, pick the value. `dot scene save` gives every new scene the same default
glyph and colour, and the moment you want to fix that you are looking at the
bar, not at a JSON file.

Icons come from `config/aerospace/scene-icons.tsv`, and every glyph in it is
verified present in Hack Nerd Font — which is what the bar falls back to for
codepoints Berkeley Mono does not carry. A missing glyph renders as an empty
box and you only find out by looking. Pick a colour from `PEACH`, `TEAL`,
`MAUVE`, `BLUE`, `GREEN`; those are the badge palettes each theme defines.

Everything is written to `scenes.local.json`, including changes to the two
scenes this repo ships — one key is enough, because the merge is recursive, so
your override sticks and a `git pull` can still update the rest of the original.

Deleting a shipped scene writes `null` rather than removing the key. A
**tombstone**, because removing the key would only let the shipped scene back
in on the next merge, which reads as the delete having quietly failed. Deleting
a scene that is open forgets the ledger entry: its windows stay exactly where
they are and go back to being ordinary windows.

`dot scene delete` has no launcher row of its own on purpose. It is reached
through `dot scene edit`, where you have already said which scene you mean — a
destructive action one keystroke from the top of a palette is how you delete the
wrong thing.

## Moving one

```sh
dot scene move 5            # take this scene to workspace 5
dot scene move 5 --stay     # without going with it
dot scene move 5 --from 3
```

Only the windows the scene opened travel — anything that has since landed on
that workspace stays put, the same rule that keeps `dot scene close` safe. They
arrive in the order they were sitting in, not the order the scene opened them
in, so a layout you rearranged by hand survives the move. The ledger goes with
them, or `close` would afterwards be aiming at whatever you have since put on
the old workspace.

Two things had to be learned the hard way here, and both come from the same
fact: **AeroSpace gives a hidden workspace no real geometry.** Its windows sit
parked off-screen at whatever size they last had — two windows of a two-window
scene measured 1852pt and 626pt on a 1710pt display while hidden.

So re-tiling into the target spreads the windows evenly and the scene loses its
split (a 60/40 scene came out 840/840), *and* the fix for that cannot be applied
until the workspace is visible. `dot scene move` switches first and resizes
second. With `--stay` there is nothing to aim at, so the split is left alone
rather than aimed at a parked layout — which is what made an earlier version
land a 97/3 split.

## Quitting the apps too

Closing the messaging scene and leaving WhatsApp running is half a job. But
closing the chill scene must never quit Chrome, because Chrome is also the
window you have open on another workspace.

Configuration cannot tell those apart on its own — it does not know what else
you have open at the time. So the split is:

- The **scene** says whether it tidies up after itself: `"quit": true`, off by
  default. Set it from the launcher under *Edit a scene… → Quit apps on close*,
  or with `dot scene edit messaging --quit`.
- The **decision about each app** is made by looking. An app is quit only if
  closing the scene left it with **no windows at all**, checked against both
  AeroSpace's list and `CGWindowListCopyWindowInfo` — either one saying "still
  open" leaves the app alone.

That gets both cases right without being told, and it stays right on the day
you happen to have a second WhatsApp window somewhere. Verified: a scene with
`app:Ghostty` and `chrome:` quit Ghostty and left Chrome running, because Chrome
had a window on another workspace.

`dot scene close --quit` and `--no-quit` override the scene's setting for one
close. Apps are quit by bundle id through AppleScript, which asks for
Automation permission the first time for each app; if you decline, the close
still happens and the app is left running with a note saying so.

The palette says which scenes do this: *"Close scene: messaging · workspace 4 —
and quits its apps"*.

## Splits and hidden workspaces

`dot window reflow` re-applies every open scene's declared ratio — it runs
automatically when the displays change, because `resize width` takes absolute
points and a split computed on a 1710pt laptop is wrong on a 2560pt monitor.

It can only do that to a workspace you are looking at. The others are queued in
`~/.local/state/aerospace/reflow-pending` and drained by the bar's workspace
plugin as you arrive on them, which is the first moment their layout is real.
You never see it happen.

`dot window geometry` shows you the difference, and is the tool to reach for
whenever a split looks wrong:

```
id       ws        x      y   width  height  app
137387   1         10     50    1690    1051  T3 Code (Alpha)
136980   2   ·   1709   1066    1690    1051  Google Chrome
  (· = on a hidden workspace: parked, not laid out)
```

## Bouncing between two

```sh
dot scene last
```

Goes back to the scene you were in before this one — `⌥tab` for scenes, which
is not the same as `⌥tab` for workspaces once you have visited an ordinary
workspace in between. It is in the palette; to give it a key:

```toml
ctrl-alt-tab = 'exec-and-forget $HOME/.local/bin/dot scene last'
```

The history is two lines in `~/.local/state/aerospace/scene-focus`, written by
the bar's workspace plugin — which already knows the focused workspace and
already has the ledger in memory, so this costs no extra process on the repaint
path. The ledger, not the history, decides whether the scene is still real: a
closed scene leaves its entry behind and is skipped.

## After a restart

```sh
dot scene restore          # put back what was open before the reboot
dot scene restore --list
dot scene restore --forget
```

An offer, not an action. Nothing runs at login and no agent is installed: the
row appears in the launcher when there is something to put back, and stops
appearing once you have taken it or dismissed it. Replaying at login would mean
deciding, while you are not watching, that an empty desktop should fill itself.

How it knows: a ledger written **before the current boot** describes the
previous session — every window in it went away with the machine. The first
thing to touch the ledger after a restart moves it aside to `scenes-previous`
rather than letting the next prune drop the lot. The test is the boot clock and
not "are its windows gone", because that is also exactly what closing a scene
by hand looks like.

Each scene asks for the workspace it was on and gets it only if that workspace
is empty, so a restore can never land on top of anything. Scenes you have since
deleted, and scenes that are already open, are skipped.

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

A `null` there is a tombstone — a shipped scene you deleted:

```json
{ "messaging": null }
```

## Adding one

Arrange a workspace the way you want it, then:

```
dot scene save work
```

It writes the spec into `scenes.local.json` and the scene is immediately
openable. From the palette it is *"Save this workspace as a scene…"*, which
asks for the name. Options: `--ratio` (default `0.6`), `--icon`, `--badge`,
`--label`, and `--force` to replace an existing scene — without it, saving over
one refuses.

What it captures:

| open window | saved as |
|---|---|
| any native app | `app:<App Name>` |
| a Chrome window | `chrome:<every tab's URL>` |

Windows are saved left to right, which is the order a scene reopens them in.

Two things it does not guess. A Chrome `--app` window looks exactly like a
one-tab window over AppleScript, so it is saved as `chrome:` — change it to
`chrome-app:` by hand if you wanted the stripped-down panel. And the split
ratio is not measured: AeroSpace does not report window frames, and reading
them out of Accessibility costs a permission prompt and the best part of a
second for a number you can type. Pass `--ratio`, or edit it after.

You can also write an entry into `scenes.json` by hand, or into
`scenes.local.json` to keep it to yourself. Either reaches the palette
immediately — `dot scene open --describe` enumerates the file. No code, and no
second registration.

To bind it to a key, add to `aerospace.toml`:

```toml
alt-shift-m = 'exec-and-forget $HOME/.local/bin/dot scene open messaging'
```

The palette's keybinding hint picks it up automatically.
