#import "CrashGuard.h"

static void V20_HandleUncaughtException(NSException *exception);

@implementation CrashGuard {
    GuardStatus _currentStatus;
    dispatch_queue_t _guardQueue;
}

+ (instancetype)sharedInstance {
    static CrashGuard *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _currentStatus = GuardStatusNormal;
        _guardQueue = dispatch_queue_create("com.boostv20.crashguard", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (GuardStatus)currentStatus { return _currentStatus; }

- (void)startMonitoring {
    NSSetUncaughtExceptionHandler(&V20_HandleUncaughtException);
    BOOL isSafe = [[NSUserDefaults standardUserDefaults] boolForKey:@"BoostV20_SafeModeActive"];
    if (isSafe) _currentStatus = GuardStatusSafeMode;
}

- (BOOL)canExecuteHooks {
    return (_currentStatus == GuardStatusNormal);
}

- (void)resetSafeModeManually {
    dispatch_async(_guardQueue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"BoostV20_SafeModeActive"];
        [defaults synchronize];
        self->_currentStatus = GuardStatusNormal;
    });
}

@end

static void V20_HandleUncaughtException(NSException *exception) {
    NSString *reason = exception.reason ?: @"Unknown Error";
    NSLog(@"[BoostV20_CrashGuard] FATAL: CAUGHT EXCEPTION: %@", reason);
    // Luôn reset để phiên sau chạy lại mượt mà, không khóa chết user
    [[CrashGuard sharedInstance] resetSafeModeManually]; 
}
