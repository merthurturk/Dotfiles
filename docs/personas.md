# Who this is for

Four people this is built for, what each of them actually does with it, and —
honestly — where it still makes them work harder than it should.

These aren't marketing sketches. Each use case below maps to a capability that
exists, and each gap is something verified missing rather than imagined.

---

## 1. Never used a tiling window manager

*"My screen is a mess of overlapping windows and I've heard tiling helps, but
i3 configs look like homework."*

**What they need:** it to work and look right immediately, and to be able to
find things without reading anything.

| They want to… | They do |
|---|---|
| Install it | `git clone` + `./install.sh` |
| Find out what it can do | **⌥space** — everything, searchable, each row showing its key |
| Learn the shortcuts | the same palette; the detail column *is* the cheat sheet |
| Know if something's broken | `dot doctor` — and it names the fix |
| Change how it looks | `dot theme set` — bar, terminal and wallpaper together |
| Back out | `./uninstall.sh` (dry run by default) |

**Why the palette matters most for them.** They will not remember `⌥⇧↩`. They
will remember one chord, and everything is behind it — including the names of
the chords, so the palette teaches itself out of use.

**Where it's still hard:**

- **No screenshots in the readme.** For a project whose whole point is how it
  looks, that's the biggest adoption gap there is.
- **Permissions are unavoidable and awkward.** Full Disk Access and
  Accessibility need System Settings, twice, and no installer can do it.
  `dot doctor` at least tells them exactly which and where.
- **Berkeley Mono is commercial.** It falls back to Hack automatically, so
  nothing breaks — but the screenshots they'll see won't be quite what they get.

---

## 2. Already tiles, wants the bar

*"I've had AeroSpace for months. I want that bar, and the scenes, without
losing my keybindings."*

**What they need:** to take parts, not the whole, and to trust it won't
clobber a config they've tuned.

| They want to… | They do |
|---|---|
| Keep their own `aerospace.toml` | `install.sh` moves theirs to `~/.dotfiles-backup/<timestamp>/` first, never overwrites |
| Understand the wiring before trusting it | [architecture.md](architecture.md) — one page, four parts |
| Add their own commands | one file in `libexec/dot/`, no second registration |
| Keep personal scenes out of git | `scenes.local.json`, merged over the shipped examples |

**The one thing to tell them up front:** the bar does *not* update by itself.
A launchd agent (`event-bridge.sh`) translates AeroSpace's events into
SketchyBar triggers. Take the bar without the agent and the workspace pills
will look broken.

**Where it's still hard:**

- **It's all or nothing.** There's no "bar only" install; they get the
  keybindings too and have to prune. Their old config is backed up, not merged.
- **Chrome is assumed** by `dot window split` — it's built around Chrome's
  profile picker. Other browsers work through `split-with.sh <App> <ratio>`,
  which has no profile concept.

---

## 3. Wants the computer driven by an agent

*"I want to describe what I want and have the machine do it, without giving an
LLM a shell."*

**What they need:** a surface an agent can discover, and a blast radius they
can reason about.

| They want to… | They do |
|---|---|
| Let Claude see what's possible | `dot capabilities --json` — every command, its args, whether it's destructive |
| Ask in plain language | `dot ai "…"` — a real Claude session, in the repo, beside their window |
| Keep it on rails | `dot ai --plan` — manifest only, `dot` commands only, confirmed first |
| Review what an agent did | `~/.local/state/aerospace/audit.log` |
| Have Claude know the conventions | `CLAUDE.md` and `.claude/skills/dot/` load themselves |

**Why the descriptors matter.** Every capability declares `destructive`, and
`bin/check-capabilities.sh` *fails* if a destructive one doesn't also declare a
`guard`. An agent can read the manifest and know that `dot scene close` refuses
workspaces it didn't open — before trying it.

**The rule that came from being burned:** exit codes here are not evidence.
AeroSpace returns 0 and does nothing, routinely. Capabilities that mutate
declare a `verify` command, and the agent is told to run it.

**Where it's still hard:**

- **`dot ai` needs a Claude subscription** and the `claude` CLI. Nothing else
  in the repo does; this is the one part that isn't self-contained.
- **A session has your normal permissions.** Only `--plan` is constrained. Say
  so before someone assumes otherwise.

---

## 4. Wants to make it theirs

*"Nice, but I want my colours, my scenes, my layout."*

| They want to… | They do |
|---|---|
| Add a scene | an entry in `scenes.json` — data, no code, appears in the palette at once |
| Add a theme | a directory in `themes/` with three files |
| Check their theme is legible | `bin/check-themes.sh` — and the hook won't let them commit one that isn't |
| Add a command | one self-describing file in `libexec/dot/` |
| Change the geometry | `BAR_RADIUS` and `PILL_HEIGHT`; every other measurement derives |

**What makes this pleasant is that nothing needs registering twice.** The
palette renders from the capabilities, scene badges from `scenes.json`, the
keybinding hints from `aerospace.toml`. Add the thing; it shows up.

**Where it's still hard:**

- **No `dot theme new` scaffold.** They copy a directory and edit ~40 colours by
  hand, and only `check-themes.sh` tells them when they've got one wrong.
- **Accents have to be darkened.** Every palette worth borrowing ships accents
  that fail as a filled chip — Latte's peach is 2.64:1, Rosé Pine Dawn's gold
  2.05:1. That surprises people; [themes.md](themes.md) explains it, but the
  work is manual.

---

## What would help all four most

In rough order of what it would buy:

1. **Screenshots and a short screen recording in the readme.** Everything else
   here is documented well and shown not at all.
2. **`dot theme new <name>`** — scaffold from an existing theme, then let
   `check-themes.sh` grade it.
3. **A "bar only" install path**, for people who already tile.
4. **Make the browser configurable** rather than assuming Chrome.
