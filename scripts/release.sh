#!/bin/zsh
# Builds a Developer ID signed Cone Player and a signed DMG in build/release.
#
#   scripts/release.sh              build, sign and verify (nothing leaves this Mac)
#   scripts/release.sh --notarize   also submit the DMG to Apple's notary service and staple it
#
# Notarizing uses the "ConePlayer" Keychain profile created with:
#   xcrun notarytool store-credentials "ConePlayer" --apple-id <apple-id> --team-id 2C39YHVFA2
set -euo pipefail
cd "$(dirname "$0")/.."

notarize=false
[[ "${1:-}" == "--notarize" ]] && notarize=true

version=$(awk -F'"' '/MARKETING_VERSION/ { print $2; exit }' project.yml)
out=build/release
archive=$out/ConePlayer.xcarchive
app=$out/export/ConePlayer.app
dmg=$out/ConePlayer-$version.dmg
identity="Developer ID Application: Jeff Evertse (2C39YHVFA2)"

# Clear only this version's build products; DMGs of earlier versions are kept.
rm -rf "$archive" "$out/export" "$out/dmg" "$dmg"
mkdir -p "$out"

echo "==> Generating project"
xcodegen generate --quiet

echo "==> Archiving Release $version"
xcodebuild archive -quiet \
  -project ConePlayer.xcodeproj -scheme ConePlayer -configuration Release \
  -archivePath "$archive" -destination 'generic/platform=macOS' \
  -clonedSourcePackagesDirPath build/SourcePackages -allowProvisioningUpdates

echo "==> Exporting with Developer ID"
xcodebuild -exportArchive -quiet \
  -archivePath "$archive" -exportPath "$out/export" \
  -exportOptionsPlist scripts/ExportOptions.plist -allowProvisioningUpdates

echo "==> Checking the version"
app_version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")
build_number=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$app/Contents/Info.plist")
if [[ "$app_version" != "$version" ]]; then
  echo "error: the app says version $app_version but project.yml says $version" >&2
  exit 1
fi
echo "Version $app_version (build $build_number)"

echo "==> Verifying the app's signature"
codesign --verify --deep --strict --verbose=2 "$app"
codesign -dv --verbose=2 "$app" 2>&1 | grep -E "^(Authority=Developer ID Application|TeamIdentifier|Runtime Version|Timestamp)"
if codesign -d --entitlements - "$app" 2>/dev/null | grep -q "get-task-allow"; then
  echo "error: release build still has get-task-allow" >&2
  exit 1
fi

echo "==> Building the DMG"
staging=$out/dmg
mkdir -p "$staging"
cp -R "$app" "$staging/Cone Player.app"
ln -s /Applications "$staging/Applications"
hdiutil create -quiet -volname "Cone Player" -srcfolder "$staging" -ov -format UDZO "$dmg"
codesign --sign "$identity" --timestamp "$dmg"
codesign --verify --verbose=2 "$dmg"

if $notarize; then
  echo "==> Submitting to Apple's notary service (this can take a few minutes)"
  xcrun notarytool submit "$dmg" --keychain-profile "ConePlayer" --wait
  echo "==> Stapling the notarization ticket"
  xcrun stapler staple "$dmg"
  xcrun stapler validate "$dmg"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
else
  echo "==> Not notarized. Gatekeeper's verdict until then:"
  spctl --assess --type execute --verbose=2 "$app" 2>&1 || true
fi

echo "==> Done: $dmg"
