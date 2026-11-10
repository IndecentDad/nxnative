# NXNative Project Status

## Current architecture

- Canonical repository: https://github.com/IndecentDad/nxnative. Customized main is the only permanent branch and GitHub default. Integrate reviewed upstream/main changes into main.
- Windows host: ssh nxwindows. User work checkout: D:\\NXNativeWindows. Clean main worktree: D:\\NXNativeBuilds\\main-upstream-sync.
- Keep originals in D:\\Downloads; use F:\\Temp for extraction, build data, shaders, and staging. Final IPA stays at its established destination.

## Upstream and cleanup — 2026-11-06

- Upstream 0c7e88b92b5fdf0dfa0e9496df5652f350f05e20 was merged normally; current origin/main is 6e190eba2a8056925eddaab3324e315bc3c5e1fc. The merge includes 41 commits, including SSBU copy-stride fix cac783a1 and 13.0.5 HTML extraction fix a5c7234e.
- The recovery branch/worktree had no unique commits or source fixes. Dirty files were generated shader/translator outputs and compile intermediates; it is retired without an archive.
- Windows checks: GUI 11 pass/1 optional skip; staging 17 pass; split-data 1 pass; py_compile passes. One shared NSP incremental test expects nx_extract instead of Windows nx_extract.exe; the production wrapper adapts this. pytest is unavailable.

## Toolchain and SSD

- SDK 26.5 remains at D:\\NXNativeWindows\\win\\sdk\\out\\iPhoneOS.sdk. The clean main worktree does not contain that ignored output, so the Windows user variable NXW_IOS_SDK now points to it.
- win/doctor.py passes all checks: Python packages, .NET 10.0.403, translator, LLVM 23.1.4/linker, iOS/macOS Metal, spirv-cross, zstd, glslang, and fonts.
- SSBU has 17.6 GB RomFS data and a known 17.5 GB IPA. Allow about 60 GB peak for extracted data, the build's 6 GB image/shader/slack reserve, possible staged input packages, and local IPA transfer; retain 70 GB free.
- F: is a 1 TB NTFS SSD with 141,403,774,976 bytes (131.7 GiB) free at last check. This is sufficient. No ROMs or final artifacts were moved.

## Upstream sync and build review — 2026-11-09

