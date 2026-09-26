#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>
#import <notify.h>

#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.duchaivcy.boostiphone6s/ReloadPrefs"

extern char **environ;

@interface RootListController : PSListController
@end

@implementation RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

// ============================================================================
// POPUP NỔI CHỌN TẦN SỐ QUÉT HZ & FPS (30 - 60 - 90 - 120 - 144)
// ============================================================================
- (void)showHzPopupPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Tần Số Quét (Hz & FPS)"
                                                                   message:@"Chọn mức giới hạn hiển thị hệ thống:\n• 30Hz: Tiết kiệm pin tối đa, giảm sinh nhiệt\n• 60Hz: Mặc định chuẩn iOS\n• 90Hz - 120Hz - 144Hz: Tối ưu cảm ứng siêu mượt"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *hzValues = @[@30, @60, @90, @120, @144];
    for (NSNumber *hz in hzValues) {
        NSString *title = [NSString stringWithFormat:@"Khóa ở %@ Hz / FPS", hz];
        [alert addAction:[UIAlertAction actionWithTitle:title
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
            [self applyTargetHz:hz.integerValue];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        alert.popoverPresentationController.sourceView = self.view;
        alert.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0, 1.0, 1.0);
    }

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)applyTargetHz:(NSInteger)hz {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:PREF_PATH] ?: [NSMutableDictionary dictionary];
    prefs[@"TargetRefreshRate"] = @(hz);
    [prefs writeToFile:PREF_PATH atomically:YES];
    notify_post(NOTIFY_RELOAD);
    [self reloadSpecifiers];
}

// ============================================================================
// CHỨC NĂNG RESPRING HỆ THỐNG
// ============================================================================
- (void)respringDevice {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Khởi Động Lại SpringBoard"
                                                                   message:@"Bạn có chắc chắn muốn Respring để áp dụng toàn bộ thay đổi?"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Respring Ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        pid_t pid;
        const char *argv[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)argv, environ);
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

// ============================================================================
// CHỨC NĂNG ĐẶT LẠI CÀI ĐẶT BAN ĐẦU
// ============================================================================
- (void)resetAllSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Đặt Lại Cấu Hình"
                                                                   message:@"Toàn bộ thiết lập của BoostiPhone6s sẽ được khôi phục về trạng thái xuất xưởng."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        [[NSFileManager defaultManager] removeItemAtPath:PREF_PATH error:nil];
        notify_post(NOTIFY_RELOAD);
        [self reloadSpecifiers];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end
