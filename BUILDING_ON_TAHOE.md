# Building NXNative on Tahoe

Primary checkout: `/Users/kylepyne/nxnative`  
Current fork-main commit: `b0f117b`  
Build data and outputs stay outside Git under `/Users/kylepyne/nxnative-games/<Game>/`.

## One-time shell setup

Open Terminal or SSH as `kylepyne` (the Codex container is not required):

```sh
export NX=/Users/kylepyne/nxnative
export NXTOOLS=/Users/kylepyne/nxnative-tools/bin
export PATH="$NXTOOLS:/usr/local/share/dotnet:$PATH"
cd "$NX"
```

Tahoe has Xcode 26.6, `xcodegen` at `/Users/kylepyne/nxnative-tools/bin/xcodegen`, `/usr/local/share/dotnet/dotnet`, Python 3, `make`, `sips`, SPIRV-Cross, zstd, and the installed shader tools. Keep NSP/XCI files, keys, extracted RomFS/ExeFS, shader caches, patched modules, and IPAs under the game data directory, never in this repository.

## Update fork main

```sh
cd "$NX"
git fetch origin main
git switch main
git pull --ff-only origin main
git status --short
git rev-parse --short HEAD
```

The checkout includes Intel macOS launcher support, generated app icons, and shared iCloud save support (`dm/ios/Sources/DmSaveSync.m`).

## Build from NSP/XCI input

The supported front door is the NSP build script. Give it a directory containing the base game NSP and optional update/DLC NSP files; it extracts and reuses the work folder, shader cache, and patched modules on later runs:

```sh
GAME_DIR=/Users/kylepyne/nxnative-games/MyGame
python3 "$NX/scripts/build_ipa_from_nsp.py" "$GAME_DIR" \
  --keys /Users/kylepyne/keys/prod.keys \
  --keep-extracted --progress lines
```

The script accepts an XCI only when the installed `nx_extract` version supports that container; if it reports an unsupported input, dump the XCI to NSPs first and pass the directory containing those NSPs. Do not copy ROMs into the repository.

The normal output is next to the input work directory, usually:

`/Users/kylepyne/nxnative-games/<Game>/<display name>.ipa`

For an already extracted game, the lower-level command avoids extraction and shader regeneration:

```sh
GAME=010093801237C000
W=/Users/kylepyne/nxnative-games/MetroidDread/010093801237C000_build/ipa
GAME="$GAME" W="$W" PATCHED=/Users/kylepyne/nxnative-games/MetroidDread/010093801237C000_build/patched_v327680 \
  ROMFS=/Users/kylepyne/nxnative-games/MetroidDread/010093801237C000_build/extract/v327680/RomFS \
  MSL_IOS=/Users/kylepyne/nxnative-games/MetroidDread/010093801237C000_build/shader/ios \
  PATH="$NXTOOLS:$PATH" bash "$NX/dm/ios/tools/build_ipa.sh" \
  /Users/kylepyne/nxnative-games/MetroidDread/MetroidDread-new.ipa
```

The result is unsigned and is ready for PlumeImpactor after signing. The script creates the Xcode project, preserves the title-ID-derived bundle ID (`org.nxnative.<lowercase title ID>`), generates the app icon from the game artwork, and writes an adjacent entitlements plist for inspection.

## Optional iCloud signing configuration

Set these before the build when the Apple Developer setup is ready:

```sh
export DM_TEAM_ID=YOUR10CHARTEAM
export DM_ICLOUD_CONTAINER=iCloud.your.reverse.dns.shared.saves
export DM_BASE_ENTITLEMENTS=/path/to/memory-entitlements.plist
export DM_BUILD_VERSION=2.1.1
```

The generator carries forward increased-memory-limit and extended-virtual-addressing, adds CloudDocuments and both container identifier entitlements, and removes old app/team identity values so the final profile supplies the current identity. The Apple Developer portal must associate the shared container with every explicit game App ID and the regenerated profile. PlumeImpactor must sign with that profile while retaining the stable bundle ID and requested entitlements. Without this portal/profile setup, build locally without `DM_ICLOUD_CONTAINER`; local save export/import still works.

## Troubleshooting

- `xcodegen not found`: export `PATH="$NXTOOLS:$PATH"`.
- `dotnet` or `dmsh_xlate` not found: export `PATH="$NXTOOLS:/usr/local/share/dotnet:$PATH"`; verify `dm/gfx/tools/dmsh_chain.lock` matches the installed translator.
- Missing patched modules: rerun the NSP script for the same input directory; do not delete the existing work folder.
- Missing shader libraries: reuse the game’s `shader/ios` output when its chain lock matches; otherwise follow the shader-chain procedure in `AGENTS.md`.
- IPA installation fails: keep the title-ID bundle ID, sign with a profile containing the requested memory/iCloud entitlements, and inspect the adjacent `.entitlements.plist`.
- Runtime save problems: use the app’s Saves menu; retrieve `Documents/log.txt`, and do not replace `Documents/save` while the game is running.

Known-good Metroid Dread IPAs and assets remain under `/Users/kylepyne/nxnative-games/MetroidDread`; this setup does not rebuild them automatically.
