#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

build_output="$repo_root/BuildOutput"
swift build -c release --disable-sandbox
release_products="$(swift build -c release --disable-sandbox --show-bin-path)"
app_bundle="$build_output/MiniVocab.app"
dmg_path="$build_output/MiniVocab.dmg"
resource_bundle="$release_products/MiniVocab_MiniVocab.bundle"

test -x "$release_products/MiniVocab"
test -f "$resource_bundle/MiniVocab.icns"

rm -rf -- "$app_bundle" "$dmg_path"
mkdir -p "$app_bundle/Contents/MacOS" "$app_bundle/Contents/Resources"

cp "$release_products/MiniVocab" "$app_bundle/Contents/MacOS/MiniVocab"
cp -R "$resource_bundle"/. "$app_bundle/Contents/Resources/"
cp "$repo_root/Packaging/Info.plist" "$app_bundle/Contents/Info.plist"

codesign --deep --force --sign - "$app_bundle"
codesign --verify --deep --strict --verbose=2 "$app_bundle"

hdiutil create \
	-volname MiniVocab \
	-srcfolder "$app_bundle" \
	-ov \
	-format UDZO \
	"$dmg_path"

cp "$dmg_path" "$repo_root/MiniVocab.dmg"
echo "Packaged $repo_root/MiniVocab.dmg"
