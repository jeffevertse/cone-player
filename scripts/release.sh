#!/bin/zsh
# Builds a Developer ID signed Cone Player and a signed DMG in build/release.
#
#   scripts/release.sh              build, sign and verify (nothing leaves this Mac)
#   scripts/release.sh --notarize   also submit the DMG to Apple's notary service and staple it
#   scripts/release.sh --publish    notarize, then publish it to the in-app update feed
#                                   (jeffevertse/cone-player-releases on GitHub Pages)
#
# Publishing signs the feed with the Sparkle EdDSA key stored in the login Keychain
# under the account "cone-player" (created once with Sparkle's generate_keys), and uses
# release-notes/<version>.html as the notes shown in the update window.
#
# Notarizing uses the "ConePlayer" Keychain profile created with:
#   xcrun notarytool store-credentials "ConePlayer" --apple-id <apple-id> --team-id 2C39YHVFA2
set -euo pipefail
cd "$(dirname "$0")/.."

notarize=false
publish=false
case "${1:-}" in
  --notarize) notarize=true ;;
  --publish) notarize=true; publish=true ;;
esac

version=$(awk -F'"' '/MARKETING_VERSION/ { print $2; exit }' project.yml)
out=build/release
archive=$out/ConePlayer.xcarchive
app=$out/export/ConePlayer.app
dmg=$out/ConePlayer-$version.dmg
identity="Developer ID Application: Jeff Evertse (2C39YHVFA2)"
sparkle_version=2.9.4
feed_repo=jeffevertse/cone-player-releases
feed_base=https://jeffevertse.github.io/cone-player-releases
notes=release-notes/$version.html

if $publish && [[ ! -f "$notes" ]]; then
  echo "error: write the update notes in $notes first" >&2
  exit 1
fi

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
# Give hdiutil an explicit size: when it estimates one from the folder it can guess too
# small and fail with "device full". It can also fail with "Resource busy", so retry.
size_mb=$(( $(du -sm "$staging" | cut -f1) * 13 / 10 + 20 ))
for attempt in 1 2 3; do
  if hdiutil create -quiet -volname "Cone Player" -srcfolder "$staging" -size "${size_mb}m" -ov -format UDZO "$dmg"; then
    break
  elif [[ $attempt == 3 ]]; then
    echo "error: couldn't create the DMG" >&2
    exit 1
  fi
  echo "hdiutil failed (attempt $attempt), retrying…"
  sleep 3
done
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

if $publish; then
  echo "==> Publishing to the update feed"
  tools=build/sparkle/bin
  if [[ ! -x $tools/generate_appcast ]]; then
    mkdir -p build/sparkle
    curl -sfL -o build/sparkle/Sparkle.tar.xz \
      "https://github.com/sparkle-project/Sparkle/releases/download/$sparkle_version/Sparkle-$sparkle_version.tar.xz"
    tar -xf build/sparkle/Sparkle.tar.xz -C build/sparkle ./bin/generate_appcast ./bin/sign_update ./bin/generate_keys
  fi

  pages=build/pages-checkout
  rm -rf "$pages"
  gh repo clone "$feed_repo" "$pages" -- --quiet
  mkdir -p "$pages/releases"
  cp "$dmg" "$pages/releases/ConePlayer-$version.dmg"
  cp "$notes" "$pages/releases/ConePlayer-$version.html"

  # Signs each DMG with the Keychain key and writes appcast.xml. Absolute download
  # URLs, and no deltas (they'd need publishing too).
  $tools/generate_appcast --account cone-player \
    --download-url-prefix "$feed_base/releases/" \
    --embed-release-notes --maximum-deltas 0 \
    "$pages/releases"
  mv "$pages/releases/appcast.xml" "$pages/appcast.xml"

  # Stage everything generate_appcast touched, including files it moved.
  git -C "$pages" add -A
  git -C "$pages" commit -q -m "Cone Player $version"
  git -C "$pages" push -q

  echo "==> Waiting for the feed to show $version"
  for attempt in {1..30}; do
    if curl -sf "$feed_base/appcast.xml?$(date +%s)" | grep -q "<sparkle:shortVersionString>$version</sparkle:shortVersionString>"; then
      echo "Feed is live: $feed_base/appcast.xml"
      break
    elif [[ $attempt == 30 ]]; then
      echo "warning: the feed doesn't show $version yet; GitHub Pages may still be deploying" >&2
    fi
    sleep 10
  done
fi

echo "==> Done: $dmg"
