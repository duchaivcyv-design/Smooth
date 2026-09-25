#import "SystemBlocker.h"
#import <dlfcn.h>

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
        
        // Khởi tạo danh sách mặc định
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            kDefaultBlockedProcesses = @[
                @"analyticsd",      // Apple Analytics daemon
                @"adid",            // Advertising Identifier
                @"rapportd",        // Continuity telemetry
                @"diagnosticsd",    // Diagnostics daemon (optional)
                @"awdd",            // Apple Wireless Diagnostics
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
        
        // Thêm các tiến trình mặc định vào danh sách chặn
        for (NSString *process in kDefaultBlockedProcesses) {
            [self->_blockedProcessSet addObject:process];
        }
        
        // Thực hiện chặn qua launchctl
        [self applyBlockers];
        
        self->_isActive = YES;
        NSLog(@"[SystemBlocker] ✅ Blockers initialized - %lu processes blocked",
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
            NSLog(@"[SystemBlocker] ✅ Blocked: %@", processName);
        } else {
            [self->_blockedProcessSet removeObject:processName];
            [self unblockSingleProcess:processName];
            NSLog(@"[SystemBlocker] ✅ Unblocked: %@", processName);
        }
    });
}

- (void)stopAllBlockers {
    dispatch_sync(_blockerQueue, ^{
        if (!self->_isActive) return;
        
        NSLog(@"[SystemBlocker] Stopping all blockers...");
        
        // Unblock tất cả tiến trình
        for (NSString *process in self->_blockedProcessSet) {
            [self unblockSingleProcess:process];
        }
        
        [self->_blockedProcessSet removeAllObjects];
        self->_isActive = NO;
        
        NSLog(@"[SystemBlocker] ✅ All blockers stopped");
    });
}

#pragma mark - Private Methods

/**
 * Áp dụng tất cả blockers bằng launchctl.
 * Sử dụng "launchctl stop" để dừng các daemon telemetry.
 */
- (void)applyBlockers {
    for (NSString *process in _blockedProcessSet) {
        [self blockSingleProcess:process];
    }
}

/**
 * Chặn một tiến trình đơn lẻ qua launchctl stop.
 * @param processName Tên tiến trình cần chặn
 */
- (void)blockSingleProcess:(NSString *)processName {
    // Tạo command string
    NSString *jbPath = @"/var/jb/bin/launchctl";
    NSString *rootfulPath = @"/bin/launchctl";
    
    // Kiểm tra path nào tồn tại
    const char *launchctlPath = NULL;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) {
        launchctlPath = [jbPath UTF8String];
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:rootfulPath]) {
        launchctlPath = [rootfulPath UTF8String];
    }
    
    if (!launchctlPath) {
        NSLog(@"[SystemBlocker] ⚠️ launchctl not found, cannot block %@", processName);
        return;
    }
    
    // Execute launchctl stop
    NSString *command = [NSString stringWithFormat:@"%@ stop com.apple.%@", launchctlPath, processName];
    
    typedef int (*sys_func)(const char *);
    void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
    if (handle) {
        sys_func sys = (sys_func)dlsym(handle, "system");
        if (sys) {
            int result = sys([command UTF8String]);
            if (result == 0) {
                NSLog(@"[SystemBlocker] ✅ Stopped: com.apple.%@", processName);
            }
        }
        dlclose(handle);
    }
}

/**
 * Bỏ chặn một tiến trình qua launchctl start.
 * @param processName Tên tiến trình cần bỏ chặn
 */
- (void)unblockSingleProcess:(NSString *)processName {
    NSString *jbPath = @"/var/jb/bin/launchctl";
    NSString *rootfulPath = @"/bin/launchctl";
    
    const char *launchctlPath = NULL;
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) {
        launchctlPath = [jbPath UTF8String];
    } else if ([[NSFileManager defaultManager] fileExistsAtPath:rootfulPath]) {
        launchctlPath = [rootfulPath UTF8String];
    }
    
    if (!launchctlPath) return;
    
    NSString *command = [NSString stringWithFormat:@"%@ start com.apple.%@", launchctlPath, processName];
    
    typedef int (*sys_func)(const char *);
    void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
    if (handle) {
        sys_func sys = (sys_func)dlsym(handle, "system");
        if (sys) {
            sys([command UTF8String]);
        }
        dlclose(handle);
    }
}

@end
