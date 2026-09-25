#ifndef PSLISTCONTROLLER_H
#define PSLISTCONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSSpecifier;

/**
 * Base controller cho Settings Bundle.
 * Khớp chính xác với PSListController trong Preferences.framework.
 */
@interface PSListController : UIViewController

@property (nonatomic, copy, nullable) NSArray<PSSpecifier *> *specifiers;

/**
 * Load specifiers từ plist name (không cần extension .plist).
 * @param plistName Tên file plist trong bundle (vd: "Root").
 * @param target Target object để resolve selector get/set.
 * @return Mảng PSSpecifier đã được parse từ plist.
 */
- (NSArray<PSSpecifier *> *)loadSpecifiersFromPlistName:(NSString *)plistName 
                                                 target:(nullable id)target;

/**
 * Reload toàn bộ table view dựa trên _specifiers hiện tại.
 * Gọi sau khi thay đổi dynamic specifiers hoặc update giá trị.
 */
- (void)reloadSpecifiers;

/**
 * Trả về specifier tại index cụ thể.
 * An toàn hơn truy cập trực tiếp _specifiers[index].
 */
- (nullable PSSpecifier *)specifierAtIndex:(NSInteger)index;

/**
 * Insert specifier mới vào vị trí index.
 * Tự động reload table view sau khi insert.
 */
- (void)insertSpecifier:(PSSpecifier *)specifier atRow:(NSInteger)row;

@end

NS_ASSUME_NONNULL_END

#endif /* PSLISTCONTROLLER_H */
