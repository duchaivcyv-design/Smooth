#import "RootListController.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import <spawn.h>
#import <sys/wait.h>
#import <sys/stat.h>
#import <sys/utsname.h>
#import <fcntl.h>
#import <unistd.h>
#import <notify.h>
#import <dlfcn.h>
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/processor_info.h>
#import <mach/mach_host.h>

extern char **environ;

// ====================================================================================================
// KHAI BÁO BẢO ĐẢM TOÀN DIỆN CHO CLANG VỀ CÁC HẰNG SỐ & PRIVATE SELECTOR
// ====================================================================================================

#ifndef PRIMARY_SYNC_FILE
#define PRIMARY_SYNC_FILE @"/tmp/.boost_hz_sync"
#endif

#ifndef SECONDARY_SYNC_FILE
#define SECONDARY_SYNC_FILE @"/var/jb/tmp/.boost_hz_sync"
#endif

#ifndef BOOT_GUARD_FILE
#define BOOT_GUARD_FILE @"/tmp/.boost_boot_counter"
#endif

@interface PSListController (TitaniumPrivateSpecifierCategory)
- (nullable NSMutableArray *)loadSpecifiersFromPlistName:(NSString *)name target:(nullable id)target bundle:(nullable NSBundle *)bundle;
- (nullable NSMutableArray *)specifiersFromDictionary:(NSDictionary *)dictionary target:(nullable id)target;
- (nullable NSIndexPath *)indexPathForSpecifier:(PSSpecifier *)specifier;
- (nullable PSSpecifier *)specifierAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UITableViewCell *)cachedCellForSpecifier:(PSSpecifier *)specifier;
- (nullable UITableView *)table;
- (NSInteger)indexOfSpecifier:(PSSpecifier *)specifier;
@end

@interface BoostConfigV285Pro : NSObject
+ (instancetype)sharedInstance;
- (void)loadSettings;
- (NSInteger)resolvedTargetHz;
- (NSInteger)resolvedTargetFPS;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openURL:(NSURL *)url;
@end

// ====================================================================================================
// BỘ PHÂN GIẢI ĐƯỜNG DẪN & TIỆN ÍCH HỆ THỐNG
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
                if (sub.location != NSNotFound) {
                    cachedJbRoot = [dylibPath substringToIndex:sub.location];
                } else {
                    cachedJbRoot = @"/var/jb";
                }
            } else {
                cachedJbRoot = @"/var/jb";
            }
        } else {
            cachedJbRoot = @"/var/jb";
        }
    });
    return cachedJbRoot;
}

static inline NSBundle *Titanium_GetPreferenceBundle(void) {
    static NSBundle *cachedBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cachedBundle = [NSBundle bundleForClass:NSClassFromString(@"RootListController")];
        if (!cachedBundle || ![cachedBundle.bundlePath containsString:@"BoostiPhone6s"]) {
            NSString *root = Titanium_GetRootHidePrefixPath();
            NSArray *possiblePaths = @[
                [root stringByAppendingPathComponent:@"Library/PreferenceBundles/BoostiPhone6sPrefs.bundle"],
                [root stringByAppendingPathComponent:@"Library/PreferenceBundles/BoostiPhone6s.bundle"],
                @"/var/jb/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle",
                @"/var/jb/Library/PreferenceBundles/BoostiPhone6s.bundle",
                @"/Library/PreferenceBundles/BoostiPhone6sPrefs.bundle",
                @"/Library/PreferenceBundles/BoostiPhone6s.bundle"
            ];
            for (NSString *p in possiblePaths) {
                if ([[NSFileManager defaultManager] fileExistsAtPath:p]) {
                    cachedBundle = [NSBundle bundleWithPath:p];
                    break;
                }
            }
        }
    });
    return cachedBundle;
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
        if (access([candidate UTF8String], X_OK) == 0) {
            return candidate;
        }
    }
    return name;
}

