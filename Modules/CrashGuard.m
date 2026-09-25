#import "CrashGuard.h"
#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <pthread.h>

@implementation CrashGuard {
    NSMutableArray<NSDate *> *_crashTimestamps;
    GuardStatus _currentStatus;
    dispatch_queue_t _guardQueue;
    BOOL _alertShownThisSession;
    NSTimeInterval _lastSafeModeCheckTime;
}

// ==========================================
// HELPER: SAFE SYSTEM CALL FOR RESPRING
// ==========================================

static int (*g_respring_system)(const char *) = NULL;
static pthread_once_t g_respring_init_once = PTHREAD_ONCE_INIT;

static void respring_system_init(void) {
    typedef int (*sys_func)(const char*);
    void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
    if (handle) {
        g_respring_system = (sys_func)dlsym(handle, "system");
    }
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
        _lastSafeModeCheckTime = 0;
        _guardQueue = dispatch_queue_create("com.boostiphone6s.guard", DISPATCH_QUEUE_SERIAL);
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
    
    // Trên iOS 14-26, throw lại exception gây double-fault/bootloop.
    // Để hệ thống tự shutdown an toàn sau khi đã kích hoạt Safe Mode.
}

- (void)checkSafeModeStatus {
    NSTimeInterval now = CFAbsoluteTimeGetCurrent();
    if (now - _lastSafeModeCheckTime < 5.0 && _currentStatus != GuardStatusNormal) return;
    _lastSafeModeCheckTime = now;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL isSafe = [defaults boolForKey:@"BoostiPhone6s_SafeModeActive"];
    
    if (isSafe && _currentStatus != GuardStatusSafeMode) {
        _currentStatus = GuardStatusSafeMode;
        NSLog(@"[CrashGuard] 🔒 Loaded Safe Mode from persistent storage.");
    } else if (!isSafe && _currentStatus == GuardStatusSafeMode) {
        // Tự động thoát Safe Mode nếu user đã reset thủ công từ Settings
        _currentStatus = GuardStatusNormal;
        _alertShownThisSession = NO;
        [_crashTimestamps removeAllObjects];
        NSLog(@"[CrashGuard] ✅ Auto-exited Safe Mode after manual reset.");
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
    _alertShownThisSession = YES;
    
    // Lưu trạng thái vào UserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:@"BoostiPhone6s_SafeModeActive"];
    [defaults setObject:reason forKey:@"BoostiPhone6s_LastCrashReason"];
    [defaults synchronize];
    
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
        
        UIViewController *topVC = nil;
        
        // Ưu tiên WindowScene (iOS 13+)
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
        
        // Fallback cho iOS 12 trở xuống hoặc khi không tìm thấy WindowScene
        if (!topVC) {
            UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
            if (keyWindow) topVC = keyWindow.rootViewController;
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

- (void)resetSafeModeManually {
    dispatch_async(_guardQueue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
        [defaults removeObjectForKey:@"BoostiPhone6s_LastCrashReason"];
        [defaults synchronize];
        
        _currentStatus = GuardStatusNormal;
        _alertShownThisSession = NO;
        _lastSafeModeCheckTime = 0;
        [_crashTimestamps removeAllObjects];
        
        NSLog(@"[CrashGuard] ✅ Safe Mode manually reset by user.");
    });
}

- (void)triggerSoftRespring {
    pthread_once(&g_respring_init_once, respring_system_init);
    
    if (g_respring_system) {
        // 1. sbreload (Dopamine/Palera1n rootless)
        // 2. killall SpringBoard (Legacy/TrollStore)
        // 3. uicache + kill backboardd (Last resort)
        int result = g_respring_system("sbreload 2>/dev/null || killall -9 SpringBoard 2>/dev/null");
        if (result != 0) {
            g_respring_system("uicache --all && killall -9 backboardd 2>/dev/null");
        }
        NSLog(@"[CrashGuard] 🔄 Soft Respring triggered via fallback chain.");
    }
}

@end
