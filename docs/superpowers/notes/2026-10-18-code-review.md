# Code review, 2026-10-18 (the snob pass)

Whole codebase read after the UI/UX pass (master 8375a99). Ordered by how much they
matter, not by file. "Fix" lines are concrete; none of this is urgent, the app works and
194 tests pass.

## What is good (so the rest is in proportion)

- The split is right: `module_format` is pure Dart and the tools reuse it; `ModuleFiles`
  is one clean seam between "where bytes come from" and everything else.
- Security is taken seriously where it matters: `isSafeImageRef`, `safeEntryPath`,
  staged installs that swap folders only after validation, the repo token sent to the
  index host only, size caps on zips. The tests cover these.
- Errors reach the person as sentences, never as a silent failure or a crash.
- 194 tests, including the real modules through the real screens.

## 1. The item sheet template is an untyped bag that three places interpret

`CollectionSpec.sheet` is `Map<String, dynamic>`. `SheetSpec` (item_view.dart) parses it in
the widget, `board_block._detailLines` parses it again per row per build, and
`validator.dart` re-describes the same shape in 60 lines of `optText`/`optMap`. Add a key
and you touch three files and the schema. `details`, `swipe`, `effects` are nested maps
with `as` casts inside `build`.

Fix: parse `SheetSpec` (and `EffectsSpec`, `DetailsSpec`) in `manifest.dart` next to
`CollectionSpec`, have `validateModule` call the same parser and report its
`FormatException`s. Same for the block specs below.

## 2. Block specs are parsed by widgets, on every build

`BoardSpec(widget.spec, module)` is built inside `BoardBlock.build`. `StepSpec`,
`CardListSpec`, `FlowSpec` all live in block files and are reconstructed from
`BlockSpec.settings` maps; the validator has a parallel `checkBlock` switch that knows the
same keys. The manifest layer stops at `BlockSpec(type, settings, children)` and hands raw
maps upward.

Fix: a typed spec per block type in `module_format`, parsed once in `loadModule`,
validated by the same code. `blockRegistry` then maps `GallerySpec → GalleryBlock` instead
of re-parsing. `kBlockTypes` and the registry keys stop being two lists.

## 3. Side effects in `build`

- `HelperApp.build` calls `_start(d)` (creates controllers, subscribes to a stream, kicks
  off `library.init()`) when the future resolves. Belongs in `initState` with `.then`.
- `_GalleryBlockState._grid` clears and refills `_sectionOffsets` / `_sectionSpans` during
  build; the scroll listener reads them. Works because build runs before scrolling, but a
  layout-dependent table filled in build is the thing that breaks silently when a padding
  changes. A `LayoutBuilder`-driven model object, or computing spans from render boxes,
  would be honest.

## 4. Heights computed by hand must match widgets by eye

`ReflowGrid` positions tiles absolutely with `tileH = tileW / aspect + extraHeight`.
`ItemTile.nameHeight`, `_FlowCell.rulerH`, `_SectionHeader` 36 vs `_headerH = 36`,
`_Lane.headerH`: every one is a number that has to agree with a widget's real layout.
Two-line names were a one-line change only because the formula was updated with it.

Fix: keep (it is what makes the glide animation cheap), but pin each constant with a
widget test that measures the rendered tile and asserts it equals the formula.

## 5. Two 1000-line files

`item_view.dart` (picture, tile, chip, sheet, gestures, buttons) and `gallery_block.dart`
(grid ×3, rail, dock, cells, headers). Nothing wrong inside, but a new reader scrolls.

Fix: `item_picture.dart`, `item_tile.dart`, `item_sheet.dart`; `gallery/rail.dart`,
`gallery/filter_dock.dart`, `gallery/layouts.dart`.

## 6. `SymbolText` uses `dart:core` `Symbol` as a sentinel and parses its `toString()`

`_nameOf` does `substring(8, length - 2)` on `Symbol("name")`. That format is not
guaranteed by the language. A two-line `_Marker(name)` class, or a sealed `TextPart`,
fixes it and makes `List<Object>` typed.

## 7. Leaked controllers in dialogs

`showRepoDialog` and `showLinkDialog` create `TextEditingController`s that are never
disposed. Small, but it is the kind of thing a snob notices first. Fix: a tiny
`StatefulWidget` per dialog body, or `dispose` in `whenComplete`.

## 8. `AppState.games` is a public mutable field with a `setGames` beside it

`List<OpenGame> games;` plus `setGames(...)` that wraps in `List.unmodifiable`. Pick one:
private field, getter, setter method.

## 9. `_MouseDraggable` wraps `LongPressDraggable`

Two draggables nested, every parameter passed twice, both `onDragStarted` wired. One
`Draggable` with a recognizer that is immediate for mouse and delayed for touch is the
honest version.

## 10. `_Lane` is now a plain class returning slivers

My change today. It reads like a widget (`lane`, `items`, `drag`, `open`) but is not one,
so it does not participate in the element tree (no keys, no `context.watch`). It works
because the board rebuilds on every `_Drag` change anyway. Cleaner: a `SliverMainAxisGroup`
subclass widget, or two small sliver widgets.

## 11. Stale and dead bits

- `ZoneSpec.band` is parsed, validated, documented in `MODULE_SPEC.md`,
  `AI_INSTRUCTIONS.md`, the schema and set by Magical Athlete, but nothing draws it since
  the corner chip replaced the band. Decide: keep as accepted-and-ignored (compat) and
  mark deprecated in the spec, or remove from the format.
- `_NextButton` doc said "amber outline" after the accent change (fixed in this commit).
- `Settings`: `_columns` is cached, every other setting reads prefs on each access. Pick
  one pattern.
- `module_store.safeEntryPath`: `p == '..' || p.isEmpty && n.endsWith('/') == false`
  relies on precedence; parenthesise or rewrite.

## 12. Naming

`T` for the type scale and `p` for the palette are everywhere. Consistent, terse, and
unsearchable. `TextStyles` / `pal` cost nothing. (Low priority; the project reads
fine once you know.)

## 13. Things a snob would ask about and then accept

- `ReflowGrid` builds every tile (no virtualisation). Fine to ~200 items; a 500-card game
  would feel it. Note it in the doc, revisit when a big module shows up.
- `DirectoryModuleFiles.readText` is `async` but reads synchronously, on purpose (tests,
  Windows renames). Documented at the call site; fine.
- `validateModule` is one 400-line function of closures. It is readable top to bottom and
  tested; splitting it only pays off together with items 1 and 2.
- `tool/screenshot_test.dart` hardcodes a Windows Flutter path and font path as fallbacks.
  It is a dev tool for one machine; acceptable, say so in its header.

## If only three things get done

1. Items 1 + 2 together: typed specs in `module_format`, parsed once, validated once.
2. Item 3 first bullet: move `_start` out of `build`.
3. Item 5: split the two big files (mechanical, zero risk, helps every later change).
