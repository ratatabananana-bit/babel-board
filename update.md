# Updates: expansions, Vale of Eternity: Curse, app 3.3.0 to 3.3.2

What changed between 2026-10-25 and 2026-10-26, newest last. App releases are at
https://github.com/ratatabananana-bit/babel-board/releases and modules at
https://github.com/ratatabananana-bit/babel-board-modules.

## Where things stand

| Thing | Version | Where |
|---|---|---|
| Babel Board app | 3.3.2 (Latest release, arm64 and arm32 APKs) | `babel-board` master `8daec26`, tag `v3.3.2` |
| Vale of Eternity | 2.1.0 | modules repository |
| Vale of Eternity: Curse | 1.0.3 | modules repository `daa9bc1` |
| Tests | 361 passing, analyzer clean | `flutter test` |

The tablet (Galaxy Tab S9) runs 3.3.2 with Vale 2.1.0 and Curse 1.0.3 installed.

## App 3.3.0: expansion modules

A game's expansion is now a module of its own that merges into the installed game.

- **Expansion modules.** A module with `expands: {id, minVersion}` is an overlay, not a game.
  It adds cards to the game's collections, new collections, zones, symbols, tabs, lanes, round
  steps, checklist rows, reminders and chips, and can change any setting of the game by naming
  it. It cannot remove anything (a `null` in the overlay is an error).
- **Merge rules.** Objects merge key by key. Lists of objects merge by `id` (lanes by `zone`),
  new ones placed with `after` / `before`. Number lists replace; other lists append. An item
  that replaces one of the game's items by id is errata and gets a validator warning. The
  merged game goes through the same validator as any module.
- **Safe stacking.** Several expansions on one game apply in id order. An expansion that does
  not merge is left out and shown as broken; the game still opens.
- **Library.** Expansions get their own section with an on/off switch per expansion. An
  expansion installs only after its game ("Install X first"). Uninstalling an expansion
  forgets only the tracked cards it alone provided. Repository rows show "Expansion ·" and
  wait for the game.
- **Saved games survive expansions.** The round remembers its step by id, so a step an
  expansion inserts does not shift a game in progress. Tracking only counts cards and zones
  the open game has, so switching an expansion off hides its cards without losing them.
- **Flip picture.** A collection can name a second picture per item (`backImageField`): the
  card sheet gets a flip button, also when zoomed. The Curse Summoners use it.
- **Smaller fixes.** A labelled chip with no value is hidden; long chip text ends in "…"; a
  step name too wide for the phase bar shrinks instead of breaking mid-word.
- **Tools.** `tool/validate.dart` checks an expansion merged into its game (`--base`, or the
  sibling folder). `tool/pack.dart` packs games first and writes `expands` into the index.
- **Docs.** MODULE_SPEC (Expansions section), CAPABILITIES (§6 Expansions), AI_INSTRUCTIONS,
  the JSON schema, ARCHITECTURE, CREATING_MODULES and README.

## Vale of Eternity 2.1.0 and Vale of Eternity: Curse 1.0.0

- **Vale of Eternity 2.1.0** only gives its tabs ids (`cards`, `mine`, `round`) so the
  expansion can place things next to them.
- **Curse 1.0.0** adds:
  - 28 cards with their printed curses (a "Curses" chip);
  - 8 Summoner tiles with front and back pictures and both sides' abilities;
  - a Summoners tab, a Summoner lane and a Soothed lane in My cards;
  - a Curse step in the round after Resolution, listing your Field cards with printed curses;
  - setup rows, a final-scoring row, rules reminders and rulings.
- **Source.** Card text, Summoners and rules were read from the Curse Expansion page on
  valeofeternity.wiki.gg.

## App 3.3.1: internet in release builds

Release builds had no internet permission, so connecting a repository said "No connection"
(debug builds worked, which hid it). The permission is now in the main Android manifest, with
a test that checks it is there.

## Curse 1.0.1 to 1.0.3: your symbol drawings

| Your drawing | Symbol in the module | Shows up in |
|---|---|---|
| Curse Symbol | `curse_symbol` (printed curse mark) | the "Curses" chip on cards, round text about cursed cards |
| Curse Symbol | `curse` (curse token), since 1.0.3 | "Start ×5" on Summoners, effect and rules text |
| Curse Symbol | expansion icon, since 1.0.2 | Library rows |
| Totem Unbroken | `ward` | active ward |
| Totem Broken | `ward_broken` | broken ward ("Mend a …") |
| Turnaround | `flip` | Summoner flip |

- 1.0.1: the four drawings, as 96 px transparent symbols like the base game's.
- 1.0.2: the Library icon is your curse mark, unscaled on a transparent square.
- 1.0.3: the curse token uses the same drawing; the old black-and-red photo crop is deleted.

## App 3.3.2: pictures update without a restart

After an Update, pictures already on screen (icons, cards, symbols) stayed the old version
until the app was restarted. The app kept decoded pictures under their file path, and an
update writes new files to the same paths.

- Installed pictures are now told apart by path, last change and size, so an updated file is
  a new picture and the screen redraws it.
- Repository icon links carry the version (`?v=1.0.3`), so a new version's icon is fetched
  again, past both the app's cache and GitHub's.

Checked on the tablet: installing Curse 1.0.1 and then updating to 1.0.2 switched the icon
both times with no restart.

## Good to know

- **GitHub caches the repository index for about 5 minutes.** Right after a module is pushed,
  the Library may still offer the old version. Wait, or install the new zip from its link
  (Settings → Install from link).
- **Updating a module:** Library → refresh on the repository → Update. Saved cards and round
  progress are kept.
- **To install Curse on another phone:** install Vale of Eternity 2.1.0 first, then Curse.

## Not done / known limits

- The Summoner tile photos still show the black curse diamond printed on the art; that is the
  photo, not a symbol.
- Curse tokens, wards and soothed points are not counted (the app has no counters by design).
  The Curse step lists cards with printed curses only; a card cursed by Tyr or Dunia is not
  listed.
- Which side of a Summoner is up is not remembered; the sheet flips for reading.
- Kang San's back side needs Artifacts, which has no module yet.
- The design screenshots `design/screenshots/34`–`39` were taken before your drawings and
  still show the old symbols.
- `VoE Curse Icon WIP/` (your drawing sources) sits untracked in the modules repository
  folder; it is not in any zip.
