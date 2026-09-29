#import "SystemBlocker.h"
#import <dlfcn.h>
#import <sys/stat.h>
#import <unistd.h>

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
        _isAnalyticsBlocked = YES;
        _isSandboxBypassed = YES;
        
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

    // 1. Vượt qua giới hạn kiểm soát sandbox đối với thư mục tạm và cấu hình tweak
    NSString *root = SystemBlocker_ResolvePrefix();
    NSString *prefDir = [NSString stringWithFormat:@"%@/var/mobile/Library/Preferences", root];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:prefDir]) {
        [fm createDirectoryAtPath:prefDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
    }

    // 2. Tắt logging rác của ASL (Apple System Log) cho tiến trình hiện tại để giảm I/O disk
    setenv("OS_ACTIVITY_MODE", "disable", 1);
    setenv("SQLITE_ENABLE_IOTRACE", "0", 1);
}

- (BOOL)shouldBlockTelemetryURL:(NSURL *)url {
    if (!_isAnalyticsBlocked || !url) return NO;
    NSString *host = [[url host] lowercaseString];
    if (!host) return NO;

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
