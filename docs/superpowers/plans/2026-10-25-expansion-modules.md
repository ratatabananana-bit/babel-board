# Expansion Modules and Vale of Eternity: Curse Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a module declare `"expands"` and merge into its installed base game (new items, collections, zones, symbols, tabs, lanes, flow steps), with an on/off switch, a second "back" picture for items, and ship *Vale of Eternity: Curse* as the first expansion.

**Architecture:** The merge is pure Dart in `lib/module_format/expansion.dart`: JSON overlay rules over a base manifest, then the ordinary `checkModule` on the result, so the app, `tool/validate.dart` and `tool/pack.dart` share one engine. `lib/modules/` reads each package as a layer (files + data) and builds one `LoadedModule` from a base layer plus the expansion layers that merge; `LayeredModuleFiles` keeps `ModuleFiles` the only seam for bytes. The Library loads games through one shared function and shows expansions in their own section.

**Tech Stack:** Flutter (Dart ^3.11), `provider`, `shared_preferences`, `archive`, `http`; `flutter_test`; ffmpeg (`E:\AI\Videocationer\ffmpeg\ffmpeg.exe`) for webp conversion and crops.

**Spec:** `docs/superpowers/specs/2026-10-25-expansion-modules-design.md`

## Global Constraints

- App version **3.3.0** (`lib/app_version.dart` `kAppVersion`, `pubspec.yaml` `version: 3.3.0+7`); module `format` stays **1**. Expansions set `minAppVersion` `"3.3.0"`.
- The console's philosophy holds: games are data drawn from the fixed block catalog; no game-specific code anywhere under `lib/`. Every new capability is an optional setting with today's behaviour as default.
- `lib/module_format/` stays free of Flutter imports (the tools import it).
- Saved state of a merged game stays under the **base** id (`mod.vale-of-eternity.*`). Expansion switch: `mod.<expansionId>.enabled` = `false` when off; absent = on.
- Layer refs: `@<expansionId>/<relative path>`; `https://` refs and `''` are never rewritten.
- Vale of Eternity's only change is `version` `2.1.0` plus tab ids `cards`, `mine`, `round`; its `minAppVersion` stays `"3.0.0"`. Magical Athlete is not edited.
- `docs/CAPABILITIES.md` changes in the same task as the capability it describes, with its "Last synced with" line and change log (CLAUDE.md rule). `MODULE_SPEC.md`, `AI_INSTRUCTIONS.md` (≤ 24000 chars, `test/tool/spec_docs_test.dart`), `module.schema.json` likewise.
- Never edit files with PowerShell `Get-Content`/`Set-Content` (non-ASCII damage).
- Commits: only when the owner asks. Each task ends at a green checkpoint (`flutter analyze` clean, `flutter test` green).

## Review Focus

1. **An expansion switched off while its cards sit in Field**: the My cards badge and lanes show only base cards; switching it on brings the same cards back where they were. Pinned in Task 3 and Task 4.
2. **A base update that drops the step an expansion anchors to** (`"after": "resolution"` no longer resolves): the base opens alone, the expansion is listed as broken with the anchor error. Pinned in Task 2 and Task 4.
3. **A game in progress on End of round when Curse is installed** (saved index 3, Curse inserts a step before it): it reopens on End of round, now index 4. Pinned in Task 3.
4. **An expansion installed before its base** (file or repository): refused with "… is an expansion for Vale of Eternity. Install Vale of Eternity first.", nothing left in the store. Pinned in Task 4.
5. **An expansion item whose id the base already has**: it replaces the base item and the validator prints a WARN naming it; the game loads. Pinned in Task 1 and Task 7.

---

### Task 1: Merge engine, tab ids, version 3.3.0

**Files:**
- Create: `lib/module_format/expansion.dart`
- Modify: `lib/module_format/manifest.dart` (`TabSpec.id`), `lib/module_format/validator.dart` (expansion guard, provided item lists win, unique tab ids, `imageRefIssue`), `lib/app_version.dart`, `pubspec.yaml`, the test pinning the version constant
- Test: `test/module_format/expansion_test.dart`, `test/module_format/validator_test.dart`, `test/module_format/manifest_test.dart`
- Docs: `modules/MODULE_SPEC.md` (new "Expansions" section with the six merge rules verbatim from spec §3.1, tab `id`), `modules/module.schema.json` (`expands`, tab `id`, `after`/`before`), `modules/AI_INSTRUCTIONS.md` (one paragraph), `docs/CAPABILITIES.md` (new §6 "Expansions"; install section renumbered)

