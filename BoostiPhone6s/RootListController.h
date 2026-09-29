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
+ (instancetype)preferenceSpecifierNamed:(NSString *)name target:(id)target set:(nullable SEL)set get:(nullable SEL)get detail:(nullable Class)detail cell:(NSInteger)cell edit:(nullable Class)edit;
+ (instancetype)groupSpecifierWithName:(NSString *)name;
- (nullable id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)property forKey:(NSString *)key;
@end
#endif

@interface RootListController : PSListController {
    NSArray *_allSavedSpecifiers;
}

// ==================== BỘ ĐỌC / GHI CẤU HÌNH ĐỒNG BỘ KÉP ====================
- (nullable id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (NSDictionary *)getMergedPreferences;
- (void)ensureDefaultSettingsExist;
- (void)syncSharedMemoryFile:(BOOL)enabled;

// ==================== ĐIỀU PHỐI POPUP PICKER (HZ, FPS & LANGUAGE) ====================
- (void)showHzPickerPopup:(PSSpecifier *)specifier;
- (void)showFPSPickerPopup:(PSSpecifier *)specifier;
- (void)showSubMenuWithOptions:(NSArray *)rates title:(NSString *)title unit:(NSString *)unit isFPS:(BOOL)isFPS;
- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)dynamicMode isFPS:(BOOL)isFPS;
- (void)showLanguagePickerPopup:(PSSpecifier *)specifier;
- (void)updateDynamicTitles;

// ==================== THÔNG TIN PHÁT TRIỂN & LIÊN KẾT ZALO ====================
- (id)getAuthorName:(PSSpecifier *)specifier;
- (id)getVersionString:(PSSpecifier *)specifier;
- (void)openSupportLink:(PSSpecifier *)specifier;

// ==================== HÀNH ĐỘNG HỆ THỐNG & ĐẶT LẠI GỘP CHUNG ====================
- (void)setupNavigationItems;
- (void)presentActions;
- (void)executeResetConfiguration;

@end

NS_ASSUME_NONNULL_END

#endif /* ROOTLISTCONTROLLER_H */
