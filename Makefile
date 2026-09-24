ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

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

# 1. Thêm -Wno-unknown-warning-option để Clang không dừng khi gặp flag lạ
# 2. Thay -Wno-multiply-defined (flag sai) bằng các flag chuẩn hóa Clang
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
# PART 3: PACKAGING SCRIPT CHUẨN ROOTLESS
# ===================================================================
before-package::
	@echo "Packaging for Rootless Jailbreak..."
	
	# 1. Tạo cấu trúc thư mục Rootless chuẩn
	@mkdir -p $(THEOS_STAGING_DIR)/var/jb/usr/lib
	@mkdir -p $(THEOS_STAGING_DIR)/var/jb/Library/PreferenceBundles
	@mkdir -p $(THEOS_STAGING_DIR)/var/jb/Library/PreferenceLoader/Entries
	@mkdir -p $(THEOS_STAGING_DIR)/DEBIAN
	
	# 2. Copy dylib vào /var/jb/usr/lib/
	@if [ -f $(THEOS_OBJ_DIR)/BoostiPhone6sCore.dylib ]; then \
	    cp $(THEOS_OBJ_DIR)/BoostiPhone6sCore.dylib $(THEOS_STAGING_DIR)/var/jb/usr/lib/BoostiPhone6sCore.dylib; \
	fi
	
	# 3. Copy Bundle Settings từ subproject
	@if [ -d .theos/obj/BoostiPhone6s/BoostiPhone6sPrefs.bundle ]; then \
	    cp -r .theos/obj/BoostiPhone6s/BoostiPhone6sPrefs.bundle $(THEOS_STAGING_DIR)/var/jb/Library/PreferenceBundles/; \
	    echo "[OK] Settings Bundle copied."; \
	fi
	
	# 4. Copy Entry Plist đăng ký Cài đặt
	@if [ -f BoostiPhone6s/layout/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist ]; then \
	    cp BoostiPhone6s/layout/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist $(THEOS_STAGING_DIR)/var/jb/Library/PreferenceLoader/Entries/; \
	elif [ -f BoostiPhone6s/layout/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist ]; then \
	    cp BoostiPhone6s/layout/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist $(THEOS_STAGING_DIR)/var/jb/Library/PreferenceLoader/Entries/; \
	fi
	
	# 5. Copy DEBIAN control & scripts
	@if [ -f control ]; then cp control $(THEOS_STAGING_DIR)/DEBIAN/control; fi
	@if [ -f postinst ]; then cp postinst $(THEOS_STAGING_DIR)/DEBIAN/postinst && chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm $(THEOS_STAGING_DIR)/DEBIAN/prerm && chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/prerm; fi
	
	@echo "✅ Rootless Package Ready!"