**Interfaces:**
- Produces in `expansion.dart`:
  - `class ExpansionRef { const ExpansionRef({required this.id, this.minVersion}); final String id; final String? minVersion; static ExpansionRef? of(Map<String, dynamic> manifest); }` — null without `expands`; `SpecFormatException('expands', 'Should be {"id": "<base module id>", "minVersion"?: "x.y.z"}')` on a wrong shape.
  - `class ModuleData { const ModuleData(this.manifest, this.items); final Map<String, dynamic> manifest; final Map<String, List<Map<String, dynamic>>> items; String get id; }` — a package as JSON: the manifest and every collection's items (inline ones included).
  - `String layerRef(String layerId, String ref)`; `({String layer, String path})? splitLayerRef(String ref)`.
  - `const kExpansionHeader = {'format', 'id', 'name', 'version', 'minAppVersion', 'icon', 'players', 'source', 'expands'};`
  - `({ModuleData data, List<ValidationIssue> issues}) mergeExpansion(ModuleData base, ModuleData expansion)` — never mutates its inputs; issues are fatal except the errata WARN `collections.<c>: item "<id>" replaces the base game's item`. Version gate: `expands.minVersion` above the base `version` → fatal `expands.minVersion: Needs <base name> <min> or newer, <version> is installed`.
  - `List<ValidationIssue> checkExpansion(ModuleData expansion, {String appVersion = kAppVersion})` — standalone: header fields incl. `expands`, format, `minAppVersion`, `expands.id` ≠ `id`, plain collection names, text and unique item ids per overlay collection, safe image refs (`imageField`, `backImageField`, symbols, entry images).
  - `class StackResult { final ModuleData data; final ModuleManifest manifest; final List<String> merged; final Map<String, List<ValidationIssue>> rejected; final List<ValidationIssue> warnings; }`
  - `StackResult stackExpansions(ModuleData base, Iterable<ModuleData> expansions)` — base must already pass `checkModule`; expansions applied in id order, each one merged onto the accumulated result and kept only if `checkModule` on the candidate has no fatal issue; a wrong `expands.id` is rejected.
- Merge algorithm (the part the tests do not fully determine): `_overlay(Object? base, Object? over, String path, List<ValidationIssue> issues)`:
  - both `Map` → if both have `type` and they differ, return a deep copy of `over`; else key-wise recursion;
  - both `List` → key = `'id'` when every element of both is a `Map` with a `String` `id`; else `'zone'` when every element of both is a `Map` with `type == 'zone'` and a `String` `zone`; keyed → merge in place / insert by `after`/`before` (strip them; an anchor not in the list → fatal `<path>[n].after: No element "<x>" to place this after`; `after`/`before` on an existing key → fatal `… only places new elements`); unkeyed: all elements `num` → `over`, else base + `over` elements not deep-equal to one already present (an `after`/`before` there → fatal `… needs a list whose elements have ids`);
  - otherwise → deep copy of `over`.
  - `collections` are handled before `_overlay`: per name, overlay items replace base items with the same id-field value (WARN) or append; the rest of the spec minus `items` goes through `_overlay`.
  - Ref rewriting (before merging): overlay `symbols` values, each overlay item's effective `imageField` / `backImageField` (overlay spec, else base spec, else `image` / none), and `image` of every `{"type": "entry"}` object anywhere under overlay `tabs`.
- `TabSpec` gains `final String? id;` (`f.optText('id')`). Validator: `tabs[i].id: Duplicate tab id "<id>"`.
- `checkModule`: a manifest with `expands` → fatal `expands: This is an expansion for "<id>", not a game`; item lists: `collections[name] ?? (spec.isInline ? spec.inlineItems : null)`.
- `ValidationIssue? imageRefIssue(String path, Object? ref)` exported from `validator.dart`; `checkModule`'s `checkImage` and `checkExpansion` both use it.

- [ ] **Step 1: Write the failing tests** (`expansion_test.dart`, all on literal maps):

