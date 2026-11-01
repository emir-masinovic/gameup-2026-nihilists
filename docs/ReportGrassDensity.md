# Grass density presets

Accepted Grass V2 history promoted by fast-forward f7f7d9b → a7f64ab. No ecology compaction transferred. Removed the unused rejected static-chunk benchmark diagnostic.

Fresh settings and Video defaults select Off. Existing files missing the preference migrate to Medium while retaining other preferences. Forest capacities: Low 3000, Medium 5298, High 8000. Other biomes scale historical budgets proportionally. Off hides grass and suspends its LOD controller while retaining allocated placement data. Changing non-Off capacity rebuilds only grass, preserving wind and shelter; repeated settings applications do not rebuild.

Godot 4.7.2 Compatibility / GeForce 940MX; seed 2026, orthographic, 1152×720, uncapped and VSync disabled. Single-run representative measurements; scheduling variation affects total frame times.

| Preset | Zoom | Submitted tufts | Draw calls | Render CPU ms | GPU ms | Median frame ms | Cover generation ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| Off | 20 | 0 | 275 | 1.68 | 3.12 | 3.89 | 500.6 |
| Off | 56 | 0 | 300 | 2.02 | 1.62 | 3.29 | 500.6 |
| Medium | 20 | 5298 | 276 | 1.50 | 4.49 | 5.76 | 407.3 |
| Medium | 56 | 5298 | 301 | 1.58 | 2.25 | 2.86 | 407.3 |
| High | 20 | 8000 | 276 | 1.96 | 5.06 | 6.02 | 535.3 |
| High | 56 | 8000 | 301 | 1.78 | 2.64 | 3.23 | 535.3 |

Non-Off reconfiguration: approximately 0.3–0.7 seconds. Off visibility changes: approximately 0.01 ms. Off still pays initial allocation/generation cost; High adds GPU cost.

Passed: all-biome preset switching, legacy migration, defaults, persistence, ecological-state invariance, no renderer accumulation; 43 grass/LOD, 97 layout, 69 farming, 43 facing and 34 session/feed/sky checks. Native 1280×720 and 1600×900, fullscreen round trip and restart passed. Video layouts visually inspected at both resolutions. Single-threaded Web export passed; browser runtime remains for manual review. Validation used the existing non-worktree project copy with separate NihilistsDisplayValidation user data. All three protected primary files retain their recorded hashes.
