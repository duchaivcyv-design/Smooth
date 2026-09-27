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

// Khai báo giao diện tương thích Runtime không cần link cứng Private Framework
@interface PSListController : UIViewController
- (id)loadSpecifiersFromPlistName:(NSString *)name target:(id)target;
- (void)reloadSpecifiers;
- (void)setPreferenceValue:(id)value specifier:(id)specifier;
- (id)readPreferenceValue:(id)specifier;
@end

@interface RootListController : PSListController
@property (nonatomic, strong) id specifiers;
@end

@implementation RootListController

- (id)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupApexNavigationItems];
}

// ==============================================================================
// 1. GIAO DIỆN THANH ĐIỀU HƯỚNG GÓC PHẢI (ACTION MENU & RESET)
// ==============================================================================

- (void)setupApexNavigationItems {
    // Nút Menu Hành Động (Respring & Userspace Reboot)
    UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithTitle:@"Hành Động"
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:self
                                                                 action:@selector(presentSystemActionSheet)];
    actionBtn.tintColor = [UIColor systemBlueColor];

    // Nút Đặt Lại Cấu Hình Mặc Định
    UIBarButtonItem *resetBtn = [[UIBarButtonItem alloc] initWithTitle:@"Đặt Lại"
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(confirmResetAllSettings)];
    resetBtn.tintColor = [UIColor systemRedColor];

    self.navigationItem.rightBarButtonItems = @[actionBtn, resetBtn];
}

- (void)presentSystemActionSheet {
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"ĐIỀU KHIỂN HỆ THỐNG V24"
                                                                   message:@"Khởi động lại tiến trình để tối ưu và áp dụng cấu hình phần cứng"
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

    // Tương thích hiển thị trên iPad
    if (sheet.popoverPresentationController) {
        sheet.popoverPresentationController.barButtonItem = self.navigationItem.rightBarButtonItems.firstObject;
    }

    [self presentViewController:sheet animated:YES completion:nil];
}

// ==============================================================================
// 2. THỰC THI LỆNH HỆ THỐNG CẤP NHỊ PHÂN ROOTLESS (LAUNCHCTL DIRECT EXEC)
// ==============================================================================

- (void)executeApexRespring {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        const char *launchctlPath = NULL;
        if (access("/var/jb/bin/launchctl", X_OK) == 0) {
            launchctlPath = "/var/jb/bin/launchctl";
        } else if (access("/var/jb/usr/bin/launchctl", X_OK) == 0) {
            launchctlPath = "/var/jb/usr/bin/launchctl";
        } else {
            launchctlPath = "/bin/launchctl";
        }

        pid_t pid;
        char *argv[] = {(char *)launchctlPath, (char *)"kickstart", (char *)"-k", (char *)"system/com.apple.backboardd", NULL};
        posix_spawn(&pid, launchctlPath, NULL, NULL, argv, environ);
        int status;
        waitpid(pid, &status, 0);
    });
}

- (void)executeApexUserspaceReboot {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        const char *launchctlPath = NULL;
        if (access("/var/jb/bin/launchctl", X_OK) == 0) {
            launchctlPath = "/var/jb/bin/launchctl";
        } else if (access("/var/jb/usr/bin/launchctl", X_OK) == 0) {
            launchctlPath = "/var/jb/usr/bin/launchctl";
        } else {
            launchctlPath = "/bin/launchctl";
        }

        pid_t pid;
        char *argv[] = {(char *)launchctlPath, (char *)"reboot", (char *)"userspace", NULL};
        posix_spawn(&pid, launchctlPath, NULL, NULL, argv, environ);
        int status;
        waitpid(pid, &status, 0);
    });
}

// ==============================================================================
// 3. ĐẶT LẠI TOÀN BỘ CẤU HÌNH VỀ GỐC (RESET DEFAULTS SẠCH SẼ)
// ==============================================================================

