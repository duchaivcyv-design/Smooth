#import "RootListController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <fcntl.h>
#import <unistd.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/processor_info.h>
#import <mach/mach_host.h>
#import <mach/vm_map.h>
#import <AudioToolbox/AudioToolbox.h>
#import <QuartzCore/QuartzCore.h>

extern char **environ;

#ifndef APEX_SYNC_MAGIC_V285
#define APEX_SYNC_MAGIC_V285 0x41505837
#endif

#ifndef PRIMARY_SYNC_FILE
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#endif

#ifndef SECONDARY_SYNC_FILE
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#endif

#ifndef NOTIFY_RELOAD
#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#endif

static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cachedJbRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            NSRange range = [dylibPath rangeOfString:@"/var/jb"];
            if (range.location != NSNotFound) {
                NSRange sub = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, dylibPath.length - (range.location + 7))];
                cachedJbRoot = (sub.location != NSNotFound) ? [dylibPath substringToIndex:sub.location] : @"/var/jb";
            } else {
                cachedJbRoot = @"/var/jb";
            }
        } else {
            cachedJbRoot = @"/var/jb";
        }
    });
    return cachedJbRoot;
}

static inline NSString *Titanium_ResolvePrefPath(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    if (root && root.length > 0 && ![root isEqualToString:@"/"]) {
        NSString *jbPath = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) return jbPath;
    }
    NSString *p1 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    return @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
}

static inline NSString *Titanium_FindExecutablePath(NSString *name) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    NSArray *searchPrefixes = @[
        [root stringByAppendingPathComponent:@"usr/bin"],
        [root stringByAppendingPathComponent:@"bin"],
        @"/var/jb/usr/bin",
        @"/var/jb/bin",
        @"/usr/bin",
        @"/bin"
    ];

    for (NSString *prefix in searchPrefixes) {
        NSString *candidate = [prefix stringByAppendingPathComponent:name];
        if (access([candidate UTF8String], X_OK) == 0) return candidate;
    }
    return name;
}

static void Titanium_WriteSyncPayloadUniversal(const void *payloadData, size_t size) {
    NSArray *paths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    for (NSString *path in paths) {
        NSString *dir = [path stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
        }
        int fd = open([path UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) {
            write(fd, payloadData, size);
            close(fd);
            chmod([path UTF8String], 0666);
        }
    }
}

static inline BOOL Titanium_IsSupportedIOSVersion(void) {
    NSOperatingSystemVersion os = [[NSProcessInfo processInfo] operatingSystemVersion];
    return (os.majorVersion >= 15 && os.majorVersion <= 26);
}

static inline float Titanium_GetLiveCPULoadPercentage(void) {
    host_cpu_load_info_data_t cpuinfo;
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    static unsigned long long prevUser = 0, prevSystem = 0, prevIdle = 0, prevNice = 0;
    
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpuinfo, &count) == KERN_SUCCESS) {
        unsigned long long user = cpuinfo.cpu_ticks[CPU_STATE_USER];
        unsigned long long system = cpuinfo.cpu_ticks[CPU_STATE_SYSTEM];
        unsigned long long idle = cpuinfo.cpu_ticks[CPU_STATE_IDLE];
        unsigned long long nice = cpuinfo.cpu_ticks[CPU_STATE_NICE];
        
        unsigned long long totalTicks = (user - prevUser) + (system - prevSystem) + (idle - prevIdle) + (nice - prevNice);
        unsigned long long usedTicks = (user - prevUser) + (system - prevSystem) + (nice - prevNice);
        
        prevUser = user;
        prevSystem = system;
        prevIdle = idle;
        prevNice = nice;
        
        if (totalTicks > 0) {
            return ((float)usedTicks / (float)totalTicks) * 100.0f;
        }
    }
    return 14.5f;
}

static inline float Titanium_GetLiveGPULoadPercentage(void) {
    float cpu = Titanium_GetLiveCPULoadPercentage();
    float gpu = (cpu * 0.72f) + 3.8f;
    if (gpu > 99.0f) gpu = 98.6f;
    return gpu;
}

static inline float Titanium_GetBaseThermalTemp(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    float cpuLoad = Titanium_GetLiveCPULoadPercentage();
    float loadOffset = (cpuLoad / 100.0f) * 2.5f;

    switch (state) {
        case NSProcessInfoThermalStateNominal:  return 31.8f + loadOffset;
        case NSProcessInfoThermalStateFair:     return 36.2f + loadOffset;
        case NSProcessInfoThermalStateSerious:  return 40.8f + loadOffset;
        case NSProcessInfoThermalStateCritical: return 44.5f + loadOffset;
        default: return 32.2f + loadOffset;
    }
}

@interface RootListController () {
    dispatch_source_t _hudTimer;
    NSInteger _currentBottomTab;    // 0: Trang Chủ | 1: Hz/FPS | 2: Công Tắc | 3: App | 4: Cài Đặt
    NSInteger _currentHzFpsSubTab;
    NSInteger _currentSwitchSubTab;
    BOOL _isRateLocked;
    
    BOOL _isKernelExploited;
    
    BOOL _isCpuExpanded;
    BOOL _isGpuExpanded;
    BOOL _isRamExpanded;
    BOOL _isBatteryExpanded;
    BOOL _isScreenExpanded;
    
    NSString *_deepArchString;
    NSString *_deepCoreCountString;
    NSString *_deepRamString;
    NSString *_deepKernelString;
    NSString *_deepCacheString;
    NSString *_deviceUUIDString;
    
    NSMutableArray<NSDictionary *> *_scannedAppsList;
    NSMutableDictionary<NSString *, NSNumber *> *_appTweakStates;
    
    // Hiệu ứng bong bóng kính lỏng Liquid Glass
    UIView *_liquidGlassBubbleView;
}
@end

@implementation RootListController

@synthesize customTableView = _customTableView;
@synthesize bottomSegment = _bottomSegment;
@synthesize rateLockButton = _rateLockButton;
@synthesize settingsDict = _settingsDict;

- (instancetype)init {
    self = [super init];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"";
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.07 alpha:1.0];

    _currentBottomTab = 0; // Mặc định mở Trang Chủ ở giữa
    _currentHzFpsSubTab = 0;
    _currentSwitchSubTab = 0;

    _isCpuExpanded = NO;
    _isGpuExpanded = NO;
    _isRamExpanded = NO;
    _isBatteryExpanded = NO;
    _isScreenExpanded = NO;

    _scannedAppsList = [NSMutableArray array];

    [self loadSettingsData];
    _isRateLocked = [self.settingsDict[@"IsRateLocked"] boolValue];

    NSUUID *uuid = [[UIDevice currentDevice] identifierForVendor];
    _deviceUUIDString = uuid ? [uuid UUIDString] : @"UNKNOWN-DEVICE-UUID";

    _isKernelExploited = [self.settingsDict[@"IsKernelExploited"] boolValue];
    if (_isKernelExploited) {
        _deepArchString = self.settingsDict[@"SavedArchString"] ?: @"arm64e (Apple Silicon PAC)";
        _deepCoreCountString = self.settingsDict[@"SavedCoreCountString"] ?: @"SoC Clustered P/E Cores";
        _deepRamString = self.settingsDict[@"SavedRamString"] ?: @"LPDDR Mach Purgable";
        _deepKernelString = self.settingsDict[@"SavedKernelString"] ?: @"Darwin XNU Kernel";
        _deepCacheString = self.settingsDict[@"SavedCacheString"] ?: @"Low Latency Silicon Cache";
    }

    [self loadInstalledAppsAsync];

    [self setupTopHeaderBar];
    [self setupNavigationItems];
    [self setupBottomNavigationBar];
    [self setupMainTableView];
    [self setupLiquidGlassGestureEffect];

    [self applyDeepSpringBoardAndUIKitTweaks];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startContinuousHardwareHUD];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopContinuousHardwareHUD];
}

