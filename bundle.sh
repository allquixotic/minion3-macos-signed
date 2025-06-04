#!/usr/bin/env bash
#
# Re-generate a **universal-style Minion.app** from scratch.
# – Drops any previous build
# – Bundles BOTH Apple-silicon *and* Intel JRE 11 (with JavaFX)
# – Copies Minion-jfx.jar *plus* its lib/ dependencies
# – Optionally signs and spits out a ready-to-ship DMG
#
# Prereqs already in the same directory as this script:
#   • Minion3.0.12-java.zip   → UNZIP beforehand →  Minion-jfx.jar  and  lib/
#   • jdk11.0.27-aarch64/     (BellSoft Liberica “Full”)
#     jdk11.0.27-amd64/       (ditto, Intel build)
#
set -euo pipefail

###########################  CONFIG  ##########################################
VER=3.0.12
APPNAME=Minion
BUILDROOT=${BUILDROOT:-"$HOME/dev/minion-build"}

# Already-unzipped JDK folders (rename here if you use newer builds)
JDK_ARM="jdk11.0.27-aarch64"
JDK_INTEL="jdk11.0.27-amd64"

# Set CODESIGN_ID to your “Developer ID Application: …” to auto-sign
# Example: "Developer ID Application: Your Name (TEAMID)"
CODESIGN_ID=${CODESIGN_ID:-""}
# Keychain profile name for notarytool (setup with `xcrun notarytool store-credentials`)
NOTARY_PROFILE="AC_NOTARY"
###############################################################################

APPDIR="$BUILDROOT/$APPNAME.app"
DMG_PATH="$BUILDROOT/$APPNAME-${VER}.dmg"
ENTITLEMENTS_FILE="$BUILDROOT/$APPNAME.entitlements"

echo "▶︎ Building $APPDIR …"

###########################  CLEAN & SKELETON  ################################
rm -rf "$APPDIR" "$DMG_PATH" # Clean up old DMG too
mkdir -p "$APPDIR/Contents/"{MacOS,Resources,PlugIns}

###########################  COPY RUNTIMES  ###################################
echo "▶︎ Copying JREs..."
cp -R "$JDK_ARM"   "$APPDIR/Contents/PlugIns/jre-arm"
cp -R "$JDK_INTEL" "$APPDIR/Contents/PlugIns/jre-intel"

echo "▶︎ Cleaning up non-essential files from JREs..."
# Remove man pages, docs, sample code, header files etc.
# to prevent codesign issues and reduce bundle size.
find "$APPDIR/Contents/PlugIns/jre-arm" "$APPDIR/Contents/PlugIns/jre-intel" \
    \( -name "man" -o -name "docs" -o -name "doc" -o -name "sample" \
       -o -name "demo" -o -name "include" -o -name "legal" \) \
    -type d -print0 | xargs -0 rm -rf

###########################  COPY APP FILES  ##################################
echo "▶︎ Copying application files..."
cp  Minion-jfx.jar             "$APPDIR/Contents/Resources/"
cp -R lib                      "$APPDIR/Contents/Resources/"

ICON_SRC="/Applications/Minion.app/Contents/Resources/Minion.icns"
if [[ -f "$ICON_SRC" ]]; then
  cp "$ICON_SRC" "$APPDIR/Contents/Resources/minion.icns"
else
  echo "ℹ︎ Icon source not found at $ICON_SRC, skipping icon copy."
fi

###########################  LAUNCHER STUB  ###################################
echo "▶︎ Creating launcher stub..."
cat >"$APPDIR/Contents/MacOS/Minion" <<"EOS"
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
CPU="$(uname -m)"   # arm64 or x86_64

# Ensure this path is correct relative to the executable
if [[ "$CPU" == "arm64" ]]; then
  JAVA_HOME="$DIR/../PlugIns/jre-arm"
else
  JAVA_HOME="$DIR/../PlugIns/jre-intel"
fi

exec "$JAVA_HOME/bin/java" \
  --add-opens=javafx.graphics/com.sun.javafx.css=ALL-UNNAMED \
  --add-opens=javafx.graphics/javafx.scene.image=ALL-UNNAMED \
  --add-opens=java.base/java.lang=ALL-UNNAMED \
  -jar "$DIR/../Resources/Minion-jfx.jar"
EOS
chmod +x "$APPDIR/Contents/MacOS/Minion"

