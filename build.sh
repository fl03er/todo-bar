#!/bin/zsh
# Builds TodoBar.app and the `todo` CLI.
#   ./build.sh           build TodoBar.app here
#   ./build.sh install   build, copy the app to ~/Applications, link `todo` into ~/.local/bin, launch
#   ./build.sh release   universal build (Apple Silicon + Intel) zipped into dist/
set -e
cd "$(dirname "$0")"
VERSION=1.3.0
APP=TodoBar.app
MIN=13.0

# Build in a scratch folder and copy: codesign refuses bundles that a synced Desktop has tagged with attributes.
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
B="$STAGE/$APP"
mkdir -p "$B/Contents/MacOS" "$B/Contents/Resources"

swift tools/make-icons.swift "$STAGE/icons" >/dev/null
cp "$STAGE/icons/AppIcon.icns" "$B/Contents/Resources/"

build() { # $1 = output name, rest = sources
  local out=$1; shift
  if [[ "$MODE" == "release" ]]; then
    for arch in arm64 x86_64; do
      swiftc -O -swift-version 5 -target $arch-apple-macos$MIN -o "$STAGE/$out-$arch" "$@"
    done
    lipo -create -output "$STAGE/$out" "$STAGE/$out-arm64" "$STAGE/$out-x86_64"
  else
    # An explicit deployment target: without it swiftc targets the SDK's OS, which Launch Services may refuse.
    swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos$MIN" -o "$STAGE/$out" "$@"
  fi
}
MODE=$1
build TodoBar Sources/Shared/*.swift Sources/App/*.swift
build todo Sources/Shared/*.swift Sources/CLI/*.swift
mv "$STAGE/TodoBar" "$B/Contents/MacOS/TodoBar"
mv "$STAGE/todo" "$B/Contents/MacOS/todo"   # the CLI ships inside the app

cat > "$B/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>TodoBar</string>
  <key>CFBundleDisplayName</key><string>TodoBar</string>
  <key>CFBundleIdentifier</key><string>io.github.todo-bar</string>
  <key>CFBundleExecutable</key><string>TodoBar</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>$MIN</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
xattr -cr "$B"
codesign --force -s - "$B/Contents/MacOS/todo"
codesign --force -s - "$B" || echo "warning: codesign failed"
rm -rf "$APP"
ditto "$B" "$APP"
echo "built $PWD/$APP"

if [[ "$1" == "install" ]]; then
  mkdir -p ~/Applications ~/.local/bin
  pkill -x TodoBar || true
  rm -rf ~/Applications/$APP
  ditto "$B" ~/Applications/$APP
  ln -sf ~/Applications/$APP/Contents/MacOS/todo ~/.local/bin/todo
  open ~/Applications/$APP || (~/Applications/$APP/Contents/MacOS/TodoBar >/dev/null 2>&1 &!)
  echo "installed ~/Applications/$APP, linked ~/.local/bin/todo"
fi

if [[ "$1" == "release" ]]; then
  mkdir -p dist
  rm -f "dist/TodoBar-$VERSION.zip"
  ditto -c -k --keepParent "$B" "dist/TodoBar-$VERSION.zip"
  lipo -archs "$B/Contents/MacOS/TodoBar"
  echo "packed $PWD/dist/TodoBar-$VERSION.zip"
fi
