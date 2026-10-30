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