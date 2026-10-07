ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6sCore

BoostiPhone6sCore_INSTALL_PATH = $(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries

BoostiPhone6sCore_FILES = Tweak.xm
                          
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
                           -D__IPHONE_OS_VERSION_MIN_REQUIRED=140000 \
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
                            -lpthread

include $(THEOS_MAKE_PATH)/library.mk

# Quản lý subproject App
SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

BOOST_PLIST_NAME = BoostiPhone6sCore.plist

after-stage::
	@echo ""
	@echo "=== [BoostiPhone6sCore] Tự động tạo Filter Plist (UIKit, SpringBoard, Preferences) ==="
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
		'			<string>com.apple.UIKit</string>' \
		'			<string>com.apple.springboard</string>' \
		'			<string>com.apple.Preferences</string>' \
		'		</array>' \
		'		<key>Executables</key>' \
		'		<array>' \
		'			<string>SpringBoard</string>' \
		'		</array>' \
		'	</dict>' \
		'</dict>' \
		'</plist>' > "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)"
	@chmod 644 "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)"
	@if [ -d "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications/BoostiPhone6sApp.app" ]; then \
		chmod -R 0755 "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications/BoostiPhone6sApp.app"; \
		chmod 0755 "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications/BoostiPhone6sApp.app/BoostiPhone6sApp"; \
	fi
	@echo "  [OK] Đã tự tạo Filter nạp vào UIKit, SpringBoard & Preferences!"
	@echo ""

before-package::
	@echo ""
	@echo "=== [BoostiPhone6sCore] Kiểm tra tính toàn vẹn gói DEB ==="
	@PREFIX_PATH="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)"; \
	if [ -f "$$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.dylib" ]; then \
		echo "  [OK] Dylib: $$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.dylib"; \
	else \
		echo "  [LỖI] Dylib BoostiPhone6sCore chưa được tạo!"; exit 1; \
	fi; \
	if [ -f "$$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)" ]; then \
		echo "  [OK] Filter Plist: $$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)"; \
	else \
		echo "  [LỖI] Filter Plist thiếu!"; exit 1; \
	fi; \
	if [ -f "$$PREFIX_PATH/Applications/BoostiPhone6sApp.app/BoostiPhone6sApp" ]; then \
		echo "  [OK] App Binary: $$PREFIX_PATH/Applications/BoostiPhone6sApp.app/BoostiPhone6sApp"; \
	else \
		echo "  [LỖI] Binary App thiếu trong Staging!"; exit 1; \
	fi
	@echo ""
