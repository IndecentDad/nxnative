# NXNative project status

- Permanent model: main mirrors fetched upstream 787523f; integration remains validated upstream 6a068772 plus Intel launcher 9a68a3e and documentation. Newer upstream is not integration-validated.
- Both controls are user-confirmed functional on iPhone. Immutable tags: validated/metroid-dread-ios-6a068772 and validated/celeste-ios-c6f19d5.
- Control IPAs/provenance remain under /volume1/Media/Roms/iOS/Metroid Dread/Upstream-6a068772-Validation/ and /volume1/Media/Roms/iOS/Celeste/Integration-c6f19d5-Validation/. Original historical Dread IPA remains on Tahoe.
- All old branch tips and worktree edits archived in verified NAS/Tahoe bundles and backup refs; useful unique work also has published legacy tags. See docs/branch-archive.md for locations and recovery.
- Old diagnostic, repair, experimental and game-specific branches retired. Stable retirement explicitly approved. Dirty/unique archival worktrees remain detached; three clean redundant NAS worktrees removed. No ROMs, saves, keys, tool environments or IPAs deleted; no force-push.
- Current temporary branch: feature/eden-save-folder-sync, based directly on clean integration. No historical integration merge.
- Ported legacy save class/bridge, native Documents/save mapping, Eden title-ID folder format, existing launcher controls and successful transactional-save callback. Scheduler, audio, graphics, rewriter and normal launcher lifecycle unchanged.
- Candidate source a51aad6e0ae2fef570a94c05e5291fc0f3b5105e: 17 focused tests and real production Objective-C transfer smoke checks passed. Exactly one official fresh unsigned build per game completed, both exit 0; each compiled 135 iOS files.
- Both packages: ARM64, expected Save Sync class/commit selector, no bundled env.txt/signature/profile, complete ZIP CRC validation; fresh source/tool/input/rewriter/shader provenance verified. Guest rewritten binaries byte-identical to successful controls. NAS copies checksum-verified.
- Candidate outputs/manifests: Roms/iOS/Metroid Dread/SaveSync-a51aad6-Validation and Roms/iOS/Celeste/SaveSync-a51aad6-Validation. Dread SHA-256 fe383fee8360ed697977877a1de1362c6eca65d39f4ac9d149a93ed26d9b2967; Celeste SHA-256 0e2b80063bfaae99861706813f50e1ab642f872fdb9c3123c2462cab66dd96ae.
- Integration received documentation-only handoff updates; its runtime remains the device-validated Intel-only control. Feature candidates are not merged. No further build or merge before the user tests both.
- Do not merge into integration or retire the temporary feature until the user confirms both games with Save Folder Sync on iPhone. Do not create a validated sync checkpoint from packaging alone.
- Next device checks: launcher/gameplay without a folder; direct title-ID export/import (restart after import), Eden compatibility, conflict choices and clearing the folder while preserving native saves. Provider behavior requires device validation.
- Development checkout: /volume1/docker/nxnative-integration; Tahoe clean integration checkout remains /Users/kylepyne/nxnative-integration. Candidates use an isolated feature checkout and new game folders.
