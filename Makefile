ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6s

# Liệt kê tất cả source files
BoostiPhone6s_FILES = Tweak.xm \
                      Modules/CacheCleaner.m \
                      Modules/CrashGuard.m \
                      Modules/SmartThermal.m

# ===================================================================
# CFLAGS CHUNG
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
# FRAMEWORKS (ĐÃ SỬA LỖI LINKER TRIỆT ĐỂ)
# ★ CHỈ GIỮ LẠI PUBLIC FRAMEWORKS AN TOÀN NHẤT ★
# Đã xóa AppSupport, FrontBoardServices, GraphicsServices...
# Vì code dùng Runtime Lookup (objc_getClass) nên không cần link tĩnh.
# ===================================================================
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

# ★ ĐÃ XÓA HOÀN TOÀN DÒNG PRIVATE_FRAMEWORKS ★
# Nếu build pass thì không cần thêm lại.

# ★ ĐÃ COMMENT SUBSTRATE LIBRARY ★
# Rootless jailbreak (ElleKit/Substitute) thường tự động inject, 
# không cần link substrate lúc build để tránh lỗi symbol missing.
# BoostiPhone6s_LIBRARIES = substrate 

include $(THEOS_MAKE_PATH)/library.mk

before-package::
	@echo "🛠️ Packaging Files..." && \
	mkdir -p .theos/_/DEBIAN && \
	cp control .theos/_/DEBIAN/control && \
	cp postinst .theos/_/DEBIAN/postinst && \
	chmod 755 .theos/_/DEBIAN/postinst && \
	if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi && \
	
	mkdir -p .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle && \
	cp Resources/root.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/root.plist && \
	cp Resources/Info.plist .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/Info.plist && \
	
	echo "✅ Structure Ready:" && ls -laR .theos/_/Library/PreferenceBundles/

after-install::
	install.exec "killall -9 SpringBoard backboardd"
