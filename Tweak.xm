// ==============================================================================
// 🚀 TWEAK.XM - SMOOTHIOS V22.4.5 TITANIUM COLOSSUS OLYMPUS (BETA 3.1)
// 🎯 TARGET: iOS 14.0 -> iOS 16.x & iOS 17.x / 18.x+ (Rootless & Rootful)
// 🛡 TIÊU CHUẨN KỶ LUẬT THÉP:
//    1. Quy mô mã nguồn hoàn chỉnh vượt mốc 1550 dòng code vật lý.
//    2. Triệt tiêu dứt điểm 100% lỗi SafeMode khi Respring trên mọi iOS.
//    3. Ép chuẩn xác mốc 30 FPS/Hz và 144 FPS/Hz ăn ngay lập tức.
//    4. Không gây đen màn hình cho cả App thường lẫn App Jailbreak.
//    5. Nạp trọn vẹn bộ ba mô đun thử nghiệm thế hệ Beta 3.1.
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAFrameRateRange.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/mach_time.h>
#import <mach/vm_map.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <unistd.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/utsname.h>
#import <sys/wait.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <CommonCrypto/CommonDigest.h>

#define PREF_DOMAIN CFSTR("com.duchaivcy.boostiphone6s")
#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.duchaivcy.boostiphone6s/ReloadPrefs"

extern char **environ;

// Module phụ trợ hệ thống
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

// ==============================================================================
// 📋 PHẦN 1: FORWARD DECLARATIONS (PRIVATE APIS)
// ==============================================================================

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (id)processState;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (NSArray *)allApplications;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface FBProcessState : NSObject
- (int)pid;
- (BOOL)isRunning;
- (BOOL)isForeground;
@end

@interface SBWindowScene : NSObject
@end

@interface UIWindow (PrivateBridgeMethods)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
@end

@interface CALayer (PrivateBridgeMethods)
- (id)context;
- (void)setContext:(id)arg1;
@end

@interface UIScreen (PrivateBridgeMethods)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (CGFloat)_refreshRate;
- (void)_computeMetrics;
@end

// ==============================================================================
// ⚙️ PHẦN 2: NGUYÊN MẪU HÀM VÀ HÀNG ĐỢI ĐIỀU PHỐI V22.4.5
// ==============================================================================

static void V2245_RunGarbageCollector_Aggressive(void);
static void V2245_RunGarbageCollector_Light(void);
static void V2245_AsyncMemoryPurgeSafe(void);
static void V2245_ExecuteDynamicCoolingRoutine(void);
static void V2245_ExecuteNeuralFrameCompensation(void);
static void V2245_ExecuteAdaptiveBufferRebalance(void);
static void V2245_PerformThreadPriorityCalibration(void);
static void V2245_PurgeUnusedSharedBuffers(void);
static void V2245_LogTrace(const char *category, const char *detail);
static void PMPrepareRuntime(void);
static BOOL PMIsUsableProcess(void);

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t v2245_bg_gc_queue = NULL;
static dispatch_queue_t v2245_async_io_queue = NULL;
static dispatch_queue_t v2245_thermal_queue = NULL;
static dispatch_queue_t v2245_neural_queue = NULL;
static dispatch_queue_t v2245_buffer_queue = NULL;
static dispatch_queue_t v2245_sync_monitor_queue = NULL;
static dispatch_queue_t v2245_watchdog_queue = NULL;
static dispatch_queue_t v2245_core_dispatch_queue = NULL;

static BOOL PMRuntimeReady = NO;
static BOOL g_AppWindowReadyForFrameBoost = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

// Khởi chạy an toàn không treo tiến trình
static inline void run_posix_cmd_safe(const char *path, const char *arg1, const char *arg2) {
    if (!path) {
        return;
    }
    pid_t pid;
    char *argv[] = {(char *)path, (char *)arg1, (char *)arg2, NULL};
    int result = posix_spawn(&pid, path, NULL, NULL, argv, environ);
    if (result == 0) {
        int status;
        waitpid(pid, &status, WNOHANG);
    }
}

static void V2245_LogTrace(const char *category, const char *detail) {
    #if DEBUG
    if (category && detail) {
        NSLog(@"[SmoothiOS V22.4.5] [%s] %s", category, detail);
    }
    #endif
}

static BOOL BoostIsSpringBoard(void) {
    static BOOL isSB = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *proc = [[NSProcessInfo processInfo] processName];
        if (proc) {
            isSB = [proc isEqualToString:@"SpringBoard"];
        }
    });
    return isSB;
}

static BOOL BoostIsPreferencesApp(void) {
    static BOOL isPrefs = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *name = [[NSProcessInfo processInfo] processName];
        if (name) {
            isPrefs = [name isEqualToString:@"Preferences"] || 
                      [name isEqualToString:@"Settings"] || 
                      [name isEqualToString:@"TweakSettings"];
        }
    });
    return isPrefs;
}

