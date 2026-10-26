# Clank! Catacombs module: design

Date: 2026-10-26. Status: draft for the owner's approval. Console: Babel Board 3.3.2, module
format 1 (`modules/MODULE_SPEC.md`, `docs/CAPABILITIES.md`). No app changes are planned; this
is a data module only.

## Intent

The owner plays the Chinese edition of Clank! Catacombs (噤声寻宝记!地下墓穴, base game only)
and reads only English. The module lets anyone at the table find the English text of any
card, token or tile icon in a few taps, and walk the turn and the end-of-turn procedure
without the rulebook. It is a lookup tool, not a game tracker: Clank! is a deck-builder whose
numbers (health, Clank!, gold, rage) live on the physical board and the app has no counters.

## Goals

1. Find any Dungeon Row card from what is printed on it, with no Chinese typing: banner
   colour, cost, picture.
2. Read every token's rule (prisoners, secrets, market items, artifacts, idols, mastery).
3. Read what every tile icon means (tunnels and rooms).
4. Walk Setup, a turn, end of turn with the Dragon Attack, and final scoring as checklists.

## Non-goals, anti-goals

- No tracking of hand, deck, health, Clank!, rage or gold (anti-goal: the app must not try to
  replace the board). No "My deck" zone in v1; the module declares no zones.
- No expansions (Lairs & Lost Chambers, Underworld) in v1. They can come later as
  `expands` modules; the base keeps ids on tabs and steps so they can slot in.
- No tile-by-tile catalogue in v1 (the 29 tile pictures). The tile-icon glossary covers the
  need; a tile catalogue would be a later addition.
- Never invent card text. Every card's text is read from the scan; anything unreadable gets
  `"verified": false`.

## Sources (fixed)

- Card and token pictures: the Tabletop Simulator Workshop item 2898604358, already decoded.
  Sheets: dungeon deck = deck 297 (10 by 7 of 659 by 1024 px) and 298 (6 by 6, same card size);
  Explore, Mercenary, Secret Tome, Goblin, Burgle, Stumble = sheet 303 (10 by 7 of 500 by 690);
  Sidestep, Scramble = sheet 304 (same grid; base Clank! art, identical to Catacombs). Prisoner
  tokens are single PNGs (about 450 px). The 659 by 1024 dungeon crops are stretched about 12%
  taller than the real 63.5 by 88 mm card (the cost diamond is visibly tall); every card is
  resampled to 504 by 700 (aspect 0.72) and the collection uses `cardAspect` 0.72.
