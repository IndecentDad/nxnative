# NX Native Project Handoff

Repository: `IndecentDad/nxnative`  
Current branch: `game/mario-rabbids-kingdom-battle` (unsigned IPA validated; device testing next)

## Completed

- Intel x86_64 macOS support is merged and translator-tested.
- Game-specific app-icon selection is merged and validated in the complete Rabbids IPA.
- The Python f-string syntax error in `scripts/build_ipa_from_nsp.py` is fixed.

## Development checkouts

- Permanent development checkout: `/volume1/docker/nxnative`.
- Preserve the existing Tahoe checkout at `/Users/kylepyne/nxnative`; do not overwrite, clean, or copy unrelated local changes.
- Do not push to `seedds/nxnative`.

## Mario + Rabbids checkpoint (2026-10-22)

- NAS worktree: `/volume1/docker/nxnative-mario-rabbids`; Tahoe worktree: `/Users/kylepyne/nxnative-mario-rabbids`. Both use the dedicated game branch, based on `7b99983`. No branches were merged or main commits added during this port. Main retains one pre-existing commit ahead of `origin/main` (`6783602`); its GameSave change still awaits device validation. An unrelated edit to main's `docs/PROJECT_STATUS.md` appeared during the build and was preserved. Do not push or merge main automatically.
- Inputs preserved. Tahoe copy/intermediates: `/Users/kylepyne/nxnative-games/Mario Rabbids - Kingdom Battle`. Base title `010067300059A000`; patch `010067300059A800`, CNMT version `589824`; NACP display `1.9.589692` (filename says v1.9.0). All four DLCs have matching application IDs: B001 Battle Pixel v0, B002 Steampunk v0, B003 Ultra Challenge v65536, B004 Donkey Kong Adventure v131072.
- Base+update extraction passed integrity checks: 4,004 RomFS files, 2,888.3 MiB. All four DLCs extracted (11 files each for indices 1–3; 17 for Donkey Kong Adventure). All three NSOs translated successfully; final Xcode unsigned iOS Release compilation and ZIP64 packaging passed with the supplied JPG icon.
- Recovered proven tools: Python `/Users/kylepyne/nxnative-pr-5-x86-archive-20261022/.venv/bin/python3` (lz4, capstone, fontTools); .NET `/usr/local/share/dotnet/dotnet` 10.0.402; keys `/Users/kylepyne/nxnative-keys/prod.keys`; tools `/Users/kylepyne/nxnative-tools/bin` (xcodegen, spirv-cross, zstd). Existing Intel translator uses `dotnet exec dmsh_xlate.dll`. System Python and existing environments were preserved. Only zstandard was added under the Rabbids build's `python/` directory; use that as PYTHONPATH.
- Dedicated profile exists in `dm/games/010067300059A000/`. Actual SDK 4.4.0; modules main/subsdk0(GLSLC)/sdk. main build `3b39e0c06b8841f1baf0ea4d54286bfe`. Static call at main+0x37c requests a 100 MiB heap; profile's 128 MiB heap region fits it. Profile remains experimental.
- Implemented CNMT `nx_extract --metadata`, DLC shader scan roots/cache inputs, explicit `--no-glslc-capture` for Intel offline packaging, and indexed BERG shader extraction. Seven synthetic framing/index/shader tests pass on Tahoe. All 11,368 shaders compiled for Mac/iOS (10,382 vertex, 732 pixel, 254 compute), with 10,382 separable program pairs, 148 generated fetch variants, no undecoded bindings, and no unfillable driver reads. Final c1 guard lists 34 shaders; chain `5c8a686da164`.
- Fixed recognition of `subsdk0`'s jump table at 0x7340b8 using a longer, stable-copy search: w18 copies w17 at +0x733f94; later unsigned bounds checks compare w17 <=4. The real-function test verifies all five targets and rejects a modified source register. Capstone incorrectly reports CMP as writing its input; the new stability check excludes comparison instructions. Full NSO rewrite passed for main/subsdk0/sdk.
- Indexed extraction resolved: WEST v22 has 204-byte DDS entries and omits the later format's per-chunk file ID; 145,164 main resources parse successfully. DLC archive IDs are sparse global IDs, not bounded by their local archive count. Named `shadercache/nvn/` resources provide precise boundaries for raw, zstd, and nested zlib data. Format reference: https://github.com/GoldFarmer/rouge_sdf/blob/master/main.cpp .
- BERG shaders are confirmed offline inside compressed resources: control size 0x838, followed by valid NVN code (both vertex and pixel observed). Some full records have zstd wrappers plus inner zlib. Four DLC roots must be included in the scan. Runtime GLSL variants remain unverified; Intel cannot execute the ARM64 host for capture, so report this explicitly on the first offline IPA.
- Tahoe tool fingerprints are recorded in this branch's `dmsh_chain.lock` (same translator, installed Metal 32023.883/SPIRV-Cross). Rabbids chain header, Mac+iOS libraries, final c1 guard, and Release host are rebuilt consistently. No Dread profile or build assets changed.
- Persistent inspection/stage scripts and survey are saved at `/volume1/docker/nxnative-mario-rabbids-handoff/`; Tahoe copies are under the Rabbids build's `session-tools/`. `rabbids-stage.py` runs rewrite/split/shaders/ipa using exact env/paths, reusing existing extraction. `rabbids-prepare.py` is historical: do not regenerate over the refined profile. Source and final handoff belong to the dedicated review branch; Git history is authoritative.
- Final artifact delivered: `/volume1/Media/Roms/iOS/Mario Rabbids - Kingdom Battle/MarioRabbidsKingdomBattle-v1.9.589692-NXNative-unsigned.ipa`, 4,905,957,755 bytes (4.57 GiB). NAS SHA256 matches Tahoe: `97e718f03856fe2d3cbef8a86e8c548caa1e97f43e8209be50490553c92a594f`. Validation passed: full ZIP CRCs, ZIP64 records, unsigned ARM64 Mach-O, icon, module tables, final guard data, all 4,004 RomFS files and 50 DLC files, and 11,368 shader libraries. Framework references are system frameworks/libraries. Detailed report: `<Tahoe game>/010067300059A000_build/logs/validation.json` (NAS copy in the handoff directory).
- Build-only Release check used `DM_BUILD_ONLY=1`; final measured guard data replaced the temporary conservative table before the normal final Release/IPA stage. `.sdfdata` is stored directly to avoid redundant compression. Completed libraries remain cached.
- Next: install/sign with PlumeImpactor and device-test rendering, memory growth, saves, input/audio, and all DLC access; return `Documents/log.txt`. No external entitlement file is required. Runtime-only GLSLC variants and actual gameplay remain unverified. See [mario-rabbids.md](mario-rabbids.md) for general fixes that can be reviewed separately; never merge experimental game work into main automatically.

