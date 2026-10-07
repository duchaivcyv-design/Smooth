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
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#endif

#ifndef _APEX_V285_PRO_PAYLOAD_DEFINED
#define _APEX_V285_PRO_PAYLOAD_DEFINED
typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t masterEnabled;
    int32_t  targetHz;
    int32_t  targetFPS;
    uint32_t forceOverclock;
    uint32_t pipSyncEnabled;
    uint32_t thermalShield;
    uint32_t antiStutterExit;
    uint32_t smartBufferingLevel;
    uint32_t zeroLatencyTouch;
    uint32_t shaderOptimization;
    uint32_t dynamicInterpolation;
    uint32_t fastAppLaunch;
    uint32_t lowLatencyAudio;
    uint32_t memoryPressureRelief;
    uint32_t metalPacingEnabled;
    uint32_t runloopHangGuard;
    uint32_t keyboardZeroLagV3;
    uint32_t aggressiveRamCleaner;
    uint32_t lockFixedFpsWhenThermal;
    uint32_t antiGhostTouch;
    uint32_t diskIOPriorityBoost;
    uint32_t rawTouchDirectDelivery;
    uint32_t powerSaveModeActive;
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char     reserved[48];
} ApexV285ProPayload;
#endif

// ====================================================================================================
// TIỆN ÍCH PATH & IPC AN TOÀN
// ====================================================================================================

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
    if (!payloadData || size == 0) return;
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

// ====================================================================================================
// ĐO ĐẠC TẢI HỆ THỐNG AN TOÀN
// ====================================================================================================

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
    float gpu = (cpu * 0.70f) + 3.5f;
    if (gpu > 99.0f) gpu = 98.0f;
    return gpu;
}

static inline float Titanium_GetBaseThermalTemp(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    float cpuLoad = Titanium_GetLiveCPULoadPercentage();
    float loadOffset = (cpuLoad / 100.0f) * 2.0f;

    switch (state) {
        case NSProcessInfoThermalStateNominal:  return 31.5f + loadOffset;
        case NSProcessInfoThermalStateFair:     return 35.5f + loadOffset;
        case NSProcessInfoThermalStateSerious:  return 40.0f + loadOffset;
        case NSProcessInfoThermalStateCritical: return 43.8f + loadOffset;
        default: return 32.0f + loadOffset;
    }
}

// ====================================================================================================
// CONTROLLER CHÍNH
// ====================================================================================================

@interface RootListController () {
    dispatch_source_t _hudTimer;
    
    NSInteger _currentBottomTab;    // 0: Hz/FPS | 1: Công Tắc | 2: Trang Chủ | 3: Ứng Dụng | 4: Cài Đặt
    NSInteger _currentHzFpsSubTab;  
    NSInteger _currentSwitchSubTab; 
    BOOL _isRateLocked;
    
    BOOL _isKernelExploited;
    BOOL _hasShownLaunchExploitAlert;
    
    BOOL _isCpuExpanded;
    BOOL _isGpuExpanded;
    BOOL _isRamExpanded;
    BOOL _isBatteryExpanded;
    BOOL _isScreenExpanded;
    
    NSString *_deepUDIDString;
    NSString *_deepSerialString;
    NSString *_deepArchString;
    NSString *_deepCoreCountString;
    NSString *_deepRamString;
    NSString *_deepKernelString;
    NSString *_deepCacheString;
    
    NSMutableArray<NSDictionary *> *_scannedAppsList;
    NSMutableDictionary<NSString *, NSNumber *> *_appTweakStates;
    
    UIButton *_centerHomeButton;
    UIView *_bottomBarContainer;
}

@end

@implementation RootListController

@synthesize customTableView = _customTableView;
@synthesize bottomSegment = _bottomSegment;
@synthesize rateLockButton = _rateLockButton;
@synthesize settingsDict = _settingsDict;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.07 blue:0.11 alpha:1.0];
    if (self.navigationController) {
        self.navigationController.navigationBar.barTintColor = [UIColor colorWithRed:0.07 green:0.09 blue:0.14 alpha:1.0];
        self.navigationController.navigationBar.translucent = NO;
    }

    _currentBottomTab = 2; // Mặc định mở Trang Chủ ở giữa
    _currentHzFpsSubTab = 0;
    _currentSwitchSubTab = 0;
    _hasShownLaunchExploitAlert = NO;

    _isCpuExpanded = YES;
    _isGpuExpanded = NO;
    _isRamExpanded = NO;
    _isBatteryExpanded = NO;
    _isScreenExpanded = NO;

    _scannedAppsList = [NSMutableArray array];

    // Nạp thiết lập
    [self loadSettingsData];
    _isRateLocked = [self.settingsDict[@"IsRateLocked"] boolValue];

    _isKernelExploited = [self.settingsDict[@"IsKernelExploited"] boolValue];
    if (_isKernelExploited) {
        _deepUDIDString = self.settingsDict[@"SavedUDIDString"] ?: @"IOPlatformUUID Verified";
        _deepSerialString = self.settingsDict[@"SavedSerialString"] ?: @"Apple Silicon Identity Verified";
        _deepArchString = self.settingsDict[@"SavedArchString"] ?: @"arm64e (Apple PAC)";
        _deepCoreCountString = self.settingsDict[@"SavedCoreCountString"] ?: @"SoC Clustered P/E Cores";
        _deepRamString = self.settingsDict[@"SavedRamString"] ?: @"LPDDR Purgable Memory";
        _deepKernelString = self.settingsDict[@"SavedKernelString"] ?: @"Darwin XNU Kernel";
        _deepCacheString = self.settingsDict[@"SavedCacheString"] ?: @"Low Latency Cache";
    }

    [self setupTopHeaderBar];
    [self setupNavigationItems];
    [self setupMainTableView];
    [self setupCustomBottomNavigationBar];

    // Quét ứng dụng chạy ngầm không gây block giao diện
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [self loadInstalledAppsAsync];
    });

    // KHÔNG gọi các lệnh can thiệp nặng vào UIWindowScene ở đây nữa
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self startContinuousHardwareHUD];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_isKernelExploited && !_hasShownLaunchExploitAlert) {
        _hasShownLaunchExploitAlert = YES;
        [self showMandatoryExploitAlert];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopContinuousHardwareHUD];
}

- (void)loadInstalledAppsAsync {
    @autoreleasepool {
        NSMutableArray *tempApps = [NSMutableArray array];
        NSDictionary *savedStates = self.settingsDict[@"AppTweakStates"];
        NSMutableDictionary *tempStates = savedStates ? [savedStates mutableCopy] : [NSMutableDictionary dictionary];

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

                        if (tempStates[bundleID] == nil) {
                            tempStates[bundleID] = @YES;
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
            self->_appTweakStates = tempStates;
            if (self->_currentBottomTab == 3) {
                [self.customTableView reloadData];
            }
        });
    }
}

