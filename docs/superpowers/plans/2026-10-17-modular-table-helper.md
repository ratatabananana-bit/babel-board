# Modular Table Helper Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Table Helper into an empty "console" that installs data-only game modules (zip or single JSON) from files, links or a private GitHub repository, and draws them with a fixed catalog of blocks. Vale of Eternity and Magical Athlete are rebuilt as modules with no visible change.

**Architecture:** A Flutter-free `module_format` library defines the module JSON (manifest, collections, block tree, path/filter mini-language) and a validator shared by the app and CLI tools. The app loads a module through a `ModuleFiles` abstraction (disk, HTTP, or memory), keeps its state per module id, and renders each tab by looking up block types in a registry of widgets generalized from today's Vale and Magical Athlete screens. A `ModuleStore` installs, updates and uninstalls modules on disk; the Library screen browses installed and repository modules.

**Tech Stack:** Flutter 3.41 / Dart 3.11, `provider`, `shared_preferences`, `quick_actions` (existing); new: `archive` (zip), `http`, `path_provider`, `flutter_secure_storage`, `file_picker`, `receive_sharing_intent`. Add each with `flutter pub add <name>` (latest).

**Spec:** `docs/superpowers/specs/2026-10-17-modular-table-helper-design.md`

## Global Constraints

- No downloaded code: a module is data only; block types are a fixed built-in set (spec §4).
- App version `3.0.0` (`pubspec.yaml` `version: 3.0.0+3`, constant `kAppVersion = '3.0.0'`); module `format` = `1`.
- Module ids for the converted games: `vale-of-eternity`, `magical-athlete`.
- All module state is saved under the prefix `mod.<moduleId>.`; modules never share state.
- Zone accents only `amber`, `mint`, `violet` (existing `Palette`), used only for tracking state.
- Installed modules work fully offline; image links are downloaded once at install.
- The Android APK ships with **no game data or art**; the web build is a preview that bundles `modules/` (spec §10).
- GitHub token stored with `flutter_secure_storage`; sent only to the host of the configured repository index.
- English UI only; every game string lives in module data.
- Everything in spec §9 ("Behavior that must survive") stays true: printed card shape; mouse = immediate drag, touch = long-press 220 ms; drop bar includes Remove; auto-scroll; never add/remove a wrapper around a `DragTarget` mid-drag; bottom sheets; zone buttons toggle; jump rail tail space + press-and-slide; Next shows "n steps left" + double tap; New game behind red confirm in ⋮; bottom-nav labels always visible; providers above the Navigator.
- Never edit source files with PowerShell `Get-Content`/`Set-Content` (non-ASCII corruption); use editor tools or UTF-8-safe writes.

## Review Focus

