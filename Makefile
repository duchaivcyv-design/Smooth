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
# FRAMEWORKS & LIBRARIES (ĐÃ SỬA LỖI LINKER)
# ★ ĐÃ LOẠI BỎ 'CommonCrypto' VÌ NÓ KHÔNG PHẢI FRAMEWORK ★
# Code hiện tại chỉ dùng NSUserDefaults nên không cần lib crypto.
# ===================================================================
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

# Các framework private thường có stub header trong Theos, nhưng nếu vẫn lỗi 
# thì hãy xóa bớt những cái không dùng trực tiếp. 
# AppSupport/FrontBoardServices thường an toàn hơn GraphicsServices/MobileCoreServices trên SDK mới.
BoostiPhone6s_PRIVATE_FRAMEWORKS = AppSupport FrontBoardServices 

# Nếu cần link thêm lib khác (như substrate), để ở đây.
# Nhưng với Rootless Jailbreak (ElleKit/Substitute), ta thường KHÔNG link substrate 
# mà rely vào runtime injection. Để trống hoặc comment đi nếu build pass.
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
