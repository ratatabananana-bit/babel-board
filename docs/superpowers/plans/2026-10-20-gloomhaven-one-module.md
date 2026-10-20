# One Module for Gloomhaven (Package 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let one module carry a 1300-item game (Gloomhaven) by adding a hub block, a lazy gallery with drill-down groups, zone-linked filters, bulk zone actions, several flows and a streaming installer, while Vale of Eternity and Magical Athlete run unchanged from their current manifests.

**Architecture:** Every change is an optional setting with today's behaviour as the default, or a new block type registered through `blockParsers` + `blockRegistry`. Pure-Dart specs live in `lib/module_format/`, widgets in `lib/blocks/`, saved state in `lib/modules/` and `lib/blocks/flow/flow_state.dart`. The validator keeps reporting path + message. Docs (`modules/MODULE_SPEC.md`, `modules/module.schema.json`, `modules/AI_INSTRUCTIONS.md`, `docs/CAPABILITIES.md`) are updated inside the task that adds each feature; `test/tool/spec_docs_test.dart` enforces that every block type is documented.

**Tech Stack:** Flutter (Dart SDK ^3.11), `provider`, `shared_preferences`, `archive` ^4.5 (`archive_io` for streams), `http`. Tests with `flutter_test`; `test/helpers.dart` pumps the app with the mini fixture module.

**Spec:** `docs/superpowers/specs/2026-10-20-gloomhaven-one-module-design.md` (Package 2 chosen; counters, tables and links out of scope).

## Global Constraints

- Module `format` stays `1`. New features are opt-in; a module using them sets `minAppVersion: "3.2.0"`.
- `kAppVersion` becomes `3.2.0` (`lib/app_version.dart`, `pubspec.yaml` `version: 3.2.0+6`); fix the test that pins the constant.
- `modules/vale-of-eternity/module.json` and `modules/magical-athlete/module.json` are **not edited** by any task. `git status` after each task shows no change under `modules/vale-of-eternity/` or `modules/magical-athlete/`.
- Zone accents stay `amber`, `mint`, `violet`; icons stay the ten in `moduleIcon`.
- Saved-state keys already in use keep their meaning: `mod.<id>.zones`, `mod.<id>.phase.index`, `mod.<id>.phase.checked` (the first flow of a module).
- Every task ends with `flutter analyze` clean and `flutter test` green (224 tests today plus the new ones). `flutter test tool/screenshot_test.dart` must pass at the end of Tasks 2, 4, 5 and 8 (it rewrites `design/screenshots/`; commit the PNGs only when they changed on purpose).
- Commit per task on `master` with a plain message; no amends.
- Reflow threshold: `kReflowLimit = 120` shown items. At or below it the gallery keeps the gliding `ReflowGrid`; above it the lazy layout is used. Dock picker threshold: `kDockPickerLimit = 8` options.
- Install limits: `maxZipBytes = 250 MB`, `maxTotalBytes = 600 MB`, `maxFileBytes = 15 MB` (unchanged).

## Review Focus

