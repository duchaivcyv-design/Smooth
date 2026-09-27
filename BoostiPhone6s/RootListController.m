#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
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
- (void)setSpecifiers:(id)specifiers;
- (id)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (id)loadSpecifiersFromPlistName:(NSString *)name target:(id)target bundle:(NSBundle *)bundle;
- (void)reloadSpecifiers;
@end

@interface PSSpecifier : NSObject
+ (instancetype)preferenceSpecifierNamed:(NSString *)title target:(id)target set:(SEL)set get:(SEL)get detail:(Class)detail cell:(NSInteger)cell edit:(Class)edit;
- (id)propertyForKey:(NSString *)key;
- (void)setProperty:(id)property forKey:(NSString *)key;
@end

@interface RootListController : PSListController
@end

@implementation RootListController

// ==============================================================================
// 1. NẠP CHÍNH XÁC ROOT.PLIST TỪ BUNDLE ROOTLESS (SỬA TRIỆT ĐỂ LỖI TRẮNG MÀN)
// ==============================================================================

- (id)specifiers {
    if (!_specifiers) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        if (!bundle) {
            bundle = [NSBundle bundleWithPath:@"/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"];
        }
        if (!bundle) {
            bundle = [NSBundle bundleWithPath:@"/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"];
        }

        // Ưu tiên nạp kèm Bundle để loadSpecifiers đọc đúng file Root.plist
        if ([self respondsToSelector:@selector(loadSpecifiersFromPlistName:target:bundle:)]) {
            _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self bundle:bundle];
        } else {
            _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        }
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupApexNavigationItems];
}

// ==============================================================================
// 2. BỘ ĐỌC / GHI ĐỒNG BỘ 100% TẤT CẢ CÁC KEY VÀO BỘ NHỚ VÀ ĐĨA
// ==============================================================================

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return nil;

    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH];
    if (!prefs) {
        prefs = [NSMutableDictionary dictionaryWithContentsOfFile:FALLBACK_PREF_PATH];
    }

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

    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:targetPath];
    if (!prefs) {
        prefs = [NSMutableDictionary dictionaryWithContentsOfFile:FALLBACK_PREF_PATH] ?: [NSMutableDictionary dictionary];
    }

    [prefs setObject:value forKey:key];
    [prefs writeToFile:targetPath atomically:YES];

    // Ghi vào CFPreferences IPC cho SpringBoard nhận ngay tức thì
    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);

    NSString *notification = [specifier propertyForKey:@"PostNotification"];
    if (notification) {
        notify_post([notification UTF8String]);
    } else {
        notify_post(NOTIFY_RELOAD);
    }
}

// ==============================================================================
// 3. THANH ĐIỀU HƯỚNG GÓC PHẢI (HÀNH ĐỘNG & ĐẶT LẠI)
// ==============================================================================

- (void)setupApexNavigationItems {
    UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithTitle:@"Hành Động"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(presentSystemActionSheet)];
    actionBtn.tintColor = [UIColor systemBlueColor];

    UIBarButtonItem *resetBtn = [[UIBarButtonItem alloc] initWithTitle:@"Đặt Lại"
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(confirmResetAllSettings)];
    resetBtn.tintColor = [UIColor systemRedColor];

    self.navigationItem.rightBarButtonItems = @[actionBtn, resetBtn];
}

