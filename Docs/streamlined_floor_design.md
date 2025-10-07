# Streamlined Floor Design Concept

## Design Goals
- Maintain a fast-paced, readable experience across floors.
- Provide visual and mechanical variety without overwhelming players.
- Connect narrative beats to gameplay modifiers so each floor feels purposeful.

## Floor Progression Structure
1. **Orientation Floors (1-3)**
   - Teach core mechanics with limited hazards and generous spacing.
   - Palette: bright, warm hues to signal safety and learning.
   - Story Beat: The snake leaves its home grove, guided by the village elder.
2. **Skill Check Floors (4-6)**
   - Introduce one new hazard per floor, layering on earlier lessons.
   - Palette: cooler twilight tones to communicate rising tension.
   - Story Beat: The elder’s guidance fades; whispers hint at a looming corruption.
3. **Adaptive Floors (7-9)**
   - Players choose between two modifiers at the start of each floor (e.g., bonus fruit vs. extra traps).
   - Palette: split-complementary schemes that contrast safe zones and danger areas.
   - Story Beat: Allies met along the path offer choices; player agency shapes the journey.
4. **Climactic Floors (10-12)**
   - Combine prior hazards in tight arenas, but add predictable telegraphs to keep deaths fair.
   - Palette: high-saturation highlights with deep shadows to evoke urgency.
   - Story Beat: The corruption reveals itself; the elder returns as a spectral guide.
5. **Resolution Floor (13)**
   - Boss-style arena with unique mechanic (e.g., cleansing nodes to purify corruption).
   - Palette: begins chaotic, shifts to harmonious gradients as objectives are completed.
   - Story Beat: Final confrontation and catharsis.
6. **Epilogue Floor (14)**
   - Low-pressure victory lap rewarding perfect play (e.g., score multiplier, cosmetic unlocks).
   - Palette: return to the grove’s calm, pastel colors.
   - Story Beat: The grove celebrates; player sees ripple effects of their choices.

## Palette Implementation Notes
- Build a palette matrix referencing moods (Calm, Curious, Tense, Dire, Triumphant).
- Each floor references the matrix to determine base color, accent, and VFX tint.
- Gradually reduce visual noise by standardizing hazard colors (danger = red/orange, safe = teal/green).
- Use particle systems sparingly; tie bursts to narrative cues (e.g., corruption motes disperse when nodes are cleansed).

## Story Integration Strategy
- Deliver story via short, skippable dialogue bubbles at floor start.
- Trigger ambient lore objects (floating text) that hint at backstory without pausing action.
- Track player choices during Adaptive Floors and reflect them in dialogue and visual changes later (e.g., saved ally appears in Epilogue).

## Maintaining Variety
- Alternate floor shapes: wide-open arenas, corridor runs, and puzzle-like patterns.
- Rotate objective hooks: survival timers, fruit quotas, cleansing nodes, escort mini-events.
- Introduce seasonal variants that recolor palettes and remix hazards while preserving progression flow.

## Quality-of-Life Considerations
- Provide palette accessibility options (high-contrast, color-blind friendly) via settings menu.
- Offer a “Story Recap” toggle on pause menu to revisit missed dialogue.
- Surface floor traits in pre-floor UI so players understand upcoming mechanics.

## Next Steps
1. Prototype the Orientation Floors with new color treatments.
2. Script branching dialogue for Adaptive Floors using existing localization tools.
3. Playtest palette readability with accessibility presets enabled.
4. Gather feedback on modifier choices to adjust difficulty pacing.
