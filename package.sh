#!/bin/bash

echo "Starting Packaging Process..."

# 1. Tạo thư mục DEBIAN
mkdir -p .theos/_/DEBIAN

# 2. Copy control files
cp control .theos/_/DEBIAN/control
cp postinst .theos/_/DEBIAN/postinst
chmod 755 .theos/_/DEBIAN/postinst

if [ -f prerm ]; then 
    cp prerm .theos/_/DEBIAN/prerm
    chmod 755 .theos/_/DEBIAN/prerm
fi

# 3. Tạo thư mục PreferenceBundle
BUNDLE_DIR=".theos/_/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"
mkdir -p "$BUNDLE_DIR"

# 4. Copy resources vào bundle
cp Resources/root.plist "$BUNDLE_DIR/root.plist"
cp Resources/Info.plist "$BUNDLE_DIR/Info.plist"

echo " Structure Ready:"
ls -laR .theos/_/Library/PreferenceBundles/
