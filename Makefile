ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6sCore

BoostiPhone6sCore_INSTALL_PATH = $(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries

BoostiPhone6sCore_FILES = Tweak.xm \
                          TitaniumKernelOverdrive.m

BoostiPhone6sCore_CFLAGS = -fobjc-arc \
                           -O3 \
                           -fvisibility=hidden \
                           -Wall \
                           -Wno-error \
                           -Wno-unused-variable \
                           -Wno-deprecated-declarations \
                           -Wno-unused-function \
                           -Wno-implicit-function-declaration \
                           -Wno-deprecated-non-prototype \
                           -Wno-macro-redefined \
                           -Wno-module-import-in-extern-c \
                           -Wno-unguarded-availability-new \
                           -Wno-unguarded-availability \
                           -Wno-unused-command-line-argument \
                           -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000 \
                           -DBUILDING_LIBRARY=1 \
                           -IHeaders \
                           -I.

BoostiPhone6sCore_OBJCXXFLAGS = $(BoostiPhone6sCore_CFLAGS) -std=gnu++17

BoostiPhone6sCore_FRAMEWORKS = UIKit \
                               CoreGraphics \
                               QuartzCore \
                               AVFoundation \
                               Foundation \
                               CoreFoundation \
                               Metal \
                               WebKit \
                               CoreVideo \
                               Accelerate \
                               CoreServices

BoostiPhone6sCore_PRIVATE_FRAMEWORKS = IOKit

BoostiPhone6sCore_LIBRARIES = substrate

BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-undefined,dynamic_lookup \
                            -Wl,-no_warn_duplicate_libraries \
                            -Wl,-w \
                            -lpthread

include $(THEOS_MAKE_PATH)/library.mk

SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

BOOST_PLIST_NAME = BoostiPhone6sCore.plist

# [FIX] Dam bao postinst + prerm LUON co trong DEB (dat cung voi control trong thu muc DEBIAN/)
after-stage::
	@echo ""
	@echo "=== [BoostisCore] Copy postinst/prerm vao DEBIAN/ ==="
	@mkdir -p "$(THEOS_STAGING_DIR)/DEBIAN"
	@if [ -f "postinst" ]; then \
		cp -f "postinst" "$(THEOS_STAGING_DIR)/DEBIAN/postinst"; \
		chmod 0755 "$(THEOS_STAGING_DIR)/DEBIAN/postinst"; \
		echo "  [OK] postinst -> DEBIAN/postinst"; \
	else \
		echo "  [WARN] postinst khong ton tai trong thu muc goc — bo qua"; \
	fi
	@if [ -f "prerm" ]; then \
		cp -f "prerm" "$(THEOS_STAGING_DIR)/DEBIAN/prerm"; \
		chmod 0755 "$(THEOS_STAGING_DIR)/DEBIAN/prerm"; \
		echo "  [OK] prerm -> DEBIAN/prerm"; \
	else \
		echo "  [WARN] prerm khong ton tai trong thu muc goc — bo qua"; \
	fi
	@echo ""
	@echo "=== [BoostisCore] Create Filter Plist ==="
	@mkdir -p "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries"
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'	<key>Filter</key>' \
		'	<dict>' \
		'		<key>Bundles</key>' \
		'		<array>' \
		'			<string>com.apple.springboard</string>' \
		'			<string>com.apple.backboardd</string>' \
		'			<string>com.apple.Preferences</string>' \
		'			<string>com.apple.UIKit</string>' \
		'			<string>com.apple.UIKitCore</string>' \
		'		</array>' \
		'		<key>Executables</key>' \
		'		<array>' \
		'			<string>SpringBoard</string>' \
		'			<string>backboardd</string>' \
		'		</array>' \
		'	</dict>' \
		'</dict>' \
		'</plist>' > "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)"
	@chmod 644 "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)"
	@if [ -d "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications" ]; then \
		find "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications" -type d -name "*.app" -exec chmod -R 0755 {} +; \
		find "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications" -type f -perm +0111 -exec chmod 0755 {} +; \
	fi
	@echo "  [OK] Filter Plist created"
	@echo ""

before-package::
	@echo ""
	@echo "=== [BoostiPhone6sCore] Check DEB package ==="
	@PREFIX_PATH="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)"; \
	if [ -f "$$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.dylib" ]; then \
		echo "  [OK] Dylib found"; \
	else \
		echo "  [ERROR] Dylib missing!"; exit 1; \
	fi; \
	if [ -f "$$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)" ]; then \
		echo "  [OK] Filter Plist found"; \
	else \
		echo "  [ERROR] Filter Plist missing!"; exit 1; \
	fi; \
	if [ -f "$(THEOS_STAGING_DIR)/DEBIAN/postinst" ]; then \
		echo "  [OK] postinst found in DEBIAN/"; \
	else \
		echo "  [WARN] postinst missing in DEBIAN/ (se khong chay sau cai)"; \
	fi; \
	if [ -f "$(THEOS_STAGING_DIR)/DEBIAN/prerm" ]; then \
		echo "  [OK] prerm found in DEBIAN/"; \
	else \
		echo "  [WARN] prerm missing in DEBIAN/ (se khong chay truoc go)"; \
	fi; \
	echo "  [OK] Ready for DEB packaging"
	@echo ""
