#import "CrashGuard.h"

static void handleUncaughtException(NSException *exception);

@implementation CrashGuard {
    NSMutableArray<NSDate *> *_crashTimestamps;
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
        _crashTimestamps = [NSMutableArray array];
        _currentStatus = GuardStatusNormal;
        _guardQueue = dispatch_queue_create("com.boostiphone6s.guard.v12", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (GuardStatus)currentStatus { return _currentStatus; }

- (void)startMonitoring {
    NSSetUncaughtExceptionHandler(&handleUncaughtException);
    BOOL isSafe = [[NSUserDefaults standardUserDefaults] boolForKey:@"BoostiPhone6s_SafeModeActive"];
    if (isSafe) _currentStatus = GuardStatusSafeMode;
}

- (BOOL)canExecuteHooks {
    return (_currentStatus != GuardStatusSafeMode && _currentStatus != GuardStatusCritical);
}

- (void)resetSafeModeManually {
    dispatch_async(_guardQueue, ^{
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults removeObjectForKey:@"BoostiPhone6s_SafeModeActive"];
        [defaults synchronize];
        self->_currentStatus = GuardStatusNormal;
        [self->_crashTimestamps removeAllObjects];
    });
}

@end

static void handleUncaughtException(NSException *exception) {
    NSString *reason = exception.reason ?: @"Unknown";
    NSLog(@"[CrashGuard] EXCEPTION CAUGHT: %@", reason);
    // Auto-reset safe mode on crash to prevent permanent lockout during dev/testing
    [[CrashGuard sharedInstance] resetSafeModeManually]; 
}
