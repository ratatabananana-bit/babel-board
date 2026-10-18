# Table Helper — UI/UX changes for implementation

Source of truth: `Table Helper Review v2.dc.html` (interactive mockups at 360 × 780 dp).
Owner decisions are final; items marked **Keep** must not change.

## Priority 1 — Card sheet flick feedback (owner's note 1)

Replace the current flick feedback (tinted card + label on the card) with feedback on the **slot the card leaves**.

- The sheet panel follows the finger 1:1 horizontally and tilts up to 4° near the edge. Lock the axis after 6 dp of movement, so vertical drags still scroll and drag up.
- Behind the panel sits a "slot" layer the same shape as the sheet (base `#0A0A0D`).
  - Before the threshold, the slot is tinted with the target zone colour at 10% → 40% opacity, scaled by progress.
  - Past the threshold, the slot is filled solid with the zone colour.
- Zone icon + zone name (18 sp, w800), stacked vertically and centred in the **revealed strip** (the width the card has moved). They never sit on the card.
  - Before the threshold: zone colour on the dark slot.
  - Past the threshold: dark text (`#111115`) on the solid fill, and the icon swaps to a check (`check_circle`).
- Threshold is about ⅓ of the sheet width (110 dp on a 360 dp phone). Fire a light haptic tick when crossing it in either direction.
- Release past the threshold:
  1. The card flies out in the swipe direction.
  2. The slot shows "Added to {Zone}" full-width for ~400 ms.
  3. The sheet closes and the My cards badge updates.
  4. No snackbar or Undo (as already decided).
- Release before the threshold: spring back (~260–280 ms, ease-out); the tint fades with it.
- Direction comes from the module (`sheet.swipe`). Vale: left = Table, right = Hand. Swiping left mirrors everything, so the label sits on the right edge.
- Animation speed setting: Instant skips the fly-out and the hold. The confirmation still shows for one frame before closing.

## Card sheet — everything else

**Keep** the current sheet exactly: layout, fact chips (family / cost / sells), the 50 dp Table / Hand / Field buttons, the original remove ("stop tracking") icon, and drag-up for details.

Only addition:
- Put a text label next to the drag-up chevron, e.g. "⌃ Interactions" (13 sp, w600, muted).
- The label text comes from the **module**, one value per game, not per card. Suggested field: `sheet.details.hint: "Interactions"`. Add it to MODULE_SPEC, AI_INSTRUCTIONS, the schema and the validator.
- Show the label only on cards that have details content.
- Tapping the label or chevron opens the details, the same as dragging up. The chevron rotates when open.

## Card gallery — rail

- **Slim and full height.** The rail is 26 dp wide and spans the whole grid area from top to bottom (6 dp inset), with positions spread evenly. It sits in its own column (the grid has 32 dp right padding), so it never overlaps cards and the active pill is never clipped by the screen edge.
- **Fixed positions** for the module's cost range (Vale 0–10), so a cost is always in the same spot.
  - Costs the current family lacks show as 3 dp dots, not numbers.
  - Sliding over a dot snaps to the nearest existing cost.
- **Slide to select** is the main interaction.
  - Pressing anywhere on the rail starts scrubbing. The rail gets a subtle background (`rgba(36,36,43,.92)`).
  - A large bubble "Cost N" (cream pill, 44 dp tall, 18 sp w800) follows the finger, left of the rail.
  - The grid jumps live (no smooth scroll while scrubbing). Releasing picks the cost. Tapping a number still works.
- **Number pills** are 22 dp with 12 sp w800 labels:
  - **Picked:** filled cream (`#EDE2CC`) with dark text.
  - **In view while scrolling:** 1.5 dp ring (`#77757F`) with light text. This is option 2 from rail-highlight: it follows real user scrolls only.
  - **Other:** muted text.

## Card gallery — top bar

- Search gets the remaining width. Placeholder: "Search cards" (it no longer truncates).
- Replace the three-way density segmented control with **one view pill** on the right, containing two buttons:
  - **Density:** grid icon + current number. Tap cycles 4 → 3 → 2 → 4. **No pinch** (owner: too fragile).
  - **Layout switch:** grouped ↔ flowing. The icon shows the current layout (`view_agenda` = grouped, `view_quilt` = flowing). Switching resets the scroll to the top and keeps the picked cost.
- Remove the grouped/flowing toggle from the family dock. Settings keeps it as the default.
- The family dock is now just the family row (All + medallions). No cost row in the dock (owner: too easy to mis-tap).

## Card gallery — grid cells (both layouts)