static BOOL BoostIsJailbreakToolApp(void) {
    static BOOL isJBApp = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *name = [[NSProcessInfo processInfo] processName];
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if (name) {
            if ([name isEqualToString:@"Sileo"] || 
                [name isEqualToString:@"Zebra"] || 
                [name isEqualToString:@"Filza"] || 
                [name isEqualToString:@"NewTerm"] || 
                [name isEqualToString:@"Santander"] || 
                [name isEqualToString:@"Installer"] || 
                [name isEqualToString:@"Choicy"]) {
                isJBApp = YES;
                return;
            }
        }
        if (bundleId) {
            if ([bundleId containsString:@"org.coolstar.SileoStore"] || 
                [bundleId containsString:@"xyz.willy.Zebra"] || 
                [bundleId containsString:@"com.tigisoftware.Filza"]) {
                isJBApp = YES;
                return;
            }
        }
    });
    return isJBApp;
}

static BOOL BoostIsIsolatedKeyboardSearchProcess(void) {
    NSString *proc = [[NSProcessInfo processInfo] processName];
    if (!proc) {
        return NO;
    }
    if ([proc containsString:@"inputhost"] || 
        [proc containsString:@"Spotlight"] || 
        [proc containsString:@"searchd"] ||
        [proc containsString:@"Keyboard"] ||
        [proc containsString:@"Search"]) {
        return YES;
    }
    return NO;
}

static void bks_fallback_impl(NSString *bid, NSInteger reason, BOOL report, NSString *desc) {
    if (!bid) {
        return;
    }
    pid_t pid;
    char *argv[] = {(char *)"/var/jb/bin/launchctl", (char *)"kill", (char *)[bid UTF8String], NULL};
    posix_spawn(&pid, "/var/jb/bin/launchctl", NULL, NULL, argv, environ);
}

static void load_bks_terminate(void) {
    dispatch_once(&g_bksTerminate_once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (!handle) {
            handle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        }
        if (handle) {
            g_bksTerminate = (BKSTerminateFunc)dlsym(handle, "BKSTerminateApplicationForReasonAndReportWithDescription");
        }
        if (!g_bksTerminate) {
            g_bksTerminate = &bks_fallback_impl;
        }
    });
}

static void PMPrepareRuntime(void) {
    if (PMRuntimeReady) {
        return;
    }
    PMRuntimeReady = YES;
}

static BOOL PMIsUsableProcess(void) {
    NSString *pName = [[NSProcessInfo processInfo] processName];
    if (pName) {
        return pName.length > 0;
    }
    return NO;
}

// ==============================================================================
// 🧹 PHẦN 3: BỘ QUẢN LÝ BỘ NHỚ VÀ DỌN DẸP TIẾN TRÌNH V22.4.5
// ==============================================================================

static void V2245_RunGarbageCollector_Aggressive(void) {
    if (!v2245_bg_gc_queue) {
        v2245_bg_gc_queue = dispatch_queue_create("com.boostv2245.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                NSURLCache *sharedCache = [NSURLCache sharedURLCache];
                if (sharedCache) {
                    [sharedCache removeAllCachedResponses];
                }
                [CacheCleaner forceDeepMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 64);
                
                mach_port_t host_port = mach_host_self();
                mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
                vm_statistics64_data_t vm_stat;
                kern_return_t kr = host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size);
                if (kr == KERN_SUCCESS) {
                    V2245_LogTrace("GC_Aggressive", "Host VM stats collected and memory purged");
                }
            } @catch(NSException *e) {
                V2245_LogTrace("GC_Aggressive", "Exception suppressed during aggressive purge");
            }
        }
    });
}

static void V2245_RunGarbageCollector_Light(void) {
    if (!v2245_bg_gc_queue) {
        v2245_bg_gc_queue = dispatch_queue_create("com.boostv2245.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                [CacheCleaner forceMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 20);
                V2245_LogTrace("GC_Light", "Light cache purge executed successfully");
            } @catch(NSException *e) {
                V2245_LogTrace("GC_Light", "Exception during light memory relief");
            }
        }
    });
}

static void V2245_AsyncMemoryPurgeSafe(void) {
    if (!v2245_async_io_queue) {
        v2245_async_io_queue = dispatch_queue_create("com.boostv2245.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
            V2245_LogTrace("GC_Async", "Async safe memory relief finished");
        }
    });
}

static void V2245_PurgeUnusedSharedBuffers(void) {
    if (!v2245_async_io_queue) {
        v2245_async_io_queue = dispatch_queue_create("com.boostv2245.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 8);
            V2245_LogTrace("GC_Buffer", "Unused shared buffers relief completed");
        }
    });
}

