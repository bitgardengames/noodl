# Floor Atmosphere & Design Checklist

## 1. Atmosphere & Visual Identity

**Goal:** Each floor should feel like a place or moment with its own energy.

| Element | Questions to Ask | Implementation Ideas |
| --- | --- | --- |
| Backdrop shader | Does it have unique motion or color dynamics distinct from the previous floor? | Introduce different scroll speeds, vignette shapes, or directional gradients. Try slow orbiting noise, soft pulsations, or subtle "parallax flicker." |
| Arena base color | Does the ground contrast clearly with the snake and fruit? | Keep base saturation low, border saturation high. Adjust hue to complement fruit color without stealing focus. |
| Border design | Is it visually clear but not harsh? | Use border tone to indicate danger level — warmer hues for high tension floors, cooler ones for early/friendly zones. |
| Lighting/vignette | Does the light gradient subtly guide focus to the center? | Consider per-floor vignette color (forest green tint → pale gold → dark indigo, etc.) |
| Particle ambience | Are there floating motes, sparks, dust, or spores to sell the atmosphere? | Add low-opacity ambient particle fields tied to floor theme (dust for ruins, pollen for garden, embers for molten levels). |

## ⚙️ 2. Hazard Personality & Rhythm

**Goal:** Every hazard type should speak differently on each floor.

| Element | Check | Notes |
| --- | --- | --- |
| Hazard mix clarity | Can players instantly recognize the hazard profile for this floor? | Each floor should have one “signature” hazard, introduced early and showcased through level pacing. |
| Rhythm curve | Does hazard frequency ebb and flow, not just ramp endlessly? | Alternate “breath” beats (tight windows → open lanes). Use fruit timing to gate intensity. |
| Laser choreography | Are beam charges telegraphed well? | Lengthen pre-fire charge on early floors, shorten later. Match shader pulse to laser warmup. |
| Saws & motion | Do saws move predictably, but with visual tension? | Add short stall frames or slight speed variance; feels more natural than pure sinusoidal motion. |
| Rocks / destructibles | Are rock colors and shatter effects readable? | Distinct palette per floor (mossy → crystalline → molten). Always emit dust/flash feedback. |

## 🧠 3. Gameplay Feel & Flow

**Goal:** Player should experience controlled chaos — tension with room to express skill.

| Check | Ask Yourself |
| --- | --- |
| Spawn pacing | Do hazards or fruit spawn in recognizable patterns or “waves”? Players subconsciously enjoy learning rhythms. |
| Safe zones | Are there any moments to catch breath between chaos spikes? Strategic calm beats emphasize intensity later. |
| Floor intro clarity | Does the player clearly read what’s new? Use intro text + mild visual accent (hazard highlight shimmer). |
| Exit clarity | Does the final fruit cluster or descent transition feel rewarding? Add subtle vignette brighten or score pulse when approaching floor completion. |
| Learning curve | Does this floor teach something unique mechanically? Floor 3 = timing; Floor 4 = positioning; Floor 5 = multi-hazard juggling. |

## 🔊 4. Audio & Feedback Layer

| Check | Detail |
| --- | --- |
| Ambient tone | Unique hum, pad, or atmospheric note per floor. Keep subtle but distinct. |
| Hazard SFX mix | EQ laser vs saw vs rock shatters so no frequency overlaps harshly. |
| Fruit collect SFX | Maybe a slightly different timbre per floor — like instruments evolving as you descend. |
| Transition music | Short, soft motif as player descends — like a “chapter break.” |

## 🌈 5. Color & Contrast Audit

Perform a quick visual pass per floor:

1. Ensure snake, fruit, and hazards are always discernible at a glance.
2. Avoid “desaturation stacking” — if the background is dull, hazards should pop.
3. Check for over-bright UI elements that clash with the floor’s palette.
4. Test colorblind visibility — ensure lasers and fruit contrast enough.
5. Do a 10-second “blur test”: zoom out or squint — can you still tell what’s going on?

## 🌀 6. Progression Arc Across Floors

Think of all floors as a musical progression:

- Floor 1–3: Colorful, legible, learning-focused.
- Floor 4–6: Introduce mixed hazards and darker palettes.
- Floor 7–10: Stylized extremes — saturated colors, dramatic shaders, higher motion.
- Final floors: Visually striking “epilogue” zones — maybe lighter or ethereal tones (contrast instead of intensity).

Each floor’s theme should feel like an emotional beat in a descent.

## 🧾 7. Final QA Checklist (Use Before Release)

| ✅ | Item |
| --- | --- |
| ☐ | Each floor’s shader, hazard pacing, and audio layer are distinct and thematic. |
| ☐ | No hazard overlaps or impossible RNG spawns. |
| ☐ | Snake, fruit, and hazard silhouettes remain readable under all shaders. |
| ☐ | Transition timing between floors feels deliberate (no abrupt audio or visual cuts). |
| ☐ | Performance consistent — shader intensity scales safely. |
| ☐ | Optional: each floor screenshot looks screenshot-worthy for marketing (strong silhouette and palette contrast). |