1. **Some image links fail or time out during install** → install still completes; those items render the text-only card style (test in Task 10).
2. **Repository lists a module whose `minAppVersion` is newer than the app** → shown as "Needs app update", install button disabled (test in Task 12).
3. **Updating the module that is currently open** → saved zones/flow survive and the game screen rebuilds without a crash (test in Task 10 for state; Task 12 for the open screen).
4. **Zip entries with `..\`, `../`, absolute paths, or a decompressed size over the limit** → install rejected with a clear message, nothing written outside the temp folder (test in Task 10).
5. **Repository index points zips/icons at a different host** → the GitHub token is not sent there (test in Task 11).

---

## File Structure

```
lib/
  app_version.dart                 kAppVersion
  main.dart                        app root: providers, startup (last game or Library)
  module_format/                   Flutter-free (importable from tool/ scripts)
    manifest.dart                  ModuleManifest, CollectionSpec, ZoneSpec, TabSpec, BlockSpec
    block_types.dart               kBlockTypes + required settings per type
    path_expr.dart                 resolvePath, fillTemplate
    filter.dart                    ItemFilter, FieldRule
    validator.dart                 validateModule, ValidationIssue, compareVersions
  modules/
    module_files.dart              ModuleFiles + Directory/Http/Memory implementations
    loaded_module.dart             LoadedModule, Item, loadModule, ModuleLoadException
    module_state.dart              ZoneState (per-module zones)
  blocks/
    registry.dart                  blockRegistry, buildBlock, UnknownBlock, ModuleScope
    icons.dart                     moduleIcon(name)
    item_view.dart                 ItemPicture, ItemTile, showItemSheet
    gallery_block.dart             gallery (+ sections, rail, filter dock, search, density)
    board_block.dart               board, zone, card list, drag + drop bar
    flow/flow_block.dart           flow + step + checklist (generalized core/flow/flow_screen.dart)
    flow/flow_state.dart           moved from core/flow (prefix mod.<id>.)
    text_block.dart                text
  library/
    module_store.dart              install/update/uninstall/list on disk
    repository.dart                RepoConfig, RepoClient, RepoListing
    install_sources.dart           file picker, link, share sheet
    migration.dart                 legacy vale.*/ma.* → mod.<id>.*
    library_screen.dart            Library UI
  core/                            kept: theme, settings, widgets/*, game_switcher (adapted)
modules/
  MODULE_SPEC.md, AI_INSTRUCTIONS.md, module.schema.json
  vale-of-eternity/   module.json, data/cards.json, images/...
  magical-athlete/    module.json, data/racers.json, images/...
tool/
  validate.dart  pack.dart  convert_legacy.dart  screenshot_test.dart
test/
  fixtures/mini_module/            tiny module used by block tests
  module_format/  modules/  blocks/  games/  library/  tool/
```

Deleted at the end: `lib/games/`, `lib/core/game_module.dart`, `lib/core/flow/`, `lib/core/migrate.dart` (logic folded into `library/migration.dart`), game `assets/` entries in `pubspec.yaml`.

---

## Phase 1: Module engine (ends with both games running as modules from `modules/` in tests and web preview)

### Task 1: Module format model and path/filter language

**Files:**
- Create: `lib/module_format/manifest.dart`, `lib/module_format/block_types.dart`, `lib/module_format/path_expr.dart`, `lib/module_format/filter.dart`, `lib/app_version.dart`
- Test: `test/module_format/manifest_test.dart`, `test/module_format/path_expr_test.dart`, `test/module_format/filter_test.dart`

**Interfaces:**
- Produces:
  - `const String kAppVersion = '3.0.0'; const int kModuleFormat = 1;` (`app_version.dart`)
  - `class ModuleManifest { int format; String id, name, version, minAppVersion; String? icon, players, source; Map<String, CollectionSpec> collections; Map<String, String> symbols; List<ZoneSpec> zones; List<TabSpec> tabs; static ModuleManifest fromJson(Map<String, dynamic>) }`
  - `class CollectionSpec { Object items /* String path or List<Map> inline */; String idField /* default 'id' */; String imageField /* default 'image' */; String imageShape /* 'card' | 'square' */; double cardAspect /* default 0.716 */; String titleField; String? subtitleField; Map<String, dynamic> sheet /* item template, see Task 7 */; }`
  - `class ZoneSpec { String id, label, icon, accent; String? hint, band; }`
  - `class TabSpec { String label, icon; String? badge /* 'zoneCount' */; BlockSpec block; }`
  - `class BlockSpec { String type; Map<String, dynamic> settings /* all keys except type, children */; List<BlockSpec> children; }`
  - `List<Object?> resolvePath(Object? data, String path)`: `a.b` walks maps; lists are flattened; `a[k=v].b` keeps list elements whose `k` equals `v`; missing → `[]`.
  - `String fillTemplate(String template, Map<String, dynamic> item)`: replaces each `{path}` with the resolved values joined by `", "`; missing → empty string.
  - `class FieldRule { String path; Object? has; Object? equals; bool matches(Map<String, dynamic> item) }` (`has`: any resolved value equals it; `equals`: exactly one value equal to it)
  - `class ItemFilter { String? zone; List<FieldRule> where; bool matches(Map<String, dynamic> item, String? itemZone); static ItemFilter fromJson(Map<String, dynamic>) }`
  - `const Set<String> kBlockTypes = {'gallery','board','zone','cardList','flow','step','text'};` (a step's checklist is a setting of the `step` block, not a separate block)
- Pure Dart: no `package:flutter` imports anywhere under `lib/module_format/`.

- [ ] **Step 1: Write failing tests**
  - `manifest_test.dart`: parses a minimal manifest with one collection (path form), one inline collection (list form), two zones, and a tab whose block is `{"type":"board","children":[{"type":"zone","zone":"table"}]}` → `tabs[0].block.children[0].settings['zone'] == 'table'`; missing `id` throws `FormatException` whose message contains `id`.
  - `path_expr_test.dart`: `resolvePath({'effects':[{'type':'instant','text':'A'},{'type':'active','text':'B'}]}, 'effects.type') == ['instant','active']`; `'effects[type=active].text' → ['B']`; `'missing.x' → []`; `fillTemplate('Cost {cost}', {'cost': 2}) == 'Cost 2'`.
  - `filter_test.dart`: filter `{"zone":"field","where":[{"path":"effects.type","has":"active"}]}` matches Imp-like item in zone `field`, not in zone `hand`, not an item without active effects.
- [ ] **Step 2: Run** `flutter test test/module_format` → FAIL (files missing)
- [ ] **Step 3: Implement the files above**
- [ ] **Step 4: Run** `flutter test test/module_format` → PASS
- [ ] **Step 5: Commit** `feat(format): module manifest, block tree, path and filter language`

### Task 2: Validator

**Files:**
- Create: `lib/module_format/validator.dart`
- Test: `test/module_format/validator_test.dart`

**Interfaces:**
- Consumes: Task 1 types, `kBlockTypes`, `kAppVersion`, `kModuleFormat`.
- Produces:
  - `class ValidationIssue { String path; String message; bool fatal; }`
  - `int compareVersions(String a, String b)` (semver `x.y.z`, missing parts = 0)
  - `List<ValidationIssue> validateModule(Map<String, dynamic> manifestJson, {required Map<String, List<Map<String, dynamic>>> collections, String appVersion = kAppVersion})`
- Rules (all fatal unless marked): required fields; `format` > `kModuleFormat` → "This game needs a newer Table Helper"; `minAppVersion` > app → same message; unknown block type → `"Unknown block 'x' — this game needs a newer Table Helper"`; required settings per type (`gallery.collection`, `board` children all `zone`, `zone.zone` exists in zones, `cardList.collection`, `flow` has at least one child and all children are `step`, `step.id` unique within a flow, checklist `action.type` ∈ {`clearZone`,`newGame`} and `clearZone.zone` exists); collection referenced by blocks exists; item ids unique per collection; image values are `https://…` or a relative path with no `..`, no leading `/` or `\`, no drive letter; zone accent ∈ {amber, mint, violet}; non-fatal: item with `verified: false` count reported once.

