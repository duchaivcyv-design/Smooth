#import "SystemBlocker.h"
#import <spawn.h>

// environ declaration cho posix_spawn trên iOS 26 SDK
extern char **environ;

// Danh sách các tiến trình telemetry/analytics mặc định bị chặn
static NSArray<NSString *> *kDefaultBlockedProcesses = nil;

@implementation SystemBlocker {
    BOOL _isActive;
    NSMutableSet<NSString *> *_blockedProcessSet;
    dispatch_queue_t _blockerQueue;
}

+ (instancetype)sharedInstance {
    static SystemBlocker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isActive = NO;
        _blockedProcessSet = [NSMutableSet set];
        _blockerQueue = dispatch_queue_create("com.boostiphone6s.systemblocker", DISPATCH_QUEUE_SERIAL);
        
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            kDefaultBlockedProcesses = @[
                @"analyticsd",
                @"adid",
                @"rapportd",
                @"diagnosticsd",
                @"awdd",
            ];
        });
    }
    return self;
}

- (void)initBlockers {
    if (_isActive) {
        NSLog(@"[SystemBlocker] Already active, skipping initialization");
        return;
    }
    
    dispatch_sync(_blockerQueue, ^{
        NSLog(@"[SystemBlocker] Initializing system blockers...");
        
        for (NSString *process in kDefaultBlockedProcesses) {
            [self->_blockedProcessSet addObject:process];
        }
        
        [self applyBlockers];
        
        self->_isActive = YES;
        NSLog(@"[SystemBlocker] Blockers initialized - %lu processes blocked",
              (unsigned long)self->_blockedProcessSet.count);
    });
}

- (BOOL)isActive {
    return _isActive;
}

- (NSArray<NSString *> *)blockedProcesses {
    return [_blockedProcessSet allObjects];
}

- (void)setBlock:(BOOL)block forProcess:(NSString *)processName {
    if (!processName || processName.length == 0) return;
    
    dispatch_async(_blockerQueue, ^{
        if (block) {
            [self->_blockedProcessSet addObject:processName];
            [self blockSingleProcess:processName];
            NSLog(@"[SystemBlocker] Blocked: %@", processName);
        } else {
            [self->_blockedProcessSet removeObject:processName];
            [self unblockSingleProcess:processName];
            NSLog(@"[SystemBlocker] Unblocked: %@", processName);
        }
    });
}

- (void)stopAllBlockers {
    dispatch_sync(_blockerQueue, ^{
        if (!self->_isActive) return;
        
        NSLog(@"[SystemBlocker] Stopping all blockers...");
        
        for (NSString *process in self->_blockedProcessSet) {
            [self unblockSingleProcess:process];
        }
        
        [self->_blockedProcessSet removeAllObjects];
        self->_isActive = NO;
        
        NSLog(@"[SystemBlocker] All blockers stopped");
    });
}

#pragma mark - Private Methods

- (void)applyBlockers {
    for (NSString *process in _blockedProcessSet) {
        [self blockSingleProcess:process];
    }
}

/**
 * Chặn một tiến trình đơn lẻ qua launchctl stop.
 * FIX v10: Dùng posix_spawn thay vì dlopen/system() cho iOS 26 SDK compatibility.
 * FIX v10: %s cho launchctlPath (const char *), %@ cho processName (NSString *).
 */
- (void)blockSingleProcess:(NSString *)processName {
    NSString *jbPath = @"/var/jb/bin/launchctl";
    NSString *rootfulPath = @"/bin/launchctl";
    
    const char *launchctlBin = NULL;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) {
        launchctlBin = "/var/jb/bin/launchctl";
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:rootfulPath]) {
        launchctlBin = "/bin/launchctl";
    }
    
    if (!launchctlBin) {
        NSLog(@"[SystemBlocker] launchctl not found, cannot block %@", processName);
        return;
    }
    
    // Tạo argument: "stop" "com.apple.<processName>"
    NSString *serviceName = [NSString stringWithFormat:@"com.apple.%@", processName];
    
    pid_t pid;
    char *argv[] = {
        (char *)launchctlBin,
        "stop",
        (char *)[serviceName UTF8String],
        NULL
    };
    
    int result = posix_spawn(&pid, launchctlBin, NULL, NULL, argv, environ);
    
    if (result == 0) {
        int status;
        waitpid(pid, &status, 0);
        NSLog(@"[SystemBlocker] Stopped: %@", serviceName);
    } else {
        NSLog(@"[SystemBlocker] posix_spawn failed for %@ (errno: %d)", serviceName, result);
    }
}

/**
 * Bỏ chặn một tiến trình qua launchctl start.
 * FIX v10: Dùng posix_spawn thay vì dlopen/system().
 */
- (void)unblockSingleProcess:(NSString *)processName {
    NSString *jbPath = @"/var/jb/bin/launchctl";
    NSString *rootfulPath = @"/bin/launchctl";
    
    const char *launchctlBin = NULL;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) {
        launchctlBin = "/var/jb/bin/launchctl";
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:rootfulPath]) {
        launchctlBin = "/bin/launchctl";
    }
    
    if (!launchctlBin) return;
    
    NSString *serviceName = [NSString stringWithFormat:@"com.apple.%@", processName];
    
    pid_t pid;
    char *argv[] = {
        (char *)launchctlBin,
        "start",
        (char *)[serviceName UTF8String],
        NULL
    };
    
    int result = posix_spawn(&pid, launchctlBin, NULL, NULL, argv, environ);
    
    if (result == 0) {
        int status;
        waitpid(pid, &status, 0);
        NSLog(@"[SystemBlocker] Started: %@", serviceName);
    }
}

@end
