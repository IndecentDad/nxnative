#!/bin/bash
# Generate two small Xcode projects from the real shared template; no compilation or IPA.
set -euo pipefail
IOS=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
XCODEGEN=${XCODEGEN:-xcodegen}
for GAME in 010093801237C000 010015100B514000; do
  P="$TMP/$GAME"; mkdir -p "$P/Gen/dm" "$P/Gen/src" "$P/Gen/main" "$P/Gen/Assets.xcassets"
  cp "$IOS/project.yml" "$P/project.yml"
  cp -R "$IOS/Sources" "$P/Sources"
  touch "$P/Gen/embed.S" "$P/Gen/main/main.c" "$P/Gen/dm.xcconfig"
  export DM_GAME_TITLE_ID=$GAME DM_BUNDLE_ID=org.nxnative.$(echo "$GAME" | tr A-Z a-z)
  export DM_DISPLAY_NAME="Test $GAME" DM_APP_VERSION=1.0 DM_BUILD_VERSION=1.1 DM_APP_CATEGORY=public.app-category.games DM_TEAM_ID=ABCDE12345
  (cd "$P" && "$XCODEGEN" generate -q)
  python3 "$IOS/tools/configure_icloud.py" "$P/Sources/Info.plist" "$P/Gen/DmIOS.entitlements" \
    --title-id "$GAME" --container iCloud.org.nxnative.saves --team ABCDE12345
  python3 - "$P" "$GAME" <<'PY'
import pathlib, plistlib, sys
p, game = pathlib.Path(sys.argv[1]), sys.argv[2]
info = plistlib.loads((p / 'Sources/Info.plist').read_bytes())
ent = plistlib.loads((p / 'Gen/DmIOS.entitlements').read_bytes())
project = (p / 'DmIOS.xcodeproj/project.pbxproj').read_text()
assert info['DMTitleID'] == game
assert f'org.nxnative.{game.lower()}' in project, 'stable bundle ID missing'
assert 'DmSaveSync.m' in project, 'shared source missing'
assert 'Gen/DmIOS.entitlements' in project, 'entitlements setting missing'
assert ent['com.apple.developer.ubiquity-container-identifiers'] == ['iCloud.org.nxnative.saves']
assert info['NSUbiquitousContainers']['iCloud.org.nxnative.saves']['NSUbiquitousContainerIsDocumentScopePublic']
print(f'{game}: shared source, identity, iCloud Files folder and entitlements verified')
PY
done
