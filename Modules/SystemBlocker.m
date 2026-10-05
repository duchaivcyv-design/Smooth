#import "SystemBlocker.h"
#import <dlfcn.h>
#import <sys/stat.h>
#import <unistd.h>
#import <string.h>

// ====================================================================================================
// TRIỂN KHAI 2 HÀM C KIỂM TRA NHANH 0NS CHO %CTOR CỦA TWEAK.XM (KHỚP CHUẨN SYSTEM_BLOCKER.H)
// ====================================================================================================

BOOL SystemBlocker_IsNetworkProcess(const char *procName) {
    if (!procName) return NO;
    if (strstr(procName, "WebKit") || 
        strstr(procName, "WebContent") ||
        strstr(procName, "GPUProcess") || 
        strstr(procName, "Networking") ||
        strstr(procName, "nsurlsessiond") || 
        strstr(procName, "mDNSResponder") ||
        strstr(procName, "cloudd")) {
        return YES; // Nhận diện tiến trình mạng để cách ly 100%
    }
    return NO;
}

BOOL SystemBlocker_ShouldBypassDaemon(const char *procName) {
    if (!procName) return YES;

    // 1. Cách ly tiến trình mạng để bảo vệ kết nối không bị nghẽn
    if (SystemBlocker_IsNetworkProcess(procName)) {
        return YES;
    }

    // 2. Chặn tiêm hook vào các daemon hệ thống nhạy cảm (chống treo reboot / safe mode)
    if (strstr(procName, "jailbreakd") || strstr(procName, "launchd") ||
        strstr(procName, "containermanagerd") || strstr(procName, "cfprefsd") ||
        strstr(procName, "watchdogd") || strstr(procName, "mediaserverd") ||
        strstr(procName, "installd") || strstr(procName, "logd") ||
        strstr(procName, "analyticsd") || strstr(procName, "symptomsd") ||
        strstr(procName, "powerd") || strstr(procName, "backboardd") ||
        strstr(procName, "notifyd") || strstr(procName, "securityd") ||
        strstr(procName, "runningboardd") || strstr(procName, "thermalmonitord") ||
        strstr(procName, "mediaremoted") || strstr(procName, "assertiond")) {
        return YES;
    }

    return NO;
}

static inline NSString *SystemBlocker_ResolvePrefix(void) {
    static NSString *cachedRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)SystemBlocker_ResolvePrefix, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            NSRange range = [dylibPath rangeOfString:@"/var/jb"];
            if (range.location != NSNotFound) {
                NSRange sub = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, dylibPath.length - (range.location + 7))];
                cachedRoot = (sub.location != NSNotFound) ? [dylibPath substringToIndex:sub.location] : @"/var/jb";
            } else {
                cachedRoot = @"/var/jb";
            }
        } else {
            cachedRoot = @"/var/jb";
        }
    });
    return cachedRoot;
}

@interface SystemBlocker ()
@property (nonatomic, assign, readwrite) BOOL isAnalyticsBlocked;
@property (nonatomic, assign, readwrite) BOOL isSandboxBypassed;
@end

@implementation SystemBlocker {
    NSArray<NSString *> *_blockedHosts;
    NSArray<NSString *> *_blockedDaemons;
    BOOL _initialized;
}

+ (instancetype)sharedInstance {
    static SystemBlocker *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _initialized = NO;
        self.isAnalyticsBlocked = YES;
        self.isSandboxBypassed = YES;
        
        // Danh sách chặn telemetry rác (chỉ chặn endpoint analytics, không chạm vào CDN media)
        _blockedHosts = @[
            @"app-measurement.com",
            @"crashlytics.com",
            @"telemetry.apple.com",
            @"diagnostics.apple.com",
            @"metrics.icloud.com",
            @"xp.apple.com",
            @"firebaselogging-pa.googleapis.com",
            @"browser.sentry-cdn.com"
        ];

        _blockedDaemons = @[
            @"com.apple.ReportCrash",
            @"com.apple.awdd",
            @"com.apple.analyticsd",
            @"com.apple.powerlogHelperd"
        ];

        [self initBlockers];
    }
    return self;
}

- (void)initBlockers {
    if (_initialized) return;
    _initialized = YES;

    // 1. Thiết lập quyền truy cập thư mục cấu hình trong phân vùng Rootless
    NSString *root = SystemBlocker_ResolvePrefix();
    NSString *prefDir = [NSString stringWithFormat:@"%@/var/mobile/Library/Preferences", root];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:prefDir]) {
        [fm createDirectoryAtPath:prefDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
    }

    // 2. Tắt logging ngầm của Apple System Log (ASL) để giải phóng I/O và CPU
    setenv("OS_ACTIVITY_MODE", "disable", 1);
    setenv("SQLITE_ENABLE_IOTRACE", "0", 1);
}

- (BOOL)shouldBlockTelemetryURL:(NSURL *)url {
    if (!self.isAnalyticsBlocked || !url) return NO;
    NSString *host = [[url host] lowercaseString];
    if (!host) return NO;

    // BẢO VỆ MẠNG: Tuyệt đối không chặn các CDN phát video/nhạc hay tải game
    if ([host containsString:@"googlevideo.com"] || 
        [host containsString:@"byteoversea.com"] || 
        [host containsString:@"ibytedtos.com"] || 
        [host containsString:@"tiktokcdn.com"] || 
        [host containsString:@"fbcdn.net"]) {
        return NO;
    }

    for (NSString *blocked in _blockedHosts) {
        if ([host containsString:blocked]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)shouldMuteLoggingForBundle:(NSString *)bundleIdentifier {
    if (!bundleIdentifier) return NO;
    for (NSString *daemon in _blockedDaemons) {
        if ([bundleIdentifier isEqualToString:daemon]) {
            return YES;
        }
    }
    return NO;
}

@end
