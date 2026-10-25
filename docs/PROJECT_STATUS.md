# NXNative project status

- Permanent model: `main` mirrors current upstream; `integration` starts at verified upstream `6a068772` plus Intel launcher commit `9a68a3e`. Later upstream changes are not yet integration-validated.
- Runtime changes versus the pinned baseline: universal translator launcher only. No Eden Save Folder Sync, diagnostics, scheduler experiments or game-specific custom patches.
- Metroid Dread 2.1.0 is user-confirmed working on iPhone; immutable checkpoint `validated/metroid-dread-ios-6a068772` reconstructs its exact source tree.
- Successful IPA and provenance: `/volume1/Media/Roms/iOS/Metroid Dread/Upstream-6a068772-Validation/`. Original historical `MetroidDread-main-6783602.ipa` remains on Tahoe.
- Latest Metroid log reaches frame 1800 without RED errors or a recorded crash; footprint about 1039→1056 MiB, then normal background suspension. Longer gameplay/memory validation remains outstanding.
- Existing local/origin branch tips backed up under `refs/backup/consolidation-20261025T030211Z/`; original worktrees and uncommitted edits remain untouched. Snapshot patches are under the main repository's `.git/consolidation-backups/20261025T030211Z/`.
- Legacy Save Sync retained at `refs/legacy/save-folder-sync-ec440a2`, `feature/metroid-dread@ec440a2` and existing archive refs. No branches/worktrees deleted.
- Current task: build one clean unsigned Celeste 1.4.1.1 IPA from integration, with fresh artifacts and recorded provenance; stop for device results.
- After Celeste device confirmation only: audit/consolidate old branches and worktrees, then port Save Folder Sync on a temporary feature branch without historical runtime code; validate both games before merging.
- Build/update policy and exact modifications: `README.md`, `AGENTS.md`, `docs/build-provenance.md`.
