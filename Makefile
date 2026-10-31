ARCHS = arm64 arm64e
TARGET := iphone:clang:latest:15.0

DEBUG = 0
FINALPACKAGE = 1
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

LIBRARY_NAME = BoostiPhone6sCore

BoostiPhone6sCore_INSTALL_PATH = $(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries

BoostiPhone6sCore_FILES = Tweak.xm \
                          TitaniumKernelOverdrive.m

BoostiPhone6sCore_CFLAGS = -fobjc-arc \
                           -O2 \
                           -g \
                           -fno-omit-frame-pointer \
                           -Wall \
                           -Wno-unused-variable \
                           -Wno-deprecated-declarations \
                           -Wno-unused-function \
                           -Wno-deprecated-non-prototype \
                           -Wno-macro-redefined \
                           -Wno-module-import-in-extern-c \
                           -Wno-unguarded-availability-new \
                           -Wno-unguarded-availability \
                           -Wno-unused-command-line-argument \
                           -DBUILDING_LIBRARY=1 \
                           -IHeaders \
                           -I.

BoostiPhone6sCore_OBJCXXFLAGS = $(BoostiPhone6sCore_CFLAGS) -std=gnu++17

BoostiPhone6sCore_FRAMEWORKS = UIKit \
                               CoreGraphics \
                               QuartzCore \
                               AVFoundation \
                               Foundation \
                               CoreFoundation \
                               Metal \
                               WebKit \
                               CoreVideo \
                               Accelerate \
                               CoreServices

BoostiPhone6sCore_PRIVATE_FRAMEWORKS = IOKit

BoostiPhone6sCore_LIBRARIES = substrate

BoostiPhone6sCore_LDFLAGS = -Wl,-dead_strip \
                            -Wl,-undefined,dynamic_lookup \
                            -Wl,-no_warn_duplicate_libraries \
                            -lpthread

include $(THEOS_MAKE_PATH)/library.mk

SUBPROJECTS += BoostiPhone6s
include $(THEOS_MAKE_PATH)/aggregate.mk

BOOST_PLIST_NAME = BoostiPhone6sCore.plist
BOOST_PLIST_DIR = $(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Library/MobileSubstrate/DynamicLibraries

after-stage::
	@mkdir -p "$(THEOS_STAGING_DIR)/DEBIAN"
	@if [ -f "postinst" ]; then \
		cp -f "postinst" "$(THEOS_STAGING_DIR)/DEBIAN/postinst"; \
		chmod 0755 "$(THEOS_STAGING_DIR)/DEBIAN/postinst"; \
	fi
	@if [ -f "prerm" ]; then \
		cp -f "prerm" "$(THEOS_STAGING_DIR)/DEBIAN/prerm"; \
		chmod 0755 "$(THEOS_STAGING_DIR)/DEBIAN/prerm"; \
	fi
	@mkdir -p "$(BOOST_PLIST_DIR)"
	@printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'	<key>Filter</key>' \
		'	<dict>' \
		'		<key>Mode</key>' \
		'		<string>Any</string>' \
		'		<key>Bundles</key>' \
		'		<array>' \
		'			<string>com.apple.springboard</string>' \
		'			<string>com.apple.backboardd</string>' \
		'			<string>com.apple.Preferences</string>' \
		'			<string>com.apple.mobilesafari</string>' \
		'			<string>com.apple.UIKit</string>' \
		'			<string>com.apple.UIKitCore</string>' \
		'		</array>' \
		'		<key>Executables</key>' \
		'		<array>' \
		'			<string>SpringBoard</string>' \
		'			<string>backboardd</string>' \
		'		</array>' \
		'		<key>Classes</key>' \
		'		<array>' \
		'			<string>UIApplication</string>' \
		'			<string>UIWindow</string>' \
		'			<string>UIWindowScene</string>' \
		'			<string>UIViewController</string>' \
		'			<string>UIView</string>' \
		'			<string>UIScrollView</string>' \
		'			<string>UITableView</string>' \
		'			<string>UICollectionView</string>' \
		'			<string>UITextView</string>' \
		'			<string>UITextField</string>' \
		'			<string>UIKeyboardImpl</string>' \
		'			<string>UIButton</string>' \
		'			<string>CALayer</string>' \
		'			<string>CAMetalLayer</string>' \
		'			<string>CADisplayLink</string>' \
		'			<string>CAAnimation</string>' \
		'			<string>CATransaction</string>' \
		'			<string>CADisplay</string>' \
		'			<string>CADisplayController</string>' \
		'			<string>CAWindowServer</string>' \
		'			<string>CAWindowServerDisplay</string>' \
		'			<string>WKWebView</string>' \
		'			<string>NSURLSessionConfiguration</string>' \
		'			<string>SBApplication</string>' \
		'			<string>SBUIController</string>' \
		'		</array>' \
		'	</dict>' \
		'</dict>' \
		'</plist>' > "$(BOOST_PLIST_DIR)/$(BOOST_PLIST_NAME)"
	@chmod 644 "$(BOOST_PLIST_DIR)/$(BOOST_PLIST_NAME)"
	@if [ -d "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications" ]; then \
		find "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications" -type d -exec chmod 0755 {} +; \
		find "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications" -type f -exec chmod 0644 {} +; \
		find "$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)/Applications" -type f -perm +0111 -exec chmod 0755 {} +; \
	fi

before-package::
	@PREFIX_PATH="$(THEOS_STAGING_DIR)$(_THEOS_PREFIX)"; \
	[ -f "$$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/BoostiPhone6sCore.dylib" ] || (echo "[ERROR] Dylib missing"; exit 1); \
	[ -f "$$PREFIX_PATH/Library/MobileSubstrate/DynamicLibraries/$(BOOST_PLIST_NAME)" ] || (echo "[ERROR] Plist missing"; exit 1); \
	echo "  [OK] Ready"
