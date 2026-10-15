# Add Magical Athlete to Vale Helper: build brief

Turn **Vale Helper** (`E:\AI\Vale of Eternity Helper`) into **one app for several board games**,
and add **Magical Athlete** as the second game. Start Claude Code in this project folder and paste
the prompt at the bottom.

---

## Decisions already made

- **One app, not two.** Of the current 18 MB APK, Flutter itself is 15.6 MB and Vale of Eternity's
  data is 1.5 MB. Two separate apps would be about 34 MB in total; one app with both games is about 20 MB.
  It's also one codebase, so shared fixes only happen once.
- **Quick open:**
  - The app **opens straight into the last game played**. No menu in between.
  - The very first launch shows a small game picker.
  - Switch games with a **game switcher in the top bar**.
  - **Long-pressing the app icon** shows "Vale of Eternity" and "Magical Athlete" shortcuts.
  - Each game keeps its own saved state, so switching never wipes anything.
- **Magical Athlete focuses on racer cards and rules:** look up any racer, read its ability in
  English, and follow the game flow with checklists. There's **no draft or team tracking**.
- **Any player count the box supports.** No "me vs her" wording anywhere.
  - Vale of Eternity is 2–4 players, and its rules text is already worded for any count.
  - Magical Athlete: check the box's player count in the rulebook.
- English only for now. All rules text stays in JSON so Chinese can be added later.
- The app name is open: suggest 2–3 names (e.g. "Table Helper") and let me pick.

## Why Magical Athlete is worth it

The box has ~36 racers, and each has an ability printed on its card in Chinese. The game is built
around those abilities: tripping, copying, moving when another racer moves. Being able to read
them matters at least as much as in Vale of Eternity.

## Game facts to build on

