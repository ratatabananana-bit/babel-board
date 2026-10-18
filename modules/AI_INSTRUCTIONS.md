# Write a Babel Board game module

Babel Board is a phone app that helps people play board games they can't read (e.g. a
Chinese edition). It has no games built in. You will write one **game module**: a single JSON
file describing one game's cards and screens, using only the building blocks below. The app
validates it on install and rejects anything else.

## Research rules

1. Use the game's **official rulebook** and printed cards. Put your sources in `source`.
2. **Never invent card text.** If you can't confirm a card's exact wording, give your best
   reading and add `"verified": false` to that item.
3. Cover **every player count the box supports** ("2 cards per player (4 / 6 / 8 for 2 / 3 / 4
   players)"), never just two players.
4. English only, short and plain.
5. Pictures: only `https` links you are sure exist (they are downloaded once at install).
   Unsure? Leave the picture out; the app draws a clean text-only card.

## The file (single JSON form)

```json
{
  "format": 1,
  "id": "lowercase-id",
  "name": "Game Name",
  "version": "1.0.0",
  "minAppVersion": "3.0.0",
  "icon": "https://… (optional)",
  "players": "2-5",
  "source": "Official rulebook (Publisher, year)",
  "collections": { "<collectionId>": { "items": [ { "id": "…", "name": "…" } ], … } },
  "symbols": { "<name>": "https://… small icon" },
  "zones": [ … ],
  "tabs": [ … ]
}
```

`id`: lowercase letters, digits, `-`. Every item needs a unique text `id`.

### Collection settings

`items` (the list), `titleField` (default `name`), `subtitleField`, `imageField` (default
`image`), `imageShape` (`card` = the picture is the whole printed card; `square` = square art
with the name under it), `cardAspect` (width ÷ height, default 0.716), `sheet`.