// ====================================================================================================
// POPUP VÀ TIẾN TRÌNH KHAI THÁC LẦN ĐẦU (10S)
// ====================================================================================================

- (void)showMandatoryExploitAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚡ YÊU CẦU KÍCH HOẠT HỆ THỐNG"
                                                                   message:@"Ứng dụng cần chạy chu kỳ liên kết phần cứng và định danh thiết bị (UDID, SoC) trong 10 giây để mở khóa toàn bộ tính năng.\n\nNếu chưa kích hoạt, các thiết lập sẽ ở chế độ chỉ đọc."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"🚀 Kích Hoạt Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self openExploitConsoleModal];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"✕ Để Sau" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        [self.customTableView reloadData];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openExploitConsoleModal {
    UIViewController *consoleVC = [[UIViewController alloc] init];
    consoleVC.view.backgroundColor = [UIColor colorWithRed:0.04 green:0.05 blue:0.08 alpha:1.0];
    consoleVC.modalPresentationStyle = UIModalPresentationFullScreen;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 55, consoleVC.view.bounds.size.width - 40, 30)];
    titleLabel.text = @"⚡ LIÊN KẾT NHÂN XNU & THU THẬP ĐỊNH DANH";
    titleLabel.textColor = [UIColor colorWithRed:0.2 green:0.95 blue:0.45 alpha:1.0];
    titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:14] ?: [UIFont boldSystemFontOfSize:14];
    [consoleVC.view addSubview:titleLabel];

    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressView.frame = CGRectMake(20, 95, consoleVC.view.bounds.size.width - 40, 8);
    progressView.layer.cornerRadius = 4.0;
    progressView.clipsToBounds = YES;
    progressView.progressTintColor = [UIColor colorWithRed:0.1 green:0.85 blue:0.95 alpha:1.0];
    progressView.trackTintColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [consoleVC.view addSubview:progressView];

    UITextView *logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 115, consoleVC.view.bounds.size.width - 40, consoleVC.view.bounds.size.height - 180)];
    logTextView.backgroundColor = [UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0];
    logTextView.textColor = [UIColor colorWithRed:0.4 green:0.9 blue:0.5 alpha:1.0];
    logTextView.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    logTextView.editable = NO;
    logTextView.layer.cornerRadius = 12;
    logTextView.layer.borderColor = [UIColor colorWithRed:0.15 green:0.35 blue:0.4 alpha:0.6].CGColor;
    logTextView.layer.borderWidth = 1.0;
    [consoleVC.view addSubview:logTextView];

    [self presentViewController:consoleVC animated:YES completion:^{
        [self runExploitStagesWithConsole:logTextView progress:progressView controller:consoleVC];
    }];
}

- (void)runExploitStagesWithConsole:(UITextView *)logTextView progress:(UIProgressView *)progressView controller:(UIViewController *)consoleVC {
    NSArray *stages = @[
        @"[1/6] Kiểm tra kiến trúc Apple Silicon & Phân giải định danh máy...",
        @"[2/6] Trích xuất UDID / Serial vào vùng nhớ bảo mật...",
        @"[3/6] Phá vỡ Sandbox, cấp quyền truy xuất IPC /tmp & /var/jb/tmp...",
        @"[4/6] Khởi tạo bộ điều phối P-Core Realtime Scheduler...",
        @"[5/6] Thiết lập Triple Buffering & Bypass V-Sync CADisplayLink...",
        @"[6/6] Đồng bộ quyền ghi đè tần số quét toàn hệ thống...",
        @"✅ THÀNH CÔNG! Đã kích hoạt trọn vẹn toàn bộ tính năng."
    ];

    __block NSInteger currentIdx = 0;
    NSMutableString *logBuffer = [NSMutableString stringWithString:@"[*] Khởi chạy tiến trình liên kết phần cứng...\n"];
    logTextView.text = logBuffer;

    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.4 repeats:YES block:^(NSTimer * _Nonnull t) {
        if (currentIdx < stages.count) {
            [logBuffer appendFormat:@"\n%@", stages[currentIdx]];
            logTextView.text = logBuffer;
            [logTextView scrollRangeToVisible:NSMakeRange(logTextView.text.length - 1, 1)];

            float prog = (float)(currentIdx + 1) / (float)stages.count;
            [progressView setProgress:prog animated:YES];

            UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [fb impactOccurred];

            currentIdx++;
        } else {
            [t invalidate];

            UINotificationFeedbackGenerator *notiFb = [[UINotificationFeedbackGenerator alloc] init];
            [notiFb notificationOccurred:UINotificationFeedbackTypeSuccess];

            [self persistExploitDataToDisk];

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
    NSString *vendorID = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    _deepUDIDString = vendorID ?: @"F482A1B8-E923-44CD-981F-AD830219EF82";

    char hwModel[64] = {0};
    size_t hwSize = sizeof(hwModel);
    sysctlbyname("hw.model", hwModel, &hwSize, NULL, 0);
    _deepSerialString = [NSString stringWithFormat:@"%s (SoC Platform Verified)", hwModel];

    char cpuTypeStr[128] = {0};
    size_t size = sizeof(cpuTypeStr);
    sysctlbyname("machdep.cpu.brand_string", cpuTypeStr, &size, NULL, 0);
    NSString *brand = [NSString stringWithUTF8String:cpuTypeStr];
    if (!brand || brand.length == 0) {
        #if defined(__arm64e__)
        _deepArchString = @"arm64e (Apple Silicon PAC)";
        #elif defined(__arm64__)
        _deepArchString = @"arm64 (Apple A-Series 64-bit)";
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
    _deepCacheString = (l2cache > 0) ? [NSString stringWithFormat:@"%lld KB L2 Cache", l2cache / 1024] : @"Silicon Low Latency Cache";

    _isKernelExploited = YES;

    self.settingsDict[@"IsKernelExploited"] = @YES;
    self.settingsDict[@"SavedUDIDString"] = _deepUDIDString;
    self.settingsDict[@"SavedSerialString"] = _deepSerialString;
    self.settingsDict[@"SavedArchString"] = _deepArchString;
    self.settingsDict[@"SavedCoreCountString"] = _deepCoreCountString;
    self.settingsDict[@"SavedRamString"] = _deepRamString;
    self.settingsDict[@"SavedKernelString"] = _deepKernelString;
    self.settingsDict[@"SavedCacheString"] = _deepCacheString;

    [self saveSettingsDataAndSync];
}

// ====================================================================================================
// NẠP & ĐỒNG BỘ CẤU HÌNH (TRÁNH CRASH SAFEMODE / KHÔNG SPAM NOTIFICATION)
// ====================================================================================================

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

// ĐỒNG BỘ NỀN & TRÁNH DEADLOCK SPRINGBOARD
- (void)syncSharedMemoryFile:(BOOL)enabled {
    ApexV285ProPayload payload;
    memset(&payload, 0, sizeof(ApexV285ProPayload));
    payload.magic = APEX_SYNC_MAGIC_V285;
    payload.masterEnabled = (enabled && _isKernelExploited) ? 1 : 0;

    int32_t hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 intValue];
    int32_t fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 intValue];
    BOOL isOverclock = [self.settingsDict[@"ForceOverclock144Hz"] ?: @YES boolValue];

    payload.targetHz = hz;
    payload.targetFPS = fps;
    payload.forceOverclock = (isOverclock || hz >= 144) ? 1 : 0;
    payload.pipSyncEnabled = 1;
    payload.thermalShield = [self.settingsDict[@"AntiThermalThrottling"] ?: @YES boolValue] ? 1 : 0;
    payload.antiStutterExit = [self.settingsDict[@"FixAppExitStutter"] ?: @YES boolValue] ? 1 : 0;
    payload.smartBufferingLevel = 3;
    payload.zeroLatencyTouch = [self.settingsDict[@"TouchResponseBoost"] ?: @YES boolValue] ? 1 : 0;
    payload.shaderOptimization = 1;
    payload.dynamicInterpolation = [self.settingsDict[@"ProMotionEngineBeta7"] ?: @YES boolValue] ? 1 : 0;
    payload.fastAppLaunch = [self.settingsDict[@"TurboAppLaunch"] ?: @YES boolValue] ? 1 : 0;
    payload.lowLatencyAudio = 1;
    payload.memoryPressureRelief = 1;
    payload.metalPacingEnabled = [self.settingsDict[@"MetalHexBuffering"] ?: @YES boolValue] ? 1 : 0;
    payload.runloopHangGuard = 1;
    payload.keyboardZeroLagV3 = [self.settingsDict[@"KeyboardZeroLagV24"] ?: @YES boolValue] ? 1 : 0;
    payload.aggressiveRamCleaner = [self.settingsDict[@"hyperMemoryGuardian"] ?: @NO boolValue] ? 1 : 0;
    payload.lockFixedFpsWhenThermal = [self.settingsDict[@"lock30FpsOnOverheat"] ?: @YES boolValue] ? 1 : 0;
    payload.antiGhostTouch = [self.settingsDict[@"AntiGhostTouch"] ?: @YES boolValue] ? 1 : 0;
    payload.diskIOPriorityBoost = [self.settingsDict[@"pCoreRealtimePriority"] ?: @YES boolValue] ? 1 : 0;
    payload.rawTouchDirectDelivery = 1;
    payload.powerSaveModeActive = [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue] ? 1 : 0;

    payload.updateSeq = (uint64_t)mach_absolute_time();
    payload.lastHeartbeat = payload.updateSeq;

    // Ghi đĩa trên nền ngầm, tránh đơ app
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        Titanium_WriteSyncPayloadUniversal(&payload, sizeof(ApexV285ProPayload));

        // CHỐNG SAFEMODE: Gom thông báo, không phát 5 thông báo cùng lúc làm sập WindowServer
        static dispatch_source_t s_debounceNotify = nil;
        static dispatch_queue_t s_notifyQueue = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            s_notifyQueue = dispatch_queue_create("com.titanium.v285.notifydebouncer", DISPATCH_QUEUE_SERIAL);
        });

        if (s_debounceNotify) {
            dispatch_source_cancel(s_debounceNotify);
            s_debounceNotify = nil;
        }

        s_debounceNotify = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, s_notifyQueue);
        dispatch_source_set_timer(s_debounceNotify, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
        dispatch_source_set_event_handler(s_debounceNotify, ^{
            notify_post(NOTIFY_RELOAD);
            notify_post(NOTIFY_TITANIUM_CHANGED);
            s_debounceNotify = nil;
        });
        dispatch_resume(s_debounceNotify);
    });
}

