#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <notify.h>

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"

// Tín hiệu đồng bộ tức thì cho tầng ứng dụng UIKit bên thứ 3
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"

extern char **environ;

@interface PSListController : UIViewController {
    id _specifiers;
}
- (id)specifiers;
- (void)reloadSpecifiers;
- (id)loadSpecifiersFromPlistName:(NSString *)name target:(id)target bundle:(NSBundle *)bundle;
@end

@interface PSSpecifier : NSObject
@property (nonatomic, strong) NSString *name;
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)property forKey:(NSString *)key;
@end

@interface RootListController : PSListController
@end

static inline UIAlertController *alertPresentationControllerHelper(UIAlertController *alert, UIViewController *vc) {
    if (alert.popoverPresentationController && vc.navigationItem.rightBarButtonItems.count > 0) {
        alert.popoverPresentationController.barButtonItem = vc.navigationItem.rightBarButtonItems.firstObject;
    }
    return alert;
}

@implementation RootListController

- (id)specifiers {
    if (!_specifiers) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        if (!bundle) bundle = [NSBundle bundleWithPath:@"/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"];
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self bundle:bundle];
        [self ensureDefaultSettingsExist];
        [self updateDynamicTitles];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupNavigationItems];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateDynamicTitles];
    [self reloadSpecifiers];
}

// Cập nhật giá trị hiển thị rõ ràng ra ngoài dòng chữ song hành cho cả SpringBoard và App
- (void)updateDynamicTitles {
    NSDictionary *prefs = [self getMergedPreferences];
    BOOL isDynamic = prefs[@"ProMotionEngineBeta3"] ? [prefs[@"ProMotionEngineBeta3"] boolValue] : YES;
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 90;
    NSInteger fps = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 90;

    for (PSSpecifier *spec in (NSArray *)_specifiers) {
        NSString *key = [spec propertyForKey:@"key"];
        if ([key isEqualToString:@"TargetRefreshRate"]) {
            if (isDynamic) {
                spec.name = [NSString stringWithFormat:@"Chọn Mức Tần Số Quét: Tự Động (Max %ld Hz)", (long)hz];
            } else {
                spec.name = [NSString stringWithFormat:@"Chọn Mức Tần Số Quét: Khóa %ld Hz", (long)hz];
            }
        } else if ([key isEqualToString:@"TargetFPSRate"]) {
            if (isDynamic) {
                spec.name = [NSString stringWithFormat:@"Chọn Mức Khung Hình: Tự Động (Max %ld FPS)", (long)fps];
            } else {
                spec.name = [NSString stringWithFormat:@"Chọn Mức Khung Hình: Khóa %ld FPS", (long)fps];
            }
        }
    }
}

// Helper gom dữ liệu đồng nhất giữa CFPreferences và Disk Plist
- (NSDictionary *)getMergedPreferences {
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    NSDictionary *diskDict = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:PREF_PATH]) {
        diskDict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:FALLBACK_PREF_PATH]) {
        diskDict = [NSDictionary dictionaryWithContentsOfFile:FALLBACK_PREF_PATH];
    }
    return diskDict ?: [NSDictionary dictionary];
}

