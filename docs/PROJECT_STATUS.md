# NXNative Project Status

- `main`, `origin/main`, and `upstream/main` match at `ebe75c9d5d34486f714678f850f0e74bbab398ac`.
- `compat/intel-tahoe` is `617abac`, with the universal launcher and the two parser fixes needed by the current upstream build.
- Save Folder Sync development is authoritative on `feature/save-folder-sync-upstream` at `f6357b4`.
- `67c8873` removes the incorrect guest `save_path` layer: Celeste sync now uses the actual host payload root `Documents/save`, preserves the native transactional mount, and the realistic filesystem tests pass 17/17.
- `5bafbbc` copies immediate host-directory contents recursively, preserving legitimate game subfolders without synthesizing a guest `nts/save` hierarchy; focused tests remain 17/17.
- `f6357b4` aligns import fingerprinting with that same direct recursive traversal and logs expected/actual verification fingerprints and payload listings for code 4 failures.
- The supplied logs showed `nts/save/0.celeste` came from the earlier mistaken host-side `save_path=nts/save`; it was never the confirmed fresh-device native layout. The regression fix no longer creates or inspects that local path.
- Celeste was rebuilt unsigned from `f6357b4` on Tahoe; the rebuilt IPA overwrote `Celeste-SaveFolderSync-5a419c3.ipa` in the iOS output folder.
- The old Save Sync branch is archived as `archive/save-folder-sync-tahoe-xcode26` at `e71cb3a`.
- The next step is device validation using a local On My iPhone/iPad folder first, then a manually selected iCloud Drive folder. Confirm direct `0.celeste` export/import and inspect `Documents/log.txt` if verification still fails; tests and the build do not replace this validation.
