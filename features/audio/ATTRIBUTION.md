# Licensed sound palette

Kenney created all eight included recordings. Both packs use CC0; unchanged original license notices are included in LICENSE_Interface.txt and LICENSE_Impact.txt. Credit: Kenney (https://kenney.nl).

## Sources and mapping

- Interface Sounds 1.0: https://kenney.nl/assets/interface-sounds . Copied byte-for-byte from the read-only local central-assets/audio/kenney_interface-sounds/Audio catalog; source originals were not changed.
- Impact Sounds 1.0: https://kenney.nl/assets/impact-sounds . Official author page explicitly identifies CC0. Downloaded 2026-10-31 through the page's official download link into external temporary scratch; only the five listed recordings and its license were copied into this project. The full downloaded pack is not included.

| Runtime cue | Original file | Use |
| --- | --- | --- |
| ui_confirm | confirmation_001.ogg | Small button confirmation |
| ui_back | back_001.ogg | Back, close, cancel, return, resume buttons |
| discovery | pluck_001.ogg | Brief discovery notice |
| footstep | footstep_grass_000.ogg / 001 / 002 | Alternating actual grass footsteps |
| chop | impactWood_medium_000.ogg | Single wood-impact foley at action start |
| tree_fall | impactWood_heavy_000.ogg | Short heavier wood-impact foley on falling event |

Wood impacts are restrained foley accents, not recordings of a complete tree falling or a continuous sawing loop. Assets are unchanged; runtime gain reduces volume. See Catalog.json for exact format, duration, size and SHA-256.

## Deliberately absent categories

No rain, wind, bonfire crackle or music recording was found in the verified suitable packs. Weather cues remain observable but silent. There are no synthetic replacements or ambient loops requiring pause ducking. Existing Settings Master/SFX bus volumes control every included sound; Music remains available for future licensed music.

The local Gothic Winter folder has no license file. Its official page (https://ambroggiomusic.itch.io/gothic-winter , inspected 2026-10-31) permits use in projects with credit but does not explicitly state public source asset redistribution rights; none was copied. The local Halloween pack restricts standalone redistribution and has no suitable forest ambience; none was copied.

## Runtime ownership

SoundPalette is a child of SceneFlow, not an autoload. Existing and newly added buttons connect once through SceneTree.node_added. Four UI voices process while menus are paused; eight positional voices belong to the attached world and pause/free with it. World-local cue positions are transformed to global space. Requests/playback are exposed through emitted_counts and played_counts; rapid repeats are throttled. No per-frame node scans or unbounded voice allocation are used.
