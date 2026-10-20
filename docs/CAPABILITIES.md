# What a Babel Board module can do (capability map)

A one-page inventory of what the console can draw, track and remember, written so that a
new game can be judged against it quickly ("will *Heat* fit?"). It states limits as well as
features. The authoritative format is `modules/MODULE_SPEC.md`; the code map is
`docs/ARCHITECTURE.md`. **Keep this file current: any change to blocks, sheet settings,
saved state, zones, filters, limits or tools must be reflected here in the same commit.**

Last synced with: app 3.2.0 (in progress, branch package-2), module format 1, 2026-10-20.

## 1. Data model

| Thing | Can | Cannot |
|---|---|---|
| Collections | Any number, each a flat list of JSON objects with free fields and a unique text `id`. Per collection: title, subtitle, image field, `imageShape` card/square, one `cardAspect`, one `sheet`. | Nested collections, relations between items (an item that *refers* to another), per-item aspect, more than one picture per item (no card back / flip side). |
| Item ids | Unique within a collection. | Zone state is keyed by item id **without** the collection name, so two collections sharing an id share a zone slot. Keep ids unique across the whole module. |
| Symbols | Named small pictures. `:name:` in any player-facing text draws them inline, one line tall. Used by chips, filters, effects, checklists, text blocks. | Larger diagrams inline (hex patterns, grids): rendered one line tall only. |
| Images | `https` links (downloaded once at install) or files in the zip (`.webp .png .jpg .jpeg`). Missing picture → text-only card. | SVG, animated, remote-at-runtime. |
| Size limits | Zip 250 MB, unpacked 600 MB, one file 15 MB. Zips install from disk entry by entry, so a big module never sits in memory. | Anything bigger must be split into several modules. |
| Text | English, `:symbol:` inline, lists of strings for multi-paragraph. Any length. | Rich text (bold, links, tables), images inside text. |

## 2. Item sheet (tap a card)

Picture (tap to zoom), name, subtitle, then in order:

- `chips`: pill facts. `symbol` + `text` templates, `symbols` path (row of icons), `label`.
- `effects`: list of `{type, text}` with per-type label, symbol and one-line help. Also what list rows show.
- `sections`: labelled text blocks from a path (string or list).
- `secondary`: small grey template line (e.g. the native-language name).
- `verifiedPath`: `"verified": false` on an item shows a warning on its sheet; validator counts them.
- `details`: drag-up hidden area with its own `sections` and a `hint` label (rulings, flavour, spoilers).
- `zones`: which zone toggles the sheet offers (one → wide toggle; several → one per zone + stop tracking).
- `swipe`: flick left/right puts the item in a zone and closes.

Cannot: counters on an item (HP, uses, charges), per-item notes, per-item flip/second face, buttons that do anything but zone moves, item-to-item links.

## 3. Zones and tracking (`ZoneState`)

- Any number of zones, each with id, label, phrase, icon (fixed set of 10), accent (`amber`, `mint`, `violet`; may repeat), hint, band.
- An item is in **at most one zone**. State is `{itemId: zoneId}`, insertion-ordered, saved per module in SharedPreferences; survives module updates, deleted on uninstall.
- Operations: put (optionally before another item), remove, clear a zone (with Undo), clear all, move everything in several zones to one zone (`moveAll`, the `moveZone` checklist action), clear several zones (`clearZones`).
- A filter rule `inZone` links collections through tracking: "items whose `monster` field names an item currently in the In play zone", so a lane of monster types drives a list of their cards.
- Cannot: quantities (two copies of a card), per-player state (one tracker per phone), ordering within a zone beyond insertion/drag, an item in two zones ("owned" and "in hand this scenario" at once), numeric trackers of any kind, history/undo beyond the clear-zone snackbar.

## 4. Blocks (one tree per tab)

