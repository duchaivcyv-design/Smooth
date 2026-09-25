#!/bin/bash

# ==============================================================================
# PRERM - PRE-REMOVAL SCRIPT FOR BOOST iPHONE 6s-X v9.0
# Target: Rootless Jailbreak (iOS 14.0 - 26.0.1)
# Author: TaoJB | Project: Smooth
# Đảm bảo gỡ bỏ SẠCH SẼ 100% không để lại rác hệ thống
# ==============================================================================

set +e

echo ""
echo "=================================================="
echo "   BOOST iPHONE 6s-X ULTIMATE EDITION v9.0"
echo "   Status: UNINSTALLING..."
echo "=================================================="
echo ""

# ------------------------------------------------------------------------------
# 1. XÓA ENTRY PLIST ĐĂNG KÝ MENU SETTINGS
# Ngăn chặn menu "ma" xuất hiện sau khi gỡ tweak
# ------------------------------------------------------------------------------
ENTRY_PLIST="/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist"
if [ -f "$ENTRY_PLIST" ]; then
    rm -f "$ENTRY_PLIST"
    echo "[OK] PreferenceLoader entry removed."
else
    echo "[INFO] No PreferenceLoader entry found at $ENTRY_PLIST"
fi

# Fallback cho rootful path
ENTRY_PLIST_ROOTFUL="/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist"
if [ -f "$ENTRY_PLIST_ROOTFUL" ]; then
    rm -f "$ENTRY_PLIST_ROOTFUL"
    echo "[OK] Rootful PreferenceLoader entry removed."
fi

# ------------------------------------------------------------------------------
# 2. XÓA TOÀN BỘ THƯ MỤC PREFERENCES & CACHE
# Xóa cả thư mục chứa plist để tránh rác tồn đọng
# ------------------------------------------------------------------------------
TWEAK_PREFS="/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
TWEAK_PREFS_JB="/var/jb/Library/Preferences/com.taojb.boostiphone6s.plist"
TWEAK_CACHE="/var/mobile/Library/Caches/com.taojb.boostiphone6s"
TWEAK_LOGS="/var/mobile/Library/Logs/BoostiPhone6s"

if [ -f "$TWEAK_PREFS" ]; then
    rm -f "$TWEAK_PREFS"
    echo "[OK] Preferences plist removed: $TWEAK_PREFS"
fi

if [ -f "$TWEAK_PREFS_JB" ]; then
    rm -f "$TWEAK_PREFS_JB"
    echo "[OK] JB Preferences plist removed: $TWEAK_PREFS_JB"
fi

if [ -d "$TWEAK_CACHE" ]; then
    rm -rf "$TWEAK_CACHE"
    echo "[OK] Tweak cache directory cleared: $TWEAK_CACHE"
else
    echo "[INFO] No tweak cache found at $TWEAK_CACHE"
fi

if [ -d "$TWEAK_LOGS" ]; then
    rm -rf "$TWEAK_LOGS"
    echo "[OK] Tweak logs directory cleared: $TWEAK_LOGS"
fi

# ------------------------------------------------------------------------------
# 3. XÓA DYLIB KHỎI HỆ THỐNG
# Đảm bảo dylib không còn tồn tại sau khi gỡ
# ------------------------------------------------------------------------------
DYLIB_PATH="/var/jb/usr/lib/BoostiPhone6sCore.dylib"
if [ -f "$DYLIB_PATH" ]; then
    rm -f "$DYLIB_PATH"
    echo "[OK] Dylib removed: $DYLIB_PATH"
else
    echo "[INFO] Dylib not found at $DYLIB_PATH"
fi

# Fallback rootful
DYLIB_ROOTFUL="/usr/lib/BoostiPhone6sCore.dylib"
if [ -f "$DYLIB_ROOTFUL" ]; then
    rm -f "$DYLIB_ROOTFUL"
    echo "[OK] Rootful dylib removed: $DYLIB_ROOTFUL"
fi

# ------------------------------------------------------------------------------
# 4. XÓA SETTINGS BUNDLE
# ------------------------------------------------------------------------------
BUNDLE_PATH="/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"
if [ -d "$BUNDLE_PATH" ]; then
    rm -rf "$BUNDLE_PATH"
    echo "[OK] Settings bundle removed: $BUNDLE_PATH"
else
    echo "[INFO] Settings bundle not found at $BUNDLE_PATH"
fi

BUNDLE_ROOTFUL="/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"
if [ -d "$BUNDLE_ROOTFUL" ]; then
    rm -rf "$BUNDLE_ROOTFUL"
    echo "[OK] Rootful settings bundle removed: $BUNDLE_ROOTFUL"
fi

# ------------------------------------------------------------------------------
# 5. RESET USERDEFAULTS AN TOÀN CHO ROOTLESS
# Dùng 'defaults' command thay vì truy cập trực tiếp file plist
# Đảm bảo xóa sạch cả Safe Mode state và crash logs cũ
# ------------------------------------------------------------------------------
if command -v defaults &> /dev/null; then
    defaults delete com.taojb.boostiphone6s 2>/dev/null || true
    echo "[OK] UserDefaults domain completely wiped via defaults command."
else
    # Fallback cho môi trường không có 'defaults' command
    rm -f "/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist" 2>/dev/null || true
    echo "[OK] Settings plist removed via fallback."
fi

# Xóa thêm các key riêng lẻ để đảm bảo sạch sẽ
if command -v defaults &> /dev/null; then
    defaults delete com.taojb.boostiphone6s BoostiPhone6s_SafeModeActive 2>/dev/null || true
    defaults delete com.taojb.boostiphone6s BoostiPhone6s_LastCrashReason 2>/dev/null || true
    defaults delete com.taojb.boostiphone6s Enabled 2>/dev/null || true
    echo "[OK] Individual safe mode keys removed."
fi

# ------------------------------------------------------------------------------
# 6. FORCE REFRESH CFPREFSD DAEMON
# Gửi signal HUP để daemon reload danh sách preference mới nhất
# An toàn hơn killall -9 trên Rootless, tránh crash SpringBoard
# ------------------------------------------------------------------------------
if pidof cfprefsd > /dev/null 2>&1; then
    killall -HUP cfprefsd >/dev/null 2>&1 || true
    echo "[OK] cfprefsd signaled to refresh cache."
else
    echo "[INFO] cfprefsd not running. Will refresh after respring."
fi

# ------------------------------------------------------------------------------
# 7. XÓA MOBILESUBSTRATE DYLID LIST ENTRY (NẾU CÓ)
# ------------------------------------------------------------------------------
DYLIB_LIST="/var/jb/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.plist"
if [ -f "$DYLIB_LIST" ]; then
    rm -f "$DYLIB_LIST"
    echo "[OK] MobileSubstrate dylib list entry removed."
fi

DYLIB_LIST_ROOTFUL="/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.plist"
if [ -f "$DYLIB_LIST_ROOTFUL" ]; then
    rm -f "$DYLIB_LIST_ROOTFUL"
    echo "[OK] Rootful MobileSubstrate dylib list entry removed."
fi

echo ""
echo "=================================================="
echo "   UNINSTALLATION COMPLETE!"
echo "   All traces of Boost iPhone 6s-X v9.0 removed."
echo "   Please RESPRING your device to finalize changes."
echo "=================================================="
echo ""

exit 0
