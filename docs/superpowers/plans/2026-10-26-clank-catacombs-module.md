# Clank! Catacombs Module Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A data module `modules/clank-catacombs/` that lets a player of the Chinese edition find and read every card, token and tile icon of Clank! Catacombs (base game) and walk the turn, viewable in the web preview and installable on the tablet.

**Architecture:** Data only, no Dart changes. Throwaway node + ffmpeg scripts in the session scratchpad crop the TTS card sheets and the rendered rulebook pages into webp files; three JSON data files (cards, tokens, tiles) are typed by hand from contact sheets and rulebook pages; `module.json` wires three galleries and one flow. `tool/validate.dart` is the test; a small node check script in the scratchpad asserts data invariants the validator does not know (banner enum, image files, counts).

**Tech Stack:** Node 24 (scripts), ffmpeg with libwebp (`E:\AI\Videocationer\ffmpeg\ffmpeg.exe`), Dart SDK 3.11 (`dart run tool/validate.dart`, `tool/pack.dart`), the existing web build in `build/web` served by `.claude/launch.json` `web-preview`.

**Spec:** `docs/superpowers/specs/2026-10-26-clank-catacombs-module-design.md`

## Global Constraints

- Module `id` `clank-catacombs`, `format` 1, `version` "1.0.0", `minAppVersion` "3.2.0", `players` "2-4".
- `cardAspect` 0.72; card pictures 504 by 700 webp quality 80; square pictures 300 by 300 webp; symbols 96 by 96 webp with transparency where the source has it.
- Never invent card text; unreadable text gets `"verified": false`.
- No zones. Four tabs: Cards, Tokens, Tiles, Turn. One flow, `id` `turn`.
- Source material: `E:\AI\BabelBoard\Workshop Item\clank-catacombs-src\` (gitignored). Scripts live in the scratchpad or that folder, never in the repo.
- Starters and Goblin have `cost` 0 so every cost section key is an integer.
- Points field absent when the card prints none; `"?"` when variable.
- English only, short and plain. `:symbol:` wherever the card prints an icon.

## Review Focus

1. A card whose text has several bars (play text + ACQUIRE bar + DEFEAT) must show each as its own effect with the right type label; check Crystal Kobold (monster with a restriction line), Flamboyance (conditional), Skulker (play + acquire). Test in Task 3's check: at least these ids have the expected effect types.
2. The cost rail must list 0 to the real maximum with no text keys: Task 3's check asserts every `cost` is an integer and reports max cost; Task 4 sets `railRange` from it.
3. Filtering by banner must leave no card orphaned: Task 3's check asserts `banner` is one of the five values for every card.
4. A token with no end-game points (e.g. Lockpick minor secret) must not show an empty points chip: Task 4 uses `label`-less chip templates only on fields that exist; Task 3's check asserts `points` is absent or non-empty on tokens.
5. The web preview must show the icon and every picture: Task 6 greps the served folder for every `image` path in the data files.

---

### Task 1: Pictures

**Files:**
- Create: `modules/clank-catacombs/images/cards/<id>.webp` (77), `images/tokens/*.webp`, `images/tiles/*.webp`, `images/symbols/*.webp`, `images/icon.webp`
- Create (scratchpad, throwaway): `make_images.js`, `crops.json`

**Interfaces:**
- Consumes: `Workshop Item\clank-catacombs-src\tts\cards\*.png` and `_index.json` (id, name, deck, idx, copies); `...\pdf\pages\hi_NN.png` (3600 px pages).
- Produces: card file name = card id (`_index.json` id) + `.webp`; token/tile/symbol file names as listed in `crops.json` (`{"out": "images/tokens/adventurer.webp", "page": 17, "x":, "y":, "w":, "h":, "size": 300}`).

- [ ] **Step 1: Card webps.** `node make_images.js cards` runs ffmpeg per card: `scale=504:700:flags=lanczos`, `-c:v libwebp -quality 80`. Expected: 77 files, each 504 by 700 (check with ffprobe in the script, print a count).
- [ ] **Step 2: Locate crops.** View `hi_03`, `hi_06`, `hi_07`, `hi_08`, `hi_10`, `hi_11`, `hi_12`, `hi_17`, `hi_18` and write `crops.json` with one entry per: 13 prisoners, 5 major secrets, 8 minor secrets, 4 market items, artifact (one generic artifact crop reused for the 7 values plus the component-page row), monkey idol, mastery, ghost cube, lockpick, gold; tile icons footprints, monster, lock, one-way (from page 9 or a tile scan), portal, artifact room, plus-artifact, crypt, crystal cave, haunted, chest, library, prison, market, wayshrine, monkey shrine, reward minor secret, reward gold, reward healing; symbols skill, sword, boot, gold, clank (the "Clank!" word mark from a card bar or a cube), heart, draw (a card back), dragon attack, rage arrow, ghost; banner swatches blue/purple/red/yellow/grey from card crops; effect-type symbols from the ACQUIRE / ARRIVE / DANGER / USE / DEFEAT bars and a "Deep" word crop; icon from the cover logo on `hi_01`.
- [ ] **Step 3: Run crops.** `node make_images.js crops` crops and scales each entry to `size`, webp q85. Expected: every `out` exists; the script prints the list and any missing source page.
- [ ] **Step 4: Eyeball.** Read a contact sheet of all token and symbol webps (ffmpeg xstack or tile filter) once; fix any crop that cut an icon.
- [ ] **Step 5: Start tile halves.** From `tts\dl\obj_145_root_Custom_Tile.img` and `obj_147_Custom_Tile_state_Custom_Tile.img` (1300 by 2600) write `images/tiles/start-a-top.webp`, `start-a-bottom.webp`, `start-b-top.webp`, `start-b-bottom.webp` at 600 by 600.
- [ ] **Step 6: Commit** `modules/clank-catacombs/images` with message `feat(clank): pictures for the Clank! Catacombs module`.

### Task 2: Card transcription, first pass

**Files:**
- Create: `modules/clank-catacombs/data/cards.json` (`{"items": [...]}`)

**Interfaces:**
- Produces item shape: `{id, name, banner, subtype?, cost, points?, resources: [symbol...], effects: [{type, text}], dragon: bool, copies, tags: [..], flavour?, verified, image}`; `type` in `play|acquire|arrive|danger|use|defeat|deep`; `banner` in `blue|purple|red|yellow|grey`; `image` = `images/cards/<id>.webp`.

- [ ] **Step 1:** For each of the 8 contact sheets in `tts\contact\sheet_0N.png` (ids per `tts\cards\_groups.json`), read the sheet and append the ten items. Text rules: write resource icons in text as `:skill:`, `:sword:`, `:boot:`, `:gold:`, `:heart:`, `:draw:` (a number before an icon stays a number: "+:skill::skill:" is written as "+2 :skill:" only when the card prints a digit; otherwise repeat the symbol); "Clank!" stays a word; "-OR-" stays; Deep restriction becomes an effect of type `deep` with the parenthesis text. Monsters: `cost` = swords; DEFEAT text is an effect of type `defeat`; a restriction line above DEFEAT ("Fight this only in a Crystal Cave or Wayshrine.") is type `play`. Reserve/starter: `banner` yellow/grey, `cost` 0 for starters and Goblin, printed cost for Explore (3), Mercenary (2), Secret Tome (7). `copies` from `_index.json`.
- [ ] **Step 2:** After every sheet, run `node check.js` (Task 3) and fix what it reports before the next sheet.

### Task 3: Data check script

**Files:**
- Create (scratchpad): `check.js`

- [ ] **Step 1:** `node check.js E:\AI\BabelBoard\modules\clank-catacombs` asserts and prints: card count (77 at the end), unique ids, `banner` in the five values, `cost` integer >= 0, `points` absent or integer or "?", every `effects[].type` in the seven, every `image` file exists, every `:sym:` used in any text is declared in `module.json` symbols (skip until Task 4 exists), tokens: ids unique, `points` absent or non-empty, every image exists; tiles likewise. Prints max cost. Exit 1 on any failure. Also asserts the Review Focus ids: `crystal-kobold` has types `play` and `defeat`, `skulker` has `play` and `acquire`, `flamboyance` has one `play` effect.
- [ ] **Step 2:** Run it; expected: PASS lines, `max cost N`.

### Task 4: Tokens, tiles, module.json

**Files:**
- Create: `data/tokens.json`, `data/tiles.json`, `module.json`

**Interfaces:**
- tokens item: `{id, name, group, points?, text, keep?, tags, verified: true, image}`; `group` label text in display order: "Prisoners", "Major secrets", "Minor secrets", "Market", "Artifacts", "Other".
- tiles item: `{id, name, kind, text, image}`; `kind` "Tunnel icons" or "Rooms".

- [ ] **Step 1: tokens.json** from `cat_17`, `cat_18`, `cat_03` (artifact values 5, 7, 10, 12, 15, 18, 20 as printed on the component page; read them off `hi_03`), `cat_04` / `cat_10` for idol, mastery, ghost, lockpick, gold. `keep` holds the italic "Keep until you use it, then return it to the box." lines.
- [ ] **Step 2: tiles.json** from `cat_07` (tunnel icons), `cat_10`, `cat_11` (rooms, wayshrine), `cat_14` (Depths), plus four start-tile items under kind "Rooms" named "Starting tile, Crypt side top/bottom" and "Starting tile, other side top/bottom" with text from the Crypt and Depths paragraphs.
- [ ] **Step 3: module.json**: header per Global Constraints; `source` "Clank! Catacombs rulebook and Token Reference Guide (Dire Wolf Digital, 2022); card text read from scans"; collections `cards` (card, 0.72, sheet: chips `{"symbol": "banner_{banner}", "text": "{subtype}"}`, `{"text": "Cost {cost}"}`, `{"label": "Points", "text": "{points}"}`, `{"label": "Gives", "symbols": "resources"}`, `{"text": "×{copies} in the deck"}`; effects path `effects` with typeLabels Play/Acquire/Arrive/Danger/Use/Defeat/Deep, typeSymbols `fx_*`, typeHelp sentences from the spec; details hint "Flavour" sections flavour + rulings; verifiedPath), `tokens` (square, sheet: chips `{"text": "{group}"}`, `{"label": "Points", "text": "{points}"}`; sections Effect `text`, "Keep or return" `keep`), `tiles` (square, sections "What it does" `text`); `symbols` map for every file in `images/symbols`; `zones: []`; tabs: `cards` gallery (filters banner dock with five options and `banner_*` symbols, sections cost rail `[0, maxCost]`, search name / effects.text / tags, `tileName` true, noun "cards", searchHint "Name, text, or what you see"), `tokens` gallery (sections by `group`, label "{value}", `tileName` false, search name / text / tags), `tiles` gallery (sections by `kind`, `tileName` false), `turn` flow with setup + steps `play`, `act`, `end`, `out`, `scoring` and the reminders from the spec. Checklist row ids prefixed by step id.
- [ ] **Step 4:** `dart run tool/validate.dart modules/clank-catacombs` → expected `OK` with zero errors (warnings only for `verified: false` items).
- [ ] **Step 5:** `node check.js ...` → PASS including symbol declarations.
- [ ] **Step 6: Commit** `feat(clank): Clank! Catacombs module 1.0.0 (cards, tokens, tiles, turn)`.

### Task 5: Second pass on card text

- [ ] **Step 1:** For each contact sheet, print the ten JSON items (name, cost, points, resources, effects, dragon) next to the sheet and compare line by line; fix typos, missed dragon marks, missed resource icons, wrong banners.
- [ ] **Step 2:** List every item still `verified: false` with the reason in `docs/notes/2026-10-26-clank-catacombs-brainstorm.md` under a "Hand-off" heading.
- [ ] **Step 3:** validate + check again; commit `fix(clank): second-pass corrections to card text`.

### Task 6: Web preview

- [ ] **Step 1:** `dart run tool/pack.dart modules build/web/modules --name "Babel Board modules" --unpacked` (same call the earlier modules used for the preview). Expected: `build/web/modules/clank-catacombs/` and the index lists it.
- [ ] **Step 2:** For every `image` path in the three data files and every symbol, assert the file exists under `build/web/modules/clank-catacombs/` (one-line node check).
- [ ] **Step 3:** `preview_start` `web-preview`; switch to Clank! Catacombs; open Cards (filter a banner, slide the rail, search "skull"), a card sheet, Tokens, Tiles, Turn (setup, next through steps, Rules sheet). Fix anything that renders wrong, re-pack, reload.
- [ ] **Step 4:** Leave the preview open for the owner.

### Task 7: Publish (after the owner's check)

- [ ] **Step 1:** `dart run tool/pack.dart modules ../babel-board-modules --name "Babel Board games"`; in `E:\AI\babel-board-modules` commit `Clank! Catacombs 1.0.0` and push with `git -c credential.username=ratatabananana-bit push`.
- [ ] **Step 2:** Update `docs/notes/...brainstorm.md` hand-off and `update.md` (one section: Clank! Catacombs 1.0.0), commit in BabelBoard, push.
