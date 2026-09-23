ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6s

# ★ DANH SÁCH FILE NGUỒN CUỐI CÙNG ★
# Đã thêm lại DeepExploit.c vì code đã được fix an toàn
BoostiPhone6s_FILES = Tweak.xm \
                      Modules/CacheCleaner.m \
                      Modules/CrashGuard.m \
                      Modules/SmartThermal.m \
                      Modules/DeepExploit.c

# ===================================================================
# COMPILER FLAGS
# ===================================================================
BoostiPhone6s_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -Wall \
    -Wno-unused-variable \
    -Wno-deprecated-declarations \
    -Wno-module-import-in-extern-c \
    -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip

# ===================================================================
# FRAMEWORKS (ONLY PUBLIC TO AVOID LINKER ERRORS)
# ===================================================================
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

# ★ KHÔNG LINK SUBSTRATE LIBRARY ★
# Rootless jailbreak tự động inject runtime.

include $(THEOS_MAKE_PATH)/library.mk

# ===================================================================
# PACKAGING LOGIC (SIMPLE & ROBUST)
# ===================================================================
before-package::
	@echo "🛠️ Packaging Files..."
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	@cp postinst .theos/_/DEBIAN/postinst
	@chmod 755 .theos/_/DEBIAN/postinst
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	@mkdir -p .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle
	@cp Resources/root.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/root.plist
	@cp Resources/Info.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Info.plist
	@echo "✅ Structure Ready:"
	@ls -laR .theos/_/Library/PreferenceBundles/

after-install::
	install.exec "killall -9 SpringBoard backboardd"