```dart
ModuleData base() => ModuleData({'format': 1, 'id': 'g', 'name': 'G', 'version': '2.1.0', 'minAppVersion': '3.0.0',
  'collections': {'cards': {'items': 'data/cards.json', 'sheet': {'chips': [{'text': 'Cost {cost}'}], 'zones': ['hand']}}},
  'symbols': {'fire': 'images/fire.webp'},
  'zones': [{'id': 'hand', 'label': 'Hand'}],
  'tabs': [
    {'id': 'mine', 'label': 'Mine', 'block': {'type': 'board', 'children': [{'type': 'zone', 'zone': 'hand'}]}},
    {'id': 'round', 'label': 'Round', 'block': {'type': 'flow', 'reminders': ['A.'], 'children': [
      {'type': 'step', 'id': 'one', 'title': 'One', 'how': ['x'], 'checklist': [{'id': 'one.a', 'text': 'a'}]},
      {'type': 'step', 'id': 'two', 'title': 'Two'}]}},
  ]}, {'cards': [{'id': 'imp', 'name': 'Imp', 'image': 'images/imp.webp'}]});

ModuleData exp(Map<String, dynamic> overlay, [Map<String, List<Map<String, dynamic>>> items = const {}]) =>
    ModuleData({'format': 1, 'id': 'g-x', 'name': 'G: X', 'version': '1.0.0', 'minAppVersion': '3.3.0',
      'expands': {'id': 'g', 'minVersion': '2.1.0'}, ...overlay}, items);

test('a new step lands after its anchor; after/before are removed', ...);   // steps ids == [one, mid, two]; no 'after' key left
test('an existing step merges: how and checklist append, title replaces', ...);
test('a lane is placed by zone key: before "hand"', ...);                    // board children zones == [summoner, hand]
test('an unknown anchor is a fatal issue at the element path', ...);       // path 'tabs[1].block.children[0].after'
test('after on an existing element is refused', ...);
test('text lists append without duplicates; number lists replace', ...);   // reminders [A., B.] from ['A.', 'B.']; railRange [0, 14]
test('a block of another type replaces the base block', ...);
test('items join by id; an equal id replaces with a WARN', ...);           // issues.single.fatal == false, message contains '"imp"'
test('expansion refs are rewritten, https and empty refs are not', ...);   // '@g-x/images/ares.webp', 'https://…', ''
test('header fields never overlay the base', ...);                          // merged name 'G', version '2.1.0', no 'expands'
test('minVersion above the base version is fatal', ...);                    // message 'Needs G 2.2.0 or newer, 2.1.0 is installed'
test('inputs are not mutated', ...);                                        // jsonEncode(base) before == after
test('stackExpansions keeps a good expansion and rejects one that fails checkModule', ...);
test('checkExpansion: missing expands.id, expands naming itself, duplicate overlay ids', ...);
test('layerRef / splitLayerRef round trip', ...);
```

`validator_test.dart`: `checkModule` refuses an `expands` manifest (`expands: This is an expansion for "g", not a game`); duplicate tab ids. `manifest_test.dart`: `TabSpec.id` parses, absent → null. Version test expects `3.3.0`.

- [ ] **Step 2: Run** `flutter test test/module_format` → FAIL (no `expansion.dart`).
- [ ] **Step 3: Implement** the interfaces above; bump the version.
- [ ] **Step 4: Run** `flutter test test/module_format` → PASS; `flutter test` → PASS; `flutter analyze` → no issues.
- [ ] **Step 5: Docs** as listed. CAPABILITIES §6 "Expansions" rows: what an expansion can add or change (items, collections, zones, symbols, tabs, lanes, steps, rows, reminders, sheet settings), the merge rules in one line each, and Cannot (remove base content, expand an expansion, require another expansion, change header fields).

---

### Task 2: Layers, layered files, building a game

**Files:**
- Create: `lib/modules/module_layer.dart`
- Modify: `lib/modules/loaded_module.dart` (`buildModule`, `buildGame`, `LoadedModule.expansions`), `lib/modules/module_files.dart` (`LayeredModuleFiles`)
- Create fixture: `test/fixtures/mini_expansion/module.json`, `data/items.json`, `images/back.webp` (copy `test/fixtures/mini_module/images/water.webp`)
- Modify fixture: `test/fixtures/mini_module/module.json` tab ids `gallery`, `board`, `flow`, `text`
- Test: `test/modules/expansion_loader_test.dart`, `test/modules/loader_test.dart`
- Docs: `docs/ARCHITECTURE.md` ("A module, as data" gains layers; "Where a module's files come from" gains `LayeredModuleFiles`)

