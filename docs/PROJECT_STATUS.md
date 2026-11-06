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

## SSBU readiness

- Profile 01006A800016E000; known build is base plus update 13.0.5 (v2031616). Other versions are not confirmed. Optional DLC AOC NSPs are supported; profile notes 99 DLC licenses.
- Windows SDK, builder, shader translation, Metal compilation, extraction, and IPA packaging prerequisites are ready. No full compile started.
- Next: confirm the base/update/DLC inputs, then build from main with F:\\Temp as work directory and final IPA at its established destination.