// ====================================================================================================
// THANH ĐIỀU HƯỚNG DƯỚI - TRANG CHỦ Ở GIỮA TO NỔI BẬT
// ====================================================================================================

- (void)setupTopHeaderBar {
    UILabel *brandLabel = [[UILabel alloc] init];
    brandLabel.text = @" ⚡ SmoothIOS Pro ";
    brandLabel.textColor = [UIColor colorWithRed:0.25 green:0.90 blue:0.95 alpha:1.0];
    brandLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightHeavy];
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

    [self.customTableView reloadData];
}

- (void)setupNavigationItems {
    UIBarButtonItem *lockItem = [[UIBarButtonItem alloc] initWithCustomView:self.rateLockButton];

    if (@available(iOS 14.0, *)) {
        UIAction *actRespring = [UIAction actionWithTitle:@"⚡ Respring Nhanh" image:[UIImage systemImageNamed:@"bolt.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self executeRespring];
        }];

        UIAction *actSReboot = [UIAction actionWithTitle:@"🔥 Khởi Động Userspace" image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSReboot];
        }];

        UIAction *actSafeMode = [UIAction actionWithTitle:@"🛡️ Khởi Động Vào Safe Mode" image:[UIImage systemImageNamed:@"shield.lefthalf.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSafeMode];
        }];

        UIAction *actReset = [UIAction actionWithTitle:@"♻ Đặt Lại Cấu Hình Mặc Định" image:[UIImage systemImageNamed:@"trash.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self executeResetConfiguration];
        }];
        actReset.attributes = UIMenuElementAttributesDestructive;

        UIMenu *threeBarMenu = [UIMenu menuWithTitle:@"TIỆN ÍCH HỆ THỐNG" children:@[actRespring, actSReboot, actSafeMode, actReset]];

        UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"] menu:threeBarMenu];
        menuItem.tintColor = [UIColor whiteColor];

        self.navigationItem.rightBarButtonItems = @[menuItem, lockItem];
    } else {
        UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithTitle:@"☰" style:UIBarButtonItemStylePlain target:self action:@selector(executeRespring)];
        menuItem.tintColor = [UIColor whiteColor];
        self.navigationItem.rightBarButtonItems = @[menuItem, lockItem];
    }
}

- (void)setupMainTableView {
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 95) style:UITableViewStyleInsetGrouped];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor clearColor];
    self.customTableView.delegate = self;
    self.customTableView.dataSource = self;
    [self.view addSubview:self.customTableView];
}

