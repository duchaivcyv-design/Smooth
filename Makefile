ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

# ===================================================================
# PART 1: BUILD MAIN LIBRARY (TWEEK CORE LOGIC) - ĐÃ SUCCESS
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
# PART 2: BUILD PREFERENCE BUNDLE (SETTINGS UI) - FIXED LINKER ERROR
# ===================================================================
INTERNAL_INSTALL_PREFIX = Library/PreferenceBundles
BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m

# ★ QUAN TRỌNG: Thêm đường dẫn tới thư mục Headers vừa tạo ★
BoostiPhone6sPrefs_INCLUDE_DIRS = Headers

# ★ KHÔNG LINK FRAMEWORK PREFERENCES NỮA ★
# Thay vào đó, ta rely vào Runtime Injection khi tweak chạy trên máy thật.
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation CoreGraphics

# CFlags cho Bundle
BoostiPhone6sPrefs_CFLAGS = \
    -fobjc-arc \
    -Wno-deprecated-declarations \
    -Wno-unused-variable

include $(THEOS_MAKE_PATH)/bundle.mk


# ===================================================================
# PACKAGING SCRIPT
# ===================================================================
before-package::
	@echo "🛠️ Packaging Files..."
	
	# 1. DEBIAN Structure
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	@cp postinst .theos/_/DEBIAN/postinst
	@chmod 755 .theos/_/DEBIAN/postinst
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	
	# 2. Copy Resources vào Bundle
	# Theos tự động build bundle vào .theos/_/Library/PreferenceBundles/...
	# Ta chỉ cần copy plist vào đó nếu chưa có sẵn trong source tree
	@mkdir -p .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle
	@cp Resources/root.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/root.plist
	@cp Resources/Info.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Info.plist
	
	@echo "✅ Structure Ready:"
	@ls -laR .theos/_/Library/PreferenceBundles/

after-install::
	install.exec "killall -9 SpringBoard backboardd"
