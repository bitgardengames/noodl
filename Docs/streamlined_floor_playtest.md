# Streamlined Floor Campaign Playtest Checklist

This checklist covers the manual verification recommended for the streamlined 14-floor campaign. Follow these steps on a fresh profile to exercise pacing, layout variety, and narrative branching.

## 1. General Setup
- Use the standard campaign mode without daily modifiers.
- Reset talents or upgrades that might trivialize hazard pacing to observe the intended baseline.
- Enable subtitles/dialogue prompts in settings so the new story panels appear.

## 2. Floor Intro Narrative Flow
1. Start a new run and proceed through Floors 1–6 without skipping dialogue.
2. Confirm that each floor intro displays the correct speaker name, localized text, and automatically advances after the set duration.
3. Verify that `Esc` skips directly to the choice (when present) and that `Enter/Space/A` advances single lines.
4. Confirm that the floor is not marked ready until dialogue (and any choice) is resolved.

## 3. Branching Choice Coverage
Run at least two campaigns to cover both branches of every decision point.

### Crossroads Market (Floor 7)
- Option A — Mira's Aid: Ensure fruit goal decreases by 2 and saw stall duration increases (check transition trait list).
- Option B — Hazard Broker: Confirm an extra saw spawns and rock spawn rate increases.

### Mistbound Gallery (Floor 8)
- Option A — Bloomward Beacon: Confirm rock spawn chance drops and fruit goal decreases by 1.
- Option B — Shadow Toll: Ensure saw count increases by 1 and their speed multiplier applies.

### Veil of Mirrors (Floor 9)
- Option A — Resonant Path: Check that one saw is removed and stall duration is extended.
- Option B — Tempest Route: Validate that saw speed increases and two additional rocks appear.

For each choice:
- Confirm the selection persists if you lose and restart (re-running the floor should show the option as locked).
- Ensure the transition screen lists the extra trait with the localized description.

## 4. Layout Sanity Checks
- Floor 4/5: Corridor layout should spawn static rock walls framing a 9–11 tile channel.
- Floor 6/7/9/11: Split layout should generate intersecting dividers with traversal gaps. Verify hazard spawn counts respect reduced values from `floorplan.lua`.
- Floor 13: Boss layout should place a circular ring of static rocks and apply the `cleansingNodes` trait (slower saws, fruit shatter bonus).

## 5. Adaptive Dialogue Reflection
- After choosing Mira (ally_support), confirm ally-specific lines appear on Floors 8, 10, and 14.
- After choosing Hazard Broker (hazard_toll), confirm broker lines appear on Floors 8, 10, and 14.
- After selecting Bloomward or Shadow Toll, listen for Tinkerer lines on Floors 9 and 11.
- After selecting Resonant or Tempest, confirm Specter lines change on Floors 11, 13, and 14.

## 6. Epilogue & Victory Lap
- On Floor 14, verify the arena is open with light hazard pressure and that dialogue reflects the combination of prior choices.
- Confirm fruit goal reduces to 10 and hazard counts reset to a low-intensity setup per `floorplan.lua`.

## 7. Regression Sweep
- Pause during a story intro and ensure the menu closes without freezing the dialogue flow.
- Test keyboard, mouse, and gamepad inputs for story advancement and choice selection.
- Check that skipping dialogue still applies the chosen modifier and finalizes floor setup.

## Reporting
Log any anomalies with the floor number, chosen branch, and expected vs. actual modifier behavior. Capture screenshots if layout geometry differs from the specifications.