// ==============================================================================
// 1. TỰ ĐỘNG KHỞI TẠO CẤU HÌNH MẶC ĐỊNH (TỐI ƯU CẢ SPRINGBOARD VÀ UIKIT)
// ==============================================================================
- (void)ensureDefaultSettingsExist {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:PREF_PATH] && ![fm fileExistsAtPath:FALLBACK_PREF_PATH]) {
        NSString *dir = [PREF_PATH stringByDeletingLastPathComponent];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
        }

        NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithDictionary:@{
            @"Enabled": @YES,
            @"ProMotionEngineBeta3": @YES,
            @"HeavyEffectAntiLagV24": @YES,
            @"KeyboardZeroLagV24": @YES,
            @"EnableHzControl": @YES,
            @"TargetRefreshRate": @90,
            @"EnableFPSControl": @YES,
            @"TargetFPSRate": @90,
            @"ForceOverclock144Hz": @NO,
            @"ColorOs17SmoothEngine": @YES,
            @"ReduceMultiTaskLag": @YES,
            @"FixAppLaunchBlackScreen": @YES,
            @"FixAppExitStutter": @YES,
            @"TouchResponseBoost": @YES,
            @"QuantumRenderShieldOfficial": @YES,
            @"NeuralBufferOptimizerOfficial": @YES,
            @"ApexBackgroundPacingDaemon": @YES,
            @"HyperMemoryGuardian": @YES,
            @"UltraResponsivenessProEngineOfficial": @YES,
            @"HyperThreadIOAcceleratorOfficial": @YES,
            @"QuantumCoreSyncStabilizerOfficial": @YES,
            @"ZeroLagNeuralBoosterOfficial": @YES,
            @"VsyncAdaptiveBufferOfficial": @YES,
            @"DynamicThermalEngineOfficial": @YES,
            @"Ios27AutoScheduler": @YES,
            @"RealtimePriorityBoost": @YES,
            @"BoostCpuGpu": @YES,
            @"SmartRamClean": @YES,
            @"AggressiveRamClean": @NO,
            @"KillBgApps": @NO,
            @"TurboAppLaunch": @YES,
            @"MetalTripleBuffering": @YES,
            @"GameFpsStabilizer": @YES,
            @"OptimizeSystemProcess": @YES,
            @"AutoSpoofNewDevice": @YES,
            @"AntiThermalThrottling": @YES,
            @"SmartThermalManager": @YES,
            @"HeavyLoadCooling": @YES,
            @"ChargeCoolingProtection": @YES,
            @"PowerSaveMode": @NO,
            @"BypassVarSandbox": @NO,
            @"BlockAnalytics": @YES,
            @"TcpTurboNetwork": @YES,
            @"UIKitIsolatedSmooth": @YES,
            @"UIKitAsyncImageDecoders": @YES,
            @"UIKitAntiStallPacing": @YES
        }];

        NSArray *targets = @[PREF_PATH, FALLBACK_PREF_PATH];
        for (NSString *tPath in targets) {
            NSString *tDir = [tPath stringByDeletingLastPathComponent];
            if (![fm fileExistsAtPath:tDir]) {
                [fm createDirectoryAtPath:tDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
            }
            [defaults writeToFile:tPath atomically:YES];
            chmod([tPath UTF8String], 0644);
        }

        for (NSString *key in defaults) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)defaults[key], PREF_DOMAIN);
        }
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
    }
}

// ==============================================================================
// 2. BỘ ĐỌC / GHI ĐỒNG BỘ KÉP (CFPREFERENCES + TỆP PLIST DISK CHO UIKIT APP CONTAINER)
// ==============================================================================
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return [specifier propertyForKey:@"default"];

    CFPreferencesAppSynchronize(PREF_DOMAIN);
    CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, PREF_DOMAIN);
    if (val) {
        return (__bridge_transfer id)val;
    }

    NSDictionary *prefs = [self getMergedPreferences];
    if (prefs && prefs[key] != nil) {
        return prefs[key];
    }

    return [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return;

    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);

    NSArray *targets = @[PREF_PATH, FALLBACK_PREF_PATH];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *targetPath in targets) {
        NSString *dir = [targetPath stringByDeletingLastPathComponent];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
        }

        NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:targetPath] ?: [NSMutableDictionary dictionary];
        [prefs setObject:value forKey:key];
        [prefs writeToFile:targetPath atomically:YES];
        chmod([targetPath UTF8String], 0644);
    }

    notify_post(NOTIFY_RELOAD);
    notify_post(NOTIFY_UIKIT_RELOAD);
}