`sheet` (the item's detail view), all optional:
- `chips`: `[{"symbol": "{field}", "text": "Cost {cost}", "symbols": "pathToListOfSymbolNames", "label": "Sells"}]`
- `effects`: `{"path": "effects", "typeLabels": {"instant": "Instant"}, "typeSymbols": {"instant": "symbolName"}, "typeHelp": {"instant": "When it triggers"}}` for items with `effects: [{"type": …, "text": …}]`
- `sections`: `[{"label": "Ability", "path": "abilities"}]` (string or list of strings)
- `secondary`: a small grey template line
- `verifiedPath`: `"verified"` (always set it)
- `details` (drag-up details): `{"hint": "Rulings", "sections": [{"label": "Rulings", "path": "rulings"}]}` — text hidden below the zone buttons until the sheet is dragged up: rulings for tricky interactions, story, flavor. Only use it for text that is not needed at first glance. `hint` is the one-word label shown next to the drag-up arrow (one per game).
- `zones`: zone ids offered as buttons. One zone = an "Add to …" toggle; several = one toggle each.
- `swipe`: `{"left": "table", "right": "hand"}` — flick the sheet sideways to put the item in that zone (either side optional).

### Paths, templates, filters

- Path: `cost`, `effects.type` (lists are flattened), `effects[type=active].text` (keep list
  elements whose `type` is `active`).
- Template: text with `{path}` holes: `"Cost {cost}"`.
- Inline symbols: write `:name:` in any text to show that symbol (declared in `symbols`) inside the line, e.g. `"Earn 2 :stone_red:"`. Use it wherever the printed card shows an icon.
- Filter: `{"zone": "field", "where": [{"path": "effects.type", "has": "active"}]}`. `zone`
  optional; each rule uses `has` (any value equals) or `equals` (exactly one value equals).

### Zones (what the player tracks)

`{"id": "hand", "label": "Hand", "icon": "hand", "accent": "mint", "hint": "Taken, not played", "band": "In hand", "phrase": "your hand"}`
- `accent`: only `amber`, `mint` or `violet`.
- Icons (zones and tabs): `cards`, `hand`, `flag`, `run`, `race`, `table`, `grid`, `book`, `list`, `star`.
- An item is in at most one zone.

### Tabs

`{"label": "Cards", "icon": "cards", "badge": "zoneCount", "block": <block>}`. Use 2–4 tabs;
`badge` (optional) shows the tracked count.

## Blocks (the only types)

Every block: `{"type": "<type>", …settings, "children": [...]}`.

- `gallery`: searchable picture grid; tap opens the sheet.
  `{"type": "gallery", "collection": "cards", "search": ["name", "effects.text"], "tileName": true, "noun": "cards",
  "filters": [{"path": "family", "label": "Family", "position": "bottom", "allLabel": "All", "options": [{"value": "fire", "label": "Fire", "symbol": "fire"}]}],
  "sections": {"path": "cost", "label": "COST {value}", "onlyWhenFiltered": true, "rail": true, "railRange": [0, 12]}}`
  Filters and sections are optional. `tileName: false` when the name is on the picture.
- `board`: lanes of tracked items with drag between them.
  `{"type": "board", "title": "My cards", "countLabel": "{count} tracked", "children": [<zone>, …]}`.
  Children are only `zone` blocks. One zone = a plain list without dragging.
- `zone`: `{"type": "zone", "zone": "<zone id>", "list": <cardList>}`.
- `cardList`: `{"type": "cardList", "collection": "cards", "style": "mini" | "rows" | "thumbs", "columns": 2, "removable": true, "emptyText": "…", "filter": <filter>}`.
  Inside a zone it lists that zone's items.
- `flow`: the round/turn checklist with a Next button, Rules sheet and New game.
  `{"type": "flow", "title": "Round", "cyclic": true, "reminders": ["Key rule…"], "newGameText": "Clears everything you tracked.", "setup": <step settings without type>, "children": [<step>, …]}`.
  `cyclic: false` runs once (last step offers New game). At least one step; one flow per module.
- `step`: `{"type": "step", "id": "draw", "title": "Draw", "short": "Draw", "tag": "optional note", "summary": "One line.", "listTitle": "Checklist", "nextLabel": "optional", "emptyText": "optional", "how": ["Detail line…"], "checklist": [{"id": "draw.cards", "text": "Draw 2 cards", "sub": "optional detail", "action": {"type": "clearZone", "zone": "table"}, "actionLabel": "Clear"}]}`.
  Step ids unique; checklist ids unique (prefix with the step id). `action` is optional:
  `{"type": "clearZone", "zone": …}` or `{"type": "newGame"}`. Optional `cardChecklist`
  instead of fixed rows: `{"collection": "cards", "filter": <filter>, "sub": "{template}"}`.
- `text`: `{"type": "text", "title": "Scoring", "paragraphs": ["…"], "bullets": ["…"]}`.

## A complete small example

```json
{
  "format": 1, "id": "example-duel", "name": "Example Duel", "version": "1.0.0", "minAppVersion": "3.0.0",
  "players": "2-4", "source": "Official rulebook",
  "collections": {
    "cards": {
      "items": [
        { "id": "spark", "name": "Spark", "cost": 1, "effects": [ { "type": "instant", "text": "Deal 1 damage." } ], "verified": true },
        { "id": "ward", "name": "Ward", "cost": 2, "effects": [ { "type": "ongoing", "text": "Prevent 1 damage each turn." } ], "verified": false }
      ],
      "sheet": {
        "chips": [ { "text": "Cost {cost}" } ],
        "effects": { "path": "effects", "typeLabels": { "instant": "Instant", "ongoing": "Ongoing" } },
        "verifiedPath": "verified",
        "zones": ["hand", "play"]
      }
    }
  },
  "zones": [
    { "id": "hand", "label": "Hand", "icon": "hand", "accent": "mint" },
    { "id": "play", "label": "In play", "icon": "grid", "accent": "violet" }
  ],
  "tabs": [
    { "label": "Cards", "icon": "cards", "block": { "type": "gallery", "collection": "cards", "search": ["name", "effects.text"] } },
    { "label": "Mine", "icon": "hand", "badge": "zoneCount", "block": { "type": "board", "title": "My cards", "children": [
      { "type": "zone", "zone": "hand", "list": { "type": "cardList", "collection": "cards", "style": "mini" } },
      { "type": "zone", "zone": "play", "list": { "type": "cardList", "collection": "cards", "style": "mini" } } ] } },
    { "label": "Turn", "icon": "flag", "block": { "type": "flow", "title": "Turn", "cyclic": true,
      "reminders": ["Hand limit 5."], "newGameText": "Clears your hand and play area.",
      "children": [
        { "type": "step", "id": "draw", "title": "Draw", "summary": "Draw up to 5 cards.", "how": ["Each player draws."],
          "checklist": [ { "id": "draw.cards", "text": "Draw to 5 cards" } ] },
        { "type": "step", "id": "play", "title": "Play", "summary": "Play cards, then clean up.", "how": ["Pay each card's cost."],
          "checklist": [ { "id": "play.cards", "text": "Play cards" },
                         { "id": "play.clear", "text": "Clear In play", "action": { "type": "clearZone", "zone": "play" }, "actionLabel": "Clear" } ] }
      ] } },
    { "label": "Rules", "icon": "book", "block": { "type": "text", "title": "Scoring", "bullets": ["First to 10 points wins."] } }
  ]
}
```

## Before you answer, check

- `format` 1, lowercase `id`, `minAppVersion` "3.0.0".
- Unique item ids; unsure text has `"verified": false`.
- Every `collection` and `zone` a block names is declared.
- Unique step ids and checklist ids.
- Images are `https` links or left out.
- Rules cover every supported player count.

Reply with one JSON file.
