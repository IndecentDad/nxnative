# NXNative Windows integration status

- Working branch: `windows/main`; current baseline includes Windows cloud-save integration (`4ddec77b`).
- GUI scrolling fix is present at `a8b462f5`; Windows RomFS extraction-mode and iOS task submission fixes are committed at `904b93bb`.
- Upstream cloud-save engine from `123c7ff0` is integrated at `0096df7a`; Windows UIKit folder selection, build source discovery, and the upstream fetch-thread failure fix are at `c899e93a`.
- Root `AGENTS.md` now documents Windows, Tahoe, Linux, and GitHub routing.
- Windows toolchain doctor passed. Four RomFS mode tests passed. `win/compile_check.py` compiled all 186 app sources for iOS SDK 26.5, including `save_sync.c`, `CloudSaves.m`, `SaveSync.m`, `front_ios.m`, and the UIKit launcher. No IPA or shaders were rebuilt.
- Windows SMB builds keep staging and build artifacts under the running GUI EXE directory; network-source IPA and split-data outputs default to Media/Roms/iOS/<Game Name>, with split data zipped locally before transfer. Ten focused tests pass; no game rebuilt.
- The upstream `t_save_sync` host test was not run on Windows; its harness uses Darwin APIs. iCloud Drive behavior still needs device validation on iPad.
- The GUI process stayed alive when started through SSH, but SSH launched it in Session 0 without a visible window handle; interactive scrolling and settings controls remain unverified.
- Shader chain files are unchanged from the Windows baseline (`dmsh_chain.h` `9a8bbaaf`, `dmsh_chain.lock` `3d7d5754`). Fetched current upstream has different fingerprints (`8cdb0742`, `d3d525eb`); do not reuse assets built for that chain without pipeline stamp checks.
- Upstream/main fetched through bfc70881. Integrated 1a9145ff (Echoes depth checks), compatible profile fixes from 74e31944 for profiles present here, and the NVN buffer layout fix f5cc73d0. Windows DM_GAMES_DIR and CRLF TSV adaptations are included; platform-specific Metal 4 changes and profiles absent from this checkout remain out.
- Focused archive suite: 18 passed, 2 skipped; isolated depth/stamp classification passed. The full regression module needs Darwin libproc and t_nvn is Mac-only. Windows compile_check passed for 186/186 app sources.
- Next: from an interactive Windows user session, push `windows/main` to `origin`; then validate a new IPA on iPad. Preserve untracked `prod.keys` and `win/gui.pyw.backup-20261030-172745`.