// ==============================================================================
// 3. POPUP TAB DẠNG CARD KÈM MỨC 30 HZ & ĐỒNG BỘ TOÀN DIỆN CHO MỌI ỨNG DỤNG
// ==============================================================================
- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chọn Mức Tần Số Quét (Hz)"
                                                                   message:@"Lựa chọn mức hiển thị cho Hệ thống và toàn bộ ứng dụng:\n• Tự Động: Tự cân bằng theo nhiệt độ & tải\n• 30Hz: Tiết kiệm pin tối đa, giảm sinh nhiệt\n• 60Hz: Mặc định chuẩn cân bằng\n• 75Hz - 90Hz: Tối ưu cảm ứng mượt mà\n• 120Hz - 144Hz: Tần số quét cực đại"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *options = @[
        @{@"title": @"Tự Động Điều Chỉnh (Dynamic)", @"rate": @90, @"dynamic": @YES},
        @{@"title": @"Khóa ở 30 Hz (Tiết kiệm pin)", @"rate": @30, @"dynamic": @NO},
        @{@"title": @"Khóa ở 60 Hz (Mặc định)", @"rate": @60, @"dynamic": @NO},
        @{@"title": @"Khóa ở 75 Hz (Mượt mà)", @"rate": @75, @"dynamic": @NO},
        @{@"title": @"Khóa ở 90 Hz (Mượt mà)", @"rate": @90, @"dynamic": @NO},
        @{@"title": @"Khóa ở 120 Hz (Cực mượt)", @"rate": @120, @"dynamic": @NO},
        @{@"title": @"Khóa ở 144 Hz (Cực đại)", @"rate": @144, @"dynamic": @NO}
    ];

    for (NSDictionary *opt in options) {
        [alert addAction:[UIAlertAction actionWithTitle:opt[@"title"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSInteger rate = [opt[@"rate"] integerValue];
            BOOL dynamicMode = [opt[@"dynamic"] boolValue];

            NSArray *targets = @[PREF_PATH, FALLBACK_PREF_PATH];
            for (NSString *targetPath in targets) {
                NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:targetPath] ?: [NSMutableDictionary dictionary];
                [prefs setObject:@(rate) forKey:@"TargetRefreshRate"];
                [prefs setObject:@(rate) forKey:@"TargetFPSRate"];
                [prefs setObject:@(dynamicMode) forKey:@"ProMotionEngineBeta3"];
                [prefs writeToFile:targetPath atomically:YES];
                chmod([targetPath UTF8String], 0644);
            }

            CFPreferencesSetAppValue(CFSTR("TargetRefreshRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
            CFPreferencesSetAppValue(CFSTR("TargetFPSRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
            CFPreferencesSetAppValue(CFSTR("ProMotionEngineBeta3"), (__bridge CFPropertyListRef)@(dynamicMode), PREF_DOMAIN);
            CFPreferencesAppSynchronize(PREF_DOMAIN);

            notify_post(NOTIFY_RELOAD);
            notify_post(NOTIFY_UIKIT_RELOAD);
            notify_post("com.taojb.boostiphone6s/HardwareSync");

            [self updateDynamicTitles];
            [self reloadSpecifiers];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chọn Mức Khung Hình Ứng Dụng (FPS)"
                                                                   message:@"Lựa chọn mức hiển thị cho Hệ thống và toàn bộ ứng dụng:\n• Tự Động: Tự cân bằng theo nhiệt độ & tải\n• 30 FPS: Tiết kiệm pin tối đa, giảm sinh nhiệt\n• 60 FPS: Mặc định chuẩn cân bằng\n• 75 FPS - 90 FPS: Khung hình nâng cao mượt mà\n• 120 FPS - 144 FPS: Khung hình cực đại"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *options = @[
        @{@"title": @"Tự Động Điều Chỉnh (Dynamic)", @"fps": @90, @"dynamic": @YES},
        @{@"title": @"Khóa ở 30 FPS (Tiết kiệm pin)", @"fps": @30, @"dynamic": @NO},
        @{@"title": @"Khóa ở 60 FPS (Mặc định)", @"fps": @60, @"dynamic": @NO},
        @{@"title": @"Khóa ở 75 FPS (Nâng cao)", @"fps": @75, @"dynamic": @NO},
        @{@"title": @"Khóa ở 90 FPS (Mượt mà)", @"fps": @90, @"dynamic": @NO},
        @{@"title": @"Khóa ở 120 FPS (Cực mượt)", @"fps": @120, @"dynamic": @NO},
        @{@"title": @"Khóa ở 144 FPS (Cực đại)", @"fps": @144, @"dynamic": @NO}
    ];

    for (NSDictionary *opt in options) {
        [alert addAction:[UIAlertAction actionWithTitle:opt[@"title"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            NSInteger fps = [opt[@"fps"] integerValue];
            BOOL dynamicMode = [opt[@"dynamic"] boolValue];

            NSArray *targets = @[PREF_PATH, FALLBACK_PREF_PATH];
            for (NSString *targetPath in targets) {
                NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:targetPath] ?: [NSMutableDictionary dictionary];
                [prefs setObject:@(fps) forKey:@"TargetFPSRate"];
                [prefs setObject:@(fps) forKey:@"TargetRefreshRate"];
                [prefs setObject:@(dynamicMode) forKey:@"ProMotionEngineBeta3"];
                [prefs writeToFile:targetPath atomically:YES];
                chmod([targetPath UTF8String], 0644);
            }

            CFPreferencesSetAppValue(CFSTR("TargetFPSRate"), (__bridge CFPropertyListRef)@(fps), PREF_DOMAIN);
            CFPreferencesSetAppValue(CFSTR("TargetRefreshRate"), (__bridge CFPropertyListRef)@(fps), PREF_DOMAIN);
            CFPreferencesSetAppValue(CFSTR("ProMotionEngineBeta3"), (__bridge CFPropertyListRef)@(dynamicMode), PREF_DOMAIN);
            CFPreferencesAppSynchronize(PREF_DOMAIN);

            notify_post(NOTIFY_RELOAD);
            notify_post(NOTIFY_UIKIT_RELOAD);
            notify_post("com.taojb.boostiphone6s/HardwareSync");

            [self updateDynamicTitles];
            [self reloadSpecifiers];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

// ==============================================================================
// 4. THÔNG TIN PHÁT TRIỂN & LIÊN KẾT NHÓM
// ==============================================================================
- (id)getAuthorName:(PSSpecifier *)specifier {
    return @"ĐỨC LONG";
}

- (id)getVersionString:(PSSpecifier *)specifier {
    return @"V23.4.4.2 Apex Ultra";
}

- (void)openSupportLink:(PSSpecifier *)specifier {
    NSURL *url = [NSURL URLWithString:@"https://github.com/duchaivcyv-design/Smooth"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    });
}

// ==============================================================================
// 5. THANH ĐIỀU HƯỚNG GÓC PHẢI & THAO TÁC HỆ THỐNG
// ==============================================================================
- (void)setupNavigationItems {
    UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithTitle:@"Hành Động"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(presentActions)];
    actionBtn.tintColor = [UIColor systemBlueColor];

    UIBarButtonItem *resetBtn = [[UIBarButtonItem alloc] initWithTitle:@"Đặt Lại"
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(resetSettings)];
    resetBtn.tintColor = [UIColor systemRedColor];

    self.navigationItem.rightBarButtonItems = @[actionBtn, resetBtn];
}

- (void)presentActions {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"HÀNH ĐỘNG HỆ THỐNG" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [sheet addAction:[UIAlertAction actionWithTitle:@"⚡️ Respring Nhanh" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            const char *path = access("/var/jb/bin/launchctl", X_OK) == 0 ? "/var/jb/bin/launchctl" : "/bin/launchctl";
            pid_t pid;
            char *argv[] = {(char *)path, (char *)"kickstart", (char *)"-k", (char *)"system/com.apple.backboardd", NULL};
            posix_spawn(&pid, path, NULL, NULL, argv, environ);
            waitpid(pid, NULL, 0);
        });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"🔥 Khởi Động Không Gian Người Dùng (SReboot)" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            const char *path = access("/var/jb/bin/launchctl", X_OK) == 0 ? "/var/jb/bin/launchctl" : "/bin/launchctl";
            pid_t pid;
            char *argv[] = {(char *)path, (char *)"reboot", (char *)"userspace", NULL};
            posix_spawn(&pid, path, NULL, NULL, argv, environ);
            waitpid(pid, NULL, 0);
        });
    }]];
    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    
    UIAlertController *configuredSheet = alertPresentationControllerHelper(sheet, self);
    [self presentViewController:configuredSheet animated:YES completion:nil];
}

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đặt Lại Cấu Hình" message:@"Khôi phục toàn bộ về giá trị mặc định tối ưu cho cả SpringBoard và UIKit App." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:FALLBACK_PREF_PATH error:nil];
        
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFArrayRef keyList = CFPreferencesCopyKeyList(PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (keyList) {
            for (CFIndex i = 0; i < CFArrayGetCount(keyList); i++) {
                CFStringRef key = (CFStringRef)CFArrayGetValueAtIndex(keyList, i);
                CFPreferencesSetAppValue(key, NULL, PREF_DOMAIN);
            }
            CFRelease(keyList);
        }
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);

        [self ensureDefaultSettingsExist];
        [self updateDynamicTitles];
        [self reloadSpecifiers];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
