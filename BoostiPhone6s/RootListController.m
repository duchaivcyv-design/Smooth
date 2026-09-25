#import "RootListController.h"
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// SỬA: KHÔNG IMPORT CRASHGUARD/SYSTEMBLOCKER NỮA ĐỂ TRÁNH LỖI LINKER
// Ta sẽ dùng cách xóa UserDefaults trực tiếp và dựa vào Darwin Notification
// mà Tweak.xm đã đăng ký để reload cấu hình.

@implementation RootListController

- (NSArray<PSSpecifier *> *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)resetSafeMode:(id)sender {
    UIAlertController *confirm = [UIAlertController alertControllerWithTitle:@"Xác nhận thoát Safe Mode?"
                                                                     message:@"Tất cả tính năng tối ưu sâu sẽ được bật lại.\nMáy sẽ tự động respring sau khi xác nhận."
                                                              preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *yesAction = [UIAlertAction actionWithTitle:@"Đồng ý" 
                                                      style:UIAlertActionStyleDestructive 
                                                    handler:^(UIAlertAction * _Nonnull action) {
        // SỬA: XÓA USERDEFAULTS TRỰC TIẾP THAY VÌ GỌI CLASS TỪ LIBRARY
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
        [defaults removeObjectForKey:@"BoostiPhone6s_LastCrashReason"];
        [defaults synchronize];
        
        // Gửi Darwin Notification để Tweak.xm reload config ngay lập tức
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                             CFSTR("com.taojb.boostiphone6s.settings/reload"), 
                                             NULL, NULL, TRUE);
        
        NSLog(@"[Settings] Safe Mode keys removed & Notification sent.");
        
        // Force reload specifiers để cập nhật UI ngay lập tức
        [self reloadSpecifiers];
        
        // Respring để áp dụng trạng thái mới
        [self performRespring];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"Hủy" 
                                                         style:UIAlertActionStyleCancel 
                                                       handler:nil];
    
    [confirm addAction:yesAction];
    [confirm addAction:cancelAction];
    [self presentViewController:confirm animated:YES completion:nil];
}

- (void)performRespring {
    pid_t pid;
    
    // 1. sbreload Rootless (Ưu tiên cao nhất cho Dopamine/Palera1n)
    const char *args1[] = {"sbreload", NULL};
    if (posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)args1, NULL) == 0) {
        return;
    }
    
    // 2. killall SpringBoard Rootless
    const char *args2[] = {"killall", "-9", "SpringBoard", NULL};
    if (posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)args2, NULL) == 0) {
        return;
    }

    // 3. Fallback Rootful (cho TrollStore/Legacy JB)
    if (posix_spawn(&pid, "/usr/bin/sbreload", NULL, NULL, (char *const *)args1, NULL) == 0) {
        return;
    }

    // 4. Last resort: killall Rootful
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args2, NULL);
}

- (void)respring:(id)sender {
    [self performRespring];
}

@end
