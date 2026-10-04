ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

# ĐỒNG BỘ CHÍNH XÁC TÊN BUNDLE VỚI ENTRY.PLIST VÀ THƯ MỤC
BUNDLE_NAME = BoostiPhone6s

BoostiPhone6s_FILES = RootListController.m
BoostiPhone6s_FRAMEWORKS = UIKit CoreGraphics Foundation
# 👈 BẮT BUỘC PHẢI CÓ Preferences ĐỂ KHÔNG BỊ DYLD ERROR KHI LOAD BUNDLE
BoostiPhone6s_PRIVATE_FRAMEWORKS =
BoostiPhone6s_INSTALL_PATH = /Library/PreferenceBundles

BoostiPhone6s_CFLAGS = -fobjc-arc \
                       -O3 \
                       -Wall \
                       -Wno-error \
                       -Wno-deprecated-declarations \
                       -Wno-unused-variable \
                       -Wno-unused-function \
                       -Wno-implicit-function-declaration \
                       -Wno-deprecated-non-prototype \
                       -I$(THEOS)/include \
                       -I$(THEOS)/vendor/include \
                       -I../Headers \
                       -I../Modules \
                       -I../ \
                       -I.

BoostiPhone6s_LDFLAGS = -Wl,-dead_strip \
                       -Wl,-undefined,dynamic_lookup \
                       -Wl,-rpath,/System/Library/PrivateFrameworks \
                       -Wl,-rpath,/Library/Frameworks \
                       -Wl,-rpath,/var/jb/Library/Frameworks \
                       -Wl,-rpath,/usr/lib \
                       -Wl,-rpath,/var/jb/usr/lib

include $(THEOS_MAKE_PATH)/bundle.mk

# TỰ ĐỘNG ĐƯA ENTRY.PLIST VÀO PREFERENCELOADER ĐỂ HIỆN TRONG SETTINGS
internal-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/PreferenceLoader/Preferences"
	@if [ -f "entry.plist" ]; then \
		cp entry.plist "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/PreferenceLoader/Preferences/BoostiPhone6s.plist"; \
		chmod 644 "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/PreferenceLoader/Preferences/BoostiPhone6s.plist"; \
	fi
