# ==============================================================================
# MAKEFILE - BOOST iPHONE 6s-X v9.0 ULTIMATE BUILD SYSTEM
# Author: TaoJB | Project: Smooth
# Target: iOS 14.0 - 26.0.1 | iPhone 6s to 15 Pro Max+
# Architecture: arm64 + arm64e (Rootless Native)
# ==============================================================================

ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

# ★ ROOTLESS NATIVE MODE ★
# Báo cho Theos biết: Mọi thứ build ra hãy ném vào /var/jb/
_INSTALL_PATH_TARGET = /var/jb

include $(THEOS)/makefiles/common.mk

# ==============================================================================
# PART 1: BUILD MAIN LIBRARY (TWEAK CORE LOGIC)
# ==============================================================================
LIBRARY_NAME = BoostiPhone6sCore

BoostiPhone6sCore_FILES = Tweak.xm \
                          DeviceBypass.xm \
                          Modules/CacheCleaner.m \
                          Modules/CrashGuard.m \
                          Modules/SmartThermal.m \
                          Modules/DeepExploit.c \
                          Modules/KernelBypass.m \
                          Modules/SystemBlocker.m

# ★ COMPILER FLAGS - TỐI ƯU HÓA CHO iOS 26 SDK ★
BoostiPhone6sCore_CFLAGS = -fobjc-arc \
                           -O3 \
                           -Wall \
                           -Wno-unknown-warning-option \
                           -Wno-unused-variable \
                           -Wno-deprecated-declarations \
                           -Wno-module-import-in-extern-c \
                           -Wno-macro-redefined \
                           -Wno-unused-function \
                           -Wno-implicit-function-declaration \
                           -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000 \
                           -DBUILDING_LIBRARY=1

# ★ FRAMEWORKS - TẤT CẢ CẦN THIẾT CHO v9.0 ★
BoostiPhone6sCore_FRAMEWORKS = UIKit \
                               CoreGraphics \
                               QuartzCore \
                               AVFoundation \
                               IOKit \
                               Foundation \
                               Metal \
                               CoreVideo \
                               Accelerate

# ★ LINKER FLAGS - TỐI ƯU SIZE VÀ LOẠI BỎ SYMBOL THỪA ★
BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-no_warn_duplicate_libraries \
                            -Wl,-exported_symbol,_init_privilege_escalation

include $(THEOS_MAKE_PATH)/library.mk

# ==============================================================================
# PART 2: SUBPROJECT SETTINGS UI
# ==============================================================================
SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

# ==============================================================================
# PART 3: PACKAGING SCRIPT CHUẨN ROOTLESS v9.0
# THEOS ĐÃ TỰ ĐỘNG MAP LIBRARY + BUNDLE + ENTRY PLIST VÀO /var/jb/
# KHÔNG CẦN COPY THỦ CÔNG NỮA TRÁNH LỖI DUPLICATE HOẶC SAI PATH
# ==============================================================================
before-package::
	@echo ""
	@echo "🚀 Finalizing Rootless Package v9.0..."
	@echo ""
	
	# Hoàn tất DEBIAN control files
	@mkdir -p $(THEOS_STAGING_DIR)/DEBIAN
	@if [ -f control ]; then \
	    cp control $(THEOS_STAGING_DIR)/DEBIAN/control; \
	    echo "[OK] DEBIAN/control copied."; \
	fi
	@if [ -f postinst ]; then \
	    cp postinst $(THEOS_STAGING_DIR)/DEBIAN/postinst; \
	    chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst; \
	    echo "[OK] DEBIAN/postinst copied and chmod 755."; \
	fi
	@if [ -f prerm ]; then \
	    cp prerm $(THEOS_STAGING_DIR)/DEBIAN/prerm; \
	    chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/prerm; \
	    echo "[OK] DEBIAN/prerm copied and chmod 755."; \
	fi
	
	# Verify package structure
	@echo ""
	@echo "📦 Package Structure Verification:"
	@if [ -f $(THEOS_STAGING_DIR)/var/jb/usr/lib/BoostiPhone6sCore.dylib ]; then \
	    echo "  ✅ Dylib: var/jb/usr/lib/BoostiPhone6sCore.dylib"; \
	else \
	    echo "  ❌ Dylib NOT FOUND!"; \
	fi
	@if [ -d $(THEOS_STAGING_DIR)/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle ]; then \
	    echo "  ✅ Bundle: var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"; \
	else \
	    echo "  ❌ Bundle NOT FOUND!"; \
	fi
	@if [ -f $(THEOS_STAGING_DIR)/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist ]; then \
	    echo "  ✅ Entry: var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist"; \
	else \
	    echo "  ❌ Entry Plist NOT FOUND!"; \
	fi
	
	@echo ""
	@echo "✅ Rootless Package v9.0 Ready!"
	@echo ""
