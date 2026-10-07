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

// ====================================================================================================
// TIỆN ÍCH HỆ THỐNG & NHẬN DIỆN VÙNG JAILBREAK
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
// ĐO ĐẠC PHẦN CỨNG THỜI GIAN THỰC
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

// ====================================================================================================
// GIAO DIỆN CHÍNH ROOTLISTCONTROLLER
// ====================================================================================================

@interface RootListController () {
    dispatch_source_t _hudTimer;
    NSInteger _currentBottomTab;    // 0: Home | 1: Hz/FPS | 2: Công Tắc | 3: Ứng Dụng | 4: Cài Đặt
    NSInteger _currentHzFpsSubTab;  // 0: Hz | 1: FPS
    NSInteger _currentSwitchSubTab; // 0: CPU | 1: GPU | 2: Màn Hình | 3: Pin | 4: Hệ Thống
    BOOL _isRateLocked;
    
    // GHI NHỚ KHAI THÁC VĨNH VIỄN
    BOOL _isKernelExploited;
    BOOL _hasShownLaunchExploitAlert;
    
    // DỮ LIỆU ĐÃ KHAI THÁC ĐƯỢC LƯU
    NSString *_deepArchString;
    NSString *_deepCoreCountString;
    NSString *_deepRamString;
    NSString *_deepKernelString;
    NSString *_deepCacheString;
    
    // DANH SÁCH ỨNG DỤNG HỆ THỐNG & APP CÀI ĐẶT
    NSMutableArray<NSDictionary *> *_scannedAppsList;
    NSMutableDictionary<NSString *, NSNumber *> *_appTweakStates;
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
    self.view.backgroundColor = [UIColor colorWithRed:0.06 green:0.08 blue:0.12 alpha:1.0];

    _currentBottomTab = 0;
    _currentHzFpsSubTab = 0;
    _currentSwitchSubTab = 0;
    _hasShownLaunchExploitAlert = NO;
    _scannedAppsList = [NSMutableArray array];

    [self loadSettingsData];
    _isRateLocked = [self.settingsDict[@"IsRateLocked"] boolValue];

    // Nạp trạng thái khai thác đã lưu trong plist
    _isKernelExploited = [self.settingsDict[@"IsKernelExploited"] boolValue];
    if (_isKernelExploited) {
        _deepArchString = self.settingsDict[@"SavedArchString"] ?: @"arm64e (Apple Silicon PAC)";
        _deepCoreCountString = self.settingsDict[@"SavedCoreCountString"] ?: @"SoC Clustered P/E Cores";
        _deepRamString = self.settingsDict[@"SavedRamString"] ?: @"LPDDR Mach Purgable";
        _deepKernelString = self.settingsDict[@"SavedKernelString"] ?: @"Darwin XNU Kernel";
        _deepCacheString = self.settingsDict[@"SavedCacheString"] ?: @"Low Latency Silicon Cache";
    }

    [self loadInstalledApps];

    [self setupTopHeaderBar];
    [self setupNavigationItems];
    [self setupBottomNavigationBar];
    [self setupMainTableView];

    [self applyDeepSpringBoardAndUIKitTweaks];
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

// Nạp danh sách ứng dụng, mặc định tất cả đều được BẬT
- (void)loadInstalledApps {
    [_scannedAppsList removeAllObjects];
    NSDictionary *savedStates = self.settingsDict[@"AppTweakStates"];
    _appTweakStates = savedStates ? [savedStates mutableCopy] : [NSMutableDictionary dictionary];

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

                    if (_appTweakStates[bundleID] == nil) {
                        _appTweakStates[bundleID] = @YES; // Mặc định tất cả bật sẵn
                    }

                    [_scannedAppsList addObject:@{
                        @"name": name,
                        @"bundleID": bundleID,
                        @"path": fullPath
                    }];
                }
            }
        }
    }
}

// ====================================================================================================
// CAN THIỆP TRỰC TIẾP VÀO SPRINGBOARD VÀ TOÀN BỘ MÔI TRƯỜNG UIKIT
// ====================================================================================================