1. **A flow nested in a hub and no top-level flow** (Gloomhaven's Scenario tracker lives under a hub). "New game" from that flow must clear zones and reset that flow, and the flow must have a `FlowState` at all. Pinned in Task 7.
2. **Vale's saved round progress across the update.** Prefs holding `mod.vale-of-eternity.phase.index = 2` must still open Vale on step 3 after several flows exist. Pinned in Task 7.
3. **An item whose group value names no item of the `by` collection** (a typo in `class`). It must stay reachable through search and the validator must warn (non-fatal) with a count. Pinned in Task 5.
4. **`inZone` against a list-valued field** (a monster ability card used by two monster types). Any value in the zone matches. Pinned in Task 6.
5. **A zip made by zipping the folder itself** (`gloomhaven/module.json` instead of `module.json`). The streaming installer must answer the same `This zip has no module.json at its root` as today, not a crash and not a half-installed module. Pinned in Task 3.

---

### Task 1: Tile-sized image decode

**Files:**
- Modify: `lib/blocks/item_picture.dart` (`ItemPicture.build`)
- Test: `test/blocks/gallery_block_test.dart`

**Interfaces:**
- Produces: `ImageProvider sizedImage(ImageProvider img, double logicalWidth, double dpr)` (top-level in `item_picture.dart`) → `ResizeImage(img, width: (logicalWidth * dpr).ceil(), policy: ResizeImagePolicy.fit, allowUpscaling: false)`.
- The sheet's full-size zoom (`_Thumb` in `item_sheet.dart`) is untouched and keeps the raw provider.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('gallery tiles decode their picture at tile size, not full size', (tester) async {
  await pumpModules(tester);
  final img = tester.widget<Image>(find.descendant(of: find.byType(ItemTile), matching: find.byType(Image)).first);
  expect(img.image, isA<ResizeImage>());
  final tileW = tester.getSize(find.byType(ItemTile).first).width;
  expect((img.image as ResizeImage).width, lessThanOrEqualTo((tileW * tester.view.devicePixelRatio).ceil()));
});
```

- [ ] **Step 2: Run it, expect FAIL** — `flutter test test/blocks/gallery_block_test.dart` → "Expected: an instance of ResizeImage".

- [ ] **Step 3: Implement.** In `ItemPicture.build`, wrap `body` in a `LayoutBuilder`; resolve `img` through `sizedImage(img, box.maxWidth, MediaQuery.devicePixelRatioOf(context))` for the `card`, `square` and `artOnly` branches. `TextOnlyCard` path unchanged.

- [ ] **Step 4: Run tests** — `flutter test` → all pass; `flutter analyze` → no issues.

- [ ] **Step 5: Commit** — `perf(gallery): decode item pictures at tile size`.

---

### Task 2: Lazy gallery above 120 items

**Files:**
- Create: `lib/blocks/gallery/lazy_grid.dart`
- Modify: `lib/blocks/gallery/gallery_block.dart` (`_grid`, plain and grouped branches), `lib/blocks/gallery/layouts.dart` (expose the panel decoration)
- Modify: `test/helpers.dart` (big fixture helper)
- Test: `test/blocks/gallery_lazy_test.dart`
- Docs: `docs/CAPABILITIES.md` gallery row, `docs/ARCHITECTURE.md` gallery tree

**Interfaces:**
- Produces: `const int kReflowLimit = 120;` in `gallery_block.dart`.
- Produces: `Widget lazyGridSliver({required List<Item> items, required int columns, required double aspect, required double extraHeight, required Widget Function(Item) tileBuilder})` in `lazy_grid.dart`: a `SliverGrid` with `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisSpacing: ReflowGrid.defaultRunSpacing, crossAxisSpacing: ReflowGrid.defaultSpacing, childAspectRatio: tileW / tileH)` where `tileW/tileH` come from `ReflowGrid.tileWidth/tileHeight` so `ReflowGrid.heightFor` stays correct for rail offsets.
- Produces: `BoxDecoration sectionPanelDecoration(Palette p, {required bool active})` in `layouts.dart`, the exact decoration `SectionPanel` paints, so the lazy grouped layout can draw it with `DecoratedSliver`.
- Produces in `test/helpers.dart`: `Future<LoadedModule> loadBig({int count = 600, void Function(Map<String, dynamic> manifest)? edit})` → the mini manifest with `collections.items.items` replaced by an inline list of `count` text-only items `{id: 'c$i', name: 'Card $i', family: i.isEven ? 'fire' : 'water', cost: i % 13, level: 1 + i % 9, effects: [{type: 'active', text: 'Effect $i'}]}` and no `image` field.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('600 items: only tiles near the viewport are built', (tester) async {
  await pumpModules(tester, load: () async => [await loadBig()]);
  expect(find.byType(AnimatedPositioned), findsNothing, reason: 'no reflow grid above kReflowLimit');
  expect(find.byType(ItemTile, skipOffstage: false).evaluate().length, lessThan(100));
  await tester.fling(find.byType(CustomScrollView), const Offset(0, -4000), 3000);
  await tester.pumpAndSettle();
  expect(find.text('Card 599', skipOffstage: false), findsNothing); // still lazy, not at the end yet
});

testWidgets('600 items grouped by cost: rail jump lands on the section header', (tester) async {
  await pumpModules(tester, load: () async => [await loadBig()]);
  await tester.tap(find.bySemanticsLabel('Family Fire')); // sections are onlyWhenFiltered in the mini manifest
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel(RegExp(r'Cost 7')));
  await tester.pumpAndSettle();
  final header = tester.getTopLeft(find.text('COST 7'));
  expect(header.dy, lessThan(200));
});

testWidgets('mini module (4 items) still uses the gliding grid', (tester) async {
  await pumpModules(tester);
  expect(find.byType(AnimatedPositioned), findsNWidgets(4));
});
```

