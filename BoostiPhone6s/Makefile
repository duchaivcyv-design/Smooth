include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_INSTALL_INFO = Info.plist

BoostiPhone6sPrefs_RESOURCE_DIRS = Resources

BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation

# ★ SỬA: HARDCODE ĐÚNG TÊN SDK MÀ WORKFLOW ĐÃ TẢI VỀ ★
# Workflow build.yml tải iPhoneOS16.5.sdk vào $(THEOS)/sdks/
# $(THEOS_SDK_NAME) trống trên runner nên phải dùng đường dẫn trực tiếp
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -I../Headers \
                            -I. \
                            -F$(THEOS)/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks \
                            -DBUILDING_SUBPROJECT

BoostiPhone6sPrefs_LDFLAGS = -F$(THEOS)/sdks/iPhoneOS16.5.sdk/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk
