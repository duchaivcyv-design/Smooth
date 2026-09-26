#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <notify.h>

#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.duchaivcy.boostiphone6s/ReloadPrefs"

extern char **environ;

// ==============================================================================
// 📱 CONTROLLER MENU NHỎ GỌN (POPOVER TABLE MINI)
// ==============================================================================
@interface MiniPickerViewController : UITableViewController
@property (nonatomic, strong) NSArray *titles;
@property (nonatomic, strong) NSArray *values;
@property (nonatomic, copy) void (^onSelect)(NSNumber *val);
@end

@implementation MiniPickerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.tableView.rowHeight = 44.0;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 15, 0, 15);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.titles.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"MiniCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        cell.textLabel.textColor = [UIColor labelColor];
    }
    cell.textLabel.text = self.titles[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.onSelect) {
        self.onSelect(self.values[indexPath.row]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// ==============================================================================
// ⚙️ ROOT LIST CONTROLLER CHÍNH
// ==============================================================================
@interface RootListController : PSListController <UIPopoverPresentationControllerDelegate>
@end

@implementation RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (NSString *)effectivePrefPath {
    if ([[NSFileManager defaultManager] fileExistsAtPath:PREF_PATH]) return PREF_PATH;
    return FALLBACK_PREF_PATH;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
    if (!prefs) return specifier.properties[@"default"];
    id val = prefs[specifier.properties[@"key"]];
    return val ? val : specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *path = [self effectivePrefPath];
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
    prefs[specifier.properties[@"key"]] = value;
    [prefs writeToFile:path atomically:YES];
    notify_post(NOTIFY_RELOAD);
}

// ============================================================================
// LẤY CHỮ HIỂN THỊ TRỰC TIẾP Ở GÓC PHẢI HÀNG
// ============================================================================
- (NSString *)getHzDisplayValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
    BOOL enabled = prefs[@"EnableHzControl"] ? [prefs[@"EnableHzControl"] boolValue] : YES;
    if (!enabled) return @"Tắt";
    NSInteger val = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 60;
    if (val == 0) return @"Tự động";
    return [NSString stringWithFormat:@"%ld Hz", (long)val];
}

- (NSString *)getFPSDisplayValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
    BOOL enabled = prefs[@"EnableFPSControl"] ? [prefs[@"EnableFPSControl"] boolValue] : YES;
    if (!enabled) return @"Tắt";
    NSInteger val = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 60;
    if (val == 0) return @"Tự động";
    return [NSString stringWithFormat:@"%ld FPS", (long)val];
}

// BẮT BUỘC KHÔNG CHO IPHONE TỰ BIẾN THÀNH SHEET ĐÁY
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    return UIModalPresentationNone;
}

// ============================================================================
// HIỂN THỊ KHUNG NHỎ GỌN NEO CHUẨN XÁC MŨI TÊN BÊN PHẢI
// ============================================================================
- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    [self presentMiniPopoverForSpecifier:specifier key:@"TargetRefreshRate" suffix:@"Hz"];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    [self presentMiniPopoverForSpecifier:specifier key:@"TargetFPSRate" suffix:@"FPS"];
}

- (void)presentMiniPopoverForSpecifier:(PSSpecifier *)specifier key:(NSString *)prefKey suffix:(NSString *)suffix {
    MiniPickerViewController *miniVC = [[MiniPickerViewController alloc] initWithStyle:UITableViewStylePlain];
    miniVC.titles = @[@"Tự Động (Auto)", 
                      [NSString stringWithFormat:@"30 %@", suffix], 
                      [NSString stringWithFormat:@"60 %@", suffix], 
                      [NSString stringWithFormat:@"90 %@", suffix], 
                      [NSString stringWithFormat:@"120 %@", suffix], 
                      [NSString stringWithFormat:@"144 %@", suffix]];
    miniVC.values = @[@0, @30, @60, @90, @120, @144];
    
    // KÍCH THƯỚC KHUNG NHỎ GỌN MINI
    miniVC.preferredContentSize = CGSizeMake(190, 264);
    miniVC.modalPresentationStyle = UIModalPresentationPopover;

    __weak typeof(self) weakSelf = self;
    miniVC.onSelect = ^(NSNumber *selectedVal) {
        NSString *path = [weakSelf effectivePrefPath];
        NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
        prefs[prefKey] = selectedVal;
        [prefs writeToFile:path atomically:YES];
        notify_post(NOTIFY_RELOAD);
        [weakSelf reloadSpecifiers];
    };

    UIPopoverPresentationController *popover = miniVC.popoverPresentationController;
    if (popover) {
        popover.delegate = self;
        UITableViewCell *cell = [self cachedCellForSpecifier:specifier];
        popover.sourceView = cell ? cell : self.view;
        // Neo dính chặt vào góc phải (chỗ hiển thị số và mũi tên chevron)
        if (cell) {
            popover.sourceRect = CGRectMake(cell.bounds.size.width - 50, cell.bounds.size.height / 2.0, 1.0, 1.0);
        } else {
            popover.sourceRect = CGRectMake(self.view.bounds.size.width - 50, 140, 1.0, 1.0);
        }
        popover.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown | UIPopoverArrowDirectionRight;
    }

    [self presentViewController:miniVC animated:YES completion:nil];
}

// ============================================================================
// QUẢN LÝ HỆ THỐNG
// ============================================================================
- (void)respringDevice {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Khởi Động Lại SpringBoard"
                                                                   message:@"Respring để áp dụng thay đổi?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Respring Ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        pid_t pid;
        const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)argv, environ);
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetAllSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đặt Lại Cấu Hình"
                                                                   message:@"Khôi phục toàn bộ cài đặt gốc của SmoothiOS V21.4.1?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:FALLBACK_PREF_PATH error:nil];
        notify_post(NOTIFY_RELOAD);
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