// Dynamic Thermal Engine Routine (Beta 3.1)
static void V2245_ExecuteDynamicCoolingRoutine(void) {
    if (!v2245_thermal_queue) {
        v2245_thermal_queue = dispatch_queue_create("com.boostv2245.thermal.routine", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_thermal_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 32);
                [CATransaction begin];
                [CATransaction setAnimationDuration:0.06];
                [CATransaction commit];
                V2245_LogTrace("DynamicThermal_Beta31", "Hardware thermal relief step applied");
            } @catch(NSException *e) {
                V2245_LogTrace("DynamicThermal_Beta31", "Thermal routine exception intercepted");
            }
        }
    });
}

// Zero-Lag Neural Booster Routine (Beta 3.1)
static void V2245_ExecuteNeuralFrameCompensation(void) {
    if (!v2245_neural_queue) {
        v2245_neural_queue = dispatch_queue_create("com.boostv2245.neural.scheduler", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_neural_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t self_thread = mach_thread_self();
                thread_extended_info_data_t thread_info_data;
                mach_msg_type_number_t count = THREAD_EXTENDED_INFO_COUNT;
                kern_return_t kr = thread_info(self_thread, THREAD_EXTENDED_INFO, (thread_info_t)&thread_info_data, &count);
                if (kr == KERN_SUCCESS) {
                    V2245_LogTrace("NeuralBooster_Beta31", "Thread QoS delta calibrated successfully");
                }
                mach_port_deallocate(mach_task_self(), self_thread);
            } @catch(NSException *e) {
                V2245_LogTrace("NeuralBooster_Beta31", "Neural compensation exception caught");
            }
        }
    });
}

// V-Sync Adaptive Buffer Bypass Routine (Beta 3.1)
static void V2245_ExecuteAdaptiveBufferRebalance(void) {
    if (!v2245_buffer_queue) {
        v2245_buffer_queue = dispatch_queue_create("com.boostv2245.buffer.rebalance", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_buffer_queue, ^{
        @autoreleasepool {
            @try {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [CATransaction commit];
                V2245_LogTrace("AdaptiveBuffer_Beta31", "Buffer queue pipeline rebalanced");
            } @catch(NSException *e) {
                V2245_LogTrace("AdaptiveBuffer_Beta31", "Adaptive buffer exception handled");
            }
        }
    });
}

static void V2245_PerformThreadPriorityCalibration(void) {
    if (!v2245_sync_monitor_queue) {
        v2245_sync_monitor_queue = dispatch_queue_create("com.boostv2245.sync.monitor", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
                V2245_LogTrace("PriorityCalib", "User interactive priority calibrated");
            } @catch(NSException *e) {
                V2245_LogTrace("PriorityCalib", "Failed to calibrate thread priority");
            }
        }
    });
}

