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
# PART 3: PACKAGING SCRIPT CHUẨN ROOTLESS (SỬA LỖI TRÙNG VAR/JB)
# ===================================================================
before-package::
	@echo "Packaging for Rootless Jailbreak..."
	
	# 1. Dọn dẹp triệt để nếu có thư mục var dư thừa từ lần build cũ[span_0](start_span)[span_0](end_span)
	@rm -rf $(THEOS_STAGING_DIR)/var
	
	# 2. Tạo cấu trúc thư mục Staging chuẩn (THEOS_STAGING_DIR đã tự trỏ tới /var/jb)
	@mkdir -p $(THEOS_STAGING_DIR)/usr/lib
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceBundles
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Entries
	@mkdir -p $(THEOS_STAGING_DIR)/DEBIAN
	
	# 3. Copy dylib vào /usr/lib/
	@if [ -f $(THEOS_OBJ_DIR)/BoostiPhone6sCore.dylib ]; then \
	    cp $(THEOS_OBJ_DIR)/BoostiPhone6sCore.dylib $(THEOS_STAGING_DIR)/usr/lib/BoostiPhone6sCore.dylib; \
	fi
	
	# 4. Copy Bundle Settings từ subproject
	@if [ -d .theos/obj/BoostiPhone6s/BoostiPhone6sPrefs.bundle ]; then \
	    cp -r .theos/obj/BoostiPhone6s/BoostiPhone6sPrefs.bundle $(THEOS_STAGING_DIR)/Library/PreferenceBundles/; \
	    echo "[OK] Settings Bundle copied."; \
	fi
	
	# 5. Copy Entry Plist đăng ký Cài đặt
	@if [ -f BoostiPhone6s/layout/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist ]; then \
	    cp BoostiPhone6s/layout/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Entries/; \
	elif [ -f BoostiPhone6s/layout/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist ]; then \
	    cp BoostiPhone6s/layout/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Entries/; \
	fi
	
	# 6. Copy DEBIAN control & scripts
	@if [ -f control ]; then cp control $(THEOS_STAGING_DIR)/DEBIAN/control; fi
	@if [ -f postinst ]; then cp postinst $(THEOS_STAGING_DIR)/DEBIAN/postinst && chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm $(THEOS_STAGING_DIR)/DEBIAN/prerm && chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/prerm; fi
	
	@echo "✅ Rootless Package Ready!"
