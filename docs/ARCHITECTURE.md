# How Table Helper is put together

Table Helper is a **console**: an app with no games in it. A game is a **module**, a folder
(or zip) of JSON and pictures. The app loads modules, draws their screens from a fixed set
of **blocks**, and remembers what the player tracked. This file is the map; the module
format itself is in `modules/MODULE_SPEC.md`.

## The three layers

| Layer | Folder | Knows about | Must not know about |
|---|---|---|---|
| **Module format** | `lib/module_format/` | JSON shapes, paths, validation. Pure Dart (tools import it). | Flutter, files, the phone. |
| **Modules at runtime** | `lib/modules/` | Reading a module from somewhere (`ModuleFiles`), its items, its saved state. | Widgets. |
| **App** | `lib/core/`, `lib/blocks/`, `lib/library/`, `lib/main.dart` | Widgets, navigation, installing. | — |

`tool/` (validate, pack, convert, screenshots) sits beside the app and imports only the
first two layers plus the store.

## Startup, top to bottom

```
main()
└─ HelperApp ──────────── loadAppData()
   │                       ├─ SharedPreferences + migrateLegacyPrefs
   │                       ├─ phone: ModuleStore(<support>/modules) → AppData.fromStore
   │                       └─ web:   loadWebModules(modules/index.json)
   ├─ AppState(games: [OpenGame(module, ZoneState, FlowState?)])   "which game is open"
   ├─ LibraryController(store, repo, install sources)               "installing things"
   ├─ Settings(prefs)                                                "theme, card size, speed"
   └─ MaterialApp
      ├─ builder: ModuleScope(LoadedModule, ZoneState, FlowState)   ← wraps the Navigator, so
      │                                                                sheets and dialogs see it
      └─ home: _Home
         ├─ no active game → LibraryScreen (→ SettingsScreen)
         └─ active game    → GameShell: PageView of tabs + bottom NavigationBar
                              each tab = buildBlock(tab.block)  ← the block registry
```

Everything below `GameShell` reads the module through `context.read<LoadedModule>()` and
the tracked cards through `ZoneState`; nothing is passed down by hand.

## A module, as data

```
module.json  (ModuleManifest)
├─ collections: { cards: CollectionSpec }      items from data/cards.json; id/title/image fields;
│                                              cardAspect, imageShape; sheet: SheetSpec (the item sheet template)
├─ symbols:     { stone_red: "images/…" }      named pictures for :stone_red: in text, chips, filters
├─ zones:       [ ZoneSpec(id, label, icon, accent, hint, phrase) ]   places a card can be tracked in
└─ tabs:        [ TabSpec(label, icon, badge?, block: BlockSpec) ]    one typed block per tab
                                                        └─ GallerySpec | BoardSpec(zones) | FlowSpec(steps) | TextSpec | …
```

`BlockSpec` is a sealed class: one subclass per entry of `blockParsers` (`block_specs.dart`),
whose keys are `kBlockTypes`. `ModuleManifest.parse` turns every block and every collection's
`sheet` into its typed spec once, through `Fields` (`spec_json.dart`), so a wrong value is a
`SpecFormatException` with a path and widgets never see a map. `validateModule` parses the
same way (collecting every failure) and then checks only what a parser cannot know: that the
zones and collections a spec names exist, one flow per module.

## Blocks and what is inside them

The registry (`lib/blocks/registry.dart`) maps a type to a widget; it is built from
`kBlockTypes`, so a type the parsers know and the registry does not fails at startup:

| type | widget | children it accepts | what it draws |
|---|---|---|---|
| `gallery` | `GalleryBlock` | — | searchable card grid |
| `board` | `BoardBlock` | `zone` | lanes, one per zone, drag between them |
| `zone` | `BoardBlock` (one lane) | — | a single lane |
| `cardList` | `CardListBlock` | — | the items matching a filter (also the list style *inside* a zone) |
| `flow` | `FlowBlock` | `step` | round tracker: phases, checklist, Next |
| `step` | (data for `flow`) | — | one phase |
| `text` | `TextBlock` | — | title, paragraphs, bullets |

### gallery (`gallery/`: `gallery_block.dart`, `layouts.dart`, `rail.dart`, `filter_dock.dart`)

```
GalleryBlock
├─ SearchTopBar            game switcher · search field · ViewPill (card size S/M/L, grouped↔flowing)
├─ the grid, one of three:
│   ├─ plain      ListView → ReflowGrid of ItemTile            (no filter picked)
│   ├─ grouped    CustomScrollView: per cost  SectionHeader (sticky pill + rule + count)      layouts.dart
│   │                                          SectionPanel (container; accent when picked) → ReflowGrid
│   └─ flowing    one ReflowGrid of FlowCell (ruler strip + ItemTile), band behind the picked cost
├─ SectionRail             fixed slots for the cost range, dots for absent costs, scrub bubble   rail.dart
└─ FilterDock              family row: _OptionRow of _OptionButton (All + one per option)       filter_dock.dart
```

