#!/bin/zsh
# Build Elysee and install it on "iPhone de Kamel" (unlocked, Developer Mode on).
set -e
cd "$(dirname "$0")"
DEVICE=${DEVICE:-00008130-00045D383492001C}
xcodegen generate -q
mkdir -p build
xcodebuild -project Elysee.xcodeproj -scheme Elysee -destination "id=$DEVICE" -allowProvisioningUpdates -derivedDataPath build build > build/log.txt 2>&1 || { grep -E "error:" build/log.txt | sort -u; exit 1; }
xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Debug-iphoneos/Elysee.app
xcrun devicectl device process launch --device "$DEVICE" fr.coffee-beans.elysee2027
