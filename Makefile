ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

# Biến này báo cho Theos biết: "Mọi thứ build ra hãy ném vào /var/jb/"
# Áp dụng cho cả Library chính lẫn Subproject BoostiPhone6s
_INSTALL_PATH_TARGET = /var/jb

include $(THEOS)/makefiles/common.mk

# ===================================================================
# PART 1: BUILD MAIN LIBRARY (TWEAK CORE LOGIC)
# ===================================================================
LIBRARY_NAME = BoostiPhone6sCore

BoostiPhone6sCore_FILES = Tweak.xm \
                          DeviceBypass.xm \
                          Modules/CacheCleaner.m \
                          Modules/CrashGuard.m \
                          Modules/SmartThermal.m \
                          Modules/DeepExploit.c \
                          Modules/KernelBypass.m \
                          Modules/SystemBlocker.m

# Các cờ dịch chuẩn hóa để tránh lỗi Clang trên GitHub Actions
BoostiPhone6sCore_CFLAGS = -fobjc-arc -O3 -Wall \
                           -Wno-unknown-warning-option \
                           -Wno-unused-variable \
                           -Wno-deprecated-declarations \
                           -Wno-module-import-in-extern-c \
                           -Wno-macro-redefined \
                           -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6sCore_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal
BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip -Wl,-no_warn_duplicate_libraries

include $(THEOS_MAKE_PATH)/library.mk

# ===================================================================
# PART 2: SUBPROJECT SETTINGS UI
# ===================================================================
SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

# ===================================================================
# PART 3: PACKAGING SCRIPT TINH GỌN (CHỈ LO DEBIAN CONTROL)
# ===================================================================
before-package::
	@echo "🚀 Finalizing Rootless Package..."
	
	# Hoàn tất DEBIAN control files
	@mkdir -p $(THEOS_STAGING_DIR)/DEBIAN
	@if [ -f control ]; then cp control $(THEOS_STAGING_DIR)/DEBIAN/control; fi
	@if [ -f postinst ]; then cp postinst $(THEOS_STAGING_DIR)/DEBIAN/postinst && chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm $(THEOS_STAGING_DIR)/DEBIAN/prerm && chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/prerm; fi
	
	@echo "✅ Rootless Package Ready! (Auto-mapped to /var/jb)"
