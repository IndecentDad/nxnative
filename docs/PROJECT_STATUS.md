# NXNative Project Status

## Shared integration baseline

- Source/build baseline for this Rabbids build: `1c592426bf22fb8caeff32076ec25ed1afdde27f`, the remote `origin/integration` merge of the upstream main mirror. The local `integration` checkout is behind this remote ref; this game branch is based on the remote integration commit. Fork `main` was not modified.
- Eden-compatible Save Folder Sync has folder selection, status/details/conflict handling, and bridge initialization. The launcher has no manual Sync Now button; save sync uses the selected folder and no legacy iCloud save path.
- Local functionality beyond the upstream mirror: Eden-compatible Save Folder Sync module/UI/bridge; Echoes 1.1.0 profile and validated shader data; portable AnyCPU translator build fix. These are candidates for upstream contribution where generally applicable. No game-specific runtime behavior was changed to add Save Sync. Upstream Intel launcher support from `1822616` remains; no launcher-only change was reintroduced by the Echo merge.

## Intel translator reproducibility

- Publish managed IL for AnyCPU with no RID, `PublishReadyToRun=false`, and `UseAppHost=false`; Tahoe x86_64 cannot load an ARM64 ReadyToRun image. Keep the checked-in `dmsh_xlate` launcher universal (arm64 + x86_64).
- Reproduce: `dotnet publish dm/gfx/tools/dmsh_xlate/dmsh_xlate.csproj -c Release -p:PublishReadyToRun=false -p:UseAppHost=false -o /tmp/nxnative-dmsh-xlate`, then `dotnet /tmp/nxnative-dmsh-xlate/dmsh_xlate.dll --source-sha`. Copy managed outputs only; verify launcher architecture, embedded source hash and translator DLL fingerprints against `dmsh_chain.lock` before builds.
- Translator source fingerprint `e6b5163bbebc6b67`; chain `60ce84a81e3c`. Checked-in translator DLL hashes match the lock. Tahoe local SPIRV-Cross (`42ee93372e51d0ee`) and Metal (`32023.883`) differ from pinned versions; official `own_compilers.py` accepts those local compiler differences while keeping translator integrity checks strict. Do not update the lock/header to silence local compiler notices.

## Validated builds

- Echoes of Wisdom 1.1.0, update `v196608`, built from baseline above, bundle `org.nxnative.01008cf01baac000`, 9,858/9,858 shaders and 14,159 metallibs, Xcode Release unsigned, 135 source files compiled. IPA: `/volume1/Media/Roms/iOS/Echoes of Wisdom/Build v1.1.0/Echoes-of-Wisdom-v1.1.0.ipa`; 8,414,216,443 bytes; SHA-256 `4ea74679bc334abb869d8f70fef7ef2f33e50d919f8b45d77b9470bd238cf76b`.
- Celeste update `v589824` (profile 1.4.1.1; app metadata 1.4.1), same baseline and translator, bundle `org.nxnative.01002b30028f6000`, 26/26 shaders and 38 metallibs, Xcode Release unsigned, 135 source files compiled. IPA: `/volume1/Media/Roms/iOS/Celeste/Build integration-2694c28/Celeste-1.4.1.1-integration-2694c28.ipa`; 924,915,261 bytes; SHA-256 `ff8500309f931f67974dc070ff93f0cd7b62d1db3689b4fc9203a1b33d1a344f`.
- Both IPAs have intact ZIPs, expected bundle metadata, Save Sync resources/code, and no legacy iCloud messages or `env.txt`. Increased Memory Limit entitlement must be applied by signing/install tooling. Echoes rebuilt IPA and Celeste regression have not been device-tested; Save Folder Sync provider bookmark/sync behavior still needs device validation. Two Echoes shaders remain flagged not proven bounded.

## Mario + Rabbids Kingdom Battle - Windows Metal build (packaged)

