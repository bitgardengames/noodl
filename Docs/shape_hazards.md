# Shape-Driven Hazard Concepts

This note explores how to extend the existing saw blade motif—constructed from triangles, circles, and rectangles—into a broader library of hazards, traps, and environmental set-pieces while staying inside the "basic shapes + 3 px outline" visual language.

## Design Principles

1. **Silhouette First** – Combine primitives to create easily readable outlines at gameplay scale.
2. **Layered Depth** – Use offsets, scaling, and concentric shapes to fake lighting and depth.
3. **Motion Implies Detail** – Let animation do the heavy lifting instead of intricate art.
4. **Palette Tokens** – Re-use existing light/shadow/edge colors to keep everything cohesive.

## Hazard Families

### 1. Blooming Spike Patch
- **Core Shapes:** Rounded square floor plate with an inset diamond telegraph; clusters of three tall triangles for spikes.
- **Motion:** Animate the diamond pulsing before the spikes rise smoothly from the floor and lock in place.
- **Accent:** Add a shallow rim rectangle around the plate so the hazard feels rooted to the arena.

### 2. Arc Laser Turret
- **Core Shapes:** Half-circle shell (two stacked rectangles with a semicircle); small circle lens.
- **Motion:** Rotate a thin rectangle “beam” that scales in length; use particle streaks for lingering heat.
- **Accent:** Concentric outlines around the lens pulsing to telegraph firing.

### 3. Spike Roller
- **Core Shapes:** Long rectangle axle; circles at ends; alternating triangles as teeth along a central cylinder.
- **Motion:** Scroll the triangle band across the cylinder to imply rotation.
- **Accent:** Offset shadow rectangle beneath to ground the object.

### 4. Shock Floor Tiles
- **Core Shapes:** Base square tile; inset diamond (rotated square) to read as circuitry; circle nodes at corners.
- **Motion:** Animate the diamond scaling and tinting to show charge-up; draw thin rectangle “bolts” during discharge.
- **Accent:** Use alternating panel colors to create a checkerboard of safe/danger tiles.

### 5. Vent Fan Updraft
- **Core Shapes:** Concentric circles for the housing; clipped triangles arranged radially for blades; rectangle frame around the pit.
- **Motion:** Spin the triangle set; spawn vertical particle streaks to suggest airflow.
- **Accent:** Animate a translucent circle expanding to show the updraft radius.

### 6. Crushing Walls
- **Core Shapes:** Paired vertical rectangles with teeth (small triangles) on the edges.
- **Motion:** Mirror-scale the rectangles inward; add a narrow rectangle “warning strip” that flashes before closing.
- **Accent:** Cast shadow rectangles on the floor to imply thickness.

### 7. Acid Drip Pipes
- **Core Shapes:** Horizontal rectangle pipe; small circles as bolts; inverted triangle drip catch.
- **Motion:** Spawn circle particles that stretch into vertical rectangles as they fall.
- **Accent:** Make the pipe outline double-thickness by layering two rectangles for a chunkier industrial feel.

### 8. Magnet Grapplers
- **Core Shapes:** U-shaped magnet from two rectangles and a semicircle bridge; central circle core.
- **Motion:** Animate the core pulsing and extend rectangle “fields” that scale toward player metal objects.
- **Accent:** Add floating particles that follow curved paths to show attraction.

### 9. Rotating Flame Jets
- **Core Shapes:** Cylinder base via stacked rectangles; circle nozzle; triangle flame burst built from nested triangles with varying opacity.
- **Motion:** Rotate the whole assembly; animate the flame triangles scaling and color cycling through palette warm tones.
- **Accent:** Draw a circular shadow ring on the floor to mark safe zones.

### 10. Sentinel Drones
- **Core Shapes:** Circle body with smaller circle core; twin rectangle “wings”; bottom triangle sensor.
- **Motion:** Bob the entire body vertically; rotate the triangle sensor toward the player; emit rectangle beams as attacks.
- **Accent:** Use a thin outline circle offset to imply a shield when active.

## Environmental Flourishes

- **Layered Platforms:** Stack rectangles with slight scale differences and alternating palette shades to imply beveled platforms.
- **Background Machinery:** Use repeating rectangle/triangle combos in parallax to suggest pistons, gears, and conveyors.
- **Interactive Doors:** Combine large rectangles with inset circles (locks) and sliding triangle bolts for animated doorways.
- **Hazard Signage:** Create caution signs from rectangles + triangles (for warning icons) to telegraph upcoming traps.

## Implementation Tips

- **Reuse Particle System:** Most hazards can share particle templates—just swap colors and motion curves.
- **Outline Consistency:** Ensure every composite shape respects the 3 px outline by drawing components with the same stroke settings.
- **Telegraphing:** Use scaling, color pulsing, and simple shape rotations as universal “tell” language so new hazards feel familiar.
- **Sound Pairing:** Even without new art, pairing these shapes with existing audio cues will elevate perceived fidelity.

By thoughtfully layering basic shapes, animation, and palette-driven lighting, you can expand the trap roster dramatically while keeping the minimalist aesthetic intact.
