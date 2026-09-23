ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

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
                      Modules/SystemBlocker.m

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
BoostiPhone6sPrefs_INCLUDE_DIRS = Headers
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation CoreGraphics
BoostiPhone6sPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable

include $(THEOS_MAKE_PATH)/bundle.mk


# ===================================================================
# PACKAGING SCRIPT (FIXED PATH FOR ENTRY.PLIST)
# ===================================================================
before-package::
	@echo "🛠️ Packaging Files..." && \
	mkdir -p .theos/_/DEBIAN && \
	cp control .theos/_/DEBIAN/control && \
	if [ -f postinst ]; then cp postinst .theos/_/DEBIAN/postinst; chmod 755 .theos/_/DEBIAN/postinst; fi && \
	if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi && \
	
	echo "📦 Installing Bundle Resources..." && \
	mkdir -p .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle && \
	cp Resources/root.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/root.plist && \
	cp Resources/Info.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Info.plist && \
	
	echo "🔗 Registering with PreferenceLoader..." && \
	mkdir -p .theos/_/Library/PreferenceLoader/Entries && \
	# ★ SỬA ĐƯỜNG DẪN Ở ĐÂY: Lấy từ thư mục gốc (/), KHÔNG phải Resources/ ★
	cp entry.plist .theos/_/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist && \
	
	echo "✅ Structure Ready:" && \
	ls -laR .theos/_/Library/PreferenceLoader/

after-install::
	install.exec "killall -9 SpringBoard backboardd"