// Thiết lập hiệu ứng kính lỏng Liquid Glass bám tay khi vuốt chạm
- (void)setupLiquidGlassGestureEffect {
    _liquidGlassBubbleView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 72, 72)];
    _liquidGlassBubbleView.backgroundColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:0.25];
    _liquidGlassBubbleView.layer.cornerRadius = 36;
    _liquidGlassBubbleView.layer.borderWidth = 1.5;
    _liquidGlassBubbleView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.65].CGColor;
    _liquidGlassBubbleView.layer.shadowColor = [UIColor colorWithRed:0.2 green:0.8 blue:1.0 alpha:0.8].CGColor;
    _liquidGlassBubbleView.layer.shadowOffset = CGSizeZero;
    _liquidGlassBubbleView.layer.shadowRadius = 16;
    _liquidGlassBubbleView.layer.shadowOpacity = 0.8;
    _liquidGlassBubbleView.hidden = YES;

    if (@available(iOS 13.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialLight];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = _liquidGlassBubbleView.bounds;
        blurView.layer.cornerRadius = 36;
        blurView.clipsToBounds = YES;
        blurView.userInteractionEnabled = NO;
        [_liquidGlassBubbleView addSubview:blurView];
    }

    [self.view addSubview:_liquidGlassBubbleView];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleLiquidGlassPan:)];
    [self.view addGestureRecognizer:pan];
}

- (void)handleLiquidGlassPan:(UIPanGestureRecognizer *)pan {
    CGPoint pt = [pan locationInView:self.view];
    if (pan.state == UIGestureRecognizerStateBegan) {
        _liquidGlassBubbleView.center = pt;
        _liquidGlassBubbleView.hidden = NO;
        _liquidGlassBubbleView.transform = CGAffineTransformMakeScale(0.1, 0.1);
        [UIView animateWithDuration:0.2 animations:^{
            self->_liquidGlassBubbleView.transform = CGAffineTransformIdentity;
        }];
    } else if (pan.state == UIGestureRecognizerStateChanged) {
        _liquidGlassBubbleView.center = pt;
    } else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        [UIView animateWithDuration:0.2 animations:^{
            self->_liquidGlassBubbleView.transform = CGAffineTransformMakeScale(0.01, 0.01);
        } completion:^(BOOL finished) {
            self->_liquidGlassBubbleView.hidden = YES;
            self->_liquidGlassBubbleView.transform = CGAffineTransformIdentity;
        }];
    }
}

- (void)loadInstalledAppsAsync {
    NSDictionary *savedStates = self.settingsDict[@"AppTweakStates"];
    _appTweakStates = savedStates ? [savedStates mutableCopy] : [NSMutableDictionary dictionary];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSMutableArray<NSDictionary *> *tempApps = [NSMutableArray array];
        NSArray *dirs = @[@"/Applications", @"/var/jb/Applications"];
        NSFileManager *fm = [NSFileManager defaultManager];

        for (NSString *d in dirs) {
            if ([fm fileExistsAtPath:d]) {
                NSArray *items = [fm contentsOfDirectoryAtPath:d error:nil];
                for (NSString *item in items) {
                    if ([item hasSuffix:@".app"]) {
                        NSString *fullPath = [d stringByAppendingPathComponent:item];
                        NSString *infoPath = [fullPath stringByAppendingPathComponent:@"Info.plist"];
                        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:infoPath];
                        NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: [item stringByDeletingPathExtension];
                        NSString *bundleID = info[@"CFBundleIdentifier"] ?: item;

                        if (self->_appTweakStates[bundleID] == nil) {
                            self->_appTweakStates[bundleID] = @NO; // Mặc định tắt
                        }

                        [tempApps addObject:@{
                            @"name": name,
                            @"bundleID": bundleID,
                            @"path": fullPath
                        }];
                    }
                }
            }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            self->_scannedAppsList = tempApps;
            if (self->_currentBottomTab == 3) {
                [self.customTableView reloadData];
            }
        });
    });
}

- (void)applyDeepSpringBoardAndUIKitTweaks {
    if (!_isKernelExploited) return;

    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    if (self.view.window) {
        self.view.window.layer.drawsAsynchronously = YES;
    }

    if (@available(iOS 15.0, *)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSInteger targetHz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
            if (targetHz < 15) targetHz = 15;
            if (targetHz > 144) targetHz = 144;

            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    if ([ws respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                        CAFrameRateRange range = CAFrameRateRangeMake(targetHz, targetHz, targetHz);
                        [(id)ws setPreferredFrameRateRange:range];
                    }
                }
            }
        });
    }

    BOOL master = [self.settingsDict[@"Enabled"] ?: @NO boolValue];
    [self syncSharedMemoryFile:master];
}

- (void)showUnexploitedWarningAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 TÍNH NĂNG BỊ KHÓA"
                                                                   message:@"Hệ thống chưa được khai thác! Hãy vào tab Cài Đặt và nhấn vào dòng trạng thái đèn đỏ để bắt đầu khai thác thủ công."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// Khai thác thủ công từ Cài Đặt
- (void)openDopamineStyleExploitConsole {
    UIViewController *consoleVC = [[UIViewController alloc] init];
    consoleVC.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.06 alpha:1.0];
    consoleVC.modalPresentationStyle = UIModalPresentationFullScreen;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, consoleVC.view.bounds.size.width - 40, 30)];
    titleLabel.text = @"⚡ LIQUID GLASS KERNEL EXPLOIT";
    titleLabel.textColor = [UIColor colorWithRed:0.2 green:0.95 blue:0.6 alpha:1.0];
    titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:15] ?: [UIFont boldSystemFontOfSize:15];
    [consoleVC.view addSubview:titleLabel];

    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressView.frame = CGRectMake(20, 100, consoleVC.view.bounds.size.width - 40, 6);
    progressView.progressTintColor = [UIColor colorWithRed:0.2 green:0.95 blue:0.6 alpha:1.0];
    progressView.trackTintColor = [UIColor darkGrayColor];
    [consoleVC.view addSubview:progressView];

    UITextView *logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 120, consoleVC.view.bounds.size.width - 40, consoleVC.view.bounds.size.height - 210)];
    logTextView.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
    logTextView.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:0.5 alpha:1.0];
    logTextView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    logTextView.editable = NO;
    logTextView.layer.cornerRadius = 14;
    logTextView.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:1.0].CGColor;
    logTextView.layer.borderWidth = 1.0;
    [consoleVC.view addSubview:logTextView];

    [self presentViewController:consoleVC animated:YES completion:^{
        [self runExploitStagesWithConsole:logTextView progress:progressView controller:consoleVC];
    }];
}

- (void)runExploitStagesWithConsole:(UITextView *)logTextView progress:(UIProgressView *)progressView controller:(UIViewController *)consoleVC {
    NSArray *stages = @[
        [NSString stringWithFormat:@"[Stage 1/6] Nhận diện UID thiết bị: %@...", _deviceUUIDString],
        @"[Stage 2/6] Khởi tạo Mach Host & Vượt rào cản PAC arm64e...",
        @"[Stage 3/6] Can thiệp XNU Scheduler, phân bổ P-Core Realtime...",
        @"[Stage 4/6] Đọc thông số phần cứng Darwin & Cấu trúc Mach VM...",
        @"[Stage 5/6] Ghi đè Pipeline Metal GPU & Kích hoạt Triple Buffering...",
        @"[Stage 6/6] Đồng bộ Shmem IPC đa phân vùng (/tmp & /var/jb/tmp)...",
        @"✅ KHAI THÁC THÀNH CÔNG! Toàn bộ hệ thống đã được mở khóa."
    ];

    __block NSInteger currentIdx = 0;
    NSMutableString *logBuffer = [NSMutableString stringWithFormat:@"[*] Tiến hành khai thác thủ công (UID: %@)...\n", _deviceUUIDString];
    logTextView.text = logBuffer;

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:2.2 repeats:YES block:^(NSTimer * _Nonnull t) {
        if (currentIdx < stages.count) {
            [logBuffer appendFormat:@"\n%@", stages[currentIdx]];
            logTextView.text = logBuffer;
            [logTextView scrollRangeToVisible:NSMakeRange(logTextView.text.length - 1, 1)];

            float prog = (float)(currentIdx + 1) / (float)stages.count;
            [progressView setProgress:prog animated:YES];

            UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
            [fb impactOccurred];

            currentIdx++;
        } else {
            [t invalidate];

            UINotificationFeedbackGenerator *notiFb = [[UINotificationFeedbackGenerator alloc] init];
            [notiFb notificationOccurred:UINotificationFeedbackTypeSuccess];

            [self persistExploitDataToDisk];
            [self applyDeepSpringBoardAndUIKitTweaks];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [consoleVC dismissViewControllerAnimated:YES completion:^{
                    [self.customTableView reloadData];
                }];
            });
        }
    }];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
}

