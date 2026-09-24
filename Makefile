ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0
# Tắt auto respring nếu cần
# INSTALL_TARGET_PROCESSES = SpringBoard backboardd 

include $(THEOS)/makefiles/common.mk

# ===================================================================
# PART 1: BUILD MAIN LIBRARY (TWEAK CORE LOGIC)
# ===================================================================
LIBRARY_NAME = BoostiPhone6sCore

# ★ GIỮ NGUYÊN DANH SÁCH FILE CŨ CỦA BẠN ★
BoostiPhone6sCore_FILES = Tweak.xm \
                          DeviceBypass.xm
                          Modules/CacheCleaner.m \
                          Modules/CrashGuard.m \
                          Modules/SmartThermal.m \
                          Modules/DeepExploit.c \
                          Modules/KernelBypass.m \
                          Modules/SystemBlocker.m \

BoostiPhone6sCore_CFLAGS = -fobjc-arc -O3 -Wall -Wno-unused-variable -Wno-deprecated-declarations -Wno-module-import-in-extern-c -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000

BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip
BoostiPhone6sCore_FRAMEWORKS = UIKit CoreGraphics QuartzCore AVFoundation IOKit Foundation Metal
BoostiPhone6sCore_PRIVATE_FRAMEWORKS = Preferences

include $(THEOS_MAKE_PATH)/library.mk


# ===================================================================
# PART 2: GỌI SUB-FOLDER CHỨA SETTINGS UI
# ===================================================================
SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk


# ===================================================================
# PART 3: PACKAGING SCRIPT CHO ROOTLESS JAILBREAK
# ★ SỬA ĐƯỜNG DẪN /usr/lib THÀNH /var/jb/usr/lib ★
# ★ BỔ SUNG LỆNH COPY BUNDLE SETTINGS TỪ SUBPROJECT ★
# ===================================================================
before-package::
	@echo "🚀 Packaging for Rootless Jailbreak..."
	
	# 1. Tạo cấu trúc thư mục Rootless chuẩn cho Library
	@mkdir -p .theos/_/var/jb/usr/lib
	
	# 2. Copy dylib vào đúng vị trí Rootless (/var/jb/usr/lib/)
	@cp $(THEOS_OBJ_DIR)/BoostiPhone6sCore.dylib .theos/_/var/jb/usr/lib/BoostiPhone6sCore.dylib
	
	# 3. ★ QUAN TRỌNG: Copy Bundle Settings từ subproject vào package ★
	# Subproject BoostiPhone6s build ra bundle tại .theos/obj/BoostiPhone6s/
	# Ta phải copy thủ công vào staging area để nó nằm trong file .deb cuối cùng
	@mkdir -p .theos/_/var/jb/Library/PreferenceBundles
	@if [ -d .theos/obj/BoostiPhone6s/BoostiPhone6sPrefs.bundle ]; then \
	    cp -r .theos/obj/BoostiPhone6s/BoostiPhone6sPrefs.bundle .theos/_/var/jb/Library/PreferenceBundles/; \
	    echo "[OK] Settings Bundle copied to package."; \
	else \
	    echo "[WARN] Settings Bundle not found in subproject output!"; \
	fi
	
	# 4. Copy Entry Plist đăng ký menu Settings
	@mkdir -p .theos/_/var/jb/Library/PreferenceLoader/Entries
	@if [ -f BoostiPhone6s/layout/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist ]; then \
	    cp BoostiPhone6s/layout/var/jb/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist .theos/_/var/jb/Library/PreferenceLoader/Entries/; \
	    echo "[OK] PreferenceLoader Entry copied to package."; \
	else \
	    echo "[WARN] PreferenceLoader Entry plist not found!"; \
	fi
	
	# 5. Hoàn tất DEBIAN control files
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	@if [ -f postinst ]; then cp postinst .theos/_/DEBIAN/postinst; chmod 755 .theos/_/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	
	@echo "✅ Rootless Package Ready! (Library + Settings Bundle included)"
