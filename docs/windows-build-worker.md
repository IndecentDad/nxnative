# Windows build worker

## Checkout and access

The Windows repository is on the physical Windows 11 PC at `D:\NXNativeWindows`. From the Synology Codex host, the documented SSH alias is `nxwindows`; the stable `windows/main` branch may also be checked out in a separate worktree under `D:\NXNativeBuilds`. Run `git worktree list` before selecting a checkout. Inspect `git status` before any work and preserve uncommitted files, build outputs, game inputs and caches.

Read-only connection check:

```sh
ssh -o BatchMode=yes nxwindows "whoami"
```

PowerShell inspection through SSH:

```sh
ssh nxwindows "powershell -NoProfile -Command \"Set-Location 'D:\\NXNativeWindows'; git status --short --branch; git remote -v; git branch -avv; git worktree list --porcelain\""
```

## Toolchain and build

The iPhoneOS SDK is under `win\sdk\out\iPhoneOS.sdk`; `win\toolchain.py` discovers SDKs under `win\sdk\out`. Check existing tools with `python win\doctor.py` before installing anything. It checks Python packages, .NET 10, LLVM/clang and `ld64.lld`, the SDK, Metal compilers, spirv-cross, zstd, glslang and fonts.

The Windows entry point is:

```powershell
python win\build_ipa_windows.py <NSP-folder> -k <prod.keys>
```

Use `--split-data` for an app plus a sibling data folder. Inspect the IPA and generated data folder before transfer. Build outputs and reusable shader artifacts stay beside the NSP under `<title ID>_build`; preserve them and let the pipeline validate cache reuse. Windows split-data builds extract RomFS as a directory; conventional IPA extraction retains `RomFS.img`. The builder stages the requested representation and replaces only the old RomFS representation when switching modes.

Do not print key values, overwrite original game inputs, delete output/cache folders, or clean unrelated worktrees. Keep SMB output transfers staged locally and verify transferred output hashes before considering a packaging run complete.