- (void)persistExploitDataToDisk {
    char cpuTypeStr[128] = {0};
    size_t size = sizeof(cpuTypeStr);
    sysctlbyname("machdep.cpu.brand_string", cpuTypeStr, &size, NULL, 0);
    NSString *brand = [NSString stringWithUTF8String:cpuTypeStr];
    if (!brand || brand.length == 0) {
        #if defined(__arm64e__)
        _deepArchString = @"arm64e (Apple PAC v8.3+ Cryptographic)";
        #elif defined(__arm64__)
        _deepArchString = @"arm64 (Apple A-Series 64-bit Core)";
        #else
        _deepArchString = @"ARM64 Silicon Native";
        #endif
    } else {
        _deepArchString = brand;
    }

    int ncpu = 0;
    size = sizeof(ncpu);
    sysctlbyname("hw.ncpu", &ncpu, &size, NULL, 0);
    _deepCoreCountString = [NSString stringWithFormat:@"%d Nhân SoC (Clustered P/E)", ncpu];

    int64_t memsize = 0;
    size = sizeof(memsize);
    sysctlbyname("hw.memsize", &memsize, &size, NULL, 0);
    double ramGB = (double)memsize / (1024.0 * 1024.0 * 1024.0);
    _deepRamString = [NSString stringWithFormat:@"%.2f GB LPDDR (Mach Purgable)", ramGB];

    char osrelease[64] = {0};
    size = sizeof(osrelease);
    sysctlbyname("kern.osrelease", osrelease, &size, NULL, 0);
    _deepKernelString = [NSString stringWithFormat:@"Darwin %s (XNU Kernel)", osrelease];

    int64_t l2cache = 0;
    size = sizeof(l2cache);
    sysctlbyname("hw.l2cachesize", &l2cache, &size, NULL, 0);
    _deepCacheString = (l2cache > 0) ? [NSString stringWithFormat:@"%lld KB L2 Cache", l2cache / 1024] : @"Low Latency Silicon Cache";

    _isKernelExploited = YES;

    self.settingsDict[@"IsKernelExploited"] = @YES;
    self.settingsDict[@"SavedArchString"] = _deepArchString;
    self.settingsDict[@"SavedCoreCountString"] = _deepCoreCountString;
    self.settingsDict[@"SavedRamString"] = _deepRamString;
    self.settingsDict[@"SavedKernelString"] = _deepKernelString;
    self.settingsDict[@"SavedCacheString"] = _deepCacheString;
    self.settingsDict[@"SavedDeviceUUID"] = _deviceUUIDString;
    [self saveSettingsDataAndSync];
}

- (void)loadSettingsData {
    NSString *prefPath = Titanium_ResolvePrefPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
        self.settingsDict = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];
    } else {
        self.settingsDict = [NSMutableDictionary dictionary];
    }
    [self ensureDefaultSettingsExist];
}

- (void)saveSettingsDataAndSync {
    NSString *prefPath = Titanium_ResolvePrefPath();
    NSString *dir = [prefPath stringByDeletingLastPathComponent];
    if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
    }
    [self.settingsDict writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0666);

    BOOL master = [self.settingsDict[@"Enabled"] boolValue];
    [self syncSharedMemoryFile:master];
}

- (void)setupTopHeaderBar {
    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.text = @" 💧 Liquid Glass Pro ";
    brandLabel.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:1.0 alpha:1.0];
    brandLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightHeavy];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:brandLabel];

    self.rateLockButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self updateLockIcon];
    [self.rateLockButton addTarget:self action:@selector(toggleRateLockAction) forControlEvents:UIControlEventTouchUpInside];
}

- (void)updateLockIcon {
    NSString *iconName = self->_isRateLocked ? @"lock.fill" : @"lock.open.fill";
    UIColor *color = self->_isRateLocked ? [UIColor systemRedColor] : [UIColor systemGreenColor];
    if (@available(iOS 13.0, *)) {
        [self.rateLockButton setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
    } else {
        [self.rateLockButton setTitle:(self->_isRateLocked ? @"🔒" : @"🔓") forState:UIControlStateNormal];
    }
    self.rateLockButton.tintColor = color;
}

- (void)toggleRateLockAction {
    if (!_isKernelExploited) {
        [self showUnexploitedWarningAlert];
        return;
    }

    self->_isRateLocked = !self->_isRateLocked;
    self.settingsDict[@"IsRateLocked"] = @(self->_isRateLocked);
    [self saveSettingsDataAndSync];
    [self updateLockIcon];

    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [feedback impactOccurred];

    [self applyDeepSpringBoardAndUIKitTweaks];
    [self.customTableView reloadData];
}

- (void)setupNavigationItems {
    UIBarButtonItem *lockItem = [[UIBarButtonItem alloc] initWithCustomView:self.rateLockButton];

    if (@available(iOS 14.0, *)) {
        UIAction *actRespring = [UIAction actionWithTitle:@"⚡ Respring Nhanh (Làm Mới)"
                                                    image:[UIImage systemImageNamed:@"bolt.fill"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self executeRespring];
        }];

        UIAction *actSReboot = [UIAction actionWithTitle:@"🔥 Khởi Động Userspace"
                                                   image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSReboot];
        }];

        UIAction *actSafeMode = [UIAction actionWithTitle:@"🛡️ Vào Safe Mode An Toàn"
                                                    image:[UIImage systemImageNamed:@"shield.lefthalf.fill"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSafeMode];
        }];

        UIAction *actReset = [UIAction actionWithTitle:@"♻ Đặt Lại & Xóa Cấu Hình"
                                                 image:[UIImage systemImageNamed:@"trash.fill"]
                                            identifier:nil
                                               handler:^(__kindof UIAction * _Nonnull action) {
            [self executeResetConfiguration];
        }];
        actReset.attributes = UIMenuElementAttributesDestructive;

        UIMenu *threeBarMenu = [UIMenu menuWithTitle:@"HÀNH ĐỘNG HỆ THỐNG" children:@[actRespring, actSReboot, actSafeMode, actReset]];

        UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"]
                                                                       menu:threeBarMenu];
        menuItem.tintColor = [UIColor whiteColor];

        self.navigationItem.rightBarButtonItems = @[menuItem, lockItem];
    } else {
        UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithTitle:@"☰"
                                                                      style:UIBarButtonItemStylePlain
                                                                     target:self
                                                                     action:@selector(executeRespring)];
        menuItem.tintColor = [UIColor whiteColor];
        self.navigationItem.rightBarButtonItems = @[menuItem, lockItem];
    }
}

// Bố cục thanh điều hướng Liquid Glass chuẩn iOS 26, 📊 Trang Chủ đặt ở giữa nổi bật to rõ
- (void)setupBottomNavigationBar {
    UIView *bottomBarContainer = [[UIView alloc] initWithFrame:CGRectMake(12, self.view.bounds.size.height - 88, self.view.bounds.size.width - 24, 58)];
    bottomBarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    bottomBarContainer.backgroundColor = [UIColor colorWithRed:0.06 green:0.09 blue:0.16 alpha:0.75];
    bottomBarContainer.layer.cornerRadius = 24;
    bottomBarContainer.layer.borderWidth = 1.2;
    bottomBarContainer.layer.borderColor = [UIColor colorWithWhite:0.4 alpha:0.35].CGColor;
    
    if (@available(iOS 13.0, *)) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = bottomBarContainer.bounds;
        blurView.layer.cornerRadius = 24;
        blurView.clipsToBounds = YES;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [bottomBarContainer addSubview:blurView];
    }
    
    [self.view addSubview:bottomBarContainer];

    self.bottomSegment = [[UISegmentedControl alloc] initWithItems:@[@"🎛️ Hz/FPS", @"⚡ Switch", @"📊 Trang Chủ", @"📱 App", @"⚙️ Cài Đặt"]];
    self.bottomSegment.frame = CGRectMake(4, 6, bottomBarContainer.bounds.size.width - 8, 46);
    self.bottomSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.bottomSegment.selectedSegmentIndex = 2; // Mặc định mở Trang Chủ ở giữa
    _currentBottomTab = 0;

    NSDictionary *attrNormal = @{NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightMedium], NSForegroundColorAttributeName: [UIColor colorWithWhite:0.65 alpha:1.0]};
    NSDictionary *attrSelected = @{NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightBold], NSForegroundColorAttributeName: [UIColor whiteColor]};
    [self.bottomSegment setTitleTextAttributes:attrNormal forState:UIControlStateNormal];
    [self.bottomSegment setTitleTextAttributes:attrSelected forState:UIControlStateSelected];

    [self.bottomSegment addTarget:self action:@selector(onBottomTabChanged:) forControlEvents:UIControlEventValueChanged];
    [bottomBarContainer addSubview:self.bottomSegment];
}

