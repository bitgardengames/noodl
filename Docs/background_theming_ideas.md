# Floor Background Theming Concepts

These notes outline subtle background motifs that can help differentiate each floor while keeping the playfield clean. They focus on simple silhouettes, gentle parallax elements, and restrained color blocking that reinforce mood without distracting from gameplay.

## General Guidelines
- Favor low-contrast silhouettes and soft gradients so hazards and fruit remain readable.
- Use repeating motifs sparingly—one or two distinctive shapes per floor keeps the scene evocative without clutter.
- Consider light motion (slow parallax drifting, occasional blink animations) only where it will not clash with critical telegraphs.

## Floor Concepts

### Cavern / Subterranean Floor
- Broad arc along the upper edge with jagged triangular stalactites, tapering differently per tile chunk to avoid repetition.
- Suggest distant cavern walls with offset semi-circular arches fading into darkness.
- Occasional side-wall silhouettes hinting at underground pillars or supports.
- Subtle shimmering mineral veins drawn as faint diagonal streaks that catch light when the player nears a combo threshold.

### Machine / Factory Floor
- Thin horizontal conveyor belts in the distance with slow-moving box silhouettes.
- Rotating cog outlines partially occluded behind grates, using alternating light/dark wedges.
- Vertical cable bundles hanging from above, swaying very slightly to imply energy flow.
- Soft glows from recessed indicator panels that pulse gently when multipliers increase.

### Botanical / Greenhouse Floor
- Translucent leaf silhouettes overlapping to create a canopy gradient near the top of the screen.
- Hanging vines or tendrils traced with thin bezier curves that sway on beat transitions.
- Distant glass panes with subtle diagonal lattice reflections to suggest a greenhouse structure.
- Occasional fluttering silhouettes of small insects or pollen motes during high-scoring streaks.

### Arctic / Glacial Floor
- Layered ice shelf shapes at the bottom edges, rendered with gentle blue-white gradients.
- Sharp icicle forms descending from the top, mirrored sparingly to maintain rhythm.
- Soft aurora ribbons sweeping horizontally in the far background, animated at a slow cadence.
- Crystalline fractal patterns faintly etched into the floor tiles, brightening when the player dashes.

### Urban Rooftop Floor
- Silhouetted skyline parallax with staggered building heights and antenna details.
- Rooftop HVAC units or satellite dishes drawn as simple rectangles with circular cut-outs.
- Blinking aircraft warning lights in the distance synchronized with combo milestones.
- Light pollution glow washing up from the bottom edges to simulate city ambience.

### Desert / Ruins Floor
- Half-buried archways or column fragments leaning at varied angles along the horizon line.
- Wind-blown sand streaks rendered as low-opacity curved paths sweeping across tiles.
- Distant mirage shimmer effect that subtly distorts background silhouettes on long combos.
- Carved glyph patterns faintly embossed into the floor texture, illuminated during power-ups.

### Laboratory / Neon Floor
- Hexagonal grid overlays that fade in and out to evoke holographic projections.
- Encased specimen tubes outlined with minimal line art, containing softly glowing shapes.
- Data streams represented by ascending dotted lines that accelerate with player speed.
- Ceiling-mounted mechanical arms extending in and out of view during pause transitions.

### Oceanic / Deep-Sea Floor
- Large, soft-edged light cones from imaginary submersibles sweeping slowly across the backdrop.
- Silhouettes of drifting kelp forests anchored to the floor edges.
- Bubble clusters that rise lazily from vents, dissipating before reaching gameplay elements.
- Faint outlines of distant sea creatures—e.g., jellyfish or whales—appearing briefly when special fruit spawns.

## Implementation Notes
- Reuse existing color palettes where possible, applying minor hue shifts to keep the interface consistent.
- Background assets can be authored as simple vector shapes exported to spritesheets to minimize memory.
- Consider a small library of modular overlays (e.g., stalactites, cables, vines) that can be procedurally arranged per run for variation.

