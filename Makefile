ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
# Tắt auto respring nếu cần
# INSTALL_TARGET_PROCESSES = SpringBoard backboardd 

include $(THEOS)/makefiles/common.mk

# ===================================================================
# PART 1: BUILD MAIN LIBRARY (TWEAK CORE LOGIC)
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
# ===================================================================
SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk


# ===================================================================
# PART 3: PACKAGING SCRIPT TỔNG HỢP (TỰ ĐỘNG TẠO USR VÀ COPY CORE)
# ===================================================================
before-package::
	@echo "Đang tự động tạo cấu trúc /usr/lib..."
	@mkdir -p .theos/_/usr/lib
	
	@echo "Đang copy BoostiPhone6sCore.dylib vào usr/lib..."
	@cp $(THEOS_OBJ_DIR)/BoostiPhone6sCore.dylib .theos/_/usr/lib/BoostiPhone6sCore.dylib
	@codesign -s - --entitlements "" .theos/_/usr/lib/BoostiPhone6sCore.dylib 2>/dev/null || true

	@echo "Đang hoàn tất DEBIAN control files..."
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	@if [ -f postinst ]; then cp postinst .theos/_/DEBIAN/postinst; chmod 755 .theos/_/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	@echo "Hoàn tất đóng gói!"
