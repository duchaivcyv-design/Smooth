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
# Lưu ý: Nếu bạn vẫn còn DeepExploit.c, hãy thêm nó vào đây. 
# Nhưng tốt nhất nên xóa file .c đi vì logic đã nằm hết trong Tweak.xm rồi.

# ===================================================================
# CFLAGS CHUNG (Áp dụng cho .xm và .m)
# ★ ĐÃ LOẠI BỎ -std=c11 ĐỂ TRÁNH LỖI VỚI OBJECTIVE-C++ ★
# ===================================================================
BoostiPhone6s_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -Wall \
    -Wno-unused-variable \
    -Wno-deprecated-declarations \
    -Wno-module-import-in-extern-c \
    -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

# ===================================================================
# CFLAGS RIÊNG CHO FILE .C (Nếu có)
# Nếu bạn có file .c thuần túy, hãy uncomment dòng dưới và chỉ định tên file
# ===================================================================
# BoostiPhone6s_c_CFLAGS = -std=c11 -O3

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip

# Frameworks cần thiết
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Preferences Metal CommonCrypto
BoostiPhone6s_PRIVATE_FRAMEWORKS = AppSupport FrontBoardServices MobileCoreServices GraphicsServices
BoostiPhone6s_LIBRARIES = substrate

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