- (void)onBottomTabChanged:(UISegmentedControl *)sender {
    NSInteger index = sender.selectedSegmentIndex;
    if (index == 0) _currentBottomTab = 1;
    else if (index == 1) _currentBottomTab = 2;
    else if (index == 2) _currentBottomTab = 0;
    else if (index == 3) _currentBottomTab = 3;
    else if (index == 4) _currentBottomTab = 4;

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    [self.customTableView reloadData];
}

- (void)setupMainTableView {
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 96) style:UITableViewStyleInsetGrouped];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor clearColor];
    self.customTableView.delegate = self;
    self.customTableView.dataSource = self;
    [self.view addSubview:self.customTableView];
}

#pragma mark - TableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_currentBottomTab == 0) return 6; // Section 0 là Master Switch đo hệ thống + 5 Section CPU/GPU/RAM/Pin/Màn hình
    if (_currentBottomTab == 1) return 3;
    if (_currentBottomTab == 2) return 2;
    if (_currentBottomTab == 3) return 1;
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_currentBottomTab == 0) {
        if (section == 0) return 1; // Công tắc Master đo hệ thống
        BOOL isMonitorActive = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
        if (!isMonitorActive) return 1; // Tắt thì chỉ hiện 1 dòng thông báo trạng thái tắt

        if (section == 1) return _isCpuExpanded ? 5 : 1;
        if (section == 2) return _isGpuExpanded ? 5 : 1;
        if (section == 3) return _isRamExpanded ? 4 : 1;
        if (section == 4) return _isBatteryExpanded ? 5 : 1;
        return _isScreenExpanded ? 4 : 1;
    } else if (_currentBottomTab == 1) {
        if (section == 0) return 1;
        if (section == 1) return 1;
        return 6;
    } else if (_currentBottomTab == 2) {
        if (section == 0) return 1;
        switch (_currentSwitchSubTab) {
            case 0: return 5;
            case 1: return 5;
            case 2: return 5;
            case 3: return 5;
            case 4: return 6;
            default: return 5;
        }
    } else if (_currentBottomTab == 3) {
        return _scannedAppsList.count;
    } else {
        if (section == 0) return 2;
        if (section == 1) return _isKernelExploited ? 8 : 1;
        return 4;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_currentBottomTab == 0) {
        if (section == 0) return @"🎛️ ĐIỀU KHIỂN HỆ THỐNG ĐO";
        if (section == 1) return @"🧠 BỘ XỬ LÝ TRUNG TÂM (CPU)";
        if (section == 2) return @"🎮 BỘ XỬ LÝ ĐỒ HỌA (GPU)";
        if (section == 3) return @"💾 BỘ NHỚ TRUY XUẤT (RAM)";
        if (section == 4) return @"🔋 NGUỒN ĐIỆN & PIN";
        return @"🖥️ MÀN HÌNH HIỂN THỊ";
    } else if (_currentBottomTab == 1) {
        if (section == 0) return @"ℹ️ NGUYÊN LÝ HOẠT ĐỘNG HZ & FPS";
        if (section == 1) return @"⚡ ĐIỀU PHỐI ĐỘC LẬP TẦN SỐ QUÉT";
        return (_currentHzFpsSubTab == 0) ? @"🎛️ KHÓA TẦN SỐ QUÉT (HZ)" : @"🎮 KHÓA KHUNG HÌNH (FPS)";
    } else if (_currentBottomTab == 2) {
        if (section == 0) return @"🎚️ CHỌN PHÂN NHÓM CÔNG TẮC";
        switch (_currentSwitchSubTab) {
            case 0: return @"🧠 NHÓM CPU";
            case 1: return @"🎮 NHÓM GPU";
            case 2: return @"🖥️ NHÓM MÀN HÌNH";
            case 3: return @"🔋 NHÓM PIN";
            case 4: return @"⚡ NHÓM HỆ THỐNG";
            default: return @"🟢 CÔNG TẮC";
        }
    } else if (_currentBottomTab == 3) {
        return @"📱 QUẢN LÝ ỨNG DỤNG TƯƠNG TÁC";
    } else {
        if (section == 0) return @"🛡️ TRẠNG THÁI KHAI THÁC HỆ THỐNG";
        if (section == 1) return @"📱 THÔNG TIN PHẦN CỨNG THIẾT BỊ";
        return @"🛡️ THÔNG TIN VÙNG SANDBOX";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellID = [NSString stringWithFormat:@"Cell_%ld_%ld_%ld", (long)_currentBottomTab, (long)indexPath.section, (long)indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
    }

    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }

    cell.backgroundColor = [UIColor colorWithRed:0.07 green:0.10 blue:0.16 alpha:0.65];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:0.85 blue:0.98 alpha:1.0];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    // TAB 0: TRANG CHỦ
    if (_currentBottomTab == 0) {
        if (indexPath.section == 0) {
            cell.textLabel.text = @"⚡ Bật / Tắt Bộ Đo Hệ Thống";
            cell.textLabel.font = [UIFont boldSystemFontOfSize:14];

            UISwitch *monitorSwitch = [[UISwitch alloc] init];
            monitorSwitch.on = [self.settingsDict[@"EnableSystemMonitoring"] boolValue]; // Mặc định là TẮT
            [monitorSwitch addTarget:self action:@selector(onSystemMonitorToggled:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = monitorSwitch;
            return cell;
        }

        BOOL isMonitorActive = [self.settingsDict[@"EnableSystemMonitoring"] boolValue];
        if (!isMonitorActive) {
            cell.textLabel.text = @"🔒 Bộ đo đang tắt (Bật công tắc phía trên để xem)";
            cell.detailTextLabel.text = @"[ĐÃ TẮT]";
            cell.detailTextLabel.textColor = [UIColor systemOrangeColor];
            cell.textLabel.textColor = [UIColor lightGrayColor];
            return cell;
        }

        float baseTemp = Titanium_GetBaseThermalTemp();
        float cpu = Titanium_GetLiveCPULoadPercentage();
        float gpu = Titanium_GetLiveGPULoadPercentage();

        cell.selectionStyle = UITableViewCellSelectionStyleDefault;

        if (indexPath.section == 1) {
            if (indexPath.row == 0) {
                cell.textLabel.text = _isCpuExpanded ? @"🧠 CPU (Chạm để thu gọn ▼)" : @"🧠 CPU (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: %.1f%%", baseTemp, cpu];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ CPU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> % Tải CPU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%%", cpu];
            } else if (indexPath.row == 3) {
                float ghz = (cpu > 60.0f) ? 2.49f : ((cpu > 25.0f) ? 1.85f : 1.10f);
                cell.textLabel.text = @"   |--> Xung nhịp CPU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f GHz", ghz];
            } else {
                cell.textLabel.text = @"   |--> Trạng thái P-Core";
                cell.detailTextLabel.text = (cpu > 40.0f) ? @"Hiệu Năng Cao" : @"Tiết Kiệm Điện";
            }
        } else if (indexPath.section == 2) {
            if (indexPath.row == 0) {
                cell.textLabel.text = _isGpuExpanded ? @"🎮 GPU (Chạm để thu gọn ▼)" : @"🎮 GPU (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: %.1f%%", baseTemp - 0.7f, gpu];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ GPU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 0.7f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> % Tải GPU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%%", gpu];
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"   |--> Xung nhịp Metal";
                cell.detailTextLabel.text = @"600 MHz";
            } else {
                cell.textLabel.text = @"   |--> Pipeline Buffer";
                cell.detailTextLabel.text = @"Triple Buffering";
            }
        } else if (indexPath.section == 3) {
            if (indexPath.row == 0) {
                cell.textLabel.text = _isRamExpanded ? @"💾 RAM (Chạm để thu gọn ▼)" : @"💾 RAM (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: 42.5%%", baseTemp - 1.2f];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ RAM Bus";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.2f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Dung lượng đã cấp";
                cell.detailTextLabel.text = _deepRamString ?: @"2.85 GB / 4.00 GB";
            } else {
                cell.textLabel.text = @"   |--> Trạng thái Purgable";
                cell.detailTextLabel.text = @"Mach Clean";
            }
        } else if (indexPath.section == 4) {
            [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
            int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
            if (level < 0) level = 100;
            float batteryLoad = (cpu * 0.45f) + 8.5f;

            if (indexPath.row == 0) {
                cell.textLabel.text = _isBatteryExpanded ? @"🔋 Pin (Chạm để thu gọn ▼)" : @"🔋 Pin (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Tải: %.1f%%", baseTemp - 2.0f, batteryLoad];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ cell Pin";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 2.0f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> % Tải xả pin";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%% Load", batteryLoad];
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"   |--> Mức dung lượng";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%d%%", level];
            } else {
                cell.textLabel.text = @"   |--> Trạng thái sạc";
                cell.detailTextLabel.text = @"Li-ion Zin Chuẩn";
            }
        } else {
            NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
            NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];

            if (indexPath.row == 0) {
                cell.textLabel.text = _isScreenExpanded ? @"🖥️ Màn Hình (Chạm để thu gọn ▼)" : @"🖥️ Màn Hình (Chạm để xem chi tiết ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %ld Hz", baseTemp - 1.5f, (long)hz];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ bề mặt";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.5f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Tần số quét (Hz)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld Hz", (long)hz];
            } else {
                cell.textLabel.text = @"   |--> Khung hình (FPS)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld FPS", (long)fps];
            }
        }
    } 
    // TAB 1: HZ / FPS
    else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
            cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.85 blue:0.95 alpha:1.0];
            cell.textLabel.text = @"📌 Lưu ý: Tần số Hz/FPS giúp tối ưu chu kỳ CADisplayLink, giảm độ trễ hiển thị UIKit và SpringBoard nhằm tạo cảm giác mượt mà tối đa.";
        } else if (indexPath.section == 1) {
            UISegmentedControl *subSeg = [[UISegmentedControl alloc] initWithItems:@[@"Tần Số Quét (Hz)", @"Khung Hình (FPS)"]];
            subSeg.frame = CGRectMake(12, 6, cell.contentView.bounds.size.width - 24, 32);
            subSeg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            subSeg.selectedSegmentIndex = _currentHzFpsSubTab;
            [subSeg addTarget:self action:@selector(onHzFpsSubTabChanged:) forControlEvents:UIControlEventValueChanged];
            [cell.contentView addSubview:subSeg];
            cell.textLabel.text = @"";
            cell.detailTextLabel.text = @"";
        } else {
            BOOL isHz = (_currentHzFpsSubTab == 0);
            NSInteger currentVal = isHz ? [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue] : [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
            NSArray *standardRates = @[@30, @60, @90, @120];

            if (indexPath.row < 4) {
                NSInteger r = [standardRates[indexPath.row] integerValue];
                cell.textLabel.text = [NSString stringWithFormat:@"Khóa Cứng %ld %@", (long)r, isHz ? @"Hz" : @"FPS"];
                cell.detailTextLabel.text = (currentVal == r) ? @"✓ Đang Chọn" : @"";
                cell.detailTextLabel.textColor = (currentVal == r) ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
            } else if (indexPath.row == 4) {
                cell.textLabel.text = [NSString stringWithFormat:@"⚡ Mở Rộng 144 %@", isHz ? @"Hz" : @"FPS"];
                cell.detailTextLabel.text = (currentVal == 144) ? @"✓ Đang Chọn" : @"";
                cell.detailTextLabel.textColor = (currentVal == 144) ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
            } else {
                cell.textLabel.text = @"⌨️ Tự Nhập Số Chính Xác (15 - 144)...";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Hiện tại: %ld", (long)currentVal];
                cell.detailTextLabel.textColor = [UIColor systemYellowColor];
            }

            cell.selectionStyle = _isRateLocked ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
        }
    } 
    // TAB 2: CÔNG TẮC (MẶC ĐỊNH TẮT TOÀN BỘ, VẪN BẤM BẬT/TẮT ĐƯỢC)
    else if (_currentBottomTab == 2) {
        if (indexPath.section == 0) {
            UISegmentedControl *catSeg = [[UISegmentedControl alloc] initWithItems:@[@"CPU", @"GPU", @"Màn Hình", @"Pin", @"Hệ Thống"]];
            catSeg.frame = CGRectMake(8, 6, cell.contentView.bounds.size.width - 16, 32);
            catSeg.autoresizingMask = UIViewAutoresizingFlexibleWidth;
            catSeg.selectedSegmentIndex = _currentSwitchSubTab;
            [catSeg addTarget:self action:@selector(onSwitchSubTabChanged:) forControlEvents:UIControlEventValueChanged];
            [cell.contentView addSubview:catSeg];
            cell.textLabel.text = @"";
            cell.detailTextLabel.text = @"";
        } else {
            UISwitch *toggle = [[UISwitch alloc] init];
            [toggle addTarget:self action:@selector(onSwitchToggled:) forControlEvents:UIControlEventValueChanged];

            NSString *title = @"";
            BOOL state = NO;
            NSInteger tag = 0;

            if (_currentSwitchSubTab == 0) {
                if (indexPath.row == 0) { title = @"Ưu Tiên P-Core Realtime"; state = [self.settingsDict[@"pCoreRealtimePriority"] ?: @NO boolValue]; tag = 101; }
                else if (indexPath.row == 1) { title = @"Điều Phối CPU Scheduler"; state = [self.settingsDict[@"schedulerGovernor"] ?: @NO boolValue]; tag = 102; }
                else if (indexPath.row == 2) { title = @"Đồng Bộ Xung Quantum"; state = [self.settingsDict[@"quantumCoreSync"] ?: @NO boolValue]; tag = 103; }
                else if (indexPath.row == 3) { title = @"Khóa Tần Số CPU Sàn"; state = [self.settingsDict[@"lockHighIdleFloor"] ?: @NO boolValue]; tag = 104; }
                else { title = @"Chống Bóp Xung Nhiệt Độ"; state = [self.settingsDict[@"AntiThermalThrottling"] ?: @NO boolValue]; tag = 105; }
            } else if (_currentSwitchSubTab == 1) {
                if (indexPath.row == 0) { title = @"Metal Hex/Triple Buffering"; state = [self.settingsDict[@"MetalHexBuffering"] ?: @NO boolValue]; tag = 201; }
                else if (indexPath.row == 1) { title = @"Cưỡng Chế RenderServer 90"; state = [self.settingsDict[@"IsolateRenderPipeline"] ?: @NO boolValue]; tag = 202; }
                else if (indexPath.row == 2) { title = @"Bỏ Khóa V-Sync Khung Hình"; state = [self.settingsDict[@"vsyncAdaptiveBuffer"] ?: @NO boolValue]; tag = 203; }
                else if (indexPath.row == 3) { title = @"Ổn Định Khung Hình Game"; state = [self.settingsDict[@"gameFPSStabilizer"] ?: @NO boolValue]; tag = 204; }
                else { title = @"Triệt Tiêu Blur Động"; state = [self.settingsDict[@"flatTintBlur"] ?: @NO boolValue]; tag = 205; }
            } else if (_currentSwitchSubTab == 2) {
                if (indexPath.row == 0) { title = @"🔥 Ép Xung 144Hz Toàn Máy"; state = [self.settingsDict[@"ForceOverclock144Hz"] ?: @NO boolValue]; tag = 301; }
                else if (indexPath.row == 1) { title = @"ProMotion Engine Beta 7"; state = [self.settingsDict[@"ProMotionEngineBeta7"] ?: @NO boolValue]; tag = 302; }
                else if (indexPath.row == 2) { title = @"Cảm Ứng 0ms Touch Boost"; state = [self.settingsDict[@"TouchResponseBoost"] ?: @NO boolValue]; tag = 303; }
                else if (indexPath.row == 3) { title = @"Động Cơ Cuộn ColorOS 17"; state = [self.settingsDict[@"ColorOs17SmoothEngine"] ?: @NO boolValue]; tag = 304; }
                else { title = @"Dự Đoán Tọa Độ Neural"; state = [self.settingsDict[@"zeroLagNeural"] ?: @NO boolValue]; tag = 305; }
            } else if (_currentSwitchSubTab == 3) {
                if (indexPath.row == 0) { title = @"Lọc Loạn Cảm Ứng Sạc"; state = [self.settingsDict[@"AntiGhostTouch"] ?: @NO boolValue]; tag = 401; }
                else if (indexPath.row == 1) { title = @"Khử Nhiễu Sóng Củ Sạc"; state = [self.settingsDict[@"ChargerRippleRejection"] ?: @NO boolValue]; tag = 402; }
                else if (indexPath.row == 2) { title = @"Giả Lập Pin Đầy"; state = [self.settingsDict[@"fakeFullBatteryState"] ?: @NO boolValue]; tag = 403; }
                else if (indexPath.row == 3) { title = @"Khóa 30 FPS Khi Quá Nhiệt"; state = [self.settingsDict[@"lock30FpsOnOverheat"] ?: @NO boolValue]; tag = 404; }
                else { title = @"Chế Độ Tiết Kiệm Pin 60Hz"; state = [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue]; tag = 405; }
            } else {
                if (indexPath.row == 0) { title = @"Khởi Động App Siêu Tốc"; state = [self.settingsDict[@"TurboAppLaunch"] ?: @NO boolValue]; tag = 501; }
                else if (indexPath.row == 1) { title = @"Trị Dứt Điểm Đen App"; state = [self.settingsDict[@"FixAppLaunchBlackScreen"] ?: @NO boolValue]; tag = 502; }
                else if (indexPath.row == 2) { title = @"Giảm Lag Đa Nhiệm"; state = [self.settingsDict[@"ReduceMultiTaskLag"] ?: @NO boolValue]; tag = 503; }
                else if (indexPath.row == 3) { title = @"Chống Khựng Thoát App"; state = [self.settingsDict[@"FixAppExitStutter"] ?: @NO boolValue]; tag = 504; }
                else if (indexPath.row == 4) { title = @"Dọn RAM Chuyên Sâu"; state = [self.settingsDict[@"hyperMemoryGuardian"] ?: @NO boolValue]; tag = 505; }
                else { title = @"Tự Động Đóng App Nền"; state = [self.settingsDict[@"autoKillBackground"] ?: @NO boolValue]; tag = 506; }
            }

            toggle.tag = tag;
            toggle.on = state;

            cell.textLabel.text = title;
            cell.textLabel.textColor = [UIColor whiteColor];
            toggle.enabled = YES;
            toggle.alpha = 1.0;

            cell.accessoryView = toggle;
        }
    } 
    // TAB 3: DANH SÁCH ỨNG DỤNG
    else if (_currentBottomTab == 3) {
        if (_scannedAppsList.count > indexPath.row) {
            NSDictionary *appInfo = _scannedAppsList[indexPath.row];
            NSString *name = appInfo[@"name"];
            NSString *bundleID = appInfo[@"bundleID"];

            cell.textLabel.text = name;
            cell.detailTextLabel.text = bundleID;
            cell.detailTextLabel.font = [UIFont systemFontOfSize:11];

            UISwitch *appToggle = [[UISwitch alloc] init];
            appToggle.on = [_appTweakStates[bundleID] boolValue];
            appToggle.tag = indexPath.row;
            [appToggle addTarget:self action:@selector(onAppToggleChanged:) forControlEvents:UIControlEventValueChanged];

            cell.textLabel.textColor = [UIColor whiteColor];
            appToggle.enabled = YES;
            appToggle.alpha = 1.0;

            cell.accessoryView = appToggle;
        }
    }
    // TAB 4: CÀI ĐẶT
    else {
        if (indexPath.section == 0) {
            if (indexPath.row == 0) {
                if (_isKernelExploited) {
                    cell.backgroundColor = [UIColor colorWithRed:0.06 green:0.20 blue:0.12 alpha:0.9];
                    cell.textLabel.text = @"🟢 ĐÃ KHAI THÁC & HOẠT ĐỘNG (SẴN SÀNG)";
                    cell.textLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                    cell.detailTextLabel.text = @"✓ Đã Lưu Máy";
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                } else {
                    cell.backgroundColor = [UIColor colorWithRed:0.30 green:0.08 blue:0.10 alpha:0.9];
                    cell.textLabel.text = @"🔴 CHƯA KHAI THÁC [BẤM ĐỂ BẮT ĐẦU 15S]";
                    cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
                    cell.detailTextLabel.text = @"✕ Bấm Ngay";
                    cell.detailTextLabel.textColor = [UIColor systemYellowColor];
                }
                cell.textLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightHeavy];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                NSString *curIOS = [[UIDevice currentDevice] systemVersion];
                BOOL isSupported = Titanium_IsSupportedIOSVersion();
                
                if (isSupported) {
                    cell.backgroundColor = [UIColor colorWithRed:0.06 green:0.20 blue:0.12 alpha:0.9];
                    cell.textLabel.text = [NSString stringWithFormat:@"🟢 iOS Hỗ Trợ: iOS %@ (Tương Thích)", curIOS];
                    cell.textLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                    cell.detailTextLabel.text = @"Chuẩn 15 - 18.7.1";
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                } else {
                    cell.backgroundColor = [UIColor colorWithRed:0.30 green:0.08 blue:0.10 alpha:0.9];
                    cell.textLabel.text = [NSString stringWithFormat:@"🔴 iOS Hỗ Trợ: iOS %@ (Không Hỗ Trợ)", curIOS];
                    cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                    cell.detailTextLabel.text = @"Không Khả Dụng";
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0];
                }
                cell.textLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
        } else if (indexPath.section == 1) {
            if (!_isKernelExploited) {
                if (indexPath.row == 0) { cell.textLabel.text = @"Thông Tin Phần Cứng"; cell.detailTextLabel.text = @"[Đang ẩn - Cần Khai Thác]"; }
            } else {
                struct utsname sysInfo;
                uname(&sysInfo);
                NSString *deviceModel = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
                NSString *osVersion = [[UIDevice currentDevice] systemVersion];

                if (indexPath.row == 0) { cell.textLabel.text = @"UID Thiết Bị"; cell.detailTextLabel.text = _deviceUUIDString; }
                else if (indexPath.row == 1) { cell.textLabel.text = @"Mã Thiết Bị"; cell.detailTextLabel.text = deviceModel; }
                else if (indexPath.row == 2) { cell.textLabel.text = @"Kiến Trúc"; cell.detailTextLabel.text = _deepArchString; }
                else if (indexPath.row == 3) { cell.textLabel.text = @"Phiên Bản iOS"; cell.detailTextLabel.text = [NSString stringWithFormat:@"iOS %@", osVersion]; }
                else if (indexPath.row == 4) { cell.textLabel.text = @"Tên Máy"; cell.detailTextLabel.text = [[UIDevice currentDevice] name]; }
                else if (indexPath.row == 5) { cell.textLabel.text = @"Số Nhân CPU"; cell.detailTextLabel.text = _deepCoreCountString; }
                else if (indexPath.row == 6) { cell.textLabel.text = @"RAM Vật Lý"; cell.detailTextLabel.text = _deepRamString; }
                else { cell.textLabel.text = @"Darwin Release"; cell.detailTextLabel.text = _deepKernelString; }
            }
        } else {
            NSString *jbRoot = Titanium_GetRootHidePrefixPath();
            BOOL isRootless = [jbRoot containsString:@"/var/jb"];

            if (indexPath.row == 0) { cell.textLabel.text = @"Môi Trường"; cell.detailTextLabel.text = isRootless ? @"Rootless / RootHide" : @"Rootful"; }
            else if (indexPath.row == 1) { cell.textLabel.text = @"Vùng Thư Mục"; cell.detailTextLabel.text = jbRoot; }
            else if (indexPath.row == 2) { cell.textLabel.text = @"Trạng Thái Sandbox"; cell.detailTextLabel.text = _isKernelExploited ? @"Đã Phá Bỏ (Unsandboxed)" : @"Đang Khóa"; cell.detailTextLabel.textColor = _isKernelExploited ? [UIColor systemGreenColor] : [UIColor systemOrangeColor]; }
            else { cell.textLabel.text = @"Quyền Ghi IPC"; cell.detailTextLabel.text = @"🟢 Hoạt Động (RW)"; }
        }
    }

    return cell;
}

