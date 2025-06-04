# Minion for macOS (Fixed)

**Minion stopped working on newer Macs?** This fixes it!

## Download

**[⬇️ Download Minion-3.0.12.dmg](https://github.com/allquixotic/minion3-macos-signed/releases/download/v1.0/Minion-3.0.12.dmg)**

## Installation

1. Download the DMG file above
2. Double-click to open it
3. Drag Minion to your Applications folder
4. **First time only:** Right-click Minion and choose "Open"

That's it! Minion should now work on your Mac.

## What This Fixes

- ✅ Works on macOS Sonoma and newer
- ✅ Works on Apple Silicon (M1/M2/M3) Macs
- ✅ Works on Intel Macs
- ✅ No command line needed
- ✅ No Java installation needed

## Troubleshooting

**"Minion is damaged and can't be opened"**
- In Terminal, run: `xattr -cr /Applications/Minion.app`

**Still having issues?**
- Check System Settings > Privacy & Security
- Look for any messages about Minion and click "Allow"

---

### Technical Details

This is a universal app bundle that includes both ARM64 and Intel Java 11 runtimes with JavaFX. The app automatically detects your CPU architecture and uses the appropriate runtime. It's signed and notarized for Gatekeeper compatibility.