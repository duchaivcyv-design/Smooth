#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <notify.h>

#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.duchaivcy.boostiphone6s/ReloadPrefs"

extern char **environ;

@interface RootListController : PSListController
@end

@implementation RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (NSString *)effectivePrefPath {
    if ([[NSFileManager defaultManager] fileExistsAtPath:PREF_PATH]) {
        return PREF_PATH;
    }
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
// LẤY CHỮ HIỂN THỊ TRỰC TIẾP Ở NGOÀI MENU (DETAIL TEXT)
// ============================================================================
- (NSString *)getHzDisplayValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
    NSInteger val = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 60;
    if (val == 0) return @"Auto (iOS 27)";
    return [NSString stringWithFormat:@"%ld Hz", (long)val];
}

- (NSString *)getFPSDisplayValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
    NSInteger val = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 60;
    if (val == 0) return @"Auto (iOS 27)";
    return [NSString stringWithFormat:@"%ld FPS", (long)val];
}

// ============================================================================
// POPUP NHỎ BÊN PHẢI NHẢY XUỐNG (POPOVER ANCHOR)
// ============================================================================
- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    [self presentSmallRightDropdownForSpecifier:specifier title:@"Tần Số Quét (Hz)" key:@"TargetRefreshRate" suffix:@"Hz"];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    [self presentSmallRightDropdownForSpecifier:specifier title:@"Tốc Độ Khung Hình (FPS)" key:@"TargetFPSRate" suffix:@"FPS"];
}

- (void)presentSmallRightDropdownForSpecifier:(PSSpecifier *)specifier title:(NSString *)title key:(NSString *)prefKey suffix:(NSString *)suffix {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:@"Chọn mốc thiết lập"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *titles = @[@"Tự Động (Auto iOS 27)", @"30", @"60", @"90", @"120", @"144"];
    NSArray *values = @[@0, @30, @60, @90, @120, @144];

    for (NSUInteger i = 0; i < values.count; i++) {
        NSNumber *val = values[i];
        NSString *actionTitle = (i == 0) ? titles[i] : [NSString stringWithFormat:@"%@ %@", titles[i], suffix];
        
        [alert addAction:[UIAlertAction actionWithTitle:actionTitle
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
            NSString *path = [self effectivePrefPath];
            NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
            prefs[prefKey] = val;
            [prefs writeToFile:path atomically:YES];
            notify_post(NOTIFY_RELOAD);
            // Tải lại specifiers ngay để chữ ở ngoài đổi lập tức thành số vừa chọn
            [self reloadSpecifiers];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    // ÉP POPUP NẰM KHUNG NHỎ BÊN PHẢI NHẢY XUỐNG DƯỚI (POPOVER)
    UITableViewCell *cell = [self cachedCellForSpecifier:specifier];
    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = cell ? cell : self.view;
        if (cell) {
            // Neo chính xác vào mép bên phải của hàng vừa chạm
            CGRect rightRect = CGRectMake(cell.bounds.size.width - 70, cell.bounds.size.height / 2.0, 1.0, 1.0);
            alert.popoverPresentationController.sourceRect = rightRect;
        } else {
            alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width - 50, 100, 1.0, 1.0);
        }
        alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

// ============================================================================
// RESPRING & ĐẶT LẠI
// ============================================================================
- (void)respringDevice {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Khởi Động Lại SpringBoard"
                                                                   message:@"Respring ngay để áp dụng toàn bộ thiết lập?"
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
                                                                   message:@"Khôi phục cài đặt gốc của SmoothiOS V21.3?"
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