- Branch: `game/mario-rabbids-kingdom-battle`, based on integration `1c592426bf22fb8caeff32076ec25ed1afdde27f`.
- Build/workflow commit: `73541146`. Push is pending GitHub authentication: no HTTPS credential is configured, and SSH host-key verification for github.com fails. Do not bypass host-key verification; push this branch after trusted GitHub access is restored.
- Windows results validate: 16,797 unique MSL sources, 24,117 unique library keys, 16,797 successful libraries/receipts, exact iOS 18 flags, matching source/reflection hashes, one Metal Developer Tools 6.2 compiler identity, zero failures.
- All 24,117 libraries and reflection metadata were imported into a separate Windows-only build directory. The Tahoe fallback outputs remain untouched. c1/cb safety tables were generated from existing MSL/reflection metadata; no Tahoe Metal shader compilation ran.
- Xcode 26.6 Release compiled 180 files. The package used the base game, v1.9.0 update, four DLCs, extracted JPG icon, Eden-compatible Save Folder Sync, and the empty documented PSO prewarm manifest.
- IPA: `/volume1/Media/Roms/iOS/Mario Rabbids - Kingdom Battle/MarioRabbidsKingdomBattle-v1.9.589692-Windows-Metal-6.2-unsigned.ipa`; 5,063,928,124 bytes; SHA-256 `e6a466b5a02df9faa047c05774b29fe0c87da0f86313107d66e6f24965c8c87e`. ZIP integrity passed; no signing artifacts. Packaged shader libraries: 11,368 base and 2,367 vertex-shadow variants. The packager omits 10,382 `_bp` libraries because no PSO archive is included.
- Warnings: runtime GLSLC capture was disabled on Intel Tahoe, so runtime-only shader coverage is unverified; no PSO archive/prewarm was built. The IPA is unsigned and ready for PlumeImpactor. Device installation/gameplay and Metal runtime loading remain untested.

## Verification and next steps

- 19/19 existing Save Sync contract/filesystem tests passed (filesystem tests run via a temporary stdlib compatibility harness because pytest is absent). Relevant stdlib unittest source/profile/translator suite: 47 passed, 4 expected skips; one pytest-only module is not discoverable by unittest. Both official top-level IPA workflows compiled successfully.
- Preserve validated extraction, shader and Xcode caches for reuse. Removed superseded Echoes IPA and stale Echo build logs after replacement validation; originals, NSP/XCI inputs, keys, saves and Celeste runtime files remain intact.
- Next: device-test the validated IPAs, verify Save Folder Sync with a Files provider and conflict cases, then consider upstreaming general Save Sync and translator fixes. Push the Rabbids branch after trusted IndecentDad access is restored; do not merge it into `main` or `integration` before validation.

## Mario + Rabbids startup memory fix (Oct 27, 2026)

- Root cause: main build `3b39e0c06b8841f1baf0ea4d54286bfe` initializes three 4 GiB Snowdrop pools, requests one unchecked 12 GiB address region, then writes to `0x20000ffff` after the reservation fails. SDK 4.4.0’s 1 GiB region alignment cannot place a contiguous 3 GiB request inside the 4.375 GiB alias after its 1 GiB node area and game metadata.
- Applied title-specific cuts: three equal 1 GiB pools, 3 GiB combined request, and a 16,384-page limit for the 64 KiB allocator. Kept the per-class layout equal; did not copy Sparks of Hope’s 2/0.5/0.5 GiB split. SDK build `9de92bad67c4150268943ab4843ace65` now aligns large regions to 32 MiB, placing the 3 GiB range at about alias+1.03125 GiB and ending at alias+4.03125 GiB. Existing node area and allocator boundaries remain intact.
- Added build-ID and original-byte-bound SDK/game patches, allocation success/failure OBS gates, and `DM_SVC=1` logs for reservation results, addresses, `GetInfo`, and physical commits. The patch tables in `patched_v589824` confirm all expected original and replacement words.
- Fresh Synology-local official Windows verifier pass: 16,797/16,797 sources, 24,117/24,117 keys, Windows Metal Developer Tools 6.2, iOS 18 target, NXNative flags `-mios-version-min=18.0 -fmetal-math-mode=relaxed -fpreserve-invariance`, zero failures. Tahoe Metal compilation was skipped.
- Reused extracted game, four DLCs, executable rewrite, and 11,368-shader split. Xcode Release succeeded (52 files compiled). Unsigned IPA CRC and structure checks passed; it contains `DM_SVC=1`, AOC indices 1–4, 11,368 base libraries, 2,367 vertex-shadow libraries, and 11,368 reflection files. The current no-pull packaging rule omits `_bp` pull libraries.
- Diagnostic IPA: `/volume1/Media/Roms/iOS/Mario Rabbids - Kingdom Battle/MarioRabbidsKingdomBattle-v1.9.589692-Startup-Memory-Diagnostic-unsigned.ipa` (5,063,929,501 bytes). No device runtime test yet; next verify allocator success and mapped pages in the device log, then whether startup advances to a rendered frame.
