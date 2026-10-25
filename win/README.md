# nxnative on Windows

This folder builds the same IPA as `scripts/build_ipa_from_nsp.py` on a Windows 10/11 PC, with no Mac or Xcode.
The pipeline itself is unchanged: the upstream script runs as-is. Only the steps that call macOS tools are replaced, at the subprocess boundary.

Status: **experimental, not yet verified end to end.** The Python parts have unit tests (`win/tests/test_win.py`). Nobody has yet compiled, installed and played an IPA built this way. See [Open risks](#open-risks).

## How each macOS step is replaced

| Upstream step (Mac) | Windows replacement | Where |
|---|---|---|
| `xcrun -sdk iphoneos/macosx metal`, `metallib` | Apple's **Metal Developer Tools for Windows** (`metal.exe`, `metallib.exe`). `-mios-version-min=X` becomes `-target air64-apple-iosX`. | `win/xcrun.py` |
| `xcodegen` + `xcodebuild` (C, ObjC, asm, Swift) | **LLVM clang** (`-target arm64-apple-ios26.0 -isysroot iPhoneOS.sdk`), one compile per file, linked by **ld64.lld** | `win/build_app.py` |
| `Launcher.swift` (SwiftUI) | `win/ios/Launcher.m`: a UIKit port with the same `dm_show_launcher` contract, so no Swift toolchain is needed | `win/ios/Launcher.m` |
| Darwin compiler-rt (`@available`) | `win/ios/compat_rt.c` (`__isPlatformVersionAtLeast` through `_availability_version_check`), used only when LLVM has no `libclang_rt.ios.a` | `win/ios/compat_rt.c` |
| `actool` asset catalog | loose PNG icons named in `CFBundleIcons`, scaled by Pillow | `win/build_app.py` |
| `sips`, `plutil` | Pillow, `plistlib` | `win/build_app.py` |
| `make -n -B dmhost` (source list) | the `dm/host/Makefile` source rules, reproduced. The build stops if the Makefile's `SRC=` / `GFX=` lines change. | `build_app.host_sources()` |
| `dmsh_xlate` apphost (Mach-O) | `dotnet dmsh_xlate.dll`: the same locked DLLs, so the chain fingerprints still match `dmsh_chain.lock` | `win/pyshim/sitecustomize.py` |
| `which`, `python3`, `ctypes.CDLL(None)` (clonefile) | `shutil.which`, the current Python, an empty library (falls back to plain copies) | `win/pyshim/sitecustomize.py` |
| Unix modes in the IPA (the executable's x bit) | `pack_ipa.py --exec`: on Windows, folders are packed as 755, the executable as 755, other files as 644 | `dm/ios/tools/pack_ipa.py` |
| iPhoneOS SDK from Xcode | `win/sdk/extract_xip.py` streams `Xcode_26.xip` (xar, then pbzx, then cpio) and writes only `iPhoneOS.sdk` | `win/sdk/extract_xip.py` |

These steps already run on Windows as they are: `nx_extract` (.NET, LibHac), the NSO rewriter (`patch_nso.py`), shader translation (`dmsh_xlate`), spirv-cross, reflection and tables (`dmsh_build.py`, `c1_guard.py`, `cb_extent.py`), and `pack_ipa.py`.

### What still needs a Mac

Some games make shaders only at run time. To get them, the pipeline boots the game's own arm64 code in the Mac host. No Windows PC can do this, so for these games the Windows build stops with a message:

- GLSLC capture (Fire Emblem: Three Houses)
- Vulkan or GL capture (Super Mario Galaxy, Balatro)
- Unreal and Oodle decoding (Pokémon Legends: Z-A, PlatinumGames PKZ games, DRAGON QUEST XI S, …)

The detection rules are in `dm/games/profile_guess.py`. The other games do not need this step, for example Mario Wonder, Odyssey, Mario Kart 8 Deluxe and Zelda BotW/TotK.

## Prerequisites

Run `python win/doctor.py`. It lists what is missing and where to get it:

1. **Python 3.10+**, then: `python -m pip install lz4 capstone fonttools pillow "backports.zstd; python_version < '3.14'"`
2. **.NET SDK 10** (x64)
3. **LLVM for Windows** 20 or later (`LLVM-*-win64.exe`; it includes `clang.exe` and `ld64.lld.exe`)
4. **Metal Developer Tools for Windows**, from developer.apple.com/download (free Apple ID)
5. **iPhoneOS 26 SDK**: download `Xcode_26.x.xip` from developer.apple.com/download (free Apple ID), then run `python win/sdk/extract_xip.py Xcode_26.x.xip`. Copying `iPhoneOS.sdk` from a Mac also works.
6. **spirv-cross** and **zstd**, Windows builds (the Vulkan SDK has spirv-cross and glslangValidator; zstd has releases on GitHub)
7. Optional: `STD_FONT`, a TTF with broad Unicode coverage for the shared-font stand-in. The default is Windows' Arial.

If a tool is not found automatically, set its path in `win/toolchain.json` (copy `win/toolchain.example.json`) or with `NXW_<KEY>` environment variables.

Licences: Apple's Xcode and SDK agreement covers how its SDK and tools may be used. Read it before you use them on non-Apple hardware.

## Build

```
python win/build_ipa_windows.py D:\Games\MarioWonder -k D:\keys\prod.keys
```

The options are the upstream script's (`-h`). Only `--platform ios` exists here. The IPA is unsigned, as upstream: sign it with your sideloading tool (Sideloadly on Windows, AltStore, …), with the Increased Memory Limit capability where the tool offers it.

## Open risks

These risks are untested until a real build runs. Check each one in this order:

1. **Windows Metal compiler output**: the shader libraries must load on iOS 26 (`MTLDevice newLibraryWithURL`). The Windows tools' version must accept `-target air64-apple-ios18.0` and the MSL that spirv-cross emits.
2. **clang and the iOS 26 SDK headers**: open-source clang must parse Apple's SDK, which uses Apple-clang-only attributes in places. `-mcpu=apple-a18` needs LLVM 20 or later.
3. **ld64.lld**: it must accept `-segprot` for the rewritten modules' W segments (`gen_embed.py`), the SDK's `.tbd` stubs (TAPI v5), and the very large `__TEXT` sections.
4. **Icons without an asset catalog** on iOS 26.
5. **The launcher port** (`Launcher.m`) behaving like `Launcher.swift`.

The `rea` MCP (github.com/morluto/rea) is optional. It helps compare a Windows-built Mach-O with a Mac-built one (load commands, sections, symbols) when a step above fails.
