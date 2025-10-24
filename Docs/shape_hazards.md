# Hazard Catalog

This catalog documents every active hazard currently deployed in the arena. Each entry describes visual scale, behavior, and how the snake can expect to interact with it during play.

## Rocks
- **Tile Footprint:** 1×1
- **Motion:** Completely stationary once spawned. Rocks are placed either procedurally along arena walls or as debris inside floor layouts. They never translate or rotate after placement.
- **Environmental Interactions:** Act as solid obstacles. Rocks block projectiles and fruit line-of-sight, but can be destroyed by certain floor events (e.g., explosive barrels) that clear adjacent tiles.
- **Snake Interaction:** The snake cannot occupy a tile containing a rock. Contact with the head ends the run immediately, while collisions with the body segments are ignored because the snake cannot overlap with an obstacle tile.

## Saws
- **Tile Footprint:** 5×1 horizontal strip of tiles that includes the hub and every exposed blade tooth.
- **Motion:** Travel along predetermined rail paths at a constant speed. On some floors they reverse direction at endpoints; on others they teleport back to their starting node for looping patrols. Saws animate continuously, giving visual feedback about their velocity and spin.
- **Environmental Interactions:** Saws pass over fruit and floor decals but will shatter crates or other destructible props they cross. They do not clip through walls or rocks; rails are always carved to avoid static blockers.
- **Snake Interaction:** Any contact between a blade tile and the snake head causes instant death. Body segments are also cut on contact, which likewise triggers a game-over. Because the footprint spans five tiles, players must account for both the hub and trailing blade cells when planning a safe crossing.

## Lasers
- **Tile Footprint:** 1×1 emitter that projects a beam across its facing direction.
- **Motion:** Emitters pivot between predefined angles or toggle on/off according to floor scripting. When active they sweep the beam across lanes in steady arcs, often synchronised with audio cues.
- **Environmental Interactions:** Laser beams extend until they strike a wall, rock, or other solid hazard. They can trigger crystal switches and ignite combustible props if the beam rests on them long enough.
- **Snake Interaction:** The emitter tile is safe to pass when the beam is disabled. Crossing an active beam is fatal to the snake head and any body segment that intersects the path, encouraging players to time movement with the emitter’s cycle.

