# Floor Color & Progression Audit

This audit reviews the current eight playable floors against Sections 5 (Color & Contrast) and 6 (Progression Arc) of the Floor Atmosphere & Design Checklist. Findings are based on the palettes and thematic descriptions in `floors.lua` and `Docs/floor_progression.md`, along with expected hazard/ui behavior from existing assets.

## 🌈 Section 5 — Color & Contrast Checks

| Floor | Readability (snake/fruit/hazard) | Desaturation Stacking | UI & HUD integration | Colorblind considerations | Blur / silhouette read | Notes & Recommendations |
| --- | --- | --- | --- | --- | --- | --- |
| 1 — Garden Gate | Strong contrast between mint snake and deep green arena; saws lean warm copper | Background is moderately muted, saws/fruit stay saturated enough | HUD golds align with arena border; avoid adding cooler overlays | Saws and fruit stay lighter than arena; consider outlining lasers if introduced later | High — snake pops as light mid-tone | Maintain current palette; ensure garden shaders do not add green tint to hazards | 
| 2 — Moonwell Caves | Pale snake and pears read against navy base; rocks risk blending | Background and arena share low saturation; add specular pops to hazards | HUD orange elements may feel bright; slight desaturation may help | Magenta laser prototype could blend; suggest cyan charge-up light | Moderate — snake silhouette fine, rocks hazy | Introduce higher-contrast rock highlights and hazard rim lights |
| 3 — Tide Vault | Citrus saws and lime snake readable vs teal arena | Arena borderline muted; ensure waves do not dim hazards simultaneously | UI gold ok; avoid overlay blues that flatten contrast | Red/green colorblind players may lose lime vs teal — add navy outline to snake body | Strong — citrus elements anchor focus | Consider alternating saw colors (amber/white) for clarity |
| 4 — Rusted Hoist | Bright amber snake vs dark bronze ground works; saws similar hue to snake | Palette trends toward warm browns; risk of snake/saw merging | HUD oranges may oversaturate; add cooler accent to scoreboard | Colorblind readability decent but rely on luminance; ensure lasers use teal/white | Moderate — busy rust vignette could reduce clarity | Add cooler sparks or steel beams for hazard distinction |
| 5 — Crystal Run | Ice-blue snake vs navy arena; saws pale cyan, distinct | Background aurora adds saturation; hazards maintain brightness | UI golds contrast nicely; no clash | If lasers appear, ensure they skew warm to avoid cyan-on-cyan | High — luminous hazards stand out | Keep particle density low to avoid wash-out |
| 6 — Ember Market | Snake gold vs charcoal arena; hazards bright orange — readable | Warm-on-warm; need darker shadows to prevent stacking | HUD oranges risk blending; introduce embered teal as UI accent | Red/green colorblind may struggle with snake vs saw luminance — add glowing edge to hazards | Moderate — ember shader bloom could obscure | Implement pulsing light strips to carve silhouettes |
| 7 — Skywalk | Snake (sunset) vs pale arena; hazards tan may fade | Very bright arena reduces contrast; need darker structural lines | HUD gold pops too much on pastel sky; lighten/soften | Colorblind: fruit vs hazards both warm; add cool halo to hazards | Low-moderate — blur test loses hazard detail due to high values | Darken bridge edges, add cloud shadows to reintroduce contrast |
| 8 — Promise Gate | Magenta snake vs violet arena; hazards pink may merge | Saturation high but similar hue; rely on glow intensity | UI orange clash with magenta; consider switching to pale violet UI | Colorblind: differentiate lasers with cyan pulses; fruit should lean gold | Moderate — silhouettes ok but busy shader pulses | Add neutral dark structures or white highlights to separate hazards |

### Global Observations
- **Laser readability:** Later floors lack explicit contrasting laser hues in palettes; introduce white/cyan charges or dark outlines so beams remain visible across colorblind profiles.
- **HUD palette:** Default warm UI elements can clash on Floors 6–8; provide per-floor HUD tints or adaptive alpha.
- **Hazard sheen:** Repeating warm saw colors (Floors 1, 3, 4, 6, 7, 8) risk monotony. Consider per-floor emissive accents tied to themes (e.g., teal sparks in Hoist, violet glows in Promise Gate).

## 🌀 Section 6 — Progression Arc Review

| Stage | Floors | Palette & Mood Progression | Compliance | Gaps & Adjustments |
| --- | --- | --- | --- | --- |
| 1. Learning (bright, legible) | 1–3 | Floor 1 welcoming greens, Floor 2 cool blues, Floor 3 teal/citrus — clear thematic shifts and readable contrasts | ✅ | Ensure Floor 2 hazards pop more against muted background |
| 2. Mixed hazards / darker | 4–6 | Rusted Hoist and Ember Market deliver darker, hazard-heavy tones; Crystal Run skews cool but still bright | ⚠️ Partial | Floor 5 feels brighter/cleaner than guideline; consider pushing deeper shadows or moving to stage 1; ensure hazard mix escalates |
| 3. Stylized extremes | 7–10 | Skywalk very bright pastel, Promise Gate vivid magenta; Floors 9–10 absent | ❌ | Need at least two additional dramatic floors. Skywalk lacks contrast/drama — adjust shader motion/intensity to sell “extreme” beat |
| 4. Epilogue | Final | Promise Gate acts as finale but leans dark/saturated rather than ethereal | ⚠️ Partial | Consider a lighter, ethereal post-finale space or adjust Promise Gate palette to include luminous whites/pales |

### Progression Notes
- **Missing Floors 9–10:** The checklist expects ten floors, but only eight are defined. Plan new late-stage concepts (e.g., storm-swept industrial, luminous void) to complete arc.
- **Emotional cadence:** Transition from Floor 6 (fiery market) to Floor 7 (bright pastel) feels abrupt. Introduce intermediary visual cues (e.g., twilight sky) or adjust palette to create smoother descent.
- **Shader escalation:** Later floors reuse `auroraVeil`; consider unique shader variants for higher drama (particle storms, parallax void).
- **Epilogue treatment:** Promise Gate could lighten center vignette or introduce iridescent accents to evoke closure instead of tension.

## Recommended Next Steps
1. Prototype HUD palette overrides per floor to maintain harmony on warm-heavy stages (6–8).
2. Add secondary hazard color passes (rim lights/glows) focusing on colorblind-safe contrasts, especially where snake/hazard hues converge.
3. Design and document Floors 9–10 with bold shader concepts and contrasting palettes to fulfill the stylized arc requirement.
4. Revisit Skywalk lighting to deepen silhouettes without losing its airy identity (cloud shadows, cooler structural lines).
5. Evaluate Promise Gate as finale; either introduce a distinct epilogue floor or adjust palette toward ethereal luminance to meet checklist guidance.
