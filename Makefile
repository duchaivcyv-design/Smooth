ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
# Tắt auto respring
# INSTALL_TARGET_PROCESSES = SpringBoard backboardd 

include $(THEOS)/makefiles/common.mk

# ===================================================================
# PART 1: BUILD MAIN LIBRARY (TWEEK CORE LOGIC)
# ===================================================================
LIBRARY_NAME = BoostiPhone6sCore

BoostiPhone6sCore_FILES = Tweak.xm \
                          Modules/CacheCleaner.m \
                          Modules/CrashGuard.m \
                          Modules/SmartThermal.m \
                          Modules/DeepExploit.c \
                          Modules/KernelBypass.m \
                          Modules/SystemBlocker.m

BoostiPhone6sCore_CFLAGS = -fobjc-arc -O3 -Wall -Wno-unused-variable -Wno-deprecated-declarations -Wno-module-import-in-extern-c -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip
BoostiPhone6sCore_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal

include $(THEOS_MAKE_PATH)/library.mk


# ===================================================================
# PART 2: GỌI SUB-FOLDER CHỨA SETTINGS UI
# ★ CƠ CHẾ NATIVE: Theos sẽ cd vào BoostiPhone6s và chạy make ở đó ★
# Folder 'layout' bên trong sẽ tự động được map vào /var/jb/... khi package.
# ===================================================================
SUBPROJECTS += BoostiPhone6s


# ===================================================================
# PACKAGING SCRIPT TỔNG HỢP (CHỈ LO DEBIAN CONTROL FILES)
# ===================================================================
before-package::
	@echo "Finalizing Package..."
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	@if [ -f postinst ]; then cp postinst .theos/_/DEBIAN/postinst; chmod 755 .theos/_/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	@echo "Done."
