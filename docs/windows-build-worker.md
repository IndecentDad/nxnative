# Windows build worker

## Repository and checkout

The canonical repository is https://github.com/IndecentDad/nxnative. Customized `main` is the complete Windows-compatible fork; it includes the Windows builder and GUI, shader translation, Metal compilation adapters, game profiles, SMB staging, split-data packaging, and existing game-specific work. There is no permanent `windows/main` branch.

The physical Windows 11 PC is reached from Synology with `ssh nxwindows`. The active builder checkout is `D:\NXNativeWindows`; the clean `main` worktree is `D:\NXNativeBuilds\main-upstream-sync`. Inspect `git status --short --branch`, remotes, and `git worktree list` before changing either checkout. Preserve dirty feature work, keys, game files, generated data, and caches.

## Workspace paths

- Keep original NSP/XCI/NSZ/XCZ files and downloads in `D:\Downloads`.
- Use the SSD `F:\Temp` for temporary extraction, shader caches, intermediate build data, and staging.
- The GUI uses a per-title work directory under `F:\Temp\NXNative\SMB\<title ID>\build` when the drive is available. Its SMB inputs, local output staging, and split-data staging use the same SSD workspace.
- Direct CLI builds retain the upstream source-folder default. Specify `--work-dir F:\Temp\<title ID>` for a new build and use `-o <existing final IPA path>` to keep the IPA at its established destination. The original inputs are not moved.

## Toolchain and build

Run `python win/doctor.py` before building. It checks Python packages, .NET 10, LLVM/clang and `ld64.lld`, the iPhoneOS SDK, Metal compilers, spirv-cross, zstd, glslang, and fonts. The locator scans this worktree `win/sdk/out`. For a shared SDK stored in another checkout, set the Windows user variable `NXW_IOS_SDK`; this host reuses `D:\\NXNativeWindows\\win\\sdk\\out\\iPhoneOS.sdk`. Do not copy or install tools when the existing SDK is available.

The Windows entry point is:

```powershell
python win/build_ipa_windows.py <NSP-folder> -k <prod.keys> --work-dir F:\Temp\<title-id> -o <final-IPA-path>
```

The GUI is started with `Build-IPA-GUI.bat` from the repository root or `pythonw win/gui.pyw`. It selects the per-title SSD work folder automatically, preserves the selected/default final IPA destination, and verifies SMB transfers. Use `--split-data` for an app plus a sibling data folder; inspect both outputs before transfer.

## Validation

The Windows builder's pure-Python tests run with `python win/tests/test_win.py`. SMB staging and split-data tests are in `win/tests`. Shader and archive tests that use standard `unittest` can run with `python -m unittest <module>`; the full macOS C/Metal runtime tests require the Mac toolchain. A Windows IPA compile does not establish gameplay compatibility.
