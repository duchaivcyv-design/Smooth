ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

# Tat log rac, toi uu hoa goi bundle cho moi truong Production
DEBUG = 0
FINALPACKAGE = 1

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

# File ma nguon giao dien cai dat V24.7.1 Apex Supreme
BoostiPhone6sPrefs_FILES = RootListController.m

# Frameworks cong khai can thiet
BoostiPhone6sPrefs_FRAMEWORKS = UIKit CoreGraphics Foundation

# Thu muc cai dat bundle Rootless tieu chuan
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles

# Co Clang: Khong dung auto-link Preferences va triet tieu toan bo warning bien dich
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
                            -I../Headers \
                            -I../Modules \
                            -I../ \
                            -I.

# Bat buoc dung dynamic_lookup de bo qua kiem tra ky hieu PSListController luc link
BoostiPhone6sPrefs_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-undefined,dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
