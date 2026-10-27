# Updates: Clank! Catacombs module, app 3.3.3 to 3.3.5

What changed between 2026-10-26 and 2026-10-27, newest last. App releases are at
https://github.com/ratatabananana-bit/babel-board/releases and modules at
https://github.com/ratatabananana-bit/babel-board-modules. The previous round (expansions,
Vale of Eternity: Curse, app 3.3.0 to 3.3.2) is in the git history of this file.

## Where things stand

| Thing | Version | Where |
|---|---|---|
| Babel Board app | 3.3.5 (Latest release, arm64 and arm32 APKs) | `babel-board` master, tag `v3.3.5` |
| Clank! Catacombs | 1.1.0 (needs app 3.3.4; lane labels need 3.3.5) | modules repository |
| Vale of Eternity | 2.1.1 | modules repository |
| Vale of Eternity: Curse | 1.0.4 | modules repository |
| Magical Athlete | 1.0.0 | modules repository |
| Tests | 370 passing, analyzer clean | `flutter test` |

## App 3.3.3

- **Italic sections.** `"italic": true` on a sheet section or a details section draws it in
  italics (flavour text). Figtree italic faces are bundled. Fixed late in the day: the drag-up
  Notes renderer had dropped the flag, so details sections were upright until `b8716b3`.
- **Inline italics.** `*…*` in any module text draws that run in italics; symbols inside it
  still work; a lone `*` stays as written.
- **Numbered symbols.** `:gold#3:` draws the gold symbol with "3" centred on it (bold white,
  dark rim). In a chip, `"symbol": "cost#{cost}"` does the same from a field, and a template
  that fills to a bare `name#` hides the chip. One blank coin, badge or triangle serves every
  printed amount. Templates can also pick the symbol: `"{costSymbol}#{cost}"`.
- **Flat filter dock.** A dock option with a `symbol` draws it as delivered, no disc or ring;
  unselected ones are dimmed to half, the selected label goes bold. Text options keep the disc.
- Web preview note: `tool/pack.dart … --unpacked` is required for `build/web/modules/<id>/`;
  the preview reads modules unzipped and never re-fetches a same-version module.

Spec, schema, `AI_INSTRUCTIONS.md` and `docs/CAPABILITIES.md` describe all of it.

## App 3.3.4

- **Symbols in chips.** A chip's `text` template now goes through the symbol renderer, so a
  field holding `:points#5: if you have a Crown` shows the gem inside the pill. Needed so the
  token sheets in Clank! show points the same way the card text does.

## App 3.3.5

- **Lane rows name the effect type.** In a board lane, an effect whose type has no symbol
  now starts with its label ("Defeat: ", "When played: "), so a tracked Clank! card reads
  right without opening it. Modules whose every type has a symbol (Vale) are unchanged.

## Clank! Catacombs 1.0.0 to 1.1.0

Base game. Six tabs: Cards, Tokens, Tiles, Mine, Rules (hub of categorised text), Turn (flow
with a start-of-turn step and categorised reminders). Mine (1.1.0) tracks three zones: My deck
(acquired cards, one entry per card), Watched (Row cards to keep an eye on), Trashed. The card
sheet offers all three and swipes left to My deck, right to Watched. Lanes show each card's
effect text. No hand or resource tracking: the hand changes every turn and the app has no
counters.

- **Cards (77 unique, 101 printed).** TTS Workshop scans at 504 x 700. Found without families:
  a filter dock of five banner buttons (Blue, Device, Monster, Reserve, Starter) with the
  designer's cracked-ribbon icons, a cost rail 0 to 8, and search over name, text and "what
  you see" tags. Sheet chips: banner + kind, cost on the blue triangle (monsters: swords on
  the red triangle, via `costSymbol`), points on the green gem, Gives (resource icons),
  card icon × copies. Printed line breaks kept; `+N Clank!` / `-N Clank!` in italics; flavour
  text under Notes in italics. Gold, skill and boot amounts use `:gold#2:` style.
- **Tokens (37).** Prisoners (TTS faces, pentagon-masked, same height, centred), major and
  minor secrets and market items (TTS faces), artifacts (rulebook crop, `verified: false`),
  mastery, ghost cube, lockpick, gold.
- **Tiles (24).** Tunnel icons, room features and rewards, four start-tile halves.
- **Pictures by source** (see `clank-catacombs-pictures.html` in the old session folder for
  the per-file list): 32 TTS token faces, 7 TTS tile scans, 23 drawn by the owner (cost, fight,
  gold, points, skill, sword, boot, heart, dragon, mastery, arrive, danger, ghost cubes,
  footprints, lock, portal, artifact room, crystal cave, healing, logo), 5 designer banners,
  17 rulebook crops, 1 placeholder (copies card icon).
- 1.0.1 to 1.0.5: every point, gold, cost, sword, boot and skill amount in token text, tile
  text, the Rules hub, the Turn flow and the token points chip is drawn on its symbol; plain
  blue cards are labelled Blue; tiles search by kind; the cost rail reads "COST / SWORDS N"
  because a monster row's number is swords.
- Sources and scripts live outside the repo in `E:\AI\BabelBoard\Workshop Item\clank-catacombs-src`
  (gitignored): `scripts/cards_src.js`, `tokens_src.js`, `tiles_src.js` generate the data;
  `check.js` asserts it; `crops.json` + `make_images.js` cut the rulebook pictures;
  `prisoners.js` masks the prisoner tokens. Owner drawings in
  `E:\AI\Vale of Eternity Helper\wide\replace *.png`.

### Open for Clank!

- Skill diamond carries a printed 1; four cards overlay 2, 3 or 6 on it (owner: leave for now).
- Copies card icon is a flat placeholder; monster and one-way tunnel icons, the Artifacts
  stack and the single Lockpick are still rulebook crops.
- Banner icons sit small in the dock buttons (the designer's file has margins).
- The module ships publisher scans: personal use only, like the Vale module.

## Vale card pictures from the TTS Workshop item (2026-10-27)

All 98 Vale cards now use the pictures from the Vale of Eternity Tabletop Simulator Workshop
item (English sheets). Base game (2.1.1): 600 x 838, twice the old 300 x 419, same artwork,
crisper when zoomed. Curse (1.0.4): the old pictures were soft photo scans; the TTS ones are
clean renders with sharp text and symbols, 430 x 600. Every card was checked against the old
picture before the swap. The workshop item also has a third 28-card sheet (Duduri King,
Rockscale, Taweret…) that no module covers yet. Script: `Workshop Item/vale-src/cards.js`
(gitignored), which stages the crops and writes old-vs-new contact sheets before `--apply`.

## Known limits (unchanged)

- Gloomhaven module unwritten; Vale Artifacts expansion not done; no counters by design.
- GitHub caches the repository index about 5 minutes after a push.
