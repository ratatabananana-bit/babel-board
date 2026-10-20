# One module for Gloomhaven: design options

Status: **Package 2 chosen** by the owner on 2026-10-20; counters (Package 3) out of scope. Written 2026-10-20 against app 3.1.1,
module format 1. Companion to `docs/CAPABILITIES.md`, which lists what the console does today.

## Intent

Carry all of Gloomhaven (ability cards, items, monster stat and ability cards, city and
road events, scenario pages, battle goals, personal quests, perks, attack modifiers) in a
**single installable module**, for the same job the app already does: read the card you
cannot read, keep track of which cards are yours, walk the round. Vale of Eternity and
Magical Athlete must keep working exactly as they do, from their unchanged manifests.

## Goals, non-goals, anti-goals

- Goals: one install, one game-switcher entry, one saved state; finding any Gloomhaven card
  in two or three taps; your hand readable without opening anything; the app stays usable
  with 1300 items and 1300 pictures.
- Non-goals: replacing Gloomhaven Helper (monster HP per standee, initiative ordering,
  element board, attack modifier deck draws). Scoring and campaign bookkeeping.
- Anti-goals: a Vale manifest that needs editing; a module format 2 that forks the
  validator; a gallery that feels different for 70-card games; features only Gloomhaven
  would ever use.

## Compatibility rule for everything below

Stay on `format: 1`. Every addition is an **optional setting with today's behaviour as the
default**, or a **new block type**. A module that uses a new block already gets "This game
needs a newer Babel Board" on an old app, through `blockParsers`; new settings on old blocks
are ignored by old apps, so a module that relies on them sets `minAppVersion` to the release
that adds them. Validator, `test/games/` runs of Vale and Magical Athlete, and the screenshot
test are the regression fence. A synthetic 600-item fixture module joins `test/fixtures/`.

## The six problems and their options

Each problem has options A, B, C with a recommendation. Effort is a rough size for one
builder: S under a day, M a few days, L a week or more.

### 1. Navigation: eight browsable sets, a four-tab bar

| | Option | How | Effort | Notes |
|---|---|---|---|---|
| A | **`hub` block (recommended)** | A tab whose block is a list of entries `{label, icon?, image?, summary?, block}`. Tapping pushes a full-screen route with a back arrow drawing that block tree. Any block, so a hub can hold galleries, text, even another hub. Entry tiles can show a picture (class crest, monster portrait). | M | Vale untouched. Pushed routes sit inside `ModuleScope`, which already wraps the Navigator, so sheets and zones work there. Tab state kept; pushed screens are ordinary routes. |
| B | Sub-games in one module | Manifest gains `games: [{id, name, icon, tabs}]` sharing collections and zones; the game switcher lists them under one install. | M | Reuses `GameShell`. But the shell is keyed by game id, so switching resets filters and scroll; it would feel like four games. Only wins if we want the switcher as the hub. |
| C | More tabs | A scrollable tab bar or a "More" sheet past four tabs. | S | Cheap, ugly on a phone, still no grouping. |

Gloomhaven tabs with A: **Cards** (hub: Abilities, Items, Monsters, Events, Scenarios,
Goals), **My hand** (board), **Scenario** (flow), **Rules** (hub of text blocks).

### 2. Finding: 17 classes, 37 monster types, 500 cards in one grid

| | Option | How | Effort | Notes |
|---|---|---|---|---|
| A | **Drill-down gallery (recommended)** | `gallery.groups: {path: "class", by: "classes", image: "crest"}`: the gallery first shows one tile per group, drawn from a second collection (so the class tile has its own crest and name), tap opens that group's cards with back. The group screen is the normal gallery, so filters, sections, rail and search work inside it. | M | Replaces a 17-pill dock. Also serves Monsters (37 types), Events (City / Road), Scenarios (by chapter or by 10s). Vale has no `groups`, nothing changes. |
| B | Filter dock overflow | When a dock has more than `N` options it becomes a button opening a bottom sheet with a searchable grid of options. | S | General and cheap; still one value at a time; worth doing anyway for mid-size docks. |
| C | Letter rail | Allow `sections` by a text field and generalise the rail to ordered keys (first letters). | M | Helps alphabetic lists, does not help "which monster is in this room". |

