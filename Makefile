# ==============================================================
# V20 ULTIMATE ROOT MAKEFILE - TỰ TẠO FILE TỪ GỐC
# ==============================================================

ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

GO_EASY_ON_ME = 1
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

# ==============================================================
# PART 1: BUILD MAIN TWEAK & TỰ TẠO PLIST NGAY TỪ GỐC
# ==============================================================
TWEAK_NAME = BoostiPhone6sCore

BoostiPhone6sCore_FILES = Tweak.xm \
                          Modules/CacheCleaner.m \
                          Modules/CrashGuard.m \
                          Modules/SmartThermal.m \
                          Modules/DeepExploit.c \
                          Modules/KernelBypass.m \
                          Modules/SystemBlocker.m

BoostiPhone6sCore_CFLAGS = -fobjc-arc \
                           -O3 \
                           -Wall \
                           -Wno-error \
                           -Wno-logos \
                           -Wno-unknown-warning-option \
                           -Wno-unused-variable \
                           -Wno-deprecated-declarations \
                           -Wno-module-import-in-extern-c \
                           -Wno-macro-redefined \
                           -Wno-unused-function \
                           -Wno-implicit-function-declaration \
                           -D__IPHONE_OS_VERSION_MIN_REQUIRED=150000 \
                           -IHeaders \
                           -IModules \
                           -I.

BoostiPhone6sCore_FRAMEWORKS = UIKit \
                               CoreGraphics \
                               QuartzCore \
                               AVFoundation \
                               IOKit \
                               Foundation \
                               Metal \
                               CoreVideo \
                               Accelerate \
                               CoreServices

BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-exported_symbol,_init_privilege_escalation

include $(THEOS_MAKE_PATH)/tweak.mk

# ==============================================================
# PART 2: SUBPROJECT SETTINGS UI
# ==============================================================
SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

# ==============================================================
# PART 3: TỰ ĐỘNG BƠM VÀ ÉP THEOS NHẬN DIỆN
# ==============================================================
before-package::
	@echo "==> [V20] Ép tạo file BoostiPhone6sCore.plist vào Staging..."
	@mkdir -p $(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries
	@printf "{\n  Filter = {\n    Executables = ( \"SpringBoard\" );\n    Bundles = ( \"com.apple.springboard\", \"com.apple.UIKit\", \"com.apple.Preferences\" );\n  };\n}\n" > "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.plist"
	@chmod 644 "$(THEOS_STAGING_DIR)/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.plist"
	
	@mkdir -p $(THEOS_STAGING_DIR)/DEBIAN
	@if [ -f control ]; then cp control $(THEOS_STAGING_DIR)/DEBIAN/control; fi
	@if [ -f postinst ]; then cp postinst $(THEOS_STAGING_DIR)/DEBIAN/postinst; chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/postinst; fi
	@if [ -f prerm ]; then cp prerm $(THEOS_STAGING_DIR)/DEBIAN/prerm; chmod 755 $(THEOS_STAGING_DIR)/DEBIAN/prerm; fi
	@echo "Rootless Package V20 Ready!"
