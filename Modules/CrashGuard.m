#import "CrashGuard.h"
#import <signal.h>
#import <unistd.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <sys/stat.h>
#import <fcntl.h>

#define MAX_ALLOWED_CRASHES 3
#define CRASH_WINDOW_SECONDS 15.0

static const char *kCrashGuardCounterPath = "/tmp/.boost_boot_counter";
static const char *kCrashGuardSafeFlag = "/tmp/.boost_safe_mode";

// ====================================================================================================
// HÀM KIỂM TRA NHANH 0NS CHO %CTOR TRONG TWEAK.XM (KHÔNG DÙNG HEAP / OBJC RUNTIME)
// ====================================================================================================

BOOL CrashGuard_IsSafeModeActive(void) {
    return (access(kCrashGuardSafeFlag, F_OK) == 0);
}

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

// ====================================================================================================
// ASYNC-SIGNAL-SAFE TRAP: TUYỆT ĐỐI CHỈ DÙNG SYSCALL POSIX (CHỐNG DEADLOCK & CHỐNG TREO MÁY)
// ====================================================================================================

static void CrashGuard_SignalHandler(int sig) {
    // 1. Đọc và cập nhật số lần crash thuần POSIX (không gọi malloc hay Obj-C runtime)
    int count = 0;
    int fd = open(kCrashGuardCounterPath, O_RDWR | O_CREAT, 0666);
    if (fd >= 0) {
        char buf[16] = {0};
        ssize_t bytesRead = read(fd, buf, sizeof(buf) - 1);
        if (bytesRead > 0) {
            count = atoi(buf);
        }
        count++;
        
        // Ghi đè lại counter mới
        lseek(fd, 0, SEEK_SET);
        char outBuf[16] = {0};
        int len = snprintf(outBuf, sizeof(outBuf), "%d", count);
        write(fd, outBuf, len);
        close(fd);
    }
    
    // 2. Kích hoạt cờ Safe Mode nếu vượt ngưỡng sập liên tục
    if (count >= MAX_ALLOWED_CRASHES) {
        int sfd = open(kCrashGuardSafeFlag, O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (sfd >= 0) {
            close(sfd);
        }
    }
    
    // 3. Trả lại signal mặc định để hệ thống sinh CrashReport sạch sẽ
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
    NSString *safeFlagStr = [NSString stringWithUTF8String:kCrashGuardSafeFlag];
    NSString *counterPathStr = [NSString stringWithUTF8String:kCrashGuardCounterPath];
    
    if ([fm fileExistsAtPath:safeFlagStr]) {
        _status = GuardStatusSafeMode;
        return;
    }
    
    if ([fm fileExistsAtPath:counterPathStr]) {
        NSError *err = nil;
        NSString *content = [NSString stringWithContentsOfFile:counterPathStr encoding:NSUTF8StringEncoding error:&err];
        if (content) {
            _crashes = [content integerValue];
            if (_crashes >= MAX_ALLOWED_CRASHES) {
                _status = GuardStatusCritical;
            } else if (_crashes >= 2) {
                _status = GuardStatusSafeMode;
            }
        }
    }
}

- (void)startMonitoring {
    if (_monitoringStarted) return;
    _monitoringStarted = YES;
    
    // Đăng ký bẫy tín hiệu bảo vệ nhân
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
    
    // Tự động xóa cờ boot counter sau 3.5s nếu hệ thống hoạt động ổn định
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self markAppSuccessfullyLaunched];
    });
}

- (BOOL)canExecuteHooks {
    [self inspectEnvironment];
    return (_status == GuardStatusNormal);
}

- (void)markAppSuccessfullyLaunched {
    unlink(kCrashGuardCounterPath);
    _crashes = 0;
    if (_status != GuardStatusSafeMode) {
        _status = GuardStatusNormal;
    }
}

- (void)resetSafeModeManually {
    unlink(kCrashGuardSafeFlag);
    unlink(kCrashGuardCounterPath);
    _crashes = 0;
    _status = GuardStatusNormal;
}

- (void)reportFailureWithReason:(NSString *)reason {
    _crashes++;
    if (_crashes >= MAX_ALLOWED_CRASHES) {
        _status = GuardStatusCritical;
        int fd = open(kCrashGuardSafeFlag, O_WRONLY | O_CREAT | O_TRUNC, 0666);
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
