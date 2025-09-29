# Shape-Driven Hazard Concepts

This note explores how to extend the existing saw blade motif—constructed from triangles, circles, and rectangles—into a broader library of hazards, traps, and environmental set-pieces while staying inside the "basic shapes + 3 px outline" visual language.

## Design Principles

1. **Silhouette First** – Combine primitives to create easily readable outlines at gameplay scale.
2. **Layered Depth** – Use offsets, scaling, and concentric shapes to fake lighting and depth.
3. **Motion Implies Detail** – Let animation do the heavy lifting instead of intricate art.
4. **Palette Tokens** – Re-use existing light/shadow/edge colors to keep everything cohesive.

## Hazard Library

### Conveyor Belt

* **Silhouette:** A low, wide rounded rectangle matches the existing saw track "slit" footprint so it can slot into familiar floor sockets. Two slightly inset circles at either end read as rollers and push the outline past a plain bar.
* **Materials:** Fill the body with the arena's darkest track tone, then add a slim inner highlight to suggest polished rubber. Rollers reuse the saw hub gray so they feel like part of the same machine family while still separating from the belt via a thin outline ring.
* **Animation:** Mask a repeating chevron strip across the belt interior. Scroll it slowly (≈12–16 px/s) opposite the snake's forward direction to imply mechanical motion even when the player is idle. Keep contrast gentle—just a 10–15 % value shift—so the pattern reads as texture rather than noise.
* **Depth Cues:** Drop a faint shadow beneath the belt and give the rollers a tiny vertical offset during spawn to mimic settling weight. Optional sparks or dust motes can emit when rocks collide to sell friction without cluttering the main loop.
* **Gameplay Hooks:** The moving surface can subtly tug the snake or falling fruit along its axis, or act as a timed transport lane when paired with saw blades and crushers for layered trap setups.
