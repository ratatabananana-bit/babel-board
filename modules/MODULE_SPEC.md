# Babel Board module spec (format 1)

Babel Board is a phone app that helps people play board games they can't read. It has no
games built in. A **game module** describes one game as data: its cards (or racers, tiles…),
pictures, rules text, and the screens to show, built from a fixed set of **blocks**. This
guide is written for whoever writes a module, including an AI asked "write me a module for
*Heat*". Follow it exactly; the app checks every module before installing it.

Worked examples: `vale-of-eternity/` and `magical-athlete/` in this folder.
Machine-readable schema: `module.schema.json`. Validator: `dart run tool/validate.dart <folder>`.

## Research rules (read first)

1. Use the **official rulebook** and the printed cards. Name your sources in `source`.
2. **Never invent card text.** If you can't find the exact wording of a card, write your best
   reading and set `"verified": false` on that item; the app shows a warning on its sheet.
3. Support **any player count the box supports**. Don't assume two players: write "2 cards
   per player (4 / 6 / 8 for 2 / 3 / 4 players)" rather than "4 cards".
4. All text is **English**, short, and plain. Rules go in checklists and "how it works" lines.
5. Only use image links you are sure exist. A missing picture is fine: the app draws a clean
   text-only card instead.

## Two shapes of module

- **Zip** (the full form): `module.json` at the root, collections in `data/*.json`
  (each file is `{"items": [...]}`), pictures under `images/`. Allowed file types:
  `.json .webp .png .jpg .jpeg`. Limits: zip 250 MB, unpacked 600 MB, any one file 15 MB.
- **single JSON** file (the quick form, for an AI chat): the same `module.json`, but each
  collection's `items` is the list itself, and every picture is an `https` link. Links are
  downloaded **once, at install**, and stored with the module, so the game works offline.
  A link that fails to download leaves that item with the text-only card style.