- Fetched refs: origin/main `8700b867`, upstream/main `04811a63`; verified 142 fork-only and 96 upstream-only commits. Customized `main` now contains the upstream merge and retains the Windows builder, profiles, shader pipeline, split-data packaging, and fork documentation.
- Windows compatibility updates: include upstream's `pad_switch2_apple.m` in the Windows source collector; make IPA reuse reads work without `os.pread`, avoid Darwin APFS cloning on Windows, and close the old IPA before replacing it. Shader chain header regenerated to `466e38874059`.
- Validation on the Windows PC: `win/doctor.py` passed; builder/staging/split-data suite 30 passed, 1 optional skip; iOS compile check built 267/267 files for Mario Kart World on SDK 26.5; repeated pack-and-replace smoke check passed with executable mode 755. The generic IPA reuse suite is macOS/APFS-specific and is not a Windows pass criterion.
- Before the 2026-11-10 rebuild, OoT's latest canonical IPA was the 2026-11-07 build from customized `main` `03776c36`, upstream baseline `24fe1e5a`; provenance and 42,848 shader libraries were under `F:\Temp\0400486024DEC000`. Upstream movie compute (`c66a36ab`), full-resolution/GPU work (`04419bc2`), depth correctness (`81906931`), pool retirement (`1d377206`), heap reuse (`7f502220`), and pipeline archive fixes (`eed7c429`, `4c3a03af`) were absent from that build and motivated the rebuild below.
- Mario Kart World has a 2026-11-03 v1.8.0 playable IPA build record from workspace `3ca7bc88` (upstream base `df7fa667`). The newer 2026-11-04 diagnostic package on source `57306e0b`, chain `ca3de5a06b0b`, translated 11,603/11,604 shaders; record `078997bf631992c5` failed on instruction `0x481` and its gameplay effect is unknown. Upstream sparse-memory and shader changes (`1110473c`, `75e5ddd8`, `e07cba1c`, `84dea698`) motivated the 2026-11-10 rebuild; slow-motion fix `7d8dcdf8` is not an FPS gain.
- OoT was rebuilt from customized `main` `37ca0937` (upstream baseline `04811a63`), game update v131072 (1.2.0), with shader chain `466e38874059`. The Windows build reused extracted game data and the split shader package, translated 42,848/42,848 shaders, and compiled/reused 42,848 iOS Metal libraries. Translator reported no lost shaders.
- OoT IPA: `/volume1/Media/Roms/iOS/Zelda Ocarina of Time/ZeldaOcarinaOfTime.ipa`, 44,251,449 bytes, SHA-256 `88d5dcc0c051d46df64012c129da78bfe9371d28a863dc1410668f4c93868306`. Split-data ZIP: `ZeldaOcarinaOfTime-data.zip`, 32,574,059,430 bytes, SHA-256 `5a3a04bd7bd7091212a37f84cac1715a3a4993ed9edfbfbe6afc5e3007dfd497`; ZIP integrity and transfer hashes passed. iPad gameplay validation is pending.
- Mario Kart World v1.8.0 was rebuilt from customized `main` `37ca0937` (upstream baseline `04811a63`), profile `0400C3F00006E000`, using the Windows builder, SDK 26.5, LLVM 23.1.4, SPIRV-Cross from Vulkan SDK 1.4.363.0, and Metal 32023.850 with `--allow-other-metal`. Current shader chain is `466e38874059`; the exact translator/toolchain and lock are retained under `F:\Temp\0400C3F00006E000\build\tools` for incremental reuse.
- Mario's fresh v0 extraction contains 206,333 files/21.9 GB. Shader split produced 11,603 records; 11,602 translated and generated Metal libraries, one failed with the same unimplemented Ampere instruction `0x481` signature (`...020c0481`) as the 2026-11-04 diagnostic build. The earlier unsupported record therefore remains unresolved. The Metal CAS reused 482 libraries; 15,116 variants compiled. No pipeline archive was generated.
- The profile was derived from the v0 package (display version 1.8.0); its code IDs do not match registered builds, so fixed-address patches were not applied and the build log warns it may run less well. IPA validation passed (ZIP CRC, bundle ID `org.nxnativewindows.0400c3f00006e000`, version 1.8.0); 268/268 iOS sources compiled and linked.
- Mario Kart World IPA: `/volume1/Media/Roms/iOS/Mario Kart World/MarioKartWorld-v1.8.0.ipa`, 38,279,683 bytes, SHA-256 `d854aede2ccc4ca79b4b712680c329239e9280caea4a87b7f8fdac3d43abe9e5`. Split-data ZIP: `MarioKartWorld-v1.8.0-data.zip`, 25,412,607,874 bytes, SHA-256 `c7aff72f74986104c7e4df895f7122ec7836f219f4ceac72ce5f3e040987653c`; archive CRC, local copy verification, and transfer hash passed. Superseded generated outputs were removed; per-title F: workspaces/caches remain for reuse. Both new IPAs await device testing; FPS/stability improvement is unverified.

## SSBU build: 2026-11-06

- Built Super Smash Bros. Ultimate base XCI plus update 13.0.5 (v2031616), profile 01006A800016E000, and all 99 supplied DLC packages. No other game versions were validated.
- Reused extraction, module rewrite, and shader split in `F:\\Temp\\NXNative\\SMB\\01006A800016E000\\build`. The full shader stage translated 35,012/35,012 with 0 failures. iOS Metal compiled 24,787 libraries and reused 10,232 from its content cache; no translation losses or unrecognized bindings. Eight c1 reads use the conservative full-buffer fallback.
- Used installed Metal 32023.850 with the authorized `--allow-other-metal`. The upstream `dm/gfx/tools/dmsh_chain.lock` was not changed. A workspace-only `build/tools/windows-toolchain.lock` records the actual rebuilt current-source translator, Windows SPIRV-Cross, and Metal fingerprints; retain the build workspace and set DMSH_TOOLCHAIN_LOCK to that file, with --allow-other-metal, to resume without rebuilding completed shaders.
- Fixed two integration blockers exposed by the build: the Windows packager now accepts upstream's packed NVN shader `.img`, and the missing iOS `aoc_locate` definition was restored so `main.m` compiles. The chain header was regenerated for the current source tree.
- IPA: `F:\\Temp\\NXNative\\SMB\\01006A800016E000\\outputs\\SuperSmashBrosUltimate.ipa` (117,246,877 bytes). Split data: `F:\\Temp\\NXNative\\SMB\\01006A800016E000\\outputs\\SuperSmashBrosUltimate-data` (19,507,038,987 payload bytes), containing RomFS image, shader-library image, and 99 DLC images. IPA ZIP CRC check passed; no game data is embedded in the IPA.
- Ready for device testing after signing/installing the IPA and copying the complete split-data folder into the app's Documents. Rendering/performance with Metal 32023.850 remains unverified on an iPad.

