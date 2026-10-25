# Expansion modules, and *Vale of Eternity: Curse* as the first one (design)

Status: **implemented in 3.3.0** (branch feat/expansion-modules, 2026-10-25) · written against app 3.2.0, module format 1.
Companion to `docs/CAPABILITIES.md`.

## 1. Intent

The owner has *The Vale of Eternity: Curse* (Renegade / Mandoo, 2025–26): 28 new cards
shuffled into the base deck, 8 two-sided Summoner tiles, curse and ward tokens, and a new
Curse phase after Resolution. The owner wants it as a **separate module** that, once
installed, **combines with the Vale of Eternity module**: one game in the switcher, the new
cards in the same gallery, the new phase in the same round tracker.

The app cannot do that today. Every module is a whole game; two modules never meet. So this
work has two parts: an **expansion** mechanism in the app (general, not Vale-only), and the
**Curse module** built on it.

## 2. Goals, non-goals, anti-goals

- Goals
  - An expansion is its own installable package (own id, version, zip, repository row), so
    it updates and uninstalls on its own.
  - Installed, it merges into its base game: new items join the base's collections, new
    steps slot into the base's flows at a named place, new tabs, lanes, zones and symbols
    appear. Saved state stays the base game's (`mod.vale-of-eternity.*`).
  - An expansion can never break its base. If it fails to merge (bad data, a base update
    that moved things), the base still opens and the expansion shows as broken with the
    reason.
  - Writing one needs no new vocabulary beyond "write the parts you add, in the same shape
    as a module", plus `expands` and `after`/`before`. An AI can write it from the spec.
  - Works on the phone (store), in the web preview, and in `tool/validate.dart` /
    `tool/pack.dart`.
