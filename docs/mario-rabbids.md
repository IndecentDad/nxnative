# Mario + Rabbids Kingdom Battle: experimental iOS port

Profile: `010067300059A000`; SDK 4.4.0; Snowdrop/NVN. Device gameplay has not
been verified. The supplied update is named v1.9.0, but its NACP display version
is `1.9.589692` and its CNMT version is `589824`.

| Content | Title ID | CNMT version |
|---|---|---|
| Base | 010067300059A000 | 0 |
| Update | 010067300059A800 | 589824 |
| Battle Pixel Pack | 010067300059B001 | 0 |
| Steampunk Pack | 010067300059B002 | 0 |
| Ultra Challenge Pack | 010067300059B003 | 65536 |
| Donkey Kong Adventure | 010067300059B004 | 131072 |

All add-ons declare the same application ID. Extraction uses the merged base
and update, with separate read-only DLC mounts at indices 1–4. Source NSPs are
preserved. The original archives are packed as game resources; offline shader
extraction does not replace or modify them.

## Build and validation

Use the existing Tahoe workflow in [BUILDING_ON_TAHOE.md](../BUILDING_ON_TAHOE.md)
from the isolated `/Users/kylepyne/nxnative-mario-rabbids` worktree. The retained
Python is `/Users/kylepyne/nxnative-pr-5-x86-archive-20261022/.venv/bin/python3`.
Add `/Users/kylepyne/nxnative-tools/bin` and `/usr/local/share/dotnet` to PATH.
The game-local `010067300059A000_build/python` directory supplies zstandard
through PYTHONPATH. No system environment changes are required.

The regular NSP builder accepts `--no-glslc-capture` for this Intel build host.
It packages the offline cache shaders and preserves the ARM64 GLSLC module;
runtime-only variants remain unverified because Intel cannot execute the ARM64
Mac host for capture. The full indexed scan finds 11,368 unique shaders:
10,382 vertex, 732 pixel, and 254 compute, with 10,382 separable-program pairs.

The NSO rewrite, all 11,368 Mac/iOS shader builds, unsigned Xcode Release build,
and ZIP64 IPA packaging have passed. There are no undecoded resource bindings
or unfillable driver reads; the final guard table conservatively protects 34
shaders. `DM_BUILD_ONLY=1`
can compile the app while shaders are building; the final shader stage must
regenerate `c1_full.tsv` before normal IPA packaging. The app uses the supplied
JPG, Documents-based saves, and the existing full controller layout. PlumeImpactor
supplies signing and memory entitlements; no external entitlement file is needed.

The 4,905,957,755-byte `MarioRabbidsKingdomBattle-v1.9.589692-NXNative-unsigned.ipa`
passed full ZIP CRC and ZIP64 checks, all 4,004 RomFS and 50 DLC file-size/name
checks, shader-library checks, icon metadata checks, and unsigned ARM64 Mach-O
validation. It is delivered under `/volume1/Media/Roms/iOS/Mario Rabbids - Kingdom Battle/`;
the NAS copy matches Tahoe's SHA256
`97e718f03856fe2d3cbef8a86e8c548caa1e97f43e8209be50490553c92a594f`.
Retrieve `Documents/log.txt` for subsequent device compatibility work.

## General fixes to consider separately for upstream

- Read title IDs and versions from CNMT metadata with `nx_extract --metadata`.
- Read Snowdrop WEST v22 indices and named NVN shader caches, including sparse
  DLC archive IDs, raw/zstd resources, and inner zlib envelopes. The format was
  cross-checked against [rouge_sdf](https://github.com/GoldFarmer/rouge_sdf/blob/master/main.cpp)
  and verified on the supplied archives. Later versions are explicitly rejected.
- Recognize a long-lived copied index in an offset jump table. Rabbids' GLSLC
  table at `subsdk0+0x7340b8` has five targets; a real-function check verifies
  them and rejects a changed source register. Existing short-form rules remain.
- Include DLC shader roots in the scan and cache fingerprint.
- Permit explicitly deferred GLSLC capture and build-only Release validation.

Tahoe's measured `dmsh_chain.lock` is environment-specific and should be reviewed
separately from those fixes. No game-specific instruction cuts or shared runtime
refactoring were introduced. Runtime memory, rendering, audio, saves, input, and
DLC access still require device testing.
