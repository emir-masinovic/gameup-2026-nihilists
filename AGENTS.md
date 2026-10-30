# Working in this repository

Read README.md, docs/ARCHITECTURE.md, current files, and Git status/diff before editing. Final gameplay and title are undecided. Protect human-approved decisions; ask before changing them. Do not infer a genre, mechanics, art style, levels, saving, combat, or puzzles.

## Filesystem and naming

Use shallow, feature-owned directories under features/. Colocate a feature's scenes, scripts, sprites, animations, audio, and local resources. Create only populated directories needed by actual work; no empty folders or .gitkeep files. Shared resources exist once. Use features/common/ only for genuinely reusable components; about three distinct consumers is a guideline, not a threshold. Do not add speculative managers, frameworks, services, or autoloads.

For this repository, folders and filenames use snake_case, including .tscn, .gd, .tres, sprites, and audio. Match scene/script basenames where useful. Avoid redundant prefixes. GDScript class_name, enum types, and node names use PascalCase. Methods, variables, and signals use snake_case; internal members use _snake_case. Constants and enum values use UPPER_SNAKE_CASE.

## Ownership and scope

Emir focuses on UI, level design, visual direction, asset integration, and general systems. Onur focuses on player FSM, movement, dash, and gameplay mechanics when approved. These are coordination areas, not implemented features or approved design requirements. Review another developer's work before modifying it. Coordinate shared-file edits; AI agents must not edit the same shared files concurrently.

Prefer editor-authored Godot scenes where practical. Keep AI changes small, focused, and reviewable. Do not purchase, generate paid content, or introduce external assets without approval. Do not copy code, assets, or designs from Castlevania or the older GameUP scaffold.

## Validation and Git

Use Godot 4.7.2. Validate project import, affected entry scenes, and resource references after relevant changes. Check the final diff and status; do not track .godot/ caches, credentials, or incidental output. Keep checks focused and report failures honestly.

main is the shared initial branch. Use separate feature branches for larger edits. Inspect branch, HEAD, remotes, and working tree before Git changes. Preserve unrelated work. Never reset, clean, force-push, or reconcile unexpected history automatically. Fetch/check remote state before a normal push; stop on unexpected changes, authentication failures, or branch protection. Commit only reviewed task files. The initial foundation contains no gameplay.
