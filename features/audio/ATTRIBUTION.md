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

The original verified packs supplied no weather loops. ElevenLabs environmental assets were subsequently added as described below. Bonfire crackle and music remain absent. Master/SFX controls apply to all included sound; Music remains reserved for future music.

The local Gothic Winter folder has no license file. Its official page (https://ambroggiomusic.itch.io/gothic-winter , inspected 2026-10-31) permits use in projects with credit but does not explicitly state public source asset redistribution rights; none was copied. The local Halloween pack restricts standalone redistribution and has no suitable forest ambience; none was copied.

## Runtime ownership

SoundPalette is a child of SceneFlow, not an autoload. Existing and newly added buttons connect once through SceneTree.node_added. Four UI voices process while menus are paused; eight positional voices belong to the attached world and pause/free with it. World-local cue positions are transformed to global space. Requests/playback are exposed through emitted_counts and played_counts; rapid repeats are throttled. No per-frame node scans or unbounded voice allocation are used.

## ElevenLabs environmental audio (2026-11-01)

Eleven user-authorized Sound Effects v2 outputs are listed in CatalogGenerated.json, including prompts, settings, file hashes and estimated costs. These are generated assets, not Kenney/CC0 recordings; use is subject to the originating ElevenLabs account terms. No voice cloning, narration or music generation was used. Original MP3s and request records remain in the external shared tools workspace; only approved audio and sanitized provenance are included here. No lossy transcoding was performed.

The batch reserved 880 estimated credits at 40 credits/second from a human-verified unused 1,000-credit key allowance, leaving 120 estimated credits. There were no failed requests or retries. Actual billing was not returned by the wrapper. Requested durations were five 3.5-second loops, four 0.75-second steps, one 0.5-second drop and one 1-second croak; MP3 decoded lengths differ slightly. Technical signal checks do not certify perceptual seamlessness, content quality or final mix; short-loop repetition requires human listening.

ControllerAmbience is owned by SoundPalette and polls existing world state five times per second. Biome, wind and rain form three continuous layers; the biome layer uses two fixed voices during crossfades (four continuous players maximum during transitions). One additional bounded detail voice provides occasional droplets/croaks. SFX/Master controls apply; no Ambience slider was added. Wind uses the climate wind state and shelter; rain uses the existing binary weather state and canopy attenuation. No independent rain intensity or weather simulation was introduced. Local vegetation health reduces the living ambience, and degraded Wetlands suppress isolated frogs.

Surface footsteps use the existing single cell-entered event, with grass/mud/dry/wet classification from actual terrain/moisture. Each generated step uses five small deterministic pitch variations and three gain variations. Existing grass clips remain a missing-generated-asset fallback. Existing UI, chop and tree-fall recordings are retained. Pause suspends environmental playback; returning to Main Menu stops it immediately. Region transitions retain wind/rain and crossfade biome voices without accumulating players.

Validation: use tests/audio_palette_test.gd (headless mapping/fallback/pool tests) and tests/audio_desktop_test.gd (native waveform, weather, transition and lifecycle checks). Web export success does not establish browser playback. Check browser gesture activation, pause/resume, loop seams, short-clip repetition and relative levels manually before acceptance.
