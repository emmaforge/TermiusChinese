#!/bin/sh
# extract_ios_strings.sh - dump Termius iOS UI strings on a jailbroken device.
# Usage: sh tools/extract_ios_strings.sh /path/to/Termius.app > ios_strings.txt
# Read-only: it never modifies the app. The .app must be the DECRYPTED
# installed copy (an App Store IPA downloaded on a computer is encrypted
# and `strings` will show nothing useful).
# Send only ios_strings.txt (text), never the IPA itself.
set -eu
APP="${1:-}"
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "usage: $0 /path/to/Termius.app" >&2
  exit 1
fi
echo "== Info.plist =="
plutil -p "$APP/Info.plist" 2>/dev/null | grep -E 'CFBundleIdentifier|CFBundleExecutable|CFBundleShortVersionString|CFBundleVersion' || true
echo
echo "== .lproj dirs =="
find "$APP" -maxdepth 2 -name '*.lproj' -print
echo
echo "== .strings / storyboard files =="
find "$APP" -name '*.strings' -o -name '*.storyboard' -o -name '*.stringsdict' | head -100
echo
echo "== strings from main executable (ASCII, len>=4, dedup, first 20000) =="
EXE=$(plutil -p "$APP/Info.plist" 2>/dev/null | sed -n 's/.*CFBundleExecutable.*=> "\(.*\)".*/\1/p' | head -1)
if [ -z "$EXE" ]; then EXE="Termius"; fi
if [ -f "$APP/$EXE" ]; then
  strings -a "$APP/$EXE" 2>/dev/null | grep -E '^[A-Za-z0-9][ -~]{3,}$' | sort -u | head -20000
else
  echo "executable not found: $APP/$EXE" >&2
fi
