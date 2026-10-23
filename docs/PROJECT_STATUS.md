# NXNative Project Status

- `main`, `origin/main`, and `upstream/main` match at `ebe75c9d5d34486f714678f850f0e74bbab398ac`.
- `compat/intel-tahoe` is `617abac`, with the universal launcher and the two parser fixes needed by the current upstream build.
- Save Folder Sync development is authoritative on `feature/save-folder-sync-upstream` at `1090450`.
- `1090450` maps Celeste's current native payload `Documents/save/nts/save` to the direct Title ID folder, preserves the native transactional root, logs source/destination URLs and verification listings, and keeps provider coordination scoped to provider sources; focused filesystem tests pass 17/17.
- The supplied logs confirmed `nts/save/0.celeste` was produced by Celeste beneath the native save mount and then preserved by `copyTree`; the previous copy failure occurred at the provider `copyItemAtURL` stage for that nested destination path. The new build removes that nested external path by using the actual payload root.
- Celeste build `Celeste-SaveFolderSync-1090450.ipa` was built unsigned on Tahoe and copied to the iOS output folder.
- The old Save Sync branch is archived as `archive/save-folder-sync-tahoe-xcode26` at `e71cb3a`.
- The next step is device validation using a local On My iPhone/iPad folder first, then a manually selected iCloud Drive folder. Confirm direct `0.celeste` export/import and inspect `Documents/log.txt` if verification still fails; tests and the build do not replace this validation.
