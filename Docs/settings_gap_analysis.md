# Settings Gap Analysis

## Existing Options
The current settings screen exposes only a handful of options: display mode, windowed resolution, music/SFX mute toggles, volume sliders, and language selection.【F:settingsscreen.lua†L16-L23】 These are also the only fields persisted in the user settings file, reinforcing that the game lacks additional configuration hooks at the code level.【F:settings.lua†L1-L9】

## Notable Missing Settings
Below is a non-exhaustive list of common settings that are absent yet frequently expected by players, platform holders, or accessibility guidelines.

### Video & Display
- **VSync / frame rate cap** – Lets players eliminate tearing on fixed-refresh monitors and helps laptops or handhelds manage thermals by capping GPU load.
- **Window size & borderless full-screen** – Provide multiple window sizes, a borderless option, or per-axis resolution scaling to better fit ultrawide monitors and streaming overlays.
- **Brightness / gamma / contrast sliders** – Essential for visibility across varied displays and HDR-to-SDR tone mapping quirks.
- **UI scale & text size** – Improves readability on high-DPI monitors, TVs viewed from a couch, and Steam Deck handheld mode.
- **Color filters or colorblind presets** – Assist deuteranopia/protanopia/tritanopia players in distinguishing critical fruit, hazards, and UI cues.
- **Screen shake / post-processing toggles** – Allow sensitive players to disable potentially nauseating effects.
- **Performance diagnostics (FPS counter, latency graph)** – Helpful when troubleshooting stutters on lower-end hardware.

### Audio
- **Per-channel sliders (UI, ambience, voice)** – Give finer control when balancing music against gameplay-critical SFX cues.
- **Dynamic range or “night mode” compression** – Popular on consoles and handhelds where headphone vs. speaker usage varies.
- **Subtitle / caption options** – If narrative VO or impactful SFX cues are added later, the groundwork for accessibility captions should be laid out.

### Input & Controls
- **Key and gamepad remapping** – Currently hard-coded gameplay bindings limit accessibility for left-handed players and alternative peripherals.【F:controls.lua†L6-L31】 Custom mapping is widely expected on PC and many console certification checklists.
- **Analog sensitivity & deadzone adjustments** – Beneficial for controllers with drift or players preferring tighter/looser stick response. Only a fixed deadzone is present in the settings screen logic.【F:settingsscreen.lua†L14-L22】
- **Toggle vs. hold preferences** – E.g., dashing or time-dilation could support toggle modes for mobility-impaired users.
- **Vibration / haptics control** – Standard for console releases and helpful for accessibility comfort.

### Gameplay & Accessibility Quality-of-Life
- **Difficulty modifiers (speed, damage forgiveness)** – Enable broader player skill coverage and satisfy platform accessibility requirements.
- **Assist options (slow time, aim assist, input buffering)** – Already partially present in gameplay, but exposing them as tunable settings increases inclusivity.
- **Tutorial / tip reminders, goal tracking overlays** – Let returning players skip or re-enable onboarding UX.
- **Localization fallbacks** – Offering font overrides for CJK languages or dyslexia-friendly fonts can prevent rendering issues on diverse systems.

## Recommendations
1. **Establish a settings framework** that supports categorized tabs, descriptors, and per-setting validation so new options integrate smoothly with save serialization.
2. **Prioritize accessibility-critical toggles** (colorblind filters, key remapping, text scaling) to meet community expectations and potential platform certification requirements.
3. **Audit hardware targets** (PC, Steam Deck, potential consoles) and add compatibility toggles like VSync, FPS cap, and input sensitivity to reduce support friction.
4. **Document default behaviors**—for example, clarify that screen shake or vibration are currently fixed—and track user feedback to guide which settings deliver the most value first.

Addressing these gaps will broaden the game’s reach, minimize hardware-specific issues, and demonstrate a commitment to player comfort and accessibility.
