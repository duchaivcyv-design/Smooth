include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_INSTALL_INFO = Info.plist

BoostiPhone6sPrefs_RESOURCE_DIRS = Resources

BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation

# Theos tự động thêm -framework Preferences nhưng không tìm thấy đường dẫn
# Ta tự thêm -F trỏ đến PrivateFrameworks trong SDK đang dùng
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -I../Headers \
                            -I. \
                            -DBUILDING_SUBPROJECT

BoostiPhone6sPrefs_LDFLAGS = -F$(THEOS)/sdks/$(THEOS_SDK_NAME)/System/Library/PrivateFrameworks \
                             -framework Preferences

include $(THEOS_MAKE_PATH)/bundle.mk