State the gallery keeps: search text, selected filter value, `_picked` (what you chose on
the rail; its cards stay highlighted) and `_activeSection` (what fills the screen while you
scroll; the rail ring follows it). `_sectionOffsets` / `_sectionSpans` are recomputed on every
build so the rail can jump and the ring can follow.

`ReflowGrid` (`core/widgets`) positions every tile absolutely and animates them to new slots
when the column count or the item set changes. Tile height is computed, not measured, so
every tile widget must fit `tileWidth / aspect + extraHeight`.

### item tiles and the sheet (`item_picture.dart`, `item_tile.dart`, `item_sheet.dart`)

```
ItemTile ─────────── picture + two-line name; when tracked: 2 dp outline + ZoneChip (corner)
└─ ItemPicture ───── card art, or _FramedCard (square shape), or TextOnlyCard (no picture)
tap → showItemSheet → ItemSheet
   ├─ _SheetPanel         the panel itself (painted here, not by the route, so it can slide away)
   ├─ _Thumb              picture, tap to zoom
   ├─ _Chip ×n            fact chips from sheet.chips
   ├─ effects / sections  SymbolText lines
   ├─ _ZoneButton ×n | _SingleZoneButton, plus "stop tracking"
   └─ _SheetGestures      drag-up details (sheet.details), flick left/right (sheet.swipe) with the slot behind
```

`SymbolText` turns `:name:` into inline pictures everywhere player-facing text is drawn.

### board (`board_block.dart`, ~1000 lines)

```
BoardBlock
├─ _Header (title, count, ⋮ menu)  ⇄  _DropDock while dragging (one target per zone + Remove)
└─ CustomScrollView of _Lane slivers, per zone:
    ├─ sticky header   icon · name · count · chevron (collapse)   …   hint   Clear pill
    └─ body            _MiniCard ×n (2 columns; _MiniCardBody = thumb + name + effects)
                       or _RowCard (rows style) or ItemPicture (thumbs style)
_Ghost      the lifted card while dragging (ring in the colour of the target under the finger)
_Drag       ChangeNotifier shared by every drop target: what is dragged, what it is over
clearZoneWithUndo   empties a lane, snackbar with Undo
```

### flow (`flow/flow_block.dart`, ~750 lines)

```
FlowBlock
├─ _Header          title · Rules sheet (reminders) · ⋮ (Setup checklist, New game)
├─ _PhaseBar        one segment per step, tap to jump
├─ step title + summary
├─ ParchmentChecklist      the cream card: rows from step.checklist or step.cardChecklist
│   └─ _ChecklistRowView   tick, text, sub; _ActionPill runs {clearZone | newGame}
├─ _HowItWorks      folded "How this phase works"
└─ _NextButton      armed on first tap when steps are open; Next / New game
FlowState           index + ticked ids, saved per module
```

## Saved state, all in SharedPreferences

| Key | Owner | What |
|---|---|---|
| `app.lastGame` | `AppState` | reopened on launch |
| `mod.<id>.zones` | `ZoneState` | `{itemId: zoneId}`, insertion-ordered |
| `mod.<id>.phase.index`, `.phase.checked` | `FlowState` | round progress |
| `settings.*` | `Settings` | theme, columns, animation speed, flowing grid |
| `repo.indexUrl` (+ token in secure storage) | `RepoConfigStore` | the private module repository |

Uninstalling a module deletes every `mod.<id>.` key. Updating keeps them.

## The Library layer (`lib/library/`)

```
LibraryController ──┬─ ModuleStore        install zip / single JSON: unzip to .staging → download https
                    │                     images → loadModule (validates) → swap folder into place
                    ├─ RepoClient         index.json + zips; token sent to the index host only
                    ├─ RepoConfigStore    URL in prefs, token in secure storage
                    ├─ InstallSources     file picker, pasted link, share sheet
                    └─ migration          legacy built-in-game state → module keys
LibraryScreen       installed tiles · repository rows · dialogs (repo, link)
SettingsScreen      games · appearance · card gallery · about
```

## Where a module's files come from (`lib/modules/module_files.dart`)

`ModuleFiles` is the one seam: `DirectoryModuleFiles` (installed on the phone),
`HttpModuleFiles` (web preview reads `build/web/modules/<id>/`), `MemoryModuleFiles`
(tests). `loadModule(files)` reads `module.json` and the collections, runs `validateModule`,
and returns a `LoadedModule` (manifest + items + files). Image refs that could leave the
module folder are refused everywhere (`isSafeImageRef`).

## Theme (`lib/core/theme.dart`)

`Palette` is a `ThemeExtension` with two fixed sets (dark, light). Rules: the three zone
colours (amber, mint, violet) mean zones only; the neutral **accent** (cream / ink) marks
picked things, the My cards badge, Next; parchment is the checklist card in both themes.
`T` holds the type scale. `context.pal` reaches the palette.

## Tests (`test/`, 224)

`helpers.dart` pumps the app with the mini fixture module (`test/fixtures/mini_module`) and
opens a tab. `test/games/` runs the real Vale and Magical Athlete modules through the same
screens. `tool/screenshot_test.dart` is a test that writes `design/screenshots/*.png`.