## Metroid Dread

Metroid Dread reaches gameplay but experiences severe memory growth. The saved log ends at frame 16,800 (439 s) at 8,101 MiB resident, 7,246 MiB Metal allocated and 90 MiB headroom; it does not contain a terminating exception. The deferred-release queue was zero, pools stayed at 9, shared textures plateaued at 40, and serial/residency counts rose. A memory-limit termination is plausible but unconfirmed without the device's `.ips` report. This log's timeline differs from the separately reported ~97-second crash.

## Next priority

Fetched `seedds/nxnative` main to local `upstream/main` without merging (at `ea12221` on 2026-10-21). The fork already contains `ca90b26`, `12a20d0`, `aadb939`, `6c0a14d`, and the Dread autorelease-pool leak fix in `8b21049`. Later upstream `37c24c6` evicts shared textures on storage takeover; its relevance to Dread is unproven. Preserve Tahoe's `pr-5-x86` checkout at `b5a2a8c` with its unrelated local changes.

On 2026-10-21, the isolated Tahoe checkout `/Users/kylepyne/nxnative-dread-diag-f613cd3` built Metroid Dread 2.1.0 from fork commit `f613cd3`. Only `dmsh_chain.lock` and Dread's generated `dmsh_chain.h` differ there, to match Tahoe's installed translator/Metal tools (chain `78c708956b92`); no graphics resource lifetime code changed. Full ZIP CRC validation passed; the diagnostic IPA contains `DM_NVN_ALLOCPROF=1`, 1,010 compatible shader libraries, Dread RomFS, and the custom icon. As checked on 2026-10-22, the NAS now holds this diagnostic-size build as `/volume1/Media/Roms/iOS/Metroid Dread/Metroid Dread.ipa` (4,789,625,110 bytes); the separate diagnostic filename is absent. The original baseline survives on Tahoe at `/Users/kylepyne/nxnative-games/MetroidDread/MetroidDread-Official.ipa` (4,786,760,273 bytes). No IPA, shaders, assets, or existing Tahoe checkout were changed during iCloud work.

## iCloud save feature (2026-10-22)

Commit `752255f` adds shared iOS snapshot/revision sync, manual Files export/import, an on-screen Saves menu, deferred imports, and optional shared iCloud Documents build configuration. See [icloud-saves.md](icloud-saves.md). Tahoe compiled the shared iOS sources; APFS runtime tests, two generated Xcode project configurations, and an ad hoc entitlement check passed. No new IPA was built. Obsolete `app-icon-support` and `intel-macos-support` remote branches were deleted after verifying both are ancestors of fork main and no worktree depends on them; the local app-icon branch was also deleted. Newer upstream was reviewed but not merged. The old uncommitted status document was preserved in a pre-merge stash, and its findings were incorporated here.

The feature branch replaces custom `DmSaveSync` snapshot/export/import logic with the iOS 26 GameSave `GSSyncedDirectory` adapter. Local `Documents/save` remains authoritative and visible through the app's display-name folder; the Saves button, manual Files workflows, and `NXNative Saves` metadata are removed. Project-generation tests pass and the adapter passes an arm64 Tahoe/Xcode 26.5 SDK syntax check. No IPA or save data was changed.

Remaining: device-test local Files visibility, first upload, offline/unavailable iCloud, newer-save restore, and conflict preservation. Confirm the signed profile retains `CloudDocuments`, the exact shared container, increased-memory-limit, and extended-virtual-addressing. Do not merge until those tests pass; continue Dread memory diagnostics separately.