static void Titanium_WriteSyncPayloadUniversal(const void *payloadData, size_t size) {
    NSArray *paths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    for (NSString *path in paths) {
        NSString *dir = [path stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
        }
        int fd = open([path UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (fd >= 0) {
            write(fd, payloadData, size);
            close(fd);
            chmod([path UTF8String], 0644);
        }
    }
}

// ====================================================================================================
// THU THẬP THÔNG SỐ CPU / GPU / NHIỆT ĐỘ THỜI GIAN THỰC (0S OVERHEAD)
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
    return 12.5f;
}

static inline NSString *Titanium_GetLiveThermalString(void) {
    NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
    switch (state) {
        case NSProcessInfoThermalStateNominal:  return @"🟢 Mát Mẻ (~31°C)";
        case NSProcessInfoThermalStateFair:     return @"🟡 Bình Thường (~36°C)";
        case NSProcessInfoThermalStateSerious:  return @"🟠 Ấm Máy (~40°C)";
        case NSProcessInfoThermalStateCritical: return @"🔴 Quá Nhiệt (>43°C)";
        default: return @"🟢 Ổn Định (~32°C)";
    }
}

// ====================================================================================================
// ROOTLISTCONTROLLER IMPLEMENTATION
// ====================================================================================================

@interface RootListController () {
    dispatch_queue_t _syncQueue;
    dispatch_source_t _monitorTimer;
}
@end

@implementation RootListController

- (instancetype)init {
    self = [super init];
    if (self) {
        _syncQueue = dispatch_queue_create("com.titanium.v285.rootsync", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _syncQueue = dispatch_queue_create("com.titanium.v285.rootsync", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (id)initForContentSize:(CGSize)size {
    self = [super init];
    if (self) {
        _syncQueue = dispatch_queue_create("com.titanium.v285.rootsync", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

// ====================================================================================================
// NẠP ĐÚNG BẢN GỐC ROOT.PLIST - BẢO ĐẢM HIỆN 100% CÀI ĐẶT
// ====================================================================================================

- (id)specifiers {
    if (!_specifiers) {
        NSBundle *bundle = Titanium_GetPreferenceBundle();
        if (bundle && [self respondsToSelector:@selector(loadSpecifiersFromPlistName:target:bundle:)]) {
            _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self bundle:bundle];
        }
        if (!_specifiers || _specifiers.count == 0) {
            _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        }
        [self ensureDefaultSettingsExist];
        [self updateDynamicTitlesForSpecifiers:_specifiers];
    }
    return _specifiers;
}

// --- GETTERS CHO 4 DÒNG HUD TRONG ROOT.PLIST ---
- (id)getMonitorHzFPS:(PSSpecifier *)specifier {
    NSDictionary *prefs = [self getMergedPreferences];
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 144;
    NSInteger fps = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 144;
    BOOL isPowerSave = prefs[@"PowerSaveMode"] ? [prefs[@"PowerSaveMode"] boolValue] : NO;
    if (isPowerSave) { hz = 60; fps = 60; }
    return [NSString stringWithFormat:@"%ld Hz | %ld FPS (Khóa Phẳng Lì)", (long)hz, (long)fps];
}

- (id)getMonitorCPUGPU:(PSSpecifier *)specifier {
    float cpu = Titanium_GetLiveCPULoadPercentage();
    return [NSString stringWithFormat:@"CPU: %.1f%% | GPU: Metal Active", cpu];
}

- (id)getMonitorThermal:(PSSpecifier *)specifier {
    return Titanium_GetLiveThermalString();
}

- (id)getMonitorBattery:(PSSpecifier *)specifier {
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    int level = (int)([[UIDevice currentDevice] batteryLevel] * 100);
    if (level < 0) level = 100;
    UIDeviceBatteryState state = [[UIDevice currentDevice] batteryState];
    NSString *charging = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull) ? @"⚡ Đang Sạc" : @"🔋 Dùng Pin";
    return [NSString stringWithFormat:@"%d%% (%@)", level, charging];
}

- (void)syncSharedMemoryFile:(BOOL)enabled {
    NSDictionary *prefs = [self getMergedPreferences];
    
    ApexV285ProPayload payload;
    memset(&payload, 0, sizeof(ApexV285ProPayload));
    payload.magic = APEX_SYNC_MAGIC_V285;
    payload.masterEnabled = enabled ? 1 : 0;

    if (!enabled) {
        payload.targetHz = 60;
        payload.targetFPS = 60;
        payload.forceOverclock = 0;
    } else {
        int32_t hz = prefs[@"TargetRefreshRate"] ? (int32_t)[prefs[@"TargetRefreshRate"] intValue] : 144;
        int32_t fps = prefs[@"TargetFPSRate"] ? (int32_t)[prefs[@"TargetFPSRate"] intValue] : 144;
        BOOL isPowerSave = prefs[@"PowerSaveMode"] ? [prefs[@"PowerSaveMode"] boolValue] : NO;

        if (hz < 15) hz = 15;
        if (hz > 144) hz = 144;
        if (fps < 15) fps = 15;
        if (fps > 144) fps = 144;

        if (isPowerSave) {
            hz = 60;
            fps = 60;
        }

        payload.targetHz = hz;
        payload.targetFPS = fps;
        payload.forceOverclock = (hz >= 144 || fps >= 144) ? 1 : 0;
        payload.dynamicInterpolation = prefs[@"ProMotionEngineBeta7"] ? ([prefs[@"ProMotionEngineBeta7"] boolValue] ? 1 : 0) : 1;
        payload.pipSyncEnabled = 1;
        payload.thermalShield = prefs[@"AntiThermalThrottling"] ? ([prefs[@"AntiThermalThrottling"] boolValue] ? 1 : 0) : 1;
        payload.antiStutterExit = prefs[@"FixAppExitStutter"] ? ([prefs[@"FixAppExitStutter"] boolValue] ? 1 : 0) : 1;
        payload.smartBufferingLevel = 3;
        payload.zeroLatencyTouch = prefs[@"TouchResponseBoost"] ? ([prefs[@"TouchResponseBoost"] boolValue] ? 1 : 0) : 1;
        payload.shaderOptimization = 1;
        payload.fastAppLaunch = prefs[@"TurboAppLaunch"] ? ([prefs[@"TurboAppLaunch"] boolValue] ? 1 : 0) : 1;
        payload.metalPacingEnabled = prefs[@"MetalHexBuffering"] ? ([prefs[@"MetalHexBuffering"] boolValue] ? 1 : 0) : 1;
        payload.lowLatencyAudio = 1;
        payload.memoryPressureRelief = 1;
        payload.runloopHangGuard = 1;
        payload.keyboardZeroLagV3 = prefs[@"KeyboardZeroLagV24"] ? ([prefs[@"KeyboardZeroLagV24"] boolValue] ? 1 : 0) : 1;
        payload.aggressiveRamCleaner = prefs[@"AggressiveRamClean"] ? ([prefs[@"AggressiveRamClean"] boolValue] ? 1 : 0) : 0;
        payload.lockFixedFpsWhenThermal = prefs[@"AntiThermalThrottling"] ? ([prefs[@"AntiThermalThrottling"] boolValue] ? 1 : 0) : 1;
        payload.antiGhostTouch = prefs[@"AntiGhostTouch"] ? ([prefs[@"AntiGhostTouch"] boolValue] ? 1 : 0) : 1;
        payload.diskIOPriorityBoost = 1;
        payload.rawTouchDirectDelivery = 1;
        payload.powerSaveModeActive = isPowerSave ? 1 : 0;
    }

    payload.updateSeq = (uint64_t)mach_absolute_time();
    payload.lastHeartbeat = payload.updateSeq;

    Titanium_WriteSyncPayloadUniversal(&payload, sizeof(ApexV285ProPayload));

    Class configClass = NSClassFromString(@"BoostConfigV285Pro");
    if (configClass) {
        [[configClass sharedInstance] loadSettings];
    }

    notify_post(NOTIFY_RELOAD);
    notify_post(NOTIFY_UIKIT_RELOAD);
    notify_post(NOTIFY_HARDWARE_SYNC);
    notify_post(NOTIFY_FPS_CHANGED);
    notify_post(NOTIFY_TITANIUM_CHANGED);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    [self setupNavigationItems];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavigationItems];
    [self startHardwareMonitor];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self stopHardwareMonitor];
}

- (void)startHardwareMonitor {
    [self stopHardwareMonitor];

    _monitorTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(_monitorTimer, dispatch_time(DISPATCH_TIME_NOW, 0), (uint64_t)(1.2 * NSEC_PER_SEC), (uint64_t)(0.2 * NSEC_PER_SEC));

    __weak typeof(self) weakSelf = self;
    dispatch_source_set_event_handler(_monitorTimer, ^{
        [weakSelf refreshHardwareHUD];
    });
    dispatch_resume(_monitorTimer);
}

- (void)stopHardwareMonitor {
    if (_monitorTimer) {
        dispatch_source_cancel(_monitorTimer);
        _monitorTimer = nil;
    }
}

- (void)refreshHardwareHUD {
    NSDictionary *prefs = [self getMergedPreferences];
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 144;
    NSInteger fps = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 144;
    BOOL isPowerSave = prefs[@"PowerSaveMode"] ? [prefs[@"PowerSaveMode"] boolValue] : NO;
    if (isPowerSave) { hz = 60; fps = 60; }

    float cpuLoad = Titanium_GetLiveCPULoadPercentage();
    NSString *thermalDesc = Titanium_GetLiveThermalString();

    int batLevel = (int)([[UIDevice currentDevice] batteryLevel] * 100);
    if (batLevel < 0) batLevel = 100;
    UIDeviceBatteryState state = [[UIDevice currentDevice] batteryState];
    NSString *charging = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull) ? @"⚡ Đang Sạc" : @"🔋 Dùng Pin";

    NSString *hzFpsStr = [NSString stringWithFormat:@"%ld Hz | %ld FPS (Khóa Phẳng Lì)", (long)hz, (long)fps];
    NSString *thermalStr = [NSString stringWithFormat:@"%@", thermalDesc];
    NSString *cpuStr = [NSString stringWithFormat:@"CPU: %.1f%% | GPU: Metal Active", cpuLoad];
    NSString *batStr = [NSString stringWithFormat:@"%d%% (%@)", batLevel, charging];

    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self respondsToSelector:@selector(table)]) {
            UITableView *tbl = [self table];
            if (tbl) {
                for (UITableViewCell *c in [tbl visibleCells]) {
                    NSIndexPath *ip = [tbl indexPathForCell:c];
                    if (ip && [self respondsToSelector:@selector(specifierAtIndexPath:)]) {
                        PSSpecifier *s = [self specifierAtIndexPath:ip];
                        NSString *k = [s propertyForKey:@"key"] ?: [s propertyForKey:@"id"];
                        if ([k isEqualToString:@"MonitorHzFPS"]) {
                            c.detailTextLabel.text = hzFpsStr;
                            [c setNeedsLayout];
                        } else if ([k isEqualToString:@"MonitorCPUGPU"]) {
                            c.detailTextLabel.text = cpuStr;
                            [c setNeedsLayout];
                        } else if ([k isEqualToString:@"MonitorThermal"]) {
                            c.detailTextLabel.text = thermalStr;
                            [c setNeedsLayout];
                        } else if ([k isEqualToString:@"MonitorBattery"]) {
                            c.detailTextLabel.text = batStr;
                            [c setNeedsLayout];
                        }
                    }
                }
            }
        }
    });
}

