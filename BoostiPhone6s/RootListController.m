#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <notify.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>

#define PREF_DOMAIN CFSTR("com.duchaivcy.boostiphone6s")
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

// Đồng bộ đa tầng: Vừa ghi CFPreferences hệ thống vừa ghi file plist vật lý
- (void)syncPreferenceValueToSystem:(id)value forKey:(NSString *)key {
    if (!key) return;
    
    // Tầng 1: CoreFoundation Preferences (xuyên thủng Sandbox App con)
    CFStringRef cfKey = (__bridge CFStringRef)key;
    CFPreferencesSetAppValue(cfKey, (__bridge CFPropertyListRef)value, PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    
    // Tầng 2: Ghi file Plist vật lý (Rootless + Rootful fallback)
    NSString *primaryPath = PREF_PATH;
    NSString *fallbackPath = FALLBACK_PREF_PATH;
    
    NSMutableDictionary *primaryDict = [NSMutableDictionary dictionaryWithContentsOfFile:primaryPath] ?: [NSMutableDictionary dictionary];
    primaryDict[key] = value;
    [primaryDict writeToFile:primaryPath atomically:YES];
    
    NSMutableDictionary *fallbackDict = [NSMutableDictionary dictionaryWithContentsOfFile:fallbackPath] ?: [NSMutableDictionary dictionary];
    fallbackDict[key] = value;
    [fallbackDict writeToFile:fallbackPath atomically:YES];
    
    // Tầng 3: Phát tín hiệu Darwin Notification toàn hệ thống
    notify_post(NOTIFY_RELOAD);
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    @try {
        NSString *key = specifier.properties[@"key"];
        if (!key) return specifier.properties[@"default"];
        
        // Đọc ưu tiên từ CoreFoundation
        CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, PREF_DOMAIN);
        if (val) {
            return (__bridge_transfer id)val;
        }
        
        // Fallback đọc file vật lý
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        if (prefs && prefs[key]) {
            return prefs[key];
        }
        return specifier.properties[@"default"];
    } @catch (NSException *e) {
        return specifier.properties[@"default"];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    @try {
        NSString *key = specifier.properties[@"key"];
        [self syncPreferenceValueToSystem:value forKey:key];
    } @catch (NSException *e) {}
}

// ============================================================================
// HIỂN THỊ TRẠNG THÁI HIỆN TẠI RA CELL
// ============================================================================
- (NSString *)getHzDisplayValue:(PSSpecifier *)specifier {
    @try {
        CFPropertyListRef enabledVal = CFPreferencesCopyAppValue(CFSTR("EnableHzControl"), PREF_DOMAIN);
        BOOL enabled = enabledVal ? [(__bridge id)enabledVal boolValue] : YES;
        if (enabledVal) CFRelease(enabledVal);
        
        if (!enabled) return @"Tắt";
        
        CFPropertyListRef hzVal = CFPreferencesCopyAppValue(CFSTR("TargetRefreshRate"), PREF_DOMAIN);
        NSInteger val = hzVal ? [(__bridge id)hzVal integerValue] : 60;
        if (hzVal) CFRelease(hzVal);
        
        if (val == 0) return @"Tự động";
        return [NSString stringWithFormat:@"Khóa ở %ld Hz", (long)val];
    } @catch (NSException *e) {
        return @"Khóa ở 60 Hz";
    }
}

- (NSString *)getFPSDisplayValue:(PSSpecifier *)specifier {
    @try {
        CFPropertyListRef enabledVal = CFPreferencesCopyAppValue(CFSTR("EnableFPSControl"), PREF_DOMAIN);
        BOOL enabled = enabledVal ? [(__bridge id)enabledVal boolValue] : YES;
        if (enabledVal) CFRelease(enabledVal);
        
        if (!enabled) return @"Tắt";
        
        CFPropertyListRef fpsVal = CFPreferencesCopyAppValue(CFSTR("TargetFPSRate"), PREF_DOMAIN);
        NSInteger val = fpsVal ? [(__bridge id)fpsVal integerValue] : 60;
        if (fpsVal) CFRelease(fpsVal);
        
        if (val == 0) return @"Tự động";
        return [NSString stringWithFormat:@"Khóa ở %ld FPS", (long)val];
    } @catch (NSException *e) {
        return @"Khóa ở 60 FPS";
    }
}

// ============================================================================
// BẬT BẢNG CHỌN ACTION SHEET CHUẨN 100% THEO ẢNH
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
                                 message:@"Lựa chọn mức hiển thị hệ thống:\n• Tự Động: Tự cân bằng theo nhiệt độ & tải\n• 30Hz: Tiết kiệm pin tối đa, giảm sinh nhiệt\n• 60Hz: Mặc định chuẩn\n• 90Hz - 120Hz - 144Hz: Tối ưu cảm ứng siêu mượt" 
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
        [weakSelf syncPreferenceValueToSystem:val forKey:prefKey];
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
                                                                   message:@"Respring để đồng bộ toàn diện SmoothiOS V22.2.6?"
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
                                                                   message:@"Khôi phục toàn bộ cài đặt gốc của SmoothiOS V22.2.6?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        NSDictionary *dict = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(NULL, PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        for (id key in dict) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, PREF_DOMAIN);
        }
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:FALLBACK_PREF_PATH error:nil];
        notify_post(NOTIFY_RELOAD);
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
