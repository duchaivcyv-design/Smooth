ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

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

BoostiPhone6sCore_PRIVATE_FRAMEWORKS = IOKit BackBoardServices

BoostiPhone6sCore_LIBRARIES = substrate

BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip \
                            -undefined dynamic_lookup \
                            -Wl,-no_fixup_chains \
                            -lpthread

# Ký Entitlements đặc quyền cao cho SpringBoard & backboardd
BoostiPhone6sCore_CODESIGN_FLAGS = -SBoostiPhone6sCore.entitlements

include $(THEOS_MAKE_PATH)/library.mk

# Quản lý subproject App
SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

BOOST_PLIST_NAME = BoostiPhone6sCore.plist

before-all::
	@echo ""
	@echo "=== [BoostiPhone6sCore] Tự động khởi tạo file Entitlements đặc quyền ==="
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'	<key>com.apple.private.hid.client.event-filter</key>' \
		'	<true/>' \
		'	<key>com.apple.private.iokit.system-nvram-allow</key>' \
		'	<true/>' \
		'	<key>com.apple.backboardd.launchapplications</key>' \
		'	<true/>' \
		'</dict>' \
		'</plist>' > BoostiPhone6sCore.entitlements
	@echo "  [OK] Đã tạo BoostiPhone6sCore.entitlements!"

after-stage::
	@echo ""
	@echo "=== [BoostiPhone6sCore] Tự động tạo Filter Plist chuẩn XNU ==="
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
	@echo "  [OK] Đã hoàn tất gán quyền Staging và tạo Filter Plist!"
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
	fi
	@echo "  [OK] Cấu trúc gói đã sẵn sàng đóng gói DEB!"
	@echo ""
