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
