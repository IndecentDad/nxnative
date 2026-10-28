# NXNative Project Status

## Active work

- Temporary branch: `game/mario-rabbids-kingdom-battle`. The working branch has reconciled latest upstream `201dfd1280684e9d3ceac8b644236fdac11b6cc2`; `main` and `integration` remain unchanged.
- Upstream now carries the complete Kingdom Battle profile and fixes: Snowdrop 2 GiB / 512 MiB / 512 MiB pools, 32,768-page large-pool bound, SDK 4.4.0 64 MiB node area and 32 MiB large-region alignment, plus 11,625 shader stages including nested SDF records.
- The old equal 1 GiB diagnostic patch is superseded. Upstream reports Mac gameplay through early World 1-1; iOS remains unvalidated.
- Eden-compatible Save Folder Sync was restored onto the upstream launcher, retaining folder selection, automatic save/foreground sync, status/details, conflict resolution and no Sync Now button or legacy iCloud path.
- The Windows Metal worker and exchange utility remain on this branch. Existing 16,797-source/24,117-key Windows outputs and previous IPAs are preserved as historical fallbacks; they are from the previous chain and are not yet verified reusable for the new 11,625-stage chain.

## Validation and build constraints

- Passed: 15 upstream patch-table tests; 12 Save Sync contract checks; full iOS Swift launcher type-check against the installed SDK. The translator launcher is a universal x86_64/arm64 Mach-O.
- The existing Windows IPA remains at `/volume1/Media/Roms/iOS/Mario Rabbids - Kingdom Battle/MarioRabbidsKingdomBattle-v1.9.589692-Windows-Metal-6.2-unsigned.ipa` (SHA-256 `e6a466b5a02df9faa047c05774b29fe0c87da0f86313107d66e6f24965c8c87e`). It predates upstream's new shader inventory and compiler chain; it is not a build of this update.
- A fresh upstream build is blocked on toolchain fingerprints: upstream requires Python 3.12+ and Metal `32023.921`; Tahoe currently has Python 3.9.6 and Metal `32023.883`. The preserved Windows receipts are Metal `32023.850` with the prior no-`-O1` flags. Do not reuse those or enable `--allow-other-metal` without an explicit compatibility decision.
- NSP extraction and four DLC extractions remain in the existing game workspace. No new shader split, Metal compile, Xcode build or IPA packaging was run because the pinned compiler/source toolchain does not match.

## Other validated builds

- Echoes of Wisdom 1.1.0: unsigned IPA `/volume1/Media/Roms/iOS/Echoes of Wisdom/Build v1.1.0/Echoes-of-Wisdom-v1.1.0.ipa`; 9,858 shaders, 14,159 metallibs; device gameplay and Save Sync provider behavior remain untested.
- Celeste 1.4.1.1: unsigned IPA `/volume1/Media/Roms/iOS/Celeste/Build integration-2694c28/Celeste-1.4.1.1-integration-2694c28.ipa`; 26 shaders, 38 metallibs; not device-tested.

## Next

- Resolve the matching compiler/runtime requirement (Python 3.12+ and Metal 32023.921 on Tahoe, or a Windows compiler/configuration that matches the new upstream chain). Then run the source pipeline, compare source hashes before reusing any old libraries, compile missing/current outputs consistently, and build the unsigned IPA.
- The previous Rabbids IPA has not been installed. After a matching build is produced, device-test startup and Save Folder Sync; compiler success alone is not runtime validation.
