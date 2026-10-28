# NXNative Project Status

## Active work

- Branch: `game/mario-rabbids-kingdom-battle`; fresh build based on `695c1f8129edd6246bafb5c8bbfdf640fd4e1346`. `main` and `integration` were not changed.
- Kingdom Battle uses the upstream Snowdrop 2 GiB / 512 MiB / 512 MiB allocator layout, SDK address-region fixes, and 11,625 registered shader stages.
- Eden-compatible automatic Save Folder Sync and its current conflict/status UI remain in the branch; no Sync Now control or legacy iCloud path.

## Clean Intel Tahoe build

- Built from original base, v1.9.0 update, all four DLC NSPs, and the JPG icon in a fresh isolated workspace. No prior game outputs were reused.
- Tahoe: Intel x86_64, macOS Tahoe 26.7.1, Xcode 26.6 (17F113), iOS SDK 26.5, .NET 10.0.402, Python 3.13.18.
- Source-built translator is framework-dependent portable IL and reports source SHA `c31111ab3918d09b`. Managed assembly fingerprints are in `dm/gfx/tools/dmsh_chain.lock`.
- Upstream Metal pin remains 32023.921. This build used actual Metal 32023.883 only through official `--allow-other-metal`; both actual and pinned identities are recorded in the build log. Chain/header: `09b94713e34b`.
- Fresh compile produced all 11,625 iOS shader stages (0 cache hits); the packaged bundle contains 14,143 metallib files including generated variants. Executable rewrites and Xcode Release succeeded.
- IPA: `/Volumes/Media/Roms/iOS/Mario Rabbids - Kingdom Battle/MarioRabbidsKingdomBattle-v1.9.589692-Clean-Intel-Xcode26.6-unsigned.ipa` (5,095,625,689 bytes).
- SHA-256: `b860b76bf1819f1961697c481cda44d4942b3b70e336758013c9d2bb80c178cd`; sidecar is next to the IPA. ZIP CRC check passed. App bundle contains merged `romfs.img`, four `aoc/*.img` DLC images, and the fresh `b-09b94713e34b` shader set. No code-signature directory or provisioning profile is present; package is unsigned.
- Complete logs, tool/build outputs, and fresh shader inventory are retained under `/Users/kylepyne/nxnative-games/Mario Rabbids - Kingdom Battle/Clean-Tahoe-Xcode26.6-695c1f8/`.

## Next

- Install through PlumeImpactor and device-test startup/gameplay. Compilation and archive validity do not establish runtime compatibility.
- Previous IPAs, original NSPs, saves, and prior crash logs were preserved.
