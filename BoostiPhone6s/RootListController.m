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

- (NSString *)effectivePrefPath {
    @try {
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm fileExistsAtPath:PREF_PATH]) {
            return PREF_PATH;
        }
    } @catch (NSException *e) {}
    return FALLBACK_PREF_PATH;
}

- (BOOL)isMasterEnabled {
    @try {
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFPropertyListRef val = CFPreferencesCopyAppValue(CFSTR("Enabled"), PREF_DOMAIN);
        if (val) {
            BOOL b = [(__bridge id)val boolValue];
            CFRelease(val);
            return b;
        }
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        if (prefs && prefs[@"Enabled"] != nil) {
            return [prefs[@"Enabled"] boolValue];
        }
    } @catch (NSException *e) {}
    return YES;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        @try {
            NSMutableArray *specs = [self loadSpecifiersFromPlistName:@"Root" target:self];
            BOOL masterOn = [self isMasterEnabled];
            
            for (PSSpecifier *spec in specs) {
                if (!spec) continue;
                NSString *key = spec.properties[@"key"];
                if ([key isEqualToString:@"Enabled"]) {
                    [spec setProperty:@YES forKey:@"enabled"];
                    continue;
                }
                // Khóa tương tác toàn bộ menu con nếu công tắc tổng bị TẮT
                [spec setProperty:@(masterOn) forKey:@"enabled"];
            }
            _specifiers = specs;
        } @catch (NSException *e) {
            _specifiers = [NSMutableArray array];
        }
    }
    return _specifiers;
}

- (void)updateSpecifiersStateAnimated:(BOOL)animated {
    @try {
        BOOL masterOn = [self isMasterEnabled];
        for (PSSpecifier *spec in _specifiers) {
            if (!spec) continue;
            NSString *key = spec.properties[@"key"];
            if ([key isEqualToString:@"Enabled"]) continue;
            [spec setProperty:@(masterOn) forKey:@"enabled"];
        }
        [self reloadSpecifiers];
    } @catch (NSException *e) {}
}

// GHI ĐỒNG BỘ 2 CHIỀU: RAM CFPREFERENCES VÀ FILE ĐĨA VẬT LÝ
- (void)syncPreferenceValueToSystem:(id)value forKey:(NSString *)key {
    if (!key) return;
    @try {
        // Kênh 1: Ghi trực tiếp vào bộ đệm CFPreferences
        CFStringRef cfKey = (__bridge CFStringRef)key;
        CFPreferencesSetAppValue(cfKey, (__bridge CFPropertyListRef)value, PREF_DOMAIN);
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        
        // Kênh 2: Ghi trực tiếp ra file đĩa vật lý để Tweak đọc tức thì 0ms
        NSString *primaryPath = PREF_PATH;
        NSString *fallbackPath = FALLBACK_PREF_PATH;
        
        NSMutableDictionary *primaryDict = [NSMutableDictionary dictionaryWithContentsOfFile:primaryPath] ?: [NSMutableDictionary dictionary];
        primaryDict[key] = value;
        [primaryDict writeToFile:primaryPath atomically:YES];
        
        NSMutableDictionary *fallbackDict = [NSMutableDictionary dictionaryWithContentsOfFile:fallbackPath] ?: [NSMutableDictionary dictionary];
        fallbackDict[key] = value;
        [fallbackDict writeToFile:fallbackPath atomically:YES];
        
        // Phát tín hiệu Darwin Notification ép SpringBoard nạp cấu hình mới ngay lập tức
        notify_post(NOTIFY_RELOAD);
    } @catch (NSException *e) {}
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    @try {
        NSString *key = specifier.properties[@"key"];
        if (!key) return specifier.properties[@"default"];
        
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, PREF_DOMAIN);
        if (val) {
            return (__bridge_transfer id)val;
        }
        
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[self effectivePrefPath]];
        if (prefs && prefs[key] != nil) {
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
        
        if ([key isEqualToString:@"Enabled"]) {
            [self updateSpecifiersStateAnimated:YES];
        }
    } @catch (NSException *e) {}
}

