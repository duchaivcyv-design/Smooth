#ifndef PSLISTCONTROLLER_H
#define PSLISTCONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSSpecifier;

/**
 * Base controller cho Settings Bundle.
 * Khớp chính xác với PSListController trong Preferences.framework.
 * Hỗ trợ iOS 14.0 - 26.0.1 Rootless.
 * 
 * Subclass này cung cấp đầy đủ API để:
 * - Load specifiers từ plist
 * - Dynamic add/remove specifier
 * - Reload table view
 * - Handle specifier actions
 */
@interface PSListController : UIViewController <UITableViewDataSource, UITableViewDelegate>

/**
 * Mảng chứa tất cả PSSpecifier đang hiển thị.
 * Tự động reload table view khi assign mảng mới.
 */
@property (nonatomic, copy, nullable) NSArray<PSSpecifier *> *specifiers;

/**
 * Table view hiển thị danh sách settings.
 * Tự động tạo và quản lý bởi PSListController.
 */
@property (nonatomic, retain, nullable) UITableView *table;

/**
 * Bundle chứa resources (icon, plist) cho controller này.
 * Mặc định là bundle chứa class hiện tại.
 */
@property (nonatomic, retain, nullable) NSBundle *bundle;

/**
 * Target object để resolve selector get/set/action.
 * Mặc định là self.
 */
@property (nonatomic, retain, nullable) id target;

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
 * An toàn gọi từ bất kỳ thread nào (auto dispatch to main).
 */
- (void)reloadSpecifiers;

/**
 * Reload specifier tại index cụ thể.
 * Hiệu quả hơn reloadSpecifiers khi chỉ thay đổi 1 cell.
 * @param specifier Specifier cần reload.
 */
- (void)reloadSpecifier:(PSSpecifier *)specifier;

/**
 * Trả về specifier tại index cụ thể.
 * An toàn hơn truy cập trực tiếp _specifiers[index].
 * @param index Vị trí trong mảng specifiers.
 * @return PSSpecifier tại index hoặc nil nếu out of bounds.
 */
- (nullable PSSpecifier *)specifierAtIndex:(NSInteger)index;

/**
 * Insert specifier mới vào vị trí index.
 * Tự động reload table view sau khi insert.
 * @param specifier Specifier cần thêm.
 * @param row Vị trí chèn vào.
 */
- (void)insertSpecifier:(PSSpecifier *)specifier atRow:(NSInteger)row;

/**
 * Remove specifier tại index.
 * Tự động reload table view sau khi remove.
 * @param index Vị trí cần xóa.
 */
- (void)removeSpecifierAtIndex:(NSInteger)index;

/**
 * Tìm specifier theo name/key.
 * @param name Tên internal key của specifier.
 * @return PSSpecifier khớp name hoặc nil nếu không tìm thấy.
 */
- (nullable PSSpecifier *)specifierForID:(NSString *)name;

/**
 * Handle action khi user tap vào PSButtonCell hoặc PSLinkCell.
 * Override trong subclass để xử lý custom action.
 * @param specifier Specifier bị tap.
 */
- (void)actionForSpecifier:(PSSpecifier *)specifier;

/**
 * Called when a switch cell value changes.
 * Override trong subclass để xử lý custom logic.
 * @param value Giá trị mới của switch.
 * @param specifier Specifier chứa switch.
 */
- (void)setPreferenceValue:(nullable id)value specifier:(PSSpecifier *)specifier;

/**
 * Called when controller is about to appear.
 * Override để refresh data trước khi hiển thị.
 */
- (void)viewWillAppear:(BOOL)animated;

/**
 * Called when controller did appear.
 * Override để perform post-appear logic.
 */
- (void)viewDidAppear:(BOOL)animated;

/**
 * Suspend/resume specifier updates.
 * Dùng khi batch update nhiều specifier cùng lúc.
 */
- (void)suspendSpecifierUpdates;
- (void)resumeSpecifierUpdates;

@end

NS_ASSUME_NONNULL_END

#endif /* PSLISTCONTROLLER_H */
