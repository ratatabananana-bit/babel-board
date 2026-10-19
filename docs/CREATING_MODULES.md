# Making a game module for Babel Board

Babel Board has no games built in. Each game is a **module**: a folder (or zip) of JSON
and pictures that tells the app what to draw. You never touch the app's code. This page is
the human walkthrough; the exact format is in [`modules/MODULE_SPEC.md`](../modules/MODULE_SPEC.md).

## What you need

- The game's **official rulebook** (PDF or the box) and its cards.
- Card pictures: your own photos/scans, or image links you are sure exist. A module with no
  pictures still works (cards show as clean text cards).
- Either an AI chat (Claude, ChatGPT) or a text editor. Dart is only needed to run the
  checker on a computer; the app checks every module itself when you install it.

Modules contain the publisher's art, so keep them for personal use: share through a
**private** repository or by sending the file directly, never on a public site.

## The quick way: ask an AI (works on a phone)

1. In the app: **Library → ⚙ Settings → Copy instructions for AI**. This copies a compact
   spec to the clipboard.
2. Paste it into Claude or ChatGPT, then say what you want, for example:

   > Write a Babel Board module for *Heat: Pedal to the Metal*. Use the official rulebook.
   > Cards: the upgrade cards. Zones: hand and discard. Add a round flow with the phases
   > from the rulebook. Use the single-JSON form with image links.

3. The AI answers with one JSON file. Save it (any name, `.json`).
4. On the phone: **Settings → Install from file**, pick the file. Or share the file to
   Babel Board from any app. The app validates it and tells you, in words, what is wrong
   if anything.
5. Play. Fix wording later by editing the JSON and installing it again; your tracked cards
   and round progress survive updates (raise `version` first).

Picture links are downloaded **once, at install**, so the game works offline afterwards. A
link that fails just leaves that card as a text card.

## The full way: a module folder

```
my-game/
  module.json          the manifest: name, collections, zones, tabs
  data/cards.json      {"items": [ { "id": "...", "name": "...", ... }, ... ]}
  images/icon.webp     round game icon
  images/cards/*.webp  card art (any size; 300 × 420 is plenty)
  images/symbols/*.webp  small icons used inline in text
```

Copy `modules/vale-of-eternity/` or `modules/magical-athlete/` and change things one at a
time; both are complete, working examples.

### module.json in five parts

1. **Header**: `format: 1`, `id` (lowercase, never changes once published), `name`,
   `version` ("1.0.0"; raise it for every update), `minAppVersion` ("3.0.0"), `icon`,
   `players`, `source`.
2. **collections**: your lists of things (cards, racers, tiles). Each item is a JSON object
   with any fields you like plus a unique `id`. Say which field is the title, the image,
   the subtitle, and what the item's **sheet** shows (chips, effects, extra sections,
   drag-up details such as rulings, which zones it can be put in, which zone a flick
   left/right goes to).
3. **symbols**: named small pictures (`"heat": "images/symbols/heat.webp"`). Write
   `:heat:` in any text and the app draws the picture inline.
4. **zones**: the places a player tracks things in (hand, table, in play, this race…). Each
   has an id, label, icon name, and one of three accents: `amber`, `mint`, `violet`.
5. **tabs**: the bottom bar. Each tab is one **block**:
   - `gallery`: a searchable picture grid with a family filter dock and cost sections.
   - `board`: lanes, one per zone, with drag-and-drop between them.
   - `flow`: a round tracker: steps, each with a checklist and "how it works" lines.
   - `text`: plain rules text (paragraphs, bullets).
   - `cardList`: the items matching a filter (for example the cards in one zone that
     have an "active" effect).

### Writing good card text

- Copy the printed wording. If you cannot confirm it, add `"verified": false` to the item;
  the app shows a warning on that card.
- Use symbols for icons the card prints (`:stone_red:`, `:fire:`). Repeat a symbol for
  small counts, like the card does: `Earn :stone_red::stone_red:`.
- Keep rulings in the drag-up details (`sheet.details`), one to three short sentences per
  card, and only when they change play. The main sheet stays the card's own text.
- Write for any player count the box supports ("2 cards per player"), not for one table.

## Check it before installing

```bash
dart run tool/validate.dart my-game
```

prints every problem with its path in the JSON (`tabs[0].block.filters[1].path: …`). The
app runs the same checks at install. A green validator means the module will draw.

## Install it

- **File**: Settings → Install from file (zip or JSON), or share the file to the app.
- **Link**: Settings → Install from link (a direct `.zip` / `.json` URL).
- **Repository**: a folder of packed modules plus an `index.json` that the app lists, so
  friends can install and update with one tap. See below.

## Share modules with friends: a repository

1. Pack every module folder into a repository folder:

   ```bash
   dart run tool/pack.dart modules ../babel-board-modules --name "Our games"
   ```

   This validates each module, writes `<id>-<version>.zip`, copies icons, and writes
   `index.json` with relative links.
2. Put that folder in a **private** GitHub repository and push.
3. Give each friend a fine-grained personal access token for that one repository with
   **Contents: Read-only** and nothing else.
4. In the app: Settings → Repository. Paste the repository link
   (`https://github.com/<owner>/<repo>`), tap **Connect**, and the games appear with Install
   buttons. A private repository also needs the token ("Private repository? Add a token").
   The app offers updates whenever a `version` rises.

## When something is wrong

| You see | It means |
|---|---|
| "needs a newer Babel Board" | The module uses a block type or format this app version lacks. |
| "Unknown zone / collection" | A tab or sheet names an id that is not declared in `zones` / `collections`. |
| A text-only card | The image path or link did not resolve. Check the path is inside the module and the file type is webp/png/jpg. |
| "This file is not a valid game module" | `module.json` is missing or not JSON. The validator's first line says where. |
