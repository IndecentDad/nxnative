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
