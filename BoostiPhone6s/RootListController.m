#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <notify.h>

#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
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

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    if (!prefs) {
        return specifier.properties[@"default"];
    }
    id val = prefs[specifier.properties[@"key"]];
    return val ? val : specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH] ?: [NSMutableDictionary dictionary];
    prefs[specifier.properties[@"key"]] = value;
    [prefs writeToFile:PREF_PATH atomically:YES];
    notify_post(NOTIFY_RELOAD);
}

// ============================================================================
// POPUP NỔI CHỌN TẦN SỐ QUÉT HZ/FPS (TỰ ĐỘNG, 30, 60, 90, 120, 144)
// ============================================================================
- (void)showHzPickerPopup {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chọn Tần Số Quét (Hz & FPS)"
                                                                   message:@"Lựa chọn mức hiển thị hệ thống:\n• Tự Động: Tự cân bằng theo nhiệt độ & tải\n• 30Hz: Tiết kiệm pin tối đa, giảm sinh nhiệt\n• 60Hz: Mặc định chuẩn\n• 90Hz - 120Hz - 144Hz: Tối ưu cảm ứng siêu mượt"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *hzTitles = @[@"Tự Động Điều Chỉnh (Dynamic)", @"Khóa ở 30 Hz (Tiết kiệm pin)", @"Khóa ở 60 Hz (Mặc định)", @"Khóa ở 90 Hz (Mượt mà)", @"Khóa ở 120 Hz (Cực mượt)", @"Khóa ở 144 Hz (Cực đại)"];
    NSArray *hzValues = @[@0, @30, @60, @90, @120, @144];

    for (NSUInteger i = 0; i < hzValues.count; i++) {
        NSNumber *hz = hzValues[i];
        NSString *title = hzTitles[i];
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
            [self applyTargetHz:hz.integerValue];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0);
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyTargetHz:(NSInteger)hz {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH] ?: [NSMutableDictionary dictionary];
    prefs[@"TargetRefreshRate"] = @(hz);
    [prefs writeToFile:PREF_PATH atomically:YES];
    notify_post(NOTIFY_RELOAD);
    [self reloadSpecifiers];
}

// ============================================================================
// RESPRING HỆ THỐNG
// ============================================================================
- (void)respringDevice {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Khởi Động Lại SpringBoard"
                                                                   message:@"Respring ngay để áp dụng toàn bộ tinh chỉnh?"
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        pid_t pid;
        const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)argv, environ);
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

// ============================================================================
// ĐẶT LẠI CÀI ĐẶT
// ============================================================================
- (void)resetAllSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đặt Lại Toàn Bộ Cấu Hình"
                                                                   message:@"Mọi thiết lập của tweak sẽ trở về trạng thái gốc."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        notify_post(NOTIFY_RELOAD);
        [self reloadSpecifiers];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

@end
