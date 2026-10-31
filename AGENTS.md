# Working in this repository

Read README.md, [docs/DESIGN.md](docs/DESIGN.md), docs/ARCHITECTURE.md, current files, and Git status/diff before editing. DESIGN.md is the authoritative current working direction, authorized for publication by Emir and open to Onur's review and revision. Protect human-approved decisions; ask before changing them. Distinguish working direction from open decisions and examples; never silently promote proposals into approved mechanics. Implement only what the current task authorizes.

## Filesystem and naming

Use shallow, feature-owned directories under features/. Colocate a feature's scenes, scripts, sprites, animations, audio, and local resources. Create only populated directories needed by actual work; no empty folders or .gitkeep files. Shared resources exist once. Use features/common/ only for genuinely reusable components; about three distinct consumers is a guideline, not a threshold. Do not add speculative managers, frameworks, services, or autoloads.

For this repository, folders and filenames use snake_case, including .tscn, .gd, .tres, sprites, and audio. Match scene/script basenames where useful. Avoid redundant prefixes. GDScript class_name, enum types, and node names use PascalCase. Methods, variables, and signals use snake_case; internal members use _snake_case. Constants and enum values use UPPER_SNAKE_CASE.

## Ownership and scope

Emir focuses on UI, level design, visual direction, asset integration, and general systems. Onur focuses on player FSM, movement, dash, and gameplay mechanics when approved. These are coordination areas, not implemented features or approved design requirements. Review another developer's work before modifying it. Coordinate shared-file edits; AI agents must not edit the same shared files concurrently.

Prefer editor-authored Godot scenes where practical. Keep AI changes small, focused, and reviewable. Do not purchase, generate paid content, or introduce external assets without approval. Do not copy code, assets, or designs from Castlevania or the older GameUP scaffold.

## Validation and Git

Use Godot 4.7.2. Validate project import, affected entry scenes, and resource references after relevant changes. Check the final diff and status; do not track .godot/ caches, credentials, or incidental output. Keep checks focused and report failures honestly.

The permanent team workflow is **working branches → development → main**.

- Emir develops on the permanent `emir-codex` branch. Onur develops on his own working branch; do not assume an existing historical feature branch is disposable.
- Reuse permanent working branches for small changes; a new feature branch is not required for every change. Keep small logical commits and integrate frequently.
- Submit tested working-branch changes through PRs into `development`, the shared integration/testing branch. After integrated testing and human acceptance, promote `development` to stable `main` through a separate PR.
- Periodically fetch and synchronize working branches with `development`. Fast-forward when possible; otherwise use a reviewed normal merge without rewriting history. On shared-history synchronization PRs, preserve ancestry with merge commits rather than squash/rebase.
- Inspect branch, HEAD, remotes and working-tree changes before Git operations. Never force-push shared branches, discard another developer's work, reset/clean away human edits, or reconcile unexpected divergence automatically. Stop and report conflicts, unexpected changes, authentication failures or branch protection.
- Commit only reviewed task files. Preserve the user-owned uncommitted `project.godot` edit unless explicitly authorized to include it. Publishing and merging still require the task's authorization; branch synchronization is not blanket permission to push or merge.
- Preserve `feature/microclimate-balance` and its paused analysis; it is not permission to implement microclimate or alter gameplay.
