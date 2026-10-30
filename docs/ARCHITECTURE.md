# Feature ownership

Files belong to the feature that uses them, rather than global scenes/, scripts/, audio/, or assets/ buckets. Keep scenes, matching scripts, local resources, and media together in a shallow feature directory.

The actual tracked foundation is:

```text
.
├── .gitignore
├── AGENTS.md
├── README.md
├── project.godot
├── docs/
│   ├── ARCHITECTURE.md
│   └── DESIGN.md
└── features/
    └── levels/
        └── prototype/
            └── prototype.tscn
```

prototype.tscn is an empty technical bootstrap with a status label. Its location does not approve a level structure or gameplay concept.

If approved and implemented later, player files would live in features/player/, level files in features/levels/, and menus in features/menus/. A player's sprites, animations, and audio would stay with that player feature; menu audio and assets would stay with menus. These are examples, not directories or systems to create now.

Store genuinely shared components once in features/common/ only when cross-feature reuse warrants it. Approximately three distinct consumers is a useful guideline, not a strict requirement. Keep feature-owned files local until there is a concrete reason to share them. Do not introduce speculative managers, services, or autoloads.

See [AGENTS.md](../AGENTS.md) for naming, coordination, validation, and safe Git rules. See [DESIGN.md](DESIGN.md) for the provisional current direction and open decisions; gameplay decisions remain with Emir and Onur.