- (void)confirmResetAllSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xác Nhận Đặt Lại"
                                                                   message:@"Toàn bộ các khóa cấu hình V23.9 và V24 sẽ được xóa sạch và khôi phục về giá trị mặc định tối ưu nhất."
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
    // 1. Xóa toàn bộ key trong CFPreferences IPC
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

    // 2. Xóa các tệp plist vật lý lưu trên đĩa Rootless
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:PREF_PATH error:nil];
    [fm removeItemAtPath:FALLBACK_PREF_PATH error:nil];

    // 3. Xóa cờ SafeMode nếu có
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BoostV20_SafeModeActive"];
    [[NSUserDefaults standardUserDefaults] synchronize];

    // 4. Phát tín hiệu thông báo cho Tweak.xm tải lại cấu hình gốc
    notify_post(NOTIFY_RELOAD);

    // 5. Làm mới lại danh sách Specifiers giao diện
    [self reloadSpecifiers];
}

// ==============================================================================
// 4. BỘ CHỌN POPUP HZ & FPS ĐỒNG BỘ 100% CẢ HAI CHIỀU
// ==============================================================================

- (id)getHzDisplayValue:(id)specifier {
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    CFPropertyListRef val = CFPreferencesCopyAppValue(CFSTR("TargetRefreshRate"), PREF_DOMAIN);
    NSInteger rate = 60;
    if (val) {
        rate = [(__bridge id)val integerValue];
        CFRelease(val);
    }
    return [NSString stringWithFormat:@"%ld Hz", (long)rate];
}

- (void)showHzPickerPopup:(id)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CHỌN TẦN SỐ QUÉT MÀN HÌNH (HZ)"
                                                                   message:@"Mức FPS mục tiêu sẽ được tự động đồng bộ khớp chính xác với mức Hz được chọn."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *rates = @[@60, @75, @90, @120, @144];
    for (NSNumber *rateNum in rates) {
        NSInteger rate = [rateNum integerValue];
        NSString *title = [NSString stringWithFormat:@"%ld Hz%@", (long)rate, (rate == 60 ? @" (Mặc định mượt/mát)" : @" (Gia tốc siêu mượt)")];
        
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
            // Ghi nhận Hz
            CFPreferencesSetAppValue(CFSTR("TargetRefreshRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
            // Tự động đồng bộ sang FPS
            CFPreferencesSetAppValue(CFSTR("TargetFPSRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
            CFPreferencesAppSynchronize(PREF_DOMAIN);

            notify_post(NOTIFY_RELOAD);
            [self reloadSpecifiers];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if (alert.popoverPresentationController) {
        alert.popoverPresentationController.sourceView = self.view;
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (id)getFPSDisplayValue:(id)specifier {
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    CFPropertyListRef val = CFPreferencesCopyAppValue(CFSTR("TargetFPSRate"), PREF_DOMAIN);
    NSInteger fps = 60;
    if (val) {
        fps = [(__bridge id)val integerValue];
        CFRelease(val);
    }
    return [NSString stringWithFormat:@"%ld FPS", (long)fps];
}

- (void)showFPSPickerPopup:(id)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CHỌN MỨC KHUNG HÌNH (FPS)"
                                                                   message:@"Khuyến nghị chọn mức FPS tương đồng với tần số quét (Hz) của máy."
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *rates = @[@30, @60, @75, @90, @120, @144];
    for (NSNumber *fpsNum in rates) {
        NSInteger fps = [fpsNum integerValue];
        NSString *title = [NSString stringWithFormat:@"%ld FPS%@", (long)fps, (fps == 30 ? @" (Siêu tiết kiệm pin)" : (fps == 60 ? @" (Chuẩn cân bằng)" : @" (Khung hình cao)"))];
        
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
            CFPreferencesSetAppValue(CFSTR("TargetFPSRate"), (__bridge CFPropertyListRef)@(fps), PREF_DOMAIN);
            CFPreferencesAppSynchronize(PREF_DOMAIN);

            notify_post(NOTIFY_RELOAD);
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

- (id)getAuthorName:(id)specifier {
    return @"Đức LONG (0374288058)";
}

- (id)getVersionString:(id)specifier {
    return @"V24 Pro beta";
}

- (void)openSupportLink:(id)specifier {
    NSURL *url = [NSURL URLWithString:@"https://zalo.me/g/qjd56ltkraiih88ps6ui"];
    if ([[UIApplication sharedApplication] canOpenURL:url]) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

@end
