# NXNative Project Status

- `main`, `origin/main`, and `upstream/main` match at `ebe75c9d5d34486f714678f850f0e74bbab398ac`.
- `compat/intel-tahoe` is `617abac`, with the universal launcher and the two parser fixes needed by the current upstream build.
- Save Folder Sync development is authoritative on `feature/save-folder-sync-upstream` at `f54a5ca`.
- `f54a5ca` fixes canonical Title ID folder resolution, one-sided baseline decisions, staged replacement, source/destination verification, and readable iCloud/file errors; focused filesystem tests pass 17/17.
- Celeste build `Celeste-SaveFolderSync-f54a5ca.ipa` was built unsigned on Tahoe and copied to the iOS output folder.
- The old Save Sync branch is archived as `archive/save-folder-sync-tahoe-xcode26` at `e71cb3a`.
- The next step is device validation using a local On My iPhone/iPad folder first, then a manually selected iCloud Drive folder. Confirm import/export, conflict handling, and restart guidance using the new Title ID path; tests and the build do not replace this validation.