(Check the rail's semantics label in `rail.dart` and adjust the `RegExp` to what it emits.)

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/blocks/gallery_lazy_test.dart`.

- [ ] **Step 3: Implement.** In `_grid`: `final lazy = shown.length > kReflowLimit;`. Plain branch when lazy: `CustomScrollView(controller: _scroll, slivers: [SliverPadding(padding: _pad.copyWith(top: 8, right: 16), sliver: lazyGridSliver(...))])`. Grouped branch when lazy: per section `SliverMainAxisGroup([SliverPersistentHeader(pinned, SectionHeader…), DecoratedSliver(decoration: sectionPanelDecoration(p, active: k == activeKey), sliver: SliverPadding(padding: kGroupPad, sliver: lazyGridSliver(items…)))])` followed by a `SliverToBoxAdapter(SizedBox(height: _sectionGap))`; keep the `_sectionOffsets`/`_sectionSpans` arithmetic (same `heightFor`). Flowing layout: when lazy, fall through to grouped (ignore `Settings.flowingSections`).

- [ ] **Step 4: Run tests** — `flutter test`; `flutter test tool/screenshot_test.dart`; look at `design/screenshots/01_cards_all.png` and `08`: identical to before (Vale has 70 items).

- [ ] **Step 5: Docs.** `docs/CAPABILITIES.md` gallery row: replace the "Not lazy…" sentence with "Lazy above 120 shown items (no glide animation there); gliding grid at or below." Update "Last synced with" to 3.2.0-dev and add a change-log line. `docs/ARCHITECTURE.md` gallery tree: add the `lazy` branch.

- [ ] **Step 6: Commit** — `perf(gallery): lazy sliver grid above 120 items`.

---

### Task 3: Streaming zip install and raised limits

**Files:**
- Modify: `lib/library/module_store.dart` (limits, `installFile`, `_unzipStream`)
- Modify: `lib/library/install_sources.dart`, `lib/library/library_controller.dart`, `lib/library/repository.dart` (`RepoClient.download`)
- Test: `test/library/module_store_test.dart`, `test/library/repository_test.dart`
- Docs: `modules/MODULE_SPEC.md` limits line, `docs/CAPABILITIES.md` size row

**Interfaces:**
- Produces: `sealed class ModuleSource { }` with `class FileSource extends ModuleSource { final File file; }` and `class BytesSource extends ModuleSource { final Uint8List bytes; }` in `module_store.dart`.
- Produces: `Future<InstalledModule> ModuleStore.install(ModuleSource src, {Map<String, String> Function(Uri)? headersFor})`. `BytesSource` → existing `installBytes`. `FileSource` whose first four bytes are `PK\x03\x04` → `_unzipStream(File, Directory staging)`; otherwise reads the file (single JSON) into `installBytes`.
- `_unzipStream`: `final input = InputFileStream(file.path); final archive = ZipDecoder().decodeStream(input);` then for each entry apply today's checks (`safeEntryPath`, `allowedExtensions`, `maxFileBytes` on `f.size`, running `maxTotalBytes`), write with `f.writeContent(OutputFileStream(_staged(staging, path).path))` (or `OutputFileStream` + `f.content` per entry if `writeContent` is unavailable in 4.5), then `input.close()`. Reject before reading when `file.lengthSync() > maxZipBytes`. The whole zip is never held in a `Uint8List`.
- `InstallSources.pickModuleFile()` → `Future<ModuleSource?>`: `FileSource(File(f.path!))` when the picked file has a path, else `BytesSource(await f.xFile.readAsBytes())`.
- `InstallSources.downloadLink(Uri, {headersFor})` → `Future<ModuleSource>`: `client.send(http.Request('GET', url)..headers.addAll(...))`, pipe `response.stream` into a temp file under `Directory.systemTemp` (name `bb-<micros>.bin`), return `FileSource`; non-200 → `InstallException('That link answered HTTP <code>')` as today.
- `InstallSources.sharedFiles()` → `Stream<ModuleSource>` yielding `FileSource` (drop the `maxZipBytes` pre-check there; the store checks).
- `RepoClient.download(Uri)` → `Future<ModuleSource>` via the same streaming download.
- `LibraryController.installBytes(Uint8List…)` stays for tests; add `Future<InstalledModule?> installSource(ModuleSource src, {bool open = false, String? label})` and route `installEntry`, `installLink`, `installFromFile`, `listenForSharedFiles` through it. `ModuleStore` deletes a `FileSource` it created from a download after install (controller passes `deleteAfter: true` on `FileSource`, a `final bool temporary` field).

- [ ] **Step 1: Write the failing tests**

```dart
test('installs the mini module from a zip file on disk without reading it whole', () async {
  final zip = File('${parent.path}/mini.zip')..writeAsBytesSync(zipOf(miniFiles()));
  final store = ModuleStore(root);
  final m = await store.install(FileSource(zip));
  expect(m.id, 'mini');
  expect(File('${m.dir!.path}/data/items.json').existsSync(), isTrue);
});

test('a zip of the folder itself (prefix/module.json) is refused with the same message', () async {
  final zip = File('${parent.path}/nested.zip')
    ..writeAsBytesSync(zipOf({for (final e in miniFiles().entries) 'mini/${e.key}': e.value}));
  expect(() => ModuleStore(root).install(FileSource(zip)),
      throwsA(predicate((e) => e is InstallException && e.message == 'This zip has no module.json at its root')));
  expect(Directory('${root.path}/.staging').listSync(), isEmpty, reason: 'staging cleaned up');
});

test('limits: 250 MB zip, 600 MB unpacked, 15 MB per file', () {
  expect(ModuleStore.maxZipBytes, 250 * 1024 * 1024);
  expect(ModuleStore.maxTotalBytes, 600 * 1024 * 1024);
  expect(ModuleStore.maxFileBytes, 15 * 1024 * 1024);
});
```

Plus in `repository_test.dart`: `download` returns a `FileSource` whose file holds the served bytes.

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/library/`.
- [ ] **Step 3: Implement** the interfaces above. Existing `installBytes` tests keep passing untouched.
- [ ] **Step 4: Run** — `flutter test`, `flutter analyze`.
- [ ] **Step 5: Docs.** `MODULE_SPEC.md` "Limits: zip 250 MB, unpacked 600 MB, any one file 15 MB." Same in `docs/CAPABILITIES.md` size row and change log.
- [ ] **Step 6: Commit** — `feat(install): stream zips from disk; limits 250 MB zip, 600 MB unpacked`.

---

### Task 4: `hub` block (menu page with pushed sub-screens)

**Files:**
- Modify: `lib/module_format/block_specs.dart` (`HubSpec`, `HubEntrySpec`, `blockParsers`), `lib/module_format/validator.dart` (`checkBlock`, entry images), `lib/blocks/registry.dart`
- Create: `lib/blocks/hub_block.dart`
- Modify: `lib/core/app_state.dart` (find flows inside hubs), `lib/main.dart` (badge) — none; badges stay tab-level
- Test: `test/module_format/block_specs_test.dart`, `test/module_format/validator_test.dart`, `test/blocks/hub_block_test.dart`
- Docs: `modules/MODULE_SPEC.md` (`### hub`, `### entry`), `modules/module.schema.json` (`blockType` enum + hub/entry branches), `modules/AI_INSTRUCTIONS.md` (one paragraph, keep ≤ 24000 chars), `docs/CAPABILITIES.md`, `docs/ARCHITECTURE.md` registry table

**Interfaces:**
- JSON: `{"type": "hub", "title": "Cards", "children": [{"type": "entry", "label": "Abilities", "icon": "cards", "image": "images/abilities.webp", "summary": "500 ability cards", "block": {…}}]}`. `icon` defaults `grid`; `image` optional image ref (shown instead of the icon when present); `summary` optional.
- Produces: `class HubSpec extends BlockSpec { String get type => 'hub'; final String title; final List<HubEntrySpec> entries; static HubSpec fromJson(Map<String,dynamic> j, String where); }` — `title` default `'Menu'`; children must all be `entry` (else `SpecFormatException(c.where, 'A hub holds only entries, not "$t"')`); at least one entry (`f.fail('children', 'A hub needs at least one entry')`).
- Produces: `class HubEntrySpec extends BlockSpec { String get type => 'entry'; final String label; final String icon; final String? image; final String? summary; final BlockSpec block; }`.
- `blockParsers` gains `'hub'` and `'entry'`; registry: `'hub' => HubBlock`, `'entry' => null` (data, like `step`).
- Produces: `Iterable<BlockSpec> walkBlocks(BlockSpec root)` in `block_specs.dart`: depth-first over hub entries' blocks (and the root). Used by the validator and by `OpenGame.load`.
- Validator `checkBlock`: `case HubSpec h:` → `checkImage('$path.children[$i].image', e.image)` and recurse `checkBlock('$path.children[$i].block', e.block)`; the flow counter counts nested flows too.
- `OpenGame.load`: find the first `FlowSpec` with `for (final t in tabs) for (final b in walkBlocks(t.block))`.
- Widget `HubBlock(spec)`: header row (`GameSwitcherButton`, title in `T.title`), then a `ListView` of `_HubTile` (56 dp leading: `Image` from `module.files.image(entry.image)` or `Icon(moduleIcon(entry.icon))`; label `T.body` bold; summary `p.text2`; trailing chevron). Tap → `Navigator.of(context).push(MaterialPageRoute(builder: (_) => HubScreen(entry: entry)))`. `HubScreen`: `Scaffold(appBar: AppBar(title: Text(entry.label), leading: BackButton), body: SafeArea(child: buildBlock(context, entry.block)))`. Providers come from `ModuleScope` above the Navigator (already the case).

- [ ] **Step 1: Write the failing tests**

```dart
// block_specs_test.dart
test('hub parses entries and refuses non-entry children', () {
  final h = BlockSpec.fromJson({'type': 'hub', 'title': 'Cards', 'children': [
    {'type': 'entry', 'label': 'All', 'block': {'type': 'text', 'title': 'x'}}]}, 'tabs[0].block') as HubSpec;
  expect(h.entries.single.label, 'All');
  expect(h.entries.single.icon, 'grid');
  expect(() => BlockSpec.fromJson({'type': 'hub', 'children': [{'type': 'text'}]}, 'b'),
      throwsA(isA<SpecFormatException>().having((e) => e.message, 'message', contains('holds only entries'))));
  expect(() => BlockSpec.fromJson({'type': 'hub', 'children': []}, 'b'),
      throwsA(isA<SpecFormatException>().having((e) => e.path, 'path', 'b.children')));
});

// validator_test.dart
test('a gallery inside a hub entry must name a real collection; entry images are checked', () { /* unknown collection → ERROR tabs[0].block.children[0].block.collection; image "../x.png" → ERROR tabs[0].block.children[0].image */ });

// hub_block_test.dart
testWidgets('hub lists entries; tapping opens the entry block with a back arrow', (tester) async {
  await pumpModules(tester, edit: (m) {
    m['tabs'] = [
      {'label': 'Menu', 'icon': 'grid', 'block': {'type': 'hub', 'title': 'Cards', 'children': [
        {'type': 'entry', 'label': 'Gallery', 'summary': 'All cards', 'block': (m['tabs'] as List)[0]['block']},
        {'type': 'entry', 'label': 'Rules', 'block': {'type': 'text', 'title': 'Rules', 'paragraphs': ['Hello']}},
      ]}},
      (m['tabs'] as List)[1],
    ];
  });
  expect(find.text('All cards'), findsOneWidget);
  await tester.tap(find.text('Rules'));
  await tester.pumpAndSettle();
  expect(find.text('Hello'), findsOneWidget);
  await tester.tap(find.byType(BackButton));
  await tester.pumpAndSettle();
  expect(find.text('All cards'), findsOneWidget);
  await tester.tap(find.text('Gallery'));
  await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('Imp'));
  await tester.pumpAndSettle();
  expect(find.byType(ItemSheet), findsOneWidget, reason: 'sheets open from a pushed screen');
});
```

- [ ] **Step 2: Run, expect FAIL** — `flutter test test/module_format test/blocks/hub_block_test.dart`.
- [ ] **Step 3: Implement** specs, validator, registry, `walkBlocks`, `OpenGame.load`, `HubBlock`/`HubScreen`.
- [ ] **Step 4: Run** — `flutter test` (the `registry_test` that checks every `kBlockTypes` has a builder or is data must pass), `flutter analyze`, `flutter test tool/screenshot_test.dart`.
- [ ] **Step 5: Docs.** Spec sections for `hub` and `entry` with the JSON above; schema `blockType` enum adds `hub`, `entry`, with `if/then` branches (`hub`: `title`; `entry`: required `label`, `block`, optional `icon`, `image`, `summary`); AI instructions: a paragraph under Blocks; `docs/CAPABILITIES.md` blocks table row + tabs paragraph ("a hub entry costs no tab"); `docs/ARCHITECTURE.md` registry table.
- [ ] **Step 6: Commit** — `feat(blocks): hub block with pushed entry screens`.

---

### Task 5: Gallery drill-down groups, tile subtitle, number keypad, dock picker

**Files:**
- Modify: `lib/module_format/block_specs.dart` (`GroupsSpec`, `GallerySpec` fields), `lib/module_format/validator.dart`
- Modify: `lib/blocks/gallery/gallery_block.dart`, `lib/blocks/gallery/filter_dock.dart`, `lib/blocks/item_tile.dart`, `lib/core/widgets/search_top_bar.dart`
- Test: `test/module_format/block_specs_test.dart`, `test/module_format/validator_test.dart`, `test/blocks/gallery_groups_test.dart`, `test/blocks/gallery_block_test.dart`
- Docs: `MODULE_SPEC.md` gallery section, schema gallery branch, AI instructions gallery line, `docs/CAPABILITIES.md` gallery row

**Interfaces:**
- JSON on `gallery`: `"groups": {"path": "class", "by": "classes", "noun": "classes"}`, `"tileSubtitle": "{initiative}"`, `"searchKeyboard": "number"`.
- Produces: `class GroupsSpec { final String path; final String by; final String noun; static GroupsSpec fromJson(Map, String where); }` (`noun` default `'groups'`). `GallerySpec` gains `final GroupsSpec? groups; final String? tileSubtitle; final String searchKeyboard;` (`searchKeyboard` default `'text'`; any value other than `text`/`number` → `f.fail('searchKeyboard', 'Should be "text" or "number"')`).
- Validator: `requireCollection('$path.groups.by', g.groups!.by)`; non-fatal warning `collections.<coll>: N items whose "<path>" names no item of "<by>"` when any item's group value is not an id in the `by` collection (count them in `checkModule`, which has the item lists).
- `ItemTile` gains `final String? subtitle; final VoidCallback? onTap;` — `onTap` replaces opening the sheet when given; `subtitle` adds one line (`nameSize`, `p.text2`, weight 500) under the name. Produces `static double textHeight({required bool name, required bool subtitle})` = `6 + (name ? nameLines : 0) * nameSize * nameLineHeight + (subtitle ? nameSize * nameLineHeight : 0)` (0 when neither). `nameHeight` stays as the `name: true, subtitle: false` value. Gallery passes `extra = ItemTile.textHeight(name: _g.tileName, subtitle: _g.tileSubtitle != null)` everywhere it used `extra` (plain, grouped, flowing, lazy).
- `SearchTopBar` gains `final TextInputType keyboardType;` (default `TextInputType.text`), passed to the `TextField`.
- Gallery group state: `Object? _group;`. Rules: with `groups` set and `_group == null` and the search box empty → **group screen**: the grid shows `module.items(groups.by)` as `ItemTile(onTap: () => setState(() => _group = it.id), collection: bySpec, showName: true)`; filters and sections are not shown on the group screen; the count noun is `groups.noun`. With `_group != null` → the normal gallery over `shown.where(item => resolvePath(item.data, groups.path).any((v) => '$v' == _group))`, plus a `_GroupBar` under the search bar: 32 dp thumbnail of the group item, its title, and a `TextButton('All ${groups.noun}')` that sets `_group = null` (also clears `_picked`/`_activeSection`, jumps to 0). With a non-empty search box the search runs over **all** items regardless of `_group` (the `_GroupBar` stays if set).
- `FilterDock`: when `filter.options.length > kDockPickerLimit` (`const kDockPickerLimit = 8;` in `filter_dock.dart`) render `_DockPickerButton`: full-width pill reading `'${filter.label}: ${selectedLabel ?? filter.allLabel}'` with a `▾`; tap → `showModalBottomSheet` containing a `TextField` (hint `'Search ${filter.label.toLowerCase()}'`), then a `GridView` of options (All first, then options filtered by the typed text, each a 64 dp symbol-or-initial circle + label); tapping an option calls `onPick` and pops. Semantics labels stay `'${filter.label} ${o.label}'` so existing tests and the picker share one vocabulary.

- [ ] **Step 1: Write the failing tests**

```dart
// gallery_groups_test.dart
Future<AppState> pumpGrouped(WidgetTester tester) => pumpModules(tester, edit: (m) {
  m['collections']['families'] = {'items': [
    {'id': 'fire', 'name': 'Fire', 'image': 'images/fire.webp'},
    {'id': 'water', 'name': 'Water', 'image': 'images/water.webp'}]};
  final g = (m['tabs'] as List)[0]['block'] as Map;
  g['groups'] = {'path': 'family', 'by': 'families', 'noun': 'families'};
  g['tileSubtitle'] = '{cost}';
  g['searchKeyboard'] = 'number';
  g.remove('filters');
});

testWidgets('group screen first, then that group, then back to all groups', (tester) async {
  await pumpGrouped(tester);
  expect(find.bySemanticsLabel('Fire'), findsOneWidget);
  expect(find.bySemanticsLabel('Imp'), findsNothing);
  await tester.tap(find.bySemanticsLabel('Fire'));
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Imp'), findsOneWidget);
  expect(find.bySemanticsLabel('Nessie'), findsNothing);
  await tester.tap(find.text('All families'));
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Water'), findsOneWidget);
});

testWidgets('search spans every group; the keypad is numeric; tiles show the subtitle', (tester) async {
  await pumpGrouped(tester);
  expect(tester.widget<TextField>(find.byType(TextField)).keyboardType, TextInputType.number);
  await tester.enterText(find.byType(TextField), 'nessie');
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Nessie'), findsOneWidget);
  await tester.tap(find.bySemanticsLabel('Nessie'));
  await tester.pumpAndSettle();
  expect(find.byType(ItemSheet), findsOneWidget);
  await tester.tap(find.byType(ItemSheet).first, warnIfMissed: false); // close as other tests do
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '');
  await tester.tap(find.bySemanticsLabel('Fire'));
  await tester.pumpAndSettle();
  expect(find.descendant(of: find.byType(ItemTile), matching: find.textContaining(RegExp(r'^\d+$'))), findsWidgets);
});

// gallery_block_test.dart
testWidgets('a dock with more than 8 options becomes a picker button opening a searchable sheet', (tester) async {
  await pumpModules(tester, edit: (m) {
    final f = (m['tabs'] as List)[0]['block']['filters'][0] as Map;
    f['options'] = [for (var i = 0; i < 12; i++) {'value': 'fam$i', 'label': 'Family $i'}];
  });
  expect(find.text('Family: All families'), findsOneWidget);
  await tester.tap(find.text('Family: All families'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Search family'), '11');
  await tester.pumpAndSettle();
  expect(find.bySemanticsLabel('Family Family 11'), findsOneWidget);
  expect(find.bySemanticsLabel('Family Family 1'), findsNothing);
  await tester.tap(find.bySemanticsLabel('Family Family 11'));
  await tester.pumpAndSettle();
  expect(find.text('Family: Family 11'), findsOneWidget);
});

// validator_test.dart
test('groups.by must exist; items with a group value naming no group give a warning', () {
  // by: 'nope' → ERROR tabs[0].block.groups.by Unknown collection "nope"
  // one item with family 'lava' and families [fire, water] → WARN collections.items: 1 item whose "family" names no item of "families"
});
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement** spec, validator, `ItemTile`, `SearchTopBar`, gallery group screen and `_GroupBar`, `FilterDock` picker.
- [ ] **Step 4: Run** — `flutter test`, `flutter analyze`, `flutter test tool/screenshot_test.dart`; Vale screenshots unchanged (five families, no groups, no subtitle).
- [ ] **Step 5: Docs.** Spec gallery section: `groups`, `tileSubtitle`, `searchKeyboard`, picker behaviour ("more than 8 options become a picker"); schema; AI instructions one line each; `docs/CAPABILITIES.md` gallery row and change log.
- [ ] **Step 6: Commit** — `feat(gallery): drill-down groups, tile subtitle, number keypad, option picker`.

---

### Task 6: Zone actions (`moveZone`, `clearZones`) and the `inZone` filter rule

**Files:**
- Modify: `lib/modules/module_state.dart` (`moveAll`), `lib/module_format/filter.dart` (`inZone`), `lib/module_format/block_specs.dart` (`ChecklistAction`), `lib/module_format/validator.dart`, `lib/blocks/flow/flow_block.dart` (`runChecklistAction`, default labels), `lib/blocks/board_block.dart:955-962` and `lib/blocks/flow/flow_block.dart:150-157` (pass `zoneOf`)
- Test: `test/modules/state_test.dart`, `test/module_format/filter_test.dart`, `test/module_format/block_specs_test.dart`, `test/module_format/validator_test.dart`, `test/blocks/flow_block_test.dart`, `test/blocks/board_block_test.dart`
- Docs: spec (Filters paragraph, `step` actions), schema (`filter.where` items gain `inZone`; `checklistRow.action` `oneOf` gains two branches), AI instructions, `docs/CAPABILITIES.md` zones + step rows

**Interfaces:**
- Produces: `void ZoneState.moveAll(Iterable<String> from, String to)` — every item whose zone is in `from` gets zone `to`, order preserved, one save and notify. No-op (no save) when nothing moved.
- `FieldRule` gains `final String? inZone;` and its `matches` becomes `bool matches(Map<String, dynamic> item, {String? Function(String id)? zoneOf})`: when `inZone != null`, at least one resolved value `v` must satisfy `zoneOf?.call('$v') == inZone`. `ItemFilter.matches(Map item, String? itemZone, {String? Function(String id)? zoneOf})` forwards. `FieldRule.fromJson` fails with `'A rule needs "has", "equals" or "inZone"'` when all three are absent. Callers in `board_block.dart` and `flow_block.dart` pass `zoneOf: zones.zoneOf` (they already `watch` `ZoneState`).
- `kChecklistActions = {'clearZone', 'newGame', 'moveZone', 'clearZones'}`. `ChecklistAction` gains `final List<String> from; final String? to; final List<String> zones;`. Parse: `moveZone` needs `to` (text) and `from` (text or list of text, else `f.fail('from', 'Should be a zone id or a list of zone ids')`); `clearZones` needs `zones` (non-empty text list).
- Validator `checkStep`: zone ids in `from`, `to`, `zones` all checked (`Unknown zone "x"`).
- `runChecklistAction`: `moveZone` → `zones.moveAll(action.from, action.to!)`, returns true; `clearZones` → `for z in action.zones: clearZone(z)` (one snackbar with Undo is not required), returns true. Default pill labels in `_ChecklistRowView`: `moveZone` → `'Move'`, `clearZones` → `'Clear'`.

- [ ] **Step 1: Write the failing tests**

```dart
// state_test.dart
test('moveAll moves items from several zones into one, keeping order', () async {
  final z = ZoneState(await SharedPreferences.getInstance(), 'mini');
  z..put('a', 'hand')..put('b', 'discard')..put('c', 'lost')..put('d', 'pool');
  z.moveAll(['hand', 'discard', 'lost'], 'pool');
  expect(z.idsIn('pool'), ['a', 'b', 'c', 'd']);
  expect(z.count('hand') + z.count('discard') + z.count('lost'), 0);
});

// filter_test.dart
test('inZone keeps items whose field names an item currently in that zone, lists included', () {
  final f = ItemFilter.fromJson({'where': [{'path': 'monster', 'inZone': 'inplay'}]});
  String? zoneOf(String id) => id == 'archer' ? 'inplay' : null;
  expect(f.matches({'monster': 'archer'}, null, zoneOf: zoneOf), isTrue);
  expect(f.matches({'monster': ['guard', 'archer']}, null, zoneOf: zoneOf), isTrue);
  expect(f.matches({'monster': 'guard'}, null, zoneOf: zoneOf), isFalse);
  expect(() => FieldRule.fromJson({'path': 'x'}), throwsA(isA<SpecFormatException>()));
});

// block_specs_test.dart
test('moveZone and clearZones actions parse; moveZone needs "to"', () { /* from as text and as list; missing to → SpecFormatException at ….action.to */ });

// flow_block_test.dart
testWidgets('a moveZone row moves Lane A into Lane B and ticks itself', (tester) async {
  await pumpModules(tester, tab: 'Flow', edit: (m) {
    final step = (m['tabs'] as List)[2]['block']['children'][0] as Map;
    (step['checklist'] as List).add({'id': 'one.move', 'text': 'Return cards',
      'action': {'type': 'moveZone', 'from': ['a'], 'to': 'b'}});
  });
  final zones = scoped<ZoneState>(tester)..put('imp', 'a');
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ActionChip, 'Move').first);  // adjust to the pill widget type used by _ActionPill
  await tester.pumpAndSettle();
  expect(zones.zoneOf('imp'), 'b');
});

