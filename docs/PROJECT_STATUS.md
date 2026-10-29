# NXNative Project Status

## Mario + Rabbids Kingdom Battle — COMPLETE

- Successful clean Intel Tahoe IPA build used source commit `3be93c03c7ec19139d53712509e3d4035f66122c` on `game/mario-rabbids-kingdom-battle`. The checkout was clean after that source commit; its translator binaries and shader-chain changes are committed. Annotated validation tag: `rabbids-clean-intel-xcode26.6-2026-10-28`.
- IPA: `/Volumes/Media/Roms/iOS/Mario Rabbids - Kingdom Battle/MarioRabbidsKingdomBattle-v1.9.589692-Clean-Intel-Xcode26.6-unsigned.ipa` (5,095,625,689 bytes).
- SHA-256: `b860b76bf1819f1961697c481cda44d4942b3b70e336758013c9d2bb80c178cd`; checksum sidecar is beside the IPA. The archive CRC check and independent checksum verification passed.
- Build source: original base game, v1.9.0 update, all four DLC NSPs, and JPG icon. The bundle contains merged `romfs.img`, four DLC images, and the fresh shader chain. No old generated game outputs were reused.
- Toolchain: Intel x86_64 Tahoe 26.7.1; Xcode 26.6 / build 17F113; iOS SDK 26.5; .NET 10.0.402; Python 3.13.18. Source-built portable managed translator reports source SHA `c31111ab3918d09b`; chain/header is `09b94713e34b`.
- `dmsh_chain.lock` retains upstream Metal 32023.921. The successful build used actual Metal 32023.883 only with official `--allow-other-metal`; both identities are in the retained build log. All 11,625 fresh iOS shader stages compiled with zero cache hits; 14,143 metallib files including variants are packaged. Xcode Release succeeded.
- Archive inspection confirms an unsigned app without a provisioning profile. The app executable includes the Save Folder Sync section label; source has the status/conflict UI and no Sync Now control or legacy iCloud path. This is package/source inspection, not a sync runtime test.
- Runtime/device tests passed: none recorded. Launch progression, first rendered frame, gameplay, DLC activation, PlumeImpactor installation, and automatic/conflict Save Folder Sync behavior remain untested.
- Complete build logs, shader inventory, and generated build records remain under `/Users/kylepyne/nxnative-games/Mario Rabbids - Kingdom Battle/Clean-Tahoe-Xcode26.6-695c1f8/`. Original NSPs, saves, previous IPAs, and crash logs were preserved.

## Integration validation — candidate only

- Isolated worktree/branch: `/Users/kylepyne/nxnative-integration-validation`, `integration-validation/rabbids-clean-build`. Base `integration` was `57e0837a7ac8efd09ac49692627c6fa7890b625a`; candidate merge checkpoint is `b4b69bb574360eed5926245d533b5cd8f8717b98`. The simulated merge had no conflicts. No changes were made to `integration` or `main`, and no regression tests were run on the candidate.
- The Rabbids branch is 187 commits ahead of integration and changes 745 files (about 593k insertions / 2.9k deletions), including a broad upstream update through `201dfd1280684e9d3ceac8b644236fdac11b6cc2`. Do not fast-forward integration until the checklist below passes.
- Direct profile changes for Celeste, Metroid Dread, and Echoes of Wisdom are documentation-only (2, 21, and 5 lines respectively); their game profile data is unchanged. Shared host, NVN/graphics, shader, extraction, and iOS launcher changes still require regression coverage for all three.
- Save Folder Sync's Objective-C sync core is unchanged relative to integration. The candidate adds the SwiftUI status/conflict section and changes launcher/settings wiring. Test existing sync state migration, automatic sync, background/resume, conflicts, and resolution before promoting it.
- Translator DLLs are portable managed IL and ran on Intel Tahoe, but not yet on Windows or Apple Silicon in this build. Keep the new translator fingerprints isolated until cross-host chain checks and representative shader outputs pass. Keep Metal 32023.921 as the shared pin; use `--allow-other-metal` only for explicitly validated alternate compiler builds.

### Regression checklist before integration promotion

- Run upstream Python, host, shader, iOS packaging, and profile checks on the validation branch; inspect any failures against the old integration baseline.
- Build and smoke-test Celeste, Metroid Dread, and Echoes of Wisdom; check launch, rendering, audio, input, save loading, memory/address regions, and shader cache behavior.
- Exercise Save Folder Sync migration, auto-sync, app suspend/resume, status reporting, conflict detection/resolution, and confirm no Sync Now or legacy iCloud path returns.
- Verify translator `--source-sha` and chain checks on Intel macOS, Apple Silicon macOS, and Windows .NET; compile representative shaders on each supported host. Confirm default Metal pin validation and the explicit alternate-Metal override separately.
- Re-run unsigned IPA structure/integrity checks and verify per-game content before any merge to integration.
