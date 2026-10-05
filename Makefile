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

# CỜ BIÊN DỊCH C / OBJC: TỐI ƯU HÓA O3 & GIẢM DUNG LƯỢNG BINARY
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
                           -IModules \
                           -I.

# ĐỒNG BỘ CỜ CHO TWEAK.XM.MM: NẠP CHUẨN C++17 VÀ KẾ THỪA CFLAGS
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
                               CoreServices \
                               IOKit

# BẢO ĐẢM TƯƠNG THÍCH MỌI MÔI TRƯỜNG JAILBREAK ROOTLESS & ROOTHIDE
BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-undefined,dynamic_lookup \
                            -lpthread

include $(THEOS_MAKE_PATH)/library.mk

SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

BOOST_PLIST_NAME = BoostiPhone6sCore.plist

after-stage::
	@echo ""
	@echo "=== [BoostiPhone6sCore] Đồng bộ Filter Plist vào Staging ==="
	@TARGET_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries"; \
	mkdir -p "$$TARGET_DIR"; \
	if [ -f "$(BOOST_PLIST_NAME)" ]; then \
		cp "$(BOOST_PLIST_NAME)" "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
		chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
		echo "[OK] Nạp filter plist từ root: $$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	elif [ -f "BoostiPhone6s.plist" ]; then \
		cp "BoostiPhone6s.plist" "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
		chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
		echo "[OK] Nạp filter plist từ BoostiPhone6s.plist đổi tên thành $(BOOST_PLIST_NAME)"; \
	else \
		echo "[WARN] Tạo tự động filter plist tiêu chuẩn cho $(BOOST_PLIST_NAME)..."; \
		printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>Filter</key>\n\t<dict>\n\t\t<key>Bundles</key>\n\t\t<array>\n\t\t\t<string>com.apple.UIKit</string>\n\t\t\t<string>com.apple.springboard</string>\n\t\t\t<string>com.apple.Preferences</string>\n\t\t\t<string>com.apple.TextInputUI</string>\n\t\t\t<string>com.apple.InputUI</string>\n\t\t</array>\n\t\t<key>Executables</key>\n\t\t<array>\n\t\t\t<string>SpringBoard</string>\n\t\t\t<string>Preferences</string>\n\t\t</array>\n\t</dict>\n</dict>\n</plist>' > "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
		chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
		echo "[OK] Đã xuất filter plist tự động!"; \
	fi
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
	@echo ""
