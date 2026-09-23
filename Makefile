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
# ===================================================================
SUBPROJECTS += BoostiPhone6s


# ===================================================================
# PACKAGING SCRIPT TỔNG HỢP
# ===================================================================
before-package::
	@echo "Finalizing Package..."
	@mkdir -p .theos/_/DEBIAN
	@cp control .theos/_/DEBIAN/control
	@if [ -f postinst ]; then cp postinst .theos/_/DEBIAN/postinst; chmod 755 .theos/_/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm .theos/_/DEBIAN/prerm; chmod 755 .theos/_/DEBIAN/prerm; fi
	
	# Đường dẫn đích trong package: /Library/PreferenceBundles/
	@mkdir -p .theos/_/Library/PreferenceBundles
	
	# Tìm xem bundle đã build xong chưa (thường nằm trong .theos/obj hoặc similar)
	# Cách an toàn nhất là copy trực tiếp từ folder source nếu build local fail
	# Nhưng vì dùng GitHub Actions, ta tin tưởng vào SUBPROJECTS. 
	# Tuy nhiên, để chắc ăn, ta sẽ verify sự tồn tại của nó trong staging area.
	
	@if [ ! -d ".theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle" ]; then \
	    echo "Warning: Bundle not found in standard location. Attempting manual copy from source..."; \
	    mkdir -p .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle; \
	    if [ -d "BoostiPhone6s/.theos/obj/debugfinal/BoostiPhone6sPrefs.bundle" ]; then \
	        cp -r BoostiPhone6s/.theos/obj/debugfinal/BoostiPhone6sPrefs.bundle/* .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/; \
	    elif [ -d "BoostiPhone6s/Resources" ]; then \
	        # Fallback: Copy resources manually if binary missing (rare case)
	        cp -r BoostiPhone6s/Resources/* .theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle/; \
	    fi; \
	fi

	@echo "All Done."
