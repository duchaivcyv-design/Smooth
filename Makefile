ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
# Tắt auto respring
# INSTALL_TARGET_PROCESSES = SpringBoard backboardd 

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

BoostiPhone6s_CFLAGS = -fobjc-arc -O3 -Wall -Wno-unused-variable -Wno-deprecated-declarations -Wno-module-import-in-extern-c -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

include $(THEOS_MAKE_PATH)/library.mk


# ===================================================================
# PART 2: CALL SUB-MAKE FOR SETTINGS BUNDLE
# ★ SỬ DỤNG CƠ CHẾ 'SUBPROJECTS' CỦA THEOS ★
# Theos sẽ tự động cd vào folder BoostiPhone6s và chạy Makefile ở đó.
# Kết quả (.bundle) sẽ được gom chung vào package .deb cuối cùng.
# ===================================================================
SUBPROJECTS += BoostiPhone6s


# ===================================================================
# PACKAGING SCRIPT TỔNG HỢP (CHỈ LO DEBIAN CONTROL FILES)
# Không cần copy resources hay entries nữa vì Subproject đã lo hết.
# ===================================================================
before-package::
	@echo "Finalizing Package..."
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	@if [ -f postinst ]; then cp postinst .theos/_/DEBIAN/postinst; chmod 755 .theos/_/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	@echo "✅ All Done."
