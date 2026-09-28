#import "CrashGuard.h"

#define PREF_SUITE @"com.taojb.boostiphone6s"
#define SAFE_MODE_KEY @"BoostiPhone6s_SafeModeActive"

static void Apex_HandleUncaughtException(NSException *exception);

@implementation CrashGuard {
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
        _currentStatus = GuardStatusNormal;
        _guardQueue = dispatch_queue_create("com.taojb.boostiphone6s.crashguard", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (GuardStatus)currentStatus { 
    return _currentStatus; 
}

- (void)startMonitoring {
    NSSetUncaughtExceptionHandler(&Apex_HandleUncaughtException);
    
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:PREF_SUITE];
    BOOL isSafe = [prefs boolForKey:SAFE_MODE_KEY];
    if (isSafe) {
        _currentStatus = GuardStatusSafeMode;
    }
}

- (BOOL)canExecuteHooks {
    return (_currentStatus == GuardStatusNormal);
}

- (void)resetSafeModeManually {
    dispatch_async(_guardQueue, ^{
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:PREF_SUITE];
        [prefs removeObjectForKey:SAFE_MODE_KEY];
        [prefs synchronize];
        self->_currentStatus = GuardStatusNormal;
    });
}

@end

static void Apex_HandleUncaughtException(NSException *exception) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:PREF_SUITE];
    [prefs setBool:YES forKey:SAFE_MODE_KEY];
    [prefs synchronize];
}
