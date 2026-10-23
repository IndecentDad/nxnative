# NXNative Project Status

- `main`, `origin/main`, and `upstream/main` match at `ebe75c9d5d34486f714678f850f0e74bbab398ac`.
- `compat/intel-tahoe` is `617abac`, with the universal launcher and the two parser fixes needed by the current upstream build.
- Save Folder Sync development is authoritative on `feature/save-folder-sync-upstream` at `67c8873`.
- `67c8873` removes the incorrect guest `save_path` layer: Celeste sync now uses the actual host payload root `Documents/save`, preserves the native transactional mount, and the realistic filesystem tests pass 17/17.
- The supplied logs showed `nts/save/0.celeste` came from the earlier mistaken host-side `save_path=nts/save`; it was never the confirmed fresh-device native layout. The regression fix no longer creates or inspects that local path.
- Celeste build `Celeste-SaveFolderSync-67c8873.ipa` was built unsigned on Tahoe and copied to the iOS output folder.
- The old Save Sync branch is archived as `archive/save-folder-sync-tahoe-xcode26` at `e71cb3a`.
- The next step is device validation using a local On My iPhone/iPad folder first, then a manually selected iCloud Drive folder. Confirm direct `0.celeste` export/import and inspect `Documents/log.txt` if verification still fails; tests and the build do not replace this validation.