| Block | Draws | Settings | Limits |
|---|---|---|---|
| `gallery` | Searchable picture grid, 4/3/2 per row, grouped or flowing layout; optional drill-down (group tiles first). | One `collection`; `search` paths; `tileName`; `tileSubtitle` template (a second line, e.g. the printed number); `searchKeyboard` `text`/`number`; `filters` (single-select docks, each `path` + `options` with symbol; more than 8 options become a picker button opening a searchable sheet); `sections` by one field with sticky headers and optional number `rail` (`railRange` needs integer values); `groups` (`path`, `by` collection, `noun`): one tile per `by` item, tap to see its items, a bar with the way back; a typed search spans every group. | One collection per gallery. No multi-select, no range filter, no sort control. Group tiles come from a second collection, so each group needs an item there (the validator warns about items whose group value names none). Pictures decode at tile size. Lazy above 120 shown items (`kReflowLimit`): only tiles near the viewport are built and nothing glides; at or below, the gliding `ReflowGrid`. The flowing layout is only used at or below the limit. |
| `board` | One coloured lane per zone; drag between lanes, before a card, or to Remove; ⋮ clears. | `title`, `countLabel`, children = `zone` blocks each with a `cardList` style. | One zone → plain list, no dragging. Lanes show only items of that lane's `cardList.collection`. |
| `zone` | A single lane (a one-zone board as a tab). | `zone`, `list`. | — |
| `cardList` | Items matching a `filter` (zone and/or `where` rules). Styles `mini` (columns), `rows`, `thumbs`; `removable` ✕. | | Filter rules are `has`, `equals` and `inZone`, all must match; no OR, no numeric comparison. |
| `flow` | Round/turn tracker: step bar, parchment checklist, "How this phase works", Next (nags on unticked), Rules sheet (`reminders`), ⋮ Setup and New game. | `cyclic`, `setup` step, `children` = `step`. | **One flow per module.** Linear steps only. |
| `step` | One phase. | `title/short/tag/summary/how`, fixed `checklist` rows (`id/text/sub/action/actionLabel`) **or** `cardChecklist` (tracked items matching a filter, with a `sub` template). | Actions: `clearZone`, `newGame`, `moveZone` (from zones → to zone), `clearZones`. No branching, no counters, no dice, no random draw, no timers, no per-player rows, no conditional rows. |
| `text` | Title, paragraphs, bullets. | | No headings inside, no images, no collapsible sections, no search. |
| `hub` | A menu page: one row per `entry` (icon or picture, label, summary); tapping pushes the entry's block on its own screen with a back arrow. | `title`, children = `entry` blocks (`label`, `icon`, `image`, `summary`, `block`). Any block inside, hubs included. | Entries are not tabs: no badge, no swipe between them. A flow inside a hub is found for saved state (first flow in tab order, hubs walked). |

Tabs: a Material bottom bar, swipe between tabs, state kept per tab. Two to four fit; five is cramped; more is not guarded against but unusable. One gallery per tab, but a `hub` tab holds any number of galleries and texts as entries, so a browsable collection no longer costs a tab.

## 5. Saved state (per module, SharedPreferences)

`mod.<id>.zones` (tracking), `mod.<id>.phase.index` + `.phase.checked` (flow). That is all a
module can remember. No free-form notes, numbers, unlocks, campaign log or per-character
profiles. `newGame` wipes zones and flow together.

## 6. Install, update, share

Install from zip, single JSON (images as links), a pasted link, a shared file, or a GitHub
repository of packed modules (`tool/pack.dart`; Install / Update / Uninstall per game).
Validator (`tool/validate.dart`, also run on install) reports path + message. Game switcher
in the top bar swaps modules in two taps. Web preview serves unpacked modules.

## 7. Quick fit test for a new game

Good fit when the game is: a fixed set of cards/tiles whose **text** is the problem, a
handful of places a card can be (hand, table, in play), and a round with a repeatable
checklist. Examples: Vale of Eternity, Magical Athlete, Heat, Wingspan (birds), Ark Nova.

Poor fit when the game needs: numbers that change every turn (HP, gold, XP, elements,
initiative), per-instance state (several monsters of one type), random draws or dice,
branching scripts, a book of long narrative, more than ~150 cards in one browsable set, or
more than four browsable sets. Such games need new block types or a bigger state model
before a module can carry them.

## 8. Change log of capabilities

- 3.2.0: gallery decodes pictures at tile size and goes lazy above 120 items.
- 3.2.0: install limits 250 MB zip / 600 MB unpacked; zips stream from disk; downloads spool to a temp file.
- 3.2.0: `hub` block with `entry` children (pushed sub-screens).
- 3.2.0: gallery `groups` (drill-down), `tileSubtitle`, `searchKeyboard`; filter docks over 8 options become a searchable picker.
- 3.2.0: `moveZone` and `clearZones` checklist actions; `inZone` filter rule.
- 3.1.x: repositories need no token; Install/Update/Uninstall rows; app renamed Babel Board.
- 3.0.0: console + modules (format 1); all blocks above; single-JSON install; `details`, `swipe`, `cardChecklist`.