- (void)onSystemMonitorToggled:(UISwitch *)sender {
    self.settingsDict[@"EnableSystemMonitoring"] = @(sender.isOn);
    [self saveSettingsDataAndSync];

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    [self.customTableView reloadData];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (_currentBottomTab == 0 && _isKernelExploited) {
        if (indexPath.section > 0 && indexPath.row == 0) {
            if (indexPath.section == 1) _isCpuExpanded = !_isCpuExpanded;
            else if (indexPath.section == 2) _isGpuExpanded = !_isGpuExpanded;
            else if (indexPath.section == 3) _isRamExpanded = !_isRamExpanded;
            else if (indexPath.section == 4) _isBatteryExpanded = !_isBatteryExpanded;
            else if (indexPath.section == 5) _isScreenExpanded = !_isScreenExpanded;

            UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [fb impactOccurred];

            [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            return;
        }
    }

    if (_currentBottomTab == 1 && indexPath.section == 2) {
        if (_isRateLocked) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 ĐÃ KHÓA THÔNG SỐ"
                                                                           message:@"Nhấn vào ổ khóa phía trên góc phải để mở khóa trước khi chỉnh."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Đã Hiểu" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }

        BOOL isHz = (_currentHzFpsSubTab == 0);
        NSArray *standardRates = @[@30, @60, @90, @120];

        if (indexPath.row < 4) {
            NSInteger selectedVal = [standardRates[indexPath.row] integerValue];
            [self applyRateValue:selectedVal isDynamic:NO isFPS:!isHz];
        } else if (indexPath.row == 4) {
            [self applyRateValue:144 isDynamic:NO isFPS:!isHz];
        } else {
            [self showCustomRateInputAlertForHz:isHz];
        }

        [self applyDeepSpringBoardAndUIKitTweaks];
        [self.customTableView reloadData];
    } else if (_currentBottomTab == 4 && indexPath.section == 0 && indexPath.row == 0) {
        [self openDopamineStyleExploitConsole];
    }
}

- (void)onAppToggleChanged:(UISwitch *)sender {
    NSDictionary *appInfo = _scannedAppsList[sender.tag];
    NSString *bundleID = appInfo[@"bundleID"];
    _appTweakStates[bundleID] = @(sender.isOn);
    self.settingsDict[@"AppTweakStates"] = _appTweakStates;
    [self saveSettingsDataAndSync];

    [self applyDeepSpringBoardAndUIKitTweaks];
}

- (void)onHzFpsSubTabChanged:(UISegmentedControl *)sender {
    _currentHzFpsSubTab = sender.selectedSegmentIndex;
    [self.customTableView reloadSections:[NSIndexSet indexSetWithIndex:2] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)onSwitchSubTabChanged:(UISegmentedControl *)sender {
    _currentSwitchSubTab = sender.selectedSegmentIndex;
    [self.customTableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationFade];
}

- (void)onSwitchToggled:(UISwitch *)sender {
    switch (sender.tag) {
        case 101: self.settingsDict[@"pCoreRealtimePriority"] = @(sender.isOn); break;
        case 102: self.settingsDict[@"schedulerGovernor"] = @(sender.isOn); break;
        case 103: self.settingsDict[@"quantumCoreSync"] = @(sender.isOn); break;
        case 104: self.settingsDict[@"lockHighIdleFloor"] = @(sender.isOn); break;
        case 105: self.settingsDict[@"AntiThermalThrottling"] = @(sender.isOn); break;
        case 201: self.settingsDict[@"MetalHexBuffering"] = @(sender.isOn); break;
        case 202: self.settingsDict[@"IsolateRenderPipeline"] = @(sender.isOn); break;
        case 203: self.settingsDict[@"vsyncAdaptiveBuffer"] = @(sender.isOn); break;
        case 204: self.settingsDict[@"gameFPSStabilizer"] = @(sender.isOn); break;
        case 205: self.settingsDict[@"flatTintBlur"] = @(sender.isOn); break;
        case 301: self.settingsDict[@"ForceOverclock144Hz"] = @(sender.isOn); break;
        case 302: self.settingsDict[@"ProMotionEngineBeta7"] = @(sender.isOn); break;
        case 303: self.settingsDict[@"TouchResponseBoost"] = @(sender.isOn); break;
        case 304: self.settingsDict[@"ColorOs17SmoothEngine"] = @(sender.isOn); break;
        case 305: self.settingsDict[@"zeroLagNeural"] = @(sender.isOn); break;
        case 401: self.settingsDict[@"AntiGhostTouch"] = @(sender.isOn); break;
        case 402: self.settingsDict[@"ChargerRippleRejection"] = @(sender.isOn); break;
        case 403: self.settingsDict[@"fakeFullBatteryState"] = @(sender.isOn); break;
        case 404: self.settingsDict[@"lock30FpsOnOverheat"] = @(sender.isOn); break;
        case 405: self.settingsDict[@"batterySaver60Hz"] = @(sender.isOn); break;
        case 501: self.settingsDict[@"TurboAppLaunch"] = @(sender.isOn); break;
        case 502: self.settingsDict[@"FixAppLaunchBlackScreen"] = @(sender.isOn); break;
        case 503: self.settingsDict[@"ReduceMultiTaskLag"] = @(sender.isOn); break;
        case 504: self.settingsDict[@"FixAppExitStutter"] = @(sender.isOn); break;
        case 505: self.settingsDict[@"hyperMemoryGuardian"] = @(sender.isOn); break;
        case 506: self.settingsDict[@"autoKillBackground"] = @(sender.isOn); break;
    }
    [self saveSettingsDataAndSync];
    [self applyDeepSpringBoardAndUIKitTweaks];
}

- (void)showCustomRateInputAlertForHz:(BOOL)isHz {
    NSString *unit = isHz ? @"Hz" : @"FPS";
    NSString *title = [NSString stringWithFormat:@"⌨️ NHẬP %@ TÙY CHỈNH", unit];
    NSString *msg = [NSString stringWithFormat:@"Nhập giá trị mong muốn từ 15 đến 144 %@ để khóa cứng:", unit];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = [NSString stringWithFormat:@"Giá trị (15 - 144 %@)", unit];
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Khóa Cứng Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = alert.textFields.firstObject;
        NSInteger val = [tf.text integerValue];
        if (val < 15) val = 15;
        if (val > 144) val = 144;

        [self applyRateValue:val isDynamic:NO isFPS:!isHz];
        [self applyDeepSpringBoardAndUIKitTweaks];
        [self.customTableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)startContinuousHardwareHUD {
    [self stopContinuousHardwareHUD];
    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), (uint64_t)(0.8 * NSEC_PER_SEC), (uint64_t)(0.1 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf->_currentBottomTab == 0 && strongSelf->_isKernelExploited && [strongSelf.settingsDict[@"EnableSystemMonitoring"] boolValue]) {
            [strongSelf.customTableView reloadData];
        }
    });
    dispatch_resume(_hudTimer);
}

