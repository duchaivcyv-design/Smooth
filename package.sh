#!/bin/bash

# ==============================================================================
# PACKAGE.SH - BOOST iPHONE 6s-X v10 ROOTLESS PACKAGING SCRIPT
# Author: TaoJB | Project: Smooth
# Target: iOS 14.0 - 26.0.1 | Rootless (/var/jb)
# 
# Script này chạy SAU khi 'make package' hoàn tất.
# Nhiệm vụ: kiểm tra và bổ sung các file còn thiếu vào staging directory.
# ==============================================================================

set +e

echo "[BoostiPhone6s v10] Starting post-packaging verification..."

# Xác định staging directory
# Theos mặc định dùng .theos/_/ cho staging
STAGING_DIR=".theos/_"

if [ ! -d "$STAGING_DIR" ]; then
    echo "[FAIL] Staging directory not found: $STAGING_DIR"
    echo "[INFO] Run 'make package' first before running this script."
    exit 1
fi

# ==============================================================================
# 1. DEBIAN CONTROL FILES
# ==============================================================================
echo "[STEP 1] Verifying DEBIAN control files..."

mkdir -p "$STAGING_DIR/DEBIAN"

if [ -f "control" ]; then
    cp control "$STAGING_DIR/DEBIAN/control"
    echo "  [OK] control copied"
else
    echo "  [FAIL] control file not found in project root!"
fi

if [ -f "postinst" ]; then
    cp postinst "$STAGING_DIR/DEBIAN/postinst"
    chmod 755 "$STAGING_DIR/DEBIAN/postinst"
    echo "  [OK] postinst copied and chmod 755"
else
    echo "  [WARN] postinst not found (optional)"
fi

if [ -f "prerm" ]; then
    cp prerm "$STAGING_DIR/DEBIAN/prerm"
    chmod 755 "$STAGING_DIR/DEBIAN/prerm"
    echo "  [OK] prerm copied and chmod 755"
else
    echo "  [WARN] prerm not found (optional)"
fi

# ==============================================================================
# 2. DYNAMIC LIBRARY (TWEAK CORE)
# ==============================================================================
echo "[STEP 2] Verifying Dynamic Library..."

DYLIB_SRC=".theos/obj/BoostiPhone6sCore.dylib"
DYLIB_DST_DIR="$STAGING_DIR/var/jb/Library/MobileSubstrate/DynamicLibraries"
DYLIB_DST="$DYLIB_DST_DIR/BoostiPhone6sCore.dylib"
PLIST_FILTER="BoostiPhone6sCore.plist"

mkdir -p "$DYLIB_DST_DIR"

# Tìm dylib trong các vị trí có thể
DYLIB_FOUND=0
for search_path in \
    ".theos/obj/BoostiPhone6sCore.dylib" \
    ".theos/obj/arm64/BoostiPhone6sCore.dylib" \
    ".theos/obj/arm64e/BoostiPhone6sCore.dylib" \
    ".theos/_/var/jb/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.dylib" \
    ".theos/_/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.dylib"; do
    
    if [ -f "$search_path" ]; then
        cp "$search_path" "$DYLIB_DST"
        chmod 755 "$DYLIB_DST"
        echo "  [OK] Dylib copied from $search_path"
        DYLIB_FOUND=1
        break
    fi
done

if [ "$DYLIB_FOUND" -eq 0 ]; then
    echo "  [WARN] Dylib not found in expected paths. Theos may have placed it correctly already."
fi

# Copy filter plist nếu có
if [ -f "$PLIST_FILTER" ]; then
    cp "$PLIST_FILTER" "$DYLIB_DST_DIR/BoostiPhone6sCore.plist"
    echo "  [OK] Filter plist copied"
elif [ -f "BoostiPhone6sCore.plist" ]; then
    cp "BoostiPhone6sCore.plist" "$DYLIB_DST_DIR/BoostiPhone6sCore.plist"
    echo "  [OK] Filter plist copied from root"
else
    echo "  [WARN] Filter plist not found. Create BoostiPhone6sCore.plist in project root."
fi

# ==============================================================================
# 3. PREFERENCE BUNDLE (SETTINGS UI)
# ==============================================================================
echo "[STEP 3] Verifying Preference Bundle..."

BUNDLE_DST_DIR="$STAGING_DIR/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"
mkdir -p "$BUNDLE_DST_DIR"

# Copy Root.plist (CHỮ R HOA - đây là lỗi cũ: root.plist vs Root.plist)
ROOT_PLIST_FOUND=0
for plist_name in "Root.plist" "root.plist"; do
    if [ -f "BoostiPhone6s/Resources/$plist_name" ]; then
        cp "BoostiPhone6s/Resources/$plist_name" "$BUNDLE_DST_DIR/Root.plist"
        echo "  [OK] Root.plist copied from BoostiPhone6s/Resources/$plist_name"
        ROOT_PLIST_FOUND=1
        break
    fi
