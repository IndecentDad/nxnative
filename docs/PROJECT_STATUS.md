# NXNative project status

- Permanent model: main mirrors fetched upstream 787523f; integration remains validated upstream 6a068772 plus Intel launcher 9a68a3e and documentation. Newer upstream is not integration-validated.
- Both controls are user-confirmed functional on iPhone. Immutable tags: validated/metroid-dread-ios-6a068772 and validated/celeste-ios-c6f19d5.
- Control IPAs/provenance remain under /volume1/Media/Roms/iOS/Metroid Dread/Upstream-6a068772-Validation/ and /volume1/Media/Roms/iOS/Celeste/Integration-c6f19d5-Validation/. Original historical Dread IPA remains on Tahoe.
- All old branch tips and worktree edits archived in verified NAS/Tahoe bundles and backup refs; useful unique work also has published legacy tags. See docs/branch-archive.md for locations and recovery.
- Old diagnostic, repair, experimental and game-specific branches retired. Stable retirement explicitly approved. Dirty/unique archival worktrees remain detached; three clean redundant NAS worktrees removed. No ROMs, saves, keys, tool environments or IPAs deleted; no force-push.
- Current temporary branch: feature/eden-save-folder-sync, based directly on clean integration. No historical integration merge.
- Ported legacy save class/bridge, native Documents/save mapping, Eden title-ID folder format, existing launcher controls and successful transactional-save callback. Scheduler, audio, graphics, rewriter and normal launcher lifecycle unchanged.
- Existing focused sync tests: 17 passed. Candidate iOS compilation and one fresh unsigned build per game are the current task; record source/tool/input/artifact provenance for both.
- Do not merge into integration or retire the temporary feature until the user confirms both games with Save Folder Sync on iPhone. Do not create a validated sync checkpoint from packaging alone.
- Next device checks: launcher/gameplay without a folder; direct title-ID export/import (restart after import), Eden compatibility, conflict choices and clearing the folder while preserving native saves. Provider behavior requires device validation.
- Development checkout: /volume1/docker/nxnative-integration; Tahoe clean integration checkout remains /Users/kylepyne/nxnative-integration. Candidates use an isolated feature checkout and new game folders.