- (void)updateDynamicTitlesForSpecifiers:(NSArray *)targetSpecs {
    if (!targetSpecs || targetSpecs.count == 0) return;

    NSDictionary *prefs = [self getMergedPreferences];
    NSInteger hz = prefs[@"TargetRefreshRate"] ? [prefs[@"TargetRefreshRate"] integerValue] : 144;
    NSInteger fps = prefs[@"TargetFPSRate"] ? [prefs[@"TargetFPSRate"] integerValue] : 144;
    BOOL isPowerSave = prefs[@"PowerSaveMode"] ? [prefs[@"PowerSaveMode"] boolValue] : NO;

    if (hz < 15) hz = 15;
    if (hz > 144) hz = 144;
    if (fps < 15) fps = 15;
    if (fps > 144) fps = 144;

    for (PSSpecifier *spec in targetSpecs) {
        NSString *key = [spec propertyForKey:@"key"];
        if ([key isEqualToString:@"TargetRefreshRate"]) {
            if (isPowerSave) {
                spec.name = @"🔋 Tần Số Quét: Đã Khóa 60 Hz (Tiết Kiệm Pin)";
            } else if (hz >= 144) {
                spec.name = @"⚡ Tần Số Quét: Đã Khóa Cứng 144 Hz (Ép Xung Tối Đa)";
            } else {
                spec.name = [NSString stringWithFormat:@"🔒 Tần Số Quét: Đã Khóa Cứng %ld Hz", (long)hz];
            }
            [spec setProperty:spec.name forKey:@"label"];
        } else if ([key isEqualToString:@"TargetFPSRate"]) {
            if (isPowerSave) {
                spec.name = @"🔋 Khung Hình App: Đã Khóa 60 FPS (Tiết Kiệm Pin)";
            } else if (fps >= 144) {
                spec.name = @"⚡ Khung Hình App: Đã Khóa Cứng 144 FPS (Ép Xung Tối Đa)";
            } else {
                spec.name = [NSString stringWithFormat:@"🔒 Khung Hình App: Đã Khóa Cứng %ld FPS", (long)fps];
            }
            [spec setProperty:spec.name forKey:@"label"];
        }
    }
}

