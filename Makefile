ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6s

BoostiPhone6s_FILES = Tweak.xm

# ===================================================================
# QUAN TRỌNG: Các FLAGS dưới đây giúp fix lỗi Compile trên máy ảo
# ===================================================================
BoostiPhone6s_CFLAGS = \
    -fobjc-arc \
    -O3 \
    -Wno-deprecated-declarations \
    -Wno-unused-variable \
    -Wno-module-import-in-extern-c \
    -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip

# Đường dẫn thư viện (Framework)
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit
BoostiPhone6s_PRIVATE_FRAMEWORKS = AppSupport FrontBoardServices MobileCoreServices
BoostiPhone6s_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/library.mk

# ===================================================================
# FIX CẤU TRÚC THƯ MỤC DEBIAN CHO REPO NÀY
# ===================================================================
before-package::
	@echo "🛠️ Organizing Debian structure..."
	mkdir -p $(THEOBJ)/_/DEBIAN
	cp control $(THEOBJ)/_/DEBIAN/control
	cp postinst $(THEOBJ)/_/DEBIAN/postinst
	chmod 755 $(THEOBJ)/_/DEBIAN/postinst
	@if [ -f prerm ]; then cp prerm $(THEOBJ)/_/DEBIAN/prerm; chmod 755 $(THEOBJ)/_/DEBIAN/prerm; fi

after-install::
	install.exec "killall -9 SpringBoard backboardd"
