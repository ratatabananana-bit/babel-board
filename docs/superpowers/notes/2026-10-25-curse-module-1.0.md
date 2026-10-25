# Vale of Eternity: Curse module 1.0.0 (2026-10-25)

The first expansion module: `modules/vale-of-eternity-curse/`, merged into Vale of Eternity
2.1.0 (whose only change is tab ids `cards`, `mine`, `round`). App 3.3.0.

## How it was derived

- **Card text.** Read from the 28 card images in the wiki's Curse Expansion gallery
  (`valeofeternity.wiki.gg/wiki/Curse_Expansion`, files fetched through the MediaWiki API),
  enlarged 3× to read the small print. Name, family, cost, printed curse symbols and every
  effect line come from those images. All 28 are `"verified": true`.
- **Printed names win over file names**: the wiki files `Masticore`, `Hantubanyu`, `Ixchel`,
  `Aessidhe` are the cards Manticore, Hantu Banyu, Ix Chel and Aes Sidhe.
- **Summoners.** Read from the 16 tile photos (front and back), including the starting
  resources in the top-left corner. Pictures are those photos, cropped to the tile.
- **Rules.** From the two rulebook photos on the same page: setup, cursed cards, the Curse
  Phase, final scoring, wards, the Summoner notes and the Abilities FAQ & Reminders.
- **Symbols.** The curse token, the printed curse mark, the active and broken ward and the
  flip mark were cropped from the tile photos and cut to their printed shape (diamond, circle,
  rounded tile), 96 px like the base symbols. The expansion icon is the curse mark.
- **Conventions kept from the base module**: family labels and sell values, `:symbol:` text,
  stones repeated for counts, `N :points:` for points, rulings only in the drag-up details,
  printed typos smoothed (Strix "for each your" → "for each of your").

## What it adds, as an overlay

| Base part | Added |
|---|---|
| `cards` collection | 28 items; a `curses` list of `curse_symbol` per printed curse; a "Curses" chip (hidden on cards without curses) |
| new `summoners` collection | 8 tiles with a back picture (`backImageField`), each side's abilities as typed effects, starting resources as chips, rulings |
| symbols | `curse`, `curse_symbol`, `ward`, `ward_broken`, `flip` |
| zones | `summoner`, `soothed` |
| tabs | Summoners (after Cards); My cards gets a Summoner lane before Table and a Soothed lane after Field |
| Round flow | 5 reminders; setup `how` + 4 rows before "Start a new game"; `how` lines on Hunting, Action, Resolution and End; a **Curse** step after Resolution listing your Field cards with printed curses; a final-scoring row before "Clear Table" |

## Rulings added (drag-up details)

Taniwha (three: must be completable, curses follow the card, fixed cost = exactly one blue),
Ares and Axomama (stone limit changes at once), Dullahan, Selkie (stones only), Tarasque
("up to", empty areas), Anansi (zero is even), Inferno (overflow then discard). Every
Summoner has its rulebook note (setup extras, when it flips, Kang San needs Artifacts).

## Known limits

- The Curse step lists cards with **printed** curses. A card cursed by Tyr or Dunia is not
  listed (the app tracks no token counts); its `how` line says to treat it the same.
- Curse tokens, wards and soothed points are not counted by the app (no counters, by design).
- Which side of a Summoner is up is not remembered; the sheet flips for reading.
- Kang San's back is an Artifacts effect; there is no Artifacts module yet.

## Checks

- `dart run tool/validate.dart modules/vale-of-eternity-curse` → `OK vale-of-eternity-curse 1.0.0`
  (merged into the sibling Vale folder).
- `test/games/curse_module_test.dart`: 98 cards, 8 Summoners with both pictures, every symbol
  resolves, the round's steps, tab and lane order, the Water filter, the Curse step, the flip.
- Screenshots 34–39 in `design/screenshots/`.
