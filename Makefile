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
	@echo "=== [BoostiPhone6s] ĐỒNG BỘ FILTER & PREFERENCELOADER VÀO GÓI ROOTLESS ==="
	@# 1. ĐỒNG BỘ FILTER CHO DYLIB (LOẠI BỎ PREFERENCES ĐỂ CHỐNG XUNG ĐỘT RENDER)
	@TARGET_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries"; \
	mkdir -p "$$TARGET_DIR"; \
	printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>Filter</key>\n\t<dict>\n\t\t<key>Bundles</key>\n\t\t<array>\n\t\t\t<string>com.apple.UIKit</string>\n\t\t\t<string>com.apple.springboard</string>\n\t\t</array>\n\t\t<key>Executables</key>\n\t\t<array>\n\t\t\t<string>SpringBoard</string>\n\t\t</array>\n\t</dict>\n</dict>\n</plist>' > "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	chmod 644 "$$TARGET_DIR/$(BOOST_PLIST_NAME)"; \
	echo "[OK] Filter Plist đã cấu hình: $$TARGET_DIR/$(BOOST_PLIST_NAME)";
	
	@# 2. ĐỒNG BỘ ENTRY.PLIST VÀO PREFERENCELOADER (BẮT BUỘC ĐỂ HIỆN TRONG SETTINGS)
	@PREF_LOADER_DIR="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/PreferenceLoader/Preferences"; \
	mkdir -p "$$PREF_LOADER_DIR"; \
	if [ -f "BoostiPhone6s/entry.plist" ]; then \
		cp "BoostiPhone6s/entry.plist" "$$PREF_LOADER_DIR/BoostiPhone6s.plist"; \
		chmod 644 "$$PREF_LOADER_DIR/BoostiPhone6s.plist"; \
		echo "[OK] Nạp entry.plist từ thư mục BoostiPhone6s -> $$PREF_LOADER_DIR/BoostiPhone6s.plist"; \
	elif [ -f "layout/Library/PreferenceLoader/Preferences/BoostiPhone6s.plist" ]; then \
		cp "layout/Library/PreferenceLoader/Preferences/BoostiPhone6s.plist" "$$PREF_LOADER_DIR/BoostiPhone6s.plist"; \
		chmod 644 "$$PREF_LOADER_DIR/BoostiPhone6s.plist"; \
		echo "[OK] Nạp từ thư mục layout -> $$PREF_LOADER_DIR/BoostiPhone6s.plist"; \
	else \
		echo "⚠️ Tự động tạo BoostiPhone6s.plist cho PreferenceLoader..."; \
		printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>entry</key>\n\t<dict>\n\t\t<key>bundle</key>\n\t\t<string>BoostiPhone6s</string>\n\t\t<key>cell</key>\n\t\t<string>PSLinkCell</string>\n\t\t<key>detail</key>\n\t\t<string>RootListController</string>\n\t\t<key>isController</key>\n\t\t<true/>\n\t\t<key>label</key>\n\t\t<string>BoostiPhone6s</string>\n\t</dict>\n</dict>\n</plist>' > "$$PREF_LOADER_DIR/BoostiPhone6s.plist"; \
		chmod 644 "$$PREF_LOADER_DIR/BoostiPhone6s.plist"; \
		echo "[OK] Đã tự tạo thành công plist cho PreferenceLoader!"; \
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
	fi; \
	if [ -d "$$PREFIX_PATH/Library/PreferenceBundles/BoostiPhone6s.bundle" ]; then \
		echo "  [OK] Preference Bundle: $$PREFIX_PATH/Library/PreferenceBundles/BoostiPhone6s.bundle"; \
	else \
		echo "  [LỖI] Thiếu BoostiPhone6s.bundle trong PreferenceBundles!"; exit 1; \
	fi; \
	if [ -f "$$PREFIX_PATH/Library/PreferenceLoader/Preferences/BoostiPhone6s.plist" ]; then \
		echo "  [OK] PreferenceLoader Plist: $$PREFIX_PATH/Library/PreferenceLoader/Preferences/BoostiPhone6s.plist"; \
	else \
		echo "  [LỖI] Thiếu file nạp Settings trong PreferenceLoader/Preferences!"; exit 1; \
	fi
	@echo ""
