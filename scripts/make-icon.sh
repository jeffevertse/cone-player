#!/bin/zsh
# Renders design/icon/*.svg into the app's asset catalog. Run after editing the SVGs.
#   AppIcon  - every macOS app icon size, from ConePlayerIcon.svg
#   ConeMark - the cone alone as a vector PDF, for the in-app mark
# Needs rsvg-convert (brew install librsvg).
set -euo pipefail
cd "$(dirname "$0")/.."

catalog=ConePlayer/Resources/Assets.xcassets
icon=$catalog/AppIcon.appiconset
mark=$catalog/ConeMark.imageset
rm -rf "$icon" "$mark"
mkdir -p "$icon" "$mark"

cat > "$catalog/Contents.json" <<'JSON'
{ "info" : { "author" : "xcode", "version" : 1 } }
JSON

entries=()
for size in 16 32 128 256 512; do
  for scale in 1 2; do
    px=$((size * scale))
    suffix=""
    if [[ $scale == 2 ]]; then suffix="@2x"; fi
    name="icon_${size}x${size}${suffix}.png"
    rsvg-convert -w $px -h $px design/icon/ConePlayerIcon.svg -o "$icon/$name"
    entries+=("    { \"idiom\" : \"mac\", \"size\" : \"${size}x${size}\", \"scale\" : \"${scale}x\", \"filename\" : \"$name\" }")
  done
done
{
  echo '{'
  echo '  "images" : ['
  print -l -- "${(j:,\n:)entries}"
  echo '  ],'
  echo '  "info" : { "author" : "xcode", "version" : 1 }'
  echo '}'
} > "$icon/Contents.json"

rsvg-convert -f pdf design/icon/ConeMark.svg -o "$mark/ConeMark.pdf"
cat > "$mark/Contents.json" <<'JSON'
{
  "images" : [ { "idiom" : "universal", "filename" : "ConeMark.pdf" } ],
  "info" : { "author" : "xcode", "version" : 1 },
  "properties" : { "preserves-vector-representation" : true }
}
JSON

echo "Updated $icon and $mark"