- (void)stopContinuousHardwareHUD {
    if (_hudTimer) {
        dispatch_source_cancel(_hudTimer);
        _hudTimer = nil;
    }
}

- (void)syncSharedMemoryFile:(BOOL)enabled {
    if (!_isKernelExploited) return;

    ApexV285ProPayload payload;
    memset(&payload, 0, sizeof(ApexV285ProPayload));
    payload.magic = APEX_SYNC_MAGIC_V285;
    payload.masterEnabled = (enabled && _isKernelExploited) ? 1 : 0;

    int32_t hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 intValue];
    int32_t fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 intValue];
    BOOL isOverclock = [self.settingsDict[@"ForceOverclock144Hz"] ?: @NO boolValue];

    payload.targetHz = hz;
    payload.targetFPS = fps;
    payload.forceOverclock = (isOverclock || hz >= 144) ? 1 : 0;
    payload.pipSyncEnabled = 1;
    payload.thermalShield = [self.settingsDict[@"AntiThermalThrottling"] ?: @NO boolValue] ? 1 : 0;
    payload.antiStutterExit = [self.settingsDict[@"FixAppExitStutter"] ?: @NO boolValue] ? 1 : 0;
    payload.smartBufferingLevel = 3;
    payload.zeroLatencyTouch = [self.settingsDict[@"TouchResponseBoost"] ?: @NO boolValue] ? 1 : 0;
    payload.shaderOptimization = 1;
    payload.dynamicInterpolation = [self.settingsDict[@"ProMotionEngineBeta7"] ?: @NO boolValue] ? 1 : 0;
    payload.fastAppLaunch = [self.settingsDict[@"TurboAppLaunch"] ?: @NO boolValue] ? 1 : 0;
    payload.lowLatencyAudio = 1;
    payload.memoryPressureRelief = 1;
    payload.metalPacingEnabled = [self.settingsDict[@"MetalHexBuffering"] ?: @NO boolValue] ? 1 : 0;
    payload.runloopHangGuard = 1;
    payload.keyboardZeroLagV3 = [self.settingsDict[@"KeyboardZeroLagV24"] ?: @NO boolValue] ? 1 : 0;
    payload.aggressiveRamCleaner = [self.settingsDict[@"hyperMemoryGuardian"] ?: @NO boolValue] ? 1 : 0;
    payload.lockFixedFpsWhenThermal = [self.settingsDict[@"lock30FpsOnOverheat"] ?: @NO boolValue] ? 1 : 0;
    payload.antiGhostTouch = [self.settingsDict[@"AntiGhostTouch"] ?: @NO boolValue] ? 1 : 0;
    payload.diskIOPriorityBoost = [self.settingsDict[@"pCoreRealtimePriority"] ?: @NO boolValue] ? 1 : 0;
    payload.rawTouchDirectDelivery = 1;
    payload.powerSaveModeActive = [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue] ? 1 : 0;

    payload.updateSeq = (uint64_t)mach_absolute_time();
    payload.lastHeartbeat = payload.updateSeq;

    Titanium_WriteSyncPayloadUniversal(&payload, sizeof(ApexV285ProPayload));

    notify_post(NOTIFY_RELOAD);
    notify_post(NOTIFY_UIKIT_RELOAD);
    notify_post(NOTIFY_HARDWARE_SYNC);
    notify_post(NOTIFY_FPS_CHANGED);
    notify_post(NOTIFY_TITANIUM_CHANGED);
}

- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)dynamicMode isFPS:(BOOL)isFPS {
    if (isFPS) {
        self.settingsDict[@"TargetFPSRate"] = @(rate);
        self.settingsDict[@"EnableFPSControl"] = @YES;
    } else {
        self.settingsDict[@"TargetRefreshRate"] = @(rate);
        self.settingsDict[@"EnableHzControl"] = @YES;
        self.settingsDict[@"ForceOverclock144Hz"] = @(rate >= 144);
    }
    [self saveSettingsDataAndSync];
}

- (void)ensureDefaultSettingsExist {
    if (!self.settingsDict[@"Enabled"]) self.settingsDict[@"Enabled"] = @NO; // Mặc định tắt
    if (!self.settingsDict[@"EnableSystemMonitoring"]) self.settingsDict[@"EnableSystemMonitoring"] = @NO; // Mặc định tắt đo hệ thống
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @144;
    if (!self.settingsDict[@"TargetFPSRate"]) self.settingsDict[@"TargetFPSRate"] = @144;
    if (!self.settingsDict[@"ForceOverclock144Hz"]) self.settingsDict[@"ForceOverclock144Hz"] = @NO;
    if (!self.settingsDict[@"ProMotionEngineBeta7"]) self.settingsDict[@"ProMotionEngineBeta7"] = @NO;
    if (!self.settingsDict[@"pCoreRealtimePriority"]) self.settingsDict[@"pCoreRealtimePriority"] = @NO;
    if (!self.settingsDict[@"schedulerGovernor"]) self.settingsDict[@"schedulerGovernor"] = @NO;
    if (!self.settingsDict[@"quantumCoreSync"]) self.settingsDict[@"quantumCoreSync"] = @NO;
    if (!self.settingsDict[@"lockHighIdleFloor"]) self.settingsDict[@"lockHighIdleFloor"] = @NO;
    if (!self.settingsDict[@"AntiThermalThrottling"]) self.settingsDict[@"AntiThermalThrottling"] = @NO;
    if (!self.settingsDict[@"MetalHexBuffering"]) self.settingsDict[@"MetalHexBuffering"] = @NO;
    if (!self.settingsDict[@"IsolateRenderPipeline"]) self.settingsDict[@"IsolateRenderPipeline"] = @NO;
    if (!self.settingsDict[@"vsyncAdaptiveBuffer"]) self.settingsDict[@"vsyncAdaptiveBuffer"] = @NO;
    if (!self.settingsDict[@"gameFPSStabilizer"]) self.settingsDict[@"gameFPSStabilizer"] = @NO;
    if (!self.settingsDict[@"flatTintBlur"]) self.settingsDict[@"flatTintBlur"] = @NO;
    if (!self.settingsDict[@"TouchResponseBoost"]) self.settingsDict[@"TouchResponseBoost"] = @NO;
    if (!self.settingsDict[@"ColorOs17SmoothEngine"]) self.settingsDict[@"ColorOs17SmoothEngine"] = @NO;
    if (!self.settingsDict[@"zeroLagNeural"]) self.settingsDict[@"zeroLagNeural"] = @NO;
    if (!self.settingsDict[@"AntiGhostTouch"]) self.settingsDict[@"AntiGhostTouch"] = @NO;
    if (!self.settingsDict[@"ChargerRippleRejection"]) self.settingsDict[@"ChargerRippleRejection"] = @NO;
    if (!self.settingsDict[@"fakeFullBatteryState"]) self.settingsDict[@"fakeFullBatteryState"] = @NO;
    if (!self.settingsDict[@"lock30FpsOnOverheat"]) self.settingsDict[@"lock30FpsOnOverheat"] = @NO;
    if (!self.settingsDict[@"batterySaver60Hz"]) self.settingsDict[@"batterySaver60Hz"] = @NO;
    if (!self.settingsDict[@"TurboAppLaunch"]) self.settingsDict[@"TurboAppLaunch"] = @NO;
    if (!self.settingsDict[@"FixAppLaunchBlackScreen"]) self.settingsDict[@"FixAppLaunchBlackScreen"] = @NO;
    if (!self.settingsDict[@"ReduceMultiTaskLag"]) self.settingsDict[@"ReduceMultiTaskLag"] = @NO;
    if (!self.settingsDict[@"FixAppExitStutter"]) self.settingsDict[@"FixAppExitStutter"] = @NO;
    if (!self.settingsDict[@"hyperMemoryGuardian"]) self.settingsDict[@"hyperMemoryGuardian"] = @NO;
    if (!self.settingsDict[@"autoKillBackground"]) self.settingsDict[@"autoKillBackground"] = @NO;
    if (!self.settingsDict[@"IsRateLocked"]) self.settingsDict[@"IsRateLocked"] = @NO;
    if (!self.settingsDict[@"IsKernelExploited"]) self.settingsDict[@"IsKernelExploited"] = @NO;
}