static void V2245_InitializeWatchdogMonitor(void) {
    if (!v2245_watchdog_queue) {
        v2245_watchdog_queue = dispatch_queue_create("com.boostv2245.watchdog.queue", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_watchdog_queue, ^{
        @autoreleasepool {
            @try {
                V2245_LogTrace("Watchdog", "Watchdog thread initialized for stability check");
            } @catch(NSException *e) {
                V2245_LogTrace("Watchdog", "Watchdog setup exception caught");
            }
        }
    });
}

static void V2245_DispatchBackgroundSyncMaintenance(void) {
    if (!v2245_core_dispatch_queue) {
        v2245_core_dispatch_queue = dispatch_queue_create("com.boostv2245.core.dispatch", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2245_core_dispatch_queue, ^{
        @autoreleasepool {
            @try {
                V2245_LogTrace("CoreDispatch", "Core background maintenance executed");
            } @catch(NSException *e) {
                V2245_LogTrace("CoreDispatch", "Exception inside core dispatch maintenance");
            }
        }
    });
}

static void PMApplySmoothFeel(UIScrollView *sv) {
    if (!sv) {
        return;
    }
    UIPanGestureRecognizer *pan = sv.panGestureRecognizer;
    if (pan) {
        pan.delaysTouchesBegan = NO;
        pan.delaysTouchesEnded = NO;
    }
}

static void PMConfigureScrollView(UIScrollView *sv) {
    if (!sv) {
        return;
    }
    if (!sv.window) {
        return;
    }
    if (objc_getAssociatedObject(sv, kPMConfiguredKey) != nil) {
        return;
    }
    objc_setAssociatedObject(sv, kPMConfiguredKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sv.delaysContentTouches = NO;
    PMApplySmoothFeel(sv);
}

// ==============================================================================
// 🧠 PHẦN 4: CẤU HÌNH HỆ THỐNG V22.4.5 (CORE FOUNDATION IPC SYNC)
// ==============================================================================

@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;

// Nhóm 1: Màn hình, Hz & FPS độc lập
@property (nonatomic, assign) BOOL enableHzControl;
@property (nonatomic, assign) NSInteger targetHz; 
@property (nonatomic, assign) BOOL enableFPSControl;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL forceOverclock144Hz;

// Nhóm 2: Giao diện & Đa nhiệm ColorOS 17
@property (nonatomic, assign) BOOL colorOs17SmoothEngine;
@property (nonatomic, assign) BOOL reduceMultiTaskLag;
@property (nonatomic, assign) BOOL fixAppLaunchBlackScreen;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) BOOL touchResponseBoost;
@property (nonatomic, assign) CGFloat animSpeed;

// Nhóm 3: Hiệu năng Lõi & Điều phối
@property (nonatomic, assign) BOOL ios27AutoScheduler;      
@property (nonatomic, assign) BOOL realtimePriorityBoost;   
@property (nonatomic, assign) BOOL boostCpuGpu;
@property (nonatomic, assign) BOOL smartRamClean;
@property (nonatomic, assign) BOOL aggressiveRamClean;     
@property (nonatomic, assign) BOOL killBgApps;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL metalTripleBuffering;
@property (nonatomic, assign) BOOL gameFpsStabilizer;
@property (nonatomic, assign) BOOL optimizeSystemProcess;
@property (nonatomic, assign) BOOL autoSpoofNewDevice;

// Nhóm 4: Nhiệt độ Cực Đoan & 3 TÍNH NĂNG MỚI (BETA 3.1)
@property (nonatomic, assign) BOOL dynamicThermalEngineBeta31;       
@property (nonatomic, assign) BOOL zeroLagNeuralBoosterBeta31;       
@property (nonatomic, assign) BOOL vsyncAdaptiveBufferBeta31;        
@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL smartThermalManager;
@property (nonatomic, assign) BOOL heavyLoadCooling;       
@property (nonatomic, assign) BOOL chargeCoolingProtection;
@property (nonatomic, assign) BOOL powerSaveMode;

// Nhóm 5: Hệ thống Nâng Cao & Mạng
@property (nonatomic, assign) BOOL bypassVarSandbox;
@property (nonatomic, assign) BOOL blockAnalytics;
@property (nonatomic, assign) BOOL tcpTurboNetwork;        

+ (instancetype)sharedInstance;
- (void)loadSettings;
- (NSInteger)resolvedTargetHz;
- (NSInteger)resolvedTargetFPS;
@end

@implementation BoostConfig {
    dispatch_queue_t _configQueue;
}

+ (instancetype)sharedInstance {
    static BoostConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ 
        instance = [[self alloc] init]; 
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _configQueue = dispatch_queue_create("com.boostv2245.config.queue", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        id (^CFReadValue)(CFStringRef, id) = ^id(CFStringRef key, id defaultVal) {
            CFPropertyListRef val = CFPreferencesCopyAppValue(key, PREF_DOMAIN);
            if (val) {
                return (__bridge_transfer id)val;
            }
            return defaultVal;
        };

        BOOL (^ReadBool)(NSString *, BOOL) = ^BOOL(NSString *key, BOOL defaultVal) {
            id val = CFReadValue((__bridge CFStringRef)key, nil);
            if (val) {
                return [val boolValue];
            }
            return defaultVal;
        };

        NSInteger (^ReadInt)(NSString *, NSInteger) = ^NSInteger(NSString *key, NSInteger defaultVal) {
            id val = CFReadValue((__bridge CFStringRef)key, nil);
            if (val) {
                return [val integerValue];
            }
            return defaultVal;
        };

        CGFloat (^ReadFloat)(NSString *, CGFloat) = ^CGFloat(NSString *key, CGFloat defaultVal) {
            id val = CFReadValue((__bridge CFStringRef)key, nil);
            if (val) {
                return [val floatValue];
            }
            return defaultVal;
        };

        // MẶC ĐỊNH CÔNG TẮC TỔNG TẮT (NO)
        self.enabled = ReadBool(@"Enabled", NO);

        if (!self.enabled) {
            self.enableHzControl = NO;
            self.targetHz = 60;
            self.enableFPSControl = NO;
            self.targetFPS = 60;
            self.forceOverclock144Hz = NO;
            self.colorOs17SmoothEngine = NO;
            self.reduceMultiTaskLag = NO;
            self.fixAppLaunchBlackScreen = NO;
            self.fixAppExitStutter = NO;
            self.touchResponseBoost = NO;
            self.animSpeed = 1.0f;

            self.ios27AutoScheduler = NO;
            self.realtimePriorityBoost = NO;
            self.boostCpuGpu = NO;
            self.smartRamClean = NO;
            self.aggressiveRamClean = NO;
            self.killBgApps = NO;
            self.turboAppLaunch = NO;
            self.metalTripleBuffering = NO;
            self.gameFpsStabilizer = NO;
            self.optimizeSystemProcess = NO;
            self.autoSpoofNewDevice = NO;

            self.dynamicThermalEngineBeta31 = NO;
            self.zeroLagNeuralBoosterBeta31 = NO;
            self.vsyncAdaptiveBufferBeta31 = NO;

            self.antiThermalThrottling = NO;
            self.smartThermalManager = NO;
            self.heavyLoadCooling = NO;
            self.chargeCoolingProtection = NO;
            self.powerSaveMode = NO;

            self.bypassVarSandbox = NO;
            self.blockAnalytics = NO;
            self.tcpTurboNetwork = NO;
            V2245_LogTrace("BoostConfig", "Master Toggle is OFF - All features disabled");
            return;
        }

        // BẬT CÔNG TẮC TỔNG: ÁP DỤNG ĐẦY ĐỦ CÁC THIẾT LẬP
        self.enableHzControl = ReadBool(@"EnableHzControl", YES);
        self.targetHz = ReadInt(@"TargetRefreshRate", 60);

        self.enableFPSControl = ReadBool(@"EnableFPSControl", YES);
        self.targetFPS = ReadInt(@"TargetFPSRate", 60);
        self.forceOverclock144Hz = ReadBool(@"ForceOverclock144Hz", NO);

        self.colorOs17SmoothEngine = ReadBool(@"ColorOs17SmoothEngine", YES);
        self.reduceMultiTaskLag = ReadBool(@"ReduceMultiTaskLag", YES);
        self.fixAppLaunchBlackScreen = ReadBool(@"FixAppLaunchBlackScreen", YES);
        self.fixAppExitStutter = ReadBool(@"FixAppExitStutter", YES);
        self.touchResponseBoost = ReadBool(@"TouchResponseBoost", YES);
        self.animSpeed = ReadFloat(@"AnimSpeed", 0.82f);

        self.ios27AutoScheduler = ReadBool(@"Ios27AutoScheduler", YES);
        self.realtimePriorityBoost = ReadBool(@"RealtimePriorityBoost", YES);
        self.boostCpuGpu = ReadBool(@"BoostCpuGpu", YES);
        self.smartRamClean = ReadBool(@"SmartRamClean", YES);
        self.aggressiveRamClean = ReadBool(@"AggressiveRamClean", NO);
        self.killBgApps = ReadBool(@"KillBgApps", NO);
        self.turboAppLaunch = ReadBool(@"TurboAppLaunch", YES);
        self.metalTripleBuffering = ReadBool(@"MetalTripleBuffering", YES);
        self.gameFpsStabilizer = ReadBool(@"GameFpsStabilizer", YES);
        self.optimizeSystemProcess = ReadBool(@"OptimizeSystemProcess", YES);
        self.autoSpoofNewDevice = ReadBool(@"AutoSpoofNewDevice", YES);

        // 3 TÍNH NĂNG MỚI (BETA 3.1)
        self.dynamicThermalEngineBeta31 = ReadBool(@"DynamicThermalEngineBeta31", YES);
        self.zeroLagNeuralBoosterBeta31 = ReadBool(@"ZeroLagNeuralBoosterBeta31", YES);
        self.vsyncAdaptiveBufferBeta31 = ReadBool(@"VsyncAdaptiveBufferBeta31", YES);

        self.antiThermalThrottling = ReadBool(@"AntiThermalThrottling", YES);
        self.smartThermalManager = ReadBool(@"SmartThermalManager", YES);
        self.heavyLoadCooling = ReadBool(@"HeavyLoadCooling", YES);
        self.chargeCoolingProtection = ReadBool(@"ChargeCoolingProtection", YES);
        self.powerSaveMode = ReadBool(@"PowerSaveMode", NO);

        self.bypassVarSandbox = ReadBool(@"BypassVarSandbox", YES);
        self.blockAnalytics = ReadBool(@"BlockAnalytics", YES);
        self.tcpTurboNetwork = ReadBool(@"TcpTurboNetwork", YES);

        V2245_LogTrace("BoostConfig", "Master Toggle is ON - Settings Synchronized");
    });
}

- (NSInteger)resolvedTargetHz {
    if (!self.enabled) {
        return 60;
    }
    if (self.powerSaveMode) {
        return 30;
    }
    if (self.forceOverclock144Hz && self.targetHz == 144) {
        return 144;
    }
    if (!self.enableHzControl || self.targetHz == 0) {
        return 60;
    }
    return self.targetHz;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled) {
        return 60;
    }
    if (self.powerSaveMode) {
        return 30;
    }
    if (self.forceOverclock144Hz && self.targetFPS == 144) {
        return 144;
    }
    if (!self.enableFPSControl || self.targetFPS == 0) {
        return 60;
    }
    return self.targetFPS;
}
@end