- (void)updateDynamicTitles {
    [self updateDynamicTitlesForSpecifiers:self->_specifiers];
}

- (NSDictionary *)getMergedPreferences {
    NSString *prefPath = Titanium_ResolvePrefPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
        NSDictionary *fileDict = [NSDictionary dictionaryWithContentsOfFile:prefPath];
        if (fileDict && fileDict.count > 0) return fileDict;
    }
    
    CFPreferencesAppSynchronize(PREF_DOMAIN);
    CFArrayRef keyList = CFPreferencesCopyKeyList(PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    if (keyList) {
        NSDictionary *dict = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList, PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        CFRelease(keyList);
        if (dict) return dict;
    }
    return [NSDictionary dictionary];
}

- (void)ensureDefaultSettingsExist {
    NSString *prefPath = Titanium_ResolvePrefPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:prefPath]) {
        NSString *dir = [prefPath stringByDeletingLastPathComponent];
        if (![fm fileExistsAtPath:dir]) {
            [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
        }

        NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithDictionary:@{
             @"Enabled": @YES,
             @"ShowBasicOptions": @YES,
             @"ShowAdvancedOptions": @NO,
             @"SelectedLanguage": @"auto",
             @"ProMotionEngineBeta7": @YES,
             @"MetalHexBuffering": @YES,
             @"KeyboardZeroLagV24": @YES,
             @"EnableHzControl": @YES,
             @"TargetRefreshRate": @144,
             @"EnableFPSControl": @YES,
             @"TargetFPSRate": @144,
             @"ForceOverclock144Hz": @YES,
             @"SyncModuleDelay": @NO,
             @"IsolateRenderPipeline": @YES,
             @"ColorOs17SmoothEngine": @YES,
             @"ReduceMultiTaskLag": @YES,
             @"FixAppLaunchBlackScreen": @YES,
             @"FixAppExitStutter": @YES,
             @"TouchResponseBoost": @YES,
             @"QuantumRenderShield": @NO,
             @"NeuralBufferOpt": @YES,
             @"BackgroundPacingDaemon": @YES,
             @"HyperMemoryGuardian": @YES,
             @"UltraResponsiveness": @YES,
             @"HyperThreadIO": @YES,
             @"QuantumCoreSync": @YES,
             @"ZeroLagNeuralBooster": @YES,
             @"VsyncAdaptiveBuffer": @YES,
             @"DynamicThermalEngine": @YES,
             @"IOSchedulerEngine": @YES,
             @"RealtimeThreadSched": @YES,
             @"CPUGPUFreqOptimizer": @YES,
             @"PeriodicRamClean": @NO,
             @"AggressiveRamClean": @NO,
             @"MachVMPurgeRam": @NO,
             @"AutoCloseBackgroundApp": @NO,
             @"TurboAppLaunch": @YES,
             @"GameFPSStabilizer": @YES,
             @"SystemProcessOpt": @YES,
             @"DeviceSpoofer": @YES,
             @"AntiThermalThrottling": @YES,
             @"SmartThermalDispatch": @YES,
             @"HeavyLoadCooling": @YES,
             @"ChargeThermalProtection": @YES,
             @"PowerSaveMode": @NO,
             @"AntiGhostTouch": @YES,
             @"ChargerRippleRejection": @YES,
             @"BypassVarSandbox": @YES,
             @"BlockBackgroundTelemetry": @YES
        }];

        [defaults writeToFile:prefPath atomically:YES];
        chmod([prefPath UTF8String], 0644);

        for (NSString *key in defaults) {
            CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)defaults[key], PREF_DOMAIN);
        }
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        [self syncSharedMemoryFile:YES];
    }
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return [specifier propertyForKey:@"default"];

    NSString *prefPath = Titanium_ResolvePrefPath();
    if ([[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:prefPath];
        if (prefs && prefs[key] != nil) {
            return prefs[key];
        }
    }

    CFPreferencesAppSynchronize(PREF_DOMAIN);
    CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)key, PREF_DOMAIN);
    if (val) {
        return (__bridge_transfer id)val;
    }

    return [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (!key) return;

    NSString *prefPath = Titanium_ResolvePrefPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [prefPath stringByDeletingLastPathComponent];
    if (![fm fileExistsAtPath:dir]) {
        [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
    }

    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];
    [prefs setObject:value forKey:key];
    [prefs writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0644);

    CFPreferencesSetAppValue((__bridge CFStringRef)key, (__bridge CFPropertyListRef)value, PREF_DOMAIN);
    CFPreferencesAppSynchronize(PREF_DOMAIN);

    if ([key isEqualToString:@"Enabled"]) {
        [self syncSharedMemoryFile:[value boolValue]];
    }

    BOOL currentEnabled = [prefs[@"Enabled"] boolValue];
    [self syncSharedMemoryFile:currentEnabled];

    if ([key isEqualToString:@"SelectedLanguage"] || [key isEqualToString:@"ForceOverclock144Hz"] || [key isEqualToString:@"PowerSaveMode"]) {
        self->_specifiers = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setupNavigationItems];
            [self reloadSpecifiers];
        });
    }
}