Collected from these sources; confirm each one before relying on it:
[RulesPal rulebook](https://rulespal.com/magical-athlete/rulebook),
[Board Game Quest review](https://www.boardgamequest.com/magical-athlete-review/),
[Meeples Corner guide](https://meeplescorner.co.uk/blogs/meeple-musings/how-to-win-at-magical-athlete-your-step-by-step-strategy-guide),
[Dice Tower listing](https://dicetower.com/board-game/454103).

- Current edition (2025, CMYK, updated by Richard Garfield). It has **36 racers**, 6 dice, and
  placement chips (gold 1st place, silver 2nd place, and bronze 1- and 3-point chips).
- Roll-and-move: roll a die and move that many spaces. Many racer abilities change this.
- Each player drafts a team of **4 racers**. The sources disagree on the draft method,
  **so use the current rulebook's method.**
- **4 races.** Before each race, every player **secretly picks one racer** from their team, then
  everyone reveals. Each racer runs in only one race.
- Races **alternate between the "mild" and "wild" sides** of the board.
- A race ends when **2 racers have crossed the finish line**. The first two finishers score point
  chips, worth more in later races. Most points after all races wins.
- **Check in the rulebook:** player count, the draft method, chip values for each race,
  tie-breaks, and the exact wording of each ability.
- **The 2003 original edition is different (25 racers, bidding draft). Don't use its data.**

## Plan, in order (each step ends with all tests green)

### 1. Split into shared core + Vale module (no visible change)
- `lib/core/`: theme, widgets (card image, animated grid, card sheet base, dashed border,
  confirm, checklist and Next button, lanes and drag), state helpers, and the game switcher.
- `lib/games/vale/`: everything specific to Vale of Eternity (models, data, screens, rules).
- A small `GameModule` interface: `id`, `title`, `icon`, `load()`, `tabs`, and a key prefix for saved state.
- **Keep my saved data:** stored keys move from `tracker.zones` to `vale.tracker.zones` (and
  likewise for the others). Add a one-time migration and a test for it.
- All existing tests keep passing, and the screenshots look the same as before.

### 2. Multi-game shell
- On launch, read `app.lastGame` and open that game. If there isn't one, show the game picker.
- Top bar: a game switcher (game symbol + name ▾) that opens a bottom sheet listing the games.
- Long-press shortcuts on the app icon, e.g. with the `quick_actions` package. Keep extra
  dependencies to a minimum.
- Each game's bottom tabs come from its module.

### 3. Magical Athlete data
- `assets/games/magical_athlete/racers.json`: `id, name, nameZh, number (if printed), abilities[], verified, image`.
- `assets/games/magical_athlete/racers/*.webp`: one image per racer, compressed to ~20–40 KB.
- `assets/games/magical_athlete/rules_en.json`: game flow steps, checklists, chip values per race,
  and key rules.
- **Sources:** the rulebook is the source of truth for rules. For the racer list, abilities and art,
  look for a fan wiki, a BoardGameGeek file, or Board Game Arena. Check each ability against the
  printed card image where possible, and mark anything unconfirmed as `verified: false`.
  **Never invent racers or abilities.** Chinese names are a bonus.
- The art is the publisher's, so the app is for personal sideloading only. Never publish it.

### 4. Magical Athlete screens (two tabs)
**Racers**
- A grid of racer pictures in their real card shape (never square crops).
- Search by name or ability text, plus the 4 / 3 / 2 per-row toggle.
- No family or cost filters, since the game has none. Sort by racer number if printed, otherwise alphabetically.
- Tapping a racer opens a sheet: art thumbnail (tap for full size), English name, Chinese name if
  known, and the **ability in the largest text**, with ⚠ if unverified.
- Optional extra, only if cheap: a "**In this race**" quick pick. Tick the racers on the track to
  see all their abilities on one screen, since they interact. Clear it after each race.

**Game** (same pattern as Vale's Round tab)
- Progress bar: **Setup → Draft → Race 1 → Race 2 → Race 3 → Race 4 → Final scoring**.
  Each race shows whether it's on the mild or wild side.
- A parchment checklist per step, with done count and progress bar. "Next" shows "n steps left"
  and needs a second tap to skip.
- Examples (take the exact wording from the rulebook):
  - **Draft:** how many racers are revealed, and the picking order.
  - **Race setup:** set the board side, everyone picks a racer secretly, reveal, and place them at the start.
  - **End of race:** give out 1st and 2nd place chips (show this race's values), set the used
    racers aside, and flip the board for the next race.
  - **Final:** count points, then apply the tie-break.
- "How this step works" folds away under the checklist. Rules and New game sit in the header and ⋮ menu.
- No score tracking. The chips stay on the table.

### 5. Finish
- Tests: per-game data integrity (racer count, images exist, unique ids), the saved-data
  migration, the game switcher, and last-game-on-launch. Also Magical Athlete search, the racer
  sheet, and the Game tab's double tap on Next.
- `tool/screenshot_test.dart` renders both games' screens into `design/screenshots/`.
- Release APK copied to the project root, plus a web build for the preview. Commit a checkpoint.

## Lessons from building Vale Helper (don't repeat these)

1. **Show cards in their printed shape.** Square crops were rejected immediately.
2. **Drag needs two recognizers:** an immediate one for the mouse (a custom `Draggable` whose
   `createRecognizer` returns `ImmediateMultiDragGestureRecognizer(supportedDevices: {mouse})`)
   plus `LongPressDraggable` (~220 ms) for touch, so fingers can still scroll.
3. **Never add or remove a wrapper around a `DragTarget` during a drag.** It rebuilds the
   target mid-hover, so hovering flickers and drops miss. Always wrap, and make the wrapper
   transparent when it isn't needed.
4. **Inside a `Row` stretched by `IntrinsicHeight`, a `Stack` needs `fit: StackFit.passthrough`
   and a non-positioned child**, or the cards collapse to zero height.
5. **A tile's `Semantics` needs `excludeSemantics: true`**, or its label merges with the visible name.
6. **Labels in tight spaces need `FittedBox(scaleDown)` or ellipsis**, or they overflow with large text.
7. **Providers go above `MaterialApp`**, or pushed routes and sheets can't read them.
8. **Jump rails need room after the last section**, or the last items can't scroll to the top and
   the highlight jumps back. Rails also support press-and-slide scrubbing, not just taps.
9. **On Windows, never rewrite source files with PowerShell `Get-Content`/`Set-Content`.** They
   garble non-ASCII characters such as `·` and `–`. Use the editor tools, or `[IO.File]` with UTF-8.
10. **The browser pane's screenshots are unreliable at phone size.** Use `tool/screenshot_test.dart`.
11. **Bottom navigation labels are always visible.**
12. **Check a design mock's rule details against the rulebook.** The last mock invented rules.

## How to work with me

- **Build a runnable version quickly, then show me** in the browser preview, plus an APK. Keep
  questions to a minimum.
- Put long explanations in a file and open it, because text between question pop-ups gets missed.
- Commit checkpoints when I ask.

---

## Prompt to paste into Claude Code (in the Vale Helper project folder)

> Read `docs/magical-athlete-app-brief.md` and follow it. Turn this app into one app for several
> board games: it opens into the last game played and has a game switcher in the top bar, and my
> saved Vale of Eternity data must survive. Then add Magical Athlete, focused on racer cards
> (English abilities) and the game-flow rules, for any player count the box supports. Research
> the current 2025 rulebook and the full racer list first, and never invent abilities. Do it in
> the brief's order with tests green at each step. Then show me the preview and give me the APK.
