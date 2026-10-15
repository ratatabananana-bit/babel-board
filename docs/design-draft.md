# Vale of Eternity Helper — Design (DRAFT, for your review)

Status: **draft**. Sections 1–2 are waiting for your OK. The card data source is still being researched.

## Goal
A light, offline Android app for 2-player Vale of Eternity (Chinese edition) that lets you:
1. **Look up any card by its picture** and read its effect in English (main feature).
2. **Track your own cards** as Table / Hand / Field.
3. **Follow the round's phases** with a cleanup checklist, so you stop forgetting maintenance steps (secondary feature).

English only for now. All rules text sits in one file so Chinese can be added later.

## What we decided
| Topic | Decision |
|---|---|
| Who uses it | Only you, English UI |
| Card tracking | Only your cards: Table, My hand, My field |
| Phase tracker | Phase only, no round or score counter |
| Data source | Official rulebook PDF + online research + card wiki (names and images) |
| Tech | Flutter APK, sideloaded onto your phone |

---

## Section 1: screens
Three tabs along the bottom: **Cards · My Cards · Phase**

### Cards (the card-lookup screen)
- **Top bar**
  - Family chips: All, Fire, Water, Earth, Wind, Dragon (multi-select)
  - Cost chips: All, then each cost that exists (multi-select)
  - **Column slider**: drag between 2 and 8 cards per row. The grid smoothly re-flows and snaps to each count. It doesn't zoom. Your last setting is remembered.
- **Grid of card pictures**, grouped under family headers and sorted by cost. You see all 70 cards when nothing is filtered, and filters narrow the grid instantly.
- **Tap a picture** to open the detail view:
  - a big image, English name, Chinese name, family, and cost
  - an effect-type badge: Instant, Permanent, or Active, with a one-line explanation
  - the English effect text, with a ⚠ if unverified
  - three buttons: **Table / Hand / Field**

### My Cards
- Three groups: Table, Hand, Field. Each uses the same small pictures plus a one-line effect.
- Tap a card to move it to another zone or remove it.
- A **Clear table** button empties the table for the next Hunting phase.
- In Field, cards with Active effects are highlighted, as a Resolution reminder.
- Everything is saved when you close the app.

### Phase
- A cycle of **Hunting → Action → Resolution → End of round**, then Hunting again. There's also a one-time **Setup** checklist.
- Each phase has "what happens" bullets and a cleanup checklist, then a **Next phase** button.
- During Resolution, the Phase screen lists the Active cards in your Field.

**Rules content (from the official rulebook):**
- **Setup:** first player gets the first-player marker. Round marker goes on space 1. Starting score is your turn position: first player gets 1 point, second player 2.
- **Hunting:**
  - Reveal 4 cards (2 × players) and sort them by family.
  - First picks go **clockwise from the first player**. Second picks go **counterclockwise from the last player**, so the last player picks twice in a row.
- **Action:**
  - In turn order, sell, tame, summon, or remove, as many times as you like.
  - You can't end your turn with a marker still on a card.
  - Hard limits:
    - at most 4 magic stones
    - areas = round number
    - remove cost = round number
    - no change when you overpay
- **Resolution:** in turn order, use each Active effect in your areas once. Every effect must be used.
- **End of round (cleanup):**
  - ☐ Check for game end: anyone at 60+ points, or round 10 just ended.
  - ☐ Move the round marker forward 1 space.
  - ☐ Pass the first-player marker to the **left** of the current first player.
  - ☐ Clear the table in the app.
  - Remember: next round you get +1 area, and removing a card costs 1 more.

Note: Vale of Eternity never passes cards. The clockwise/counterclockwise rule is only the Hunting draft order.

---

## Section 2: data and architecture
- **Project:** Flutter, Android only. Light dependencies: `provider` for state and `shared_preferences` for saving.
- **Data** (bundled, works offline, editable without touching code):
  - `assets/cards.json` holds per card: `id, name, nameZh, family, cost, effectType, effect, verified, image`
  - `assets/cards/*.webp` holds the card images, downloaded once from the wiki and compressed (about 5–10 MB in total)
  - `assets/rules_en.json` holds the phases, bullets, and checklists. Chinese later means adding `rules_zh.json`.
- **Saved state:**
  - card → zone (all 70 cards are unique, so each card is in at most one zone)
  - the current phase and ticked checklist items
  - the grid column count
- **Code layout:** `models/`, `data/`, `state/`, `screens/` (cards, my_cards, phase), `widgets/` (card tile, filter bar, column slider)
- **When things go wrong:**
  - a missing image shows a placeholder tile with the name and cost
  - an unverified effect shows ⚠
  - malformed data shows an error screen instead of crashing
- **Testing:**
  - data: exactly 70 cards, every image exists, valid families and costs
  - state: moving cards between zones, and saving and reloading
  - widgets: filters narrow the grid, and the slider changes the column count
  - then build the release APK and install it

## Personal use only
The card images are the publisher's art, so the APK is for personal sideloading only and goes on no app store.

## Still open
- The card list and images are being researched now. I'll fill this in and mark any card whose text I couldn't verify.
