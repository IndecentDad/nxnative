# NXNative Project Status

- `main` and `origin/main` are an exact mirror of `upstream/main` at `9a56ecf0`.
- `integration` includes local Save Folder Sync polish (`a368850`) and the handoff commit (`46041d3`), then merges upstream `main` at `bd2b164`. Pre-merge state is preserved locally as `integration/pre-upstream-9a56ecf-46041d3`.
- The merge preserved Eden-compatible Save Folder Sync and upstream's new same-core wake handoff. One launcher conflict was resolved by keeping upstream's `GeometryReader`/`NavigationStack` layout while retaining Save Sync status, controls, and details.
- Focused Save Folder Sync pytest suites pass (19 tests); patch tests pass (6 tests). PR #210's source branch `IndecentDad/save-folder-sync` remains unchanged at `c077af7`.
- Metroid Dread build is pending. Tahoe has Xcode 26.6 and Metal 32023.883; the checkout's locked Metal fingerprint is 32023.921, so locked shader caches are incompatible. Tahoe has 9.3 GiB free, while the 4.2 GiB base NSP and 284 MiB update remain on the Synology volume, which is not mounted on Tahoe.
- No physical iOS device is visible to Xcode, so actual gameplay validation has not occurred. No IPA was produced.
- Next: provide enough Tahoe disk space and access to the two ROM files, build from a separate checkout of the then-current `integration` commit with matching/rebuilt shader artifacts, then install on a connected device and capture real logs through the movie transition and gameplay.