- **Tracked status off the card text.** Remove the HAND / FIELD / TABLE bands that cover the bottom of the card. Instead:
  - a 2 dp outline in the zone colour, 2 dp offset;
  - a 20 dp zone-colour chip with the zone icon (dark, filled) on the **top-right corner** of the art, offset −6 dp and with a 2 dp background-coloured ring.
- **Names wrap to two lines** (11.5–12 sp, balanced) instead of truncating with "…". This applies on tablets too.

## Card gallery — grouped layout

- Every cost group is a container with the **same padding whether highlighted or not** (8 dp vertical, 6 dp horizontal, 14 dp radius), so nothing shifts and the panel lines up with the grid.
- Group header = separator: cost label pill ("COST 3", 11 sp w800, letter-spaced) + 1.5 dp rule (flex) + count ("4 cards", muted).
- **Picked group highlight** (must be obvious; the current panel melts into the background):
  - background `rgba(237,226,204,0.10)`;
  - 1.5 dp inset outline `rgba(237,226,204,0.55)`;
  - label pill filled cream with dark text;
  - rule in cream at 50%.
- The highlight stays while scrolling until another cost or family is picked (unchanged behaviour).

## Card gallery — flowing layout (redesign)

- Remove the gutter bars and the corner cost badges.
- Use even gutters: cells have 4 dp horizontal padding and 0 column gap, with an 8 dp row gap.
- Each cell has a 16 dp **cost ruler strip** above the card:
  - a 2 dp line that runs continuously across cells of the same cost;
  - the first card of a cost shows a small number pill (16 dp tall, 10.5 sp w800) at the start of the line;
  - the last card of a cost ends its line 6 dp early, so boundaries read as a gap.
- **Picked cost highlight works like a text selection:**
  - one continuous band `rgba(237,226,204,0.16)` behind every card of that cost, wrapping across rows;
  - 10 dp rounded corners only at the run ends (first card of the cost or first column; last card of the cost or last column);
  - the ruler and number pill turn cream.
- A rail jump scrolls so the target row's ruler is at the top of the viewport (offset −4 dp). This fixes the strip of the previous row's names peeking in.

## My cards

**Keep** the current layout and sizes: two columns, tinted lanes, count badges in the headers, lane descriptions, drag to move.

Changes, all in the lane header:
- Move the **collapse chevron to the left**, right after the count badge. The whole icon + name + count + chevron group is the collapse button.
- **Clear** stays at the right edge (outlined pill in the zone colour). Collapse and Clear are now at opposite ends of the row.
- Lane headers are **sticky** while scrolling, so Clear stays reachable in a long lane.
- Clear stays visible when the lane is collapsed, and is dimmed or disabled when the lane is empty.
- Undo snackbar: cream (accent) background, dark text, "{Zone} cleared · Undo", 5 s, sitting above the bottom nav.
- Let the lane description wrap or shrink rather than truncate.
- Add bottom padding to the list so the last Field card clears the nav.

## Colour rules

- Zone colours only mean zones: Table `#E9B95A`, Hand `#5ED3A9`, Field `#A891F0`.
- The **My cards total badge** uses the neutral accent (cream `#EDE2CC`, dark text), not Hand mint.
- Still to change:
  - The Round "Next" button uses amber (Table). Use the accent or a neutral instead.
  - Settings segmented buttons use the default Material violet (close to Field). Use the accent instead.
- Module tint (planned): a module tints the neutral surfaces and the accent; zone colours and layout stay fixed.

## Bugs

1. **CJK font fallback:** Chinese text on the Magical Athlete racer sheet renders as □□□□. Bundle Noto Sans SC / TC (or let the system CJK font act as the fallback) so any module can ship Chinese text.
2. **Library version label:** a repo row shows "Installed" for 1.0.0 while 1.1.0 is installed. Show "1.1.0 installed" (or "Newer installed").

## Smaller items from the review (not yet decided)

- Round: the phase name appears three times (tab, title, card header).
- Round: the cream checklist card has a hard dark "lip" shadow; in the light theme it loses its edge.
- Round / Game: content scrolls under the Next button with no fade or bar.
- "Tap again to skip them" double-tap skips open steps without showing which ones.
- Three different Clear styles: outlined pill (lanes), filled pill (checklists), plain text (This race). Unify them.
- Status position differs per module: IN RACE at the top (Magical Athlete) vs zone band at the bottom (Vale). Use the corner chip + ring everywhere.
- Library: "INSTALLED" (caps) vs "From Our games" (sentence case); letter avatars where a logo exists; "Needs app update" styled as a disabled button.
- Settings: "4 3 2" order reads backwards; the off-switch has low contrast.
