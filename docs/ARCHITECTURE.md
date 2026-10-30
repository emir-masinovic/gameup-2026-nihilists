# Feature ownership

Scenes, scripts, resources, and local media belong to the feature that uses them. Keep the tree shallow; do not create global scenes/, scripts/, audio/, or assets/ buckets. Share a component only when reuse warrants it, and keep shared resources in one place. No external assets are used in this prototype.

## Current filesystem

```text
.
|-- .gitignore
|-- AGENTS.md
|-- README.md
|-- project.godot
|-- docs/
|   |-- ARCHITECTURE.md
|   `-- DESIGN.md
|-- features/
|   |-- menus/
|   |   |-- main_menu.gd / main_menu.tscn
|   |   |-- pause_menu.gd / pause_menu.tscn
|   |   |-- options_menu.gd / options_menu.tscn
|   |   |-- style_category_active.tres
|   |   `-- scene_flow.gd
|   |-- settings/
|   |   |-- settings_manager.gd
|   |   `-- audio_bus_layout.tres
|   |-- save_system/save_manager.gd
|   |-- player/grid_player.gd / grid_player.tscn
|   `-- levels/
|       |-- prototype/prototype.tscn
|       `-- forest/
|           |-- forest_level.gd / forest_level.tscn
|           |-- forest_tree.tscn
|           |-- grid_data.gd
|           |-- camera_orbit.gd
|           `-- shader_grid.gdshader
`-- tests/
    |-- foundation_test.gd
    |-- desktop_test.gd
    |-- settings_restart_test.gd
    |-- video_desktop_test.gd
    |-- grid_world_test.gd
    |-- playtest_feedback_test.gd
    |-- feedback_desktop_test.gd
    `-- camera_grid_test.gd
```

Godot-generated `.gd.uid` companions belong alongside their scripts and should be committed. `.godot/` editor, import, UID, and shader caches remain ignored. The original prototype scene is retained untouched.

## Reusable foundation (Phase B)

The project starts at `main_menu.tscn`. `SceneFlow` owns scene transitions and the pause overlay; `application/run/playable_scene` selects the game scene, falling back to the original prototype when unset. Transitions always clear pause state. Pause uses an always-processing overlay on canvas layer 20, above the world HUD while the game tree and movement tweens stop. Both menu contexts instantiate the same `options_menu.tscn`. Closing nested Options returns to its parent; it does not resume the game. Options has an opaque full-screen background and a container-authored footer with Back on the left and category-only Restore Defaults on the right. A persistent selected sidebar accent replaces duplicate content headings; the settings panel has a subtly lighter background. Menu layouts are editable PackedScenes; Options builds repeated setting/binding rows from data. No editor plugin or external UI library is required.

`SettingsManager` owns `user://settings.cfg`, applies video/audio settings, and installs the centralized movement, interaction, and pause InputMap actions. Each game action has two physical keyboard bindings. Loading validates values and rejects conflicting binding sets. Rebinding leaves built-in `ui_*` navigation actions intact. The shared Options component calls this service; it contains no movement rules. Music and SFX buses send to Master through `audio_bus_layout.tres`. Window mode, resolution, and VSync controls are disabled on Web/headless backends; resolution is also disabled while fullscreen (desktop resolution is used). Saved window sizes are constrained to the usable display area. Video adds 3D MSAA Disabled/2×/4× and shadows Off/Low/Medium/High (512/1024/2048 directional atlas sizes for enabled qualities). The forest subscribes to graphics changes to enable/disable its sun shadows. FXAA and TAA are not exposed in Compatibility. Existing settings files remain readable with defaults for new fields; Exit is hidden on Web. No controller rebinding is implemented.

`SaveManager` independently owns version-1 `user://progression.json`. Its small API loads safe defaults, validates progression data, and replaces saves through a temporary file. Discovery identifiers, Knowledge, and upgrade identifiers are storage fields, not implemented reward or upgrade mechanics. Missing, malformed, or unsupported-version data returns defaults without overwriting the original. `run_path` is reserved for separate temporary run data; no run serialization or restoration is implemented, so Continue is deliberately disabled. Settings are never stored in progression data.

These three autoloads have distinct, currently required responsibilities. Avoid adding a generic manager or serialization framework around them.

## First grid world (Phase C)

The Phase C `application/run/playable_scene` setting points to `forest_level.tscn`; generic scene-flow code does not depend on the forest. `grid_data.gd` owns a regular 17 × 17 grid, deterministic RNG generation version 1, passability, and cell-to-world conversion. The same seed and algorithm version reproduce the same initial cells. The level's exported seed defaults to 2026; repeated New Game currently uses that seed. A clear spawn area and central routes guarantee a valid starting position.

