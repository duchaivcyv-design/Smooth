ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6sCore

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
                           -Wno-unguarded-availability-new -Wno-unguarded-availability
                           -Wno-deprecated-declarations \
                           -Wno-unused-function \
                           -Wno-implicit-function-declaration \
                           -Wno-deprecated-non-prototype \
                           -Wno-macro-redefined \
                           -Wno-module-import-in-extern-c \
                           -D__IPHONE_OS_VERSION_MIN_REQUIRED=140000 \
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

# CẤU HÌNH LDFLAGS ĐẶC TRỊ PHÂN VÙNG ROOTHIDE & ROOTLESS
BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-undefined,dynamic_lookup \
                            -Wl,-install_name,@rpath/BoostiPhone6sCore.dylib \
                            -Wl,-rpath,/Library/Frameworks \
                            -Wl,-rpath,/var/jb/Library/Frameworks \
                            -Wl,-rpath,/usr/lib \
                            -Wl,-rpath,/var/jb/usr/lib \
                            -Wl,-rpath,/Library/MobileSubstrate/DynamicLibraries \
                            -Wl,-rpath,/var/jb/Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/library.mk

SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

BOOST_PLIST_NAME = BoostiPhone6sCore.plist
BOOST_PLIST_SRC = BoostiPhone6s/Layout/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)

after-stage::
	@echo ""
	@echo "[V26.1] Synchronizing MobileSubstrate filter plist for Dual-Environment..."
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
	    echo "[WARN] $(BOOST_PLIST_NAME) not found! Generating safe multi-target filter..."; \
	    printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>Filter</key>\n\t<dict>\n\t\t<key>Bundles</key>\n\t\t<array>\n\t\t\t<string>com.apple.UIKit</string>\n\t\t\t<string>com.apple.springboard</string>\n\t\t\t<string>com.apple.Preferences</string>\n\t\t\t<string>com.apple.Accessibility</string>\n\t\t\t<string>com.apple.TextInputUI</string>\n\t\t\t<string>com.apple.InputUI</string>\n\t\t</array>\n\t\t<key>Executables</key>\n\t\t<array>\n\t\t\t<string>SpringBoard</string>\n\t\t\t<string>Preferences</string>\n\t\t\t<string>assistivetouchd</string>\n\t\t</array>\n\t</dict>\n</dict>\n</plist>' > "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	    chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	    echo "[OK] Auto-generated complete filter plist!"; \
	fi
	@echo ""

before-package::
	@echo ""
	@echo "Finalizing Universal Package (Rootless + RootHide)..."
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
