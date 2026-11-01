# NXNative Windows integration status

- Working branch: `windows/main`; current baseline includes Windows cloud-save integration (`4ddec77b`).
- GUI scrolling fix is present at `a8b462f5`; Windows RomFS extraction-mode and iOS task submission fixes are committed at `904b93bb`.
- Upstream cloud-save engine from `123c7ff0` is integrated at `0096df7a`; Windows UIKit folder selection, build source discovery, and the upstream fetch-thread failure fix are at `c899e93a`.
- Root `AGENTS.md` now documents Windows, Tahoe, Linux, and GitHub routing.
- Windows toolchain doctor passed. Four RomFS mode tests passed. `win/compile_check.py` compiled all 186 app sources for iOS SDK 26.5, including `save_sync.c`, `CloudSaves.m`, `SaveSync.m`, `front_ios.m`, and the UIKit launcher.
- Windows SMB builds keep staging and build artifacts under the running GUI EXE directory; network-source IPA and split-data outputs default to Media/Roms/iOS/<Game Name>, with split data zipped locally before transfer. Ten focused tests pass.
- The upstream `t_save_sync` host test was not run on Windows; its harness uses Darwin APIs. iCloud Drive behavior still needs device validation on iPad.
- The GUI process stayed alive when started through SSH, but SSH launched it in Session 0 without a visible window handle; interactive scrolling and settings controls remain unverified.
- Shader chain files are unchanged from the Windows baseline (`dmsh_chain.h` `9a8bbaaf`, `dmsh_chain.lock` `3d7d5754`). Fetched current upstream has different fingerprints (`8cdb0742`, `d3d525eb`); do not reuse assets built for that chain without pipeline stamp checks.
- Upstream Switch 2 main tip cd859c38 is merged locally in 692b53dc; branch windows/main is unpushed and worktree was clean after the merge commit. Local branch is ahead of origin/windows/main; no local nx2 branch exists. Remote origin/nx2 has one unique commit and upstream/nx2 has seven commits not in upstream/main; neither ref has been deleted.
- Focused archive suite: 18 passed, 2 skipped; isolated depth/stamp classification passed. The full regression module needs Darwin libproc and t_nvn is Mac-only. Windows compile_check passed for 186/186 app sources.
- Overcooked v1.0.12 compiled 45,221/45,221 filtered shaders and produced a 41.2 MB IPA plus an 8.00 GB data ZIP. The Increased Memory Limit entitlement was verified. Build outputs and hashes are in the game note; device gameplay remains untested.
- Upstream lock still requires Metal 32023.922.4; Windows Metal 32023.850 is separately identified in dmsh_chain.windows.lock. The original dmsh_chain.lock is unchanged. Tahoe SSH remains blocked at the documented OpenCore picker; exact Mac compiler availability is unverified.
- The iOS memory guard is preserved; unsafe texture-page discard remains disabled. Windows tests passed 30 (1 optional skip); focused dump, AArch64 validation, Metal lock/cache, and patch_nso worker tests passed.

- Windows translator variant is a Release win-x64 .NET 10 build, source hash bff706efc1b71e0e, validated against its explicit lock. Upstream ARM64 translator lock/binaries remain untouched.
- Bananza dump under D:\Downloads\Donkey Kong Bananza is update 458752 with base/updates/dlc; source is unchanged and the isolated workspace uses directory junctions. Upstream pack produced an 8.6 GB RomFS image and one DLC image.
- Upstream shader split found 23,638 entries. Vertex f9c807930abd1234, geometry 5d537f7630ec3671, and compute 56493833ce173d1b passed translation and iOS Metal compilation: 5 outputs, 20 variants compiled, 1 compatible cache reuse.
- Full split-IPA build is active in D:\NXNativeBuilds\Bananza-040074A01BF12000-win; Metal stage 4,084/23,638 (17%) at last check, using the Windows 32023.850 lock/cache identity. No IPA/data ZIP or Synology transfer yet. Split packaging now places the packed image at Documents/romfs.img, which the iOS runtime supports; the Windows regression suite passes 31 tests (1 optional skip).
- Windows build fixes include UTF-8 shader table outputs, dump copy fallback when APFS cp is unavailable, explicit XLATE selection, variant-aware Metal validation, and a Windows thread pool for patch_nso scans. The full cross-platform Python suite is not clean on Windows (770 tests: 27 failures, 138 errors, 41 skips); graphics suite also has host-specific failures. Do not describe those suites as passing.