- [ ] **Step 1: Write failing tests:** a valid fixture (the Task 1 minimal manifest) → `isEmpty`; each rule above has one test asserting the issue path and that `fatal` is true; `compareVersions('3.0.0','3.0') == 0`, `compareVersions('3.1.0','3.0.9') > 0`.
- [ ] **Step 2: Run** `flutter test test/module_format/validator_test.dart` → FAIL
- [ ] **Step 3: Implement `validator.dart`**
- [ ] **Step 4: Run** → PASS
- [ ] **Step 5: Commit** `feat(format): module validator`

### Task 3: Module files and loader

**Files:**
- Create: `lib/modules/module_files.dart`, `lib/modules/loaded_module.dart`
- Create fixture: `test/fixtures/mini_module/module.json`, `test/fixtures/mini_module/data/items.json`, two small PNGs under `test/fixtures/mini_module/images/` (copy any two existing webp/png assets). The mini module has: collection `items` (4 items, one without image), zones `a`,`b`; tabs: gallery, board(zones a,b), flow (2 steps, one with a filter-driven checklist), text.
- Test: `test/modules/loader_test.dart`

**Interfaces:**
- Consumes: Tasks 1–2.
- Produces:
  - `abstract class ModuleFiles { Future<String> readText(String path); ImageProvider? image(String? ref); }` — `image` returns null for null/missing refs.
  - `DirectoryModuleFiles(Directory root)` (uses `FileImage`; rejects refs escaping `root`), `HttpModuleFiles(Uri base)` (uses `NetworkImage`, for the web preview), `MemoryModuleFiles(Map<String, Uint8List> files)` (tests).
  - `class Item { String id; Map<String, dynamic> data; String title(CollectionSpec c); String? subtitle(CollectionSpec c); String? imageRef(CollectionSpec c); }`
  - `class LoadedModule { ModuleManifest manifest; Map<String, List<Item>> collections; ModuleFiles files; Item? item(String collection, String id); }`
  - `class ModuleLoadException implements Exception { List<ValidationIssue> issues; }`
  - `Future<LoadedModule> loadModule(ModuleFiles files)` — reads `module.json`, loads path-form collections as `{"items":[...]}` files, runs `validateModule`, throws `ModuleLoadException` on any fatal issue.

- [ ] **Step 1: Write failing tests:** loading the fixture via `DirectoryModuleFiles(Directory('test/fixtures/mini_module'))` gives 4 items and `item('items', <id>)` works; a `MemoryModuleFiles` manifest with an unknown block throws `ModuleLoadException` whose issues mention `Unknown block`; `DirectoryModuleFiles.image('../secret.png')` returns null.
- [ ] **Step 2: Run** `flutter test test/modules/loader_test.dart` → FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run** → PASS
- [ ] **Step 5: Commit** `feat(modules): module files and loader`

### Task 4: Per-module state

**Files:**
- Create: `lib/modules/module_state.dart`
- Move: `lib/core/flow/flow_state.dart` → `lib/blocks/flow/flow_state.dart` (keep class `FlowState(prefs, {prefix, phaseCount})`)
- Test: `test/modules/state_test.dart` (port the Tracker and FlowState cases from `test/state_test.dart`)

