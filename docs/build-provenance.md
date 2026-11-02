# Integration builds and provenance

## Source baseline

- Upstream: `seedds/nxnative`, pinned initially to `6a0687721a1da9a6a0273c6ce2f11eedcf4af445` (includes nested audio-renderer fix `6de59702ec`).
- Intel change: commit `9a68a3e`; only `dm/gfx/tools/dmsh_xlate_bin/dmsh_xlate` changes. SHA-256: `000ac0baf0e4aa352a19365bd2196bc58e1330114278bb2badeb2de6fa2019bd`.
- The universal launcher comes from the existing verified Intel-compatible build. Its DLLs and source fingerprint must match upstream's lock. Do not rebuild or replace the translator DLLs, rewrite the lock, or copy old generated game outputs.
- `validated/metroid-dread-ios-6a068772` records the source tree reconstructed from the successful device-tested build. Its original detached upstream checkout plus local launcher change, exact command and tool fingerprints remain in that IPA's provenance report.

## Reproduce an unsigned IPA

Use the existing `tahoe` SSH alias. Run developer commands through `zsh -lc` so the configured tool PATH is loaded. Check `df -h` first. Keep the original checkout and successful Metroid artifacts untouched. Create a separate checkout of the recorded integration commit and a new folder under `/Users/kylepyne/nxnative-games/` for each validation. Configure Git locally for IndecentDad.

The official script puts `<title-id>_build` beside its inputs. Put symlinks to the original base/update NSPs in the new folder, with title ID and version in their names, rather than copying generated outputs. Preserve inputs, keys and saves. Use an existing complete Python environment; game build artifacts must be new.

```sh
python3 scripts/build_ipa_from_nsp.py <new-input-folder> \
  -k <existing-prod.keys> -p <registered-update-version> \
  --platform ios --no-show-fps --progress lines -o <new-output.ipa>
```

Celeste uses title `01002B30028F6000`, update `v589824` / 1.4.1.1 (the game itself shows 1.4.1.0). Its registered modules are `main=9382989af9636a1e02aeb3693094e87d` and `sdk=8618895246b420329b77746b960a66ab`. Dread uses `010093801237C000`, `v327680` / 2.1.0.

Run with a sanitized environment: keep login PATH, prepend the selected Python environment, and retain only standard HOME/USER/LOGNAME/SHELL/TMPDIR/language values plus a recorded job limit. Do not inherit `DM_*`, `XLATE*`, `PATCHED`, `ROMFS`, `MSL_IOS`, `GAME`, `WORK`, SDK/compiler flags or diagnostic overrides. Do not supply `--env-file`, `--allow-damaged` or `--provisional`. Use upstream's defaults for game/runtime behavior. `--no-show-fps` disables the optional overlay only.

The Tahoe toolchain is x86_64 macOS 26.7.1, Xcode 26.6 (17F113), .NET 10. Metal 32023.883 and spirv-cross fingerprint `42ee93372e51d0ee` differ from the maintainer's lock; upstream's official `own_compilers.py` supports this and records the differences without changing the shader-chain lock. Record actual versions each time.

## Required artifact record

Keep alongside every IPA: exact upstream/integration SHA and custom commits; clean Git state; invocation and sanitized environment; original input names, sizes and SHA-256; extracted module build IDs; Python packages, Xcode/.NET/Metal and translator fingerprints; complete build log/exit status; rewrite source stamps and gate counts; shader chain/input stamps and generated-table headers; IPA size and SHA-256. Never record key contents or tokens.

Before delivery verify embedded ARM64 code sections and packaged rewriter tables against that build's fresh outputs, and shader stamps/tables against the compiled host's chain. Verify no bundled `env.txt`, provisioning profile or signature, and that custom functionality matches the declared source (Intel-only controls exclude Save Sync; sync candidates include its compiled bridge). Verify the copied NAS IPA checksum. Preserve the manifest and log; do not claim gameplay from successful packaging. Device `Documents/env.txt` and launcher preferences persist independently of the IPA and should be checked before device validation without deleting saves.

## Updating upstream

1. Fetch `upstream` and `origin`; inspect every relevant worktree and back up stable refs before moving them. Verify remotes and IndecentDad identity.
2. Update `main` from `upstream/main`, retaining only required, reviewed custom functionality. Validate the source changes and preserve the last known-working artifacts.
3. Create a temporary `feature/*` or `fix/*` branch from `windows/main`, merge the updated `main`, and resolve shared-code conflicts without dropping Windows build tools, GUI, shader compilation, staging, caching, split builds or packaging. Validate on the physical Windows checkout before advancing `windows/main`.
4. Record exact source and artifact provenance. Create immutable annotated tags for device-validated checkpoints. Retire temporary branches after merge; retire `integration` only once its required changes are safely present in both stable branches and the Windows validation is complete.

Do not force-push, delete remote branches or rewrite published history without a separate review and explicit authorization. Local consolidation does not authorize remote writes.

Eden Save Folder Sync passed the device-validation gate for both Metroid Dread and Celeste. The candidate manifests identify source commit `a51aad6e0ae2fef570a94c05e5291fc0f3b5105e`; their recorded IPA SHA-256 values match the preserved files. The immutable integration checkpoint is `validated/save-folder-sync-v1`. Continue follow-up work on `fix/save-sync-polish` without rebuilding or replacing those confirmed IPAs unless requested.
