#!/bin/bash
set +e

STAGING_DIR=".theos/_"

if [ ! -d "$STAGING_DIR" ]; then
    echo "[FAIL] Staging directory not found. Run 'make package' first."
    exit 1
fi

mkdir -p "$STAGING_DIR/DEBIAN"
[ -f "control" ] && cp control "$STAGING_DIR/DEBIAN/control"
[ -f "postinst" ] && cp postinst "$STAGING_DIR/DEBIAN/postinst" && chmod 755 "$STAGING_DIR/DEBIAN/postinst"
[ -f "prerm" ] && cp prerm "$STAGING_DIR/DEBIAN/prerm" && chmod 755 "$STAGING_DIR/DEBIAN/prerm"

DYLIB_DST_DIR="$STAGING_DIR/var/jb/Library/MobileSubstrate/DynamicLibraries"
mkdir -p "$DYLIB_DST_DIR"

for search_path in ".theos/obj/BoostiPhone6sCore.dylib" ".theos/obj/arm64/BoostiPhone6sCore.dylib" ".theos/obj/arm64e/BoostiPhone6sCore.dylib"; do
    if [ -f "$search_path" ]; then
        cp "$search_path" "$DYLIB_DST_DIR/BoostiPhone6sCore.dylib"
        chmod 755 "$DYLIB_DST_DIR/BoostiPhone6sCore.dylib"
        break
    fi
done

[ -f "BoostiPhone6sCore.plist" ] && cp BoostiPhone6sCore.plist "$DYLIB_DST_DIR/BoostiPhone6sCore.plist"

BUNDLE_DST_DIR="$STAGING_DIR/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"
mkdir -p "$BUNDLE_DST_DIR"

for plist_name in "Root.plist" "root.plist"; do
    if [ -f "BoostiPhone6s/Resources/$plist_name" ]; then
        cp "BoostiPhone6s/Resources/$plist_name" "$BUNDLE_DST_DIR/Root.plist"
        break
    fi
done

[ -f "BoostiPhone6s/Info.plist" ] && cp BoostiPhone6s/Info.plist "$BUNDLE_DST_DIR/Info.plist"
[ -f "BoostiPhone6s/Resources/icon.png" ] && cp BoostiPhone6s/Resources/icon.png "$BUNDLE_DST_DIR/icon.png"

ENTRY_DST_DIR="$STAGING_DIR/var/jb/Library/PreferenceLoader/Entries"
mkdir -p "$ENTRY_DST_DIR"

for entry_path in "BoostiPhone6s/Layout/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist" "BoostiPhone6s/BoostiPhone6sPrefs.plist" "BoostiPhone6sPrefs.plist"; do
    if [ -f "$entry_path" ]; then
        cp "$entry_path" "$ENTRY_DST_DIR/BoostiPhone6sPrefs.plist"
        break
    fi
done

PASS=0; FAIL=0
[ -f "$DYLIB_DST_DIR/BoostiPhone6sCore.dylib" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
[ -f "$BUNDLE_DST_DIR/Root.plist" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
[ -f "$ENTRY_DST_DIR/BoostiPhone6sPrefs.plist" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
[ -f "$STAGING_DIR/DEBIAN/control" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))

echo "Verification: $PASS passed, $FAIL failed"
exit $FAIL
