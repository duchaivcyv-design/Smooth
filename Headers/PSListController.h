#ifndef PSLISTCONTROLLER_H
#define PSLISTCONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSSpecifier;

/**
 * PSListController - Base controller cho Settings Bundle.
 * 
 * Khớp chính xác với PSListController trong Preferences.framework.
 * RootListController kế thừa class này để hiển thị danh sách settings.
 * 
 * Hỗ trợ iOS 14.0 - 26.0.1 Rootless.
 * 
 * Luồng hoạt động:
 * 1. viewDidLoad → gọi specifiers (lazy load)
 * 2. specifiers → gọi loadSpecifiersFromPlistName:@"Root" target:self
 * 3. Parse Root.plist → tạo mảng PSSpecifier
 * 4. UITableView hiển thị từng specifier theo cellType
 * 5. User toggle switch → performSetterWithValue → ghi UserDefaults → sendPostNotification
 * 6. Tweak.xm nhận Darwin Notification → reload config
 */
@interface PSListController : UIViewController <UITableViewDataSource, UITableViewDelegate>

// ==============================================================================
// CORE PROPERTIES
// ==============================================================================

/**
 * Mảng chứa tất cả PSSpecifier đang hiển thị.
 * Lazy load qua method -specifiers.
 * Assign mảng mới sẽ tự động reload table view.
 */
@property (nonatomic, copy, nullable) NSArray<PSSpecifier *> *specifiers;

/**
 * Table view hiển thị danh sách settings.
 * Tự động tạo và quản lý bởi PSListController.
 */
@property (nonatomic, retain, nullable) UITableView *table;

/**
 * Bundle chứa resources (Root.plist, icon.png) cho controller này.
 * Mặc định là bundle chứa class hiện tại (BoostiPhone6sPrefs.bundle).
 */
@property (nonatomic, retain, nullable) NSBundle *bundle;

/**
 * Target object để resolve selector get/set/action.
 * Mặc định là self (RootListController instance).
 */
@property (nonatomic, assign, nullable) id target;

// ==============================================================================
// SPECIFIER LOADING
// ==============================================================================

/**
 * Load specifiers từ plist name (không cần extension .plist).
 * 
 * Đây là method QUAN TRỌNG NHẤT - được gọi từ RootListController.m:
 *   _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
 * 
 * Method này:
 * 1. Tìm file Root.plist trong self.bundle
 * 2. Parse array "items" từ plist
 * 3. Tạo PSSpecifier cho mỗi dict
 * 4. Resolve getter/setter/action selectors trên target
 * 5. Trả về mảng PSSpecifier đã sẵn sàng hiển thị
 * 
 * @param plistName Tên file plist (vd: @"Root" → Root.plist)
 * @param target Target object để resolve selectors (thường là self)
 * @return Mảng PSSpecifier đã được parse từ plist
 */
- (NSArray<PSSpecifier *> *)loadSpecifiersFromPlistName:(NSString *)plistName
                                                 target:(nullable id)target;

// ==============================================================================
// TABLE VIEW RELOAD
// ==============================================================================

/**
 * Reload toàn bộ table view dựa trên specifiers hiện tại.
 * Gọi sau khi thay đổi dynamic specifiers hoặc update giá trị.
 * An toàn gọi từ bất kỳ thread nào (auto dispatch to main).
 */
- (void)reloadSpecifiers;

/**
 * Reload specifier tại vị trí cụ thể.
 * Hiệu quả hơn reloadSpecifiers khi chỉ thay đổi 1 cell.
 * @param specifier Specifier cần reload
 */
- (void)reloadSpecifier:(PSSpecifier *)specifier;

/**
 * Reload specifier theo index trong mảng.
 * @param index Vị trí trong mảng specifiers
 */
- (void)reloadSpecifierAtIndex:(NSInteger)index;

// ==============================================================================
// SPECIFIER ACCESS
// ==============================================================================

/**
 * Trả về specifier tại index cụ thể.
 * An toàn hơn truy cập trực tiếp specifiers[index].
 * @param index Vị trí trong mảng specifiers
 * @return PSSpecifier tại index hoặc nil nếu out of bounds
 */
- (nullable PSSpecifier *)specifierAtIndex:(NSInteger)index;

/**
 * Tìm specifier theo identifier/key.
 * @param identifier Tên internal key của specifier
 * @return PSSpecifier khớp identifier hoặc nil nếu không tìm thấy
 */
- (nullable PSSpecifier *)specifierForID:(NSString *)identifier;

// ==============================================================================
// DYNAMIC SPECIFIER MODIFICATION
// ==============================================================================

/**
 * Insert specifier mới vào vị trí index.
 * Tự động reload table view sau khi insert.
 * @param specifier Specifier cần thêm
 * @param row Vị trí chèn vào
 */
- (void)insertSpecifier:(PSSpecifier *)specifier atRow:(NSInteger)row;

/**
 * Remove specifier tại index.
 * Tự động reload table view sau khi remove.
 * @param index Vị trí cần xóa
 */
- (void)removeSpecifierAtIndex:(NSInteger)index;

/**
 * Thêm specifier vào cuối danh sách.
 * @param specifier Specifier cần thêm
 */
- (void)addSpecifier:(PSSpecifier *)specifier;

// ==============================================================================
// VALUE CHANGE HANDLING
// ==============================================================================

/**
 * Called when a switch/slider/text cell value changes.
 * Override trong subclass để xử lý custom logic.
 * 
 * Trong RootListController.m, method này được gọi tự động bởi
 * PSListController khi user toggle switch. Value được ghi vào
 * UserDefaults domain tương ứng, sau đó PostNotification được gửi.
 * 
 * @param value Giá trị mới của cell
 * @param specifier Specifier chứa cell bị thay đổi
 */
- (void)setPreferenceValue:(nullable id)value specifier:(PSSpecifier *)specifier;

/**
 * Handle action khi user tap vào PSButtonCell hoặc PSLinkCell.
 * Override trong subclass để xử lý custom action.
 * 
 * Trong RootListController.m:
 *   - (void)respring:(id)sender → gọi performRespring
 *   - (void)resetSafeMode:(id)sender → gọi reset logic
 * 
 * @param specifier Specifier bị tap
 */
- (void)actionForSpecifier:(PSSpecifier *)specifier;

// ==============================================================================
// LIFECYCLE
// ==============================================================================

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
 * Called when controller loads view.
 * PSListController tự động setup table view ở đây.
 */
- (void)viewDidLoad;

// ==============================================================================
// SUSPEND / RESUME
// ==============================================================================

/**
 * Suspend specifier updates.
 * Dùng khi batch update nhiều specifier cùng lúc để tránh reload liên tục.
 */
- (void)suspendSpecifierUpdates;

/**
 * Resume specifier updates.
 * Gọi sau suspendSpecifierUpdates để áp dụng tất cả thay đổi.
 */
- (void)resumeSpecifierUpdates;

// ==============================================================================
// NAVIGATION
// ==============================================================================

/**
 * Push một PSListController con lên navigation stack.
 * Dùng cho PSLinkCell để mở sub-page settings.
 * @param specifier Specifier chứa thông tin sub-page
 */
- (void)pushController:(PSSpecifier *)specifier;

@end

NS_ASSUME_NONNULL_END

#endif /* PSLISTCONTROLLER_H */