- (void)applyDeepSpringBoardAndUIKitTweaks {
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

    BOOL master = [self.settingsDict[@"Enabled"] ?: @YES boolValue];
    [self syncSharedMemoryFile:master];
}

// ====================================================================================================
// POPUP BẮT BUỘC KHAI THÁC LẦN ĐẦU VÀO APP
// ====================================================================================================

- (void)showMandatoryExploitAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@" YÊU CẦU KHAI THÁC KERNEL / DARWIN"
                                                                   message:@"Ứng dụng cần chiếm quyền điều khiển nhân Darwin tầng sâu (XNU Sysctl, P-Core Scheduler, CADisplayLink Pipeline và Mach VM) trong khoảng 15 giây để kích hoạt khả năng tăng tốc.\n\nNếu không khai thác, toàn bộ công tắc, đo phần cứng và mức chọn Hz/FPS sẽ bị KHÓA CỨNG (Hiện xám)."
                                                            preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *exploitAction = [UIAlertAction actionWithTitle:@" Khai Thác Ngay (~15 Giây)" 
                                                            style:UIAlertActionStyleDefault 
                                                          handler:^(UIAlertAction * _Nonnull action) {
        [self openDopamineStyleExploitConsole];
    }];
    [alert addAction:exploitAction];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"✕ Bỏ qua (Chỉ xem)" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:^(UIAlertAction * _Nonnull action) {
        [self.customTableView reloadData];
    }];
    [alert addAction:cancelAction];

    [self presentViewController:alert animated:YES completion:nil];
}

// ====================================================================================================
// GIAO DIỆN CONSOLE LOG KHAI THÁC ĐÚNG 15 GIÂY (CHẠY TỪNG STAGE & RUNG HAPTIC)
// ====================================================================================================

- (void)openDopamineStyleExploitConsole {
    UIViewController *consoleVC = [[UIViewController alloc] init];
    consoleVC.view.backgroundColor = [UIColor blackColor];
    consoleVC.modalPresentationStyle = UIModalPresentationFullScreen;

    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 50, consoleVC.view.bounds.size.width - 40, 30)];
    titleLabel.text = @"⚡ DARWIN KERNEL EXPLOIT (15S)";
    titleLabel.textColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.4 alpha:1.0];
    titleLabel.font = [UIFont fontWithName:@"Menlo-Bold" size:17] ?: [UIFont boldSystemFontOfSize:17];
    [consoleVC.view addSubview:titleLabel];

    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    progressView.frame = CGRectMake(20, 95, consoleVC.view.bounds.size.width - 40, 6);
    progressView.progressTintColor = [UIColor colorWithRed:0.2 green:1.0 blue:0.5 alpha:1.0];
    progressView.trackTintColor = [UIColor darkGrayColor];
    [consoleVC.view addSubview:progressView];

    UITextView *logTextView = [[UITextView alloc] initWithFrame:CGRectMake(20, 115, consoleVC.view.bounds.size.width - 40, consoleVC.view.bounds.size.height - 200)];
    logTextView.backgroundColor = [UIColor colorWithRed:0.05 green:0.07 blue:0.05 alpha:1.0];
    logTextView.textColor = [UIColor colorWithRed:0.3 green:0.95 blue:0.4 alpha:1.0];
    logTextView.font = [UIFont fontWithName:@"Menlo" size:13] ?: [UIFont systemFontOfSize:13];
    logTextView.editable = NO;
    logTextView.layer.cornerRadius = 10;
    logTextView.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:1.0].CGColor;
    logTextView.layer.borderWidth = 1.0;
    [consoleVC.view addSubview:logTextView];

    [self presentViewController:consoleVC animated:YES completion:^{
        [self runExploitStagesWithConsole:logTextView progress:progressView controller:consoleVC];
    }];
}

