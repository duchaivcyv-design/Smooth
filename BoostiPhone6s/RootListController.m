#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <notify.h>

#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.duchaivcy.boostiphone6s/ReloadPrefs"

extern char **environ;

// ==============================================================================
// 📱 MINI POPOVER CONTROLLER (CHỐNG VĂNG KHI SAFEMODE & NEO CHUẨN GÓC PHẢI)
// ==============================================================================
@interface SmoothMiniPickerVC : UITableViewController
@property (nonatomic, strong) NSArray *titles;
@property (nonatomic, strong) NSArray *values;
@property (nonatomic, copy) void (^onSelect)(NSNumber *val);
@end

@implementation SmoothMiniPickerVC

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.backgroundColor = [UIColor secondarySystemBackgroundColor];
    self.tableView.rowHeight = 44.0;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 15, 0, 15);
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.alwaysBounceVertical = NO;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.titles ? self.titles.count : 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"SmoothMiniCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        cell.textLabel.textColor = [UIColor labelColor];
    }
    if (indexPath.row < self.titles.count) {
        cell.textLabel.text = self.titles[indexPath.row];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.onSelect && indexPath.row < self.values.count) {
        self.onSelect(self.values[indexPath.row]);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

// ==============================================================================
// ⚙️ ROOT LIST CONTROLLER
// ==============================================================================
@interface RootListController : PSListController <UIPopoverPresentationControllerDelegate>
@end

@implementation RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        } @catch (NSException *e) {
            _specifiers = [NSArray array];
        }
    }
    return _specifiers;
}

- (NSString *)effectivePrefPath {
    if ([[NSFileManager defaultManager] fileExistsAtPath:PREF_PATH]) return PREF_PATH;
    return FALLBACK_PREF_PATH;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    @try {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        if (!prefs) return specifier.properties[@"default"];
        id val = prefs[specifier.properties[@"key"]];
        return val ? val : specifier.properties[@"default"];
    } @catch (NSException *e) {
        return specifier.properties[@"default"];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    @try {
        NSString *path = [self effectivePrefPath];
        NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
        prefs[specifier.properties[@"key"]] = value;
        [prefs writeToFile:path atomically:YES];
        notify_post(NOTIFY_RELOAD);
    } @catch (NSException *e) {}
}

// ============================================================================
// LẤY CHỮ HIỂN THỊ ĐỘNG TRỰC TIẾP Ở GÓC PHẢI
// ============================================================================
- (NSString *)getHzDisplayValue:(PSSpecifier *)specifier {
    @try {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        BOOL enabled = prefs[@"EnableHzControl"] ? [prefs[@"EnableHzControl"] boolValue] : YES;
        if (!enabled) return @"Tắt";
        NSInteger val = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 60;
        if (val == 0) return @"Tự động";
        return [NSString stringWithFormat:@"%ld Hz", (long)val];
    } @catch (NSException *e) {
        return @"60 Hz";
    }
}

- (NSString *)getFPSDisplayValue:(PSSpecifier *)specifier {
    @try {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        BOOL enabled = prefs[@"EnableFPSControl"] ? [prefs[@"EnableFPSControl"] boolValue] : YES;
        if (!enabled) return @"Tắt";
        NSInteger val = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 60;
        if (val == 0) return @"Tự động";
        return [NSString stringWithFormat:@"%ld FPS", (long)val];
    } @catch (NSException *e) {
        return @"60 FPS";
    }
}

// BẮT BUỘC KHÔNG CHO BIẾN THÀNH SHEET TO TOÀN MÀN HÌNH
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone;
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    return UIModalPresentationNone;
}

// ============================================================================
// HIỂN THỊ KHUNG MINI GÓC PHẢI NEO CHUẨN XÁC
// ============================================================================
- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    [self presentMiniPopoverForSpecifier:specifier key:@"TargetRefreshRate" suffix:@"Hz"];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    [self presentMiniPopoverForSpecifier:specifier key:@"TargetFPSRate" suffix:@"FPS"];
}

- (void)presentMiniPopoverForSpecifier:(PSSpecifier *)specifier key:(NSString *)prefKey suffix:(NSString *)suffix {
    SmoothMiniPickerVC *miniVC = [[SmoothMiniPickerVC alloc] initWithStyle:UITableViewStylePlain];
    miniVC.titles = @[@"Tự Động (Auto)", 
                      [NSString stringWithFormat:@"30 %@", suffix], 
                      [NSString stringWithFormat:@"60 %@", suffix], 
                      [NSString stringWithFormat:@"90 %@", suffix], 
                      [NSString stringWithFormat:@"120 %@", suffix], 
                      [NSString stringWithFormat:@"144 %@", suffix]];
    miniVC.values = @[@0, @30, @60, @90, @120, @144];
    
    miniVC.preferredContentSize = CGSizeMake(180, 264);
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
        if (cell) {
            popover.sourceRect = CGRectMake(cell.bounds.size.width - 45, cell.bounds.size.height / 2.0, 1.0, 1.0);
        } else {
            popover.sourceRect = CGRectMake(self.view.bounds.size.width - 45, 140, 1.0, 1.0);
        }
        popover.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown | UIPopoverArrowDirectionRight;
    }

    [self presentViewController:miniVC animated:YES completion:nil];
}

// ============================================================================
// QUẢN LÝ HỆ THỐNG: RESPRING & ĐẶT LẠI
// ==============================================================================
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
                                                                   message:@"Khôi phục cài đặt gốc của SmoothiOS V21.4.4?"
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
