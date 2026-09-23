ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
# INSTALL_TARGET_PROCESSES = SpringBoard backboardd # Comment dòng này để tránh auto-respring gây lỗi dpkg

include $(THEOS)/makefiles/common.mk

# ===================================================================
# PART 1: BUILD MAIN LIBRARY (TWEEK CORE LOGIC)
# ===================================================================
LIBRARY_NAME = BoostiPhone6s

BoostiPhone6s_FILES = Tweak.xm \
                      Modules/CacheCleaner.m \
                      Modules/CrashGuard.m \
                      Modules/SmartThermal.m \
                      Modules/DeepExploit.c \
                      Modules/KernelBypass.m \
                      Modules/SystemBlocker.m # ★ ĐẢM BẢO FILE NÀY CÓ TRONG FOLDER MODULES ★

BoostiPhone6s_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -Wall \
    -Wno-unused-variable \
    -Wno-deprecated-declarations \
    -Wno-module-import-in-extern-c \
    -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip

# ★ SỬA LỖI LINKER: ĐÃ XÓA 'CommonCrypto' KHỎI DANH SÁCH FRAMEWORKS ★
# CommonCrypto là lib system, không phải framework public cần link thủ công.
# Code Tweak.xm không dùng CC_SHA256 hay các hàm crypto phức tạp nên an toàn khi xóa.
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

include $(THEOS_MAKE_PATH)/library.mk


# ===================================================================
# PART 2: BUILD PREFERENCE BUNDLE (SETTINGS UI)
# ===================================================================
INTERNAL_INSTALL_PREFIX = Library/PreferenceBundles
BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INCLUDE_DIRS = Headers
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation CoreGraphics
BoostiPhone6sPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable

include $(THEOS_MAKE_PATH)/bundle.mk


# ===================================================================
# PACKAGING SCRIPT
# ===================================================================
before-package::
	@echo "🛠️ Packaging Files..."
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	@if [ -f postinst ]; then cp postinst .theos/_/DEBIAN/postinst; chmod 755 .theos/_/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	
	@mkdir -p .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle
	@cp Resources/root.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/root.plist
	@cp Resources/Info.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Info.plist
	
	@echo "Structure Ready:"
	@ls -laR .theos/_/Library/PreferenceBundles/

# after-install::
# 	install.exec "killall -9 SpringBoard backboardd" # Đã tắt để tránh lỗi dpkg interrupted