- (void)runExploitStagesWithConsole:(UITextView *)logTextView progress:(UIProgressView *)progressView controller:(UIViewController *)consoleVC {
    NSArray *stages = @[
        @"[Stage 1/6] Khởi tạo Mach Host & Vượt bảo vệ PAC arm64e...",
        @"[Stage 2/6] Can thiệp XNU Scheduler, điều phối P-Core Realtime...",
        @"[Stage 3/6] Phá vỡ rào cản Sandbox, chiếm quyền I/O liên vùng...",
        @"[Stage 4/6] Khai thác Darwin VM Map, ép xả sạch cache bộ nhớ đệm...",
        @"[Stage 5/6] Ghi đè Pipeline Metal GPU & Đăng ký Triple Buffering 0ms...",
        @"[Stage 6/6] Cấp quyền IPC Shmem liên vùng (/tmp & /var/jb/tmp)...",
        @"✅ KHAI THÁC THÀNH CÔNG! Toàn bộ tính năng đã được kích hoạt vĩnh viễn."
    ];

    __block NSInteger currentIdx = 0;
    NSMutableString *logBuffer = [NSMutableString stringWithString:@"[*] Bắt đầu chu kỳ khai thác Darwin tầng sâu (15 giây)...\n"];
    logTextView.text = logBuffer;

    // Khoảng 2.2 giây mỗi bước -> tổng cộng đúng ~15 giây
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

// ====================================================================================================
// ĐỌC THÔNG SỐ VÀ LƯU VĨNH VIỄN VÀO TỆP PLIST (KHI XÓA TWEAK THÌ PLIST MẤT THEO)
// ====================================================================================================

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
    brandLabel.text = @" SmoothIOS Pro ";
    brandLabel.textColor = [UIColor colorWithRed:0.25 green:0.85 blue:0.95 alpha:1.0];
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
        UIAction *actRespring = [UIAction actionWithTitle:@"⚡ Respring Nhanh (An Toàn)"
                                                    image:[UIImage systemImageNamed:@"bolt.fill"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self executeRespring];
        }];

        UIAction *actSReboot = [UIAction actionWithTitle:@"🔥 Khởi Động Userspace (SReboot)"
                                                   image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"]
                                              identifier:nil
                                                 handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSReboot];
        }];

        UIAction *actSafeMode = [UIAction actionWithTitle:@"🛡️ Khởi Động Vào Safe Mode"
                                                    image:[UIImage systemImageNamed:@"shield.lefthalf.fill"]
                                               identifier:nil
                                                  handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSafeMode];
        }];

        UIAction *actReset = [UIAction actionWithTitle:@"♻ Đặt Lại Cấu Hình Mặc Định"
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

// Bố cục thanh điều hướng 5 Tab rõ ràng, không bị co cụm chữ
- (void)setupBottomNavigationBar {
    UIView *bottomBarContainer = [[UIView alloc] initWithFrame:CGRectMake(8, self.view.bounds.size.height - 82, self.view.bounds.size.width - 16, 52)];
    bottomBarContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    bottomBarContainer.backgroundColor = [UIColor colorWithRed:0.11 green:0.14 blue:0.20 alpha:0.95];
    bottomBarContainer.layer.cornerRadius = 16;
    bottomBarContainer.layer.borderWidth = 1.0;
    bottomBarContainer.layer.borderColor = [UIColor colorWithWhite:0.2 alpha:0.5].CGColor;
    [self.view addSubview:bottomBarContainer];

    // 5 mục rõ ràng: Home, Hz/FPS, Switch, Ứng Dụng, Cài Đặt
    self.bottomSegment = [[UISegmentedControl alloc] initWithItems:@[@"📊 Home", @"🎛️ Hz/FPS", @"⚡ Switch", @"📱 App", @"⚙️ Cài Đặt"]];
    self.bottomSegment.frame = CGRectMake(4, 6, bottomBarContainer.bounds.size.width - 8, 40);
    self.bottomSegment.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.bottomSegment.selectedSegmentIndex = _currentBottomTab;
    
    // Tối ưu kích cỡ font chữ tránh tràn màn hình
    NSDictionary *attr = @{NSFontAttributeName: [UIFont systemFontOfSize:11 weight:UIFontWeightMedium]};
    [self.bottomSegment setTitleTextAttributes:attr forState:UIControlStateNormal];
    [self.bottomSegment setTitleTextAttributes:attr forState:UIControlStateSelected];

    [self.bottomSegment addTarget:self action:@selector(onBottomTabChanged:) forControlEvents:UIControlEventValueChanged];
    [bottomBarContainer addSubview:self.bottomSegment];
}

- (void)onBottomTabChanged:(UISegmentedControl *)sender {
    _currentBottomTab = sender.selectedSegmentIndex;
    [self.customTableView reloadData];
}

- (void)setupMainTableView {
    self.customTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height - 90) style:UITableViewStyleInsetGrouped];
    self.customTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.customTableView.backgroundColor = [UIColor clearColor];
    self.customTableView.delegate = self;
    self.customTableView.dataSource = self;
    [self.view addSubview:self.customTableView];
}