- (void)applyRateValue:(NSInteger)rate isDynamic:(BOOL)dynamicMode isFPS:(BOOL)isFPS {
    if (rate < 15) rate = 15;
    if (rate > 144) rate = 144;

    NSString *prefPath = Titanium_ResolvePrefPath();
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];

    if (isFPS) {
        [prefs setObject:@(rate) forKey:@"TargetFPSRate"];
        [prefs setObject:@YES forKey:@"EnableFPSControl"];
    } else {
        [prefs setObject:@(rate) forKey:@"TargetRefreshRate"];
        [prefs setObject:@YES forKey:@"EnableHzControl"];
    }

    [prefs setObject:@NO forKey:@"PowerSaveMode"];
    BOOL isOverclock = (rate >= 144);
    if (!isFPS) {
        [prefs setObject:@(isOverclock) forKey:@"ForceOverclock144Hz"];
    }

    [prefs writeToFile:prefPath atomically:YES];
    chmod([prefPath UTF8String], 0644);

    if (isFPS) {
        CFPreferencesSetAppValue(CFSTR("TargetFPSRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
        CFPreferencesSetAppValue(CFSTR("EnableFPSControl"), kCFBooleanTrue, PREF_DOMAIN);
    } else {
        CFPreferencesSetAppValue(CFSTR("TargetRefreshRate"), (__bridge CFPropertyListRef)@(rate), PREF_DOMAIN);
        CFPreferencesSetAppValue(CFSTR("EnableHzControl"), kCFBooleanTrue, PREF_DOMAIN);
        CFPreferencesSetAppValue(CFSTR("ForceOverclock144Hz"), isOverclock ? kCFBooleanTrue : kCFBooleanFalse, PREF_DOMAIN);
    }
    CFPreferencesAppSynchronize(PREF_DOMAIN);

    [self syncSharedMemoryFile:YES];
    [self updateDynamicTitles];
    [self reloadSpecifiers];
}

- (void)showLanguagePickerPopup:(PSSpecifier *)specifier {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"CHỌN NGÔN NGỮ (LANGUAGE)" message:nil preferredStyle:UIAlertControllerStyleActionSheet];

    NSArray *langs = @[
        @{@"code": @"auto", @"name": @"🌐 Tự Động / Auto (Theo Máy)"},
        @{@"code": @"vi",   @"name": @"🇻🇳 Tiếng Việt"},
        @{@"code": @"en",   @"name": @"🇺🇸 English"}
    ];

    for (NSDictionary *item in langs) {
        [alert addAction:[UIAlertAction actionWithTitle:item[@"name"] style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *code = item[@"code"];
            NSString *prefPath = Titanium_ResolvePrefPath();
            NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:prefPath] ?: [NSMutableDictionary dictionary];
            prefs[@"SelectedLanguage"] = code;
            [prefs writeToFile:prefPath atomically:YES];
            chmod([prefPath UTF8String], 0644);

            CFPreferencesSetAppValue(CFSTR("SelectedLanguage"), (__bridge CFPropertyListRef)code, PREF_DOMAIN);
            CFPreferencesAppSynchronize(PREF_DOMAIN);

            notify_post(NOTIFY_RELOAD);
            notify_post(NOTIFY_TITANIUM_CHANGED);
            self->_specifiers = nil;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setupNavigationItems];
                [self reloadSpecifiers];
            });
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Đóng" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
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
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (UIMenu *)buildHzMenu API_AVAILABLE(ios(14.0)) {
    UIAction *act144 = [UIAction actionWithTitle:@"144 Hz (Ép Xung Cực Đại)" image:[UIImage systemImageNamed:@"bolt.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:144 isDynamic:NO isFPS:NO];
    }];
    UIAction *act120 = [UIAction actionWithTitle:@"120 Hz (ProMotion Max)" image:[UIImage systemImageNamed:@"sparkles"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:120 isDynamic:NO isFPS:NO];
    }];
    UIAction *act90 = [UIAction actionWithTitle:@"90 Hz (Siêu Mượt)" image:[UIImage systemImageNamed:@"speedometer"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:90 isDynamic:NO isFPS:NO];
    }];
    UIAction *act60 = [UIAction actionWithTitle:@"60 Hz (Tiêu Chuẩn Chuẩn Mực)" image:[UIImage systemImageNamed:@"checkmark.seal.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:60 isDynamic:NO isFPS:NO];
    }];
    UIAction *act30 = [UIAction actionWithTitle:@"30 Hz (Tiết Kiệm Pin)" image:[UIImage systemImageNamed:@"leaf.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:30 isDynamic:NO isFPS:NO];
    }];

    UIAction *customAction = [UIAction actionWithTitle:@"Tự Nhập Số Chính Xác (15 - 144 Hz)..." image:[UIImage systemImageNamed:@"keyboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self showCustomRateInputAlertForHz:YES];
    }];

    return [UIMenu menuWithTitle:@"TẦN SỐ QUÉT (HZ)" children:@[act144, act120, act90, act60, act30, customAction]];
}