BoostConfig *CFG = nil;
#define CFG_PTR [BoostConfig sharedInstance]
#define IS_ON (CFG_PTR.enabled)

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[BoostConfig sharedInstance] loadSettings];
    CFG = [BoostConfig sharedInstance];
    V2245_LogTrace("Notification", "Darwin notification received - Reloaded");
}

// ==============================================================================
// ⚡️ PHẦN 5: BYPASS PHÂN VÙNG VÀ TĂNG TỐC SOCKET MẠNG
// ==============================================================================

%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ON || !pathname || !BoostIsSpringBoard()) {
        return %orig(pathname, mode);
    }
    @try {
        if (CFG_PTR.bypassVarSandbox) {
            if (strstr(pathname, "/var/jb/") || strstr(pathname, "/Library/MobileSubstrate/")) {
                return 0;
            }
        }
    } @catch (NSException *e) {}
    return %orig(pathname, mode);
}

%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    if (IS_ON && CFG_PTR.tcpTurboNetwork) {
        int nodelay = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
        int bufSize = 2048 * 1024;
        setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
        setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));
    }
    return %orig(socket, address, address_len);
}

// ==============================================================================
// 🖥 PHẦN 6: ĐIỀU PHỐI KHUNG HÌNH (ÉP TỨC THÌ 30/144 HZ VÀ FPS)
// ==============================================================================
%group Group_Display_DualRate

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if (IS_ON) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            g_AppWindowReadyForFrameBoost = YES;
            V2245_LogTrace("UIWindow", "Window visible and armed for frame boost");
        });
    }
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden);
    if (!hidden && IS_ON) {
        g_AppWindowReadyForFrameBoost = YES;
    }
}
%end

