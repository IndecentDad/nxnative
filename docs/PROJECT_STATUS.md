# NXNative Project Status

## Canonical layout

- Repository: https://github.com/IndecentDad/nxnative; customized main is the only permanent development branch and GitHub default.
- upstream/main is an external source. Review and merge applicable changes into main, validate on Windows, then push origin/main.
- Windows host: ssh nxwindows. User work checkout: D:\\NXNativeWindows. Clean main worktree: D:\\NXNativeBuilds\\main-upstream-sync. Preserve active feature work.
- Original archives stay in D:\\Downloads. Use SSD F:\\Temp for temporary extraction, build data, shader caches, and staging. Keep final IPA at the selected destination.

## November 6 upstream integration

- Integrated upstream 0c7e88b92b5fdf0dfa0e9496df5652f350f05e20 into customized main with a normal merge; pushed origin/main as 353004bad01f4b03f690826d9451b306516b40eb.
- Included 41 upstream commits since merge base 865cc35fad7034d17c2190f8ce349f61f5bcaba1, including SSBU copy-stride fix cac783a1 and 13.0.5 HTML extraction fix a5c7234e.
- Resolved game index, NVN, shader split, and patch-note conflicts. Kept Windows UTF-8 behavior and custom features.
- GUI staging now defaults to F:\\Temp\\NXNative\\SMB when present and uses per-title work directories; existing fallback/output routing remains.
- Checks: win tests 11 pass/1 optional skip; SMB staging 17 pass; split-data 1 pass; py_compile passes. One shared NSP incremental test fails on Windows due an exe filename expectation, while the production Windows wrapper adapts it. pytest is unavailable.
- doctor detects Python/.NET, translator, LLVM, Metal and support tools. iPhoneOS SDK 26+ is missing. No game compilation was run.

## SSBU readiness

- Profile title ID 01006A800016E000; known supported build is update 13.0.5 (v2031616) with base game. Other versions are not confirmed.
- Base/update NSP inputs are handled by extraction; optional DLC AOC NSPs are supported. The profile notes 99 DLC licenses.
- Offline extraction, shader translation, Metal compile, Windows builder and IPA packaging paths are present. Upstream fixes cover Adventure opening copy stride and 13.0.5 HTML extraction.
- Before building, configure iPhoneOS SDK 26+, confirm F:\\Temp capacity and device storage for the ~17.5 GB IPA, and verify exact base/update/DLC inputs. No full compile started.
