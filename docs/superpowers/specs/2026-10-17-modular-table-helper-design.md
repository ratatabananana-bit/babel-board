# Table Helper: modular rewrite (design)

Status: **draft for approval** · 2026-10-17

Owner decisions: the app **ships empty**, and the owner's repository is a **private GitHub repo**.

## 1. Intent

Table Helper is a phone app that helps play board games whose copies the owner can't read
(Chinese editions; the owner reads only English). Today it has two games, Vale of Eternity and
Magical Athlete, and each one is **written into the app as code** (`lib/games/vale`,
`lib/games/magical_athlete`). Every new game means a new app build.

The rewrite turns Table Helper into a **console**. Games stop being code and become
**game modules**: downloadable packages of data that describe the game's screens using a
**fixed set of building blocks** the app already knows how to draw.

**The moment it's for (the owner's words):** at a game shop, friends want to play a game like
*Heat*. The owner asks Claude or ChatGPT to write a module for Heat, downloads it into the app,
and can play right away, **without rewriting the app**.

**Success means:**
- A new game can go from "let's play this" to "it's on my phone" in one AI conversation plus a
  download, with no app rebuild, as long as it only needs the existing blocks.
- Vale of Eternity and Magical Athlete, rebuilt as modules, look and work **the same as today**,
  including every polish detail (see §9), and the owner's saved progress survives.

## 2. Vocabulary (agreed with the owner)

