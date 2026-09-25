#import "RootListController.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

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
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
        [defaults removeObjectForKey:@"BoostiPhone6s_LastCrashReason"];
        [defaults synchronize];
        
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                             CFSTR("com.taojb.boostiphone6s.settings/reload"), 
                                             NULL, NULL, TRUE);
        
        NSLog(@"[Settings] Safe Mode keys removed & Notification sent.");
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

- (void)performRespring {
    pid_t pid;
    const char *args1[] = {"sbreload", NULL};
    if (posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)args1, NULL) == 0) return;
    
    const char *args2[] = {"killall", "-9", "SpringBoard", NULL};
    if (posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)args2, NULL) == 0) return;
    
    if (posix_spawn(&pid, "/usr/bin/sbreload", NULL, NULL, (char *const *)args1, NULL) == 0) return;
    
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args2, NULL);
}

- (void)respring:(id)sender {
    [self performRespring];
}

@end