- (UIMenu *)buildFPSMenu API_AVAILABLE(ios(14.0)) {
    UIAction *act144 = [UIAction actionWithTitle:@"144 FPS (Ép Xung Cực Đại)" image:[UIImage systemImageNamed:@"bolt.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:144 isDynamic:NO isFPS:YES];
    }];
    UIAction *act120 = [UIAction actionWithTitle:@"120 FPS (Gaming Cực Mượt)" image:[UIImage systemImageNamed:@"sparkles"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:120 isDynamic:NO isFPS:YES];
    }];
    UIAction *act90 = [UIAction actionWithTitle:@"90 FPS (Tối Ưu Game)" image:[UIImage systemImageNamed:@"speedometer"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:90 isDynamic:NO isFPS:YES];
    }];
    UIAction *act60 = [UIAction actionWithTitle:@"60 FPS (Chuẩn Mặc Định)" image:[UIImage systemImageNamed:@"checkmark.seal.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:60 isDynamic:NO isFPS:YES];
    }];
    UIAction *act30 = [UIAction actionWithTitle:@"30 FPS (Tiết Kiệm Pin)" image:[UIImage systemImageNamed:@"leaf.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self applyRateValue:30 isDynamic:NO isFPS:YES];
    }];

    UIAction *customAction = [UIAction actionWithTitle:@"Tự Nhập Số Chính Xác (15 - 144 FPS)..." image:[UIImage systemImageNamed:@"keyboard"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
        [self showCustomRateInputAlertForHz:NO];
    }];

    return [UIMenu menuWithTitle:@"KHUNG HÌNH (FPS)" children:@[act144, act120, act90, act60, act30, customAction]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    if (@available(iOS 14.0, *)) {
        PSSpecifier *spec = nil;
        if ([self respondsToSelector:@selector(specifierAtIndexPath:)]) {
            spec = [self specifierAtIndexPath:indexPath];
        }
        if (spec) {
            NSString *key = [spec propertyForKey:@"key"];
            if ([key isEqualToString:@"TargetRefreshRate"]) {
                [self attachMenu:[self buildHzMenu] toCell:cell];
            } else if ([key isEqualToString:@"TargetFPSRate"]) {
                [self attachMenu:[self buildFPSMenu] toCell:cell];
            }
        }
    }
    return cell;
}

