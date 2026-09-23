ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6s

# ★ LIỆT KÊ TẤT CẢ FILE NGUỒN (.xm, .m, .c) ★
BoostiPhone6s_FILES = Tweak.xm \
                      Modules/CacheCleaner.m \
                      Modules/DeepExploit.c \
                      Modules/CrashGuard.m \
                      Modules/SmartThermal.m

# ★ COMPILER FLAGS (Tối ưu hóa cao nhất) ★
BoostiPhone6s_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -Wall \
    -Wno-unused-variable \
    -Wno-deprecated-declarations \
    -Wno-module-import-in-extern-c \
    -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000 \
    -std=c11 \
    -funroll-loops \
    -ftree-vectorize

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip

# ★ FRAMEWORKS CẦN THIẾT CHO GOD MODE ★
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Preferences Metal CoreMedia CommonCrypto
BoostiPhone6s_PRIVATE_FRAMEWORKS = AppSupport FrontBoardServices MobileCoreServices GraphicsServices
BoostiPhone6s_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/library.mk

# ===================================================================
# PACKAGING SCRIPT (COPY RESOURCE & FIX PERMISSION)
# ===================================================================
before-package::
	@echo "🛠️ Packaging Files..." && \
	mkdir -p .theos/_/DEBIAN && \
	cp control .theos/_/DEBIAN/control && \
	cp postinst .theos/_/DEBIAN/postinst && \
	chmod 755 .theos/_/DEBIAN/postinst && \
	if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi && \
	
	# Copy Preference Bundle Resources
	mkdir -p .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle && \
	cp Resources/root.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/root.plist && \
	cp Resources/Info.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Info.plist && \
	
	echo "✅ Structure Ready:" && ls -laR .theos/_/Library/PreferenceBundles/

after-install::
	install.exec "killall -9 SpringBoard backboardd"
