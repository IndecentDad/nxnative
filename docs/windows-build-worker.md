# Windows build worker

## Repository and worktrees

The canonical repository is https://github.com/IndecentDad/nxnative. Customized main is the permanent development branch. Fetch and review upstream/main before integrating upstream changes.

The Windows host is reached with ssh nxwindows. The dirty primary checkout remains at D:\NXNativeWindows; it is the common Git repository for linked worktrees and contains user-owned changes. Keep it in place. The Celeste source worktree is now at F:\NXNative\1_Development\Worktrees\celeste-upstream-sync, linked to that repository. Other existing worktrees and game caches remain under D:\NXNativeBuilds; inspect each before any relocation. Do not copy or move the whole directory.

## Permanent development locations

- Development root: F:\NXNative\1_Development
- iOS SDK 27.2: F:\NXNative\1_Development\SDKs\Xcode_27.2\iPhoneOS.sdk (SDK build 24B8118)
- iOS SDK 26.5 fallback: F:\NXNative\1_Development\SDKs\Xcode_26.5\iPhoneOS.sdk
- Celeste ROMs, builds, caches, logs, and outputs: F:\NXNative\Celeste
- Original Switch archives remain in D:\Downloads. General per-title build staging for other games may use F:\Temp as documented by their workspace.

The Windows user variable NXW_IOS_SDK selects SDK 27.2 by default. Set it to the 26.5 path above when a fallback build is specifically required.

## Toolchain

NXNative-specific extracted SDKs and source worktrees live on F:. Shared system installations remain in their existing locations: Python 3.14.5 under the user profile, .NET SDK 10.0.403 under C:\Program Files\dotnet, LLVM 23.1.4 under C:\Program Files\LLVM, Metal Developer Tools under Program Files, and Vulkan utilities under C:\VulkanSDK. The repository-local .NET shader translator stays with each source worktree. These shared tools are discovered by win/toolchain.py; do not duplicate or relocate them.

D:\NXNativeBuilds\.venvs\factorio-native-arm-ipad belongs to the Factorio project and remains on D:. Other D: build worktrees contain active or uncommitted game work and remain untouched. The primary repository's Git administration is still on D:, so F: linked worktrees depend on D:\NXNativeWindows\.git.

## Build workflow

Run python win/doctor.py before building. The Windows entry point is win/build_ipa_windows.py. For a new direct build, specify --work-dir and -o so intermediates and the final IPA go to the established locations. For Celeste use --work-dir F:\NXNative\Celeste\build and keep all game-specific work under F:\NXNative\Celeste.

The GUI starts with Build-IPA-GUI.bat or pythonw win/gui.pyw. It stages per-title builds under F:\Temp\NXNative\SMB when available, preserves the chosen output destination, and verifies SMB transfers. Other game workspaces retain their established paths.

For Celeste, use --split-data=F:\NXNative\Celeste\output\Celeste-data. Zip the split-data folder with the existing win/staging.py helper. The package contains the RomFS image and shader image and is copied to the app's Documents folder by the established install flow.

## Validation

win/doctor.py checks Python packages, .NET, LLVM/ld64.lld, the selected iPhoneOS SDK, Metal compilers, SPIRV-Cross, zstd, glslang, and fonts. Run python win/tests/test_win.py for the Windows builder suite. SMB staging and split-data tests are in win/tests; standard archive/shader unit tests use unittest.

SDK selection is part of the app compiler's object-cache key through its -isysroot argument. Confirm the detailed build log reports the selected SDK and actual compiled-object count. IPA metadata and the executable's Mach-O build version must both record the intended SDK. Compilation is not physical-device validation.
