# Minion MacOS Fixed and Signed Build Project

## Project Goal

Create a simple, one-click solution for Mac users to run Minion (an addon manager for Elder Scrolls Online) on macOS Sonoma and newer versions, supporting both Intel (x86_64) and Apple Silicon (arm64) architectures.

## Background

Minion stopped working on macOS Sonoma due to Java/JavaFX compatibility issues. The community has developed various workarounds involving command-line operations and manual Java installations, but these are too technical for average users. This project packages everything needed into a standard Mac application bundle that users can simply download, open, and run.

## Solution Overview

The `bundle.sh` script creates a universal Minion.app that:
- Includes both ARM64 and Intel Java 11 runtimes with JavaFX
- Automatically detects the user's CPU architecture
- Contains the latest patched Minion JAR file
- Can be signed and notarized for distribution
- Packages everything into a DMG file

## Prerequisites for Building

1. **Directory Structure**
   ```
   minion-build/
   ├── bundle.sh
   ├── Minion-jfx.jar      # Latest patched version (3.0.12)
   ├── lib/                # Minion's dependencies
   ├── jdk11.0.27-aarch64/ # BellSoft Liberica Full JDK (ARM64)
   └── jdk11.0.27-amd64/   # BellSoft Liberica Full JDK (Intel)
   ```

2. **Required Files**
   - **Minion JAR**: Download from https://cdn.mmoui.com/minion/v3/Minion3.0.12-java.zip and extract
   - **JDK Downloads**: Get BellSoft Liberica "Full JDK" (includes JavaFX) from https://bell-sw.com/pages/downloads/
     - ARM64 version for Apple Silicon
     - AMD64 version for Intel Macs
   - **Icon**: Copy from existing Minion.app at `/Applications/Minion.app/Contents/Resources/Minion.icns`

## Build Instructions

1. **Basic Build** (unsigned)
   ```bash
   ./bundle.sh
   ```

2. **Signed Build** (for distribution)
   
   First, install dotenvx:
   ```bash
   curl -L https://dotenvx.sh/install.sh | sh
   ```

   Create a `.env` file with your credentials:
   ```bash
   # Create .env file
   cat > .env << 'EOF'
   CODESIGN_ID="Developer ID Application: Your Name (TEAMID)"
   APP_PASSWORD="your-app-specific-password"
   NOTARY_PROFILE="AC_NOTARY"
   EOF
   ```

   Encrypt your `.env` file to protect sensitive credentials:
   ```bash
   # Encrypt the .env file (creates .env.keys)
   dotenvx encrypt
   ```

   Configure notarization with your app password:
   ```bash
   # Load encrypted credentials and configure notarization
   dotenvx run -- xcrun notarytool store-credentials "$NOTARY_PROFILE" \
     --apple-id "your-apple-id@example.com" \
     --team-id "TEAMID" \
     --password "$APP_PASSWORD"
   ```

   Build with encrypted credentials:
   ```bash
   # Run bundle script with encrypted environment variables
   dotenvx run -- ./bundle.sh
   ```

## Technical Details

### Why This Works

1. **Java 11 with JavaFX**: The latest Minion requires JavaFX, which Oracle removed from standard Java distributions. BellSoft Liberica "Full" includes JavaFX.

2. **Module Access Flags**: Modern Java requires explicit module access permissions:
   ```bash
   --add-opens=javafx.graphics/com.sun.javafx.css=ALL-UNNAMED
   --add-opens=javafx.graphics/javafx.scene.image=ALL-UNNAMED
   --add-opens=java.base/java.lang=ALL-UNNAMED
   ```

3. **Universal Binary Approach**: Instead of creating a true universal binary, we include both architectures and select at runtime based on `uname -m`.

### Known Issues & Solutions

1. **macOS 14.4 Bug**: A temporary Apple bug caused SIGKILL instead of SIGSEGV, breaking Java. Fixed in 14.4.1+.

2. **Outdated JAR**: The Minion website may an old JAR or DMG file (3.0.10) that has compatibility issues. Always use the auto-updated version (3.0.12+).

3. **Gatekeeper**: Unsigned apps will show security warnings. Users must right-click and select "Open" the first time. The signing process in bundle.sh is designed to minimize the amount of annoyance incurred by Gatekeeper.

## For End Users

### Installation
1. Download the DMG file
2. Open the DMG
3. Drag Minion to your Applications folder
4. Right-click Minion and select "Open" (first time only)

### Troubleshooting
- If Minion doesn't open, check System Settings > Privacy & Security
- For "damaged app" errors, run in Terminal: `xattr -cr /Applications/Minion.app`

## Future Improvements

sirinsidiator is working on Minion 4; there probably won't be another release of Minion 3.x.

## References

- Original forum thread: https://www.esoui.com/forums/showthread.php?t=10775
- Minion downloads: https://minion.mmoui.com/?download
- BellSoft Liberica: https://bell-sw.com/pages/downloads/
- JavaFX module documentation: https://openjfx.io/javadoc/11/