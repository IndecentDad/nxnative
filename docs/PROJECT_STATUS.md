# NXNative Project Status

## Branch synchronization — 2026-11-05

- Upstream `seedds/nxnative` main was fetched through `865cc35fad7034d17c2190f8ce349f61f5bcaba1`.
- Fork `main` is maintained as an upstream mirror; the synchronization worktree is `D:\\NXNativeBuilds\\nxnative-sync-main-20261105` on `codex/sync-main-20261105`.
- The Windows integration retains its Windows build GUI, translator and Metal pipeline, SMB staging, split-data packaging, custom game profiles, and existing Save Folder Sync components.
- The controller layout gear fix from PR #4 (`6833993b`) is included.
- The integration includes upstream changes through `865cc35`, including Unreal dynamic-buffer copies (`6d269f93`) and file-backed guest-memory support (`865cc35`). File-backed memory remains opt-in; no MKW-specific runtime setting was changed.
- Windows-only compatibility fixes include matching `web_apple.m` in the host source list, Windows locking in `dm/tools/tree_tar.py`, and Windows translator/SPIRV-Cross discovery in the Ampere regression tests.

## Validation

- Windows application, SMB staging, and split-data tests: 28 passed, 1 skipped (optional texture decoder).
- Focused mesh-stage, shader reflection, pool-array, Unreal ring, and NSO matching tests: 84 passed, 1 skipped.
- Game-profile and documentation tests: 18 passed after regenerating the patch/symptom indexes with Python UTF-8 mode.
- Python syntax checks and `win/doctor.py`: passed; Windows SDK, .NET, translator DLLs, Metal compilers, SPIRV-Cross, and supporting tools were found.
- Ampere translator suite on Windows: 70 passed, 3 failed in unsupported-operation cases because the child process could not load `System.Runtime, Version=10.0.0.0`; no shader behavior changes were made. The upstream tool-lock checker remains Mac-oriented and does not describe the Windows Metal/translator binaries.
- `win/tests/test_romfs_extract_mode.py` remains incompatible with the current `build_ipa_from_nsp.py` API; it expects extraction-mode APIs that do not exist. No game build was run.

## Remaining work

- Verify the final remote refs after pushing the validated mirror and Windows integration; keep pushes fast-forward only.
- Review the Windows branch's legacy Save Folder Sync implementation separately before any removal.
- Controller gear behavior and Mario Kart World performance have not been device-tested as part of this synchronization.
