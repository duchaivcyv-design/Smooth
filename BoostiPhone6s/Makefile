ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

# ===================================================================
# BUILD PREFERENCE BUNDLE (SETTINGS UI ONLY)
# ===================================================================
INTERNAL_INSTALL_PREFIX = Library/PreferenceBundles
BUNDLE_NAME = BoostiPhone6sPrefs

# Code nguồn cho bundle
BoostiPhone6sPrefs_FILES = RootListController.m

# ★ QUAN TRỌNG: Chỉ định folder Resources nằm ngay cạnh Makefile này ★
BoostiPhone6sPrefs_RESOURCES_DIR = Resources

# Frameworks cần thiết cho UI Settings
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation CoreGraphics Preferences
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

BoostiPhone6sPrefs_LDFLAGS = -Wl,-undefined,dynamic_lookup
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable

include $(THEOS_MAKE_PATH)/bundle.mk

# ===================================================================
# PACKAGING SCRIPT CHO RIÊNG FOLDER NÀY
# Copy entry.plist vào PreferenceLoader khi đóng gói cục bộ
# ===================================================================
before-package::
	@echo "Packaging Settings Bundle..."
	@mkdir -p .theos/_/Library/PreferenceLoader/Entries
	@if [ -f Resources/entry.plist ]; then \
	    cp Resources/entry.plist .theos/_/Library/PreferenceLoader/Entries/BoostiPhone6sPrefs.plist; \
	fi
	@echo "Done."
