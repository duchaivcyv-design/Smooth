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
        @try {
            _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        } @catch (NSException *e) {
            _specifiers = [NSMutableArray array];
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
// HIỂN THỊ TRẠNG THÁI HIỆN TẠI RA CELL
// ============================================================================
- (NSString *)getHzDisplayValue:(PSSpecifier *)specifier {
    @try {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        BOOL enabled = prefs[@"EnableHzControl"] ? [prefs[@"EnableHzControl"] boolValue] : YES;
        if (!enabled) return @"Tắt";
        NSInteger val = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 60;
        if (val == 0) return @"Tự động";
        return [NSString stringWithFormat:@"Khóa ở %ld Hz", (long)val];
    } @catch (NSException *e) {
        return @"Khóa ở 60 Hz";
    }
}

- (NSString *)getFPSDisplayValue:(PSSpecifier *)specifier {
    @try {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        BOOL enabled = prefs[@"EnableFPSControl"] ? [prefs[@"EnableFPSControl"] boolValue] : YES;
        if (!enabled) return @"Tắt";
        NSInteger val = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 60;
        if (val == 0) return @"Tự động";
        return [NSString stringWithFormat:@"Khóa ở %ld FPS", (long)val];
    } @catch (NSException *e) {
        return @"Khóa ở 60 FPS";
    }
}

// ============================================================================
// BẢNG ACTION SHEET TỪ ĐÁY MÀN HÌNH (CHUẨN ẢNH 100%)
// ============================================================================
- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    [self presentActionSheetForSpecifier:specifier 
                                   title:@"Chọn Tần Số Quét (Hz & FPS)" 
                                 message:@"Lựa chọn mức hiển thị hệ thống:\n• Tự Động: Tự cân bằng theo nhiệt độ & tải\n• 30Hz: Tiết kiệm pin tối đa, giảm sinh nhiệt\n• 60Hz: Mặc định chuẩn\n• 90Hz - 120Hz - 144Hz: Tối ưu cảm ứng siêu mượt" 
                                     key:@"TargetRefreshRate" 
                                  suffix:@"Hz"];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    [self presentActionSheetForSpecifier:specifier 
                                   title:@"Chọn Mức Khung Hình Ứng Dụng (FPS)" 
                                 message:@"Lựa chọn giới hạn FPS render ứng dụng:\n• Tự Động: Theo engine mặc định của app\n• 30 FPS: Tiết kiệm pin, chống quá nhiệt\n• 60 FPS: Mượt mà ổn định chuẩn\n• 90 FPS - 120 FPS - 144 FPS: Đột phá giới hạn cực hạn" 
                                     key:@"TargetFPSRate" 
                                  suffix:@"FPS"];
}

- (void)presentActionSheetForSpecifier:(PSSpecifier *)specifier 
                                 title:(NSString *)title 
                               message:(NSString *)message 
                                   key:(NSString *)prefKey 
                                suffix:(NSString *)suffix {
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:title
                                                                         message:message
                                                                  preferredStyle:UIAlertControllerStyleActionSheet];

    __weak typeof(self) weakSelf = self;
    void (^saveHandler)(NSNumber *) = ^(NSNumber *val) {
        NSString *path = [weakSelf effectivePrefPath];
        NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary dictionary];
        prefs[prefKey] = val;
        [prefs writeToFile:path atomically:YES];
        notify_post(NOTIFY_RELOAD);
        [weakSelf reloadSpecifiers];
    };

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Tự Động Điều Chỉnh (Dynamic)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@0);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 30 %@ (Tiết kiệm pin)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@30);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 60 %@ (Mặc định)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@60);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 90 %@ (Mượt mà)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@90);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 120 %@ (Cực mượt)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@120);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Khóa ở 144 %@ (Cực đại)", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@144);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [self cachedCellForSpecifier:specifier];
        actionSheet.popoverPresentationController.sourceView = cell ? cell : self.view;
        actionSheet.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0);
    }

    [self presentViewController:actionSheet animated:YES completion:nil];
}

// ============================================================================
// HỆ THỐNG
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
                                                                   message:@"Khôi phục cài đặt gốc của SmoothiOS V21.5.7?"
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
