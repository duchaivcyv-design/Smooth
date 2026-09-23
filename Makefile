ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
INSTALL_TARGET_PROCESSES = SpringBoard backboardd

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6s

BoostiPhone6s_FILES = Tweak.xm

# ===================================================================
# CFLAGS: Giữ nguyên các cờ chống lỗi compile cũ
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
# FRAMEWORKS: CHỈ GIỮ LẠI CÁC FRAMEWORK CÔNG KHAI (PUBLIC)
# XÓA BỎ DÒNG _PRIVATE_FRAMEWORKS VÌ NÓ GÂY LỖI LINKER
# ===================================================================
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation

# Lưu ý: Không thêm substrate vào LIBRARIES nếu bạn dùng Substitute/ElleKit 
# cho rootless jailbreak mới. Nhưng nếu repo cũ vẫn dùng Cydia Substrate thì giữ lại.
# Để an toàn nhất cho build deb rootless hiện nay, ta thường KHÔNG link substrate 
# mà rely vào runtime injection. Tuy nhiên, nếu bắt buộc phải link:
# BoostiPhone6s_LIBRARIES = substrate 

include $(THEOS_MAKE_PATH)/library.mk

before-package::
	@echo "🛠️ Organizing Debian structure..."
	mkdir -p $(THEOBJ)/_/DEBIAN
	cp control $(THEOBJ)/_/DEBIAN/control
	cp postinst $(THEOBJ)/_/DEBIAN/postinst
	chmod 755 $(THEOBJ)/_/DEBIAN/postinst
	@if [ -f prerm ]; then cp prerm $(THEOBJ)/_/DEBIAN/prerm; chmod 755 $(THEOBJ)/_/DEBIAN/prerm; fi

after-install::
	install.exec "killall -9 SpringBoard backboardd"
