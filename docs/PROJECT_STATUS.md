# NX Native Project Handoff

Repository: `IndecentDad/nxnative`  
Upstream: `seedds/nxnative`  
Infrastructure paths and Tahoe access details are documented in the repository/host `AGENTS.md`.

## Branches and commits

- `main` includes the latest upstream baseline plus the merged Intel support change (`3d4408c`).
- `intel-macos-support` was the focused Intel compatibility branch; its two-file change was merged to `main`.
- `app-icon-support` is based on current `main` and currently contains `7a26c4b`.
- Do not push to `seedds/nxnative`.

## Intel macOS support

The Intel compatibility patch provides an architecture-aware `dmsh_xlate` launcher and the `dmsh_xlate.arm64` companion executable. On the Intel Tahoe VM, the launcher falls back to `/usr/local/share/dotnet/dotnet` and successfully reports the translator source hash. Apple Silicon selects the arm64 companion.

## App icons

The upstream project template and iOS build script already generate `Gen/Assets.xcassets/AppIcon.appiconset` and set `DM_APPICON` when an icon exists. The app-icon change makes the Python build pipeline prefer explicit `DM_ICON`, then matching artwork named `<Game>_icon` beside the requested IPA, then extracted `icon.jpg`. It is reusable across games and does not extract icons from NSP files.

The Synology artwork currently found for Metroid Dread is `MetroidDread_icon.jpg` (992×992). The change has passed the focused artwork-selection check and whitespace validation, but has not been tested in a full IPA build.

## Tahoe checkout

The existing checkout is `/Users/kylepyne/nxnative` on the Tahoe VM. Preserve it; it is not to be overwritten or cleaned. It was on the Intel PR branch during earlier validation and has local work unrelated to the fork merge.

Outstanding local Tahoe modifications are in:

- `dm/games/010093801237C000/dmsh_chain.h`
- `dm/gfx/tools/dmsh_chain.lock`
- `dm/ios/project.yml`
- `scripts/build_ipa_from_nsp.py`
- untracked `.venv/` and backup files

The Dread chain header and lock changes affect shader-chain reproduction. The project-template icon-reference removal and the script heartbeat are local workarounds/diagnostics; do not copy them blindly. The icon references are present in fork `main`.

## Metroid Dread memory issue

Gameplay reaches roughly 16,800 frames before resident memory approaches the 8.2 GB iOS limit. Observed resident memory was about 8,101 MB, with roughly 90 MB headroom; Metal accounted for about 7,246 MB. Deferred queue depth was zero, while resource/residency counters and reuploads continued growing. This strongly suggests uncontrolled Metal/NVN resource retention or a related cache/lifetime problem, but the termination has not been conclusively classified. No memory fix has been implemented.

## Known blocker

`scripts/build_ipa_from_nsp.py` contains a pre-existing f-string syntax error at line 427 (`mods[n]["kind"]` inside an f-string expression). It predates the icon change and remains unresolved intentionally.

## Next session

First review this handoff and `AGENTS.md`, then verify the fork branch and Tahoe state. Test the icon path with a targeted catalog-generation check before any full IPA build. Keep Dread memory work separate from icon support.
