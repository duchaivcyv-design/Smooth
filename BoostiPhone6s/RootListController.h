#ifndef ROOTLISTCONTROLLER_H
#define ROOTLISTCONTROLLER_H

#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

NS_ASSUME_NONNULL_BEGIN

@interface RootListController : PSListController

// Các hàm hiển thị và chọn mức Hz / FPS
- (id)getHzDisplayValue:(PSSpecifier *)specifier;
- (void)showHzPickerPopup:(PSSpecifier *)specifier;

- (id)getFPSDisplayValue:(PSSpecifier *)specifier;
- (void)showFPSPickerPopup:(PSSpecifier *)specifier;

// Các hàm hành động hệ thống khớp 100% với Root.plist
- (void)respringDevice;
- (void)resetAllSettings;

@end

NS_ASSUME_NONNULL_END

#endif