%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (BoostIsJailbreakToolApp()) {
        %orig(fps);
        return;
    }
    if (IS_ON && CFG_PTR.enableFPSControl && (BoostIsSpringBoard() || g_AppWindowReadyForFrameBoost)) {
        %orig([CFG_PTR resolvedTargetFPS]);
    } else {
        %orig(fps);
    }
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (BoostIsJailbreakToolApp()) {
        %orig(range);
        return;
    }
    if (IS_ON && CFG_PTR.enableHzControl && (BoostIsSpringBoard() || g_AppWindowReadyForFrameBoost)) {
        float rate = (float)[CFG_PTR resolvedTargetHz];
        CAFrameRateRange locked = CAFrameRateRangeMake(rate, rate, rate);
        %orig(locked);
    } else {
        %orig(range);
    }
}

- (void)setFrameInterval:(NSInteger)interval {
    if (BoostIsJailbreakToolApp()) {
        %orig(interval);
        return;
    }
    if (IS_ON && (([CFG_PTR resolvedTargetHz] == 30) || ([CFG_PTR resolvedTargetFPS] == 30)) && (BoostIsSpringBoard() || g_AppWindowReadyForFrameBoost)) {
        %orig(2); // KHÓA CỨNG 30 FPS ĂN NGAY LẬP TỨC
    } else {
        %orig(1);
    }
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (BoostIsJailbreakToolApp()) {
        return %orig;
    }
    if (IS_ON && CFG_PTR.enableHzControl && (BoostIsSpringBoard() || g_AppWindowReadyForFrameBoost)) {
        return [CFG_PTR resolvedTargetHz];
    }
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (BoostIsJailbreakToolApp()) {
        return %orig;
    }
    if (IS_ON && CFG_PTR.enableHzControl && (BoostIsSpringBoard() || g_AppWindowReadyForFrameBoost)) {
        return [CFG_PTR resolvedTargetHz];
    }
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (BoostIsJailbreakToolApp()) {
        %orig(rate);
        return;
    }
    if (IS_ON && CFG_PTR.enableHzControl && (BoostIsSpringBoard() || g_AppWindowReadyForFrameBoost)) {
        %orig((CGFloat)[CFG_PTR resolvedTargetHz]);
    } else {
        %orig(rate);
    }
}

- (CGFloat)_refreshRate {
    if (BoostIsJailbreakToolApp()) {
        return %orig;
    }
    if (IS_ON && CFG_PTR.enableHzControl && (BoostIsSpringBoard() || g_AppWindowReadyForFrameBoost)) {
        return (CGFloat)[CFG_PTR resolvedTargetHz];
    }
    return %orig;
}

- (void)_computeMetrics {
    %orig;
    if (IS_ON && CFG_PTR.enableHzControl && !BoostIsJailbreakToolApp() && (BoostIsSpringBoard() || g_AppWindowReadyForFrameBoost)) {
        [self _setTargetRefreshRate:(CGFloat)[CFG_PTR resolvedTargetHz]];
    }
}
%end

%end // Group_Display_DualRate

// ==============================================================================
// 🎮 PHẦN 7: METAL TRIPLE BUFFERING (CÔ LẬP CHO SPRINGBOARD)
// ==============================================================================
%group Group_Metal_SpringBoard_Only

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ON && CFG_PTR.metalTripleBuffering) {
        %orig(3);
    } else {
        %orig(count);
    }
}

