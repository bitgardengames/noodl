# Floor Visual Audit

This audit reviews each story floor against quick readability heuristics. Contrast ratios were computed directly from the palette definitions in `floors.lua` and the global theme colors in `theme.lua` (relative luminance/contrast per WCAG 2.1).

## Garden Gate
- **Readability:** Snake contrast against the arena is modest (≈2.6:1) and rocks sit near-background values (≈1.2:1), making hazards easy to lose at a glance; fruit fares better but red apples still sit under 1.5:1.【F:floors.lua†L15-L23】【a157c5†L1-L14】
- **Desaturation stacking:** Rock tint is just slightly cooler than the turf, so both hazards and arena tiles lean into the same muted greens.【F:floors.lua†L18-L23】
- **UI brightness:** The golden border (0.83/0.62/0.34) is significantly brighter than the surrounding greens and can flare against muted backdrops.【F:floors.lua†L18-L21】
- **Colorblind notes:** Laser glow is only ≈1.4:1 against the arena floor; consider either deepening the arena or brightening the beam rim to keep it legible for protan/deutan players.【a157c5†L9-L14】

## Moonwell Caves
- **Readability:** Excellent separation—snake, fruit, and hazards all land ≥3.4:1, with the snake sitting above 10:1 so it never disappears against the deep blue floor.【F:floors.lua†L32-L40】【a157c5†L15-L30】
- **Desaturation stacking:** Cool blues dominate but saws stay warm and reflective, preventing the washed look.【F:floors.lua†L35-L40】
- **UI brightness:** Purple borders echo the palette and stay mid-luminance, avoiding glare.【F:floors.lua†L36-L38】
- **Colorblind notes:** Red lasers and fruit all exceed 4:1, so silhouettes remain clear.【a157c5†L21-L30】

## Tide Vault
- **Readability:** Strong contrast for snake (≈11.4:1) and saws (≈8.9:1); rocks, however, remain muted (≈3.4:1) which is acceptable but could benefit from either sharpening edges or lightening highlights.【F:floors.lua†L49-L58】【a157c5†L31-L44】
- **Desaturation stacking:** Palette mixes teals/oranges effectively; hazards keep warm glints to avoid blending.【F:floors.lua†L53-L58】
- **UI brightness:** Turquoise border is softer than Garden Gate’s gold and sits harmoniously with the floor.【F:floors.lua†L53-L55】
- **Colorblind notes:** Laser at ≈4.4:1 and fruit ≥4.8:1—no issues detected.【a157c5†L35-L44】

## Rusted Hoist
- **Readability:** Snake sits near 9.8:1 while rocks drop to ≈2.4:1; rocky hazards risk blending into the copper tiles, especially for players with low-vision.【F:floors.lua†L67-L75】【a157c5†L45-L58】
- **Desaturation stacking:** Rock and arena browns share close values—consider more metallic highlights or rim lights on hazards.【F:floors.lua†L70-L75】
- **UI brightness:** Border brass (0.5/0.42/0.24) is restrained, keeping UI cohesive.【F:floors.lua†L71-L72】
- **Colorblind notes:** Laser beam remains ≈4:1; fruit stay above 4.3:1 so silhouettes remain distinct.【a157c5†L49-L58】

## Crystal Run
- **Readability:** Snake and saw contrast remain high (≥9.7:1); rocks hover around 3.7:1, acceptable but still cooler than the floor so they can recede.【F:floors.lua†L84-L93】【a157c5†L59-L72】
- **Desaturation stacking:** Ice blues dominate yet saws add warmer reflections; consider bumping rock saturation for extra pop.【F:floors.lua†L89-L93】
- **UI brightness:** Luminous cyan border echoes crystals without clipping—no clashes observed.【F:floors.lua†L89-L90】
- **Colorblind notes:** Laser/fruit all sit ≥4.2:1 ensuring clear cues.【a157c5†L63-L72】

## Ember Market
- **Readability:** Snake (≈9.2:1) and saws (≈7.3:1) read clearly; rocks dip to ≈3.2:1, still serviceable.【F:floors.lua†L102-L112】【a157c5†L73-L86】
- **Desaturation stacking:** Warm oranges dominate but hazards run hotter (1.0/0.62/0.32), so nothing muddies.【F:floors.lua†L106-L112】
- **UI brightness:** Copper border is bright yet consistent with the market glow—no overexposed UI noted.【F:floors.lua†L106-L109】
- **Colorblind notes:** Laser contrast climbs to ≈4.7:1, and fruit maintain ≥5.1:1.【a157c5†L77-L86】

## Skywalk
- **Readability:** Bright arena severely flattens the snake (≈1.35:1) and saws (≈1.47:1); banana fruit nearly vanish at ≈1.3:1. Hazards and player need darker outlining or richer complementary hues.【F:floors.lua†L120-L129】【a157c5†L87-L100】
- **Desaturation stacking:** Pale blues dominate the entire scene, so everything shares similar saturation; consider deepening the floor or pushing hazards toward saturated ambers/reds.【F:floors.lua†L124-L129】
- **UI brightness:** Border (0.72/0.86/0.96) is only slightly darker than the arena (0.92/0.97/1.0), which helps, but any additional glow risks glare—keep overlays subdued.【F:floors.lua†L125-L127】
- **Colorblind notes:** Lasers stay around 3:1, but fruit (especially banana/golden pear) fall near 1.3–1.4:1; colorblind and low-vision players will struggle unless hues darken or outlines intensify.【a157c5†L87-L100】

## Promise Gate
- **Readability:** Rich purples ensure snake (≈6.7:1) and hazards (≈6.9:1) stay clear; rocks land just under 3:1 but still readable thanks to hue shift.【F:floors.lua†L139-L148】【a157c5†L101-L114】
- **Desaturation stacking:** Deep violets with magenta saws provide energetic contrast—no stacking issues.【F:floors.lua†L143-L149】
- **UI brightness:** Rose border (0.68/0.26/0.72) pops but stays within palette harmony.【F:floors.lua†L143-L146】
- **Colorblind notes:** Lasers at ≈5:1 and fruit ≥5.5:1 provide strong silhouettes.【a157c5†L105-L114】

## Global Suggestions
- Introduce a darker or complementary hazard tint for Garden Gate, Rusted Hoist, and Skywalk to prevent hazards from flattening into the arena.【F:floors.lua†L18-L23】【F:floors.lua†L70-L75】【F:floors.lua†L124-L129】
- Consider global outlines or emissive pulses for lasers on bright floors (Garden Gate and Skywalk) to preserve quick readability under colorblind filters.【F:floors.lua†L18-L23】【F:floors.lua†L124-L129】【a157c5†L9-L14】【a157c5†L87-L100】
- Revisit fruit assignments on Skywalk or adjust arena brightness so yellow/orange fruit stay visible for tritan/protan players.【F:floors.lua†L124-L129】【a157c5†L87-L100】
