ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:14.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS =
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -O3 \
                            -Wall \
                            -Wno-error \
                            -Wno-deprecated-declarations \
                            -Wno-unknown-warning-option \
                            -Wno-unused-variable \
                            -Wno-unused-function \
                            -Wno-implicit-function-declaration \
                            -Wno-deprecated-non-prototype \
                            -fno-autolink \
                            -I$(THEOS)/include \
                            -I$(THEOS)/vendor/include \
                            -I../Headers \
                            -I../Modules \
                            -I../ \
                            -I.

BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-undefined,dynamic_lookup \
                            -Wl,-install_name,@rpath/BoostiPhone6sPrefs \
                            -Wl,-rpath,/System/Library/PrivateFrameworks \
                            -Wl,-rpath,/Library/Frameworks \
                            -Wl,-rpath,/var/jb/Library/Frameworks \
                            -Wl,-rpath,/usr/lib \
                            -Wl,-rpath,/var/jb/usr/lib

include $(THEOS_MAKE_PATH)/bundle.mk

after-package::
	rm -rf .theos/ _/