**Interfaces:**
- Produces: `class ZoneState extends ChangeNotifier { ZoneState(SharedPreferences prefs, String moduleId); String? zoneOf(String itemId); List<String> idsIn(String zone); int count(String zone); int get total; void put(String itemId, String zone, {String? beforeId}); void remove(String itemId); void clearZone(String zone); void clearAll(); }` saved as JSON map under `mod.<moduleId>.zones` (same semantics as today's `Tracker`, including `beforeId` ordering).
- `FlowState` is constructed with `prefix: 'mod.<moduleId>.'` from now on.

- [ ] **Step 1: Write failing tests** (move/one-zone-per-item, beforeId ordering, clearZone, persist across instances, two module ids don't share state).
- [ ] **Step 2: Run** `flutter test test/modules/state_test.dart` → FAIL
- [ ] **Step 3: Implement / move**
- [ ] **Step 4: Run** → PASS
- [ ] **Step 5: Commit** `feat(modules): per-module zone and flow state`

### Task 5: Block registry, module scope and game shell

**Files:**
- Create: `lib/blocks/registry.dart`, `lib/blocks/icons.dart`, `lib/blocks/text_block.dart`
- Modify: `lib/main.dart` (GameShell builds tabs from `TabSpec`s), `lib/core/app_state.dart` (games = loaded modules), `lib/core/game_switcher.dart` (game icon from module image, list includes "Library" entry stub)
- Test: `test/blocks/registry_test.dart`

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces:
  - `typedef BlockBuilder = Widget Function(BuildContext context, BlockSpec spec);`
  - `final Map<String, BlockBuilder> blockRegistry;` (keys ⊆ `kBlockTypes`; later tasks register into it)
  - `Widget buildBlock(BuildContext context, BlockSpec spec)` → registered builder or `UnknownBlock(type)` showing "This game needs a newer Table Helper (unknown block '<type>')".
  - `class ModuleScope extends StatelessWidget { ModuleScope({required LoadedModule module, required ZoneState zones, required FlowState? flow, required Widget child}) }` — provides `LoadedModule`, `ZoneState`, `FlowState` via `provider`; used in `MaterialApp.builder` so sheets/dialogs see them.
  - `IconData moduleIcon(String name)` for names: `cards, hand, flag, run, race, table, grid, book, list, star` (fallback `Icons.circle_outlined`).
  - `class OpenGame { LoadedModule module; ZoneState zones; FlowState? flow; }` held by `AppState`: `List<OpenGame> games; OpenGame? active; void open(String moduleId)`; last game key stays `app.lastGame` (value = module id).
  - Text block settings: `{"type":"text","title":String?,"bullets":[String] | "paragraphs":[String]}`.

- [ ] **Step 1: Write failing tests:** pump the app with a loader returning the mini module whose tab 1 is a text block → its text is visible and the bottom-nav label from `TabSpec.label` shows; a module whose tab block type is registered as missing renders `UnknownBlock` text; switching tabs keeps state (KeepAlive as today).
- [ ] **Step 2: Run** `flutter test test/blocks/registry_test.dart` → FAIL
- [ ] **Step 3: Implement** (shell keeps today's PageView + NavigationBar styling, badge from `TabSpec.badge == 'zoneCount'` → `ZoneState.total`)
- [ ] **Step 4: Run** → PASS
- [ ] **Step 5: Commit** `feat(blocks): registry, module scope, shell from module tabs`

### Task 6: Flow, step, checklist blocks

**Files:**
- Create: `lib/blocks/flow/flow_block.dart` (generalize `lib/core/flow/flow_screen.dart`; reuse its widgets: header with switcher/Rules/⋮, phase bar with `short`/`tag`, parchment checklist, action pill, HowItWorks, Next button)
- Test: `test/blocks/flow_block_test.dart`

**Interfaces:**
- Consumes: Task 5 scope; `FlowState`; `ZoneState`; `ItemFilter`, `fillTemplate`.
- Block JSON (settings):
  - `flow`: `{title, cyclic (default true), reminders:[String], setup: <step settings object>, newGameText: String, children: [step blocks]}` — each step is a `step` sub-block; `setup` uses the same settings shape but is shown only from the ⋮ menu.
  - `step` settings: `{id, title, short?, tag?, summary, listTitle, nextLabel?, emptyText?, how:[String], checklist:[{id,text,sub?,action?:{type:'clearZone',zone}|{type:'newGame'},actionLabel?}], cardChecklist?: {collection, filter: <ItemFilter>, sub: <template>}}` — when `cardChecklist` is present the checklist rows are the matching items (id `card.<itemId>`, leading thumbnail, sub from template), as Vale's Resolution does today.
- Produces: `blockRegistry['flow']`.

- [ ] **Step 1: Write failing tests** (port from today's `test/widget_test.dart` Round tests and `magical_athlete_test.dart` flow test, against the mini module): "n steps left" shows; first Next tap shows "Tap again to skip them", second advances; ticking all → single tap advances; `clearZone` pill empties zone `a` and ticks its row; non-cyclic last step shows "New game" and confirming resets zones and flow; `cardChecklist` lists only items in zone `b` matching the filter.
- [ ] **Step 2: Run** `flutter test test/blocks/flow_block_test.dart` → FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run** → PASS
- [ ] **Step 5: Commit** `feat(blocks): flow, step and checklist blocks`

### Task 7: Item templates, gallery block and item sheet

**Files:**
- Create: `lib/blocks/item_view.dart`, `lib/blocks/gallery_block.dart` (reuse `ReflowGrid`, `SearchTopBar`, the cost rail and family dock from `lib/games/vale/screens/cards_screen.dart`, `CardSheet` and `RacerSheet` layouts)
- Test: `test/blocks/gallery_block_test.dart`

**Interfaces:**
- Consumes: Tasks 5, 3 (`Item`, `CollectionSpec`), `ZoneState`, `fillTemplate`, `resolvePath`.
- `CollectionSpec.sheet` template JSON: `{chips:[{symbol?:<template>, text?:<template>, symbols?:<path to list of symbol names>, label?:String}], effects?:{path, typeLabels:{type:label}, typeSymbols:{type:symbol}, typeHelp:{type:text}}, sections?:[{label, path}], secondary?:<template>, verifiedPath?:String, zones:[zoneId]}` — `zones` of length 1 → single "Add to <label>" / "In <label>" toggle (Magical Athlete); length > 1 → segmented toggles plus untrack button (Vale).
- Gallery block JSON: `{collection, search:[path], tileName: bool (name under picture), filters?: [{path, label, position:'bottom', options:[{value,label,symbol?}], allLabel}], sections?: {path, label:<template using {value}>, onlyWhenFiltered: bool, rail: bool, railRange?:[int,int]}}`
- Produces:
  - `class ItemPicture extends StatelessWidget { ItemPicture(Item item, CollectionSpec c, {double radius}) }` — `imageShape 'card'`: picture in `cardAspect`; `'square'`: framed card (art on top, title/subtitle below, as `RacerCard`); no image or image failed → text-only card (parchment, title, subtitle, first chip).
  - `class ItemTile` (picture + optional name + zone ring/band using `ZoneSpec.band ?? label`, band at top for `square`, bottom for `card`, as today).
  - `Future<void> showItemSheet(BuildContext context, Item item, String collectionId)`.
  - `blockRegistry['gallery']`.

- [ ] **Step 1: Write failing tests** (port from today's Cards/Racers tests against the mini module): single-select bottom filter dock + summary text `"<label> · n cards"`; search narrows by name and by a nested path; density toggle keys `density4/3/2`; sections + rail: press-and-slide from first to last section shows that header, and tapping the last rail number keeps it highlighted (tail space); sheet: multi-zone toggles put and untrack, single-zone button adds and removes; the item without an image renders the text-only card (find its title text inside `ItemPicture`).
- [ ] **Step 2: Run** `flutter test test/blocks/gallery_block_test.dart` → FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run** → PASS
- [ ] **Step 5: Commit** `feat(blocks): gallery, item templates and item sheet`

### Task 8: Board, zone and card list blocks

**Files:**
- Create: `lib/blocks/board_block.dart` (generalize `lib/games/vale/screens/my_cards_screen.dart` and `this_race_screen.dart`, keeping `_Drag`, `_DropDock`, `_MouseDraggable`, always-wrapped `DashedBorder`, `StackFit.passthrough` mini cards, auto-scroll)
- Test: `test/blocks/board_block_test.dart`

**Interfaces:**
- Consumes: Tasks 5, 7 (`ItemPicture`, `showItemSheet`), `ZoneState`.
- Block JSON: `board: {title, countLabel: <template using {count}>, children:[zone]}`; `zone: {zone, list: <cardList>}`; `cardList: {collection, style:'mini'|'rows'|'thumbs', columns?:int, filter?:<ItemFilter>, removable?: bool}`. A board with one zone has no drop bar; `rows` + `removable` shows the ✕ remove button (Magical Athlete "This race").
- Header ⋮ menu: "Clear <zone label>" per zone + red "Clear everything" (confirm).
- Produces: `blockRegistry['board']`, `['zone']`, `['cardList']`.

- [ ] **Step 1: Write failing tests** (port today's drag tests): touch long-press drag from zone `a` to zone `b` via the lane; drag to the drop bar `Remove`; mouse drag moves with no hold; drop on a card inserts before it; one-zone board shows rows with remove button and no drop bar; Clear everything asks for confirmation.
- [ ] **Step 2: Run** `flutter test test/blocks/board_block_test.dart` → FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run** → PASS
- [ ] **Step 5: Commit** `feat(blocks): board, zone and card list blocks`

### Task 9: Convert Vale of Eternity and Magical Athlete to modules

**Files:**
- Create: `tool/convert_legacy.dart` (one-off: reads `assets/cards.json`, `assets/rules_en.json`, `assets/symbols/`, `assets/cards/`, `assets/games/magical_athlete/*` and writes the two module folders), `modules/vale-of-eternity/**`, `modules/magical-athlete/**`
- Modify: `tool/screenshot_test.dart` (load modules from `modules/` with `DirectoryModuleFiles`, keep the same shot list and names)
- Test: `test/games/vale_module_test.dart`, `test/games/magical_athlete_module_test.dart` (ported from today's `test/widget_test.dart`, `test/data_test.dart`, `test/magical_athlete_test.dart`)

**Interfaces:**
- Consumes: every block from Tasks 5–8.
- Data the converter must add per Vale card (so templates need no lookup tables): `familyLabel` ("Fire"…), `sellsFor` (list of symbol names, e.g. `["stone_red","stone_red","stone_red"]`), `image` → `images/cards/<id>.webp`. Symbols: family names, `stone_red|blue|purple`, `effect_instant|permanent|active`.
- Vale tabs: Cards = gallery (bottom family dock with symbols, sections by `cost` only when filtered, rail 0–12, `tileName: true`); My cards = board (zones `table` amber "Revealed this round", `hand` mint "Taken, not summoned", `field` violet "Summoned"; mini cards, 2 columns); Round = flow (cyclic, steps from `assets/rules_en.json`, Resolution uses `cardChecklist` with filter `{"zone":"field","where":[{"path":"effects.type","has":"active"}]}` and sub `{effects[type=active].text}`, End-of-round `clearZone: table`).
- Magical Athlete tabs: Racers = gallery (`imageShape: square`, no filters, search name/abilities); This race = board with one zone `race` (mint, band "In race"), rows, removable; Game = flow (non-cyclic, steps from current `rules_en.json`, `clearZone: race`). Sheet: subtitle `powerName`, secondary `{nameZh} (fan translation)`, sections Ability/Rulebook notes, single zone toggle.
- Module icons: Vale `images/icon.webp` from the dragon symbol; Magical Athlete `images/icon.webp` = Hare art cropped to a circle.

- [ ] **Step 1: Write failing tests:** data — 70 cards (15/15/15/15/10 by family), 36 racers, every image ref resolves to an existing file, both modules pass `validateModule` with no fatal issues; interaction — every test currently in `test/widget_test.dart` and `test/magical_athlete_test.dart` re-expressed against the loaded modules (same assertions: `"Dragon · 10 cards"`, rail jumps to `COST 10`, Fire 0→4 slide, sheet toggles, drag Table→Hand, mouse drag, Next double tap, This race lineup, game switching).
- [ ] **Step 2: Run** `flutter test test/games` → FAIL
- [ ] **Step 3: Write and run the converter** `dart run tool/convert_legacy.dart`, then fix module JSON until tests pass
- [ ] **Step 4: Run** `flutter test` → all PASS; run `flutter test tool/screenshot_test.dart` and compare `design/screenshots/*.png` with the previous commit's images (open both; differences only in pixel noise)
- [ ] **Step 5: Commit** `feat(modules): Vale of Eternity and Magical Athlete as modules`

---

## Phase 2: Installing (ends with an empty app that installs modules from file, link and repository)

### Task 10: Module store (install, update, uninstall)

**Files:**
- Create: `lib/library/module_store.dart`
- Test: `test/library/module_store_test.dart` (temp directories via `Directory.systemTemp.createTemp`, `http.testing.MockClient`)

**Interfaces:**
- Consumes: `loadModule`, `validateModule`, `DirectoryModuleFiles`, `archive`, `http.Client`.
- Produces:
  - `class InstallException implements Exception { String message; List<ValidationIssue> issues; }`
  - `class InstalledModule { String id, name, version; Directory dir; bool broken; String? error; }`
  - `class ModuleStore { ModuleStore(Directory root, {http.Client? client}); Future<List<InstalledModule>> list(); Future<InstalledModule> installBytes(Uint8List bytes, {Uri? sourceUrl, Map<String, String> Function(Uri url)? headersFor}); Future<void> uninstall(String id); }`
- Behavior: detects zip (PK header) vs JSON; extracts to a temp dir under `root/.staging`; rejects entries whose normalized path contains `..`, starts with `/` or `\`, or has a drive letter, after converting `\` to `/`; limits: zip ≤ 50 MB, total uncompressed ≤ 150 MB, single file ≤ 15 MB, allowed extensions `.json .webp .png .jpg .jpeg`; single-JSON modules: inline collections written to `data/<id>.json`; every `https` image ref (collection image fields, `symbols`, `icon`) is downloaded (timeout 15 s each, max 6 at once) into `images/remote/<sha1>.<ext>` and the ref rewritten — failures leave the ref empty (text-only style); then `loadModule` on staging; then atomic swap into `root/<id>` (old folder removed only after success). State is not touched, so updates keep it. `list()` marks folders that fail `loadModule` as `broken` with the error.

- [ ] **Step 1: Write failing tests:** install the mini module as zip bytes and as single JSON; update to a higher version keeps `mod.<id>.zones` in prefs; uninstall removes the folder; traversal entries `../x.json`, `..\\x.json`, `/abs.json`, `C:/x.json` each throw `InstallException` and nothing is written outside root; oversize file rejected; **Review Focus 1:** two image links, one returns 404 and one times out → install succeeds and those refs are empty; **Review Focus 3 (state half):** reinstall same id while a `ZoneState` for it has items → items still there after reloading `ZoneState`.
- [ ] **Step 2: Run** `flutter test test/library/module_store_test.dart` → FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run** → PASS
- [ ] **Step 5: Commit** `feat(library): module store with safe install and update`

### Task 11: Repository client and token

**Files:**
- Create: `lib/library/repository.dart`
- Test: `test/library/repository_test.dart`

**Interfaces:**
- Produces:
  - `class RepoConfig { Uri indexUrl; String? token; }` persisted: URL in `shared_preferences` key `repo.indexUrl`, token in `flutter_secure_storage` key `repo.token` (wrapper `RepoConfigStore` with `load()`, `save(RepoConfig)`, `clear()`; injectable storage for tests).
  - `class RepoEntry { String id, name, version, minAppVersion; Uri zipUrl; Uri? iconUrl; int size; bool get needsAppUpdate; }` (URLs resolved relative to `indexUrl`)
  - `class RepoException implements Exception { RepoError kind /* notFound, tokenRejected, network, badIndex */; String message; }`
  - `class RepoClient { RepoClient(RepoConfig config, {http.Client? client}); Future<List<RepoEntry>> fetchIndex(); Future<Uint8List> download(Uri url); Map<String,String> headersFor(Uri url); }` — `headersFor` returns `Authorization: Bearer <token>` only when `url.host == config.indexUrl.host`.
- Index JSON: `{"name": String, "modules":[{"id","name","version","minAppVersion","zip","icon","size"}]}`.

- [ ] **Step 1: Write failing tests:** relative `zip`/`icon` resolve against `indexUrl`; 404 → `notFound`; 401/403 → `tokenRejected`; malformed JSON → `badIndex`; `needsAppUpdate` true when `minAppVersion` > `kAppVersion`; **Review Focus 5:** an entry with `zip: "https://evil.example/x.zip"` → `headersFor` has no `Authorization`, and `download` sends none (assert via `MockClient` request headers).
- [ ] **Step 2: Run** `flutter test test/library/repository_test.dart` → FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run** → PASS
- [ ] **Step 5: Commit** `feat(library): repository client with private-repo token`

### Task 12: Library screen, install sources and startup

**Files:**
- Create: `lib/library/library_screen.dart`, `lib/library/install_sources.dart`
- Modify: `lib/main.dart` (startup: load `ModuleStore.list()`, open `app.lastGame` if installed and not broken, else Library; quick actions from installed modules), `lib/core/game_switcher.dart` (sheet lists installed games + "Library"), `android/app/src/main/AndroidManifest.xml` (intent filters `VIEW`/`SEND` for `application/zip`, `application/json`, `application/octet-stream`)
- Test: `test/library/library_screen_test.dart`

**Interfaces:**
- Consumes: `ModuleStore`, `RepoClient`, `RepoConfigStore`, `AppState.open`.
- Library UI (existing design language): header "Library" + ⋮ (`Add repository` / `Edit repository`, `Install from file`, `Install from link`, `Copy instructions for AI` — wired in Task 15); grid of installed games (icon, name, version; broken ones greyed with "Can't load" and the error in a sheet); long-press → Uninstall (red confirm); section "From <repo name>": entries not installed → Install; installed but newer version → Update; `needsAppUpdate` → disabled "Needs app update". Empty state: "No games yet" with buttons "Add repository" and "Install from file". Repository dialog: index URL + token fields, Save tests the connection and shows `RepoError` messages: notFound "Couldn't find index.json at that link", tokenRejected "GitHub rejected the token", network "No connection", badIndex "That file isn't a Table Helper repository".
- `install_sources.dart`: `Future<Uint8List?> pickModuleFile()` (`file_picker`, extensions zip/json), `Future<Uint8List> downloadLink(Uri)` (plain GET; uses repo headers only for the repo host), share-intent stream from `receive_sharing_intent` → install with a progress snackbar → open the game.

- [ ] **Step 1: Write failing tests** (inject a fake store and fake repo client): empty state shows both buttons; installed game tile opens the game; repository entries show Install / Update / disabled "Needs app update" (**Review Focus 2**); uninstall asks then removes; startup opens last game when installed, Library otherwise; **Review Focus 3 (screen half):** updating the module that is open → game rebuilds and the zone count badge keeps its value.
- [ ] **Step 2: Run** `flutter test test/library/library_screen_test.dart` → FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run** → PASS; build `flutter build apk --release --split-per-abi` and confirm `Built … arm64` (retry once on the known Kotlin cache error)
- [ ] **Step 5: Commit** `feat(library): Library screen, install sources, startup`

### Task 13: Migration, ship empty, web preview

**Files:**
- Create: `lib/library/migration.dart` (absorbs `lib/core/migrate.dart`)
- Modify: `pubspec.yaml` (version `3.0.0+3`; remove `assets/cards*`, `assets/symbols/`, `assets/games/…`, `assets/rules_en.json`; keep fonts and `modules/AI_INSTRUCTIONS.md`), `lib/main.dart` (web: load modules with `HttpModuleFiles(Uri.base.resolve('modules/<id>/'))` from `modules/index.json`; no install UI on web)
- Delete: `lib/games/`, `lib/core/game_module.dart`, `lib/core/flow/`, `lib/core/migrate.dart`, the old game assets folders, `test/data_test.dart`, `test/widget_test.dart`, `test/magical_athlete_test.dart`, `test/state_test.dart` (all ported in Tasks 4 and 9)
- Test: `test/library/migration_test.dart`

**Interfaces:**
- Produces:
  - `Future<void> migrateLegacyPrefs(SharedPreferences p)` — first moves pre-multi-game keys (`tracker.zones`, `phase.*`) under `vale.` (today's behavior); then maps `app.lastGame` `vale`→`vale-of-eternity`, `ma`→`magical-athlete`; keeps `vale.*`/`ma.*` in place.
  - `Future<void> adoptLegacyState(SharedPreferences p, String moduleId)` — called by the store after installing `vale-of-eternity` or `magical-athlete` when `mod.<id>.*` keys don't exist yet: `vale.tracker.zones` → `mod.vale-of-eternity.zones`; `vale.phase.index|checked` → `mod.vale-of-eternity.phase.index|checked`; `ma.lineup` (list) → `mod.magical-athlete.zones` as `{id: "race"}` in order; `ma.phase.*` → `mod.magical-athlete.phase.*`; then removes the legacy keys for that game.

- [ ] **Step 1: Write failing tests:** prefs with `vale.tracker.zones={"imp":"hand"}`, `ma.lineup=["banana"]`, `app.lastGame='ma'` → after `migrateLegacyPrefs`, lastGame is `magical-athlete` and legacy keys still exist; after `adoptLegacyState(p,'magical-athlete')`, `ZoneState(p,'magical-athlete').zoneOf('banana') == 'race'` and `ma.lineup` is gone; adopting twice is a no-op; the pre-multi-game keys path from today's `state_test.dart` still works.
- [ ] **Step 2: Run** `flutter test test/library/migration_test.dart` → FAIL
- [ ] **Step 3: Implement, delete the old code and assets, wire `adoptLegacyState` into `ModuleStore.installBytes`**
- [ ] **Step 4: Run** `flutter analyze` → no issues; `flutter test` → all PASS; `flutter build apk --release --split-per-abi` and check the APK has no `assets/flutter_assets/assets/cards` entries (unzip listing)
- [ ] **Step 5: Commit** `feat: ship empty, migrate saved progress into modules`

---

## Phase 3: Authoring kit

### Task 14: Validator CLI and packing script

**Files:**
- Create: `tool/validate.dart`, `tool/pack.dart`, `modules/module.schema.json`
- Test: `test/tool/pack_test.dart`

**Interfaces:**
- Consumes: `lib/module_format/*` only (no Flutter imports, so `dart run` works).
- `dart run tool/validate.dart <module folder | module.json>` → prints `OK <id> <version>` or one line per issue `ERROR <path>: <message>` / `WARN …`; exit code 1 on any fatal issue.
- `dart run tool/pack.dart <modules dir> <out dir> [--name "Repo name"]` → validates every module folder, writes `<out>/<id>-<version>.zip` and `<out>/index.json` (relative `zip`/`icon`, `size` in bytes, `minAppVersion`), copies icons to `<out>/icons/<id>.webp`; also used for the web preview: `flutter build web --release` then `dart run tool/pack.dart modules build/web/modules` plus an unzipped copy per module for `HttpModuleFiles`.
- `module.schema.json`: JSON Schema (draft 2020-12) for `module.json` matching Task 1–2 rules.

- [ ] **Step 1: Write failing tests:** packing `test/fixtures/mini_module` into a temp dir yields an index with one entry whose `zip` is relative and whose `size` equals the zip file length; packing a broken module fails with exit code 1 and writes no index; **end to end (spec §11):** serve the packed output through a `MockClient` as a repository → `RepoClient.fetchIndex` → `download` → `ModuleStore.installBytes` → `loadModule` succeeds; the same zip installed as direct-link bytes and as file bytes both succeed.
- [ ] **Step 2: Run** `flutter test test/tool/pack_test.dart` → FAIL
- [ ] **Step 3: Implement**
- [ ] **Step 4: Run** → PASS; `dart run tool/validate.dart modules/vale-of-eternity` prints `OK vale-of-eternity 1.0.0`
- [ ] **Step 5: Commit** `feat(tool): module validator CLI, schema and packing script`

### Task 15: Module spec for AIs and "Copy instructions for AI"

**Files:**
- Create: `modules/MODULE_SPEC.md` (full guide: every block and setting with a tiny example, templates, paths, filters, single-file form, image links, research rules: use the official rulebook, never invent card text, mark `verified:false`, any player count the box supports), `modules/AI_INSTRUCTIONS.md` (compact version for pasting into a chat; ends with "Reply with one JSON file")
- Modify: `lib/library/library_screen.dart` (⋮ "Copy instructions for AI" → copies `AI_INSTRUCTIONS.md` asset via `Clipboard.setData`, snackbar "Copied — paste it into Claude or ChatGPT")
- Test: `test/tool/spec_docs_test.dart`

- [ ] **Step 1: Write failing tests:** `AI_INSTRUCTIONS.md` is ≤ 24,000 characters; it mentions every name in `kBlockTypes` and the words `single JSON`, `https`, `verified`; `MODULE_SPEC.md` mentions every block type; tapping the menu item puts the file's text on the clipboard (mock `SystemChannels.platform`).
- [ ] **Step 2: Run** `flutter test test/tool/spec_docs_test.dart` → FAIL
- [ ] **Step 3: Write the docs and wire the action**
- [ ] **Step 4: Run** → PASS; sanity check by hand: hand `AI_INSTRUCTIONS.md` plus "Write a module for a small game of your choice using only public rules text" to a fresh subagent, save its JSON to `test/fixtures/ai_generated.json`, and add a test that `ModuleStore.installBytes` accepts it
- [ ] **Step 5: Commit** `docs(modules): module spec, AI instructions and copy action`

### Task 16: Release check

**Files:**
- Modify: `README.md` (how to publish: `dart run tool/pack.dart modules <private repo checkout>`, push, then on the phone add the raw `index.json` URL + a fine-grained read-only token; rollout order from spec §10)
- Modify: `tool/screenshot_test.dart` (add Library empty state and Library with repository entries)

- [ ] **Step 1: Run** `flutter analyze` → `No issues found!`; `flutter test` → all pass; `flutter test tool/screenshot_test.dart` → screenshots regenerate
- [ ] **Step 2: Build** `flutter build apk --release --split-per-abi`, copy arm64 APK to `TableHelper.apk`; `flutter build web --release` + pack modules into `build/web/modules`; reload the preview and click through both games
- [ ] **Step 3: Commit** `chore: release 3.0.0 — modular Table Helper`
