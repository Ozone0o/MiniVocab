# Releasing MiniVocab

MiniVocab is a Swift Package with a macOS executable target. Source control should contain source, tests, documentation, and required resources only. Keep the release staging directory and all generated artifacts outside the tracked source files (the existing `BuildOutput/` directory is ignored for local use).

## Checklist

1. Confirm the working tree is clean:

   ```bash
   git status
   ```

2. Run the test suite:

   ```bash
   swift test
   ```

3. Build the package in release configuration:

   ```bash
   swift build -c release
   ```

4. Open `Package.swift` in Xcode, select the `MiniVocab` scheme, and create the Release app bundle/archive using the current Xcode distribution workflow. Set the release version in the generated app metadata; do not add the generated `.app` or its debug symbols to the repository.

   The package scheme can also be built from the command line:

   ```bash
   xcodebuild -scheme MiniVocab \
     -destination 'platform=macOS' \
     -configuration Release \
     -derivedDataPath BuildOutput/DerivedData \
     build
   ```

   To assemble the app bundle with the checked-in icon and package a DMG in one step, run:

   ```bash
   ./scripts/package-dmg.sh
   ```

   The helper copies `Packaging/Info.plist`, includes `MiniVocab.icns`, signs the local build ad hoc, creates `BuildOutput/MiniVocab.dmg`, and refreshes the tracked `MiniVocab.dmg` download.

5. If a Developer ID certificate is available, sign the exported app bundle and verify it:

   ```bash
   codesign --deep --force --options runtime \
     --sign "Developer ID Application: YOUR NAME (TEAMID)" \
     BuildOutput/MiniVocab.app
   codesign --verify --deep --strict --verbose=2 BuildOutput/MiniVocab.app
   ```

6. Create the disk image in the ignored staging directory:

   ```bash
   hdiutil create \
     -volname MiniVocab \
     -srcfolder BuildOutput/MiniVocab.app \
     -ov \
     -format UDZO \
     BuildOutput/MiniVocab.dmg
   ```

7. If notarization is configured, submit the disk image with an existing keychain profile and staple the result:

   ```bash
   xcrun notarytool submit BuildOutput/MiniVocab.dmg \
     --keychain-profile "YOUR_NOTARY_PROFILE" \
     --wait
   xcrun stapler staple BuildOutput/MiniVocab.dmg
   ```

   Do not place Apple credentials, certificates, provisioning profiles, or keychain profiles in the repository.

8. Create a GitHub Release with a version tag and upload `BuildOutput/MiniVocab.dmg` as the release asset.

This document does not create releases, push tags, or perform notarization automatically. Confirm the exact signing and archive output before publishing each version.