- (void)attachMenu:(UIMenu *)menu toCell:(UITableViewCell *)cell API_AVAILABLE(ios(14.0)) {
    if (!cell || !menu) return;
    UIButton *existingBtn = [cell.contentView viewWithTag:99285];
    if (!existingBtn) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.tag = 99285;
        btn.frame = cell.contentView.bounds;
        btn.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        btn.backgroundColor = [UIColor clearColor];
        btn.showsMenuAsPrimaryAction = YES;
        btn.menu = menu;
        [cell.contentView addSubview:btn];
    } else {
        existingBtn.menu = menu;
        existingBtn.showsMenuAsPrimaryAction = YES;
    }
}

- (void)showHzPickerPopup:(PSSpecifier *)specifier {
    [self showCustomRateInputAlertForHz:YES];
}

- (void)showFPSPickerPopup:(PSSpecifier *)specifier {
    [self showCustomRateInputAlertForHz:NO];
}

- (id)getAuthorName:(PSSpecifier *)specifier {
    return @"ĐỨC LONG";
}

- (id)getVersionString:(PSSpecifier *)specifier {
    return @"V28.7 SUPREME PRO (144Hz)";
}

- (void)openSupportLink:(PSSpecifier *)specifier {
    NSURL *webURL = [NSURL URLWithString:@"https://zalo.me/g/qjd56ltkraiih88ps6ui"];
    dispatch_async(dispatch_get_main_queue(), ^{
        Class workspaceClass = objc_getClass("LSApplicationWorkspace");
        if (workspaceClass && [workspaceClass respondsToSelector:@selector(defaultWorkspace)]) {
            LSApplicationWorkspace *workspace = [workspaceClass defaultWorkspace];
            if ([workspace respondsToSelector:@selector(openURL:)]) {
                if ([workspace openURL:webURL]) return;
            }
        }
        [[UIApplication sharedApplication] openURL:webURL options:@{} completionHandler:nil];
    });
}

