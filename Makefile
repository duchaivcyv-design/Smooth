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
# FRAMEWORKS (ONLY PUBLIC TO AVOID LINKER ERRORS)
# ===================================================================
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

# Xóa Private Frameworks và Substrate Library để tránh lỗi link
# Code dùng Runtime Lookup nên không cần link tĩnh

include $(THEOS_MAKE_PATH)/library.mk

# ===================================================================
# PACKAGING SCRIPT (GỌI FILE SHELL RIÊNG ĐỂ TRÁNH LỖI SYNTAX MAKEFILE)
# ===================================================================
before-package::
	bash package.sh

after-install::
	install.exec "killall -9 SpringBoard backboardd"
