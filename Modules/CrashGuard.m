#import "CrashGuard.h"
#import <UIKit/UIKit.h>

// Key UserDefaults cho Safe Mode
static NSString * const kCrashGuardSafeModeKey = @"BoostiPhone6s_SafeModeActive";
static NSString * const kCrashGuardCrashCountKey = @"BoostiPhone6s_CrashCount";
static NSString * const kCrashGuardLastCrashTimeKey = @"BoostiPhone6s_LastCrashTime";

// Ngưỡng crash loop: 3 crash trong 60 giây
static const NSInteger kCrashThreshold = 3;
static const NSTimeInterval kCrashWindow = 60.0;

@implementation CrashGuard {
    BOOL _isMonitoring;
    BOOL _safeModeActive;
    NSMutableArray<NSDate *> *_crashTimestamps;
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
        _isMonitoring = NO;
        _safeModeActive = NO;
        _crashTimestamps = [NSMutableArray array];
        _guardQueue = dispatch_queue_create("com.boostiphone6s.crashguard", DISPATCH_QUEUE_SERIAL);
        
        // Kiểm tra trạng thái Safe Mode từ UserDefaults
        _safeModeActive = [[NSUserDefaults standardUserDefaults] boolForKey:kCrashGuardSafeModeKey];
    }
    return self;
}

- (void)startMonitoring {
    if (_isMonitoring) return;
    _isMonitoring = YES;
    
    NSLog(@"[CrashGuard] Starting crash monitoring...");
    
    // Thiết lập exception handler
    NSSetUncaughtExceptionHandler(&CrashGuardExceptionHandler);
    
    // Kiểm tra xem có đang ở Safe Mode không
    if (_safeModeActive) {
        NSLog(@"[CrashGuard] ⚠️ SAFE MODE ACTIVE - Hooks will be disabled");
        return;
    }
    
    // Kiểm tra crash history
    [self checkCrashHistory];
    
    NSLog(@"[CrashGuard] ✅ Monitoring started successfully");
}

- (BOOL)canExecuteHooks {
    // Nếu đang ở Safe Mode, không cho phép hook
    if (_safeModeActive) {
        return NO;
    }
    
    // Kiểm tra lại UserDefaults (có thể bị thay đổi từ Settings)
    _safeModeActive = [[NSUserDefaults standardUserDefaults] boolForKey:kCrashGuardSafeModeKey];
    
    return !_safeModeActive;
}

- (void)resetSafeModeManually {
    dispatch_async(_guardQueue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:kCrashGuardSafeModeKey];
        [defaults removeObjectForKey:kCrashGuardCrashCountKey];
        [defaults removeObjectForKey:kCrashGuardLastCrashTimeKey];
        [defaults synchronize];
        
        self->_safeModeActive = NO;
        [self->_crashTimestamps removeAllObjects];
        
        NSLog(@"[CrashGuard] ✅ Safe Mode manually reset");
    });
}

- (NSString *)currentStatusDescription {
    if (_safeModeActive) {
        return @"SafeMode";
    } else if (_isMonitoring) {
        return @"Monitoring";
    } else {
        return @"Normal";
    }
}

#pragma mark - Private Methods

- (void)checkCrashHistory {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSInteger crashCount = [defaults integerForKey:kCrashGuardCrashCountKey];
    NSDate *lastCrashTime = [defaults objectForKey:kCrashGuardLastCrashTimeKey];
    
    if (lastCrashTime) {
        NSTimeInterval timeSinceLastCrash = [[NSDate date] timeIntervalSinceDate:lastCrashTime];
        
        // Nếu crash cuối cùng cách đây hơn 5 phút, reset counter
        if (timeSinceLastCrash > 300.0) {
            [defaults setInteger:0 forKey:kCrashGuardCrashCountKey];
            [defaults synchronize];
            crashCount = 0;
        }
    }
    
    // Nếu crash count vượt ngưỡng, kích hoạt Safe Mode
    if (crashCount >= kCrashThreshold) {
        [self activateSafeMode];
    }
}

- (void)recordCrash {
    dispatch_async(_guardQueue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSInteger crashCount = [defaults integerForKey:kCrashGuardCrashCountKey];
        crashCount++;
        
        [defaults setInteger:crashCount forKey:kCrashGuardCrashCountKey];
        [defaults setObject:[NSDate date] forKey:kCrashGuardLastCrashTimeKey];
        [defaults synchronize];
        
        [self->_crashTimestamps addObject:[NSDate date]];
        
        // Xóa các timestamp cũ hơn 60 giây
        NSDate *cutoff = [NSDate dateWithTimeIntervalSinceNow:-kCrashWindow];
        [self->_crashTimestamps filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSDate *date, NSDictionary *bindings) {
            return [date compare:cutoff] == NSOrderedDescending;
        }]];
        
        NSLog(@"[CrashGuard] Crash recorded. Count in window: %lu", (unsigned long)self->_crashTimestamps.count);
        
        // Kiểm tra crash loop
        if (self->_crashTimestamps.count >= kCrashThreshold) {
            [self activateSafeMode];
        }
    });
}

- (void)activateSafeMode {
    _safeModeActive = YES;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:kCrashGuardSafeModeKey];
    [defaults synchronize];
    
    NSLog(@"[CrashGuard] 🚨 SAFE MODE ACTIVATED - Too many crashes detected");
    
    // Hiển thị alert trên main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Safe Mode Activated"
                                                                       message:@"Boost iPhone 6s-X has detected multiple crashes. Safe Mode has been activated to prevent further issues. You can disable Safe Mode in Settings."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:okAction];
        
        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        if (rootVC) {
            [rootVC presentViewController:alert animated:YES completion:nil];
        }
    });
}

#pragma mark - C Exception Handler

void CrashGuardExceptionHandler(NSException *exception) {
    NSLog(@"[CrashGuard] 🚨 Uncaught exception: %@ - %@", exception.name, exception.reason);
    
    // Record crash
    [[CrashGuard sharedInstance] recordCrash];
    
    // Gọi handler gốc nếu có
    // (Không làm gì thêm để tránh infinite loop)
}

@end
