# Game Design

## Overview

A small 3D isometric roguelite about exploring a world affected by climate change.

The player travels through a procedurally generated forest, discovering new places, collecting resources, and adapting to an increasingly hostile environment. The world is divided into a grid, with movement and interactions happening one cell at a time.

The goal is to create an exploration game where a few simple environmental rules lead to interesting choices and unexpected situations.

**Inspirations:** Terra Nil, Frostpunk, Hades, Factorio, and Sokoban.

## Gameplay

Each run starts near a bonfire in a new, randomly generated world.

The player explores the forest, discovers plants and environmental phenomena, and interacts with the surroundings. As time passes, changing temperatures affect the landscape and make survival more difficult.

Death ends the current run, but the player retains their discoveries and permanent upgrades. The next run starts in a newly generated world.

Runs are intended to last roughly 10 minutes.

## Climate System

Climate change is a central gameplay mechanic, not just part of the setting.

The initial simulation focuses on three connected elements:

- **Temperature:** Changes over time and influences environmental conditions.
- **Soil moisture:** Decreases with heat and affects plant growth.
- **Vegetation:** Can thrive or deteriorate depending on conditions, changing the appearance and usefulness of the forest.

For example, a healthy tree might provide shade, while a dying forest could leave previously safe areas exposed to heat.

The intention is to make environmental changes visible and meaningful during exploration.

## Progression

Exploration rewards the player with **Knowledge**, a permanent currency earned by discovering something for the first time.

Discovering a particular plant, environmental event, or interaction grants Knowledge once, even across multiple runs.

Knowledge can be spent on permanent upgrades, potentially improving environmental resistance, exploration abilities, or interaction options.

The bonfire serves as a safe place to rest and potentially manage upgrades.

## Visual Direction

The game uses low-poly 3D graphics viewed through an isometric camera.

The world is built on a square grid but should feel like a small, living forest rather than a traditional tile-based puzzle board.

The visual style should emphasize changes in vegetation, terrain, and environmental conditions.

**Engine:** Godot 4.7.2  
**Renderer:** Compatibility, with Web export in mind.

## Initial Demo

The first playable version will focus on:

- A small forest map with grid-based movement.
- A visible player character and an isometric camera.
- Procedurally generated terrain.
- Basic temperature, moisture, and vegetation interactions.
- Exploration, discoveries, and persistent Knowledge.
- A simple death-and-restart loop.
- Main menu, pause menu, and settings.

Additional biomes, environmental hazards, tools, and more complex puzzles may be explored if time permits.

## Still to Decide

The game's final name, story, victory condition, specific survival mechanics, upgrade choices, and main puzzle mechanic are still being discussed.

The design will evolve as we build and playtest the prototype.

## Current Prototype

The forest now warms over time, with short rainy, cool, and hot periods that can help vegetation recover or make exploration harder. Walking damages grass. Trees provide shade; cutting takes time, leaves a stump, and removes shelter. The bonfire offers safety and one permanent Heat Resistance upgrade for 3 Knowledge. First discoveries award 1 Knowledge each across all attempts.

For now, reaching the golden clearing ends an attempt successfully. This is a temporary goal for playtesting, not the final victory condition. Camera projection can be switched between Orthographic and Perspective. Active-run saving, further upgrades, and the final pacing remain open.

## Climate and ecosystem demonstration

Normal planted-tree maturity now requires 120 accumulated favorable seconds, with visible stages at 0, 30 and 75 seconds. Moisture and suitable local temperature remain required; dry/hot patches can fail even with shorter maturity. Mature health recovery is scaled to preserve comparable canopy strength.

Healthy mature trees cool their own cell and four cardinal neighbors by up to approximately 3.6°C combined, using existing canopy. Ground drying and recovery use local temperature; loss of a tree removes shelter immediately but changes soil moisture and health gradually. Rain and watering help surviving plants; dead trees do not resurrect. Degraded grass yellows/browns and recovers from actual conditions, while authored plantable soil stays distinct brown with wet/dry variants.

Environmental body heat exchange remains continuous at camp, with intensity-scaled camp comfort recovery, existing drying/healing, and mild-weather wet cooling tapered near comfort. Cold exposure remains dangerous. Player survival retains its existing canopy response and regional ambient temperature: local ground cooling is not added as a duplicate player bonus.

The selected interaction caption reports ground temperature and soil moisture. Debug builds may launch with `-- --microclimate-demo` for four-times sapling growth (30 favorable seconds); weather, drought stress, survival and the normal balance are not accelerated. There is no restoration victory condition or new progression system. These simplified gameplay rules require manual balance review.

## Visible ecosystem transformation

Ground cover now uses shared grass/shrub MultiMeshes plus one shared crack mesh batch. Moisture and health determine clump coverage and crack exposure; short interpolation smooths growth/retreat without changing simulation time. Brown plantable soil remains free of grass and cracks. Recovering ground regains scattered clumps before dense cover.

Mature-tree foliage uses stable model-space thinning with condition hysteresis, retaining the Kenney trunk/model identity. Sparse/dead trees expose shared procedural branches; burned wood is darkened. Saplings add leaf tiers as they grow and interpolate between the existing 0/30/75-second stages. Logical maturity, collisions, cutting, inventories and survival remain unchanged.

Debug reproduction: launch with `-- --ecosystem-demo`, start New Game and use Board Center to compare both sides of the same forest. Seed 2026 supplies a healthy left patch and initially stressed right patch, preserving water and protected routes. Clear weather runs for 120 simulation seconds, rain from 120–240, then clear weather returns. Only initial conditions/weather are prescribed; subsequent grass retreat, cracking, tree condition and recovery use the actual climate rules. No final-state painting or new objective is used. The normal game does not use this scenario. Optional `--microclimate-demo` can additionally accelerate only planted growth for testing.

Batch 2 visual polish replaces regular grass placement with deterministic clustered density, off-center clumps, varied size/rotation and subtle existing-shader sway. Cracks have three patterns with stable rotation/proportion/position differences. Ground moisture and health drive surface flecks and dampness; living recovering trees show sparse new green foliage before a full canopy. This is presentation only: normal climate pacing, growth, controls, survival and interaction rules are unchanged.