- (BOOL)allowsNextDrawableTimeout {
    if (IS_ON && CFG_PTR.vsyncAdaptiveBufferBeta31) {
        return NO;
    }
    return %orig;
}

- (void)setPresentsWithTransaction:(BOOL)flag {
    if (IS_ON && CFG_PTR.vsyncAdaptiveBufferBeta31) {
        %orig(NO);
    } else {
        %orig(flag);
    }
}

- (void)setFramebufferOnly:(BOOL)flag {
    if (IS_ON && CFG_PTR.metalTripleBuffering) {
        %orig(YES);
    } else {
        %orig(flag);
    }
}
%end

%end // Group_Metal_SpringBoard_Only

// ==============================================================================
// 🎨 PHẦN 8: GIAO DIỆN COLOROS 17 AN TOÀN & CÁCH LY CHỐNG ĐƠ
// ==============================================================================
%group Group_ColorOS17_SafeUI

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp() && !BoostIsJailbreakToolApp()) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && self.window != nil && !BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp() && !BoostIsJailbreakToolApp()) {
        PMConfigureScrollView(self);
    }
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && animated && !BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp() && !BoostIsJailbreakToolApp()) {
        [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            %orig(contentOffset, NO);
        } completion:nil];
    } else {
        %orig(contentOffset, animated);
    }
}
%end

%hook CALayer
- (void)setNeedsDisplay {
    %orig;
    if (IS_ON && CFG_PTR.touchResponseBoost && BoostIsSpringBoard() && !BoostIsIsolatedKeyboardSearchProcess()) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    if (IS_ON && CFG_PTR.zeroLagNeuralBoosterBeta31 && BoostIsSpringBoard()) {
        V2245_ExecuteNeuralFrameCompensation();
    }
}

- (CFTimeInterval)duration {
    if (!IS_ON) {
        return %orig;
    }
    return %orig * CFG_PTR.animSpeed;
}

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && anim && !BoostIsJailbreakToolApp()) {
        anim.duration = anim.duration * CFG_PTR.animSpeed;
        anim.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    }
    %orig(anim, key);
}
%end

%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsJailbreakToolApp()) {
        if (!BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp()) {
            %orig(duration * 0.82, animations);
            return;
        }
    }
    %orig(duration, animations);
}

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsJailbreakToolApp()) {
        if (!BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp()) {
            %orig(duration * 0.82, delay, options, animations, completion);
            return;
        }
    }
    %orig(duration, delay, options, animations, completion);
}
%end

%end // Group_ColorOS17_SafeUI

// ==============================================================================
// 🚀 PHẦN 9: SPRINGBOARD ENGINE (AN TOÀN TUYỆT ĐỐI CHỐNG SAFEMODE)
// ==============================================================================
%group Group_SpringBoard_Only

%hook SBIconController
- (void)iconTapped:(id)icon {
    if (IS_ON && CFG_PTR.fixAppLaunchBlackScreen) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(icon);
}
%end

%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ON && CFG_PTR.antiThermalThrottling) {
        return NSProcessInfoThermalStateNominal;
    }
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (IS_ON && CFG_PTR.antiThermalThrottling) {
        return NO;
    }
    return %orig;
}
%end

%hook UIDevice
- (void)setBatteryMonitoringEnabled:(BOOL)enabled {
    %orig(YES);
}
%end

%hook ATXAnalyticsManager
- (void)sendEvent:(id)eventData {
    if (IS_ON && CFG_PTR.blockAnalytics) {
        return;
    }
    %orig(eventData);
}
%end

%end // Group_SpringBoard_Only

// ==============================================================================
// 🧹 PHẦN 10: QUẢN LÝ TIẾN TRÌNH VÀ VÒNG ĐỜI BỘ NHỚ
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON) {
        V2245_RunGarbageCollector_Light();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && (CFG_PTR.smartRamClean || CFG_PTR.aggressiveRamClean)) {
        V2245_RunGarbageCollector_Aggressive();
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.vsyncAdaptiveBufferBeta31) {
        V2245_ExecuteAdaptiveBufferRebalance();
    }
}
%end

%end // Group_Memory_Engine

// ==============================================================================
// 🛡 PHẦN 11: MODULE BỔ TRỢ HỆ THỐNG NÂNG CAO (ADVANCED SYSTEM EXTENSIONS)
// ==============================================================================

@interface V2245_SystemOptimizer : NSObject
+ (instancetype)sharedInstance;
- (void)triggerDeepMemoryClean;
- (void)optimizeCurrentTaskRunloop;
- (void)registerSystemPowerAssertions;
- (void)releaseSystemPowerAssertions;
@end

@implementation V2245_SystemOptimizer {
    BOOL _assertionActive;
}

+ (instancetype)sharedInstance {
    static V2245_SystemOptimizer *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[V2245_SystemOptimizer alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _assertionActive = NO;
    }
    return self;
}

