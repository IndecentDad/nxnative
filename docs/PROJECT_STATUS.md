# NX Native Project Handoff

Repository: `IndecentDad/nxnative`  
Current branch: `main` (iCloud feature fast-forwarded from `feature/icloud-save-sync` at `752255f`)

## Completed

- Intel x86_64 macOS support is merged and translator-tested.
- Game-specific app-icon selection is merged and selector-tested. It is not yet validated in a complete IPA.
- The Python f-string syntax error in `scripts/build_ipa_from_nsp.py` is fixed.

## Development checkouts

- Permanent development checkout: `/volume1/docker/nxnative`.
- Preserve the existing Tahoe checkout at `/Users/kylepyne/nxnative`; do not overwrite, clean, or copy unrelated local changes.
- Do not push to `seedds/nxnative`.

## Metroid Dread

Metroid Dread reaches gameplay but experiences severe memory growth. The saved log ends at frame 16,800 (439 s) at 8,101 MiB resident, 7,246 MiB Metal allocated and 90 MiB headroom; it does not contain a terminating exception. The deferred-release queue was zero, pools stayed at 9, shared textures plateaued at 40, and serial/residency counts rose. A memory-limit termination is plausible but unconfirmed without the device's `.ips` report. This log's timeline differs from the separately reported ~97-second crash.

## Next priority

Fetched `seedds/nxnative` main to local `upstream/main` without merging (at `ea12221` on 2026-10-21). The fork already contains `ca90b26`, `12a20d0`, `aadb939`, `6c0a14d`, and the Dread autorelease-pool leak fix in `8b21049`. Later upstream `37c24c6` evicts shared textures on storage takeover; its relevance to Dread is unproven. Preserve Tahoe's `pr-5-x86` checkout at `b5a2a8c` with its unrelated local changes.

On 2026-10-21, the isolated Tahoe checkout `/Users/kylepyne/nxnative-dread-diag-f613cd3` built Metroid Dread 2.1.0 from fork commit `f613cd3`. Only `dmsh_chain.lock` and Dread's generated `dmsh_chain.h` differ there, to match Tahoe's installed translator/Metal tools (chain `78c708956b92`); no graphics resource lifetime code changed. Full ZIP CRC validation passed; the diagnostic IPA contains `DM_NVN_ALLOCPROF=1`, 1,010 compatible shader libraries, Dread RomFS, and the custom icon. As checked on 2026-10-22, the NAS now holds this diagnostic-size build as `/volume1/Media/Roms/iOS/Metroid Dread/Metroid Dread.ipa` (4,789,625,110 bytes); the separate diagnostic filename is absent. The original baseline survives on Tahoe at `/Users/kylepyne/nxnative-games/MetroidDread/MetroidDread-Official.ipa` (4,786,760,273 bytes). No IPA, shaders, assets, or existing Tahoe checkout were changed during iCloud work.

## iCloud save feature (2026-10-22)

Commit `752255f` adds shared iOS snapshot/revision sync, manual Files export/import, an on-screen Saves menu, deferred imports, and optional shared iCloud Documents build configuration. See [icloud-saves.md](icloud-saves.md). Tahoe compiled the shared iOS sources; APFS runtime tests, two generated Xcode project configurations, and an ad hoc entitlement check passed. No new IPA was built. Obsolete `app-icon-support` and `intel-macos-support` remote branches were deleted after verifying both are ancestors of fork main and no worktree depends on them; the local app-icon branch was also deleted. Newer upstream was reviewed but not merged. The old uncommitted status document was preserved in a pre-merge stash, and its findings were incorporated here.

Next: configure the Apple Developer shared iCloud container and explicit App ID/profile per game; then validate PlumeImpactor's actual provisioned entitlements and two-device iCloud behavior. Build a cloud-enabled IPA only after that configuration is ready. Continue Dread memory diagnostics separately; do not modify graphics resource management before device logs are analyzed.
