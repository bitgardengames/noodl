# Card Shop Style Guide

This guide codifies how card upgrades should look, feel, and move inside the shop so UI polish reinforces mechanical clarity. It mirrors the structure of other shape-language docs to keep the team aligned across gameplay and interface work.

## Design Principles

1. **Visual Pillars First** – Reinforce rarity, upgrade tag, and urgency through color, contrast, and icon accents before any text is read.
2. **Readability at a Glance** – Maintain generous padding, consistent typography, and simplified iconography so cards remain legible in motion or when overlapped by tooltips.
3. **Shared Shape Language** – Lean on the same 3 px outline, rounded rectangle bases, and concentric glow layers used in arena props to keep shop screens grounded in the broader art direction.
4. **Animation Supports Meaning** – Reserve motion for state changes (hover, purchase, lock) and ensure easing communicates feedback rather than flourish.

## Component Library

### Card Anatomy

* **Base Plate:** A rounded rectangle with 3 px outline. Common cards use the neutral shop slab. Uncommon cards tint the outline with the secondary accent. Rare and above introduce layered glows.
* **Frame Slots:** Reserve a 12 px gutter between border and content. Slot in a 48 px icon box top-left and a rarity badge top-right. Icons reuse the monochrome glyph library; badges adopt the rarity gradient.
* **Content Stack:** Title (18 px, medium weight) sits above description text (14 px, regular). Descriptions break into two lines max; overflow scroll is never allowed. Tags appear as pill chips below copy, matching gameplay tags in tint and label.
* **Footer Actions:** Purchase button anchors at bottom with 16 px padding. Locked cards swap the button for a chain icon and greyed price. Preview tooltips emerge from this region.

### Rarity Language

* **Common:** Desaturated steel frame, subtle drop shadow. Animation limited to a soft brightness pulse on hover. Reference **Viscous Drag (Common)** and **Stone Whisperer (Common)** for baseline tags and copy length; both sit in the neutral palette in the [Card Catalog](card_catalog.md).
* **Uncommon:** Secondary accent outline with inner glow. Hover introduces a directional rim light that sweeps left to right. **Adrenaline Surge (Uncommon)** and **Shield Recycler (Uncommon)** demonstrate how adrenaline and defense tags should recolor tag chips in the [Card Catalog](card_catalog.md).
* **Rare:** Dual-tone gradient border, ambient particle specks that idle at 20% opacity, and a slow 8 s breathing scale on the glow layer. Study **Pulse Bloom (Rare)** to align color cues with defense and mobility tags in the [Card Catalog](card_catalog.md).
* **Uncommon:** Steady single-color border with 50% opacity corner glyphs. Study **Sparkstep Relay (Uncommon)** to match the mobility-forward motion lines and hazard interactions showcased in the [Card Catalog](card_catalog.md).
* **Epic & Legendary:** Add parallax shimmer on icon layer and subtle lens flare streaks that trigger when highlighted. **Abyssal Catalyst (Epic)** and **Event Horizon (Legendary)** show the combo + risk and mobility combinations we should emphasize per the [Card Catalog](card_catalog.md).

### Layout Guidelines

* Maintain a four-column grid at 144 px card width with 24 px gutters; drop to two columns on narrow screens.
* Align badge, title, and button baselines horizontally between cards so the eye can compare rarities quickly.
* Use tag chips as color anchors. Economy tags skew teal, defense tags lean cobalt, mobility tags trend amber, adrenaline tags adopt magenta, combo tags use violet, and risk tags apply a high-contrast black/gold split.
* Ensure long descriptions (e.g., **Temporal Anchor (Rare)**) reflow into bullet points only when the card is spotlighted in modal view; standard grid view remains paragraph-only.

### Interaction Cues

* **Hover:** Elevate card by 6 px with drop shadow expansion. Badge shimmer loops once. Tooltips appear only after 250 ms hover dwell.
* **Focus (controller/keyboard):** Outline swaps to a 4 px high-contrast stroke; maintain color language per rarity.
* **Purchase:** Trigger a 120 ms squash + stretch, followed by a white flash overlay at 40% opacity. Decrementing currency should animate from card footer to player total.
* **Locked:** Apply 30% desaturation and overlay a chain vignette. Chain breaks with a spark burst once prerequisite tags are met (e.g., unlocking **Resonant Shell (Uncommon)** after acquiring defense tags in the [Card Catalog](card_catalog.md)).

### Motion Rules

* All easing uses cubic-bezier(0.2, 0.8, 0.2, 1) for enter/exit, with back-ease reserved for celebratory reveals (first copy of **Pulse Bloom (Rare)**).
* Idle loops cap at 12 s duration. Particle bursts emit no more than 8 sprites to avoid visual noise.
* Sequential reveals cascade left to right with 90 ms staggering. Newly added cards (such as **Pulse Bloom (Rare)**) should bloom from 80% scale to 100% over 180 ms.
* When the shop refreshes (e.g., purchasing **Fresh Supplies (Common)**), fade old cards down over 120 ms, hold 60 ms, then fade new set up with simultaneous translation from 12 px below their resting position.

## Implementation Notes

* Use shared token variables for padding, typography, and shadows so updates propagate across the UI.
* Coordinate with audio to pair purchase and unlock motions with appropriate cues; defense and economy cards should feel heavier than mobility or adrenaline ones.
* Document any new tag colors or animations in the component library Figma page within 24 hours of implementation.
