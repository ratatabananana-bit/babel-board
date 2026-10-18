# Vale of Eternity module 2.0.0 (2026-10-18)

The card data in `modules/vale-of-eternity/data/cards.json` was rebuilt from
https://valeofeternity.wiki.gg instead of patching the 1.x data.

## How it was derived

- **Card text.** The wiki's card pages hold strategy and rulings, but not the printed text.
  The printed English text lives only in the card images. So the 70 images from the wiki's
  "All Cards" gallery were downloaded through the MediaWiki API, cropped and read one by one.
  Name, cost, family and every effect line come from those images.
- **Families and sell values.** Families come from the wiki's family galleries. Sell values
  follow the rulebook and match the wiki pages: Fire 3 red, Water 1 blue, Earth 4 red,
  Wind 1 red + 1 blue, Dragon 1 purple.
- **Rulings.** The `interactions` lines come from the "About / FAQ" sections of the card pages.
  They also use the Discard Dragons page and the Genie Exalted page, which quotes a BGG ruling.
- **Unchanged.** Ids, images, tabs, zones, symbols, sheet settings and the flow are unchanged.
  The version is 2.0.0 and `source` names the wiki. No `nameZh`: the wiki gives no Chinese names.

## What changed per group

Every card keeps its id, name, cost, family and effect types. Text changes are wording only:

- **All families.** Where the printed card shows a family icon, the text now uses the symbol
  (`:fire:`, `:water:`, `:earth:`, `:wind:`, `:dragon:`) instead of the word. This affects
  Lava Giant, Balog, Nessie, Leviathan, Triton, Poseidon, Mimic, Sand Giant, Boreas,
  Hippogriff, Dragon Egg, Tidal, Ember, Marina, Boulder and Gust.
- **Printed wording restored.** 1.x had smoothed these lines; the card says otherwise:
  - Kappa and Gargoyle: "using :stone_x:" instead of "using a".
  - Troll: "If you have :stone_purple:".
  - Stone Golem: "with :stone_purple:".
  - Hae-tae: "counts as :stone_x:".
  - Sea Spirit: "for each your :stone_blue:". This is a typo on the printed card.
  - Pegasus and Hippogriff: "The cost of your (Wind) card", singular.
  - Genie: "all available Active effect", singular.
  - Mimic: "from discard pile".
  - Forest Spirit and Aeris: "written on the card".
  - Willow: three stones with no commas.
- **Basilisk.** The added "(choose one option)" is gone from the effect. The choice is now a
  ruling in the drag-up details.
- **Leviathan.** The wiki's infobox lists it as a Dragon. The card frame, the Water gallery and
  the Discard Dragons page all say Water, so it stays Water.

## Unverified cards

None. All 70 cards were read from the wiki's card images, so every card has `"verified": true`.
Hippogriff has no wiki page, but its image is in the All Cards gallery and was read from there.

## Interactions added

33 cards have rulings. Each has one to three short lines, all about timing, what counts, or an
edge case. Cards whose wiki text only restates the effect or gives strategy have none. That
includes the "counts itself" notes on Ifrit, Incubus, Lava Giant, Poseidon, Sand Giant, Gi-rin,
Tidal, Eternity, Valkyrie and Freyja, which were left out to keep the details short.

| Card | Ruling |
|---|---|
| Hestia | Leaving your area drops you to 4 stones right away |
| Succubus | Can be summoned without all four costs; earns nothing then |
| Firefox, Rudra | Do not count themselves (already in your area) |
| Phoenix, Kappa | Don't score their own summon; no overpaying. Kappa: 2 per summon however many blue |
| Agni, Water Giant | Value boost also applies when paying, only while in your area; Water Giant + Hae-tae values |
| Hae-tae | Only the value changes, a purple is still needed; purple worth 3, also when paying |
| Yuki Onna | Discards all stones; costs 0 so it never triggers Phoenix / Kappa / Gargoyle |
| Yuki Onna Exalted, Rock Golem, Stone Golem | Count or exchange the stones left after paying; Rock Golem values with Water Giant / Hae-tae |
| Triton | Only taming counts |
| Young Forest Spirit | Needs 2 open spaces and 2 other cards in hand; the free card's own conditions apply |
| Goblin | Needs an opponent with at least 1 point |
| Forest Spirit | Can't be summoned as your only card in hand |
| Gargoyle | Not its own summon; 3 per summon; may pay with a purple but no extra stones |
| Basilisk | Pick one option; points can't go below 0 |
| Goblin Soldier | A tie still loses 4 |
| Medusa | Empty hand: nothing; cards that reach your hand during Resolution can be forced out |
| Pegasus | "Written cost" stays the printed cost |
| Tengu | Needs an open space; the next card anyone draws is Tengu |
| Boreas | Counts itself, can repeat; never counts for other cards |
| Genie | Works like Resolution; Recover returns its own card |
| Sylph | Not its own summon; scores before the new card's Instant; Dragon Egg / YFS summons count |
| Genie Exalted | A copied Recover returns Genie Exalted; can copy before or after, even an effect that can't be completed |
| Dragon Egg | Needs another Dragon in hand that meets its conditions; one space is enough |
| Leviathan, Ember, Marina, Boulder, Gust | Must target a player with that family in play (yourself allowed), else can't be summoned; that player picks the card. Ember / Marina / Boulder: you pay first, so your own boost still helps |

## Checks

- `dart run tool/validate.dart modules/vale-of-eternity`: `OK vale-of-eternity 2.0.0`.
- `flutter test`: 224 pass. Only the version expectation in `test/games/vale_module_test.dart`
  changed. The wording the tests check (Imp, Water Giant, Mud Slime, Rock Golem, "Recover.",
  the Hae-tae ruling) matches the wiki.
- `flutter test tool/screenshot_test.dart` ran. Shots 05, 29 and 30 show the sheet, the
  Interactions hint and the open Hae-tae details with stone symbols. The regenerated pngs were
  not committed: committed screenshots differ by machine (see the typed-specs notes).

## Next

Re-pack the module to the private repo: `dart run tool/pack.dart modules <checkout>`. Then
push it, so phones get 2.0.0.

## Owner's edits after review (same day, on master)

- Five printed typos are smoothed, meaning kept: Sea Spirit "for each of your", Genie "Active
  effects", Mimic "from the discard pile", Pegasus and Hippogriff "your cards is decreased".
  The printed cards have the errors; the app is for reading them in English.
- Interactions trimmed to rulings only: Firefox and Rudra ("does not count itself") removed;
  the "You pay first, so…" strategy line dropped from Ember, Marina and Boulder; the
  Water Giant / Hae-tae arithmetic dropped from Rock Golem and Water Giant (Hae-tae keeps it).
  31 cards have interactions, none longer than two lines.