// ==============================================================================
// 🎯 HIỂN THỊ HZ/FPS TỨC THÌ (TRỰC QUAN - GIAO DIỆN HIỆN ĐẠI)
// ==============================================================================
- (NSString *)getHzDisplayValue:(PSSpecifier *)specifier {
    @try {
        if (![self isMasterEnabled]) return @"Đã tắt theo công tắc tổng";
        
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFPropertyListRef enabledVal = CFPreferencesCopyAppValue(CFSTR("EnableHzControl"), PREF_DOMAIN);
        BOOL enabled = enabledVal ? [(__bridge id)enabledVal boolValue] : YES;
        if (enabledVal) CFRelease(enabledVal);
        
        if (!enabled) return @"Chưa kích hoạt";
        
        CFPropertyListRef hzVal = CFPreferencesCopyAppValue(CFSTR("TargetRefreshRate"), PREF_DOMAIN);
        NSInteger val = hzVal ? [(__bridge id)hzVal integerValue] : 60;
        if (hzVal) CFRelease(hzVal);
        
        if (val == 0) return @"Tự động tối ưu";
        return [NSString stringWithFormat:@"%ld Hz (Đang khóa)", (long)val];
    } @catch (NSException *e) {
        return @"60 Hz (Mặc định)";
    }
}

- (NSString *)getFPSDisplayValue:(PSSpecifier *)specifier {
    @try {
        if (![self isMasterEnabled]) return @"Đã tắt theo công tắc tổng";
        
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFPropertyListRef enabledVal = CFPreferencesCopyAppValue(CFSTR("EnableFPSControl"), PREF_DOMAIN);
        BOOL enabled = enabledVal ? [(__bridge id)enabledVal boolValue] : YES;
        if (enabledVal) CFRelease(enabledVal);
        
        if (!enabled) return @"Chưa kích hoạt";
        
        CFPropertyListRef fpsVal = CFPreferencesCopyAppValue(CFSTR("TargetFPSRate"), PREF_DOMAIN);
        NSInteger val = fpsVal ? [(__bridge id)fpsVal integerValue] : 60;
        if (fpsVal) CFRelease(fpsVal);
        
        if (val == 0) return @"Tự động tối ưu";
        return [NSString stringWithFormat:@"%ld FPS (Đang khóa)", (long)val];
    } @catch (NSException *e) {
        return @"60 FPS (Mặc định)";
    }
}

- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    if (![self isMasterEnabled]) return;
    [self presentActionSheetForSpecifier:specifier 
                                   title:@"Tần Số Quét Màn Hình" 
                                 message:@"Chọn mức tần số quét phần cứng (Hz) mong muốn để ép xung:" 
                                     key:@"TargetRefreshRate" 
                                  suffix:@"Hz"];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    if (![self isMasterEnabled]) return;
    [self presentActionSheetForSpecifier:specifier 
                                   title:@"Tốc Độ Khung Hình Ứng Dụng" 
                                 message:@"Chọn mức giới hạn khung hình (FPS) mượt mà:" 
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
        
        NSString *masterSwitchKey = [prefKey isEqualToString:@"TargetRefreshRate"] ? @"EnableHzControl" : @"EnableFPSControl";
        [weakSelf syncPreferenceValueToSystem:@YES forKey:masterSwitchKey];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf reloadSpecifier:specifier animated:YES];
            [weakSelf reloadSpecifiers];
        });
    };

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Tự động thích ứng (Cân bằng)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@0);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"30 %@ - Tiết kiệm pin tối đa", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@30);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"60 %@ - Tiêu chuẩn ổn định", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@60);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"90 %@ - Mượt mà nâng cao", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@90);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"120 %@ - Cực kỳ mượt mà", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@120);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"144 %@ - Ép xung cực hạn", suffix] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        saveHandler(@144);
    }]];

    [actionSheet addAction:[UIAlertAction actionWithTitle:@"Đóng menu" style:UIAlertActionStyleCancel handler:nil]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UITableViewCell *cell = [self cachedCellForSpecifier:specifier];
        actionSheet.popoverPresentationController.sourceView = cell ? cell : self.view;
        actionSheet.popoverPresentationController.sourceRect = cell ? cell.bounds : CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0);
    }

    [self presentViewController:actionSheet animated:YES completion:nil];
}

- (void)respringDevice {
    if (![self isMasterEnabled]) return;
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Khởi Động Lại Giao Diện"
                                                                   message:@"Respring SpringBoard để nạp lại toàn bộ cấu hình mượt mà?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Respring ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            pid_t pid;
            const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
            posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)argv, environ);
        });
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetAllSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Khôi Phục Mặc Định"
                                                                   message:@"Đặt lại tất cả thiết lập về trạng thái xuất xưởng ban đầu?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Xác nhận đặt lại" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        NSDictionary *dict = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(NULL, PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        for (id key in dict) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key, NULL, PREF_DOMAIN);
        }
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:FALLBACK_PREF_PATH error:nil];
        notify_post(NOTIFY_RELOAD);
        
        _specifiers = nil;
        [self reloadSpecifiers];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
