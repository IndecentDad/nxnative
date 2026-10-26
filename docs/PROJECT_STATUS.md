# NXNative Project Status

- Fork `main` remains untouched. `game/echoes-of-wisdom` is updated through upstream `d50ecc1`; merge commit `a497706` preserves `9c55499` as first parent. Upstream commit `3dd5d25` and all subsequent fixes are included. Recovery tag: `recovery/eow-v0-9c55499`.
- Echoes of Wisdom 1.1.0 profile `v196608` is active. Fresh local build workspace: `/Users/kylepyne/nxnative-games/Echoes of Wisdom/v1.1.0/build-input/`; original XCI and update NSP remain symlinked from the Synology volume.
- Extraction completed: 10,971 files, 7.5 GB. `main`, `subsdk0`, `subsdk1` and `sdk` rewrote successfully. Shader split found all 9,858 profile shaders.
- Build stopped before translation/Metal compilation: `own_compilers.py` rejected the locked translator because `xlate_source` expected `af0a596483e1ec36` but actual was empty; embedded-source check also failed. No IPA was produced.
- v1.1.0 build logs and intermediates are preserved locally. Abandoned v0 extraction/shader/package outputs were removed; its logs and startup samples are archived under `surveys/logs/v0-abandoned/`. Original ROMs, keys and surveys are preserved.
- Next: address Intel translator compatibility separately, then resume the standard 1.1.0 build from the fresh local workspace. Do not reuse v0 build assets.
