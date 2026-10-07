ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6sCore

BoostiPhone6sCore_INSTALL_PATH = /Library/MobileSubstrate/DynamicLibraries

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

# [ĐÃ SỬA]: Trỏ đúng tên thư mục con của App giao diện
SUBPROJECTS += BoostiPhone6sApp
include $(THEOS_MAKE_PATH)/aggregate.mk

BOOST_PLIST_NAME = BoostiPhone6sCore.plist

after-stage::
	@echo ""
	@echo "=== [BoostiPhone6sCore] Ép nhận toàn hệ thống qua Filter Plist ==="
	@TARGET_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries"; \
	mkdir -p "$$TARGET_DIR"; \
	printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>Filter</key>\n\t<dict>\n\t\t<key>Bundles</key>\n\t\t<array>\n\t\t\t<string>com.apple.UIKit</string>\n\t\t\t<string>com.apple.springboard</string>\n\t\t</array>\n\t\t<key>Executables</key>\n\t\t<array>\n\t\t\t<string>SpringBoard</string>\n\t\t</array>\n\t</dict>\n</dict>\n</plist>' > "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	APP_BUNDLE="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications/BoostiPhone6sApp.app"; \
	if [ -d "$$APP_BUNDLE" ]; then \
		chmod -R 0755 "$$APP_BUNDLE"; \
		chmod 0755 "$$APP_BUNDLE/BoostiPhone6sApp"; \
	fi; \
	echo "[OK] Đã cấu hình Filter nạp vào toàn bộ UIKit & SpringBoard!"
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