done

if [ "$ROOT_PLIST_FOUND" -eq 0 ]; then
    echo "  [FAIL] Root.plist NOT FOUND! Settings will be empty."
    echo "  [INFO] Expected at: BoostiPhone6s/Resources/Root.plist"
fi

# Copy Info.plist
if [ -f "BoostiPhone6s/Info.plist" ]; then
    cp "BoostiPhone6s/Info.plist" "$BUNDLE_DST_DIR/Info.plist"
    echo "  [OK] Info.plist copied"
else
    echo "  [WARN] Info.plist not found"
fi

# Copy icon nếu có
for icon_name in "icon.png" "Icon.png" "icon@2x.png" "Icon@2x.png" "icon@3x.png"; do
    if [ -f "BoostiPhone6s/Resources/$icon_name" ]; then
        cp "BoostiPhone6s/Resources/$icon_name" "$BUNDLE_DST_DIR/$icon_name"
        echo "  [OK] Icon copied: $icon_name"
    fi
done

# Copy binary của bundle nếu Theos chưa đặt đúng chỗ
BUNDLE_BINARY_FOUND=0
for bin_path in \
    ".theos/obj/BoostiPhone6sPrefs.bundle/BoostiPhone6sPrefs" \
    ".theos/_/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/BoostiPhone6sPrefs" \
    ".theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/BoostiPhone6sPrefs"; do
    
    if [ -f "$bin_path" ]; then
        cp "$bin_path" "$BUNDLE_DST_DIR/BoostiPhone6sPrefs"
        chmod 755 "$BUNDLE_DST_DIR/BoostiPhone6sPrefs"
        echo "  [OK] Bundle binary copied from $bin_path"
        BUNDLE_BINARY_FOUND=1
        break
    fi
done

if [ "$BUNDLE_BINARY_FOUND" -eq 0 ]; then
    echo "  [WARN] Bundle binary not found. Theos may have placed it correctly already."
fi

# ==============================================================================
# 4. PREFERENCE LOADER ENTRY (MENU TRONG SETTINGS.APP)
# ==============================================================================
echo "[STEP 4] Verifying PreferenceLoader Entry..."

ENTRY_DST_DIR="$STAGING_DIR/var/jb/Library/PreferenceLoader/Entries"
mkdir -p "$ENTRY_DST_DIR"

ENTRY_FOUND=0
for entry_path in \
    "BoostiPhone6s/Layout/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist" \
    "BoostiPhone6s/BoostiPhone6sPrefs.plist" \
    "BoostiPhone6sPrefs.plist"; do
    
    if [ -f "$entry_path" ]; then
        cp "$entry_path" "$ENTRY_DST_DIR/BoostiPhone6sPrefs.plist"
        echo "  [OK] Entry plist copied from $entry_path"
        ENTRY_FOUND=1
        break
    fi
done

if [ "$ENTRY_FOUND" -eq 0 ]; then
    echo "  [FAIL] Entry plist NOT FOUND! Menu will not appear in Settings.app."
    echo "  [INFO] Expected at: BoostiPhone6s/Layout/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist"
fi

# ==============================================================================
# 5. FINAL VERIFICATION
# ==============================================================================
echo ""
echo "=========================================="
echo "  PACKAGE VERIFICATION SUMMARY"
echo "=========================================="

PASS=0
FAIL=0

# Check dylib
if [ -f "$DYLIB_DST" ]; then
    echo "  [PASS] Dylib: $DYLIB_DST"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] Dylib missing!"
    FAIL=$((FAIL + 1))
fi

# Check bundle
if [ -d "$BUNDLE_DST_DIR" ] && [ -f "$BUNDLE_DST_DIR/Root.plist" ]; then
    echo "  [PASS] Bundle: $BUNDLE_DST_DIR"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] Bundle or Root.plist missing!"
    FAIL=$((FAIL + 1))
fi

# Check entry
if [ -f "$ENTRY_DST_DIR/BoostiPhone6sPrefs.plist" ]; then
    echo "  [PASS] Entry: $ENTRY_DST_DIR/BoostiPhone6sPrefs.plist"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] Entry plist missing!"
    FAIL=$((FAIL + 1))
fi

# Check DEBIAN
if [ -f "$STAGING_DIR/DEBIAN/control" ]; then
    echo "  [PASS] DEBIAN/control exists"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] DEBIAN/control missing!"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "  Result: $PASS passed, $FAIL failed"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
    echo ""
    echo "  [WARNING] Some checks failed. Review the output above."
    echo "  The .deb may still work if Theos handled the missing parts."
else
    echo ""
    echo "  [SUCCESS] All checks passed. Package is ready."
fi

echo ""
echo "  To build .deb: dpkg-deb -b $STAGING_DIR packages/"
echo ""