###########################  INFO.PLIST  ######################################
echo "▶︎ Creating Info.plist..."
cat >"$APPDIR/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>        <string>${APPNAME}</string>
  <key>CFBundleDisplayName</key> <string>${APPNAME}</string>
  <key>CFBundleIdentifier</key>  <string>ggmods.minion</string>
  <key>CFBundleVersion</key>     <string>${VER}</string>
  <key>CFBundleShortVersionString</key><string>${VER}</string>
  <key>CFBundleExecutable</key>  <string>${APPNAME}</string>
  <key>CFBundleIconFile</key>    <string>minion</string>
  <key>LSMinimumSystemVersion</key><string>10.15</string> <!-- Or your target -->
  <key>LSArchitecturePriority</key>
  <array>
    <string>arm64</string>
    <string>x86_64</string>
  </array>
  <key>CFBundlePackageType</key> <string>APPL</string>
</dict>
</plist>
EOF

echo "✅ App bundle populated: $APPDIR"

###########################  (OPTIONAL) CODESIGN & NOTARIZE ##################
if [[ -n "$CODESIGN_ID" ]]; then
  echo "▶︎ Codesigning with identity: $CODESIGN_ID"

  echo "▶︎ Creating entitlements file: $ENTITLEMENTS_FILE"
  cat >"$ENTITLEMENTS_FILE" <<EOF_ENT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/> 
    <key>com.apple.security.network.client</key><true/>
</dict>
</plist>
EOF_ENT

  echo "▶︎ Setting write permissions for signing..."
  chmod -R u+w "$APPDIR"
  # If issues persist, you might need to remove immutable flags (less common for JDK copies)
  # echo "▶︎ Removing immutable flags (if any)..."
  # chflags -R nouchg "$APPDIR" || true # Allow failure if no files have flag

  echo "▶︎ Signing .app bundle..."
  codesign --deep --force --options runtime \
    --entitlements "$ENTITLEMENTS_FILE" \
    --timestamp \
    --sign "$CODESIGN_ID" "$APPDIR"
  echo "✅ Codesign (.app) complete."

  echo "▶︎ Verifying .app signature..."
  codesign --verify --verbose=4 "$APPDIR"
  echo "▶︎ Performing initial Gatekeeper assessment (rejection for 'Unnotarized Developer ID' is expected here)..."
  spctl --assess --type execute -v "$APPDIR" || true # Allow this command to "fail"

  echo "▶︎ Creating DMG with LZMA compression: $DMG_PATH"
  hdiutil create -volname "$APPNAME $VER" \
    -srcfolder "$APPDIR" \
    -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
    -format ULMO \
    -ov \
    "$DMG_PATH"  > /dev/null
  echo "✅ DMG created at $DMG_PATH (LZMA compressed)"

  echo "▶︎ Signing DMG..."
  codesign --force \
    --timestamp \
    --sign "$CODESIGN_ID" "$DMG_PATH"
  echo "✅ Codesign (DMG) complete."

  echo "▶︎ Verifying DMG signature..."
  codesign --verify --verbose=4 "$DMG_PATH"

  echo "▶︎ Submitting DMG for notarization (profile: $NOTARY_PROFILE)..."
  xcrun notarytool submit "$DMG_PATH" \
          --keychain-profile "$NOTARY_PROFILE" \
          --wait
  echo "✅ Notarization (DMG) complete."

  echo "▶︎ Stapling ticket to .app bundle..."
  xcrun stapler staple "$APPDIR"
  echo "✅ Staple (.app) complete."
  xcrun stapler validate "$APPDIR"

  echo "▶︎ Stapling ticket to DMG..."
  xcrun stapler staple "$DMG_PATH"
  echo "✅ Staple (DMG) complete."
  xcrun stapler validate "$DMG_PATH"

  echo "▶︎ Final assessment of .app bundle..."
  spctl --assess --type execute -vvvv "$APPDIR"
  echo "▶︎ Final assessment of DMG..."
  spctl --assess --type open --context context:primary-signature -vvvv "$DMG_PATH"

else
  echo "⚠︎ Skipping codesign, notarization, and stapling (CODESIGN_ID env var not set)."
  echo "▶︎ Creating unsigned DMG with LZMA compression: $DMG_PATH"
  hdiutil create -volname "$APPNAME $VER" \
    -srcfolder "$APPDIR" \
    -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
    -format ULMO \
    -ov \
    "$DMG_PATH"  > /dev/null
  echo "✅ Unsigned LZMA DMG created at $DMG_PATH"
fi

echo "🎉 Bundle process finished."