## Ocarina of Time build: 2026-11-06

- Built profile `0400486024DEC000` from the supplied NUP: base v0 plus update v131072 (v1.2.0); no DLC was present. Original NUP remains at `F:\Temp\The Legend of Zelda Ocarina of Time.nup`.
- Used Windows builder on customized main `e17c52f368deebe852a24fb45f317a3918c9a08b`, Metal 32023.850 with authorized `--allow-other-metal`; upstream fetched at `b2d46b86d03f4b03afe11ea61c67cdf00d7a5345`. Upstream shader lock unchanged; build-local fingerprints are in `F:\Temp\0400486024DEC000\build\tools\windows-toolchain.lock`.
- Workspace `F:\Temp\0400486024DEC000`: 42,848/42,848 shaders translated. iOS Metal reused 1,903 libraries and compiled 42,628; zero compile failures, translation losses, undecoded slots, or unknown binding kinds. Variant counts: 9,839 generated, 767 cache hits, 9,072 rebuilt/compiled. 1,683 shadow-input and 22,296 alpha/logic libraries generated without failures. Only benign unused generated MSL function/variable warnings; no unsupported shader instructions reported.
- IPA: 43,988,786 bytes, SHA-256 `DF8D145365450CF6F432202654B5EB0396AF4D6534FE9B2489D3BCA675782659`. Split data payload 33,723,062,460 bytes (RomFS 26,247,576,430; shader image 7,475,485,326; metadata/readme). ZIP: 32,265,085,398 bytes, integrity check passed, SHA-256 `BF828F6A3F6A82C2A892F967DCA1B59D6CD39CAD37B5EEE26C44732CEDA1EF2A`. Windows outputs remain under `F:\Temp\0400486024DEC000\outputs`.
- Device test pending; ready for signing/install and split-data placement. NUP had no icon (blank app icon); iPad M5 rendering/performance unverified. Pipeline generated no archive, so first launch may compile Metal 4 bases on-device.


## Ocarina of Time rebuild: 2026-11-07

- Integrated upstream `seedds/nxnative/main` through `24fe1e5a8a6fb21eebe6b0c0ff6078b387d7da57` into customized main. Integration commit: `d0b99c98013257cdd3a85e7ce388f70d72c8685a`; Windows build source commit (chain header): Windows build source revision: `03776c36afad16bba5867b315816a4e38e826301` (chain `436d1b968069`).
- Relevant upstream work includes OoT profile/pipeline prewarm seeds, HMMA accumulator and LDSM fixes, texture storage/residency and cached-view page-fault fixes, mesh/depth corrections, and encoder alias barriers. No AV1 decoder change landed in this upstream range; existing dav1d fallback remains.
- Reused extracted v1.2.0 RomFS, rewritten modules, split shader set, and verified shader translation/Metal CAS caches. The nine Windows checkout files whose text matched canonical source were normalized to canonical LF bytes; source and toolchain fingerprints then matched. No full shader regeneration was necessary. Reused 42,848 shader translations; iOS Metal stage restored 42,848/42,848 libraries from cache, 0 failures.
- Toolchain: .NET 10.0.403, SDK 26.5, LLVM 23.1.4, Metal 32023.850 using authorized `--allow-other-metal`; workspace lock retained at `F:\Temp\0400486024DEC000\build\tools\windows-toolchain.lock`.
- IPA: `F:\Temp\0400486024DEC000\outputs\ZeldaOcarinaOfTime-canonical.ipa` (44,151,271 bytes), SHA-256 `069d6699a65a55b5773f08cc52c4820a5f908a221ca4ead7b65812fe6e59a969`; ZIP CRC and bundle identity checks passed (`org.nxnativewindows.0400486024dec000`).
- Split data: `F:\Temp\0400486024DEC000\outputs\ZeldaOcarinaOfTime-canonical-data` (33,731,096,012 payload bytes). RomFS is unchanged: 26,247,576,430 bytes, SHA-256 `872de47b913bb97890880e9f17dccedc4144953a258e9a6aecf04c379427a669`. Replace only `msl\b-ff71f68d44fa.img` with `msl\b-436d1b968069.img` (7,483,519,582 bytes, SHA-256 `c7feae18551fb893b988b26ec0fb8a3ce1eafcd8d6679cce1f306467ced37d67`); retain `romfs.img`.
- iPad M5 test remains pending. Check intro/movie artifacts and sustained frame pacing, then gameplay and streamed terrain for 15-45 minutes. No pipeline archive was generated; first launch may prewarm/build Metal 4 pipelines on device.
