# Table Helper module spec (format 1)

Table Helper is a phone app that helps people play board games they can't read. It has no
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
  `.json .webp .png .jpg .jpeg`. Limits: zip 50 MB, unpacked 150 MB, any one file 15 MB.
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
| `minAppVersion` | `"3.0.0"`. |
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
  "details": { "sections": [ { "label": "Interactions", "path": "interactions" } ] },
  "swipe": { "left": "table", "right": "hand" },
  "zones": ["table", "hand", "field"]
}
```

- `chips`: small pills. `symbol` is a template naming a symbol; `text` a template; `symbols`
  a path to a list of symbol names drawn in a row; `label` plain text.
- `effects`: for items with a list of `{"type": …, "text": …}` effects. Each effect shows its
  type's symbol and label above the text. List rows on boards show these effects too.
- `sections`: labeled text blocks from a path (a string or a list of strings). List rows show
  the first section when there are no `effects`.
- `secondary`: a small grey line (template).
- `details` (drag-up details): extra text a player only sometimes wants, such as rulings for
  tricky interactions, story or flavor text. It stays hidden below the zone buttons until the
  sheet is dragged up (a small arrow under the buttons shows there is more; tapping it also
  opens it). `sections` has the same shape as above. Items with no text at those paths keep
  the plain sheet.
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
- **Filter**: `{"zone": "field", "where": [{"path": "effects.type", "has": "active"}]}`.
  `zone` (optional) keeps items currently in that zone. Each `where` rule needs `has` (any
  value at the path equals it) or `equals` (exactly one value, equal to it). All rules must
  match.

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
{ "label": "My cards", "icon": "hand", "badge": "zoneCount", "block": { … } }
```

`badge: "zoneCount"` shows how many items are tracked. Keep labels to one or two words.

## Blocks

A tab is a tree of blocks. Every block is `{"type": …, settings…, "children": [...]}`.
These are all the types; anything else gives "This game needs a newer Table Helper".

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
- `filters`: single-select docks at the bottom; tap an option again for "all". Up to ~6
  options fit.
- `sections`: group by a field with sticky headers (`{value}` in the label). `rail` adds a
  number rail on the right to jump (tap or press and slide); `railRange` lists every number
  from first to last, dimming absent ones.

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
one step and only `step` children. One flow per module.

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
  `{"type": "newGame"}` asks, then clears all zones and returns to the first step. Doing the
  action ticks the row.
- `cardChecklist`: instead of fixed rows, list items that match a filter, e.g. "your Field
  cards with Active effects":
  `{"collection": "cards", "filter": {"zone": "field", "where": [{"path": "effects.type", "has": "active"}]}, "sub": "{effects[type=active].text}"}`.

### `text`

`{"type": "text", "title": "Scoring", "paragraphs": ["…"], "bullets": ["…"]}`. Plain
reading: rules summaries, scoring, glossary.

## Checklist before you deliver

- [ ] `format` 1, a fresh lowercase `id`, `version`, `minAppVersion` `"3.0.0"`.
- [ ] Every item has a unique `id`; unsure text has `"verified": false`.
- [ ] Every block `collection` and `zone` names something declared.
- [ ] Every step has a unique `id`; checklist ids are unique.
- [ ] Images are `https` links (single JSON) or files in the zip; none use `..`.
- [ ] Wording covers every player count the box supports.
- [ ] `source` names the rulebook you used.
