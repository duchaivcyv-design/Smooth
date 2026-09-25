ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

# ROOTLESS NATIVE MODE
_INSTALL_PATH_TARGET = /var/jb

include $(THEOS)/makefiles/common.mk

# ==============================================================================
# PART 1: BUILD MAIN LIBRARY (TWEAK CORE LOGIC)
# ==============================================================================
LIBRARY_NAME = BoostiPhone6sCore

BoostiPhone6sCore_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

BoostiPhone6sCore_FILES = Tweak.xm \
                          DeviceBypass.xm \
                          Modules/CacheCleaner.m \
                          Modules/CrashGuard.m \
                          Modules/SmartThermal.m \
                          Modules/DeepExploit.c \
                          Modules/KernelBypass.m \
                          Modules/SystemBlocker.m

# COMPILER FLAGS
# -Wno-error: Logos warnings (multiple %group, duplicate hooks) không được treat as errors
#   vì code gốc merge 2 codebase (Boost + ProMotion) có thể trigger logos warnings
# -Wno-logos: suppress Logos-specific warnings hoàn toàn
BoostiPhone6sCore_CFLAGS = -fobjc-arc \
                           -O3 \
                           -Wall \
                           -Wno-error \
                           -Wno-logos \
                           -Wno-unknown-warning-option \
                           -Wno-unused-variable \
                           -Wno-deprecated-declarations \
                           -Wno-module-import-in-extern-c \
                           -Wno-macro-redefined \
                           -Wno-unused-function \
                           -Wno-implicit-function-declaration \
                           -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000 \
                           -DBUILDING_LIBRARY=1 \
                           -IHeaders \
                           -IModules \
                           -I.

# FRAMEWORKS
# Thêm CoreServices cho CFNotificationCenter, posix_spawn, environ
BoostiPhone6sCore_FRAMEWORKS = UIKit \
                               CoreGraphics \
                               QuartzCore \
                               AVFoundation \
                               IOKit \
                               Foundation \
                               Metal \
                               CoreVideo \
                               Accelerate \
                               CoreServices

# LINKER FLAGS
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
# PART 3: PACKAGING SCRIPT CHUẨN ROOTLESS v10
# ==============================================================================
before-package::
	@echo ""
	@echo "Finalizing Rootless Package v10..."
	@echo ""
	
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
	
	@echo ""
	@echo "Package Structure Verification:"
	
	@FOUND=0; \
	if [ -f "$(THEOS_STAGING_DIR)/var/jb/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.dylib" ]; then \
	    echo "  [OK] Dylib: var/jb/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.dylib"; \
	    FOUND=1; \
	elif [ -f "$(THEOS_STAGING_DIR)/var/jb/usr/lib/BoostiPhone6sCore.dylib" ]; then \
	    echo "  [OK] Dylib: var/jb/usr/lib/BoostiPhone6sCore.dylib (fallback path)"; \
	    FOUND=1; \
	else \
	    echo "  [FAIL] Dylib NOT FOUND in any expected path!"; \
	fi; \
	if [ -d "$(THEOS_STAGING_DIR)/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle" ]; then \
	    echo "  [OK] Bundle: var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"; \
	else \
	    echo "  [FAIL] Bundle NOT FOUND!"; \
	fi; \
	if [ -f "$(THEOS_STAGING_DIR)/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist" ]; then \
	    echo "  [OK] Entry: var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist"; \
	else \
	    echo "  [FAIL] Entry Plist NOT FOUND!"; \
	fi
	
	@echo ""
	@echo "Rootless Package v10 Ready!"
	@echo ""
