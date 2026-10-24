# NXNative Project Status

- `main` and `origin/main` match at `af29e41`; `upstream/main` remains the clean upstream mirror at `ebe75c9`.
- Eden Save Folder Sync, Intel compatibility, and the parser fixes are merged into `main` through merge commits `66fcc2f` and `af29e41`.
- Current main retains the native transactional save handling, direct `Documents/save` mapping, and current app-icon generation; older experimental implementations remain archived rather than merged.
- `67c8873` removes the incorrect guest `save_path` layer: Celeste sync now uses the actual host payload root `Documents/save`, preserves the native transactional mount, and the realistic filesystem tests pass 17/17.
- `5bafbbc` copies immediate host-directory contents recursively, preserving legitimate game subfolders without synthesizing a guest `nts/save` hierarchy; focused tests remain 17/17.
- `f6357b4` aligns import fingerprinting with that same direct recursive traversal and logs expected/actual verification fingerprints and payload listings for code 4 failures.
- The supplied logs showed `nts/save/0.celeste` came from the earlier mistaken host-side `save_path=nts/save`; it was never the confirmed fresh-device native layout. The regression fix no longer creates or inspects that local path.
- Celeste was rebuilt unsigned from `f6357b4` on Tahoe; the rebuilt IPA overwrote `Celeste-SaveFolderSync-5a419c3.ipa` in the iOS output folder.
- The old Save Sync branch is archived as `archive/save-folder-sync-tahoe-xcode26` at `e71cb3a`.
- Unfinished Celeste, iCloud diagnostics, Mario Rabbids, and SideStore work remain outside main and were preserved unchanged.
- The next step is device validation using a local On My iPhone/iPad folder first, then a manually selected iCloud Drive folder. Confirm direct `0.celeste` export/import and inspect `Documents/log.txt` if verification still fails; tests and the build do not replace this validation.