`forest_level.gd` renders data using shared meshes/materials and a reusable tree scene. This is a bounded placeholder forest, not climate simulation. Ground tile meshes meet exactly at cell boundaries. `shader_grid.gdshader` draws thin dark boundaries in world coordinates, with derivative-based antialiasing for readable lines at different zoom levels. It adds no gaps, overlay geometry, or depth conflicts; logical coordinates are unchanged. MSAA still handles mesh silhouettes. The normal HUD only displays FOREST in the upper-right. `grid_player.gd` independently checks target cells and animates one cardinal step at a time. Tree cells block movement. `camera_orbit.gd` stays centered on the world grid using an orthographic camera. Mouse wheel zooms smoothly between sizes 24 and 56 (default 42); rebindable orbit gestures rotate around the fixed center in continuous yaw and pitch, including underneath the board. An analytic orientation frame transports the camera up direction through poles without a look-at singularity or automatic horizon flip. Button release, focus loss, and pausing cancel active drags. Controls includes two-slot camera binding buttons and a persistent Mouse Sensitivity slider (0.002-0.020 radians per pixel; default 0.008), reset with Controls defaults. Player movement does not move the target or change camera-relative input coordinates. Zooming in deliberately crops some map edges; zoom out to see the whole forest. No player FSM is needed yet.

Climate simulation, vegetation health, Knowledge rewards, upgrades, death/survival rules, bonfire saving, interaction mechanics, and puzzles are not implemented. The interaction action exists only as an input foundation.

## Focused validation

Run with the Godot 4.7.2 executable from the repository root:

```text
godot --headless --editor --import --quit
godot --headless --script res://tests/foundation_test.gd
godot --headless --script res://tests/settings_restart_test.gd -- --write
godot --headless --script res://tests/settings_restart_test.gd
godot --headless --script res://tests/grid_world_test.gd
godot --script res://tests/desktop_test.gd
godot --headless --script res://tests/playtest_feedback_test.gd
godot --script res://tests/feedback_desktop_test.gd
godot --headless --script res://tests/camera_grid_test.gd
godot --script res://tests/video_desktop_test.gd
```

The restart checks must run in the shown write/read order. Tests use separate test configuration/save filenames and remove them afterward; they do not overwrite normal user saves or settings. The desktop test requires a real display and temporarily toggles fullscreen/VSync without saving those changes. Set `NIHILISTS_CAPTURE_DIR` to an existing directory outside the repository to capture optional menu/world screenshots. Grid tests can also run without `--headless` for Compatibility rendering checks.

## Standalone resolution and FPS checks

Godot's embedded Game view controls its own viewport sizing (Fixed Size, Keep Aspect Ratio, or Stretch to Fit), and embedded games do not support window mode changes. This can mask native window resizing. For desktop resolution/fullscreen testing, disable **Embed Game on Next Play** in the Game view menu, or launch the project directly with the Godot executable and `--path` (without `--editor`). No embedded-view workaround changes standalone behavior. Web window mode, resolution, and VSync controls remain disabled.

The standalone video test selects resolutions through Options and checks the actual native window size, configuration persistence, and footer bounds. The restart test reloads settings in a separate process. `video_desktop_test.gd` also measures real process-frame throughput and reports Godot's FPS monitor beside the selected cap and display refresh rate. It uses the menu to isolate cap behavior from world rendering cost.

To compare 60, 120, and Unlimited manually, run standalone, disable VSync in Video, and compare Godot's debugger Monitors FPS reading or run the video test. Unlimited means `Engine.max_fps = 0`, not guaranteed performance. Repeat with VSync enabled: measured FPS is additionally constrained by display refresh, driver/compositor behavior, and CPU/GPU load. No public FPS overlay is added.

References: [Game embedding](https://docs.godotengine.org/en/stable/tutorials/editor/game_embedding.html), [Engine.max_fps](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-property-max-fps).

See [AGENTS.md](../AGENTS.md) for naming and Git rules and [DESIGN.md](DESIGN.md) for game direction and open decisions.

Mouse bindings share the existing InputMap action dictionary: positive integers encode physical keys, negative integers encode mouse button indices, and zero represents an empty slot. Older keyboard-only settings merge camera defaults during loading. Capture begins after a binding button activates; button release cannot bind itself. Escape cancels capture. Conflicts are checked across gameplay and camera actions; orbit requires a held mouse button, while zoom accepts mouse buttons/wheel directions. Controls defaults restore all bindings and sensitivity. Horizontal orbit retains the world yaw axis, while pitch carries the viewing up direction continuously over poles; there is no independent roll control.

## Projection and interface theme

Gameplay Options selects Orthographic (default) or Perspective. SettingsManager persists projection separately from Controls, and Gameplay defaults reset projection only. Both projections share the free orbit pivot and use zoom sizes 10-56; perspective uses a 55-degree field of view and adjusts camera radius with zoom. Near/far planes are 0.1/200.

The shared forest Theme uses warm dark greens, earthy button surfaces, and Alegreya Sans Regular from the official Google Fonts repository (`ofl/alegreyasans/AlegreyaSans-Regular.ttf`). The redistributed SIL Open Font License is included in `features/menus/fonts/OFL.txt`; no paid assets are used.