An image value is either an `https://…` link or a relative path inside the module folder
(no `..`, no leading `/` or `\`, no drive letter). An empty string means "no picture".

## module.json

```json
{
  "format": 1,
  "id": "heat",
  "name": "Heat: Pedal to the Metal",
  "version": "1.0.0",
  "minAppVersion": "3.0.0",
  "icon": "images/icon.webp",
  "players": "1-6",
  "source": "Official rulebook (Days of Wonder)",
  "collections": { "upgrades": { "items": "data/upgrades.json" } },
  "symbols": { "heat": "images/symbols/heat.webp" },
  "zones": [ { "id": "hand", "label": "Hand", "icon": "hand", "accent": "mint" } ],
  "tabs": [ { "label": "Cards", "icon": "cards", "block": { "type": "gallery", "collection": "upgrades" } } ]
}
```

| Field | Meaning |
|---|---|
| `format` | Always `1`. |
| `id` | Lowercase letters, digits, `-`, `_`, `.`. Saved progress is kept per id: never change it. |
| `name`, `version` | Shown in the Library. Raise `version` (`1.0.1`, `1.1.0`…) for every update. |
| `minAppVersion` | `"3.0.0"`, or `"3.2.0"` when the module uses `hub`, gallery `groups` / `tileSubtitle` / `searchKeyboard`, `inZone`, `moveZone` / `clearZones` or several flows, `"3.3.0"` for an expansion (`expands`, see Expansions) or a `backImageField`, or `"3.3.3"` for an `italic` section or `*italic*` runs in text. |
| `icon` | Round game icon (square picture works best). |
| `players`, `source` | Free text. |
| `collections` | Lists of items, see below. |
| `symbols` | Named small pictures (family icons, resource icons) used by chips and filters. |
| `zones` | Places the player tracks items in (hand, table, this race…). |
| `tabs` | Bottom-bar tabs, each one block tree. Two to four tabs is typical. |

### Collections

Each item is a JSON object with any fields you like. It needs a unique text `id`.

| Setting | Default | Meaning |
|---|---|---|
| `items` | — | Path to `{"items": [...]}` or the list itself (single JSON). |
| `idField` | `id` | Field holding the item id. |
| `titleField` | `name` | Field shown as the item's name. |
| `subtitleField` | none | Field shown under the name (e.g. a power name). |
| `imageField` | `image` | Field holding the picture. |
| `imageShape` | `card` | `card`: the picture is the whole printed card. `square`: square art on a cream card with the name below it. |
| `cardAspect` | `0.716` | Width ÷ height of the printed card. |
| `backImageField` | none | 3.3.0: field holding a second picture (a card back, a tile's other side). The sheet gets a flip button that turns the picture over; tiles and lists keep the front. Same rules as `imageField`. |
| `sheet` | `{}` | How the item's detail sheet looks, see below. |

Add `"verified": false` to any item whose text you couldn't confirm, and set the sheet's
`verifiedPath` to `"verified"` so the app warns about it.

### The item sheet (`sheet`)

Tapping an item opens its sheet: picture, name, subtitle, then:

```json
"sheet": {
  "chips": [
    { "symbol": "{family}", "text": "{familyLabel}" },
    { "text": "Cost {cost}" },
    { "label": "Sells", "symbols": "sellsFor" }
  ],
  "effects": {
    "path": "effects",
    "typeLabels": { "instant": "Instant", "active": "Active" },
    "typeSymbols": { "instant": "effect_instant", "active": "effect_active" },
    "typeHelp": { "active": "Use once per round." }
  },
  "sections": [ { "label": "Ability", "path": "abilities" }, { "label": "Rulebook notes", "path": "notes" } ],
  "secondary": "{nameZh}",
  "verifiedPath": "verified",
  "details": { "hint": "Interactions", "sections": [ { "label": "Interactions", "path": "interactions" } ] },
  "swipe": { "left": "table", "right": "hand" },
  "zones": ["table", "hand", "field"]
}
```

- `chips`: small pills. `symbol` is a template naming a symbol; `text` a template; `symbols`
  a path to a list of symbol names drawn in a row; `label` plain text. A chip that would show
  only its `label` (the item has no value for it) is left out.
- `effects`: for items with a list of `{"type": …, "text": …}` effects. Each effect shows its
  type's symbol and label above the text. List rows on boards show these effects too.
- `sections`: labeled text blocks from a path (a string or a list of strings); `"italic": true` (3.3.3)
  draws the block in italics (flavour text, quotes), also inside `details`. List rows show
  the first section when there are no `effects`.
- `secondary`: a small grey line (template).
- `details` (drag-up details): extra text a player only sometimes wants, such as rulings for
  tricky interactions, story or flavor text. It stays hidden below the zone buttons until the
  sheet is dragged up (a small arrow under the buttons shows there is more; tapping it also
  opens it). `sections` has the same shape as above. `hint` is the short label next to the
  arrow ("⌃ Interactions"), one value per game, not per item; leave it out for the bare
  arrow. Items with no text at those paths keep the plain sheet.
- `swipe`: flick the sheet sideways to put the item in a zone and close the sheet, e.g.
  `{"left": "table", "right": "hand"}`. Either side is optional; leave `swipe` out and
  sideways flicks do nothing. Pick the zones players fill most often.
- `zones`: which zone buttons the sheet offers. One zone: a wide "Add to …" / "In …" toggle.
  Several: one toggle per zone (tap the lit one again to stop tracking) and a "stop
  tracking" button.

## Paths, templates and filters

- **Path**: `cost`, `effects.type`, `effects[type=active].text`. Dots walk into objects; lists
  are flattened (so `effects.type` gives every effect's type); `[key=value]` keeps only list
  elements whose `key` equals `value`. Anything missing gives nothing.
- **Template**: text with `{path}` holes, e.g. `"Cost {cost}"`. Several values are joined
  with `, `. A missing value becomes empty.
- **Inline symbols**: in any text a player reads (effects, sections, drag-up details, checklist
  rows, text blocks), `:name:` shows the symbol of that name from `symbols`, e.g.
  `"Earn 2 :stone_red:"`. The picture is one line tall and sits in the line like a word. Use it
  where the printed card shows an icon (stones, resources, families) so the text reads like the
  card. A name that isn't in `symbols` is shown as written.
- **Italics** (3.3.3): `*…*` in the same texts draws the run in italics, symbols inside it
  included, e.g. `"Draw a card. *+1 Clank!*"`. A lone `*` is shown as written.
- **Filter**: `{"zone": "field", "where": [{"path": "effects.type", "has": "active"}]}`.
  `zone` (optional) keeps items currently in that zone. Each `where` rule needs `has` (any
  value at the path equals it), `equals` (exactly one value, equal to it) or `inZone` (3.2.0:
  any value at the path is the id of an item currently tracked in that zone, e.g. monster
  cards whose `monster` names a monster type put "In play"). All rules must match.

## Zones

```json
{ "id": "race", "label": "This race", "phrase": "this race", "icon": "race",
  "accent": "mint", "hint": "Racers on the track", "band": "In race" }
```

An item is in at most one zone. `accent` is `amber`, `mint` or `violet` (the only colors for
tracking). `hint` shows in the lane header, `band` on tracked pictures (default: label),
`phrase` is how the zone reads in a sentence ("Add to this race"; default: label).

Icons (tabs and zones): `cards`, `hand`, `flag`, `run`, `race`, `table`, `grid`, `book`,
`list`, `star`.

## Tabs

```json
{ "id": "mine", "label": "My cards", "icon": "hand", "badge": "zoneCount", "block": { … } }
```

`badge: "zoneCount"` shows how many items are tracked. Keep labels to one or two words.
`id` is optional: it is the handle an expansion names to add to that tab (see Expansions).
Give every tab one in a game that has, or may get, expansions.

## Blocks

A tab is a tree of blocks. Every block is `{"type": …, settings…, "children": [...]}`.
These are all the types; anything else gives "This game needs a newer Babel Board".

### `gallery`

A searchable grid of item pictures with a 4/3/2-per-row toggle. Tap opens the item sheet.

```json
{ "type": "gallery", "collection": "cards", "search": ["name", "effects.text"],
  "tileName": true, "noun": "cards", "searchHint": "Search name or effect",
  "filters": [ { "path": "family", "label": "Family", "position": "bottom", "allLabel": "All families",
                 "options": [ { "value": "fire", "label": "Fire", "symbol": "fire" } ] } ],
  "sections": { "path": "cost", "label": "COST {value}", "onlyWhenFiltered": true,
                "rail": true, "railRange": [0, 12] } }
```

- `search`: paths searched by the search box. `tileName`: name under each picture (use
  `false` when the name is printed on the picture or the shape is `square`).
- `filters`: single-select docks at the bottom; tap an option again for "all". An option with a
  `symbol` shows that picture as it is (any shape, transparent background; unselected ones are
  dimmed), one without shows its first letter in a disc. Up to ~6
  options fit as a row; more than 8 options become one button ("Class: Brute") that opens a
  searchable sheet of the options.
- `sections`: group by a field with sticky headers (`{value}` in the label). `rail` adds a
  number rail on the right to jump (tap or press and slide); `railRange` lists every number
  from first to last, dimming absent ones.
- `groups` (needs `minAppVersion` `"3.2.0"`): drill-down for big sets.
  `"groups": {"path": "class", "by": "classes", "noun": "classes"}` shows one tile per item of
  the `classes` collection first (its picture and name); tapping one shows the cards whose
  `class` equals that item's id, with a bar above the grid that leads back to "All classes".
  A typed search always spans every group. Items whose `path` value matches no `by` item are
  reachable only through search; the validator warns about them.
- `tileSubtitle` (3.2.0): a template for a second small line under the tile name, e.g.
  `"{initiative}"`, so a card can be matched by its big printed number instead of its art.
- `searchKeyboard` (3.2.0): `"number"` opens the number keypad for the search box (item
  numbers, event numbers, initiative); default `"text"`.

### `board`

The player's tracked items, one colored lane per zone. Long-press (touch) or drag (mouse) a
card to another lane, onto a card to place it before that card, or onto Remove.

```json
{ "type": "board", "title": "My cards", "countLabel": "{count} tracked",
  "children": [ { "type": "zone", "zone": "hand",
                  "list": { "type": "cardList", "collection": "cards", "style": "mini", "columns": 2 } } ] }
```

Children must all be `zone` blocks. A board with one zone shows a plain list with no lanes
and no dragging (good with `"style": "rows", "removable": true`). The ⋮ menu clears a zone or
everything.

### `zone`

One lane: `{"type": "zone", "zone": "<zone id>", "list": <cardList>}`. On its own as a tab
it is a one-lane board.

### `cardList`

How items are listed. Inside a zone it lists that zone's items; as a tab it lists the items
matching its `filter`.

```json
{ "type": "cardList", "collection": "racers", "style": "rows", "removable": true,
  "emptyText": "No racers yet." }
```

`style`: `mini` (small picture, name, effects; `columns` per row), `rows` (full width with
all text), `thumbs` (pictures only). `removable` adds an ✕ on rows. `filter` narrows the list.

### `flow`

The turn or round checklist: a step bar, the current step's parchment checklist, a Next
button that says "n steps left" and needs a second tap to skip them, a Rules sheet and a ⋮
menu with Setup and New game.

```json
{ "type": "flow", "title": "Round", "cyclic": true,
  "reminders": ["Max 4 stones each."],
  "newGameText": "Clears all your tracked cards and goes back to Hunting.",
  "setup": { "id": "setup", "title": "Setup", "summary": "Before round 1.", "listTitle": "Setup",
             "how": ["Shuffle the cards."], "checklist": [ { "id": "setup.app", "text": "New game in the app",
             "action": { "type": "newGame" } } ] },
  "children": [ { "type": "step", … } ] }
```

`cyclic: true` repeats (rounds); `false` runs once and the last step offers New game.
`reminders` fill the Rules sheet. `setup` is shown from the ⋮ menu. A flow needs at least
one step and only `step` children. A module may have several flows (3.2.0: a Scenario
tracker and a Round tracker, say); give each its own `id`, since progress is saved per id.
The first flow in tab order keeps its progress across app updates. New game resets every
flow and clears every zone.

### `step`

```json
{ "type": "step", "id": "hunting", "title": "Hunting", "short": "Hunt", "tag": "Mild",
  "summary": "Reveal 2 cards per player, then everyone drafts 2.", "listTitle": "Hunting",
  "nextLabel": "Start next round", "emptyText": "Nothing to do.",
  "how": ["Reveal 2 cards per player (4 / 6 / 8 for 2 / 3 / 4 players)."],
  "checklist": [
    { "id": "hunting.reveal", "text": "Reveal 2 cards per player", "sub": "4 / 6 / 8 cards" },
    { "id": "end.table", "text": "Clear Table in the app", "action": { "type": "clearZone", "zone": "table" },
      "actionLabel": "Clear" } ] }
```

- `id`s are unique within the flow; prefix checklist ids with the step id.
- `short` labels the step bar when `title` is long; `tag` adds a small note under it.
- `how`: the folded "How this phase works" lines.
- `action`: a pill on the row. `{"type": "clearZone", "zone": …}` empties a zone;
  `{"type": "newGame"}` asks, then clears all zones and returns to the first step;
  `{"type": "moveZone", "from": ["discard", "lost"], "to": "pool"}` (3.2.0) moves everything
  in the `from` zones to the end of `to` (a scenario's end: cards back to the pool);
  `{"type": "clearZones", "zones": ["inplay"]}` (3.2.0) empties several zones. Doing the
  action ticks the row. Default pill text: Clear, New game, Move.
- `cardChecklist`: instead of fixed rows, list items that match a filter, e.g. "your Field
  cards with Active effects":
  `{"collection": "cards", "filter": {"zone": "field", "where": [{"path": "effects.type", "has": "active"}]}, "sub": "{effects[type=active].text}"}`.

### `text`

`{"type": "text", "title": "Scoring", "paragraphs": ["…"], "bullets": ["…"]}`. Plain
reading: rules summaries, scoring, glossary.

### `hub`

A menu page for games with more sets of cards than the bottom bar has room for: one row per
`entry`, and tapping a row opens that entry's block on its own screen with a back arrow.
Anything goes inside an entry: a `gallery`, a `text`, a `board`, a `flow`, even another `hub`.

```json
{ "type": "hub", "title": "Cards", "children": [
    { "type": "entry", "label": "Abilities", "image": "images/abilities.webp", "summary": "500 ability cards",
      "block": { "type": "gallery", "collection": "abilities" } },
    { "type": "entry", "label": "Rules", "icon": "book", "block": { "type": "text", "title": "Rules", "paragraphs": ["…"] } } ] }
```

### `entry`

One row of a `hub`: `label`, an `icon` (default `grid`) or an `image` (shown instead of the
icon), an optional one-line `summary`, and the `block` it opens. Needs `minAppVersion` `"3.2.0"`.

## Expansions

An **expansion** is a module that adds to another module, its base game, instead of
standing alone: new cards in the base's collections, a new phase in its round, new tabs,
lanes, zones and symbols. It installs, updates and uninstalls on its own, needs its base
installed, and has an on/off switch in the Library. While it is on, the game switcher shows
one game: the base with everything the expansion adds. Saved progress stays the base's.

Its header is a module header plus `expands` (needs `minAppVersion` `"3.3.0"`):

```json
{
  "format": 1, "id": "vale-of-eternity-curse", "name": "Vale of Eternity: Curse", "version": "1.0.0",
  "minAppVersion": "3.3.0", "icon": "images/icon.webp", "source": "Official rulebook",
  "expands": { "id": "vale-of-eternity", "minVersion": "2.1.0" },
  "collections": { … }, "symbols": { … }, "zones": [ … ], "tabs": [ … ]
}
```

`minVersion` is optional: an older base does not get the expansion. The header (`id`,
`name`, `version`, `minAppVersion`, `icon`, `players`, `source`) describes the expansion
itself. **Everything else is an overlay**: the same shape as a module, holding only what the
expansion adds or changes, merged into the base by these rules:

1. **Objects** merge key by key. A key the base lacks is added.
2. **A plain value** (text, number, true/false), or a value of another kind than the base's,
   **replaces** the base's. A block whose `type` differs from the base block's replaces it.
3. **Lists of things with ids merge by id**: zones, tabs, steps, checklist rows (and a
   board's lanes, by `zone`). An element whose id the base has merges into it by these same
   rules. A new element goes right after the one its `"after"` names, right before the one
   its `"before"` names, or at the end.
4. **Other lists**: a list of numbers (`railRange`) replaces; any other list is appended
   to, skipping what is already there (`reminders`, `how`, `search`, `chips`, `sheet.zones`).
5. **Collections**: a collection the base has gets the expansion's `items` added; an item
   whose id the base has replaces that item (errata; the validator warns). A new collection
   name adds a collection. Its other settings merge by rules 1–4.
6. **Pictures**: the expansion's pictures are read from the expansion's own folder; paths
   are written as usual (`images/cards/ares.webp`).

An expansion cannot remove anything from its base (a `null` is an error), expand another
expansion, or change the base's header. Keep item ids unique across base and expansion.

Example: a new phase after the base's `resolution` step, two reminders, and a lane:

```json
"tabs": [
  { "id": "round", "block": { "reminders": ["Curse tokens cost 2 points each at the end."],
    "children": [ { "type": "step", "id": "curse", "after": "resolution", "title": "Curse",
                    "summary": "Move 1 curse token from each cursed card onto yourself." } ] } },
  { "id": "mine", "block": { "children": [
    { "type": "zone", "zone": "soothed", "after": "field", "list": { "type": "cardList", "collection": "cards" } } ] } },
  { "id": "summoners", "after": "cards", "label": "Summoners", "icon": "star",
    "block": { "type": "gallery", "collection": "summoners" } }
]
```

The app checks the merged game exactly like any module. When the merge fails (an `after`
naming a step the base no longer has, say), the base still opens on its own and the Library
shows the expansion as broken with the reason. Merge errors (an `after` naming nothing, a
`null`) name paths in the expansion's own `module.json`; problems found in the merged game
(an unknown zone, a duplicate id) name paths in the merged game, as for any module. Check an expansion with its base: `dart run tool/validate.dart
<expansion folder>` finds the base in the folder next to it (or pass `--base <folder>`).

## Checklist before you deliver

- [ ] `format` 1, a fresh lowercase `id`, `version`, `minAppVersion` `"3.0.0"`.
- [ ] Every item has a unique `id`; unsure text has `"verified": false`.
- [ ] Every block `collection` and `zone` names something declared.
- [ ] Every step has a unique `id`; checklist ids are unique.
- [ ] Images are `https` links (single JSON) or files in the zip; none use `..`.
- [ ] Wording covers every player count the box supports.
- [ ] `source` names the rulebook you used.
