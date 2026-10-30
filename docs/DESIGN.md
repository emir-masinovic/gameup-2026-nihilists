# Current game design direction

This is the authoritative current working direction for Nihilists at GameUP Türkiye 2026. Emir has authorized documenting and publishing it to guide the next implementation batch. Onur has not reviewed every decision and can review and revise the direction. It is provisional, not a unanimously approved or irreversible final design. Nothing here authorizes implementation beyond a separately scoped task.

## Vision

Build a small 3D isometric, grid-based exploration roguelite with environmental simulation and puzzle potential. A visible character explores a bounded forest diorama, moving discretely between cells as temperature, soil moisture, vegetation, and terrain conditions change. Exploration is the primary activity; a few understandable systems should create meaningful interactions.

Aim for attempts around ten minutes, failure and replayability, and persistent discoveries and upgrades. This is a hackathon demo, not a complete commercial game or ten minutes of unique authored content. Deterministic procedural generation is preferred, subject to feasibility.

Conceptual references are Terra Nil's visible transformation, Factorio's systemic consequences, Frostpunk's climate pressure, Hades' persistent progression, Sokoban's simple interacting rules, and Emir's Soil Enrichment project's discrete terrain states and efficient simulation. These references do not authorize copying code, assets, or whole designs.

## Core gameplay loop

1. Start near a bonfire in a safe area in a bounded world generated from a seed.
2. Explore cell by cell, discovering terrain, objects, resources, and climatic phenomena.
3. Respond to progressively changing environmental conditions; interact with the environment and potentially collect limited resources.
4. Earn permanent Knowledge for first-time discoveries.
5. Death ends the attempt. Knowledge and purchased permanent upgrades survive; temporary resources, map state, and survival conditions may reset.
6. Begin another attempt with a new seed and further opportunities to explore and progress.

The bonfire is a safe zone and potential rest/upgrade area. Active-run saving and bonfire save/resume behavior remain open. Do not assume checkpoints that undo death. Permanent progression and temporary run state must stay logically separate.

## Climate focus

Climate change must shape the player's experience through visible world transformation, exploration, environmental interactions, and changing rules and consequences. A single weather event is not equivalent to long-term climate change; communicate evolving environmental conditions and their effects.

The first simulation focus is **temperature + vegetation**. Supporting cell or regional data may include terrain type, temperature, soil moisture, vegetation health, passability, and shelter. Example simplified relationships: heat reduces soil moisture; dry soil degrades vegetation; healthy vegetation offers shade or shelter; vegetation loss makes exploration more dangerous. These are game rules, not a scientifically complete climate model.

The supplied hackathon brief requires a climate-focused demo, not a real-world technical solution. Relevant areas include renewable energy and sustainability, carbon footprint and conscious consumption, resilient cities, food security, oceans and seas, climate education, and zero waste. The demo need not cover every area. The supplied submission presentation deadline is **November 1, 2026, 23:59 Türkiye time**.

## Technical presentation

Use Godot 4.7.2 and the Compatibility renderer for intended Web support. Present the world in orthographic, approximately isometric 3D with a visible character, camera following, readable terrain differences, and visible environmental changes. Aim for low-poly presentation and an explorable diorama rather than a sheet of colored squares.

Keep a regular logical grid with simple, discrete, testable rules. Separate simulation data from rendering wherever practical. Prefer small bounded maps over infinite streaming. With deterministic generation, the same seed and generation algorithm version should reproduce the same initial world; the algorithm and map size remain open.

Suitably licensed Kenney 3D packs are possible sources, pending selection and licensing/attribution review. No asset download or import is authorized by this document. Organic visuals inspired by Townscaper are future polish; they must not complicate the initial logical grid.

## Progression

Knowledge rewards **first-time discoveries across all runs**, not repeated encounters. A persistent discovery registry prevents reward farming after restarting. Illustrative identifiers include `flora.berry_bush`, `flora.dead_tree`, `climate.heatwave`, and `interaction.tree_shade`; these are not a finalized catalog.

Knowledge persists even when death occurs before returning to the bonfire. Purchased permanent upgrades also survive death. Visibility, climatic tolerance, new interactions, and alternative characters or tools are possible upgrade directions, not approved implementation items. Reward amounts, prices, and exact persistence implementation remain open.

## MVP versus future ideas

The working demo scope is a bounded forest, visible player with discrete grid exploration, temperature/vegetation interactions, visible environmental consequences, failure and another attempt, and first-discovery progression. Seeded generation is preferred if feasible. Keep the number of systems small and scope each implementation batch separately.

Puzzle potential should come from understandable interacting rules: environmental changes might alter routes, vegetation might enable interactions, or changing one cell might affect neighbors. These are possibilities, not a selected signature mechanic. Avoid a generic survival walking simulator.

Health and climatic exposure/tolerance are candidate player statuses; exact death conditions and balance remain open. Hunger, hydration, and sanity are undecided or deferred, not mandatory.

Future ideas include frozen/thawed water, weather hazards, additional biomes, pollution/visibility, environmental tools, rivers/lakes, biome-constrained resources, and organic grid visuals. They are not committed MVP requirements. Do not make factories, industrial chains, protester AI, crafting trees, infinite streaming, or complicated hydrology mandatory architecture.

Suggested ownership, subject to agreement: Emir covers vision, environmental presentation, UI/menus, world composition, asset integration, save/progression, playtesting, and integration. Onur covers movement and an FSM if useful, grid rules, gameplay/puzzles, and climate integration/game logic if he agrees. Coordinate both human and AI edits to avoid simultaneous changes to the same feature files.

## Open decisions and next step

Still open: final title; story and world identity; victory/end condition; map size and biome count; generation algorithm; player status formulas and death balance; Knowledge rewards and upgrade prices; active-run and bonfire save/resume behavior; resource types and tools; signature puzzle mechanic; character appearance; and detailed implementation ownership.

The repository still contains only the technical bootstrap scene. A separate prompt will authorize the next implementation batch: Main Menu, Pause Menu, save/progression foundation, and the first playable 3D grid level. Until then, do not implement these systems or silently promote examples and proposals into approved mechanics.
