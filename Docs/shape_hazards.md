# Shape-Driven Hazard Concepts

This note explores how to extend the existing saw blade motif—constructed from triangles, circles, and rectangles—into a broader library of hazards, traps, and environmental set-pieces while staying inside the "basic shapes + 3 px outline" visual language.

## Design Principles

1. **Silhouette First** – Combine primitives to create easily readable outlines at gameplay scale.
2. **Layered Depth** – Use offsets, scaling, and concentric shapes to fake lighting and depth.
3. **Motion Implies Detail** – Let animation do the heavy lifting instead of intricate art.
4. **Palette Tokens** – Re-use existing light/shadow/edge colors to keep everything cohesive.

## Hazard Library

### Rolling Drum

* **Silhouette:** Start with a stout cylinder made from stacked circles to echo the saw hub language, then inset triangular teeth along its midline. The result feels like a chunky steamroller that still shares DNA with existing hazards.
* **Materials:** Use the arena's darker metal tone for the outer rim and a lighter hub for the core. Highlight the teeth tips with a warm accent so they pop even when the drum is partially obscured.
* **Animation:** Rotate the drum on a slow loop (≈10–12 rpm) with eased-in, eased-out speed bursts when it accelerates toward the player. A subtle wobble on the axle sells weight without demanding complex rigging.
* **Depth Cues:** Cast an elongated shadow ahead of the drum to imply a looming presence. Let a thin dust trail or scattering sparks kick off when it smashes rocks to reinforce impact.
* **Gameplay Hooks:** The drum can roll along predefined tracks, forcing players to time crossings, or pause to telegraph a crushing slam that clears fruit but threatens the snake.
