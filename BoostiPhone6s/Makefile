include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_INSTALL_INFO = Info.plist

# ★ RESOURCES: Copy Root.plist và icon.png vào bundle wrapper ★
# Theos tự động copy mọi file trong Resources/ vào .bundle/
BoostiPhone6sPrefs_RESOURCE_DIRS = Resources

# Frameworks chuẩn
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

# ★ SỬA: THÊM -I ĐỂ TÌM HEADERS VÀ SDK PATH ĐỘNG ★
# -I../Headers: Tìm PSListController.h, PSSpecifier.h từ thư mục Headers/ gốc
# -I.: Tìm RootListController.h cùng thư mục
# $(THEOS_SDK_DIR): Tự động trỏ đến SDK đang dùng (không hardcode phiên bản)
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc \
                            -I../Headers \
                            -I. \
                            -F$(THEOS_SDK_DIR)/System/Library/PrivateFrameworks \
                            -DBUILDING_SUBPROJECT

BoostiPhone6sPrefs_LDFLAGS = -F$(THEOS_SDK_DIR)/System/Library/PrivateFrameworks

include $(THEOS_MAKE_PATH)/bundle.mk