Small additions that help every lookup, all Vale-neutral (S each):
- `gallery.searchKeyboard: "number"`: a numeric keypad for item, event, scenario and
  initiative numbers. Search already matches numbers as substrings.
- `gallery.tileSubtitle: "{initiative}"`: a second small line under the tile name, so a
  Chinese card is matched by its big printed number instead of by art.
- `gallery.search` may already list several paths; document the initiative trick in the spec.

### 3. "Which monsters are in this room"

| | Option | How | Effort | Notes |
|---|---|---|---|---|
| A | **Zone-linked filter (recommended)** | A new filter rule `{"path": "monster", "inZone": "inplay"}`: keep items whose field value is the id of an item currently in that zone. Track the two or three monster **types** of the room in an "In play" lane; a `cardList` of monster ability cards with this rule lists only theirs, grouped by `sections`. | S | One new rule in `ItemFilter`, used nowhere by Vale. Turns a 37-way search into a glance. |
| B | Multi-select filter | `filters[].multi: true`, pills toggle, several values stay picked. | S | Simpler but the picks live in gallery state, not saved, lost on restart. |
| C | Nothing | Use the drill-down from problem 2 every time. | — | Two taps per monster turn, and a game-wide filter reset on each. |

### 4. State: pool versus scenario, one zone per item, "New game" wipes all

| | Option | How | Effort | Notes |
|---|---|---|---|---|
| A | **Zone actions and scoped reset (recommended)** | Two new checklist actions: `{"type": "moveZone", "from": "discard", "to": "pool"}` (also `from: [..]`) and `{"type": "clearZones", "zones": [...]}`. `newGame` keeps its meaning. Gloomhaven zones: `pool` (cards I own, campaign-long), `hand`, `discard`, `lost`, `active` (scenario-long), plus `inplay` for monster types and `worn` for items. Scenario end step: move hand, discard, lost, active → pool; clear inplay. | S | One item still in one zone. `ZoneState` gets `moveAll(from, to)`. Vale keeps `clearZone`/`newGame`. |
| B | Two independent trackers | Zones declare `set: "campaign"` or `"scenario"`; an item may be in one zone per set. | L | Correct model, touches every zone reader, two badges. Overkill unless items need to be "owned and equipped" at once (they do not: `worn` suffices). |
| C | Per-item counters | `sheet.counters: [{id: "hp", label, max}]` with +/- on the sheet and a badge on the tile; state `mod.<id>.counts`. | M | This is the line the README drew ("no scoring"). Needed only for monster HP per standee, which also needs instances. Leave out; name it as a possible later scope change. |

### 5. Flow: scenario setup → rounds → cleanup, plus a round loop

| | Option | How | Effort | Notes |
|---|---|---|---|---|
| A | **Several flows per module (recommended)** | Lift the one-flow rule. `FlowState` is keyed `mod.<id>.flow.<flowId>.`; the first flow keeps today's unprefixed keys so Vale progress survives. A flow gets an `id`. Gloomhaven: **Scenario** (linear: setup, play, cleanup with the zone actions above) and **Round** (cyclic, inside the Scenario hub or its own tab). | S–M | Validator drops the "only one flow" check, adds "flow ids unique". |
| B | Nested loop in one flow | `step.repeat: true` marks a step that loops on itself until "Done". | M | Awkward UI in the step bar; one flow with a hidden loop reads worse than two trackers. |
| C | Round as a text block | Setup and cleanup in the flow, the round as a static checklist in `text`. | — | Loses ticks. Not worth it. |

### 6. Size, install, performance

| | Option | How | Effort | Notes |
|---|---|---|---|---|
| A | **Raise limits with a streaming install (recommended)** | Zip 250 MB, unpacked 600 MB, one file 15 MB. Today `_unzip` holds the whole zip in memory and decodes it at once; switch to reading the picked file as a stream (`InputFileStream` / `ZipDecoder.decodeStream`) and writing entries as they come, so memory stays flat. Repository downloads stream to a temp file. | M | 1300 webp at 300×420 q75 ≈ 35 KB each ≈ 45 MB, so the current 50 MB cap is already marginal; raising it without streaming risks an out-of-memory install on a phone. |
| B | Lazy picture packs | Collections declare `images: "lazy"` and pull pictures from `https` on first open. | L | Breaks "works offline" until each card has been seen once. Not for a table app. |
| C | Keep limits, compress harder | 240×336 q65 ≈ 20 KB → 26 MB. | — | Readable on a phone but zoom on the sheet gets soft. Fallback if A slips. |

Performance work that must land first, whatever else is chosen: the **lazy gallery** with
tile-sized decode (proposed separately on 2026-10-20). Loading 1300 items of JSON is fine;
holding 1300 full-size decoded pictures is not.

### 7. Sheet details (small, all optional, S each)

- `sections[].collapsed: true`: a section folded until tapped, for event outcomes A and B.
- `sections[].table: [["Lvl","HP","Mv","Atk"],["0","5","2","2"], …]`: a small table for
  monster stats by level. Text lines work until then.
- `sheet.links: [{label: "Cards", collection: "abilities", where: {path: "class", equalsField: "id"}}]`:
  a button opening the related list. Nice to have; the drill-down covers class → cards.

## Three packages to choose from

**Package 1, "fits in a weekend": navigation and finding only.**
Lazy gallery (already proposed) + hub block + filter dock overflow + numeric search keyboard
+ tile subtitle + streaming install with raised limits. Gloomhaven installs as one module,
every card is findable in two or three taps and a number, the hand lane works as today.
Monsters still a manual pick; scenario reset wipes the pool, so players re-add their pool
after each scenario or keep the pool off the app. Rough size: 5 M-sized items.

**Package 2, "plays a campaign" (recommended).** Package 1 + drill-down gallery groups +
zone-linked filter + moveZone / clearZones actions + several flows. Pool, hand, discard,
lost and active behave like the real game, monster ability cards for the current room appear
on their own, the Scenario and Round trackers are separate. Rough size: Package 1 plus 4
S–M items, about two weeks of evenings.

**Package 3, "companion app".** Package 2 + per-item counters + tables + links. Crosses the
README's "no scoring" line and still does not give per-standee HP (needs instances). Only if
the table wants to drop Gloomhaven Helper, which this would not fully replace.

## What stays true for Vale and Magical Athlete

- Manifests unchanged, no new required fields, defaults reproduce today's screens.
- One flow keeps its saved keys; `clearZone` and `newGame` unchanged.
- Gallery with no `groups`, no `tileSubtitle`, no `searchKeyboard` draws as before; the
  lazy layout keeps the glide animation below the item threshold, so 70 cards still glide.
- Install path change is internal; the same zips install.
- `test/games/` and `tool/screenshot_test.dart` run unchanged and must pass; screenshots are
  diffed by eye once.

## Suggested order inside Package 2

1. Lazy gallery and sized decode (separate session, already proposed).
2. Streaming install and limits.
3. `hub` block.
4. Gallery: `groups`, `tileSubtitle`, `searchKeyboard`, dock overflow.
5. Zone actions `moveZone`, `clearZones`; `inZone` filter rule.
6. Several flows.
7. Spec, schema, `docs/CAPABILITIES.md`, AI instructions updated at each step.
8. The Gloomhaven module itself, in the private modules repository, built against the
   synthetic fixture first and the real card data second.

## Open decisions for the owner

1. Which package.
2. Whether the hub replaces tabs for Gloomhaven only, or whether Vale's three tabs also
   move under a hub one day (recommendation: no, tabs stay the default).
3. Image budget: 300×420 at ~35 KB (zoom stays sharp, ~45 MB) or smaller.
4. Whether counters are ever in scope (recommendation: not now).
