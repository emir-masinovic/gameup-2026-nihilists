# Nihilists — GameUP 2026

A collaborative Godot project for team Nihilists at the climate-focused GameUP Türkiye 2026 hackathon. The eventual game must address climate change within the event's focus areas. Final title, gameplay, genre, art style, and level structure are undecided.

Use **Godot 4.7.2 stable**. This foundation contains only a technical startup scene displaying “Nihilists — prototype pending”; it is not an approved game level.

## Getting started

```sh
git clone https://github.com/emir-masinovic/gameup-2026-nihilists.git
cd gameup-2026-nihilists
```

Import project.godot in Godot 4.7.2, open the project, and press F6 to run the current scene or F5 to launch the configured startup scene. No plugins or external assets are required.

Emir covers UI, level design, visual direction, asset integration, and general systems. Onur covers player FSM, movement, dash, and gameplay mechanics once agreed by the team. Both developers use AI agents.

Read [architecture](docs/ARCHITECTURE.md) and [operational rules](AGENTS.md) before editing. main is the shared branch; coordinate shared-file edits and use feature branches for larger work. Agree on the gameplay concept together before implementing it.
