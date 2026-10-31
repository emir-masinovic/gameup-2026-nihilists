# Player model and vegetation integration

This describes implemented interfaces only. It does not assume anything about Onur's separate work or assign additional controls/features. No astronaut model, player FSM, planting action, seed inventory or farming system was implemented in this batch.

## Replaceable player visual

- [grid_player.tscn](../features/player/grid_player.tscn) keeps `GridPlayer` as the logical Node3D, with a replaceable `Body` Node3D containing the placeholder Torso/Head/Backpack. Replace Body's children while retaining the Body transform used for facing. Neither this scene nor `grid_player.gd` was edited in this batch.
- `cell: Vector2i`, `facing: Vector2i`, `moving: bool`, `try_move(world_cardinal_direction)` remain the movement interface. Steps tween for 0.16 seconds. `cell_entered(cell)` fires when a valid step starts; the visual position reaches that cell at `move_tween.finished`. The player rejects overlapping/diagonal/blocked steps.
- Camera-relative input stays in GridPlayer. Camera modes target GridPlayer's position, never a mesh/bone. Keep model scaling/pivots under Body so grid coordinates and camera targets stay independent of the asset.
- The level owns survival through `world.survival` (shared across run regions), not the model. Body temperature, wetness, food/water reserves and berry count are presentation inputs. A separate WetIndicator ring and AudioListener3D sit under GridPlayer, requiring no astronaut materials or clothing physics.
- Animation adapters can read `moving/facing`, `world.context_action.active` and `progress`. Interaction descriptions expose object kind/action/duration; callbacks and existing `world.audio_cue(cue, at)` are optional hooks. No new player FSM is required.

## Grid and vegetation

The active scene is `SceneFlow`'s playable scene. It exposes `world.grid`, `world.climate`, `world.region_state` and `world.regions`. Logical cell centers come from `grid.world_position(cell)`; validate with `grid.in_bounds(cell)` and `grid.traversable(cell)`.

`climate.cell_conditions(cell)` returns a snapshot of temperature, weather, moisture, ground health, tree health/state, burning, terrain, water level, canopy and fire hazard. Invalid cells return `{}`. This query does not change state. `grid.cells[cell.y * grid.SIZE + cell.x]` remains authoritative and is preserved across regional round trips.

Current mature-tree simulation recognizes `tree`, `tree_state` (`healthy`, `dead`, `stump`, `removed`) and `tree_health` in 0–1. A healthy living tree contributes canopy proportional to health; climate ticks update health from moisture/temperature, and dead/cut trees do not become mature trees again. Seedling stages, planting eligibility and maturation remain Onur's design/implementation; they are not inferred from this mature-tree representation.

`world.register_vegetation_visual(cell, visual: Node3D) -> bool` registers an unparented visual at a valid, unoccupied visual slot under Vegetation. It does **not** create a plant or change logical passability/health. An optional visual adapter may expose `set_health(health, dead, moisture, burned)`; otherwise it is positioned without health-material updates. The actual logical mutation and any custom seedling state remain with the integrating system.

If a plant should use the existing interaction prompt/timer, call `world.register_interactable(descriptor)`. Required registration fields are a nonempty unique `id` and valid `cell`. The common descriptor supports:

```gdscript
{
    "id": "stable-region-object-id",
    "cell": Vector2i(7, 5),
    "name": "Object", "action": "Inspect",
    "range": 1.0, # Manhattan distance in grid cells, not world units
    "duration": 0.75, "available": true, "reason": "",
    "priority": 0, "complete": Callable(), "cancel": Callable()
}
```

Callbacks take no arguments. Keep the descriptor shared and update `available/reason` when conditions change. Selection uses distance, facing, priority and stable ID. Movement cancels; Pause freezes. The common prompt displays the saved Interact binding. Registration does not introduce a separate key or control obligation.

Custom interaction/visual registrations belong to the loaded scene. Re-register them from preserved logical region data when a region loads. Do not retain freed scene nodes in the run cache. `SaveManager.discover(stable_id)` awards permanent Knowledge only once and persists atomically; use stable event IDs rather than a new ID on every harvest/plant.

## Existing survival/resource calls

`world.survival.tick(seconds, ambient, shade, safe, heat_resistance, context)` owns body temperature/wetness/reserves. The level supplies weather, bounded canopy/wind and nearby fire; fire health damage remains level-owned. `damage`, `add_berries`, `eat_berry` and `drink` preserve latched death. `exposure` is a compatibility view of body temperature and is not a second visible stat.

`region_state.foraging` owns berry availability through grid fields; it is not a seed-planting API. Climate and forage catch-up for inactive regions are bounded to 30 seconds. Active-run persistence is memory-only; New Game/Main Menu discards these models, while Knowledge/upgrades remain in the version-1 progression save.
