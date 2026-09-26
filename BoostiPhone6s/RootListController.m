#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <notify.h>

#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.duchaivcy.boostiphone6s/ReloadPrefs"

extern char **environ;

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

// ============================================================================
// BẮT BUỘC POPUP NHỎ GỌN TRÊN IPHONE (KHÔNG CHO PHÉP NHẢY SANG BẢNG TO DƯỚI)
// ============================================================================
- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller {
    return UIModalPresentationNone; // Bắt buộc giữ nguyên popover nhỏ
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController *)controller traitCollection:(UITraitCollection *)traitCollection {
    return UIModalPresentationNone;
}

- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    [self presentSmallPopoverAtRightEdgeForSpecifier:specifier title:@"Tần Số Quét" key:@"TargetRefreshRate" suffix:@"Hz"];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    [self presentSmallPopoverAtRightEdgeForSpecifier:specifier title:@"Tốc Độ Khung Hình" key:@"TargetFPSRate" suffix:@"FPS"];
}

- (void)presentSmallPopoverAtRightEdgeForSpecifier:(PSSpecifier *)specifier title:(NSString *)title key:(NSString *)prefKey suffix:(NSString *)suffix {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *titles = @[@"Tự Động (Auto)", @"30", @"60", @"90", @"120", @"144"];
    NSArray *values = @[@0, @30, @60, @90, @120, @144];

    for (NSUInteger i = 0; i < values.count; i++) {
        NSNumber *val = values[i];
        NSString *btnTitle = (i == 0) ? titles[i] : [NSString stringWithFormat:@"%@ %@", titles[i], suffix];
        [alert addAction:[UIAlertAction actionWithTitle:btnTitle
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
            NSString *path = [self effectivePrefPath];
            NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
            prefs[prefKey] = val;
            [prefs writeToFile:path atomically:YES];
            notify_post(NOTIFY_RELOAD);
            [self reloadSpecifiers];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];

    // NEO VÀO ĐÚNG MŨI TÊN / CHỮ Ở GÓC PHẢI CELL
    UITableViewCell *cell = [self cachedCellForSpecifier:specifier];
    alert.modalPresentationStyle = UIModalPresentationPopover;
    
    UIPopoverPresentationController *popover = alert.popoverPresentationController;
    if (popover) {
        popover.delegate = self; // Ép dùng UIModalPresentationNone
        popover.sourceView = cell ? cell : self.view;
        if (cell) {
            // Đặt điểm neo đúng ngay mép phải mũi tên chevron
            popover.sourceRect = CGRectMake(cell.bounds.size.width - 45, cell.bounds.size.height / 2.0, 1.0, 1.0);
        } else {
            popover.sourceRect = CGRectMake(self.view.bounds.size.width - 45, 120, 1.0, 1.0);
        }
        popover.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown | UIPopoverArrowDirectionRight;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

// ============================================================================
// HỆ THỐNG: RESPRING & ĐẶT LẠI CÀI ĐẶT
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
                                                                   message:@"Khôi phục toàn bộ cài đặt gốc của SmoothiOS V21.3.6.2?"
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