- Durable copy of all source material (decoded save, `decks.json` mapping every card to
  sheet/index, the 114 downloads, the 77 card crops and contact sheets, the rendered rulebook
  pages at 1440 and 3600 px, the two PDFs, the helper scripts):
  `E:\AI\BabelBoard\Workshop Item\clank-catacombs-src\`. `Workshop Item/` is gitignored
  (publisher art, never committed). The session scratchpad holds the same files until the
  session ends.
- Rules, tile features and token text: the official rulebook + Token Reference Guide PDF
  (Dire Wolf, 2022), rendered to `pdf/pages/cat_01..18.png` in the scratchpad. Token and icon
  art for secrets, market items, artifacts, idol, mastery and tile icons is cropped from a
  high-scale render of pages 3, 7, 8, 10, 17, 18 (TTS has only tiny faces for secrets).
- Personal use only: publisher art, never a public APK. The packed zip goes to the owner's
  modules repository `ratatabananana-bit/babel-board-modules` like Vale of Eternity, Magical
  Athlete and Curse before it. That repository has been public since 2026-10-19 by the owner's
  decision (no token on the phone); the push is therefore not reversible in practice. The owner
  reaffirms this per module; the alternative is to install the zip from disk on the tablet
  (Settings, Install from file) and skip the repository.

## The module

`id` `clank-catacombs`, name "Clank! Catacombs", `players` "2-4", `minAppVersion` "3.2.0"
(the tablet runs 3.3.2; the module uses nothing newer than 3.0.0 features, 3.2.0 is a safe
floor), icon: the Catacombs logo cropped from the rulebook cover. `source`: rulebook + scans.

### Collection `cards` (77 items)

69 unique Dungeon Deck cards (the mod has 101 cards for the box's 100; the physical copy
decides the copy counts, so `copies` is a chip, not a promise) plus Burgle, Stumble, Sidestep,
Scramble, Mercenary, Explore, Secret Tome, Goblin. `imageShape` card, `cardAspect` 0.72.

Fields per item: `id`, `name`, `banner` (`blue` acquire card, `purple` device, `red` monster,
`yellow` reserve, `grey` starter), `subtype` (printed under the name: Companion, Device,
Monster, Gem, or none), `cost` (lower right; monsters: swords; starters 0), `points` (top
right; absent when the card has none so the chip hides; a text like "?" when the card prints a
variable value, e.g. Expensive Taste), `resources` (list of symbol names in printed order: `skill`, `sword`, `boot`, each
repeated per icon, e.g. `["skill","skill","boot"]`), `effects` (typed list, see below),
`dragon` (true if the Dragon Attack mark is on the right edge), `copies`, `tags` (owner-side
words describing the art: "skeleton", "lute", "spider", "potion", "woman", "blue"), `flavour`
(italic line, in `details`), `verified`.

`effects` types and help text (from the Card Effects section):
- `play`: the main text, happens when the card is played ("+1 Clank!", "Draw a card").
- `acquire`: ACQUIRE bar, once when taken from the Dungeon Row.
- `arrive`: ARRIVE bar, when revealed in the Row, before any Dragon Attack.
- `danger`: DANGER bar, +1 cube pulled while it sits in the Row.
- `use`: USE text of a device, resolved at once, card goes to the Dungeon discard.
- `defeat`: DEFEAT reward of a monster.
- `deep`: "Deep" restriction (only in the Depths).
Each type gets a symbol and a one-line `typeHelp`.

Sheet: chips `{banner symbol} {subtype or banner label}`, `Cost {cost}`, `{points} pts`,
`symbols: resources`, `x{copies}`; effects; `secondary` none; `details` hint "Flavour" with the
flavour line and rulings; `verifiedPath` "verified". No zones, no swipe.

### Gallery "Cards" (tab `cards`)

- `filters`: one dock on `banner`, five options with the banner colour as symbol (crops of
  the five banners), `allLabel` "All cards".
- `sections` by `cost` with `rail`, `railRange` [0, 8] (confirm the real maximum during
  transcription). Starters and the Goblin sit at cost 0 so every section key stays an integer
  and the rail sorts (a text key would turn the sort off).
- `search` over `name`, `effects.text`, `tags`; `searchHint` "Name, text, or what you see".
- `tileName` true (English name under the picture helps the non-reader learn names).
- Columns per row are the app's own setting (4 on a phone, toggled from the search bar), not
  the module's.

### Collection `tokens` (about 40 items), tab "Tokens"

One item per token kind, `imageShape` square. Groups via a `group` field: Prisoners (13),
Major secrets (5), Minor secrets (8), Market (4), Artifacts (7 point values as one item each,
values read off the component page), Other (Monkey Idol, Mastery token, Ghost cube, Lockpick,
Gold). Fields: `id`, `name`, `group`, `points` (end-game value or "conditional"), `text` (the
reference-guide wording), `immediate` (true when it happens at once), `tags`, `verified`.

Gallery: `sections` by `group` (sticky headers, no rail; order = data order), `filters` none,
`search` over `name`, `text`, `tags`, `tileName` false (the square frame already prints the
name). Sheet: chips group and points, section "Effect", section "Keep or return" where the
guide says so (an empty path hides the section).

### Collection `tiles` (tile-icon glossary, about 18 items), tab "Tiles"

Tunnel icons: Footprints, Monster, Lock, One-way arrow, Portal. Rooms: Artifact (and "+",
"++"), Crypt, Crystal Cave, Haunted mark, Chest, Library, Prison, Market, Wayshrine, Monkey
Shrine, Reward rooms (Minor secret, Gold, Healing). Each: `id`, `name`, `kind`
(tunnel/room), `text` from the Tile Features and Movement sections, square icon cropped from
the rulebook. Gallery with `sections` by `kind`, `tileName` false. Also the starting tile as
four square items (top and bottom half of each side, cut from the 1300 by 2600 scans), so the
Depths half and the Crypt are explained; one shape per collection rules out a tall picture.

### Tab "Turn" (flow, `id` `turn`, cyclic)

- `setup` step: A to H from the rulebook as checklist rows (board and rage marker on the
  player-count space; tiles: 22 Depths shuffled, 2 of the 6 safety tiles returned unseen and 4
  on top; bank; start tile either side up, Monkey Idols on the Monkey Shrine, Mastery tokens
  one per player; reserve + Dungeon Row of 6 without Dragon Attack marks; colour, 30 cubes,
  pawn on the Crypt; 3 Lockpicks and the 10-card deck, draw 5; first player, starting Clank!
  3/2/1/0).
- Steps: "Play" (play all five cards, resources pool, Clank! in and out), "Act" (the seven
  actions as `how` lines: acquire, use device, fight, move with tunnel icons, market 7 gold,
  take artifact and rage up, pick chest/library/prison with a lockpick; rewards once per turn
  per room; wayshrine), "End turn" (checklist: play area to discard, draw 5; refill Row to 6;
  Dragon Attack if a new card shows the mark: all Clank! cubes into the bag, draw the rage
  number, black aside, colour = damage, ghost = everyone 1 damage and ghost back to the Clank!
  area; bag empty or deck empty = game over), "Out" (what an escaped or knocked-out player
  does each turn: cubes in, draw exactly 4, or 6 with 2 players).
- Scoring is a final step after "Out" that the owner opens when all players are out:
  artifact (none = 0 points; in the Depths = 0), gold, tokens incl. mastery 20, card points;
  tie = higher artifact. One flow only.
- `reminders`: about ten short rules that bite (discard means from hand; rewards once per room
  per turn; crystal cave exhausts even after teleport; one-way tunnels; Catacombs Map reverses
  them; lockpick per lock icon; cannot take damage voluntarily that would knock you out or
  without cubes; Goblin stays; "each player" order; Depths = 22 dark tiles + top half of the
  start tile).

### Symbols

`skill`, `sword`, `boot`, `gold`, `clank`, `heart`, `draw`, `dragon` (attack mark), `rage`
(red arrow), `ghost`, `artifact`, `lockpick`, banner colours `banner_blue` to `banner_grey`,
effect types `fx_play`, `fx_acquire`, `fx_arrive`, `fx_danger`, `fx_use`, `fx_defeat`,
`fx_deep`. 96 px webp, cropped from the rulebook icons and card bars.

### Pictures and packaging

Cards cropped from the sheets, resampled to 504 by 700, webp quality 80 (about 40 KB each,
about 3.5 MB for 77 cards). Tokens and icons 300 px squares. Module folder
`modules/clank-catacombs/` with `module.json`, `data/cards.json`, `data/tokens.json`,
`data/tiles.json`, `images/{cards,tokens,tiles,symbols}`. A throwaway script in the
scratchpad does the cropping (ffmpeg); it is not part of the repo. Validate with
`tool/validate.dart`, check in the web preview, pack with `tool/pack.dart` into
`E:\AI\babel-board-modules`, commit and push there; the owner installs on the tablet.

### Transcription method

Cards are read from the 659 by 1024 crops in contact sheets of ten at a time; each card's
name, banner, subtype, cost, points, resources, every text bar and the flavour line are
typed into `cards.json`. After the first pass a second pass re-reads every card against the
JSON. Anything blurry stays `verified: false` and is listed in the hand-off notes. Tokens and
tile features are typed from the rendered PDF pages, which are crisp.

## Left to the builder

- Exact banner crops and symbol crops; icon design for the module.
- Tag vocabulary (aim for 2 to 4 plain words per card: creature or object, colour, action).
- Chip wording, step `short` labels, which rulings go into `details`.
- Copy counts: use the mod's counts, flag the 101 vs 100 discrepancy in the hand-off. The
  mod has 14 prisoner tokens by name; the Token Reference Guide's 13 kinds win.
- How a card's text splits into `effects` entries (one per printed line or bar).

## Decisions that are the agent's calls

Lookup only (no zones), no tile catalogue, no Chinese names, four tabs, one flow with
Scoring as its last step, aspect 0.72 for all cards, source material kept in the gitignored
`Workshop Item/` folder, start tile as four half-tile items. The owner can change any of
these. Reviewed once by a builder-check pass on 2026-10-26; its questions are folded in above.

## Appendix: dungeon deck as found in the mod (69 unique, counts as in the mod)

Animated Wall x2, Arcoverlord x3, Astral Projection, Bandit x2, Bard x2, Black Market, Black
Tourmaline, Blink Spell, Boots of the Ape Lords, Brave Hero, Charlatan x2, Corrupt Advisor,
Crystal Compass, Crystal Kobold x2, Curator, Darkened Alcove x2, Diversion, Divining Rod,
Double Cross, Dusty Map, Elven Sword, Empurror, Expensive Taste, Expert Guide x2, Fiery
Quartz, Flamboyance x2, Floating Skull, Golden Flute, Grand Theft, Imp Familiar, Keymaster x2,
Librarian, Lie in Wait x2, Lightstick x2, Locked Trunk, Lute, Marble Guardian, Ogre Merchant
x2, Payoff x2, Pillage x2, Rebel General, Rebel Paladin, Rebel Scribe, Rebel Thief, Remove
Traps x2, Riot x2, Robbery x2, Rose Quartz x2, Scavenger x2, Shadow Walk x2, Skeletal Ape,
Skeleton x3, Skeleton Priest x2, Skeleton Warlock, Skulker, Smash and Grab x2, Smoky Quartz,
Sneak Attack x2, Souldrinker, Spectral Rider, Sudden Movement x2, Swindle x2, The Warden,
Thieves' Shrine x2, Thirst for Adventure, Underground River x2, Waystone, White Tourmaline x2,
Wishing Well.
