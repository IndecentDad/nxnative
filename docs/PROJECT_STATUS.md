# NXNative Project Status

- Fork `main` remains untouched. `game/echoes-of-wisdom` preserves the 1.0.0 recovery reference and registered 1.1.0 profile.
- EoW 1.1.0 (base XCI + update v196608) extracted locally (10,971 files, 7.5 GB); main, subsdk0, subsdk1 and sdk rewrote successfully; shader split produced 9,858 inputs.
- Translator failure was an ARM64 ReadyToRun `dmsh_xlate.dll` loaded under Tahoe's x86_64 .NET 10 runtime. The universal launcher, runtime and network-hosted input were not the cause. The AnyCPU publish fix is commit `af5820530a4a77b430058cd651833320dfb200ec`; isolated `--source-sha` and locked translator checks pass.
- The standard Mac+iOS shader build completed: 9,858/9,858 shaders succeeded, 0 failed; 3,110 variants compiled and 188 reused; 1,003 shadow-input and 5,268 pulling libraries generated with 0 failures. The top-level IPA run then validated all 9,858 shader inputs from cache.
- Local compiler fingerprints were SPIRV-Cross `42ee93372e51d0ee` and Metal `32023.883`; the translator lock passed, and pinned compiler lock values were not changed. Warning: `c1_full.tsv` reports 2 shaders not proven bounded.
- Unsigned IPA completed and passed ZIP integrity validation: `/Users/kylepyne/nxnative-games/Echoes of Wisdom/v1.1.0/build-input/Echoes-of-Wisdom-v1.1.0.ipa`, 7.8 GB, SHA-256 `f5ca75c7245a7fac25278904f764e25f4410f497bb2d96051d2f72cf3bfe8a00`. Bundle ID `org.nxnative.01008cf01baac000`, title ID `01008CF01BAAC000`, game/app version `1.1.0`; packaged launcher metadata and 14,159 metallib files verified.
- Build is unsigned and not device-tested. Signing/sideloading must request the increased-memory entitlement. Installation/launch has not been performed.
- Local branch is ahead of `origin/game/echoes-of-wisdom`; the fix is not pushed because GitHub write authentication is unavailable. No main-branch changes were made.
