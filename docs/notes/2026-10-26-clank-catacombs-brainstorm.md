# Clank! Catacombs module: brainstorm notes (2026-10-26)

Status: brainstorm only, nothing decided. Written against app 3.3.2 / `docs/CAPABILITIES.md`.

## What the game needs from the app

- Deck-builder: the player's problem is **reading a card** (Dungeon Row, hand, tokens, tiles),
  not tracking state. Numbers (health, Clank!, gold, rage) live on the physical board; the app
  has no counters by design.
- Turn is a fixed sequence: play 5 cards -> spend Skill / Swords / Boots -> end of turn
  (discard, draw 5, refill row to 6, Dragon Attack if a new row card shows the symbol).
  Fits a `flow` with a Setup step and a Scoring step; Dragon Attack as a `how` list.
- Optional tracking: a "My deck" lane (cards bought this game) so the owner can see what is in
  the deck without reading it. Low value, cheap.

## Components (rulebook / Token Reference Guide, retailer listings)

| Set | Count | Picture shape | Source for text |
|---|---|---|---|
| Dungeon deck | 100 cards (unique count unknown, guess 60-80) | card | scans / rulebook examples |
| Starter + reserve | Burgle, Stumble, Sidestep, Scramble, Mercenary, Explore, Secret Tome, Goblin | card | rulebook |
| Prisoners | 13 kinds, 20 tokens | square | Token Reference Guide |
| Major Secrets | 5+ kinds, 11 tokens | square | Token Reference Guide |
| Minor Secrets | 8 kinds, 20 tokens | square | Token Reference Guide |
| Market items | Backpack, Blood Amulet, Burglar's Kit, Crown | square | Token Reference Guide |
| Artifacts | 7 (5-30 pts) | square | rulebook |
| Monkey Idol, Mastery, ghost cube, dragon | few | square | rulebook |
| Tiles | 1 start (two-sided) + 22 Depths + 6 Safety | square, `backImageField` for start | rulebook |
| Tile icons | footprint, monster, lock, one-way, crypt, crystal cave, haunted, chest, library, prison, market, portal, wayshrine, rewards | symbol | Token Reference Guide |
| Resource symbols | skill, sword, boot, gold, clank, draw, dragon attack, heart | symbol | rulebook |

Expansions (own modules with `expands`): Lairs & Lost Chambers (50 cards, 12 tiles, 5 monster
tokens, Entry Tunnels, Pit Traps, Trophy cards); Underworld (50 cards, 22 Fate cards, 1 start +
7 Underworld + 6 Depths tiles, Guardian).

Chinese edition exists: 噤声寻宝记!地下墓穴 (2025, simplified).

## Card lookup without families

Language-free cues printed on every card: banner colour (blue companion / yellow reserve /
purple device / red monster), cost (lower right), points (top right), dragon-attack mark,
unique art. No evidence the cards carry a printed number (Clank! cards never have); owner to
check the physical card.

Proposed gallery: `filters` dock on `type` (4 options with banner-coloured symbols) +
`sections` by `cost` with a number `rail` (like Vale) + `search` over `name`, `text` and an
owner-written `tags` field ("skeleton", "lute", "spider", "potion": describe what you see).
Picture-first grid finishes the match. Roughly 100 cards / 4 types / 8 costs = 3-4 per bucket.

## Images: what was found online

- **Official rulebook + Token Reference Guide PDF** (Dire Wolf, cloudfront):
  `https://d19y2ttatozxjp.cloudfront.net/pdfs/CLANK_CATACOMBS_Rulebook_and_Token_Reference_Guide.pdf`
  Best source for every token, tile icon and resource symbol (crop from PDF). Not the 100 cards.
- **Dire Wolf design diaries**: a handful of clean card/tile PNGs (Lairs: Ape Lord Epaulets,
  Hoard Keeper, Venomous Lurker, Heart of the Dark, three tiles). Incomplete.
- **No fan wiki / card database with pictures** for Catacombs (unlike valeofeternity.wiki.gg).
- **Scribd "Clank! Catacombs Card List"** (6 pages, text: name, cost, type, effect): login-walled
  in a fetch; maybe readable in a browser. Unverified fan transcription.
- **Tabletop Simulator Workshop mods** (3326856871 Catacombs + Lairs; 2898604358 EN/KO scripted;
  2894349197 flagged incompatible; one Lairs mod removed): usual source of full card scans at
  good resolution, but downloading needs TTS ownership; one comment says the start tile is low
  resolution. Steam page fetch got 429, contents unverified.
- **BGG image gallery**: behind a bot check for the agent; owner can browse. Mixed quality photos.
- **Clank! digital (Steam/mobile)**: no evidence it includes Catacombs. Not a source.
- **Fallback that always works**: photograph the owner's own cards; art is identical across
  editions, the module supplies the English text. ~100 cards + tokens, 1-2 h, plus a crop script.

## Open points for the owner

1. Which copy: base only, or with Lairs / Underworld? Chinese edition?
2. Pictures: TTS available, or photograph own cards, or text-only cards for v1?
3. Do the cards have a printed number anywhere? (unlocks the number keypad)
4. Track "My deck" or lookup only?

## Hand-off (build, 2026-10-26)

- Module built at `modules/clank-catacombs/` (branch `clank-catacombs`), design in
  `docs/superpowers/specs/2026-10-26-clank-catacombs-module-design.md`, plan in
  `docs/superpowers/plans/2026-10-26-clank-catacombs-module.md`.
- Source material and throwaway scripts: `Workshop Item\clank-catacombs-src\` (gitignored).
  `scripts/cards_src.js`, `tokens_src.js`, `tiles_src.js` regenerate the data files;
  `scripts/check.js` asserts the data invariants; `make_images.js` + `crops.json` rebuild pictures.
- Unverified: none of the 77 cards (two passes against the scans). One token item
  (`artifacts`, the seven-value composite) is `verified: false` because the 5/7/10 values are
  read from a small part of the component page.
- The TTS mod has 101 dungeon cards for the box's 100; copy counts are the mod's.
- Not done: Chinese names, expansions, tile catalogue, "My deck" zone.
