#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <spawn.h>
#import <sys/wait.h>
#import <notify.h>

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"

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

@implementation RootListController

- (id)specifiers {
    if (!_specifiers) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        if (!bundle) bundle = [NSBundle bundleWithPath:@"/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"];
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self bundle:bundle];
        [self ensureDefaultSettingsExist];
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

// ==============================================================================
// 1. TỰ ĐỘNG KHỞI TẠO CẤU HÌNH MẶC ĐỊNH PHÂN BỔ TỐI ƯU
// ==============================================================================
- (void)ensureDefaultSettingsExist {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:PREF_PATH] && ![fm fileExistsAtPath:FALLBACK_PREF_PATH]) {
        NSString *dir = [PREF_PATH stringByDeletingLastPathComponent];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        }

        // Khởi tạo các giá trị mặc định tối ưu sẵn
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
            @"TcpTurboNetwork": @YES
        }];

        [defaults writeToFile:PREF_PATH atomically:YES];
        
        for (NSString *key in defaults) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)defaults[key], PREF_DOMAIN);
        }
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        notify_post(NOTIFY_RELOAD);
    }
}

// ==============================================================================
// 2. BỘ ĐỌC / GHI ĐỒNG BỘ 100% IPC VÀ FILE PLIST
// ==============================================================================
- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return nil;

    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH] ?: [NSDictionary dictionaryWithContentsOfFile:FALLBACK_PREF_PATH];
    if (prefs && prefs[key] != nil) {
        return prefs[key];
    }
    return [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return;

    NSString *targetPath = PREF_PATH;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [targetPath stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:targetPath] ?: [NSMutableDictionary dictionary];
    [prefs setObject:value forKey:key];
    [prefs writeToFile:targetPath atomically:YES];

    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);

    notify_post(NOTIFY_RELOAD);
}

// ==============================================================================
// 3. THÔNG TIN PHÁT TRIỂN & MỞ LIÊN KẾT NHÓM
// ==============================================================================
- (id)getAuthorName:(PSSpecifier *)specifier {
    return @"ĐỨC LONG";
}

- (id)getVersionString:(PSSpecifier *)specifier {
    return @"V24.4 Apex Ultra";
}

- (void)openSupportLink:(PSSpecifier *)specifier {
    NSURL *url = [NSURL URLWithString:@"https://github.com/duchaivcyv-design/Smooth"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    });
}

// ==============================================================================
// 4. THANH HÀNH ĐỘNG GÓC PHẢI
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
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    }
    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đặt Lại Cấu Hình" message:@"Khôi phục toàn bộ về giá trị mặc định tối ưu." preferredStyle:UIAlertControllerStyleAlert];
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
        [self ensureDefaultSettingsExist];
        [self reloadSpecifiers];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
