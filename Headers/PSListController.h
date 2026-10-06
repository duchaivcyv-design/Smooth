#ifndef PSLISTCONTROLLER_H
#define PSLISTCONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSSpecifier;

@interface PSListController : UIViewController <UITableViewDataSource, UITableViewDelegate>

// Chuẩn của Preferences.framework là NSMutableArray hỗ trợ thêm/xóa specifier động
@property (nonatomic, strong, nullable) NSMutableArray<PSSpecifier *> *specifiers;
@property (nonatomic, strong, nullable) UITableView *table;
@property (nonatomic, strong, nullable) NSBundle *bundle;
@property (nonatomic, weak, nullable) id target;

// Nạp danh sách tùy chọn từ tệp plist cấu hình của PreferencesLoader
- (NSMutableArray<PSSpecifier *> *)loadSpecifiersFromPlistName:(NSString *)plistName target:(nullable id)target;
- (nullable NSMutableArray<PSSpecifier *> *)specifiers;
- (void)setSpecifiers:(nullable NSArray<PSSpecifier *> *)specifiers;

// Cập nhật và tải lại giao diện danh sách
- (void)reloadSpecifiers;
- (void)reloadSpecifier:(PSSpecifier *)specifier;
- (void)reloadSpecifierAtIndex:(NSInteger)index;

// Truy vấn phần tử cấu hình và chỉ mục
- (nullable PSSpecifier *)specifierAtIndex:(NSInteger)index;
- (nullable PSSpecifier *)specifierForID:(NSString *)identifier;
- (NSInteger)indexOfSpecifier:(PSSpecifier *)specifier;
- (nullable NSIndexPath *)indexPathForSpecifier:(PSSpecifier *)specifier;
- (nullable PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UITableViewCell *)cachedCellForSpecifier:(PSSpecifier *)specifier;

// Thao tác động trên danh sách Specifiers
- (void)insertSpecifier:(PSSpecifier *)specifier atRow:(NSInteger)row;
- (void)removeSpecifierAtIndex:(NSInteger)index;
- (void)addSpecifier:(PSSpecifier *)specifier;

// Đọc và ghi giá trị cấu hình (Hàm cốt tử của PreferenceLoader)
- (nullable id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(nullable id)value specifier:(PSSpecifier *)specifier;

// Xử lý sự kiện và điều hướng trang con
- (void)actionForSpecifier:(PSSpecifier *)specifier;
- (void)pushController:(PSSpecifier *)specifier;

// Quản lý chu kỳ cập nhật bảng
- (void)suspendSpecifierUpdates;
- (void)resumeSpecifierUpdates;

// Chu kỳ sống của View
- (void)viewDidLoad;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END

#endif /* PSLISTCONTROLLER_H */
