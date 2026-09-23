ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6s

BoostiPhone6s_FILES = Tweak.xm

# ===================================================================
# CFLAGS: Chống lỗi compile cũ & IOKit Module
# ===================================================================
BoostiPhone6s_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -Wno-deprecated-declarations \
    -Wno-unused-variable \
    -Wno-module-import-in-extern-c \
    -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip

# ===================================================================
# FRAMEWORKS: Chỉ giữ Public Frameworks để tránh lỗi Linker
# ===================================================================
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation

include $(THEOS_MAKE_PATH)/library.mk

# ===================================================================
# FIX LỖI DEBIAN STRUCTURE (VIẾT TRÊN 1 DÒNG ĐỂ TRÁNH SYNTAX ERROR)
# ===================================================================
before-package::
	@echo "🛠️ Organizing Debian structure for Rootless..." && \
	mkdir -p .theos/_/DEBIAN && \
	cp control .theos/_/DEBIAN/control && \
	cp postinst .theos/_/DEBIAN/postinst && \
	chmod 755 .theos/_/DEBIAN/postinst && \
	if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi && \
	echo "✅ Structure Ready:" && ls -la .theos/_/DEBIAN/

after-install::
	install.exec "killall -9 SpringBoard backboardd"
