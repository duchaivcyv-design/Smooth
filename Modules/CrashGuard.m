#import "CrashGuard.h"
#import <dlfcn.h>
#import <UIKit/UIKit.h>

@implementation CrashGuard {
    NSMutableArray *_crashTimestamps;
    GuardStatus _currentStatus;
    dispatch_queue_t _guardQueue;
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
        _guardQueue = dispatch_queue_create("com.boostiphone6s.guard", DISPATCH_QUEUE_SERIAL);
        
        // Đăng ký observer để reset trạng thái khi respring xong
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(resetStateOnWake:) 
                                                     name:UIApplicationDidBecomeActiveNotification 
                                                   object:nil];
    }
    return self;
}

- (void)startMonitoring {
    NSLog(@"[CrashGuard] 👁️ Monitoring started.");
    
    // Cài đặt Uncaught Exception Handler (Bắt lỗi Objective-C runtime)
    NSSetUncaughtExceptionHandler(&handleUncaughtException);
}

// Callback khi có exception uncaught
static void handleUncaughtException(NSException *exception) {
    NSString *name = exception.name ?: @"Unknown";
    NSString *reason = exception.reason ?: @"No reason provided";
    
    NSLog(@"[CrashGuard] ⚠️ EXCEPTION CAUGHT: %@ - %@", name, reason);
    
    // Chuyển tiếp về singleton để xử lý logic đếm
    [[CrashGuard sharedInstance] reportException:[NSString stringWithFormat:@"%@: %@", name, reason]];
    
    // Re-raise để hệ thống vẫn ghi log crash đầy đủ (nếu muốn)
    // throw exception; 
}

- (void)reportException:(NSString *)reason {
    dispatch_async(_guardQueue, ^{
        NSDate *now = [NSDate date];
        [_crashTimestamps addObject:now];
        
        // Lọc bỏ các timestamp cũ hơn 60 giây
        NSTimeInterval threshold = -60.0;
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF > %@", [now dateByAddingTimeInterval:threshold]];
        NSArray *recentCrashes = [_crashTimestamps filteredArrayUsingPredicate:pred];
        
        NSInteger count = recentCrashes.count;
        NSLog(@"[CrashGuard] Recent crashes in last 60s: %ld", (long)count);
        
        if (count >= 3 && _currentStatus != GuardStatusSafeMode) {
            NSLog(@"[CrashGuard] ☠️ THRESHOLD EXCEEDED! ACTIVATING SAFE MODE.");
            [self activateSafeModeWithReason:reason];
        } else if (_currentStatus == GuardStatusSafeMode) {
            NSLog(@"[CrashGuard] Already in Safe Mode. Ignoring further hooks.");
        }
    });
}

- (void)activateSafeModeWithReason:(NSString *)reason {
    _currentStatus = GuardStatusSafeMode;
    
    // 1. Lưu trạng thái vào UserDefaults để nhớ sau khi respring
    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"BoostiPhone6s_SafeModeActive"];
    [[NSUserDefaults standardUserDefaults] setObject:reason forKey:@"BoostiPhone6s_LastCrashReason"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 2. Hiển thị Alert cảnh báo người dùng (chạy trên main thread)
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ Boost iPhone 6s - SAFE MODE"
                                                                       message:[NSString stringWithFormat:@"Phát hiện lỗi lặp lại (%@).\n\nTất cả tính năng tối ưu sâu đã bị TẮM tạm thời để bảo vệ hệ thống.\n\nVui lòng mở Cài đặt > Boost iPhone 6s để tắt bớt tính năng Risky hoặc Gỡ bỏ tweak.", reason]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            // Sau khi bấm OK, tiến hành Soft Respring để áp dụng trạng thái mới
            [self triggerSoftRespring];
        }];
        
        [alert addAction:okAction];
        
        // Tìm topmost controller để present alert
        UIViewController *topVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        while (topVC.presentedViewController) {
            topVC = topVC.presentedViewController;
        }
        [topVC presentViewController:alert animated:YES completion:nil];
    });
}

- (BOOL)canExecuteHooks {
    // Kiểm tra nhanh từ memory trước, nếu chưa load thì đọc disk
    if (_currentStatus == GuardStatusSafeMode) return NO;
    
    // Đọc từ UserDefaults mỗi lần khởi động process mới
    BOOL isSafe = [[NSUserDefaults standardUserDefaults] boolForKey:@"BoostiPhone6s_SafeModeActive"];
    if (isSafe) {
        _currentStatus = GuardStatusSafeMode;
        return NO;
    }
    
    return YES;
}

- (void)resetStateOnWake:(NSNotification *)note {
    // Khi app active trở lại, nếu người dùng đã manually tắt Safe Mode trong Settings, ta reset state
    // Logic này đơn giản hóa: Chỉ reset khi user chủ động toggle off trong plist settings
    // Ở đây ta chỉ đảm bảo queue sạch
    dispatch_sync(_guardQueue, ^{
        [_crashTimestamps removeAllObjects];
    });
}

- (void)triggerSoftRespring {
    typedef int (*system_func_t)(const char *);
    static system_func_t real_system = NULL;
    if (!real_system) {
        void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
        if (handle) real_system = (system_func_t)dlsym(handle, "system");
    }
    
    if (real_system) {
        // sbreload là lệnh soft respring phổ biến nhất
        real_system("sbreload");
    }
}

@end
