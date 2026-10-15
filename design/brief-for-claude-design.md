# Brief for Claude Design: Vale Helper UI redesign

Attach all 16 PNGs from `design/screenshots/`, then paste everything below the line.

---

I need a UI redesign for a small Android app I use while playing the board game **Vale of Eternity**. It works, but it isn't easy to use at the table. The attached screenshots are the current app (phone at 393×851 dp, dark theme). Please propose a redesign for every screen.

## Who uses it and how
- Me, playing 2-player with my girlfriend. She reads only Chinese and I read only English. Our copy of the game is the Chinese edition, so I can't read the cards.
- The phone lies on the table or sits in one hand. I glance at it between turns, so speed and one-handed use matter more than looks.
- What I do most, in order:
  1. **Find a card I'm looking at and read its English effect.** I recognize cards by their art, not their name.
  2. **Track my own cards** in three zones: **Table** (the shared hunting area, where cards are revealed each round), **Hand** (cards I've taken) and **Field** (cards I've summoned).
  3. **Follow the round's phases** (Hunting → Action → Resolution → End of round) with a checklist, so I don't forget cleanup steps like moving the round marker or passing the first-player marker.

## Current screens (screenshot numbers)
- **Cards tab (01–04):** a grid of all 70 card pictures, sorted by family then cost.
  - The top row has the 5 family symbols (pick one, tap again for all) and a slider for 2–8 cards per row.
  - The second row has cost buttons (pick one).
  - A ✓ on a card means I'm tracking it.
- **Card detail (05–06):** opened by tapping a card.
  - It shows the big card image, a Details section (Family, Cost, Sells for, using stone icons), Effects (with the game's Instant/Permanent/Active symbols), and Table/Hand/Field buttons.
  - Swiping right goes back, and the "My Cards" button at the top right jumps to the My Cards tab.
- **My Cards tab (07–09):**
  - Table, Hand and Field are stacked as sections. Each card is a row with a thumbnail, name, family, cost and full effect text.
  - Dragging by the ⠿ handle or long-pressing a row brings up a drop bar at the bottom (08). Tapping a row opens a menu to move or remove it (09).
- **Phase tab (10–16):**
  - Chips across the top for the 4 phases, then the phase title, a summary, "What happens" bullets, a checklist and a "Next" button.
  - If items are unticked, Next shows a warning (11).
  - During Resolution it lists my Field cards that have Active effects (13).
  - Setup, Key rules and New game buttons open sheets or dialogs (15–16).
- **Bottom navigation:** Cards / My Cards / Phase. Only the selected tab shows its label.

## What I want fixed
I still find it hard to use. These are the problems I see:

**Cards tab**
- The filter rows and the slider have no labels, so it isn't obvious what the bare numbers or the "4" mean.
- Costs 9–12 are hidden off-screen to the right.
- The tracked ✓ is tiny, and I can't tell at a glance which zone a card is in.
- At 4+ cards per row the art is small. I'd like recognition to stay fast.

**Card detail**
- The card picture takes half the screen. Its printed text is in a language I can't read, and the English section underneath repeats the same information.
- The text explaining each effect type (e.g. "Triggers once, when the card is summoned") adds clutter.
- Putting a card in Table, Hand or Field is the main action, but it sits at the very bottom.

**My Cards**
- It's a long, text-heavy vertical list, and moving cards between zones takes work.
- I want moving a card between Table, Hand and Field to feel like moving real cards, and to be faster.
- The "Clear" buttons are easy to hit by accident and there's no undo.

**Phase tab**
- It's a wall of text. The phase chips get cut off ("Resolu…", "End of …").
- The important part, the cleanup checklist, doesn't stand out.
- "New game", which wipes everything, sits next to harmless buttons.

**Overall**
- The dark-brown theme is monotone and some secondary text is low-contrast.
- Spacing and density aren't consistent from screen to screen.

## Constraints
- Android phone, built with Flutter (Material 3). Portrait, about 390 dp wide.
- **Keep the game's own art:** card images (300×419, so about 5:7 portrait), the 5 family symbols (Fire, Water, Earth, Wind, Dragon), the 3 magic-stone symbols (red = 1, blue = 3, purple = 6) and the 3 effect-type symbols (Instant ⚡, Permanent ∞, Active ⌛). All are round or hex icons on a light parchment background.
- **Keep the features.** Change how they're laid out and used. Don't add things like score tracking, multiplayer or an online mode.
- English only for now. The phase and rules text may get a Chinese translation later, so leave room for longer strings.
- It works offline, with no accounts.

## What I'd like back
1. A mockup of each screen at phone size: Cards, Card detail, My Cards (including the dragging state), and Phase (one phase plus the end-of-round state).
2. A short note per screen on what changed and why, especially:
   - how I find a card in about 2 taps
   - how I move a card between zones
   - how the cleanup checklist stands out
3. A small visual system: colors (light and dark), type scale, spacing, and the card-tile, zone and checklist components.
4. Anything you'd remove or merge to make it simpler.