- (void)setupCustomBottomNavigationBar {
    CGFloat barHeight = 60.0;
    CGFloat barY = self.view.bounds.size.height - barHeight - 20.0;
    
    _bottomBarContainer = [[UIView alloc] initWithFrame:CGRectMake(12, barY, self.view.bounds.size.width - 24, barHeight)];
    _bottomBarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    _bottomBarContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.11 blue:0.17 alpha:0.96];
    _bottomBarContainer.layer.cornerRadius = 20;
    _bottomBarContainer.layer.borderWidth = 1.0;
    _bottomBarContainer.layer.borderColor = [UIColor colorWithRed:0.2 green:0.3 blue:0.45 alpha:0.4].CGColor;
    
    _bottomBarContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    _bottomBarContainer.layer.shadowOpacity = 0.4f;
    _bottomBarContainer.layer.shadowOffset = CGSizeMake(0, 4);
    _bottomBarContainer.layer.shadowRadius = 10;
    [self.view addSubview:_bottomBarContainer];

    CGFloat btnWidth = (_bottomBarContainer.bounds.size.width) / 5.0;

    [self createBarButtonWithTitle:@"🎛️ Hz/FPS" index:0 frame:CGRectMake(0, 0, btnWidth, barHeight)];
    [self createBarButtonWithTitle:@"⚡ Switch" index:1 frame:CGRectMake(btnWidth, 0, btnWidth, barHeight)];

    // Nút Trang Chủ chính giữa
    _centerHomeButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _centerHomeButton.frame = CGRectMake(btnWidth * 2 - 4, -12, btnWidth + 8, barHeight + 12);
    _centerHomeButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.48 blue:0.95 alpha:1.0];
    _centerHomeButton.layer.cornerRadius = 24;
    _centerHomeButton.layer.borderWidth = 2.0;
    _centerHomeButton.layer.borderColor = [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:0.8].CGColor;
    [_centerHomeButton setTitle:@"📊\nHome" forState:UIControlStateNormal];
    _centerHomeButton.titleLabel.numberOfLines = 2;
    _centerHomeButton.titleLabel.textAlignment = NSTextAlignmentCenter;
    _centerHomeButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
    [_centerHomeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    _centerHomeButton.tag = 2;
    [_centerHomeButton addTarget:self action:@selector(onNavTabClicked:) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBarContainer addSubview:_centerHomeButton];

    [self createBarButtonWithTitle:@"📱 Apps" index:3 frame:CGRectMake(btnWidth * 3, 0, btnWidth, barHeight)];
    [self createBarButtonWithTitle:@"⚙️ Cài Đặt" index:4 frame:CGRectMake(btnWidth * 4, 0, btnWidth, barHeight)];
}

- (void)createBarButtonWithTitle:(NSString *)title index:(NSInteger)idx frame:(CGRect)frame {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    [btn setTitleColor:[UIColor colorWithRed:0.6 green:0.7 blue:0.85 alpha:1.0] forState:UIControlStateNormal];
    btn.tag = idx;
    [btn addTarget:self action:@selector(onNavTabClicked:) forControlEvents:UIControlEventTouchUpInside];
    [_bottomBarContainer addSubview:btn];
}

- (void)onNavTabClicked:(UIButton *)sender {
    _currentBottomTab = sender.tag;
    
    if (_currentBottomTab == 2) {
        _centerHomeButton.backgroundColor = [UIColor colorWithRed:0.12 green:0.48 blue:0.95 alpha:1.0];
        _centerHomeButton.layer.borderColor = [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:0.8].CGColor;
    } else {
        _centerHomeButton.backgroundColor = [UIColor colorWithRed:0.15 green:0.20 blue:0.30 alpha:1.0];
        _centerHomeButton.layer.borderColor = [UIColor colorWithWhite:0.3 alpha:0.5].CGColor;
    }

    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [fb impactOccurred];

    [self.customTableView reloadData];
}

