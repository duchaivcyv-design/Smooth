// ==============================================================================
// 🚀 ROOTLISTCONTROLLER.M - DYNAMIC MASTER SWITCH & LAZY SYNC CONTROLLER
// 🛠 PHIÊN BẢN V24.8.7 APEX SUPREME - ĐỒNG BỘ ĐỘ TRỄ NẠP VÀ ẨN/HIỆN PHÍM TỰ ĐỘNG
// ==============================================================================

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>
#import <notify.h>

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define SHARED_SYNC_FILE @"/tmp/.boost_hz_sync"

#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"

extern char **environ;

typedef struct {
    uint32_t magic;
    BOOL masterEnabled;
    int32_t targetHz;
    int32_t targetFPS;
    BOOL isDynamic;
    uint64_t updateSeq;
} ApexSharedSyncPayload;

#define APEX_SYNC_MAGIC 0x41504558

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openURL:(NSURL *)url;
@end

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

@interface RootListController : PSListController {
    NSArray *_allSavedSpecifiers;
}
@end

static inline UIAlertController *alertPresentationControllerHelper(UIAlertController *alert, UIViewController *vc) {
    if (alert.popoverPresentationController && vc.navigationItem.rightBarButtonItem) {
        alert.popoverPresentationController.barButtonItem = vc.navigationItem.rightBarButtonItem;
    }
    return alert;
}

@implementation RootListController

- (void)syncSharedMemoryFile:(BOOL)enabled {
    NSDictionary *prefs = [self getMergedPreferences];
    int32_t hz = prefs[@"TargetRefreshRate"] ? (int32_t)[prefs[@"TargetRefreshRate"] intValue] : 60;
    int32_t fps = prefs[@"TargetFPSRate"] ? (int32_t)[prefs[@"TargetFPSRate"] intValue] : 60;
    BOOL dyn = prefs[@"ProMotionEngineBeta7"] ? [prefs[@"ProMotionEngineBeta7"] boolValue] : YES;

    ApexSharedSyncPayload payload;
    payload.magic = APEX_SYNC_MAGIC;
    payload.masterEnabled = enabled;
    payload.targetHz = hz;
    payload.targetFPS = fps;
    payload.isDynamic = dyn;
    payload.updateSeq = (uint64_t)mach_absolute_time();

    int fd = open([SHARED_SYNC_FILE UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        write(fd, &payload, sizeof(payload));
        close(fd);
        chmod([SHARED_SYNC_FILE UTF8String], 0666);
    }
}

- (id)specifiers {
    if (!_allSavedSpecifiers) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        if (!bundle) bundle = [NSBundle bundleWithPath:@"/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"];
        _allSavedSpecifiers = [self loadSpecifiersFromPlistName:@"Root" target:self bundle:bundle];
        [self ensureDefaultSettingsExist];
    }

    NSDictionary *prefs = [self getMergedPreferences];
    BOOL isMasterEnabled = prefs[@"Enabled"] ? [prefs[@"Enabled"] boolValue] : YES;

    if (!isMasterEnabled) {
        NSMutableArray *minimalSpecifiers = [NSMutableArray array];
        if (_allSavedSpecifiers.count >= 2) {
            [minimalSpecifiers addObject:_allSavedSpecifiers[0]];
            [minimalSpecifiers addObject:_allSavedSpecifiers[1]];
        }
        _specifiers = minimalSpecifiers;
    } else {
        _specifiers = [_allSavedSpecifiers mutableCopy];
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
    [self reloadSpecifiers];
}

- (void)updateDynamicTitles {
    NSDictionary *prefs = [self getMergedPreferences];
    BOOL isDynamic = prefs[@"ProMotionEngineBeta7"] ? [prefs[@"ProMotionEngineBeta7"] boolValue] : YES;
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 60;
    NSInteger fps = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 60;

    for (PSSpecifier *spec in (NSArray *)_specifiers) {
        NSString *key = [spec propertyForKey:@"key"];
        if ([key isEqualToString:@"TargetRefreshRate"]) {
            spec.name = isDynamic ? [NSString stringWithFormat:@"Chọn Mức Tần Số Quét: Tự Động (Max %ld Hz)", (long)hz] : [NSString stringWithFormat:@"Chọn Mức Tần Số Quét: Khóa %ld Hz", (long)hz];
        } else if ([key isEqualToString:@"TargetFPSRate"]) {
            spec.name = isDynamic ? [NSString stringWithFormat:@"Chọn Mức Khung Hình: Tự Động (Max %ld FPS)", (long)fps] : [NSString stringWithFormat:@"Chọn Mức Khung Hình: Khóa %ld FPS", (long)fps];
        }
    }
}

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

- (void)ensureDefaultSettingsExist {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:PREF_PATH] && ![fm fileExistsAtPath:FALLBACK_PREF_PATH]) {
        NSString *dir = [PREF_PATH stringByDeletingLastPathComponent];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
        }

        NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithDictionary:@{
            @"Enabled": @YES,
            @"ProMotionEngineBeta7": @YES,
            @"HeavyEffectAntiLagV24": @YES,
            @"KeyboardZeroLagV24": @YES,
            @"EnableHzControl": @YES,
            @"TargetRefreshRate": @60,
            @"EnableFPSControl": @YES,
            @"TargetFPSRate": @60,
            @"ForceOverclock144Hz": @NO,
            @"AppLazyInjectionSync": @YES,
            @"AppRenderShieldIsolation": @YES,
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
            @"BlockAnalytics": @YES
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

        [self syncSharedMemoryFile:YES];
        notify_post(NOTIFY_RELOAD);
        notify_post(NOTIFY_UIKIT_RELOAD);
    }
}

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

    BOOL currentEnabled = [key isEqualToString:@"Enabled"] ? [value boolValue] : ([self getMergedPreferences][@"Enabled"] ? [[self getMergedPreferences][@"Enabled"] boolValue] : YES);
    [self syncSharedMemoryFile:currentEnabled];

    notify_post(NOTIFY_RELOAD);
    notify_post(NOTIFY_UIKIT_RELOAD);

    if ([key isEqualToString:@"Enabled"]) {
        [self reloadSpecifiers];
    }
}

- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Chọn Mức Tần Số Quét (Hz)"
                                                                   message:@"Lựa chọn mức hiển thị cho Hệ thống và toàn bộ ứng dụng:\n• Tự Động: Tự cân bằng theo nhiệt độ & tải\n• 30Hz: Tiết kiệm pin tối đa, giảm sinh nhiệt\n• 60Hz: Mặc định chuẩn cân bằng\n• 75Hz - 90Hz: Tối ưu cảm ứng mượt mà\n• 120Hz - 144Hz: Tần số quét cực đại"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *options = @[
        @{@"title": @"Tự Động Điều Chỉnh (Dynamic)", @"rate": @60, @"dynamic": @YES},
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
                [prefs setObject:@(dynamicMode) forKey:@"ProMotionEngineBeta7"];
                [prefs writeToFile:targetPath atomically:YES];
                chmod([targetPath UTF8String], 0644);
            }

            CFPreferencesSetAppValue(CFSTR("TargetRefreshRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
            CFPreferencesSetAppValue(CFSTR("TargetFPSRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
            CFPreferencesSetAppValue(CFSTR("ProMotionEngineBeta7"), (__bridge CFPropertyListRef)@(dynamicMode), PREF_DOMAIN);
            CFPreferencesAppSynchronize(PREF_DOMAIN);

            [self syncSharedMemoryFile:YES];
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
        @{@"title": @"Tự Động Điều Chỉnh (Dynamic)", @"fps": @60, @"dynamic": @YES},
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
                [prefs setObject:@(dynamicMode) forKey:@"ProMotionEngineBeta7"];
                [prefs writeToFile:targetPath atomically:YES];
                chmod([targetPath UTF8String], 0644);
            }

            CFPreferencesSetAppValue(CFSTR("TargetFPSRate"), (__bridge CFPropertyListRef)@(fps), PREF_DOMAIN);
            CFPreferencesSetAppValue(CFSTR("TargetRefreshRate"), (__bridge CFPropertyListRef)@(fps), PREF_DOMAIN);
            CFPreferencesSetAppValue(CFSTR("ProMotionEngineBeta7"), (__bridge CFPropertyListRef)@(dynamicMode), PREF_DOMAIN);
            CFPreferencesAppSynchronize(PREF_DOMAIN);

            [self syncSharedMemoryFile:YES];
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

- (id)getAuthorName:(PSSpecifier *)specifier {
    return @"ĐỨC LONG";
}

- (id)getVersionString:(PSSpecifier *)specifier {
    return @"V24.8.7 DEBUG";
}

- (void)openSupportLink:(PSSpecifier *)specifier {
    NSURL *webURL = [NSURL URLWithString:@"https://zalo.me/g/qjd56ltkraiih88ps6ui"];
    dispatch_async(dispatch_get_main_queue(), ^{
        Class workspaceClass = objc_getClass("LSApplicationWorkspace");
        if (workspaceClass && [workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
            LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
            if ([workspace respondsToSelector:@selector(openURL:)]) {
                if ([workspace openURL:webURL]) return;
            }
        }

        UIApplication *app = [UIApplication sharedApplication];
        if ([app respondsToSelector:@selector(openURL:options:completionHandler:)]) {
            [app openURL:webURL options:@{} completionHandler:nil];
        } else {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [app openURL:webURL];
            #pragma clang diagnostic pop
        }
    });
}

- (void)setupNavigationItems {
    UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithTitle:@"Hành Động"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(presentActions)];
    actionBtn.tintColor = [UIColor systemBlueColor];
    self.navigationItem.rightBarButtonItem = actionBtn;
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

    [sheet addAction:[UIAlertAction actionWithTitle:@"🔥 Khởi Động Không Gian Người Dùng (SReboot)" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            const char *path = access("/var/jb/bin/launchctl", X_OK) == 0 ? "/var/jb/bin/launchctl" : "/bin/launchctl";
            pid_t pid;
            char *argv[] = {(char *)path, (char *)"reboot", (char *)"userspace", NULL};
            posix_spawn(&pid, path, NULL, NULL, argv, environ);
            waitpid(pid, NULL, 0);
        });
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"♻️ Đặt Lại Cấu Hình Mặc Định" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self executeResetConfiguration];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    UIAlertController *configuredSheet = alertPresentationControllerHelper(sheet, self);
    [self presentViewController:configuredSheet animated:YES completion:nil];
}

- (void)executeResetConfiguration {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xác Nhận Đặt Lại" message:@"Toàn bộ cài đặt sẽ được đưa về giá trị mặc định tối ưu nhất." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại Ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:FALLBACK_PREF_PATH error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SHARED_SYNC_FILE error:nil];

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

        [self syncSharedMemoryFile:YES];
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