- (void)presentSystemActionSheet {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"ĐIỀU KHIỂN HỆ THỐNG V24"
                                                                   message:@"Khởi động lại tiến trình để tối ưu và áp dụng cấu hình"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    [sheet addAction:[UIAlertAction actionWithTitle:@"⚡️ Respring Nhanh (Giao Diện)"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self executeApexRespring];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"🔥 Khởi Động Không Gian Người Dùng (SReboot)"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self executeApexUserspaceReboot];
    }]];

    [sheet addAction:[UIAlertAction actionWithTitle:@"Hủy Bỏ"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

- (void)executeApexRespring {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        const char *launchctlPath = access("/var/jb/bin/launchctl", X_OK) == 0 ? "/var/jb/bin/launchctl" : "/bin/launchctl";
        pid_t pid;
        char *argv[] = {(char *)launchctlPath, (char *)"kickstart", (char *)"-k", (char *)"system/com.apple.backboardd", NULL};
        posix_spawn(&pid, launchctlPath, NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeApexUserspaceReboot {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        const char *launchctlPath = access("/var/jb/bin/launchctl", X_OK) == 0 ? "/var/jb/bin/launchctl" : "/bin/launchctl";
        pid_t pid;
        char *argv[] = {(char *)launchctlPath, (char *)"reboot", (char *)"userspace", NULL};
        posix_spawn(&pid, launchctlPath, NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)confirmResetAllSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xác Nhận Đặt Lại"
                                                                   message:@"Toàn bộ cấu hình sẽ được khôi phục về trạng thái tối ưu mặc định ban đầu."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại Toàn Bộ"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction * _Nonnull action) {
        [self performMasterReset];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy Bỏ"
                                             style:UIAlertActionStyleCancel
                                           handler:nil]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)performMasterReset {
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

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:PREF_PATH error:nil];
    [fm removeItemAtPath:FALLBACK_PREF_PATH error:nil];

    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    notify_post(NOTIFY_RELOAD);

    _specifiers = nil;
    [self reloadSpecifiers];
}

// ==============================================================================
// 4. POPUP CHỌN TẦN SỐ QUÉT HZ & KHUNG HÌNH FPS
// ==============================================================================

- (id)getHzDisplayValue:(PSSpecifier *)specifier {
    id val = [self readPreferenceValue:specifier];
    NSInteger rate = val ? [val integerValue] : 60;
    return [NSString stringWithFormat:@"%ld Hz", (long)rate];
}

- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CHỌN TẦN SỐ QUÉT MÀN HÌNH (HZ)"
                                                                   message:@"FPS mục tiêu sẽ được tự động đồng bộ theo mức Hz được chọn."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *rates = @[@60, @75, @90, @120, @144];
    for (NSNumber *rateNum in rates) {
        NSInteger rate = [rateNum integerValue];
        NSString *title = [NSString stringWithFormat:@"%ld Hz%@", (long)rate, (rate == 60 ? @" (Mặc định chuẩn)" : @" (Gia tốc mượt)")];
        
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
            PSSpecifier *hzSpec = [PSSpecifier new];
            [hzSpec setProperty:@"TargetRefreshRate" forKey:@"key"];
            [self setPreferenceValue:@(rate) specifier:hzSpec];

            PSSpecifier *fpsSpec = [PSSpecifier new];
            [fpsSpec setProperty:@"TargetFPSRate" forKey:@"key"];
            [self setPreferenceValue:@(rate) specifier:fpsSpec];

            _specifiers = nil;
            [self reloadSpecifiers];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (id)getFPSDisplayValue:(PSSpecifier *)specifier {
    id val = [self readPreferenceValue:specifier];
    NSInteger fps = val ? [val integerValue] : 60;
    return [NSString stringWithFormat:@"%ld FPS", (long)fps];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CHỌN MỨC KHUNG HÌNH (FPS)"
                                                                   message:@"Khuyến nghị chọn mức FPS tương đồng với tần số quét của máy."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *rates = @[@30, @60, @75, @90, @120, @144];
    for (NSNumber *fpsNum in rates) {
        NSInteger fps = [fpsNum integerValue];
        NSString *title = [NSString stringWithFormat:@"%ld FPS%@", (long)fps, (fps == 30 ? @" (Tiết kiệm pin)" : (fps == 60 ? @" (Chuẩn cân bằng)" : @" (Khung hình cao)"))];
        
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
            PSSpecifier *fpsSpec = [PSSpecifier new];
            [fpsSpec setProperty:@"TargetFPSRate" forKey:@"key"];
            [self setPreferenceValue:@(fps) specifier:fpsSpec];

            _specifiers = nil;
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
// 5. THÔNG TIN PHÁT TRIỂN & LIÊN KẾT HỖ TRỢ
// ==============================================================================

- (id)getAuthorName:(PSSpecifier *)specifier {
    return @"Đức LONG (TaoJB)";
}

- (id)getVersionString:(PSSpecifier *)specifier {
    return @"V24 Beta pro";
}

- (void)openSupportLink:(PSSpecifier *)specifier {
    NSURL *url = [NSURL URLWithString:@"0374288058"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

@end