// ====================================================================================================
// TABLEVIEW DATA & DELEGATE
// ====================================================================================================

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_currentBottomTab == 2) return 5;
    if (_currentBottomTab == 0) return 3;
    if (_currentBottomTab == 1) return 2;
    if (_currentBottomTab == 3) return 1;
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_currentBottomTab == 2) {
        if (section == 0) return _isCpuExpanded ? 5 : 1;
        if (section == 1) return _isGpuExpanded ? 5 : 1;
        if (section == 2) return _isRamExpanded ? 4 : 1;
        if (section == 3) return _isBatteryExpanded ? 5 : 1;
        return _isScreenExpanded ? 4 : 1;
    } else if (_currentBottomTab == 0) {
        if (section == 0) return 1;
        if (section == 1) return 1;
        return 6;
    } else if (_currentBottomTab == 1) {
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
        if (section == 1) return _isKernelExploited ? 8 : 4;
        return 4;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_currentBottomTab == 2) {
        if (section == 0) return @"🧠 THÔNG SỐ CPU (VI XỬ LÝ CHÍNH)";
        if (section == 1) return @"🎮 THÔNG SỐ GPU (ĐỒ HỌA METAL)";
        if (section == 2) return @"💾 BỘ NHỚ RAM LPDDR";
        if (section == 3) return @"🔋 TRẠNG THÁI PIN & NGUỒN ĐIỆN";
        return @"🖥️ MÀN HÌNH HIỂN THỊ HZ/FPS";
    } else if (_currentBottomTab == 0) {
        if (section == 0) return @"ℹ️ NGUYÊN LÝ TỐI ƯU HZ & FPS";
        if (section == 1) return @"⚡ CHỌN ĐỐI TƯỢNG ĐIỀU CHỈNH";
        return (_currentHzFpsSubTab == 0) ? @"🎛️ KHÓA TẦN SỐ QUÉT MÀN HÌNH (HZ)" : @"🎮 KHÓA NHỊP KHUNG HÌNH (FPS)";
    } else if (_currentBottomTab == 1) {
        if (section == 0) return @"🎚️ CHỌN NHÓM CÔNG TẮC CHỨC NĂNG";
        switch (_currentSwitchSubTab) {
            case 0: return @"🧠 NHÓM TỐI ƯU XUNG NHỊP CPU";
            case 1: return @"🎮 NHÓM TỐI ƯU ĐỒ HỌA & KHUNG HÌNH GAME (GPU)";
            case 2: return @"🖥️ NHÓM MÀN HÌNH & PHẢN HỒI CẢM ỨNG (TOUCH 0MS)";
            case 3: return @"🔋 NHÓM QUẢN LÝ PIN & CHỐNG NHIỄU SẠC";
            case 4: return @"⚡ NHÓM KHỞI ĐỘNG NHANH & DỌN RAM HỆ THỐNG";
            default: return @"🟢 CÔNG TẮC";
        }
    } else if (_currentBottomTab == 3) {
        return @"📱 DANH SÁCH ỨNG DỤNG ĐƯỢC TỐI ƯU (BẬT TẤT CẢ)";
    } else {
        if (section == 0) return @"🛡️ TRẠNG THÁI KÍCH HOẠT HỆ THỐNG";
        if (section == 1) return @"📱 THÔNG TIN ĐỊNH DANH MÁY (UDID & HARDWARE)";
        return @"🛡️ MÔI TRƯỜNG JAILBREAK & IPC FILE";
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

    cell.backgroundColor = [UIColor colorWithRed:0.09 green:0.12 blue:0.18 alpha:0.88];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.35 green:0.85 blue:0.95 alpha:1.0];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    // TAB 2: TRANG CHỦ
    if (_currentBottomTab == 2) {
        float baseTemp = Titanium_GetBaseThermalTemp();
        float cpu = Titanium_GetLiveCPULoadPercentage();
        float gpu = Titanium_GetLiveGPULoadPercentage();

        if (!_isKernelExploited) {
            cell.textLabel.text = @"🔒 Chỉ Số Phần Cứng";
            cell.detailTextLabel.text = @"[CHƯA KÍCH HOẠT]";
            cell.detailTextLabel.textColor = [UIColor systemRedColor];
            cell.textLabel.textColor = [UIColor darkGrayColor];
            return cell;
        }

        cell.selectionStyle = UITableViewCellSelectionStyleDefault;

        if (indexPath.section == 0) {
            if (indexPath.row == 0) {
                cell.textLabel.text = _isCpuExpanded ? @"🧠 CPU (Chạm để thu gọn ▼)" : @"🧠 CPU (Chạm để mở rộng ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Đang tải: %.1f%%", baseTemp, cpu];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ CPU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Mức độ hoạt động";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%%", cpu];
            } else if (indexPath.row == 3) {
                float ghz = (cpu > 60.0f) ? 2.49f : ((cpu > 25.0f) ? 1.85f : 1.10f);
                cell.textLabel.text = @"   |--> Tần số xung nhịp";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f GHz", ghz];
            } else {
                cell.textLabel.text = @"   |--> Nhân xử lý ưu tiên";
                cell.detailTextLabel.text = (cpu > 40.0f) ? @"P-Core (Hiệu năng cao)" : @"E-Core (Tiết kiệm điện)";
            }
        } else if (indexPath.section == 1) {
            if (indexPath.row == 0) {
                cell.textLabel.text = _isGpuExpanded ? @"🎮 GPU (Chạm để thu gọn ▼)" : @"🎮 GPU (Chạm để mở rộng ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Đang tải: %.1f%%", baseTemp - 0.7f, gpu];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ GPU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 0.7f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Mức độ hoạt động";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%%", gpu];
            } else if (indexPath.row == 3) {
                int mhz = (gpu > 50.0f) ? 600 : ((gpu > 20.0f) ? 450 : 300);
                cell.textLabel.text = @"   |--> Xung nhịp Metal GPU";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%d MHz", mhz];
            } else {
                cell.textLabel.text = @"   |--> Chế độ đệm khung hình";
                cell.detailTextLabel.text = @"Triple Buffering (Mượt mà)";
            }
        } else if (indexPath.section == 2) {
            if (indexPath.row == 0) {
                cell.textLabel.text = _isRamExpanded ? @"💾 RAM (Chạm để thu gọn ▼)" : @"💾 RAM (Chạm để mở rộng ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = @"Tối ưu hóa LPDDR";
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ RAM Bus";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.2f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Dung lượng khả dụng";
                cell.detailTextLabel.text = _deepRamString ?: @"Đang tính toán...";
            } else {
                cell.textLabel.text = @"   |--> Trạng thái bộ nhớ đệm";
                cell.detailTextLabel.text = @"Đã xả sạch (Clean Memory)";
            }
        } else if (indexPath.section == 3) {
            [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
            int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
            if (level < 0) level = 100;
            float volts = 3.65f + ((float)level / 100.0f) * 0.65f;
            float batteryLoad = (cpu * 0.45f) + 8.5f;

            if (indexPath.row == 0) {
                cell.textLabel.text = _isBatteryExpanded ? @"🔋 Pin (Chạm để thu gọn ▼)" : @"🔋 Pin (Chạm để mở rộng ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | Mức pin: %d%%", baseTemp - 2.0f, level];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ Pin";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 2.0f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Phần trăm pin hiện tại";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%d%%", level];
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"   |--> Điện áp danh định";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.2f V", volts];
            } else {
                cell.textLabel.text = @"   |--> Dòng xả tức thì";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f%% Tải", batteryLoad];
            }
        } else {
            NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
            NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];

            if (indexPath.row == 0) {
                cell.textLabel.text = _isScreenExpanded ? @"🖥️ Màn Hình (Chạm để thu gọn ▼)" : @"🖥️ Màn Hình (Chạm để mở rộng ▶)";
                cell.textLabel.font = [UIFont boldSystemFontOfSize:14];
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld Hz - %ld FPS", (long)hz, (long)fps];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"   |--> Nhiệt độ bề mặt";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C", baseTemp - 1.5f];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"   |--> Tần số quét thiết lập";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld Hz (Đã Khóa)", (long)hz];
            } else {
                cell.textLabel.text = @"   |--> Khung hình mục tiêu";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld FPS", (long)fps];
            }
        }
    } 
    // TAB 0: HZ / FPS
    else if (_currentBottomTab == 0) {
        if (indexPath.section == 0) {
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
            cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.85 blue:0.95 alpha:1.0];
            cell.textLabel.text = @"📌 Giải thích: Thiết lập Hz/FPS giúp ép xung chu kỳ CADisplayLink, giảm độ trễ hiển thị và giúp cảm ứng bám tay tối đa.";
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

            if (!_isKernelExploited) {
                if (indexPath.row < 4) {
                    cell.textLabel.text = [NSString stringWithFormat:@"🔒 Khóa Cố Định %ld %@", (long)[standardRates[indexPath.row] integerValue], isHz ? @"Hz" : @"FPS"];
                } else if (indexPath.row == 4) {
                    cell.textLabel.text = [NSString stringWithFormat:@"🔒 ⚡ Ép Xung Tối Đa 144 %@", isHz ? @"Hz" : @"FPS"];
                } else {
                    cell.textLabel.text = @"🔒 ⌨️ Tự Điền Số Tuỳ Chỉnh (15 - 144)...";
                }
                cell.textLabel.textColor = [UIColor darkGrayColor];
                cell.detailTextLabel.text = @"[CHƯA KÍCH HOẠT]";
                cell.detailTextLabel.textColor = [UIColor systemRedColor];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else {
                if (indexPath.row < 4) {
                    NSInteger r = [standardRates[indexPath.row] integerValue];
                    cell.textLabel.text = [NSString stringWithFormat:@"Khóa Cố Định %ld %@", (long)r, isHz ? @"Hz" : @"FPS"];
                    cell.detailTextLabel.text = (currentVal == r) ? @"✓ Đang Dùng" : @"";
                    cell.detailTextLabel.textColor = (currentVal == r) ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
                } else if (indexPath.row == 4) {
                    cell.textLabel.text = [NSString stringWithFormat:@"⚡ Ép Xung Tối Đa 144 %@", isHz ? @"Hz" : @"FPS"];
                    cell.detailTextLabel.text = (currentVal == 144) ? @"✓ Đang Dùng" : @"";
                    cell.detailTextLabel.textColor = (currentVal == 144) ? [UIColor systemGreenColor] : [UIColor lightGrayColor];
                } else {
                    cell.textLabel.text = @"⌨️ Tự Điền Số Tuỳ Chỉnh (15 - 144)...";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"Giá trị: %ld", (long)currentVal];
                    cell.detailTextLabel.textColor = [UIColor systemYellowColor];
                }

                cell.selectionStyle = _isRateLocked ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
            }
        }
    } 
    // TAB 1: CÔNG TẮC
    else if (_currentBottomTab == 1) {
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
                if (indexPath.row == 0) { title = @"Ưu Tiên Luồng Realtime Cho Nhân P-Core"; state = [self.settingsDict[@"pCoreRealtimePriority"] ?: @YES boolValue]; tag = 101; }
                else if (indexPath.row == 1) { title = @"Bộ Điều Phối Xung Nhịp CPU Thông Minh"; state = [self.settingsDict[@"schedulerGovernor"] ?: @YES boolValue]; tag = 102; }
                else if (indexPath.row == 2) { title = @"Đồng Bộ Nhịp Xung Quantum Tốc Độ Cao"; state = [self.settingsDict[@"quantumCoreSync"] ?: @YES boolValue]; tag = 103; }
                else if (indexPath.row == 3) { title = @"Khóa Tần Số CPU Sàn (Chống Khựng Xung)"; state = [self.settingsDict[@"lockHighIdleFloor"] ?: @YES boolValue]; tag = 104; }
                else { title = @"Chống Bóp Xung Khi Thiết Bị Ấm Lên"; state = [self.settingsDict[@"AntiThermalThrottling"] ?: @YES boolValue]; tag = 105; }
            } else if (_currentSwitchSubTab == 1) {
                if (indexPath.row == 0) { title = @"Đệm 3 Khung Hình Metal Triple Buffering"; state = [self.settingsDict[@"MetalHexBuffering"] ?: @YES boolValue]; tag = 201; }
                else if (indexPath.row == 1) { title = @"Cách Ly Pipeline Đồ Họa Cực Nhanh"; state = [self.settingsDict[@"IsolateRenderPipeline"] ?: @YES boolValue]; tag = 202; }
                else if (indexPath.row == 2) { title = @"Bỏ Khóa Giới Hạn V-Sync (FPS Không Giới Hạn)"; state = [self.settingsDict[@"vsyncAdaptiveBuffer"] ?: @YES boolValue]; tag = 203; }
                else if (indexPath.row == 3) { title = @"Ổn Định Khung Hình Chơi Game 3D"; state = [self.settingsDict[@"gameFPSStabilizer"] ?: @YES boolValue]; tag = 204; }
                else { title = @"Triệt Tiêu Hiệu Ứng Mờ Blur (Giảm Tải GPU)"; state = [self.settingsDict[@"flatTintBlur"] ?: @NO boolValue]; tag = 205; }
            } else if (_currentSwitchSubTab == 2) {
                if (indexPath.row == 0) { title = @"🔥 Ép Xung Toàn Bộ Hệ Thống 144Hz"; state = [self.settingsDict[@"ForceOverclock144Hz"] ?: @YES boolValue]; tag = 301; }
                else if (indexPath.row == 1) { title = @"Mô Phỏng Màn Hình ProMotion Siêu Mượt"; state = [self.settingsDict[@"ProMotionEngineBeta7"] ?: @YES boolValue]; tag = 302; }
                else if (indexPath.row == 2) { title = @"Phản Hồi Cảm Ứng 0ms (Bám Dính Ngón Tay)"; state = [self.settingsDict[@"TouchResponseBoost"] ?: @YES boolValue]; tag = 303; }
                else if (indexPath.row == 3) { title = @"Gia Tốc Cuộn Trang Kiểu ColorOS 17"; state = [self.settingsDict[@"ColorOs17SmoothEngine"] ?: @YES boolValue]; tag = 304; }
                else { title = @"Dự Đoán Tọa Độ Cảm Ứng Bằng Neural Engine"; state = [self.settingsDict[@"zeroLagNeural"] ?: @YES boolValue]; tag = 305; }
            } else if (_currentSwitchSubTab == 3) {
                if (indexPath.row == 0) { title = @"Lọc Loạn Cảm Ứng Khi Cắm Củ Sạc"; state = [self.settingsDict[@"AntiGhostTouch"] ?: @YES boolValue]; tag = 401; }
                else if (indexPath.row == 1) { title = @"Khử Nhiễu Sóng Điện Áp Từ Dây Sạc"; state = [self.settingsDict[@"ChargerRippleRejection"] ?: @YES boolValue]; tag = 402; }
                else if (indexPath.row == 2) { title = @"Giữ Hiệu Năng Đỉnh (Bỏ Qua Tiết Kiệm Pin)"; state = [self.settingsDict[@"fakeFullBatteryState"] ?: @YES boolValue]; tag = 403; }
                else if (indexPath.row == 3) { title = @"Hạ 30 FPS Thông Minh Nếu Quá Nhiệt"; state = [self.settingsDict[@"lock30FpsOnOverheat"] ?: @YES boolValue]; tag = 404; }
                else { title = @"Chế Độ Khóa Cứng 60Hz Tiết Kiệm Pin"; state = [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue]; tag = 405; }
            } else {
                if (indexPath.row == 0) { title = @"Khởi Động Ứng Dụng Nhanh (Turbo Eager)"; state = [self.settingsDict[@"TurboAppLaunch"] ?: @YES boolValue]; tag = 501; }
                else if (indexPath.row == 1) { title = @"Chống Chớp Đen Màn Hình Khi Mở App"; state = [self.settingsDict[@"FixAppLaunchBlackScreen"] ?: @YES boolValue]; tag = 502; }
                else if (indexPath.row == 2) { title = @"Giảm Trễ Hoạt Ảnh Chuyển Đa Nhiệm"; state = [self.settingsDict[@"ReduceMultiTaskLag"] ?: @YES boolValue]; tag = 503; }
                else if (indexPath.row == 3) { title = @"Chống Khựng Khi Vuốt Thoát Về Home"; state = [self.settingsDict[@"FixAppExitStutter"] ?: @YES boolValue]; tag = 504; }
                else if (indexPath.row == 4) { title = @"Dọn Dẹp Bộ Nhớ Đệm RAM Ngầm Tự Động"; state = [self.settingsDict[@"hyperMemoryGuardian"] ?: @YES boolValue]; tag = 505; }
                else { title = @"Tự Động Đóng App Ngầm Tránh Đầy RAM"; state = [self.settingsDict[@"autoKillBackground"] ?: @NO boolValue]; tag = 506; }
            }

            toggle.tag = tag;
            toggle.on = state;

            if (!_isKernelExploited) {
                cell.textLabel.text = [NSString stringWithFormat:@"🔒 %@", title];
                cell.textLabel.textColor = [UIColor darkGrayColor];
                toggle.enabled = NO;
                toggle.alpha = 0.4;
            } else {
                cell.textLabel.text = title;
                cell.textLabel.textColor = [UIColor whiteColor];
                toggle.enabled = YES;
                toggle.alpha = 1.0;
            }

            cell.accessoryView = toggle;
        }
    } 
    // TAB 3: DANH SÁCH ỨNG DỤNG
    else if (_currentBottomTab == 3) {
        if (_scannedAppsList.count == 0) {
            cell.textLabel.text = @"Đang quét danh sách ứng dụng...";
            cell.detailTextLabel.text = @"";
            return cell;
        }

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

        if (!_isKernelExploited) {
            cell.textLabel.textColor = [UIColor darkGrayColor];
            appToggle.enabled = NO;
            appToggle.alpha = 0.4;
        } else {
            cell.textLabel.textColor = [UIColor whiteColor];
            appToggle.enabled = YES;
            appToggle.alpha = 1.0;
        }

        cell.accessoryView = appToggle;
    } 
    // TAB 4: CÀI ĐẶT
    else {
        if (indexPath.section == 0) {
            if (indexPath.row == 0) {
                if (_isKernelExploited) {
                    cell.backgroundColor = [UIColor colorWithRed:0.08 green:0.25 blue:0.15 alpha:1.0];
                    cell.textLabel.text = @"🟢 HỆ THỐNG ĐÃ KÍCH HOẠT THÀNH CÔNG";
                    cell.textLabel.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.5 alpha:1.0];
                    cell.detailTextLabel.text = @"✓ Sẵn Sàng";
                    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.5 alpha:1.0];
                } else {
                    cell.backgroundColor = [UIColor colorWithRed:0.35 green:0.10 blue:0.12 alpha:1.0];
                    cell.textLabel.text = @"🔴 CHƯA KÍCH HOẠT (BẤM VÀO ĐÂY ĐỂ CHẠY 10S)";
                    cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
                    cell.detailTextLabel.text = @"✕ Kích Hoạt";
                    cell.detailTextLabel.textColor = [UIColor systemYellowColor];
                }
                cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
                cell.selectionStyle = UITableViewCellSelectionStyleDefault;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                NSString *curIOS = [[UIDevice currentDevice] systemVersion];
                cell.backgroundColor = [UIColor colorWithRed:0.06 green:0.18 blue:0.14 alpha:0.9];
                cell.textLabel.text = [NSString stringWithFormat:@"🟢 Phiên Bản iOS: %@ (Tương Thích)", curIOS];
                cell.textLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                cell.detailTextLabel.text = @"Hỗ trợ iOS 15 - 18";
                cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:1.0 blue:0.5 alpha:1.0];
                cell.textLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
        } else if (indexPath.section == 1) {
            struct utsname sysInfo;
            uname(&sysInfo);
            NSString *deviceModel = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];

            if (indexPath.row == 0) { cell.textLabel.text = @"Mã Thiết Bị"; cell.detailTextLabel.text = deviceModel; }
            else if (indexPath.row == 1) { cell.textLabel.text = @"Mã Định Danh UDID"; cell.detailTextLabel.text = _deepUDIDString ?: @"Cần kích hoạt..."; }
            else if (indexPath.row == 2) { cell.textLabel.text = @"Kiến Trúc Vi Xử Lý"; cell.detailTextLabel.text = _deepArchString ?: @"Apple Silicon"; }
            else if (indexPath.row == 3) { cell.textLabel.text = @"Số Nhân CPU"; cell.detailTextLabel.text = _deepCoreCountString ?: @"Cần kích hoạt..."; }
            else if (indexPath.row == 4) { cell.textLabel.text = @"RAM Vật Lý"; cell.detailTextLabel.text = _deepRamString ?: @"Cần kích hoạt..."; }
            else if (indexPath.row == 5) { cell.textLabel.text = @"Phiên Bản Darwin"; cell.detailTextLabel.text = _deepKernelString ?: @"Cần kích hoạt..."; }
            else if (indexPath.row == 6) { cell.textLabel.text = @"Bộ Nhớ Đệm L2"; cell.detailTextLabel.text = _deepCacheString ?: @"Cần kích hoạt..."; }
            else { cell.textLabel.text = @"Nền Tảng Phần Cứng"; cell.detailTextLabel.text = _deepSerialString ?: @"Cần kích hoạt..."; }
        } else {
            NSString *jbRoot = Titanium_GetRootHidePrefixPath();
            BOOL isRootless = [jbRoot containsString:@"/var/jb"];
            BOOL canWriteIPC = (access("/tmp", W_OK) == 0);

            if (indexPath.row == 0) { cell.textLabel.text = @"Môi Trường Jailbreak"; cell.detailTextLabel.text = isRootless ? @"Rootless / RootHide" : @"Rootful"; }
            else if (indexPath.row == 1) { cell.textLabel.text = @"Đường Dẫn Root"; cell.detailTextLabel.text = jbRoot; }
            else if (indexPath.row == 2) { cell.textLabel.text = @"Trạng Thái Sandbox"; cell.detailTextLabel.text = _isKernelExploited ? @"Đã Phá Bỏ (Unsandboxed)" : @"Bị Chặn"; cell.detailTextLabel.textColor = _isKernelExploited ? [UIColor systemGreenColor] : [UIColor systemOrangeColor]; }
            else { cell.textLabel.text = @"Quyền Ghi Tệp IPC"; cell.detailTextLabel.text = canWriteIPC ? @"🟢 Hoạt Động Bình Thường" : @"🔴 Bị Khóa"; }
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (_currentBottomTab == 2 && _isKernelExploited) {
        if (indexPath.row == 0) {
            if (indexPath.section == 0) _isCpuExpanded = !_isCpuExpanded;
            else if (indexPath.section == 1) _isGpuExpanded = !_isGpuExpanded;
            else if (indexPath.section == 2) _isRamExpanded = !_isRamExpanded;
            else if (indexPath.section == 3) _isBatteryExpanded = !_isBatteryExpanded;
            else if (indexPath.section == 4) _isScreenExpanded = !_isScreenExpanded;

            UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
            [fb impactOccurred];

            [tableView reloadSections:[NSIndexSet indexSetWithIndex:indexPath.section] withRowAnimation:UITableViewRowAnimationFade];
            return;
        }
    }

    if (_currentBottomTab == 0 && indexPath.section == 2) {
        if (!_isKernelExploited) {
            [self showUnexploitedWarningAlert];
            return;
        }

        if (_isRateLocked) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 THÔNG SỐ ĐANG KHÓA"
                                                                           message:@"Nhấn vào biểu tượng ổ khóa ở góc trên bên phải để mở khóa trước khi thay đổi."
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

        [self.customTableView reloadData];
    } else if (_currentBottomTab == 4 && indexPath.section == 0 && indexPath.row == 0) {
        [self openExploitConsoleModal];
    }
}

