# NXNative project status

- main mirrors fetched upstream 787523f. integration retains device-validated upstream 6a068772 plus Intel launcher 9a68a3e; subsequent integration commits only document the workflow/status. Newer upstream is not integration-validated.
- Both Intel-only control IPAs are user-confirmed functional on iPhone. Immutable tags: validated/metroid-dread-ios-6a068772 and validated/celeste-ios-c6f19d5.
- Existing working IPAs, provenance, original inputs, saves and keys remain preserved. Control outputs: Roms/iOS/Metroid Dread/Upstream-6a068772-Validation and Roms/iOS/Celeste/Integration-c6f19d5-Validation.
- Branch consolidation complete: main + integration, with one temporary feature/eden-save-folder-sync. Old tips and local edits preserved in verified bundles/backup refs and useful legacy tags. Stable retirement explicitly approved; see docs/branch-archive.md.
- Feature candidate a51aad6 ports only the completed Eden Save Folder Sync bridge/UI and native transactional-save callback; no historical runtime merge. integration DOES NOT contain the feature yet.
- Candidate checks: 17 focused tests passed; real production Objective-C fingerprint/export/import/recovery/failure-preservation smoke checks passed. Both official fresh unsigned iOS builds passed, one per game.
- Candidate guest binaries are byte-identical to their successful controls; compiled sync bridge, source/tool/input provenance, shader stamps, ZIP integrity and unsigned/no-diagnostic state verified.
- Candidate outputs and manifests: Roms/iOS/Metroid Dread/SaveSync-a51aad6-Validation and Roms/iOS/Celeste/SaveSync-a51aad6-Validation.
- STOP for the user's device results on both sync candidates. Verify gameplay and native save behavior, direct Eden title-ID export/import (restart after import), conflict choices and clearing the selected folder. Provider behavior remains unvalidated.
- After BOTH pass: merge the focused feature into integration, create a new immutable validated checkpoint, then retire the temporary feature branch. Do not replace the known-working runtime from packaging alone.
- Primary development checkout: /volume1/docker/nxnative-integration (currently feature candidate). Clean Tahoe baseline: /Users/kylepyne/nxnative-integration; candidate source: /Users/kylepyne/nxnative-save-sync-candidate.
