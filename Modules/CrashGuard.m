#import "CrashGuard.h"
#import <signal.h>
#import <unistd.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <sys/stat.h>

#define MAX_ALLOWED_CRASHES 3
#define CRASH_WINDOW_SECONDS 15.0

static NSString * const kCrashGuardCounterPath = @"/tmp/.boost_boot_counter";
static NSString * const kCrashGuardSafeFlag = @"/tmp/.boost_safe_mode";

static inline NSString *CrashGuard_ResolvePrefix(void) {
    static NSString *cachedRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)CrashGuard_ResolvePrefix, &info) && info.dli_fname) {
            NSString *path = [NSString stringWithUTF8String:info.dli_fname];
            NSRange range = [path rangeOfString:@"/var/jb"];
            if (range.location != NSNotFound) {
                NSRange sub = [path rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, path.length - (range.location + 7))];
                cachedRoot = (sub.location != NSNotFound) ? [path substringToIndex:sub.location] : @"/var/jb";
            } else {
                cachedRoot = @"/var/jb";
            }
        } else {
            cachedRoot = @"/var/jb";
        }
    });
    return cachedRoot;
}

static void CrashGuard_SignalHandler(int sig) {
    // Ghi nhận tín hiệu crash nghiêm trọng trước khi tiến trình sập
    NSDictionary *counterDict = [NSDictionary dictionaryWithContentsOfFile:kCrashGuardCounterPath];
    NSInteger count = counterDict ? [counterDict[@"count"] integerValue] + 1 : 1;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    
    NSDictionary *newCounter = @{
        @"count": @(count),
        @"time": @(now),
        @"signal": @(sig)
    };
    [newCounter writeToFile:kCrashGuardCounterPath atomically:YES];
    chmod([kCrashGuardCounterPath UTF8String], 0666);
    
    if (count >= MAX_ALLOWED_CRASHES) {
        int fd = open([kCrashGuardSafeFlag UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) close(fd);
    }
    
    // Nhả lại handler mặc định để hệ thống xử lý dump crashlog bình thường
    signal(sig, SIG_DFL);
    raise(sig);
}

static void CrashGuard_ExceptionHandler(NSException *exception) {
    CrashGuard_SignalHandler(SIGABRT);
}

@implementation CrashGuard {
    GuardStatus _status;
    NSInteger _crashes;
    BOOL _monitoringStarted;
}

+ (instancetype)sharedInstance {
    static CrashGuard *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _status = GuardStatusNormal;
        _crashes = 0;
        _monitoringStarted = NO;
        [self inspectEnvironment];
    }
    return self;
}

- (void)inspectEnvironment {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if ([fm fileExistsAtPath:kCrashGuardSafeFlag]) {
        _status = GuardStatusSafeMode;
        return;
    }
    
    if ([fm fileExistsAtPath:kCrashGuardCounterPath]) {
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kCrashGuardCounterPath];
        if (dict) {
            _crashes = [dict[@"count"] integerValue];
            NSTimeInterval lastTime = [dict[@"time"] doubleValue];
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            
            if (now - lastTime < CRASH_WINDOW_SECONDS) {
                if (_crashes >= MAX_ALLOWED_CRASHES) {
                    _status = GuardStatusCritical;
                } else if (_crashes >= 2) {
                    _status = GuardStatusSafeMode;
                }
            } else {
                // Quá cửa sổ theo dõi mà không crash dồn dập -> xóa đếm
                [fm removeItemAtPath:kCrashGuardCounterPath error:nil];
                _crashes = 0;
            }
        }
    }
}

- (void)startMonitoring {
    if (_monitoringStarted) return;
    _monitoringStarted = YES;
    
    // Thiết lập bẫy tín hiệu bảo vệ
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_handler = CrashGuard_SignalHandler;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_NODEFER | SA_RESETHAND;
    
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
    
    NSSetUncaughtExceptionHandler(&CrashGuard_ExceptionHandler);
    
    // Ghi nhận lần khởi động này
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:kCrashGuardCounterPath];
    NSInteger currentCount = 1;
    if (dict) {
        NSTimeInterval lastTime = [dict[@"time"] doubleValue];
        if (now - lastTime < CRASH_WINDOW_SECONDS) {
            currentCount = [dict[@"count"] integerValue] + 1;
        }
    }
    
    NSDictionary *counterDict = @{@"count": @(currentCount), @"time": @(now)};
    [counterDict writeToFile:kCrashGuardCounterPath atomically:YES];
    chmod([kCrashGuardCounterPath UTF8String], 0666);
    
    // Nếu app chạy sống sót qua 12 giây liên tục -> tự động xóa cờ cảnh báo
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self markAppSuccessfullyLaunched];
    });
}

- (BOOL)canExecuteHooks {
    [self inspectEnvironment];
    return (_status == GuardStatusNormal);
}

- (void)markAppSuccessfullyLaunched {
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:kCrashGuardCounterPath]) {
        [fm removeItemAtPath:kCrashGuardCounterPath error:nil];
    }
    _crashes = 0;
    _status = GuardStatusNormal;
}

- (void)resetSafeModeManually {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:kCrashGuardSafeFlag error:nil];
    [fm removeItemAtPath:kCrashGuardCounterPath error:nil];
    _crashes = 0;
    _status = GuardStatusNormal;
}

- (void)reportFailureWithReason:(NSString *)reason {
    _crashes++;
    if (_crashes >= MAX_ALLOWED_CRASHES) {
        _status = GuardStatusCritical;
        int fd = open([kCrashGuardSafeFlag UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) close(fd);
    }
}

- (GuardStatus)currentStatus {
    return _status;
}

- (NSInteger)crashCount {
    return _crashes;
}

@end