// board_block_test.dart (cardList tab)
testWidgets('a cardList with an inZone rule follows the tracked zone live', (tester) async {
  // add a tab {type: cardList, collection: items, filter: {where: [{path: 'family', inZone: 'b'}]}} and a collection 'families'
  // put 'fire' (a families item id) in zone b → the list shows Imp (family fire); remove → empty text
});
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** — `flutter test`, `flutter analyze`.
- [ ] **Step 5: Docs.** Spec: Filters paragraph gains `inZone`; `step` actions gain the two new shapes with the Gloomhaven example ("Return Discard, Lost and Active to Owned"). Schema. AI instructions. `docs/CAPABILITIES.md` zones row ("bulk move" no longer a cannot), step row, filter rule list, change log.
- [ ] **Step 6: Commit** — `feat(zones): moveZone and clearZones actions; inZone filter rule`.

---

### Task 7: Several flows per module

**Files:**
- Modify: `lib/module_format/block_specs.dart` (`FlowSpec.id`), `lib/module_format/validator.dart` (unique flow ids instead of one flow), `lib/core/app_state.dart` (`OpenGame.flows`), `lib/blocks/registry.dart` (`ModuleScope`), `lib/blocks/flow/flow_block.dart` (state lookup, `confirmNewGame`), `lib/main.dart` (`ModuleScope` call site)
- Test: `test/module_format/validator_test.dart`, `test/core/` (new `open_game_test.dart`), `test/blocks/flow_block_test.dart`
- Docs: spec `flow` section ("several flows, each with an `id`"), schema (`id` on flow), AI instructions, `docs/CAPABILITIES.md` flow row

