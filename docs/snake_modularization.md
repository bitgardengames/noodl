# snake.lua modularization candidates

`snake.lua` currently blends movement, rendering, collision, and upgrade logic in a single, very large module. The sections below highlight cohesive responsibilities that can be extracted into smaller files to shrink local state and clarify ownership.

## Occupancy and grid bookkeeping
- Grid helpers (`resetSnakeOccupancyGrid`, `ensureOccupancyGrid`, and the local aliases around them) encapsulate all synchronization with `SnakeOccupancy` and track the head cell cache.【F:snake.lua†L126-L159】
- Moving these into a `snake_occupancy.lua` module would keep cell tracking and spatial index maintenance isolated from movement and rendering.

## Segment pooling and trail geometry
- Functions such as `releaseSegment`, `recalcSegmentLengthsRange`, `syncTrailLength`, and `recycleTrail` manage pooled segments, compute total length, and clean up discarded trail data.【F:snake.lua†L203-L319】
- Extracting them into a `snake_trail.lua` helper would localize pooling, length math, and trimming, reducing the variable footprint in the main snake controller.

## Lifecycle and upgrade hooks
- `load`, Glutton's Wake crystalization helpers, and direction/death setters reset trail state, rebuild occupancy, and notify upgrade systems about spawned rocks.【F:snake.lua†L2032-L2129】
- Extracting these lifecycle/reset utilities into `snake_lifecycle.lua` would keep startup/respawn logic discrete from per-frame updates.

## Rendering and clipping
- `draw` orchestrates clipping, stencil setup, face visibility, and descending-hole overlays, delegating to `SnakeDraw` while managing shared buffers.【F:snake.lua†L2445-L2558】
- A `snake_render.lua` module could own stencil circle helpers, clipped head handling, and upgrade visual collection to isolate draw-only state.

## Ability activation (dash & time dilation)
- Ability routines (`activateDash`, `getDashState`, `activateTimeDilation`, `triggerChronoWard`, `getTimeDilationState`) manage timers, cooldowns, charges, and upgrade notifications.【F:snake.lua†L3339-L3498】
- Extracting them into `snake_abilities.lua` would cluster ability bookkeeping separately from general movement and collision code.

## Hazard collision evaluators
- Body collision checks for saws, darts, and lasers gather candidate segments from spatial queries, evaluate cut events, and trigger tail chops or hazard feedback.【F:snake.lua†L3683-L4259】
- Moving collision evaluation into `snake_collisions.lua` would reduce the number of hazard-specific helpers residing in the core snake file and keep movement variables cleaner.