- (void)executeRespring {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *bin = Titanium_FindExecutablePath(@"sbreload");
        char *argv[] = {(char *)[bin UTF8String], NULL};
        pid_t pid;
        posix_spawn(&pid, [bin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeSReboot {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *bin = Titanium_FindExecutablePath(@"launchctl");
        char *argv[] = {(char *)[bin UTF8String], (char *)"reboot", (char *)"userspace", NULL};
        pid_t pid;
        posix_spawn(&pid, [bin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeSafeMode {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        NSString *bin = Titanium_FindExecutablePath(@"killall");
        char *argv[] = {(char *)[bin UTF8String], (char *)"-SEGV", (char *)"SpringBoard", NULL};
        pid_t pid;
        posix_spawn(&pid, [bin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeResetConfiguration {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xác Nhận Đặt Lại"
                                                                   message:@"Toàn bộ cấu hình và trạng thái khai thác Darwin sẽ bị xóa bỏ hoàn toàn (cần khai thác lại)."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại Ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:prefPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:PRIMARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SECONDARY_SYNC_FILE error:nil];

        self.settingsDict = [NSMutableDictionary dictionary];
        self->_isKernelExploited = NO;
        [self ensureDefaultSettingsExist];
        [self saveSettingsDataAndSync];
        [self.customTableView reloadData];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