// ====================================================================================================
// THANH ĐIỀU HƯỚNG VÀ HÀNH ĐỘNG HỆ THỐNG
// ====================================================================================================

- (void)setupNavigationItems {
    if (@available(iOS 14.0, *)) {
        UIAction *respringAction = [UIAction actionWithTitle:@"Respring Nhanh (An Toàn)" image:[UIImage systemImageNamed:@"bolt.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self executeRespring];
        }];
        UIAction *srebootAction = [UIAction actionWithTitle:@"Khởi Động Userspace (SReboot)" image:[UIImage systemImageNamed:@"arrow.clockwise.circle.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self executeSReboot];
        }];
        UIAction *resetAction = [UIAction actionWithTitle:@"Đặt Lại Cấu Hình Mặc Định (144Hz)" image:[UIImage systemImageNamed:@"trash.fill"] identifier:nil handler:^(__kindof UIAction * _Nonnull action) {
            [self executeResetConfiguration];
        }];
        resetAction.attributes = UIMenuElementAttributesDestructive;

        UIMenu *actionsMenu = [UIMenu menuWithTitle:@"Hành Động" children:@[respringAction, srebootAction, resetAction]];
        UIBarButtonItem *actionBtn = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"ellipsis.circle.fill"] menu:actionsMenu];
        actionBtn.tintColor = [UIColor systemBlueColor];
        self.navigationItem.rightBarButtonItem = actionBtn;
    }
}

- (void)executeRespring {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        NSString *sbreloadBin = Titanium_FindExecutablePath(@"sbreload");
        if (access([sbreloadBin UTF8String], X_OK) == 0) {
            pid_t pid;
            char *argv[] = {(char *)[sbreloadBin UTF8String], NULL};
            if (posix_spawn(&pid, [sbreloadBin UTF8String], NULL, NULL, argv, environ) == 0) {
                waitpid(pid, NULL, 0);
                return;
            }
        }
        NSString *launchctlBin = Titanium_FindExecutablePath(@"launchctl");
        if (access([launchctlBin UTF8String], X_OK) == 0) {
            pid_t pid;
            char *argvKick[] = {(char *)[launchctlBin UTF8String], (char *)"kickstart", (char *)"-k", (char *)"system/com.apple.SpringBoard", NULL};
            posix_spawn(&pid, [launchctlBin UTF8String], NULL, NULL, argvKick, environ);
            waitpid(pid, NULL, 0);
        }
    });
}

- (void)executeSReboot {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        pid_t pid;
        NSString *launchctlBin = Titanium_FindExecutablePath(@"launchctl");
        char *argv[] = {(char *)[launchctlBin UTF8String], (char *)"reboot", (char *)"userspace", NULL};
        posix_spawn(&pid, [launchctlBin UTF8String], NULL, NULL, argv, environ);
        waitpid(pid, NULL, 0);
    });
}

- (void)executeResetConfiguration {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Xác Nhận Đặt Lại" message:@"Toàn bộ cài đặt sẽ được đưa về giá trị mặc định tối ưu 144Hz của v28.7 Pro." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Đặt Lại Ngay" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        [[NSFileManager defaultManager] removeItemAtPath:prefPath error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:PRIMARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:SECONDARY_SYNC_FILE error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:BOOT_GUARD_FILE error:nil];

        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFArrayRef keyList = CFPreferencesCopyKeyList(PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
        if (keyList) {
            for (CFIndex i = 0; i < CFArrayGetCount(keyList); i++) {
                CFStringRef key = (CFStringRef)CFArrayGetValueAtIndex(keyList, i);
                CFPreferencesSetAppValue(key, NULL, PREF_DOMAIN);
            }
            CFRelease(keyList);
        }
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        [self syncSharedMemoryFile:YES];
        [self ensureDefaultSettingsExist];
        [self updateDynamicTitles];
        self->_specifiers = nil;
        [self setupNavigationItems];
        [self reloadSpecifiers];
    }]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Hủy" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
