#ifndef ROOTLISTCONTROLLER_H
#define ROOTLISTCONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSSpecifier;

#if __has_include(<Preferences/PSListController.h>)
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#else
@interface PSListController : UIViewController {
    id _specifiers;
}
- (id)specifiers;
- (void)reloadSpecifiers;
- (id)loadSpecifiersFromPlistName:(NSString *)name target:(id)target bundle:(NSBundle *)bundle;
@end

@interface PSSpecifier : NSObject
@property (nonatomic, strong) NSString *name;
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)property forKey:(NSString *)key;
@end
#endif

@interface RootListController : PSListController

// ==================== BỘ ĐỌC / GHI CẤU HÌNH ĐỒNG BỘ KÉP ====================
- (nullable id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;

// ==================== ĐIỀU PHỐI POPUP CARD HZ & FPS ====================
- (void)showHzPickerPopup:(PSSpecifier *)specifier;
- (void)showFPSPickerPopup:(PSSpecifier *)specifier;

// ==================== THÔNG TIN PHÁT TRIỂN & LIÊN KẾT ZALO ====================
- (id)getAuthorName:(PSSpecifier *)specifier;
- (id)getVersionString:(PSSpecifier *)specifier;
- (void)openSupportLink:(PSSpecifier *)specifier;

// ==================== HÀNH ĐỘNG HỆ THỐNG & ĐẶT LẠI GỘP CHUNG ====================
- (void)presentActions;
- (void)executeResetConfiguration;

@end

NS_ASSUME_NONNULL_END

#endif /* ROOTLISTCONTROLLER_H */
