# Onur legacy reference — review before synchronization

This isolated merge rehearsal combines development `d347d2a` and accepted main `4f22e95` without rewriting either history. Active project files match main. All five original Onur commits remain reachable through the development parent.

The 16 Onur-only files are retained byte-for-byte as `.reference.txt` files so Godot neither registers a duplicate crop system nor presents incompatible old API tests as current regressions. Original paths are preserved beneath this directory and full originals remain at `d347d2a`.

Already adapted on main: astronaut/tools/poses, climate-aware planting, preparation, refill/watering and capped collectible seeds. Intentionally not activated here: E/Space action split, stand-on-stump/crop traversal, watering-required seed germination, uncapped/refunded seeds, crop indicators and the old water-depth/climate schema. These require explicit joint review, not silent restoration. No prototype behavior is claimed to pass current tests.

Proposed workflow: PR this reviewed reconciliation into development, use a merge commit to retain both parents (do not squash), then create future feature branches from updated development. Promote accepted changes to main in a separate PR after integration testing. Nothing in this rehearsal authorizes a remote push or merge.
