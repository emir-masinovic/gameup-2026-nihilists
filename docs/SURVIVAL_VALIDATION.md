# Survival checkpoint validation

Baseline54efcea and its eight unpushed commits remain intact. This batch is isolated on feature/survival-interactions-camera; no push, merge or teammate branch import. The pre-existing project.godot edit is preserved byte-for-byte and excluded from commits (SHA256583BD67AA34B33B82E65D6E431BBFC36D1EBD2DD5E0C7E09C13EF5C12D4C6E5A).

## Implemented

Board Center, smooth Follow Player and independent Free Camera work in both projections. C cycles modes temporarily; Gameplay stores the default. Shift plus the bound orbit gesture pans Free Camera. F Eat and C are rebindable; conflicting older C/F assignments are preserved. Region transitions preserve view parameters and remap targets.

Common stable descriptors, deterministic target selection, selected-target rings, saved binding prompts and paused/cancellable progress integrate tree/stump/log/camp actions with berries and pond drinking. Seeded bushes yield two berries; depleted bushes remain and accumulate180 favorable seconds for replenishment. Food/water state persists across regions. Drinking requires adjacent wet water and changes no pond volume. Forest food and a pond-shore approach are guaranteed reachable. First discoveries remain unique.

One body-temperature state replaces visible Heat Exposure, alongside health, compact food/water reserves, contextual wetness/canopy and a small player wet indicator. Rain/canopy, heat/cold/wind, camp warmth/drying and existing upgrades affect real model state. Wetlands has more rainy periods; Drylands has more heat. Movement/player scenes and astronaut/planting implementations were untouched. See [Onur integration](ONUR_INTEGRATION.md) for actual extension APIs.

## Tests and results

Passed existing checks: foundation52, climate884, ecosystem3778, progression42, objectives51, gameplay16, grid121, interactions12, movement8384, camera grid39, projection67, mouse bindings9, settings layout93, feedback48, HUD14, presentation67, nature32, audio30, regional state3863 and regional victory71. Fresh-process settings write/reload passed including default camera mode, cycle and Eat remaps. Old heat-only timing assertions were updated for the approved gradual model; initial failures were resolved, not suppressed.

New checks: survival model33; camera modes29; full survival scene278 (including80 seeds of reachable food/water); full camera/scene156 headless and162 actual desktop. Foraging/interaction tests pass for seeded placement, depletion, climate regrowth, visuals, range, priority, callbacks, cancellation and pause. Actual scene tests cover all three modes and both projections, movement, modal input, wetness, camp recovery, binding prompts and Follow Player region arrival. A fixed .19-second fixture wait was replaced by bounded observable tween completion after native resize timing exposed it.

Godot4.7.2 import and Compatibility rendering succeeded. Desktop HUD/Gameplay Options captures at800x600,1152x720,1600x900 fit. Actual-browser testing verified startup, movement, timed harvest, berry inventory/Eat, pond selection/drinking, rain wetness, three-mode cycling, Follow targeting, independent Free Camera movement and Pause rejection. Browser warnings/errors were empty. This was a smoke test, not a complete browser victory or human balance playtest. The temporary browser tab and localhost server were closed.

Windows and single-thread Web exports pass without export warnings/errors, with font/Kenney/audio license notices. Windows Compatibility smoke exits0; only the existing unavailable OS root certificate-store diagnostic remains. Windows distribution109699844 bytes; Web40280746 bytes. Outputs stay outside Git under the session visualization survival_release folder. Builds use the preserved working project configuration, including its pre-existing uncommitted edit.

Representative scene:250 draw calls,261 nodes,42.7MiB debug static memory and120FPS at the active120 cap. Prior checkpoint243 calls/245 nodes/42.8MiB.360 climate ticks took1757ms versus prior1569ms. Capped FPS is not uncapped throughput; static memory is not total GPU/process memory.

## Balance and limitations

At24C, four minutes leave health100/body37, food76/water66.4. Food drains .10/s; water .14/s plus .005/s per ambient degree above28. Penalties start below10 reserves. At45C without shelter, thermal damage begins146s and death215s; shade and Heat Resistance delay danger. Berries restore24 food/3 water; drinking45 water. Camp restores normal temperature, dries at2.5 wetness/s and heals4 health/s, without refilling reserves. These are game parameters, not physiological modeling. The5–10 minute pacing target still needs a human run.

Deferred: astronaut model, seed planting, new FSM, full inventory/crafting, fuel management, disk active-run saves, new ambience, broad browser/device benchmarks and a complete browser victory. No known failing automated checks remain. Truly edge-on camera views retain the existing nearest-visible movement fallback.

## Manual F5 review

1. Harvest the nearby red berries, Eat, find a highlighted pond and Drink; check prompts follow saved bindings.
2. Compare rain outdoors/under living trees and dry/warm near camp; check body/food/water feedback and gradual danger.
3. Cycle Board/Follow/Free in both projections, Shift-drag pan, Pause/Options, and cross a regional trail.
4. Return to depleted bushes/logs/stumps, observe actual favorable regrowth, and finish the regional refuge objective.
5. Review HUD at the three sizes, persistence after restart, subjective survival pacing and a complete target-browser run.

Agents actually used: Sol High survival model; Sol Medium camera/settings and resource/interaction systems; Sol Low exports. The coordinator retained its inherited configuration and owned shared integration, HUD, documentation and commits. No claim is made that the coordinator model was switched.
