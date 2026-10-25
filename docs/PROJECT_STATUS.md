# NXNative project status

- Permanent model: `main` and `origin/main` exactly mirror fetched upstream `787523f`; `integration` starts at verified upstream `6a068772` plus Intel launcher commit `9a68a3e`. Later upstream changes are not yet integration-validated.
- Runtime changes versus the pinned baseline: universal translator launcher only. No Eden Save Folder Sync, diagnostics, scheduler experiments or game-specific custom patches.
- Metroid Dread 2.1.0 is user-confirmed working on iPhone; immutable checkpoint `validated/metroid-dread-ios-6a068772` reconstructs its exact source tree.
- Successful IPA and provenance: `/volume1/Media/Roms/iOS/Metroid Dread/Upstream-6a068772-Validation/`. Original historical `MetroidDread-main-6783602.ipa` remains on Tahoe.
- Latest Metroid log reaches frame 1800 without RED errors or a recorded crash; footprint about 1039→1056 MiB, then normal background suspension. Longer gameplay/memory validation remains outstanding.
- Existing local/origin branch tips backed up under `refs/backup/consolidation-20261025T030211Z/`; original worktrees and uncommitted edits remain untouched. Snapshot patches are under the main repository's `.git/consolidation-backups/20261025T030211Z/`.
- Legacy Save Sync retained at `refs/legacy/save-folder-sync-ec440a2`, `feature/metroid-dread@ec440a2` and existing archive refs. No branches/worktrees deleted.
- `main`, `integration` and the validated Metroid tag are published to `IndecentDad/nxnative` using normal pushes. Local Git identity is IndecentDad. Development checkouts: `/volume1/docker/nxnative-integration` and Tahoe `/Users/kylepyne/nxnative-integration`; older worktrees remain preserved.
- Celeste control built once from clean integration `c6f19d5389ea42ee7177147a2172fc4274433105`, official script, exit 0. Update v589824, registered 1.4.1.1; original NACP/app metadata says 1.4.1. No game-specific patches.
- Fresh Celeste extraction/module IDs, rewrite source stamps, embedded ARM64 code, packaged tables, shader stamps and ZIP CRC verified; source tree clean. Shader chain `dec5ee141a9f`, inputs `b49c5e68312b`, 26 shaders / 38 metallibs; gates main 17 / sdk 105. No bundled env.txt, Save Sync, signature or provisioning profile.
- Celeste output and provenance: `/volume1/Media/Roms/iOS/Celeste/Integration-c6f19d5-Validation/`; IPA `Celeste-Integration-c6f19d5-Unsigned.ipa`, 924775991 bytes, SHA-256 `bf36737e15d7909cffcd45c643a36da7ae5a51af68bc0abdc27bb493f4dec1bc`. Isolated Tahoe outputs: `/Users/kylepyne/nxnative-games/Celeste-integration-c6f19d5/`.
- Current gate: STOP for the user's Celeste iPhone results. No gameplay claim, Celeste validated tag, branch cleanup or Save Folder Sync migration yet. Documentation-only commits after c6f19d5 do not change the recorded build source.
- After Celeste device confirmation only: audit/consolidate old branches and worktrees, then port Save Folder Sync on a temporary feature branch without historical runtime code; validate both games before merging.
- Build/update policy and exact modifications: `README.md`, `AGENTS.md`, `docs/build-provenance.md`.
