# NXNative Project Status

- `main`, `origin/main`, and `upstream/main` match at `ebe75c9d5d34486f714678f850f0e74bbab398ac`.
- `compat/intel-tahoe` is `617abac`, with the universal launcher and the two parser fixes needed by the current upstream build.
- Save Folder Sync development is authoritative on `feature/save-folder-sync-upstream` at `9c33323`.
- `9c33323` limits file coordination to provider-backed sources, reacquires the security scope for explicit conflict actions, preserves old payloads until verification passes, changes initial conflict wording, and logs phase/URL/file/domain/code details to `Documents/log.txt`; focused filesystem tests pass 17/17.
- Celeste diagnostic build `Celeste-SaveFolderSync-9c33323.ipa` was built unsigned on Tahoe and copied to the iOS output folder.
- The old Save Sync branch is archived as `archive/save-folder-sync-tahoe-xcode26` at `e71cb3a`.
- The next step is device validation using a local On My iPhone/iPad folder first, then a manually selected iCloud Drive folder. Retrieve `Documents/log.txt` after each failed direction so the exact provider NSError can be identified; tests and the build do not replace this validation.
