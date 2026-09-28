ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

# Tối ưu hóa Log Build CI/CD và tắt cảnh báo rác
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

# ==============================================================================
# PART 1: BUILD MAIN LIBRARY (TWEAK CORE LOGIC V24.7.1 APEX)
# ==============================================================================
LIBRARY_NAME = BoostiPhone6sCore

# Đường dẫn cài đặt dylib vào MobileSubstrate
BoostiPhone6sCore_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

BoostiPhone6sCore_FILES = Tweak.xm \
                          Modules/CacheCleaner.m \
                          Modules/CrashGuard.m \
                          Modules/SmartThermal.m \
                          Modules/DeepExploit.c \
                          Modules/KernelBypass.m \
                          Modules/SystemBlocker.m

BoostiPhone6sCore_CFLAGS = -fobjc-arc \
                           -O3 \
                           -Wall \
                           -Wno-error \
                           -Wno-unused-variable \
                           -Wno-deprecated-declarations \
                           -Wno-unused-function \
                           -Wno-implicit-function-declaration \
                           -Wno-deprecated-non-prototype \
                           -Wno-macro-redefined \
                           -Wno-module-import-in-extern-c \
                           -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000 \
                           -DBUILDING_LIBRARY=1 \
                           -IHeaders \
                           -IModules \
                           -I.

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

# Tối ưu liên kết dylib bỏ qua cảnh báo deprecated
BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/library.mk

# ==============================================================================
# PART 2: SUBPROJECT SETTINGS UI
# ==============================================================================
SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

# ==============================================================================
# PART 3: AUTO-COPY FILTER PLIST VÀO MOBILESUBSTRATE (UIKIT + SB + PREFS)
# ==============================================================================
BOOST_PLIST_NAME = BoostiPhone6sCore.plist
BOOST_PLIST_SRC = BoostiPhone6s/Layout/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)

after-stage::
	@echo ""
	@echo "[V24.7.1] Synchronizing MobileSubstrate filter plist..."
	@TARGET_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries"; \
	mkdir -p "$$TARGET_DIR"; \
	if [ -f "$(BOOST_PLIST_NAME)" ]; then \
	    cp "$(BOOST_PLIST_NAME)" "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	    chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	    echo "[OK] Found in root: Copied to $$TARGET_DIR/"; \
	elif [ -f "$(BOOST_PLIST_SRC)" ]; then \
	    cp "$(BOOST_PLIST_SRC)" "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	    chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	    echo "[OK] Found in Layout path: Copied to $$TARGET_DIR/"; \
	else \
	    echo "[WARN] $(BOOST_PLIST_NAME) not found! Generating safe 3-bundle filter..."; \
	    printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>Filter</key>\n\t<dict>\n\t\t<key>Bundles</key>\n\t\t<array>\n\t\t\t<string>com.apple.UIKit</string>\n\t\t\t<string>com.apple.springboard</string>\n\t\t\t<string>com.apple.Preferences</string>\n\t\t</array>\n\t</dict>\n</dict>\n</plist>' > "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	    chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	    echo "[OK] Auto-generated safe 3-bundle filter plist!"; \
	fi
	@echo ""

# ==============================================================================
# PART 4: PACKAGING SCRIPT CHUẨN ROOTLESS V24.7.1
# ==============================================================================
before-package::
	@echo ""
	@echo "Finalizing Rootless Package V24.7.1 Titanium Apex..."
	@echo ""
	
	@mkdir -p $(THEOS_STAGING_DIR)/DEBIAN
	@if [ -f control ]; then \
	    cp control $(THEOS_STAGING_DIR)/DEBIAN/control; \
	    echo "[OK] DEBIAN/control verified."; \
	fi
	@if [ -f postinst ]; then \
	    cp postinst $(THEOS_STAGING_DIR)/DEBIAN/postinst; \
	    chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst; \
	    echo "[OK] DEBIAN/postinst set 755."; \
	fi
	@if [ -f prerm ]; then \
	    cp prerm $(THEOS_STAGING_DIR)/DEBIAN/prerm; \
	    chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/prerm; \
	    echo "[OK] DEBIAN/prerm set 755."; \
	fi
	
	@echo ""
	@echo "Verifying Essential Package Contents:"
	@PREFIX_PATH="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)"; \
	if [ -f "$$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.dylib" ]; then \
	    echo "  [OK] Dylib installed at: $$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/"; \
	else \
	    echo "  [FAIL] Dylib MISSING!"; \
	fi; \
	if [ -f "$$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)" ]; then \
	    echo "  [OK] Filter Plist verified!"; \
	else \
	    echo "  [FAIL] Filter Plist MISSING!"; \
	fi; \
	if [ -d "$$PREFIX_PATH/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle" ]; then \
	    echo "  [OK] Settings Bundle verified!"; \
	else \
	    echo "  [FAIL] Settings Bundle MISSING!"; \
	fi
	@echo ""
