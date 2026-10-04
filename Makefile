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
                           -Wno-deprecated-declarations \
                           -Wno-unused-function \
                           -Wno-implicit-function-declaration \
                           -Wno-deprecated-non-prototype \
                           -Wno-macro-redefined \
                           -Wno-module-import-in-extern-c \
                           -Wno-unguarded-availability-new \
                           -Wno-unguarded-availability \
                           -D__IPHONE_OS_VERSION_MIN_REQUIRED=140000 \
                           -DBUILDING_LIBRARY=1 \
                           -IHeaders \
                           -IModules \
                           -I.

BoostiPhone6sCore_FRAMEWORKS = UIKit \
                               CoreGraphics \
                               QuartzCore \
                               AVFoundation \
                               Foundation \
                               Metal \
                               CoreVideo \
                               Accelerate \
                               CoreServices

BoostiPhone6sCore_PRIVATE_FRAMEWORKS = IOKit

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

after-stage::
	@echo ""
	@echo "=== [BoostiPhone6sCore] Đồng bộ Filter Plist chuẩn hóa ==="
	@TARGET_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries"; \
	mkdir -p "$$TARGET_DIR"; \
	printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>Filter</key>\n\t<dict>\n\t\t<key>Bundles</key>\n\t\t<array>\n\t\t\t<string>com.apple.UIKit</string>\n\t\t\t<string>com.apple.springboard</string>\n\t\t</array>\n\t\t<key>Executables</key>\n\t\t<array>\n\t\t\t<string>SpringBoard</string>\n\t\t</array>\n\t</dict>\n</dict>\n</plist>' > "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	echo "[OK] Đã xuất Filter Plist sạch (đã loại bỏ Preferences để chống crash Settings)!"; \
	echo ""

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