**Interfaces:**
- `FlowSpec` gains `final String id;` (JSON `id`, default `'flow'`).
- Validator: remove `'A module can have only one flow'`; collect flow ids over `walkBlocks` of every tab; a repeat → `fatal(path, 'Flow id "$id" is used twice; give each flow its own id')`.
- Produces: `class FlowStates { FlowStates(this.byId); final Map<String, FlowState> byId; FlowState? get first; FlowState? operator [](String id); void resetAll(); }` in `flow_state.dart`.
- `OpenGame` gains `final FlowStates flows;` (keep `FlowState? get flow => flows.first` for existing callers/tests). `OpenGame.load`: walk tabs with `walkBlocks`; the **first** flow found gets `prefix: 'mod.$id.'` (today's keys), every later one `prefix: 'mod.$id.flow.${f.id}.'`.
- `ModuleScope` takes `required FlowStates flows` and provides `Provider<FlowStates>.value`; it no longer provides a bare `FlowState`. `FlowBlock.build` wraps its body in `ChangeNotifierProvider<FlowState>.value(value: context.read<FlowStates>()[spec.id]!)` and `Provider<FlowSpec>.value(value: spec)` so `confirmNewGame`, `runChecklistAction`, `_NextButton` and `stepItems` keep reading `FlowState`/`FlowSpec` as today. `confirmNewGame` resets **all** flows: `context.read<FlowStates>().resetAll()` after `clearAll()`.
- `LibraryController.uninstall` already removes every `mod.<id>.` key, which covers the new prefixes.

- [ ] **Step 1: Write the failing tests**

```dart
// validator_test.dart
test('two flows are allowed when their ids differ; same id (or both default) is an error', () {
  // two flow tabs, ids 'scenario' and 'round' → no fatal issues
  // two flow tabs without ids → ERROR tabs[1].block: Flow id "flow" is used twice; give each flow its own id
});

// core/open_game_test.dart
test('the first flow keeps the legacy keys, a second flow gets its own prefix', () async {
  SharedPreferences.setMockInitialValues({'mod.mini.phase.index': 1});
  final module = await loadMini(edit: (m) => (m['tabs'] as List).add({'label': 'Scenario', 'icon': 'flag',
    'block': {'type': 'flow', 'id': 'scenario', 'cyclic': false, 'children': [
      {'type': 'step', 'id': 's1', 'title': 'Setup'}, {'type': 'step', 'id': 's2', 'title': 'Play'}]}}));
  final g = OpenGame.load(await SharedPreferences.getInstance(), module);
  expect(g.flows.first!.index, 1, reason: 'legacy key read by the first flow');
  g.flows['scenario']!.next(const []);
  expect((await SharedPreferences.getInstance()).getInt('mod.mini.flow.scenario.phase.index'), 1);
  expect((await SharedPreferences.getInstance()).getInt('mod.mini.phase.index'), 1, reason: 'untouched');
});

test('a flow inside a hub gets a FlowState', () async { /* hub tab whose entry block is a flow with id 'inner'; expect g.flows['inner'] isNotNull */ });

// flow_block_test.dart
testWidgets('New game from the second flow resets both flows and clears zones', (tester) async { /* two flow tabs; advance both; open 'Scenario' tab, ⋮ → New game → confirm; both indexes 0, zones.total 0 */ });
```

- [ ] **Step 2: Run, expect FAIL.**
- [ ] **Step 3: Implement.** Update `test/games/vale_module_test.dart` only if it constructs `ModuleScope`/`OpenGame` directly.
- [ ] **Step 4: Run** — `flutter test` (existing flow tests must pass unchanged: they read `FlowState` inside the flow tab), `flutter analyze`.
- [ ] **Step 5: Docs.** Spec `flow`: "A module may have several flows; give each an `id`. The first flow in tab order keeps its progress across updates." Schema `id`. AI instructions. `docs/CAPABILITIES.md` flow row (remove "One flow per module"), saved-state section (`mod.<id>.flow.<flowId>.phase.*`), change log.
- [ ] **Step 6: Commit** — `feat(flow): several flows per module, each with its own saved progress`.

---

### Task 8: Version 3.2.0, end-to-end Gloomhaven-shaped fixture, docs sync, preview

**Files:**
- Modify: `lib/app_version.dart`, `pubspec.yaml`, the test pinning the version constant
- Create: `test/fixtures/big_module.json` (generated once by a small script in this task, committed) — or keep `loadBig` in-memory and add a `gloomlike` edit; decision: **in-memory** via `loadBig(edit:)` to avoid a second fixture folder
- Test: `test/games/big_game_test.dart`
- Docs: `docs/CAPABILITIES.md` ("Last synced with: app 3.2.0", quick fit test paragraph: Gloomhaven-size games now fit; list what still does not: counters, per-instance state), `docs/ARCHITECTURE.md` (hub, flows, `FlowStates`, install stream), `modules/MODULE_SPEC.md` intro mentions `minAppVersion "3.2.0"` for new features, `README.md` one sentence in "Games as modules"
- Modify: `docs/superpowers/specs/2026-10-20-gloomhaven-one-module-design.md` status line → "Implemented in 3.2.0"

**Interfaces:**
- Consumes everything above. The end-to-end module: collections `abilities` (600 items, `class` ∈ 17 ids, `level` 1..9, `initiative` 1..99), `classes` (17), `monsters` (37), `monsterCards` (296, `monster` id, `initiative`), zones `pool, hand, discard, lost, active, inplay`; tabs: hub (Abilities gallery with `groups` by `classes`, Monsters gallery with `groups` by `monsters`, cardList of `monsterCards` with `inZone: inplay` filter), board (five lanes), flow `scenario` (3 steps; cleanup step has `moveZone` from `[hand, discard, lost, active]` to `pool` and `clearZones [inplay]`), flow `round` (cyclic, 4 steps).

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('a Gloomhaven-shaped module: find a card in three taps, track a room, end a scenario', (tester) async {
  await pumpModules(tester, load: () async => [await loadGloomlike()]);
  await tester.tap(find.text('Abilities')); await tester.pumpAndSettle();
  await tester.tap(find.bySemanticsLabel('Class 3')); await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), '42'); await tester.pumpAndSettle();
  expect(find.byType(ItemTile), findsWidgets);
  await tester.tap(find.byType(ItemTile).first); await tester.pumpAndSettle();
  expect(find.byType(ItemSheet), findsOneWidget);
  // track a monster type, see its cards appear in the In play list; run the cleanup step; pool holds the cards
  // assert: zones.count('pool') == what was in hand+discard+lost+active, zones.count('inplay') == 0
});
```

- [ ] **Step 2: Run, expect FAIL** (helper missing).
- [ ] **Step 3: Implement** `loadGloomlike()` in `test/helpers.dart` and bump versions.
- [ ] **Step 4: Run everything** — `flutter test`, `flutter analyze`, `flutter test tool/screenshot_test.dart`; inspect `design/screenshots/*.png` for Vale and Magical Athlete: unchanged.
- [ ] **Step 5: Build and look.** `flutter build web --release`, `dart run tool/pack.dart modules build/web/modules --unpacked`, serve `build/web` with the project's `web-preview` launch config and open it in the browser pane: Vale gallery, My cards, Round, and Magical Athlete look as before. (Per the standing rule: preview after UI changes, unasked.)
- [ ] **Step 6: Docs** as listed; `git status` shows nothing under `modules/vale-of-eternity/` or `modules/magical-athlete/`.
- [ ] **Step 7: Commit** — `chore: Babel Board 3.2.0, big-game fixture, docs synced`.

---

## Self-review notes

- Spec coverage: §1 hub → T4; §2 drill-down, keypad, subtitle, picker → T5; §3 inZone → T6; §4 moveZone/clearZones → T6; §5 several flows → T7; §6 streaming install/limits → T3, lazy gallery → T1–T2; §7 (collapsed sections, tables, links) are **out of Package 2** by the spec's own packaging; "What stays true for Vale" → Global Constraints + T8 step 4–6.
- Names used across tasks: `walkBlocks` (T4, T7), `FlowStates` (T7), `ModuleSource`/`FileSource`/`BytesSource` (T3), `ItemTile.textHeight` (T5), `kReflowLimit` (T2), `kDockPickerLimit` (T5), `loadBig`/`loadGloomlike` (T2, T8).
- Review Focus items are pinned: 1 → T7 hub-flow test, 2 → T7 legacy-key test, 3 → T5 validator warning test, 4 → T6 list-valued inZone test, 5 → T3 nested-zip test.
