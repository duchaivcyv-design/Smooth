#import "CrashGuard.h"
#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@implementation CrashGuard {
    NSMutableArray *_crashTimestamps;
    GuardStatus _currentStatus;
    dispatch_queue_t _guardQueue;
    BOOL _alertShownThisSession; // Ngăn chặn spam alert loop
}

+ (instancetype)sharedInstance {
    static CrashGuard *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _crashTimestamps = [NSMutableArray array];
        _currentStatus = GuardStatusNormal;
        _alertShownThisSession = NO;
        _guardQueue = dispatch_queue_create("com.boostiphone6s.guard", DISPATCH_QUEUE_SERIAL);
        
        // ★ SỬA LỖI: KHÔNG DÙNG UIApplicationDidBecomeActiveNotification NỮA ★
        // Notification này không đáng tin cậy trong process hook system-wide.
        // Ta dùng cách check trực tiếp từ %ctor hoặc khi load settings.
    }
    return self;
}

- (void)startMonitoring {
    NSLog(@"[CrashGuard] 👁️ Monitoring started.");
    NSSetUncaughtExceptionHandler(&handleUncaughtException);
    
    // Check Safe Mode status ngay khi khởi tạo
    [self checkSafeModeStatus];
}

// Callback khi có exception uncaught
static void handleUncaughtException(NSException *exception) {
    NSString *name = exception.name ?: @"Unknown";
    NSString *reason = exception.reason ?: @"No reason provided";
    
    NSLog(@"[CrashGuard] ⚠️ EXCEPTION CAUGHT: %@ - %@", name, reason);
    [[CrashGuard sharedInstance] reportException:[NSString stringWithFormat:@"%@: %@", name, reason]];
    
    // ★ QUAN TRỌNG: KHÔNG RE-RAISE EXCEPTION ★
    // Trên iOS 14-26, việc throw lại exception trong uncaught handler 
    // thường gây double-fault và bootloop. Hãy để hệ thống tự xử lý shutdown an toàn.
}

- (void)checkSafeModeStatus {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL isSafe = [defaults boolForKey:@"BoostiPhone6s_SafeModeActive"];
    
    if (isSafe && _currentStatus != GuardStatusSafeMode) {
        _currentStatus = GuardStatusSafeMode;
        NSLog(@"[CrashGuard] 🔒 Loaded Safe Mode from persistent storage.");
    }
}

- (void)reportException:(NSString *)reason {
    dispatch_async(_guardQueue, ^{
        NSDate *now = [NSDate date];
        [_crashTimestamps addObject:now];
        
        // Lọc timestamp trong 60s gần nhất
        NSTimeInterval threshold = -60.0;
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF > %@", 
                            [now dateByAddingTimeInterval:threshold]];
        NSArray *recentCrashes = [_crashTimestamps filteredArrayUsingPredicate:pred];
        
        NSInteger count = recentCrashes.count;
        NSLog(@"[CrashGuard] Recent crashes in last 60s: %ld", (long)count);
        
        if (count >= 3 && _currentStatus != GuardStatusSafeMode && !_alertShownThisSession) {
            NSLog(@"[CrashGuard] ☠️ THRESHOLD EXCEEDED! ACTIVATING SAFE MODE.");
            [self activateSafeModeWithReason:reason];
        }
    });
}

- (void)activateSafeModeWithReason:(NSString *)reason {
    _currentStatus = GuardStatusSafeMode;
    _alertShownThisSession = YES; // Đánh dấu đã hiển thị alert
    
    // 1. Lưu trạng thái vào UserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:@"BoostiPhone6s_SafeModeActive"];
    [defaults setObject:reason forKey:@"BoostiPhone6s_LastCrashReason"];
    [defaults synchronize];
    
    // 2. ★ SỬA LỖI ALERT: DÙNG CÁCH AN TOÀN CHO IOS 15+ ★
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ Boost iPhone 6s - SAFE MODE"
                                                                       message:[NSString stringWithFormat:@"Phát hiện %d lỗi liên tiếp trong 60s.\n\nTất cả tính năng tối ưu sâu đã bị TẮM để bảo vệ hệ thống.\n\nVui lòng mở Cài đặt > Boost iPhone 6s để tắt bớt tính năng Risky.", 3]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK (Respring)" 
                                                         style:UIAlertActionStyleDefault 
                                                       handler:^(UIAlertAction * _Nonnull action) {
            [self triggerSoftRespring];
        }];
        
        [alert addAction:okAction];
        
        // ★ FIX: Tìm top VC an toàn cho iOS 14-26 ★
        UIViewController *topVC = nil;
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive) {
                for (UIWindow *window in scene.windows) {
                    if (window.isKeyWindow) {
                        topVC = window.rootViewController;
                        break;
                    }
                }
            }
            if (topVC) break;
        }
        
        // Fallback cho iOS 14 hoặc nếu không tìm thấy WindowScene
        if (!topVC) {
            topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        }
        
        // Present alert an toàn
        if (topVC) {
            while (topVC.presentedViewController) {
                topVC = topVC.presentedViewController;
            }
            [topVC presentViewController:alert animated:YES completion:nil];
        } else {
            // Nếu không present được alert, vẫn respring để áp dụng safe mode
            NSLog(@"[CrashGuard] Could not present alert. Triggering respring directly.");
            [self triggerSoftRespring];
        }
    });
}

- (BOOL)canExecuteHooks {
    if (_currentStatus == GuardStatusSafeMode) return NO;
    [self checkSafeModeStatus];
    return (_currentStatus != GuardStatusSafeMode);
}

// ★ HÀM MỚI: Cho phép user manually reset Safe Mode từ Settings ★
- (void)resetSafeModeManually {
    dispatch_async(_guardQueue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
        [defaults removeObjectForKey:@"BoostiPhone6s_LastCrashReason"];
        [defaults synchronize];
        
        _currentStatus = GuardStatusNormal;
        _alertShownThisSession = NO;
        [_crashTimestamps removeAllObjects];
        
        NSLog(@"[CrashGuard] ✅ Safe Mode manually reset by user.");
    });
}

- (void)triggerSoftRespring {
    typedef int (*system_func_t)(const char *);
    static system_func_t real_system = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
        if (handle) real_system = (system_func_t)dlsym(handle, "system");
    });
    
    if (real_system) {
        // ★ FIX: FALLBACK CHAIN CHO MỌI BẢN ROOTLESS ★
        // Thử sbreload trước (Dopamine), nếu fail thì killall SpringBoard (Palera1n/TrollStore)
        int result = real_system("sbreload 2>/dev/null || killall -9 SpringBoard 2>/dev/null");
        if (result != 0) {
            // Fallback cuối cùng: uicache + kill backboardd
            real_system("uicache --all && killall -9 backboardd 2>/dev/null");
        }
        NSLog(@"[CrashGuard]  Soft Respring triggered via fallback chain.");
    }
}

@end
