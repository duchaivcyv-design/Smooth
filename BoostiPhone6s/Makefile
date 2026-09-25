include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = BoostiPhone6sPrefs

BoostiPhone6sPrefs_FILES = RootListController.m
# Subproject sẽ tự động kế thừa _INSTALL_PATH_TARGET = /var/jb từ project gốc
# Bundle sẽ được map chính xác vào /var/jb/Library/PreferenceBundles/
BoostiPhone6sPrefs_INSTALL_PATH = /Library/PreferenceBundles
BoostiPhone6sPrefs_INSTALL_INFO = Info.plist

# Frameworks chuẩn
BoostiPhone6sPrefs_FRAMEWORKS = UIKit Foundation
BoostiPhone6sPrefs_PRIVATE_FRAMEWORKS = Preferences

# Theos tự động resolve PrivateFrameworks trong SDK target.
# Flag -fobjc-arc là đủ, không cần ép đường dẫn SDK thủ công.
BoostiPhone6sPrefs_CFLAGS = -fobjc-arc -DBUILDING_SUBPROJECT

include $(THEOS_MAKE_PATH)/bundle.mk
