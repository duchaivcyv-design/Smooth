ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
# ★ ĐÃ XÓA INSTALL_TARGET_PROCESSES ĐỂ TRÁNH AUTO RESPRING GÂY LỖI DPKG ★
# INSTALL_TARGET_PROCESSES = SpringBoard backboardd 

include $(THEOS)/makefiles/common.mk

# ===================================================================
# PART 1: BUILD MAIN LIBRARY (TWEEK CORE LOGIC)
# ===================================================================
LIBRARY_NAME = BoostiPhone6s

BoostiPhone6s_FILES = Tweak.xm \
                      Modules/CacheCleaner.m \
                      Modules/CrashGuard.m \
                      Modules/SmartThermal.m \
                      Modules/DeepExploit.c

BoostiPhone6s_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -Wall \
    -Wno-unused-variable \
    -Wno-deprecated-declarations \
    -Wno-module-import-in-extern-c \
    -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

include $(THEOS_MAKE_PATH)/library.mk


# ===================================================================
# PART 2: BUILD PREFERENCE BUNDLE (SETTINGS UI)
# ===================================================================
INTERNAL_INSTALL_PREFIX = Library/PreferenceBundles
BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m

# ★ QUAN TRỌNG: Chỉ định thư mục chứa header giả lập ★
BoostiPhone6sPrefs_INCLUDE_DIRS = Headers

# ★ KHÔNG LINK FRAMEWORK PREFERENCES TRỰC TIẾP ★
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation CoreGraphics

# ★ CỜ LINKER THẦN THÁNH CHO JAILBREAK ROOTLESS ★
# Cho phép binary chạy dù thiếu symbol lúc compile (sẽ resolve lúc runtime)
BoostiPhone6sPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup

BoostiPhone6sPrefs_CFLAGS = \
    -fobjc-arc \
    -Wno-deprecated-declarations \
    -Wno-unused-variable

include $(THEOS_MAKE_PATH)/bundle.mk


# ===================================================================
# PACKAGING SCRIPT (AN TOÀN HƠN)
# ===================================================================
before-package::
	@echo "🛠️ Packaging Files..."
	
	# 1. Tạo cấu trúc DEBIAN chuẩn
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	
	# ★ COPY SCRIPT VỚI QUYỀN EXECUTE ĐẦY ĐỦ ★
	@if [ -f postinst ]; then cp postinst .theos/_/DEBIAN/postinst; chmod 755 .theos/_/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	
	# 2. Copy Resources vào Bundle đã build
	# Theos tự tạo folder bundle, ta chỉ cần nhét plist vào đó
	@mkdir -p .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle
	@cp Resources/root.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/root.plist
	@cp Resources/Info.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Info.plist
	
	@echo "✅ Structure Ready:"
	@ls -laR .theos/_/Library/PreferenceBundles/

# • ĐÃ COMMENT DÒNG NÀY ĐỂ TRÁNH LỖI DPKG INTERRUPTED ★
after-install::
	install.exec "killall -9 SpringBoard backboardd"
