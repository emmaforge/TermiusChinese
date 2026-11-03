#!/bin/sh
# extract_ios_strings.sh - dump Termius iOS UI strings on a jailbroken device.
# Usage:
#   sh extract_ios_strings.sh [Termius.app path] > ios_strings.txt
#   # no argument: auto-searches /var/containers/Bundle/Application
# Read-only: it never modifies the app. The .app must be the DECRYPTED
# installed copy (an App Store IPA downloaded on a computer is encrypted
# and `strings` will show nothing useful).
# Send only ios_strings.txt (text), never the IPA itself.
# If ios_strings.txt is too big to upload in chat, split it:
#   split -l 5000 ios_strings.txt part_   # then upload the parts
set -eu
APP="${1:-}"
if [ -z "$APP" ]; then
  APP=$(find /var/containers/Bundle/Application -maxdepth 3 -name 'Termius.app' 2>/dev/null | head -1)
fi
if [ -z "$APP" ] || [ ! -d "$APP" ]; then
  echo "Termius.app not found. Find it in Filza, then run:" >&2
  echo "  sh extract_ios_strings.sh /path/to/Termius.app > ios_strings.txt" >&2
  exit 1
fi
echo "APP=$APP"
echo
echo "== Info.plist =="
if command -v plutil >/dev/null 2>&1; then
  plutil -p "$APP/Info.plist" 2>/dev/null | grep -E 'CFBundleIdentifier|CFBundleExecutable|CFBundleShortVersionString|CFBundleVersion' || true
else
  grep -a -A1 -E 'CFBundleIdentifier|CFBundleExecutable|CFBundleShortVersionString|CFBundleVersion' "$APP/Info.plist" 2>/dev/null | head -40 || true
fi
echo
echo "== app contents (top level) =="
ls -la "$APP" | head -60
echo
echo "== .lproj dirs =="
find "$APP" -maxdepth 2 -name '*.lproj' -print
echo
echo "== .strings / storyboard files =="
find "$APP" \( -name '*.strings' -o -name '*.storyboard' -o -name '*.stringsdict' \) -print | head -100
echo
echo "== strings from main executable (ASCII, len>=4, dedup, first 20000) =="
EXE=""
if command -v plutil >/dev/null 2>&1; then
  EXE=$(plutil -p "$APP/Info.plist" 2>/dev/null | sed -n 's/.*CFBundleExecutable.*=> "\(.*\)".*/\1/p' | head -1)
fi
if [ -z "$EXE" ]; then EXE="Termius"; fi
if [ -f "$APP/$EXE" ]; then
  if command -v strings >/dev/null 2>&1; then
    strings -a "$APP/$EXE" 2>/dev/null | grep -E '^[A-Za-z0-9][ -~]{3,}$' | sort -u | head -20000
  else
    # fallback when the strings tool is not installed on the device
    grep -a -o -E '[ -~]{4,}' "$APP/$EXE" 2>/dev/null | sort -u | head -20000
  fi
else
  echo "executable not found: $APP/$EXE" >&2
  ls "$APP" >&2
fi
