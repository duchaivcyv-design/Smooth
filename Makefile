ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

# ===================================================================
# PART 1: BUILD MAIN LIBRARY (TWEEK CORE LOGIC)
# ===================================================================
LIBRARY_NAME = BoostiPhone6s

# Liệt kê các file source cho library chính
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

# CHỈ DÙNG PUBLIC FRAMEWORKS ĐỂ TRÁNH LỖI LINKER
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

include $(THEOS_MAKE_PATH)/library.mk


# ===================================================================
# PART 2: BUILD PREFERENCE BUNDLE (SETTINGS UI)
# ★ ĐÂY LÀ PHẦN GIÚP MENU CÀI ĐẶT HIỆN RA ★
# ===================================================================
INTERNAL_INSTALL_PREFIX = Library/PreferenceBundles
BUNDLE_NAME = BoostiPhone6sPrefs

# Chỉ định file controller nằm ở thư mục GỐC (vừa di chuyển ở Bước 1)
BoostiPhone6sPrefs_FILES = RootListController.m

# Đường dẫn cài đặt bundle
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# Frameworks cho Settings UI
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation CoreGraphics Preferences
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = AppSupport # Nếu lỗi xóa dòng này đi
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk


# ===================================================================
# PACKAGING SCRIPT (COPY RESOURCES VÀO ĐÚNG CHỖ)
# ===================================================================
before-package::
	@echo "🛠️ Packaging Files..."
	
	# 1. Tạo cấu trúc DEBIAN
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	@cp postinst .theos/_/DEBIAN/postinst
	@chmod 755 .theos/_/DEBIAN/postinst
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	
	# 2. Copy Resources vào Bundle đã được Theos tự động build
	# Theos sẽ tạo folder .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle
	# Ta chép plist vào đó
	@mkdir -p .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle
	@cp Resources/root.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/root.plist
	@cp Resources/Info.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Info.plist
	
	@echo "✅ Structure Ready:"
	@ls -laR .theos/_/Library/PreferenceBundles/

after-install::
	install.exec "killall -9 SpringBoard backboardd"
