# NXNative Project Status

## Shared integration baseline

- Source/build baseline: `2694c280d563ea573c705b939f54c1ccd34f9e95` (merge of `game/echoes-of-wisdom` into `integration`; parents `fe662e1` and `e358448`). Echo history includes portable translator fix `af582053` and successful Echo build record `e358448`. Fork `main` was not modified.
- Echoes merge preserved existing integration Save Folder Sync and Intel support. Launcher keeps upstream grouped settings, reset-to-tested-defaults and navigation, with Save Sync entry, folder selection, status/details/conflict handling, manual **Sync Now**, and bridge initialization. Save paths are local `Documents/save` and `<Selected Folder>/<TitleID>/` directly.
- Local functionality beyond the upstream mirror: Eden-compatible Save Folder Sync module/UI/bridge; Echoes 1.1.0 profile and validated shader data; portable AnyCPU translator build fix. These are candidates for upstream contribution where generally applicable. No game-specific runtime behavior was changed to add Save Sync. Upstream Intel launcher support from `1822616` remains; no launcher-only change was reintroduced by the Echo merge.

## Intel translator reproducibility

- Publish managed IL for AnyCPU with no RID, `PublishReadyToRun=false`, and `UseAppHost=false`; Tahoe x86_64 cannot load an ARM64 ReadyToRun image. Keep the checked-in `dmsh_xlate` launcher universal (arm64 + x86_64).
- Reproduce: `dotnet publish dm/gfx/tools/dmsh_xlate/dmsh_xlate.csproj -c Release -p:PublishReadyToRun=false -p:UseAppHost=false -o /tmp/nxnative-dmsh-xlate`, then `dotnet /tmp/nxnative-dmsh-xlate/dmsh_xlate.dll --source-sha`. Copy managed outputs only; verify launcher architecture, embedded source hash and translator DLL fingerprints against `dmsh_chain.lock` before builds.
- Translator source fingerprint `e6b5163bbebc6b67`; chain `60ce84a81e3c`. Checked-in translator DLL hashes match the lock. Tahoe local SPIRV-Cross (`42ee93372e51d0ee`) and Metal (`32023.883`) differ from pinned versions; official `own_compilers.py` accepts those local compiler differences while keeping translator integrity checks strict. Do not update the lock/header to silence local compiler notices.

## Validated builds

- Echoes of Wisdom 1.1.0, update `v196608`, built from baseline above, bundle `org.nxnative.01008cf01baac000`, 9,858/9,858 shaders and 14,159 metallibs, Xcode Release unsigned, 135 source files compiled. IPA: `/volume1/Media/Roms/iOS/Echoes of Wisdom/Build v1.1.0/Echoes-of-Wisdom-v1.1.0.ipa`; 8,414,216,443 bytes; SHA-256 `4ea74679bc334abb869d8f70fef7ef2f33e50d919f8b45d77b9470bd238cf76b`.
- Celeste update `v589824` (profile 1.4.1.1; app metadata 1.4.1), same baseline and translator, bundle `org.nxnative.01002b30028f6000`, 26/26 shaders and 38 metallibs, Xcode Release unsigned, 135 source files compiled. IPA: `/volume1/Media/Roms/iOS/Celeste/Build integration-2694c28/Celeste-1.4.1.1-integration-2694c28.ipa`; 924,915,261 bytes; SHA-256 `ff8500309f931f67974dc070ff93f0cd7b62d1db3689b4fc9203a1b33d1a344f`.
- Both IPAs have intact ZIPs, expected bundle metadata, Save Sync resources/code, and no legacy iCloud messages or `env.txt`. Increased Memory Limit entitlement must be applied by signing/install tooling. Echoes rebuilt IPA and Celeste regression have not been device-tested; Save Folder Sync provider bookmark/sync behavior still needs device validation. Two Echoes shaders remain flagged not proven bounded.

## Verification and next steps

- 19/19 existing Save Sync contract/filesystem tests passed (filesystem tests run via a temporary stdlib compatibility harness because pytest is absent). Relevant stdlib unittest source/profile/translator suite: 47 passed, 4 expected skips; one pytest-only module is not discoverable by unittest. Both official top-level IPA workflows compiled successfully.
- Preserve validated extraction, shader and Xcode caches for reuse. Removed superseded Echoes IPA and stale Echo build logs after replacement validation; originals, NSP/XCI inputs, keys, saves and Celeste runtime files remain intact.
- Install/test both IPAs on devices, verify Save Folder Sync using a Files provider and conflict cases, then consider upstreaming general Save Sync and translator fixes. Push `integration` only under the verified IndecentDad account; record any authentication blocker here.