- Non-goals
  - Counters for curse tokens, wards or points (the README's "no scoring" line stands).
  - Expansions of expansions, or one expansion needing another (Curse's Kang San summoner
    needs *Artifacts*; it is listed with a note, nothing enforces it).
  - Removing or hiding base content (no "delete this card" in an overlay).
- Anti-goals
  - A base module that must know its expansions. The base only gives ids to the places an
    expansion may extend.
  - Merge rules that guess. Every list either merges by a declared key or appends; nothing
    is matched by position.
  - A second validator. The merged result is checked by the same `checkModule` as any game.

## 3. The expansion format (format 1, app 3.3.0)

An expansion is a module file whose header has `expands`:

```json
{
  "format": 1,
  "id": "vale-of-eternity-curse",
  "name": "Vale of Eternity: Curse",
  "version": "1.0.0",
  "minAppVersion": "3.3.0",
  "expands": { "id": "vale-of-eternity", "minVersion": "2.1.0" },
  "icon": "images/icon.webp",
  "source": "…",
  "collections": { … }, "symbols": { … }, "zones": [ … ], "tabs": [ … ]
}
```

Everything after the header is an **overlay**: the same shape as a module, holding only
what the expansion adds or changes. The header (`id`, `name`, `version`, `minAppVersion`,
`icon`, `players`, `source`) describes the expansion itself and does not overlay the base.

### 3.1 Merge rules

Applied to JSON, base first, then each enabled expansion in id order. The result is one
ordinary manifest, validated by `checkModule` like any game.

1. **Objects** merge key by key, recursively. A key the base lacks is added.
2. **A scalar**, or a value of another kind than the base's, **replaces** the base's.
   Two block objects whose `type` differs are different blocks: the overlay's replaces.
3. **Keyed lists** merge element by element. A list is keyed when every element, in base
   and overlay, is an object with a text key:
   - `id` for zones, tabs, steps, checklist rows (and anything else carrying `id`);
   - `zone` for a board's lanes (`{"type": "zone", "zone": …}`).

   An element whose key the base has merges into it (rules 1–4). A new element goes right
   after the element its `"after"` names, right before the one its `"before"` names, or at
   the end. `after`/`before` are only for new elements and are removed by the merge; naming
   a key the list doesn't have is an error.
4. **Other lists**: a list of numbers is a value (`railRange`) and is replaced; any other
   list is **appended to**, skipping elements equal to one already there (`reminders`,
   `how`, `search`, `sheet.zones`, `chips`).
5. **Collections**: an overlay collection the base has adds its `items` to the base's
   items; every other setting overlays by rules 1–4. An item whose id the base already has
   replaces that item (errata) and the validator warns about it. A new collection name adds
   a collection.
6. **Pictures**: every relative image ref of the expansion (`symbols`, item images, hub
   entry images) is rewritten to `@<expansion id>/<path>` and read from the expansion's own
   folder. Expansion files never overwrite base files.

Tabs need ids for rule 3, so **tabs gain an optional `id`**. Vale of Eternity 2.1.0 adds
`cards`, `mine`, `round` (its only change). Flows already have ids, steps and rows too.

### 3.2 Versions and failures

- `expands.minVersion` (optional): older bases do not merge ("Needs Vale of Eternity 2.1.0
  or newer, 2.0.0 is installed").
- Installing an expansion needs its base installed, and is refused unless base + this
  expansion merge and validate. Message: "Curse is an expansion for Vale of Eternity. Install
  Vale of Eternity first."
- At startup each expansion is merged on its own turn; one that fails is marked broken with
  its first error and left out. The base, and the other expansions, still load.
- Uninstalling the base leaves its expansions installed and idle ("Needs Vale of Eternity").
  *(Claude's call: cheaper to re-add the base than to re-download the expansion.)*

### 3.3 Saved state across install, update, uninstall

- The game id stays the base's, so zones and flow progress live under the base's keys.
- **Flow position by step id** *(Claude's call)*: `FlowState` also saves the current step's
  id (`phase.step`) and prefers it on load, so inserting the Curse step does not shift a
  game in progress onto the wrong step. Old saves (index only) keep working.
- Uninstalling an expansion drops tracked entries whose item or zone no longer exists, so
  the My cards badge does not count invisible cards.

## 4. App changes, by layer

| Layer | Change |
|---|---|
| `module_format/` | `expansion.dart`: `ExpansionRef` (parsed `expands`), `mergeExpansion(base, overlay)` returning the merged JSON + item lists + issues with paths. `TabSpec.id`. Validator: a standalone check for an expansion's own header and data; `checkModule` refuses a manifest with `expands` (it is not a game). |
| `modules/` | Loading split into reading a **layer** (manifest JSON, item lists, files) and building a `LoadedModule` from a base layer plus expansion layers. `LayeredModuleFiles` resolves `@id/…` refs to that layer's files (the one seam stays `ModuleFiles`). `LoadedModule.expansions` names what was merged. |
| `library/` | `ModuleStore.list()` reports `expands` and does not try to open an expansion as a game; `install` validates an expansion against its installed base. One shared "build the games from the store" function replaces the two copies in `main.dart` and `LibraryController.refresh`. Repository index entries carry `expands`; the Library shows expansions in their own section and repository rows say "Expansion for …". |
| `blocks/` | A sheet chip with a `label` but no value is hidden (base cards have no curses, so the Curses chip must not show an empty label). |
| `tool/` | `validate.dart` checks an expansion against its base (the sibling folder named by `expands.id`, or `--base <folder>`). `pack.dart` writes `expands` into `index.json`. |
| docs | `MODULE_SPEC.md` (an "Expansions" section), `AI_INSTRUCTIONS.md` (one paragraph), schema, `CAPABILITIES.md`, `ARCHITECTURE.md`, `CREATING_MODULES.md`, README sentence. |

Old apps (3.2.x) see `minAppVersion` 3.3.0 on an expansion and refuse it with the usual
"needs a newer Babel Board". Vale 2.1.0 keeps `minAppVersion` 3.0.0: an unknown tab `id` is
ignored by old apps.

## 5. The Curse module

Folder `modules/vale-of-eternity-curse/`, packed into `../babel-board-modules` with the rest.

- **Cards** (`collections.cards`, 28 items joining the 70): name, family, cost, `sellsFor`,
  effects (Instant / Permanent / Active, symbols inline like the base), `curses` (one
  `curse` symbol per printed curse), `interactions` from the wiki FAQ (Taniwha has several).
  Read from the card images, as Vale 2.0.0 was; unsure lines get `"verified": false`.
- **Sheet overlay**: one chip, `{"label": "Curses", "symbols": "curses"}`.
- **Summoners** (new collection, 8 items): front picture, starting resources, the front and
  back abilities as two effects ("Front" / "Back"), Kang San marked "needs the Artifacts
  expansion". Sheet toggle: "Add to Summoner".
- **Symbols**: `curse`, `ward`, `ward_broken`, `mend` (whatever the cards print), cropped
  from the card and rulebook images.
- **Zones**: `summoner` ("Summoner", star) and `soothed` ("Soothed", +1 point each).
- **Tabs**:
  - new `summoners` tab after `cards`: a gallery of the 8 tiles;
  - `mine`: a Summoner lane before Table, a Soothed lane after Field;
  - `round`: setup rows (pick Summoners in reverse turn order, take the starting curses,
    wards and cards shown on the tile, 3 active wards unless it says otherwise, shuffle the
    28 cards in); Action `how` lines (break 1 ward to pay 2 of a summon or remove cost;
    summoning a cursed card puts its curse tokens on it); a **Curse step after Resolution**
    listing your Field cards with curses ("move 1 curse token from each onto yourself; the
    last one gone, the card is soothed: drag it to Soothed"); End-of-round final scoring
    (−2 per curse token, +1 per active ward and soothed card; not counted for the 60-point
    trigger); reminders for wards, mending and soothing.

## 6. Testing

- Unit: every merge rule (keyed merge, `after`/`before`, unknown anchor error, appended
  lists without duplicates, number lists replaced, `type` change replaces, collections join,
  errata warning, ref rewriting); `LayeredModuleFiles`; `FlowState` by step id; zone pruning.
- Store: install refused without base; refused when the merge fails; an expansion that breaks
  after a base update leaves the base loading; uninstall order both ways.
- Widget: the mini fixture plus a mini expansion: new items in the gallery, a pushed step
  in the flow, an appended lane; the Library sections.
- Games: Vale 2.1.0 alone and Vale + Curse through `test/games/`; `tool/screenshot_test.dart`
  unchanged for Vale alone, plus shots of the merged game.
- Validator and pack on the real folders.

## 7. Owner's decisions (2026-10-25)

1. **Build it**, "like a code snob so it's easier for future people to build on top of it",
   keeping the console's philosophy: games are data drawn from a fixed catalog of blocks and
   sub-blocks; the app adds general capabilities, never game-specific code.
2. **Downloads approved** from valeofeternity.wiki.gg: the 28 card images, the 16 Summoner
   photos, the two rulebook photos. Card art goes into the module as webp; photos are read.
3. **An on/off switch per expansion** in the Library. Default on after install. Off plays
   the base alone; tracked expansion cards stay saved (not pruned) and come back when it is
   switched on again. Saved as `mod.<expansion id>.enabled = false` (absent = on), so
   uninstalling the expansion removes it with every other `mod.<id>.` key. Counts (the My
   cards badge, a board's "n tracked") include only items and zones the open game has.
4. **A flip picture**: a new general sheet capability, not a Summoner special case.
   - Collection setting `backImageField` (no default): the field holding an item's second
     picture (a card back, a tile's other side). Same ref rules as `imageField`, downloaded
     at install like it, checked by the validator like it.
   - The sheet's picture gets a flip button when the item has a back picture; tapping turns
     the card over (a Y-axis flip; instant at the "Instant" animation speed). The zoomed view
     flips the same way and opens on the side that was showing.
   - Tiles, lanes and lists keep the front. No per-item saved state: which side is up is not
     tracked.
   - Curse Summoners use it: front and back photos, each side's ability as an effect.
