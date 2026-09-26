#import "RootListController.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

extern char **environ;

@implementation RootListController

- (NSArray<PSSpecifier *> *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

// Hàm Respring siêu tốc (Hỗ trợ cả Rootless và Rootful)
- (void)performRespring {
    pid_t pid;
    const char *args[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)args, environ);
    
    // Fallback cho Rootful nếu đường dẫn Rootless không tồn tại
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, environ);
}

// Nút bấm Respring trong Cài đặt (Có hiệu ứng load mượt)
- (void)respring:(id)sender {
    UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    [spinner startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:spinner];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self performRespring];
    });
}

// Nút bấm Gỡ Safe Mode (Tránh khóa cứng thiết bị khi lỡ bị crash)
- (void)resetSafeMode:(id)sender {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Xác nhận thoát Safe Mode"
                                                                     message:@"Toàn bộ hệ thống tối ưu V20 sẽ được kích hoạt lại.\nMáy sẽ tự động Respring sau khi xác nhận."
                                                              preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Đồng ý"
                                                      style:UIAlertActionStyleDestructive
                                                    handler:^(UIAlertAction * _Nonnull action) {
        // Xóa sạch các cờ báo lỗi Safe Mode
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"BoostV20_SafeModeActive"];
        [defaults removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
        [defaults removeObjectForKey:@"BoostiPhone6s_LastCrashReason"];
        [defaults synchronize];

        // Gửi lệnh Reload tới Tweak
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                             CFSTR("com.taojb.boostiphone6s.settings/reload"),
                                             NULL, NULL, TRUE);

        [self reloadSpecifiers];
        [self performRespring];
    }];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Hủy"
                                                         style:UIAlertActionStyleCancel
                                                       handler:nil];

    [confirm addAction:yesAction];
    [confirm addAction:cancelAction];
    [self presentViewController:confirm animated:YES completion:nil];
}

@end
