# snake.lua modularization candidates

`snake.lua` currently blends movement, rendering, collision, and upgrade logic in a single, very large module. The sections below highlight cohesive responsibilities that can be extracted into smaller files to shrink local state and clarify ownership.

## Lifecycle and upgrade hooks
- `load`, Glutton's Wake crystalization helpers, and direction/death setters reset trail state, rebuild occupancy, and notify upgrade systems about spawned rocks.【F:snake.lua†L1388-L1504】
- Extracting these lifecycle/reset utilities into `snake_lifecycle.lua` would keep startup/respawn logic discrete from per-frame updates.

## Hazard collision evaluators
- Body collision checks for saws, darts, and lasers gather candidate segments from spatial queries, evaluate cut events, and trigger tail chops or hazard feedback.【F:snake.lua†L3138-L3414】
- Moving collision evaluation into `snake_collisions.lua` would reduce the number of hazard-specific helpers residing in the core snake file and keep movement variables cleaner.