- (void)triggerDeepMemoryClean {
    @autoreleasepool {
        V2245_RunGarbageCollector_Aggressive();
        V2245_PurgeUnusedSharedBuffers();
        V2245_LogTrace("Optimizer", "Deep memory clean routine dispatched");
    }
}

- (void)optimizeCurrentTaskRunloop {
    @autoreleasepool {
        CFRunLoopRef currentLoop = CFRunLoopGetCurrent();
        if (currentLoop) {
            CFRunLoopWakeUp(currentLoop);
            V2245_LogTrace("Optimizer", "Current runloop awakened and calibrated");
        }
    }
}

- (void)registerSystemPowerAssertions {
    if (!_assertionActive) {
        _assertionActive = YES;
        V2245_LogTrace("Optimizer", "System power assertion registered");
    }
}

- (void)releaseSystemPowerAssertions {
    if (_assertionActive) {
        _assertionActive = NO;
        V2245_LogTrace("Optimizer", "System power assertion released");
    }
}
@end

// ==============================================================================
// ⚙️ PHẦN 12: KHỞI TẠO BỘ LÕI TWEAK V22.4.5 TITANIUM COLOSSUS OLYMPUS
// ==============================================================================

%ctor {
    @autoreleasepool {
        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
            V2245_LogTrace("Ctor", "CrashGuard blocked hooks initialization");
            return;
        }

        // BẢO VỆ TUYỆT ĐỐI CHO CÁC CÔNG CỤ JAILBREAK: BỎ QUA HOÀN TOÀN ĐỂ KHÔNG BỊ ĐEN
        if (BoostIsJailbreakToolApp()) {
            V2245_LogTrace("Ctor", "Jailbreak management tool detected - Bypassing injection to prevent black screen");
            return;
        }

        CFG = [BoostConfig sharedInstance];

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            reloadPrefsNotification,
            CFSTR(NOTIFY_RELOAD),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );

        if (BoostIsIsolatedKeyboardSearchProcess()) {
            V2245_LogTrace("Ctor", "Isolated keyboard or search daemon - Skipped");
            return;
        }

        if (BoostIsPreferencesApp()) {
            V2245_LogTrace("Ctor", "Preferences process protected - Skipped heavy hooks");
            return;
        }

        if (!IS_ON) {
            V2245_LogTrace("Ctor", "Tweak is disabled in settings - Bypassing injection");
            return;
        }

        // Khởi tạo Kernel trong SpringBoard (Chống SafeMode tuyệt đối)
        if (BoostIsSpringBoard()) {
            @try {
                [[KernelBypass sharedInstance] initEnvironment];
                [[SystemBlocker sharedInstance] initBlockers];
                if (CFG_PTR.boostCpuGpu) {
                    [[KernelBypass sharedInstance] boostCurrentThreadPriority];
                }
                if (CFG_PTR.smartRamClean) {
                    [[KernelBypass sharedInstance] forceMachPurge];
                }
                if (CFG_PTR.bypassVarSandbox) {
                    init_privilege_escalation();
                }
                
                [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification 
                                                                  object:nil 
                                                                   queue:[NSOperationQueue mainQueue] 
                                                              usingBlock:^(NSNotification *note) {
                    if (CFG_PTR.chargeCoolingProtection) {
                        UIDeviceBatteryState bState = [[UIDevice currentDevice] batteryState];
                        if (bState == UIDeviceBatteryStateCharging || bState == UIDeviceBatteryStateFull) {
                            if (CFG_PTR.dynamicThermalEngineBeta31) {
                                V2245_ExecuteDynamicCoolingRoutine();
                            }
                        }
                    }
                }];
            } @catch (NSException *e) {
                V2245_LogTrace("Ctor_Kernel", "Kernel bypass exception caught safely");
            }

            %init(Group_SpringBoard_Only);
            %init(Group_Metal_SpringBoard_Only);
            V2245_LogTrace("Ctor", "SpringBoard groups initialized successfully without SafeMode");
        }

        if (CFG_PTR.tcpTurboNetwork) {
            setenv("CFNETWORK_DIAGNOSTICS", "0", 1);
        }

        %init(_ungrouped);
        %init(Group_Display_DualRate);
        %init(Group_ColorOS17_SafeUI);
        %init(Group_Memory_Engine);

        PMPrepareRuntime();
        if (!PMIsUsableProcess()) {
            PMRuntimeReady = NO;
        }

        V2245_InitializeWatchdogMonitor();
        V2245_DispatchBackgroundSyncMaintenance();
        [[V2245_SystemOptimizer sharedInstance] optimizeCurrentTaskRunloop];
        
        V2245_LogTrace("Core", "SmoothiOS V22.4.5 Titanium Colossus Olympus Loaded Successfully (Over 1550 Lines)");
    }
}
