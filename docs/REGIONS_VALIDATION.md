# Regional demo validation

Extends local checkpoint `10333f0`; no push or deployment. The previous four commits remain intact.

## Scope and architecture

Three deterministic connected regions now retain logical world/climate state across round trips while loading only one graphical world. Shared survival and ordered Drylands stress/mitigation → Wetlands recovery/refuge objectives give exploration a purpose. Exit/arrival cells, camera state, Pause/Options and held input are covered. Inactive catch-up is capped at 30 seconds; this approximates inactive time rather than simulating every missed second. Run state is memory-only.

Actual health/moisture drives green → yellow/brown, sparse plants, char and recovery. Pond surfaces shrink/refill with authoritative water levels. Four genuine accelerated simulation captures demonstrate healthy/drought/charred/recovered states; the stress scenario uses prolonged imposed heat/rain and is not a claim about ordinary ten-minute pacing. GPU A/B testing established terrain self-shadow acne as the diagonal artifact; disabling terrain casting while retaining received tree shadows removes it.

## Audio and provenance

Local central-assets was read-only. Kenney Interface Sounds supplied confirm/back/discovery. Local Gothic Winter/Halloween assets were excluded because public source redistribution rights were unclear/restricted. Since suitable local forest recordings were missing, five recordings were selected from the official Kenney CC0 Impact Sounds pack: three grass steps and two wood impacts (chop/falling foley accents). Eight Ogg recordings total 59,971 bytes. [Attribution](../features/audio/ATTRIBUTION.md), licenses and Catalog.json retain exact file/duration/hash records. Rain, wind, bonfire crackling and music remain absent. Sound routing reuses Master/SFX settings; no new autoload or audio engine.

## Validation evidence

Final integration checks passed: foundation52, climate884, ecosystem3778, gameplay16, interactions12, progression42, objectives51, grid121, camera grid39, projection67, bindings9, settings layout87, feedback48, HUD14, presentation67, nature32, audio30, regional state3861 and regional gameplay71. Settings write/restart/reload passed. Climate transformation passes for actual pond drying/refill, vegetation damage, ignition and gradual recovery. Movement tests were expanded after browser testing exposed duplicate key-to-grid directions at the default camera angle; 8,384 movement checks pass, including real InputMap movement at the default camera yaw and above/below/pole views. Focused grid121/regional71/camera39 checks also pass after the correction.

The regional gameplay test walks actual routes and interactions through a full victory, preserves stumps/logs/cut history on a round trip, checks one graphical world and camera/held-input/Pause behavior, and observes 15 real climate seconds beside the Wetlands habitat. This is automated scenario validation, not human pacing review. It passed both headless and actual desktop Compatibility rendering.

Desktop tests also passed feedback layout (66 checks at 800x600,1152x720,1600x900), polish (zero failures), and real audio waveforms for all six categories through WASAPI. The Dummy driver skips physical decoder playback in headless tests; dispatch counts do not claim audibility. Subjective mixing remains a manual review.

Representative fixed-seed desktop: 120 FPS cap held, 243 draw calls,245 nodes,42.8 MiB debug static memory,360 climate ticks in1569ms. Prior checkpoint:242 calls,225 nodes,41.2 MiB and1517–2356ms. These are capped observations, not uncapped throughput or total process/GPU memory. Regional catch-up measured about130–172ms in final focused runs (up to735ms under earlier concurrent load).

Windows and single-thread Web exports succeed without export warnings/errors. Native Compatibility smoke exits successfully; Windows still reports an unavailable OS root certificate store, with no script/resource failure. License notices accompany both external distributions. Browser startup, rendering, actual movement, discoveries and Pause were tested. The initial browser test found the mapping defect subsequently fixed; a complete browser victory/pacing review remains outstanding. Complete victory is verified by automated native scene tests, not claimed as human/browser completion.

## Remaining review

1. F5: inspect green Forest, drier Drylands and wetter Wetlands; verify trail labels, compact HUD and camp notes at target resolutions.
2. Confirm all four movement keys at the default and underside camera views; cross trails, release held keys, orbit/zoom and open Pause/Options.
3. Survey Drylands, selectively cut/remove a stump; leave/return to inspect persistent log/stump/burned state and clear the log.
4. In Wetlands, stand beside the mint habitat north of camp, observe genuine regrowth, then walk to the northern golden refuge. Trampling should delay recovery.
5. Review drought/char/recovery, pond boundaries, fire/shelter and subjective SFX levels. Restart and confirm unique Knowledge/upgrades.
6. Complete a full browser victory and judge first-load responsiveness and the 5–10 minute pacing target.

Deferred: bridges, hydrodynamics, extra biomes/infinite streaming, finished ambience/music, disk active-run saves and broad browser/device performance coverage. No extra gameplay was added after the user's wrap-up request.

Agents: Sol High regional state/full-run testing/movement correction; Sol Medium climate visuals and audio discovery/integration; Sol Low export validation. Coordinator retained the inherited configuration. Shared integration, commits and final review remained with the coordinator.