**Interfaces:**
- Consumes: Task 1 (`ModuleData`, `ExpansionRef`, `stackExpansions`, `splitLayerRef`).
- Produces:
  - `class ModuleLayer { ModuleLayer({required this.files, required this.data, this.readIssues = const []}); final ModuleFiles files; final ModuleData data; final List<ValidationIssue> readIssues; String get id; String get name; String get version; String? get icon; ExpansionRef? get expands; }`
  - `Future<ModuleLayer> readModuleLayer(ModuleFiles files)` — today's reading half of `loadModule` (throws `ModuleLoadException` when `module.json` is unreadable or not an object; a collection file problem goes to `readIssues`).
  - `class ExpansionInfo { const ExpansionInfo({required this.id, required this.name, required this.version}); }`
  - `LoadedModule` gains `final List<ExpansionInfo> expansions;` (default `const []`).
  - `LoadedModule buildModule(ModuleLayer layer)` — throws `ModuleLoadException` on any fatal issue (an expansion layer included, via Task 1's guard).
  - `class GameBuild { const GameBuild(this.module, this.rejected); final LoadedModule module; final Map<String, List<ValidationIssue>> rejected; }`
  - `GameBuild buildGame(ModuleLayer base, Iterable<ModuleLayer> expansions)` — the base fails → `ModuleLoadException`; expansions through `stackExpansions`; an expansion with `readIssues` fatal is rejected with them; files = `LayeredModuleFiles(base.files, {for merged: id → layer.files})`.
  - `Future<LoadedModule> loadModule(ModuleFiles files)` = `buildModule(await readModuleLayer(files))` (unchanged signature).
  - `class LayeredModuleFiles implements ModuleFiles { LayeredModuleFiles(this.base, this.layers); final ModuleFiles base; final Map<String, ModuleFiles> layers; }` — `readText` reads the base; `image('@id/path')` asks `layers[id]` for `path`, unknown layer → base with the ref as written.
- Mini expansion (`id` `mini-plus`, `expands` `{"id": "mini"}`, `minAppVersion` `3.3.0`): collection `items` adds `{"id": "kraken", "name": "Kraken", "family": "water", "familyLabel": "Water", "cost": 5, "effects": [{"type": "active", "text": "Pull."}], "image": "images/back.webp"}`; new zone `c` ("Lane C", `grid`, `violet`); tab `board` adds lane `{"type": "zone", "zone": "c", "before": "a", "list": {"type": "cardList", "collection": "items"}}`; tab `flow` adds step `{"type": "step", "id": "mid", "after": "one", "title": "Middle", "checklist": [{"id": "mid.a", "text": "Middle row"}]}` and reminder `"Rule three."`; new tab `{"id": "more", "after": "gallery", "label": "More", "icon": "book", "block": {"type": "text", "title": "More", "paragraphs": ["From the expansion."]}}`.

- [ ] **Step 1: Write the failing tests** (`expansion_loader_test.dart`):

```dart
test('base + mini-plus: items, zone, lane, step, tab and picture all merge', () async {
  final g = buildGame(await readModuleLayer(DirectoryModuleFiles(miniDir)),
      [await readModuleLayer(DirectoryModuleFiles(Directory('test/fixtures/mini_expansion')))]);
  expect(g.rejected, isEmpty);
  final m = g.module;
  expect(m.item('items', 'kraken'), isNotNull);
  expect([for (final t in m.manifest.tabs) t.id], ['gallery', 'more', 'board', 'flow', 'text']);
  expect((m.manifest.tabs[2].block as BoardSpec).zones.map((z) => z.zone), ['c', 'a', 'b']);
  expect((m.manifest.tabs[3].block as FlowSpec).steps.map((s) => s.id), ['one', 'mid', 'two']);
  expect(m.item('items', 'kraken')!.data['image'], '@mini-plus/images/back.webp');
  expect(m.files.image('@mini-plus/images/back.webp'), isA<ModuleFileImage>());
  expect(m.expansions.single.id, 'mini-plus');
});
test('an expansion whose anchor is gone is rejected; the base still builds', ...); // edit mini-plus step after: 'gone'
test('loadModule refuses an expansion on its own', ...);   // ModuleLoadException, issue path 'expands'
test('an expansion for another game is rejected', ...);    // expands.id 'other'
```

`loader_test.dart`: existing tests stay green (the split must not change messages).

- [ ] **Step 2: Run** `flutter test test/modules` → FAIL.
- [ ] **Step 3: Implement**; fixtures.
- [ ] **Step 4: Run** `flutter test`, `flutter analyze` → green.
- [ ] **Step 5: Docs** (ARCHITECTURE).

---

### Task 3: Saved state that survives merging and switching

**Files:**
- Modify: `lib/blocks/flow/flow_state.dart`, `lib/modules/module_state.dart`, `lib/core/app_state.dart` (`OpenGame.load`)
- Modify tests constructing `FlowState(... phaseCount: n)`: `test/library/migration_test.dart`, `test/modules/state_test.dart`
- Test: `test/modules/state_test.dart`, `test/core/open_game_test.dart`
- Docs: `docs/CAPABILITIES.md` §5 (flow position saved by step id; counts cover only what the open game has), `docs/ARCHITECTURE.md` saved-state table (`phase.step`)

**Interfaces:**
- `FlowState(SharedPreferences prefs, {required String prefix, required List<String> steps})` replaces `phaseCount:`; `int get phaseCount` (≥ 1). Also saves `${prefix}phase.step` (current step id). On load: a saved `phase.step` found in [steps] wins over `phase.index`.
- `ZoneState(SharedPreferences prefs, String moduleId, {Set<String>? items, Set<String>? zones})`: when given, `zoneOf`, `idsIn`, `count`, `total` see only entries whose item is in [items] and zone in [zones]; other entries stay saved untouched (`put`, `remove`, `moveAll`, `clearZone` keep them; `clearAll` removes everything). `void forgetUnknown()` drops the hidden entries (one save).
- `OpenGame.load` passes every item id of every collection, every zone id, each flow's step ids.

- [ ] **Step 1: Write the failing tests**

```dart
test('a flow reopens on its saved step id after a step is inserted before it', () async {
  SharedPreferences.setMockInitialValues({'mod.mini.phase.index': 1, 'mod.mini.phase.step': 'two'});
  final f = FlowState(await SharedPreferences.getInstance(), prefix: 'mod.mini.', steps: ['one', 'mid', 'two']);
  expect(f.index, 2);
});
test('an old save with only an index still opens there', ...);              // index 1, no step key → 1
test('an unknown step id falls back to the saved index', ...);
test('entries for items or zones the game lacks are hidden, kept, and forgettable', () async {
  final p = await SharedPreferences.getInstance();
  ZoneState(p, 'mini')..put('imp', 'a')..put('kraken', 'a')..put('nessie', 'c');
  final z = ZoneState(p, 'mini', items: {'imp', 'nessie'}, zones: {'a', 'b'});
  expect(z.total, 1);
  expect(z.idsIn('a'), ['imp']);
  expect(ZoneState(p, 'mini').total, 3, reason: 'still saved');
  z.forgetUnknown();
  expect(ZoneState(p, 'mini').total, 1);
});
// open_game_test.dart: OpenGame.load of mini + mini-plus, saved {'mod.mini.phase.step': 'two'} → flow index 2.
```

- [ ] **Step 2: Run** `flutter test test/modules test/core` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`, `flutter analyze` → green.
- [ ] **Step 5: Docs.**

---

### Task 4: Store, startup and controller

**Files:**
- Modify: `lib/library/module_store.dart` (`InstalledModule`, `list`, `install`, `_fetchRemoteImages`), `lib/library/startup.dart` (`loadInstalledGames`, expansion switch keys, `loadWebModules`), `lib/library/library_controller.dart` (`refresh`, `uninstall`, `setExpansionEnabled`, `expansions`), `lib/library/repository.dart` (`RepoEntry.expands`), `lib/main.dart` (`AppData.fromStore` uses `loadInstalledGames`; `AppData.expansions`)
- Test: `test/library/module_store_test.dart`, `test/library/startup_test.dart`, `test/library/repository_test.dart`, `test/library/library_screen_test.dart` (controller-level cases)

**Interfaces:**
- Consumes: Task 2 (`readModuleLayer`, `buildModule`, `buildGame`, `ModuleLayer`), Task 3 (`ZoneState.forgetUnknown`).
- `InstalledModule` gains `final ExpansionRef? expands; final String? icon;` and `bool get isExpansion`.
- `ModuleStore.list()`: base → validated alone as today; expansion → `checkExpansion` (broken on a fatal issue). Never builds an expansion as a game.
- `ModuleStore.install`: an expansion needs `root/<expands.id>` to hold a base that builds, else `InstallException('<name> is an expansion for <base name or id>. Install <base name or id> first.')`; then `buildGame(base, [this])` must not reject it, else `InstallException(<first fatal message>, issues)`. An expansion whose id equals its `expands.id` is refused by `checkExpansion`. `_fetchRemoteImages` downloads `backImageField` refs too and, for an expansion's collection that names no `imageField`, uses the base collection's.
- In `startup.dart`:
  - `String expansionEnabledKey(String id) => 'mod.$id.enabled';` `bool isExpansionEnabled(SharedPreferences p, String id)`.
  - `enum ExpansionState { on, off, needsBase, broken }`; `class ExpansionStatus { const ExpansionStatus(this.state, [this.message]); final ExpansionState state; final String? message; }`
  - `class InstalledGames { const InstalledGames(this.modules, this.expansions); final List<LoadedModule> modules; final Map<String, ExpansionStatus> expansions; }`
  - `Future<InstalledGames> loadInstalledGames(SharedPreferences prefs, List<InstalledModule> installed)` — the one place games are built from the store (replaces the loops in `AppData.fromStore` and `LibraryController.refresh`). `needsBase` message: `Needs <base id>`; `broken` message: the first fatal issue.
  - `loadWebModules` builds each listed base with the listed expansions for it (always on).
- `LibraryController`: `Map<String, ExpansionStatus> expansions` (from `AppData.expansions`, then every `refresh`); `Future<void> setExpansionEnabled(String id, bool on)` (writes or removes the key, refreshes); `uninstall(id)` of an expansion calls `forgetUnknown()` on its base game's zones after the refresh. Uninstalling a base leaves its expansions installed.
- `RepoEntry` gains `final String? expands;` read from index `"expands"` (text).

- [ ] **Step 1: Write the failing tests**

```dart
// module_store_test.dart
test('an expansion is refused while its base is missing, and leaves nothing behind', ...);
  // message == 'Mini Plus is an expansion for mini. Install mini first.'; root lists no folder but none; no .staging
test('an expansion installs next to its base and lists as an expansion', ...);   // list() → isExpansion, expands.id 'mini'
test('an expansion that does not merge is refused with the merge error', ...);  // step after: 'gone'
test('https back pictures are downloaded at install', ...);                      // backImageField 'back' with a MockClient URL → images/remote/…
// startup_test.dart
test('loadInstalledGames: on merges, off is left out, no base is needsBase, a broken merge is broken and the base still loads', ...);
test('switching an expansion off hides its tracked cards; on shows them again', ...);   // Review Focus 1, via OpenGame.zones.total
// library_screen_test.dart (controller)
test('uninstalling an expansion forgets tracked entries only it provided', ...);
test('uninstalling the base keeps the expansion as needsBase', ...);
// repository_test.dart
test('index entries carry expands', ...);
```

Review Focus 2 lives in the startup test (a base whose step `one` was renamed: base loads, expansion `broken` with `No element "one"`). Review Focus 4 is the first store test.

- [ ] **Step 2: Run** `flutter test test/library` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`, `flutter analyze` → green.
- [ ] **Step 5: Docs.** CAPABILITIES §7 (install, update, share): expansions install after their base, the switch, uninstall behaviour; ARCHITECTURE Library layer tree (`loadInstalledGames`).

---

### Task 5: Library screen for expansions

**Files:**
- Modify: `lib/library/library_screen.dart`
- Test: `test/library/library_screen_test.dart`
- Tool: `tool/screenshot_test.dart` (one new shot `34_library_expansions.png`)

**Interfaces:**
- Consumes: Task 4 (`LibraryController.expansions`, `setExpansionEnabled`, `InstalledModule.isExpansion`, `RepoEntry.expands`).
- INSTALLED tiles are bases only. A game tile with merged expansions reads `<version> · +<n> expansion(s)` (`LoadedModule.expansions.length`).
- New section `EXPANSIONS` (only when one is installed): `_ExpansionRow` per expansion: 44 dp icon (its own `icon` through `DirectoryModuleFiles(dir)`, letter fallback like `_EntryIcon`), name, a caption by state (`For <base title> · <version>`; `Needs <base>` muted; broken: its message in `p.danger`), and a `Switch` (on for `on`, off for `off`, disabled for `needsBase`/`broken`), Semantics label `<name> on` / `<name> off`. Long-press → the same Uninstall sheet as tiles, confirm text `Removes the expansion. Its cards you tracked are forgotten.`.
- `_RepoRow` for an entry with `expands`: caption starts `Expansion · `; while its base is not installed the Install button is disabled and the caption ends ` · install <base name from the listing, else id> first`.

- [ ] **Step 1: Write the failing widget tests**: the section lists `Mini Plus` with a switch; toggling it off removes `Kraken` from the gallery after `pumpAndSettle`; a repository row for an expansion without its base shows a disabled `Install`.
- [ ] **Step 2: Run** `flutter test test/library/library_screen_test.dart` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`, `flutter analyze` → green.

---

### Task 6: Back pictures with a flip; empty labelled chips hidden

**Files:**
- Modify: `lib/module_format/manifest.dart` (`CollectionSpec.backImageField`), `lib/module_format/validator.dart` (check back refs), `lib/modules/loaded_module.dart` (`Item.backImageRef`), `lib/blocks/item_picture.dart` (`ItemPicture(back:)`), `lib/blocks/item_sheet.dart` (`_Thumb` flip, zoom flip, `_chip`), `tool/validate.dart` (back files exist)
- Create: `lib/core/widgets/flip_card.dart`
- Test: `test/blocks/item_picture_test.dart`, `test/blocks/gallery_block_test.dart` (sheet), `test/module_format/validator_test.dart`
- Docs: MODULE_SPEC collection table (`backImageField`) and chips note; AI_INSTRUCTIONS collection settings line; schema; CAPABILITIES §1 (Collections row: a second picture per item; remove "more than one picture per item (no card back / flip side)" from Cannot) and §2 (flip on the sheet; a labelled chip with no value is hidden)

**Interfaces:**
- `CollectionSpec.backImageField` (`String?`, JSON `backImageField`, no default). `String? Item.backImageRef(CollectionSpec c)` (same rules as `imageRef`).
- `ItemPicture(Item item, CollectionSpec collection, {double radius, bool back = false})`: `back` draws the back picture with the same shape and fallbacks.
- `class FlipCard extends StatefulWidget { const FlipCard({required this.front, required this.back, required this.showBack, this.duration}); }` — Y-axis turn over [duration] (`Settings.anim(const Duration(milliseconds: 360))`; zero = jump), front while the angle < π/2, back mirrored after.
- Sheet: with a back picture, the thumb shows a second round 26 dp button top-right, `Icons.flip_rounded`, Semantics `Flip card`; the zoom dialog has the same button below the picture and opens on the side the thumb shows. Without one, nothing changes.
- `_chip`: a chip whose only content would be its `label` returns null.

- [ ] **Step 1: Write the failing tests**: mini item `imp` with `back: images/water.webp` (`edit` sets `backImageField: 'back'`): the sheet has `Flip card`; tapping it shows the back (`find.byWidgetPredicate` on `ItemPicture` with `back: true` visible); an item without `back` has no flip button; the zoom dialog opens on the back after a flip. A chip `{"label": "Curses", "symbols": "curses"}` is absent on an item without `curses`. Validator: `backImageField` value `../x.png` → `collections.items[0].back` fatal.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`, `flutter analyze`, `flutter test tool/screenshot_test.dart` (Vale shots unchanged by eye) → green.
- [ ] **Step 5: Docs.**

---

### Task 7: Tools — validate and pack expansions

**Files:**
- Modify: `tool/validate.dart`, `tool/pack.dart`
- Test: `test/tool/pack_test.dart` (and a validate test beside it)
- Docs: `docs/CREATING_MODULES.md` ("Making an expansion": folder beside the base, `expands`, the rules in plain words, `validate.dart` with the base), `README.md` (one sentence in "Games as modules")

**Interfaces:**
- Consumes: Task 1 (`checkExpansion`, `stackExpansions`, `ModuleData`).
- `readModuleFolder(Directory dir)` returns `ModuleFolder` with `ModuleData get data`; for an expansion it runs `checkExpansion`, then merges with the base folder (`--base <folder>`, else the sibling folder named `expands.id`) via `stackExpansions`; a rejection's issues are reported prefixed `with <base id>: `; no base found → `WARN expands: Base "<id>" not found next to this folder; checked on its own`. Image-file existence checks cover the expansion's own refs.
- `validatePath(String path, {String? base})`; CLI `dart run tool/validate.dart <folder> [--base <folder>]`.
- `packModules` validates expansions against the base folders it packs (a missing base is the WARN above, not a failure) and writes `"expands": "<base id>"` into the index entry.

- [ ] **Step 1: Write the failing tests**: packing `mini_module` + `mini_expansion` copied into a temp `modules/` writes two entries, the expansion with `expands: 'mini'`; validating `mini_expansion` alone finds its sibling base when both sit in one folder and prints `OK mini-plus 1.0.0`; an expansion item with id `imp` prints `WARN collections.items: item "imp" replaces the base game's item` and still exits 0 (Review Focus 5).
- [ ] **Step 2: Run** `flutter test test/tool` → FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `flutter test`, `flutter analyze`, `dart run tool/validate.dart modules/vale-of-eternity` → `OK vale-of-eternity 2.0.0` → green.
- [ ] **Step 5: Docs.**

---

### Task 8: Vale of Eternity 2.1.0 and the Curse module

**Files:**
- Modify: `modules/vale-of-eternity/module.json` (`version` `2.1.0`, tab ids `cards`, `mine`, `round`), `test/games/vale_module_test.dart` (version expectation)
- Create: `modules/vale-of-eternity-curse/module.json`, `data/cards.json`, `data/summoners.json`, `images/icon.webp`, `images/cards/<id>.webp` (28), `images/summoners/<id>_front.webp`, `<id>_back.webp` (8 + 8), `images/symbols/*.webp`
- Create: `docs/superpowers/notes/2026-10-25-curse-module-1.0.md` (how the data was derived, unverified cards, rulings, like the Vale 2.0.0 notes)
- Test: `test/games/curse_module_test.dart`; `test/games/games.dart` (loader for Vale + Curse)
- Tool: `tool/screenshot_test.dart` (shots `35_curse_cards_water.png`, `36_curse_card_sheet.png`, `37_curse_my_cards.png`, `38_curse_round_curse_step.png`, `39_curse_summoner_flip.png`)

**Interfaces:**
- Consumes: everything above.
- Research (downloads approved): wiki API `imageinfo` for the 28 `File:<Card>.png`, 16 `File:<Name>front|back.jpeg`, `File:Curserulesfront.jpeg`, `File:Curserulesback.jpeg`, `File:Cursephases.jpeg`, `File:Cursescoring.jpeg` into the scratchpad (`wiki/raw/`). Read every card and tile with the image reader; enlarge with ffmpeg (`-vf scale=iw*3:-1:flags=lanczos`) where text is small. Unsure lines: `"verified": false`.
- Card items follow the base shape exactly (`id` lowercase with `_`, `name`, `family`, `familyLabel`, `cost`, `sellsFor` per the rulebook's family values, `effects` with `:symbol:` text, `interactions`, `verified`, `image`) plus `curses`: one `"curse"` per printed curse symbol (absent when none). Ids must not collide with base ids or summoner ids.
- Summoner items: `id`, `name`, `start` (one line: starting curses, wards, cards), `effects` `[{"type": "front", …}, {"type": "back", …}]`, `notes` (Kang San: "Needs the Artifacts expansion."), `image` front, `back` back, `verified`.
- Overlay, by spec §5: `collections.cards` (items + `sheet.chips` append `{"label": "Curses", "symbols": "curses"}`), `collections.summoners` (`imageShape` `card`, aspect from the cropped tiles, `backImageField` `back`, sheet with the start chip, effects labels Front side / Back side, `zones: ["summoner"]`), `symbols` (`curse`, `ward`, `ward_broken`, `mend` and any other printed icon, cropped from the card/rulebook images with ffmpeg `crop`, saved 96 px webp), zones `summoner` (`star`, `mint`, hint "Your Summoner tile") and `soothed` (`flag`, `violet`, hint "Face down under your Summoner · +1 each"), tabs: `{"id": "summoners", "after": "cards", "label": "Summoners", "icon": "star", "block": {"type": "gallery", "collection": "summoners", "search": ["name", "effects.text"], "tileName": false, "noun": "summoners"}}`, `mine` lanes summoner (`before: "table"`, `rows`) and soothed (`after: "field"`, `mini`), `round` per §5 with the Curse step `{"type": "step", "id": "curse", "after": "resolution", …, "cardChecklist": {"collection": "cards", "filter": {"zone": "field", "where": [{"path": "curses", "has": "curse"}]}, "sub": "Move 1 :curse: from it onto your Summoner"}}`.
- Card art: card PNGs → webp q82 at native size; tile photos cropped to the tile and scaled to 480 px tall, q80.

- [ ] **Step 1: Write the failing test** (`curse_module_test.dart`): Vale 2.1.0 + Curse builds with no rejection; 98 cards; 8 summoners all with a back picture; every image ref resolves to a file; the round's steps are `[hunting, action, resolution, curse, end]`; `Water` filter shows the new Water cards; a summoner sheet flips; putting a cursed card in Field lists it on the Curse step.
- [ ] **Step 2: Run** `flutter test test/games/curse_module_test.dart` → FAIL.
- [ ] **Step 3: Research and write the module** (data, images, notes file).
- [ ] **Step 4: Run** `dart run tool/validate.dart modules/vale-of-eternity-curse` → WARNs only for `verified: false`, then `OK vale-of-eternity-curse 1.0.0`; `flutter test` → green; `flutter test tool/screenshot_test.dart` → new shots look right.

---

### Task 9: Ship check

- [ ] **Step 1:** `flutter analyze` → `No issues found!`; `flutter test` → all pass.
- [ ] **Step 2:** `flutter build web --release`, `dart run tool/pack.dart modules build/web/modules --unpacked`, serve `build/web` (`node tool/serve.mjs build/web 8765`, via `.claude/launch.json`), open the browser pane: Vale + Curse opens as one game; Cards, Summoners (flip), My cards (Summoner and Soothed lanes), Round (Curse step) look right. Magical Athlete unchanged.
- [ ] **Step 3:** `dart run tool/pack.dart modules ../babel-board-modules --name "Table Helper games"` → index lists three modules, Curse with `expands`. No push.
- [ ] **Step 4:** `docs/CAPABILITIES.md` "Last synced with: app 3.3.0, module format 1, 2026-10-25"; change-log lines for 3.3.0; spec status line → "Implemented in 3.3.0".