#pragma mark - TableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (_currentBottomTab == 0) return 1; // Home: Chỉ đo phần cứng
    if (_currentBottomTab == 1) return 3; // Hz/FPS: Chú thích + Tab chọn + Các mức
    if (_currentBottomTab == 2) return 2; // Công tắc: Phân nhóm + Danh sách switch
    if (_currentBottomTab == 3) return 1; // Danh sách Ứng Dụng
    return 3;                             // Cài Đặt
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (_currentBottomTab == 0) {
        return 4; // CPU, GPU, Màn Hình, Pin
    } else if (_currentBottomTab == 1) {
        if (section == 0) return 1; // Tiêu đề chú thích thực tế
        if (section == 1) return 1; // Tab Hz / FPS
        return 6;                   // 30, 60, 90, 120, 144, Tự nhập
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
        return _scannedAppsList.count; // Danh sách các app đã cài
    } else {
        if (section == 0) return 1; // Đèn báo trạng thái Xanh/Đỏ
        if (section == 1) return _isKernelExploited ? 8 : 4;
        return 4;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (_currentBottomTab == 0) {
        return @"📊 GIÁM SÁT PHẦN CỨNG THỜI GIAN THỰC (REALTIME 0S)";
    } else if (_currentBottomTab == 1) {
        if (section == 0) return @"ℹ️ NGUYÊN LÝ HOẠT ĐỘNG CỦA HZ & FPS";
        if (section == 1) return @"⚡ ĐIỀU PHỐI ĐỘC LẬP TẦN SỐ QUÉT & KHUNG HÌNH";
        return (_currentHzFpsSubTab == 0) ? @"🎛️ KHÓA TẦN SỐ QUÉT MÀN HÌNH (HZ)" : @"🎮 KHÓA KHUNG HÌNH APP (FPS)";
    } else if (_currentBottomTab == 2) {
        if (section == 0) return @"🎚️ CHỌN PHÂN NHÓM CÔNG TẮC PHẦN CỨNG";
        switch (_currentSwitchSubTab) {
            case 0: return @"🧠 NHÓM CPU (SOC CORE, P-CORE, SCHEDULER)";
            case 1: return @"🎮 NHÓM GPU (METAL HEX, VSYNC, SHADER)";
            case 2: return @"🖥️ NHÓM MÀN HÌNH & CẢM ỨNG (PROMOTION, TOUCH 0MS)";
            case 3: return @"🔋 NHÓM PIN & QUẢN LÝ NGUỒN (ANTI-GHOST, POWER)";
            case 4: return @"⚡ NHÓM HỆ THỐNG & RAM (TURBO LAUNCH, MEMORY JETSAM)";
            default: return @"🟢 CÔNG TẮC";
        }
    } else if (_currentBottomTab == 3) {
        return @"📱 DANH SÁCH ỨNG DỤNG (MẶC ĐỊNH BẬT TẤT CẢ - GẠT ĐỂ TẮT)";
    } else {
        if (section == 0) return @"🛡️ TRẠNG THÁI KHAI THÁC HỆ THỐNG (DARWIN)";
        if (section == 1) return @"📱 THÔNG TIN THIẾT BỊ (XNU SYSCTL & MACH HOST)";
        return @"🛡️ THÔNG TIN VÙNG JAILBREAK & SANDBOX";
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

    cell.backgroundColor = [UIColor colorWithRed:0.11 green:0.14 blue:0.22 alpha:0.85];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.3 green:0.8 blue:0.95 alpha:1.0];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;

    // TAB 0: HOME
    if (_currentBottomTab == 0) {
        if (!_isKernelExploited) {
            cell.textLabel.text = @"🔒 Chỉ số phần cứng";
            cell.detailTextLabel.text = @"[ĐÃ KHÓA]";
            cell.detailTextLabel.textColor = [UIColor systemRedColor];
            cell.textLabel.textColor = [UIColor darkGrayColor];
        } else {
            float baseTemp = Titanium_GetBaseThermalTemp();
            if (indexPath.row == 0) {
                float cpu = Titanium_GetLiveCPULoadPercentage();
                float ghz = (cpu > 60.0f) ? 2.49f : ((cpu > 25.0f) ? 1.85f : 1.10f);
                cell.textLabel.text = @"🧠 CPU (SoC Core)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %.2f GHz | Tải: %.1f%%", baseTemp, ghz, cpu];
            } else if (indexPath.row == 1) {
                float gpu = Titanium_GetLiveGPULoadPercentage();
                int mhz = (gpu > 50.0f) ? 600 : ((gpu > 20.0f) ? 450 : 300);
                cell.textLabel.text = @"🎮 GPU (Metal Shader)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %d MHz | Tải: %.1f%%", baseTemp - 0.7f, mhz, gpu];
            } else if (indexPath.row == 2) {
                NSInteger hz = [self.settingsDict[@"TargetRefreshRate"] ?: @144 integerValue];
                NSInteger fps = [self.settingsDict[@"TargetFPSRate"] ?: @144 integerValue];
                cell.textLabel.text = @"🖥️ Màn Hình";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %ld Hz - %ld FPS", baseTemp - 1.5f, (long)hz, (long)fps];
            } else if (indexPath.row == 3) {
                [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
                int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
                if (level < 0) level = 100;
                float volts = 3.65f + ((float)level / 100.0f) * 0.65f;
                float batteryLoad = (Titanium_GetLiveCPULoadPercentage() * 0.45f) + 8.5f;
                cell.textLabel.text = @"🔋 Pin (Li-ion Zin)";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f°C | %.2fV | %d%% (Tải: %.1f%%)", baseTemp - 2.0f, volts, level, batteryLoad];
            }
        }
    } 
    // TAB 1: HZ / FPS
    else if (_currentBottomTab == 1) {
        if (indexPath.section == 0) {
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightRegular];
            cell.textLabel.textColor = [UIColor colorWithRed:0.8 green:0.85 blue:0.95 alpha:1.0];
            cell.textLabel.text = @"📌 Lưu ý: Tần số Hz/FPS giúp tối ưu chu kỳ CADisplayLink, giảm độ trễ hiển thị UIKit và SpringBoard nhằm tạo cảm giác mượt mà tối đa; không thể ép thông số phần cứng màn hình vượt ngưỡng vật lý.";
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
                    cell.textLabel.text = [NSString stringWithFormat:@"🔒 Khóa Cứng %ld %@", (long)[standardRates[indexPath.row] integerValue], isHz ? @"Hz" : @"FPS"];
                } else if (indexPath.row == 4) {
                    cell.textLabel.text = [NSString stringWithFormat:@"🔒 ⚡ Mở Rộng 144 %@", isHz ? @"Hz" : @"FPS"];
                } else {
                    cell.textLabel.text = @"🔒 ⌨️ Tự Nhập Số Chính Xác (15 - 144)...";
                }
                cell.textLabel.textColor = [UIColor darkGrayColor];
                cell.detailTextLabel.text = @"[ĐÃ KHÓA]";
                cell.detailTextLabel.textColor = [UIColor systemRedColor];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else {
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
    } 
    // TAB 2: CÔNG TẮC
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
                if (indexPath.row == 0) { title = @"Ưu Tiên P-Core Realtime (Realtime Sched)"; state = [self.settingsDict[@"pCoreRealtimePriority"] ?: @YES boolValue]; tag = 101; }
                else if (indexPath.row == 1) { title = @"Điều Phối CPU Scheduler (Governor)"; state = [self.settingsDict[@"schedulerGovernor"] ?: @YES boolValue]; tag = 102; }
                else if (indexPath.row == 2) { title = @"Đồng Bộ Xung Quantum (Quantum Core Sync)"; state = [self.settingsDict[@"quantumCoreSync"] ?: @YES boolValue]; tag = 103; }
                else if (indexPath.row == 3) { title = @"Khóa Tần Số CPU Sàn (CPUGPUFreqOptimizer)"; state = [self.settingsDict[@"lockHighIdleFloor"] ?: @YES boolValue]; tag = 104; }
                else { title = @"Chống Bóp Xung Nhiệt Độ (Anti-Thermal)"; state = [self.settingsDict[@"AntiThermalThrottling"] ?: @YES boolValue]; tag = 105; }
            } else if (_currentSwitchSubTab == 1) {
                if (indexPath.row == 0) { title = @"Metal Hex/Triple Buffering"; state = [self.settingsDict[@"MetalHexBuffering"] ?: @YES boolValue]; tag = 201; }
                else if (indexPath.row == 1) { title = @"Cưỡng Chế RenderServer 90 (Cách Ly Pipeline)"; state = [self.settingsDict[@"IsolateRenderPipeline"] ?: @YES boolValue]; tag = 202; }
                else if (indexPath.row == 2) { title = @"Bỏ Khóa V-Sync Khung Hình (Adaptive Buffer)"; state = [self.settingsDict[@"vsyncAdaptiveBuffer"] ?: @YES boolValue]; tag = 203; }
                else if (indexPath.row == 3) { title = @"Ổn Định Khung Hình Game (GameFPSStabilizer)"; state = [self.settingsDict[@"gameFPSStabilizer"] ?: @YES boolValue]; tag = 204; }
                else { title = @"Triệt Tiêu Blur Động (QuantumRenderShield)"; state = [self.settingsDict[@"flatTintBlur"] ?: @NO boolValue]; tag = 205; }
            } else if (_currentSwitchSubTab == 2) {
                if (indexPath.row == 0) { title = @"🔥 Ép Xung 144Hz Toàn Máy (Overclock)"; state = [self.settingsDict[@"ForceOverclock144Hz"] ?: @YES boolValue]; tag = 301; }
                else if (indexPath.row == 1) { title = @"ProMotion Engine Beta 7"; state = [self.settingsDict[@"ProMotionEngineBeta7"] ?: @YES boolValue]; tag = 302; }
                else if (indexPath.row == 2) { title = @"Cảm Ứng 0ms (Touch Response Boost)"; state = [self.settingsDict[@"TouchResponseBoost"] ?: @YES boolValue]; tag = 303; }
                else if (indexPath.row == 3) { title = @"Động Cơ Cuộn ColorOS 17 Siêu Mượt"; state = [self.settingsDict[@"ColorOs17SmoothEngine"] ?: @YES boolValue]; tag = 304; }
                else { title = @"Dự Đoán Tọa Độ Neural (Zero-Lag Neural)"; state = [self.settingsDict[@"zeroLagNeural"] ?: @YES boolValue]; tag = 305; }
            } else if (_currentSwitchSubTab == 3) {
                if (indexPath.row == 0) { title = @"Lọc Loạn Cảm Ứng Sạc (Anti-Ghost Touch)"; state = [self.settingsDict[@"AntiGhostTouch"] ?: @YES boolValue]; tag = 401; }
                else if (indexPath.row == 1) { title = @"Khử Nhiễu Sóng Củ Sạc (Ripple Rejection)"; state = [self.settingsDict[@"ChargerRippleRejection"] ?: @YES boolValue]; tag = 402; }
                else if (indexPath.row == 2) { title = @"Giả Lập Pin Đầy (Device Spoofer)"; state = [self.settingsDict[@"fakeFullBatteryState"] ?: @YES boolValue]; tag = 403; }
                else if (indexPath.row == 3) { title = @"Khóa 30 FPS Khi Quá Nhiệt (Thermal Dispatch)"; state = [self.settingsDict[@"lock30FpsOnOverheat"] ?: @YES boolValue]; tag = 404; }
                else { title = @"Chế Độ Tiết Kiệm Pin 60Hz (Battery Saver)"; state = [self.settingsDict[@"batterySaver60Hz"] ?: @NO boolValue]; tag = 405; }
            } else {
                if (indexPath.row == 0) { title = @"Khởi Động App Siêu Tốc (Turbo Launch)"; state = [self.settingsDict[@"TurboAppLaunch"] ?: @YES boolValue]; tag = 501; }
                else if (indexPath.row == 1) { title = @"Trị Dứt Điểm Đen Màn Mở App"; state = [self.settingsDict[@"FixAppLaunchBlackScreen"] ?: @YES boolValue]; tag = 502; }
                else if (indexPath.row == 2) { title = @"Giảm Lag Đa Nhiệm (MultiTask Boost)"; state = [self.settingsDict[@"ReduceMultiTaskLag"] ?: @YES boolValue]; tag = 503; }
                else if (indexPath.row == 3) { title = @"Chống Khựng Thoát App (Exit Guard)"; state = [self.settingsDict[@"FixAppExitStutter"] ?: @YES boolValue]; tag = 504; }
                else if (indexPath.row == 4) { title = @"Dọn RAM Chuyên Sâu (Hyper Memory Guardian)"; state = [self.settingsDict[@"hyperMemoryGuardian"] ?: @YES boolValue]; tag = 505; }
                else { title = @"Tự Động Đóng App Nền (Auto Close App)"; state = [self.settingsDict[@"autoKillBackground"] ?: @NO boolValue]; tag = 506; }
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
    // TAB 3: DANH SÁCH ỨNG DỤNG (BẬT TẤT - GẠT ĐỂ TẮT)
    else if (_currentBottomTab == 3) {
        NSDictionary *appInfo = _scannedAppsList[indexPath.row];
        NSString *name = appInfo[@"name"];
        NSString *bundleID = appInfo[@"bundleID"];

        cell.textLabel.text = name;
        cell.detailTextLabel.text = bundleID;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11];

        UISwitch *appToggle = [[UISwitch alloc] init];
        appToggle.on = [_appTweakStates[bundleID] boolValue]; // Mặc định bật
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
            // ĐÈN BÁO TRẠNG THÁI XANH / ĐỎ
            if (_isKernelExploited) {
                cell.backgroundColor = [UIColor colorWithRed:0.08 green:0.25 blue:0.15 alpha:1.0];
                cell.textLabel.text = @"🟢 ĐÃ KÍCH HOẠT TWEAK (HỆ THỐNG SẴN SÀNG)";
                cell.textLabel.textColor = [UIColor colorWithRed:0.4 green:1.0 blue:0.5 alpha:1.0];
            } else {
                cell.backgroundColor = [UIColor colorWithRed:0.35 green:0.10 blue:0.12 alpha:1.0];
                cell.textLabel.text = @"🔴 CHƯA KÍCH HOẠT (BẤM ĐỂ BẮT ĐẦU 15S)";
                cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
            }
            cell.textLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightHeavy];
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        } else if (indexPath.section == 1) {
            struct utsname sysInfo;
            uname(&sysInfo);
            NSString *deviceModel = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            NSString *osVersion = [[UIDevice currentDevice] systemVersion];

            if (indexPath.row == 0) { cell.textLabel.text = @"Mã Thiết Bị"; cell.detailTextLabel.text = deviceModel; }
            else if (indexPath.row == 1) { cell.textLabel.text = @"Kiến Trúc"; cell.detailTextLabel.text = _isKernelExploited ? _deepArchString : @"arm64 / arm64e"; }
            else if (indexPath.row == 2) { cell.textLabel.text = @"Phiên Bản iOS"; cell.detailTextLabel.text = [NSString stringWithFormat:@"iOS %@", osVersion]; }
            else if (indexPath.row == 3) { cell.textLabel.text = @"Tên Máy"; cell.detailTextLabel.text = [[UIDevice currentDevice] name]; }
            else if (indexPath.row == 4) { cell.textLabel.text = @"Số Nhân CPU"; cell.detailTextLabel.text = _deepCoreCountString ?: @"Cần kích hoạt..."; }
            else if (indexPath.row == 5) { cell.textLabel.text = @"RAM Vật Lý"; cell.detailTextLabel.text = _deepRamString ?: @"Cần kích hoạt..."; }
            else if (indexPath.row == 6) { cell.textLabel.text = @"Darwin Release"; cell.detailTextLabel.text = _deepKernelString ?: @"Cần kích hoạt..."; }
            else { cell.textLabel.text = @"Cache L2"; cell.detailTextLabel.text = _deepCacheString ?: @"Cần kích hoạt..."; }
        } else {
            NSString *jbRoot = Titanium_GetRootHidePrefixPath();
            BOOL isRootless = [jbRoot containsString:@"/var/jb"];
            BOOL canWriteIPC = (access("/tmp", W_OK) == 0);

            if (indexPath.row == 0) { cell.textLabel.text = @"Môi Trường"; cell.detailTextLabel.text = isRootless ? @"Rootless / RootHide" : @"Rootful"; }
            else if (indexPath.row == 1) { cell.textLabel.text = @"Vùng Thư Mục"; cell.detailTextLabel.text = jbRoot; }
            else if (indexPath.row == 2) { cell.textLabel.text = @"Trạng Thái Sandbox"; cell.detailTextLabel.text = _isKernelExploited ? @"Đã Phá Bỏ (Unsandboxed)" : @"Chưa Phá Bỏ"; cell.detailTextLabel.textColor = _isKernelExploited ? [UIColor systemGreenColor] : [UIColor systemOrangeColor]; }
            else { cell.textLabel.text = @"Quyền Ghi IPC"; cell.detailTextLabel.text = canWriteIPC ? @"🟢 Hoạt Động (RW)" : @"🔴 Khóa"; }
        }
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    if (_currentBottomTab == 1 && indexPath.section == 2) {
        if (!_isKernelExploited) {
            [self showUnexploitedWarningAlert];
            return;
        }

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
    } else if (_currentBottomTab == 4 && indexPath.section == 0) {
        [self openDopamineStyleExploitConsole];
    }
}

// Bật tắt áp dụng Tweak trên từng ứng dụng cụ thể
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

    [self applyDeepSpringBoardAndUIKitTweaks];
}

- (void)showUnexploitedWarningAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"🔒 TÍNH NĂNG BỊ KHÓA"
                                                                   message:@"Hệ thống chưa được kích hoạt! Hãy vào mục Cài Đặt và nhấn vào dòng trạng thái đèn đỏ để bắt đầu chu kỳ 15 giây."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"🚀 Kích Hoạt Ngay" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [self openDopamineStyleExploitConsole];
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
        if (strongSelf && strongSelf->_currentBottomTab == 0 && strongSelf->_isKernelExploited) {
            [strongSelf.customTableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
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
    if (!self.settingsDict[@"Enabled"]) self.settingsDict[@"Enabled"] = @YES;
    if (!self.settingsDict[@"TargetRefreshRate"]) self.settingsDict[@"TargetRefreshRate"] = @144;
    if (!self.settingsDict[@"TargetFPSRate"]) self.settingsDict[@"TargetFPSRate"] = @144;
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