| Word | Meaning |
|---|---|
| **Table Helper** | The app itself, the "console". It has no games built in. |
| **Block** | A tab style: one kind of screen piece with its own behavior, built into the app. |
| **Sub-block** | A block placed inside another block. A tab is a **tree** of blocks (e.g. a Board holds Zones, a Zone holds a Card list). |
| **Game module** | One board game as a downloadable package. It is data only: cards, pictures, rules text, and the block tree for each tab. |
| **Repository** | A place, added to the app by URL, that lists game modules you can install. |
| **Tab** | One block tree shown as a bottom-navigation tab of a game (e.g. Vale's "Cards"). *(Claude's term.)* |
| **Library** | The installed games: the screen for picking a game, like the Switch home screen. *(Claude's term.)* |

## 3. Goals, non-goals, anti-goals

**Goals**
1. A **fixed catalog of blocks** (§5) that together can rebuild both current games exactly.
2. A **game module format** (§6): a zip with a manifest, data, images and a block tree per tab,
   simple enough for an AI to write correctly in one conversation.
3. **Install modules** (§7) from a repository URL, a direct zip URL, or a zip file on the phone.
4. A **Library** to browse installed and available games. The app still **opens straight into
   the last game played** and keeps the game switcher and long-press launcher shortcuts.
5. A **module authoring kit** in the repo: a spec, a JSON Schema, a validator, and both current
   games as worked examples, so "write me a module for Heat" works on the first try (§8).
6. Vale of Eternity and Magical Athlete converted to modules with **no visible change**, published
   to the owner's repository, with saved progress migrated (§10).

**Non-goals (for this rewrite)**
- Downloadable blocks, downloadable code, or an HTML/web-view block. The block set is fixed;
  the owner adds blocks later through app updates.
- Blocks no current game needs (counters, dice, score tracking, timers). They are the likely next
  additions (§5.4), but not built now.
- Accounts, cloud sync, multiplayer, publishing to an app store, iOS.
- Chinese UI text. Still English only, but all game text stays in module data so a translation
  can be added later.

**Anti-goals (a failure even if it technically works)**
- The rebuilt games feel worse than today: lost polish, clumsier drag, lost saved data.
- Modules so complex or fussy that an AI can't write a working one in one go.
- The app needs internet at the table. Installed modules must work fully offline.
- A broken or malicious module crashes the app or reaches outside its own folder.

## 4. Constraints

- **No downloaded code.** Android apps can't load new compiled code. A module is data, and the app
  interprets it with its built-in blocks. This is why the block set is fixed.
- **Personal use.** Modules contain publishers' card art and fan-site images. Repositories must
  not be public (see §7.3).
- **Offline at the table.** Everything a module needs is stored on the phone once installed.
- **Tech stays the same:** Flutter (Android APK sideloaded, plus a web build for preview),
  `provider`, `shared_preferences`, the existing theme (Figtree, dark/light, Palette) and the
  existing tests and screenshot tool. The rewrite happens in this repository, on a branch.
- **Any player count the box supports.** Nothing assumes two players.

## 5. Blocks

Every block is configured in the module with plain JSON settings. The app draws it with the
existing polished widgets. Blocks are either **containers** (they hold sub-blocks) or **pieces**.

### 5.1 Data blocks read: collections

A module declares one or more **collections**: lists of items with fields, e.g. Vale's `cards`
(70 items) or Magical Athlete's `racers` (36). Blocks point at a collection by id. Fields are
free-form JSON per item; the module declares which fields exist, so templates and filters can use
them. Item fields can be text, numbers, lists of text, image paths, or lists of
`{type, text}` effects.

**Symbols:** a module can declare named images (e.g. `fire`, `stone_red`, `effect_active`) and
use them in templates, so Vale's family symbols and stone rows still work.

### 5.2 State blocks write: zones and checks

- **Zones** hold item ids in order (Vale's Table/Hand/Field, Magical Athlete's "This race").
  A module declares its zones with id, label, icon and accent (amber, mint or violet, the
  existing palette, used only for tracking state). An item is in at most one zone per module.
- **Flow position and checks:** which step is current and which checklist items are ticked.
- All state is saved per module id, so modules never share or overwrite each other's progress.

### 5.3 The v1 catalog

The v1 catalog is exactly what the two current games need. Names are the builder's to choose.

**Containers**

| Block | What it does | Holds | Used by today |
|---|---|---|---|
| **Board** | A vertical stack of zones with drag-and-drop between them, a drop bar while dragging (zones plus "Remove"), long-press (touch) and immediate (mouse) drag, auto-scroll, and collapse per zone | Zone | Vale My cards, MA This race |
| **Zone** | One zone's lane: header with icon, label, count and hint, plus how its items are shown | Card list | same |
| **Flow** | Step progress bar, current step, Next button (with "n steps left" and double tap to skip), Rules sheet, ⋮ menu (Setup, New game). Repeating (rounds) or run-once (races then final) | Step | Vale Round, MA Game |
| **Step** | Title, summary, a parchment checklist card, "How this step works" | Checklist, Card list, Text | same |
| **Sections** | Splits a gallery into labeled groups (e.g. by cost) with optional sticky headers and an optional jump rail (tap or press-and-slide) | (configures Gallery) | Vale Cards by cost |

**Pieces**

| Block | What it does | Used by today |
|---|---|---|
| **Gallery** | A grid of item pictures in card shape, with search (over chosen fields), the 4/3/2 density toggle, optional single-select filter docks (e.g. family symbols, cost), a zone ring and band on tracked items, and smooth re-flow | Vale Cards, MA Racers |
| **Item sheet** | The bottom sheet for one item, from a **template**: thumbnail (tap for full size), title, subtitle, chips, icon rows, effect list with icon and label, notes, unverified warning, and zone toggles or an "add to zone" button | both |
| **Card list** | The items currently in a zone, or matching a filter, as mini cards, rows or thumbnails, using a template | Vale lanes, Resolution checklist, MA This race |
| **Checklist** | Items with optional sub-line and an **action pill** (built-in actions: clear a zone, new game) | both |
| **Text** | Paragraphs or bullets (rules, "how it works", key rules sheet) | both |

**Filters** in Card list and Checklist use one small rule language, e.g. "items in zone `field`
whose effects include type `active`". That is how Vale's Resolution checklist works. The builder
picks the syntax; it must be simple enough for an AI to write without examples going wrong.

### 5.4 Not in v1, likely next

Counter (gear, heat, score), Dice, Timer, Player list, and an HTML block as an escape hatch.
They are listed so the format leaves room for them: unknown block types in a module must produce
a clear "this game needs a newer app" message rather than a crash.

## 6. Game module format

A module comes in one of two shapes:

- **Zip** (the full form, used by repositories):

```
module.json            manifest + tabs (block trees)
data/*.json            collections
images/...             card art, symbols, the game's icon
```

- **Single JSON file** (the quick form, for an AI chat on a phone): the same `module.json`
  with its collections **inline** and images given as **links**. *(Claude's call: a chat can
  produce one file but can't pack publisher art into a zip.)*

**Images** may be a path inside the zip or an `https` link. **Links are downloaded once, during
install**, and stored with the module, so the game works offline afterwards. If an image fails to
download, the install still completes and that item shows the **text-only card style**: a clean
card with the name and key fields, a first-class style in Gallery, Card list and Item sheet, not an
error state. *(Claude's call.)*

**`module.json` (shape, not final syntax):**

```json
{
  "format": 1,
  "id": "vale-of-eternity",
  "name": "Vale of Eternity",
  "version": "1.0.0",
  "minAppVersion": "3.0.0",
  "icon": "images/icon.webp",
  "players": "2-4",
  "source": "Official rulebook (Renegade) + valeofeternity.wiki.gg",
  "collections": { "cards": "data/cards.json" },
  "symbols": { "fire": "images/symbols/fire.webp" },
  "zones": [ { "id": "table", "label": "Table", "icon": "table", "accent": "amber" } ],
  "tabs": [
    { "label": "Cards", "icon": "cards", "block": { "type": "gallery", "...": "..." } },
    { "label": "My cards", "icon": "hand", "badge": "zoneCount", "block": { "type": "board", "...": "..." } },
    { "label": "Round", "icon": "flag", "block": { "type": "flow", "...": "..." } }
  ]
}
```

- **Icons** come from a fixed named set in the app (e.g. `cards`, `hand`, `flag`, `run`,
  `table`, `grid`), not from code.
- **Images** are webp/png/jpg: a relative path inside the zip, or an `https` link (see above).
- **`format`** is the module format version; **`minAppVersion`** is the oldest app that can run it.

## 7. Getting modules onto the phone

### 7.1 Install sources
1. **Repository:** the owner adds a repository URL once. The app reads its index and shows the
   available games, with name, icon, version and size. Tap to install.
2. **Direct link:** paste a zip or JSON URL.
3. **File:** open a zip or JSON file from the phone's files or the share sheet. This is the
   main path for a module written in an AI chat on the phone, so build and test it first.
   *(Claude's call.)*

### 7.2 Repository format
A repository is an `index.json` at a URL listing modules: id, name, version, icon URL, zip URL,
size and minAppVersion. It is static files only, with no server code.

### 7.3 Hosting (privacy)
Modules contain copyrighted art, so the repository must not be public. **Decided: a private
GitHub repository.**
- The app stores a GitHub personal access token (read-only, for that repo) and sends it with
  every request to that repository: the index, zips and images. It stores the token securely
  (e.g. `flutter_secure_storage`) and never sends it to any other host.
- The repository screen has fields for the index URL and the token, and shows clear errors for
  "not found" and "token rejected".
- `index.json` lists zip and icon locations **relative to the index**, so the packing script never
  needs to know the token or the URL format.
- Other repositories (no token, public or local) use the same index format.

### 7.4 Install rules
- The app validates every module before installing: zip paths stay inside the module folder;
  only expected file types; size limits; schema check of `module.json` and collections; unknown
  block types or a too-new `format` give a clear message.
- Installing a newer version of an installed module **keeps its saved state**.
- Uninstalling asks first and removes the module's files and state.
- A module that fails to load at startup is skipped and marked broken in the Library. The rest of
  the app still works.

## 8. Authoring kit (for "write me a module for Heat")

**In the app:** a **"Copy instructions for AI"** action in the Library copies a compact module
spec (blocks, fields, filters, the single-file format, and the research rules) to the clipboard, to
paste into Claude or ChatGPT on the phone. It must stay small enough to paste into a chat.
*(Claude's call.)*

**In the repo**, under `modules/`:
- `MODULE_SPEC.md`: a plain-language guide to every block, field and filter, written **for an
  AI to read**. It includes a short checklist: research the official rulebook, never invent card
  text, mark unverified text, use any player count the box supports.
- `module.schema.json`: a JSON Schema, so editors and AIs can validate.
- A **validator** (CLI, also run by the app on install) with human-readable errors.
- `vale-of-eternity/` and `magical-athlete/`: the two converted modules as worked examples.
- A packing script that zips a module folder and updates a repository `index.json`.

## 9. Behavior that must survive the rewrite (from building the current app)

- Cards show in their **printed shape**, never cropped square.
- Two drag recognizers: **immediate for mouse**, **long-press (~220 ms) for touch**, so a finger
  can still scroll. The drop bar includes **Remove**. Auto-scroll near edges.
- Never add or remove a wrapper around a `DragTarget` during a drag (hover flicker bug).
- Item sheets are bottom sheets over the grid; zone buttons toggle (tap again to untrack).
- Jump rail: room after the last section so every section can reach the top; tap **and**
  press-and-slide scrubbing.
- Flow: the parchment checklist leads; Next shows "n steps left" and needs a second tap to skip;
  no warning dialog; New game is in ⋮ behind a red confirm.
- Labels in tight spaces scale down or ellipsize; bottom-nav labels are always visible.
- Providers sit above `MaterialApp` (or wrap the Navigator) so sheets and dialogs can read state.
- Opens into the last game; game switcher in each tab header; long-press launcher shortcuts
  (now generated from installed modules).
- Rules details are checked against the official rulebook, not taken from a design mock.

## 10. Migration

- Vale of Eternity and Magical Athlete become modules in `modules/`. Their data comes from today's
  `assets/` (cards, racers, rules, symbols, art). The packing script publishes both to the
  owner's private repository.
- **The app ships empty (owner's decision).** The APK contains no game data or art.
- **Order of rollout:** the repository is set up with both modules **before** the new APK goes
  on the phone, and the owner knows to add the repository on first launch.
- **First launch after the update:**
  - the Library is empty and leads straight to "Add repository" (and "Install from file")
  - existing saved state (`vale.*`, `ma.*` keys) is **kept, not deleted**. When the matching
    module is installed (`vale-of-eternity` ← `vale.*`, `magical-athlete` ← `ma.*`), the state
    moves into it, so tracked cards and round progress reappear
  - the last-played game is remembered and opens once that module is installed
- `lib/games/` is removed once both modules reproduce today's screenshots
  (`tool/screenshot_test.dart`).

**Web build** *(Claude's call)*: preview only. It shows the modules bundled from `modules/` and
has no install sources, because browsers block most cross-site downloads and have no module
folder. Installing is Android-only.

## 11. Testing

- **Unit:** module parsing and validation (good and bad modules, zip path traversal, unknown
  block, too-new format), filters, zone and flow state, migration.
- **Widget:** each block in isolation with a tiny test module, plus both real modules through
  the existing interaction tests (filters, rail, sheet toggles, drag with touch and mouse, Next
  double tap, game switching, last game on launch).
- **Screenshots:** the existing tool renders both modules. They should match today's images.
- **End to end:** install from a local test repository, from a zip URL, and from a file.

## 12. Left to the builder

The exact JSON syntax of blocks, templates and filters; the filter language; Dart structure (a
block registry mapping type names to widgets is the obvious shape); where modules are stored on
the phone; the Library screen layout (following the existing design language); the validator's
form (Dart CLI is fine); and the order of work. A sensible order: format and registry → rebuild
Vale as a module → Magical Athlete → install sources → Library → authoring kit.

## 13. Decisions log

- The block set is fixed; new blocks come through app updates (owner).
- The app ships empty; games come from the owner's repository (owner).
- The repository is a private GitHub repo read with a token (owner).
- Single-file JSON modules, image links downloaded at install, a text-only card style, "Copy
  instructions for AI", and web as preview-only (Claude's calls, §6–§8, §10).
