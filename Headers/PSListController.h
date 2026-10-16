#ifndef PSLISTCONTROLLER_H
#define PSLISTCONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSSpecifier;

@interface PSViewController : UIViewController
- (void)setPreferenceValue:(nullable id)value specifier:(PSSpecifier *)specifier;
- (nullable id)readPreferenceValue:(PSSpecifier *)specifier;
@end

@interface PSListController : PSViewController <UITableViewDataSource, UITableViewDelegate> {
    id _specifiers;
}

// Bảng thuộc tính chuẩn tương thích Runtime
@property (nonatomic, strong, nullable) UITableView *table;

// Quản lý specifiers
- (NSMutableArray<PSSpecifier *> *)loadSpecifiersFromPlistName:(NSString *)plistName target:(nullable id)target;
- (NSMutableArray<PSSpecifier *> *)loadSpecifiersFromPlistName:(NSString *)plistName target:(nullable id)target bundle:(nullable NSBundle *)bundle;
- (nullable id)specifiers;
- (void)setSpecifiers:(nullable id)specifiers;

// Cập nhật và tải lại giao diện
- (void)reloadSpecifiers;
- (void)reloadSpecifier:(PSSpecifier *)specifier;
- (void)reloadSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
- (void)reloadSpecifierAtIndex:(NSInteger)index;
- (void)reloadSpecifierAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)reloadSpecifierID:(NSString *)identifier;
- (void)reloadSpecifierID:(NSString *)identifier animated:(BOOL)animated;

// Truy vấn phần tử
- (nullable PSSpecifier *)specifierAtIndex:(NSInteger)index;
- (nullable PSSpecifier *)specifierForID:(NSString *)identifier;
- (NSInteger)indexOfSpecifier:(PSSpecifier *)specifier;
- (NSInteger)indexOfSpecifierID:(NSString *)identifier;
- (nullable NSIndexPath *)indexPathForSpecifier:(PSSpecifier *)specifier;
- (nullable PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UITableViewCell *)cachedCellForSpecifier:(PSSpecifier *)specifier;

// Thao tác động trên danh sách Specifiers
- (void)insertSpecifier:(PSSpecifier *)specifier atIndex:(NSInteger)index;
- (void)insertSpecifier:(PSSpecifier *)specifier atIndex:(NSInteger)index animated:(BOOL)animated;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifier:(PSSpecifier *)other;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifier:(PSSpecifier *)other animated:(BOOL)animated;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifierID:(NSString *)otherID;
- (void)insertSpecifier:(PSSpecifier *)specifier afterSpecifierID:(NSString *)otherID animated:(BOOL)animated;
- (void)insertContainedSpecifiers:(NSArray<PSSpecifier *> *)specifiers afterSpecifier:(PSSpecifier *)other;
- (void)insertContainedSpecifiers:(NSArray<PSSpecifier *> *)specifiers afterSpecifier:(PSSpecifier *)other animated:(BOOL)animated;

- (void)addSpecifier:(PSSpecifier *)specifier;
- (void)addSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
- (void)addSpecifiersFromArray:(NSArray<PSSpecifier *> *)specifiers;
- (void)addSpecifiersFromArray:(NSArray<PSSpecifier *> *)specifiers animated:(BOOL)animated;

- (void)removeSpecifier:(PSSpecifier *)specifier;
- (void)removeSpecifier:(PSSpecifier *)specifier animated:(BOOL)animated;
- (void)removeSpecifierID:(NSString *)identifier;
- (void)removeSpecifierID:(NSString *)identifier animated:(BOOL)animated;
- (void)removeSpecifierAtIndex:(NSInteger)index;
- (void)removeSpecifierAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)removeLastSpecifier;
- (void)removeLastSpecifierAnimated:(BOOL)animated;

// Đọc và ghi giá trị cấu hình
- (nullable id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(nullable id)value specifier:(PSSpecifier *)specifier;

// Điều hướng trang và thực thi hành động
- (void)actionForSpecifier:(PSSpecifier *)specifier;
- (void)pushController:(UIViewController *)controller;
- (void)pushController:(UIViewController *)controller animate:(BOOL)animate;

// Đóng băng và kích hoạt cập nhật UI theo nhóm
- (void)beginUpdates;
- (void)endUpdates;

// Trợ năng & bundle
- (nullable NSBundle *)bundle;
- (nullable NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END

#endif /* PSLISTCONTROLLER_H */
