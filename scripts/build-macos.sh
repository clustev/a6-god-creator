#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
build_dir="$root/build"
app="$build_dir/Карточки A6.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$build_dir/module-cache"
cp "$root/macos/Info.plist" "$app/Contents/Info.plist"
cp "$root/macos/Resources/template.png" "$root/macos/Resources/AppIcon.icns" "$app/Contents/Resources/"
swiftc -target arm64-apple-macos13.0 -module-cache-path "$build_dir/module-cache" -O "$root/macos/main.swift" -o "$app/Contents/MacOS/CardMaker" -framework SwiftUI -framework AppKit
codesign --force --sign - "$app"
codesign --verify --deep --strict "$app"
ditto -c -k --sequesterRsrc --keepParent "$app" "$build_dir/CardMaker-macOS-AppleSilicon.zip"
printf 'Готово: %s\n' "$build_dir/CardMaker-macOS-AppleSilicon.zip"