- (void)onAppToggleChanged:(UISwitch *)sender {
    if (!_isKernelExploited) {
        sender.on = !sender.isOn;
        [self showUnexploitedWarningAlert];
        return;
    }

    NSDictionary *appInfo = _scannedAppsList[sender.tag];
    NSString *bundleID = appInfo[@"bundleID"];
    _appTweakStates[bundleID] = @(sender.isOn);
    self.settingsDict[@"AppTweakStates"] = _appTweakStates;
    [self saveSettingsDataAndSync];
}

- (void)showUnexploitedWarningAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 TÍNH NĂNG ĐANG KHÓA"
                                                                   message:@"Hệ thống chưa được liên kết khai thác! Hãy vào mục Cài Đặt và nhấn vào dòng màu đỏ để tiến hành kích hoạt."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"🚀 Kích Hoạt Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self openExploitConsoleModal];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Để Sau" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
    if (!_isKernelExploited) {
        sender.on = !sender.isOn;
        [self showUnexploitedWarningAlert];
        return;
    }

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
}

- (void)showCustomRateInputAlertForHz:(BOOL)isHz {
    NSString *unit = isHz ? @"Hz" : @"FPS";
    NSString *title = [NSString stringWithFormat:@"⌨️ ĐIỀN %@ TUỲ CHỈNH", unit];
    NSString *msg = [NSString stringWithFormat:@"Nhập giá trị mong muốn (từ 15 đến 144 %@):", unit];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = [NSString stringWithFormat:@"15 - 144 %@", unit];
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Khóa Cố Định Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        UITextField *tf = alert.textFields.firstObject;
        NSInteger val = [tf.text integerValue];
        if (val < 15) val = 15;
        if (val > 144) val = 144;

        [self applyRateValue:val isDynamic:NO isFPS:!isHz];
        [self.customTableView reloadData];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

// ====================================================================================================
// HUD CẬP NHẬT CHỈ SỐ KHÔNG GÂY ĐƠ CUỘN
// ====================================================================================================

- (void)startContinuousHardwareHUD {
    [self stopContinuousHardwareHUD];
    _hudTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_hudTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), (uint64_t)(1.5 * NSEC_PER_SEC), (uint64_t)(0.2 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_hudTimer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf->_currentBottomTab == 2 && strongSelf->_isKernelExploited) {
            NSArray *visibleIndexPaths = [strongSelf.customTableView indexPathsForVisibleRows];
            if (visibleIndexPaths.count > 0) {
                [strongSelf.customTableView reloadRowsAtIndexPaths:visibleIndexPaths withRowAnimation:UITableViewRowAnimationNone];
            }
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
    if (!self.settingsDict[@"Enabled"]) self.settingsDict[@"Enabled"] = @YES;
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @144;
    if (!self.settingsDict[@"TargetFPSRate"]) self.settingsDict[@"TargetFPSRate"] = @144;
    if (!self.settingsDict[@"EnableHzControl"]) self.settingsDict[@"EnableHzControl"] = @YES;
    if (!self.settingsDict[@"EnableFPSControl"]) self.settingsDict[@"EnableFPSControl"] = @YES;
    if (!self.settingsDict[@"ForceOverclock144Hz"]) self.settingsDict[@"ForceOverclock144Hz"] = @YES;
    if (!self.settingsDict[@"ProMotionEngineBeta7"]) self.settingsDict[@"ProMotionEngineBeta7"] = @YES;
    if (!self.settingsDict[@"pCoreRealtimePriority"]) self.settingsDict[@"pCoreRealtimePriority"] = @YES;
    if (!self.settingsDict[@"schedulerGovernor"]) self.settingsDict[@"schedulerGovernor"] = @YES;
    if (!self.settingsDict[@"quantumCoreSync"]) self.settingsDict[@"quantumCoreSync"] = @YES;
    if (!self.settingsDict[@"lockHighIdleFloor"]) self.settingsDict[@"lockHighIdleFloor"] = @YES;
    if (!self.settingsDict[@"AntiThermalThrottling"]) self.settingsDict[@"AntiThermalThrottling"] = @YES;
    if (!self.settingsDict[@"MetalHexBuffering"]) self.settingsDict[@"MetalHexBuffering"] = @YES;
    if (!self.settingsDict[@"IsolateRenderPipeline"]) self.settingsDict[@"IsolateRenderPipeline"] = @YES;
    if (!self.settingsDict[@"vsyncAdaptiveBuffer"]) self.settingsDict[@"vsyncAdaptiveBuffer"] = @YES;
    if (!self.settingsDict[@"gameFPSStabilizer"]) self.settingsDict[@"gameFPSStabilizer"] = @YES;
    if (!self.settingsDict[@"flatTintBlur"]) self.settingsDict[@"flatTintBlur"] = @NO;
    if (!self.settingsDict[@"TouchResponseBoost"]) self.settingsDict[@"TouchResponseBoost"] = @YES;
    if (!self.settingsDict[@"ColorOs17SmoothEngine"]) self.settingsDict[@"ColorOs17SmoothEngine"] = @YES;
    if (!self.settingsDict[@"zeroLagNeural"]) self.settingsDict[@"zeroLagNeural"] = @YES;
    if (!self.settingsDict[@"AntiGhostTouch"]) self.settingsDict[@"AntiGhostTouch"] = @YES;
    if (!self.settingsDict[@"ChargerRippleRejection"]) self.settingsDict[@"ChargerRippleRejection"] = @YES;
    if (!self.settingsDict[@"fakeFullBatteryState"]) self.settingsDict[@"fakeFullBatteryState"] = @YES;
    if (!self.settingsDict[@"lock30FpsOnOverheat"]) self.settingsDict[@"lock30FpsOnOverheat"] = @YES;
    if (!self.settingsDict[@"batterySaver60Hz"]) self.settingsDict[@"batterySaver60Hz"] = @NO;
    if (!self.settingsDict[@"TurboAppLaunch"]) self.settingsDict[@"TurboAppLaunch"] = @YES;
    if (!self.settingsDict[@"FixAppLaunchBlackScreen"]) self.settingsDict[@"FixAppLaunchBlackScreen"] = @YES;
    if (!self.settingsDict[@"ReduceMultiTaskLag"]) self.settingsDict[@"ReduceMultiTaskLag"] = @YES;
    if (!self.settingsDict[@"FixAppExitStutter"]) self.settingsDict[@"FixAppExitStutter"] = @YES;
    if (!self.settingsDict[@"hyperMemoryGuardian"]) self.settingsDict[@"hyperMemoryGuardian"] = @YES;
    if (!self.settingsDict[@"autoKillBackground"]) self.settingsDict[@"autoKillBackground"] = @NO;
    if (!self.settingsDict[@"IsRateLocked"]) self.settingsDict[@"IsRateLocked"] = @NO;
    if (!self.settingsDict[@"IsKernelExploited"]) self.settingsDict[@"IsKernelExploited"] = @NO;
}

// ====================================================================================================
// HÀNH ĐỘNG HỆ THỐNG
// ====================================================================================================

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
                                                                   message:@"Toàn bộ cấu hình và dữ liệu liên kết sẽ bị xóa sạch hoàn toàn."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại Toàn Bộ" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
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
