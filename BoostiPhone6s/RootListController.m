#import "RootListController.h"
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <UIKit/UIKit.h>

// Import header internal để truy cập CrashGuard/SystemBlocker reset function
// Lưu ý: Chỉ import khi build subproject, không ảnh hưởng main library
#ifdef BUILDING_SUBPROJECT
#import "../Modules/CrashGuard.h"
#import "../Modules/SystemBlocker.h"
#endif

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
        #ifdef BUILDING_SUBPROJECT
            [[CrashGuard sharedInstance] resetSafeModeManually];
            [[SystemBlocker sharedInstance] resetSafeModeManually];
        #endif
        
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
