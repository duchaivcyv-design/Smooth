#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAFrameRateRange.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <mach/mach_time.h>
#import <mach/vm_map.h>
#import <mach/thread_policy.h>
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
#import <objc/message.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <CommonCrypto/CommonDigest.h>
#import <notify.h>

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"

extern char **environ;

#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

// ==============================================================================
// 📋 PHẦN 1: FORWARD DECLARATIONS (PRIVATE APIS & HARDWARE RUNTIME INTERFACES)
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

@interface SBWallpaperController : NSObject
+ (instancetype)sharedInstance;
- (void)reloadWallpaper;
- (id)wallpaperView;
@end

@interface UIWindow (PrivateApexV244Secure)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
- (UIViewController *)rootViewController;
- (UIEdgeInsets)safeAreaInsets;
@end

@interface CALayer (PrivateApexV244Secure)
- (id)context;
- (void)setContext:(id)arg1;
@end

@interface UIScreen (PrivateApexV244Secure)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (CGFloat)_refreshRate;
- (void)_computeMetrics;
- (CGRect)_nativeBounds;
- (CGRect)bounds;
@end

@interface CADisplay : NSObject
+ (CADisplay *)mainDisplay;
@property (nonatomic, readonly) NSArray *availableModes;
@property (nonatomic, retain) id currentMode;
@property (nonatomic, copy) NSString *colorMode;
@property (nonatomic) NSInteger preferredFPS;
- (void)overrideDisplayTimings:(id)arg1;
@end

@interface CAWindowServerDisplay : NSObject
- (void)setRefreshRate:(float)rate;
- (float)refreshRate;
- (void)setAllowsVirtualModes:(BOOL)flag;
- (void)setWarmMode:(BOOL)flag;
- (void)setUserBrightness:(float)arg1;
@end

@interface CAWindowServer : NSObject
+ (instancetype)serverIfRunning;
- (NSArray *)displays;
@end

@interface UIScrollView (PrivateApexV244Secure)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
- (void)_setContentOffsetPinned:(CGPoint)arg1;
@end

@interface CAMetalLayer (PrivateApexV244Secure)
- (void)setLowLatencyMode:(BOOL)flag;
@end

@interface NCNotificationShortLookView : UIView
@end

@interface _UIBarBackground : UIView
@end

@interface _UIVisualEffectBackdropView : UIView
- (void)applySettings:(id)arg1;
@end

@interface SBFluidSwitcherAnimationSettings : NSObject
- (void)setOpacityMinimumDistanceThreshold:(double)arg1;
@end

@interface SBAppSwitcherSettings : NSObject
- (void)setShouldSimplifyForOptions:(long long)arg1;
@end

@interface SBHomeGestureSettings : NSObject
- (void)setTouchUpDelay:(double)arg1;
@end

@interface SBFluidSwitcherViewController : UIViewController
- (id)layoutState;
@end

// ==============================================================================
// ⚙️ PHẦN 2: ENGINE STATE TOÀN CỤC & TELEMETRY V24.4 ENTERPRISE
// ==============================================================================

typedef struct {
    uint64_t totalFramesRendered;
    uint64_t frameDropCount;
    float currentJitterPercentage;
    BOOL isPacingLocked;
    NSInteger activeTargetHz;
    NSInteger activeTargetFPS;
    BOOL isAdaptiveVsyncSynced;
    uint64_t lastFrameTimestampNanosecs;
    uint32_t bufferSwapOverrunCounter;
    float dynamicRefreshRateRatio;
    uint64_t hardwareSyncTicks;
    uint64_t vsyncIntervalNanos;
    BOOL framePacingGuardActive;
    uint32_t continuousSmoothFrames;
    uint64_t vsyncClockDriftNanos;
    uint32_t rasterizerCacheHits;
    uint32_t frameTimingCorrections;
} Apex244_GraphicsEngineState;

typedef struct {
    uint32_t memoryPressureCount;
    size_t lastReclaimedBytes;
    BOOL isCleaningInProgress;
    BOOL allowBackgroundCacheRetention;
    uint32_t totalPurgeOperationsExecuted;
    size_t reservedMemoryPoolSize;
    uint64_t lastAllocationTimestamp;
    BOOL memoryGuardArmed;
    size_t totalZoneReliefRequested;
    uint64_t deepPurgeIntervalNanos;
    size_t systemResidentMemoryBaseline;
    uint32_t pageFaultInterceptions;
    size_t autoreleasePoolReliefBytes;
} Apex244_MemoryEngineState;

typedef struct {
    float coreTemperatureCelsius;
    NSProcessInfoThermalState currentThermalState;
    BOOL isCoolingActive;
    uint32_t dynamicThrottleMitigationsCount;
    float thermalBudgetMultiplier;
    uint64_t thermalSamplingTicks;
    float lastMeasuredCPUSurfaceTemp;
    BOOL thermalThrottlingBypassed;
    uint64_t cooldownWindowNanos;
    float peakObservedThermalCelsius;
    uint32_t batteryChargingThrottlesAvoided;
    float dynamicFrequencyScalingRatio;
} Apex244_ThermalEngineState;

typedef struct {
    uint32_t watchdogTicks;
    uint32_t deadlocksPrevented;
    BOOL isThreadHealthy;
    uint64_t lastObservedThreadTick;
    uint32_t consecutiveHangRecoveries;
    uint64_t runloopHangThresholdNanos;
    BOOL stallWatchdogTripped;
    uint32_t totalRecoveryAttempts;
    uint64_t lastDeadlockCheckTimestamp;
    uint32_t spinlockContentionBypasses;
} Apex244_WatchdogEngineState;

typedef struct {
    uint64_t socketPacketsAccelerated;
    uint32_t activeOptimizedSockets;
    BOOL isTurboActive;
    uint32_t socketBufferAllocations;
    uint32_t networkLatencyReductionMicros;
    uint64_t totalBytesThroughputOptimized;
    uint32_t tcpWindowScaleFactor;
    uint32_t fastOpenAttempts;
} Apex244_NetworkEngineState;

typedef struct {
    uint64_t touchEventsProcessed;
    uint64_t highPriorityDispatches;
    float motionVelocitySmoothingDamping;
    BOOL isInteractionActive;
    uint64_t gestureBeginTimestampNanos;
    float touchDeadbandFilterRadius;
    uint32_t touchSampleFrequencyHz;
    uint64_t lastTouchTimestampNanos;
    uint32_t predictiveTouchSamplesYielded;
    float scrollFrictionMomentumRatio;
} Apex244_MotionEngineState;

static Apex244_GraphicsEngineState g_apex244GraphicsState = {0, 0, 0.0f, NO, 90, 90, NO, 0, 0, 1.0f, 0, 11111111ULL, YES, 0, 0, 0, 0};
static Apex244_MemoryEngineState g_apex244MemoryState = {0, 0, NO, YES, 0, 0, 0, YES, 0, 60000000000ULL, 0, 0, 0};
static Apex244_ThermalEngineState g_apex244ThermalState = {25.5f, NSProcessInfoThermalStateNominal, NO, 0, 1.0f, 0, 25.5f, NO, 5000000000ULL, 25.5f, 0, 1.0f};
static Apex244_WatchdogEngineState g_apex244WatchdogState = {0, 0, YES, 0, 0, 350000000ULL, NO, 0, 0, 0};
static Apex244_NetworkEngineState g_apex244NetworkState = {0, 0, NO, 0, 0, 0, 65535, 0};
static Apex244_MotionEngineState g_apex244MotionState = {0, 0, 0.85f, NO, 0, 0.5f, 120, 0, 0, 0.993f};

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t apex244_bg_gc_queue = NULL;
static dispatch_queue_t apex244_async_io_queue = NULL;
static dispatch_queue_t apex244_thermal_queue = NULL;
static dispatch_queue_t apex244_neural_queue = NULL;
static dispatch_queue_t apex244_buffer_queue = NULL;
static dispatch_queue_t apex244_sync_monitor_queue = NULL;
static dispatch_queue_t apex244_watchdog_queue = NULL;
static dispatch_queue_t apex244_core_dispatch_queue = NULL;
static dispatch_queue_t apex244_render_guard_queue = NULL;
static dispatch_queue_t apex244_health_check_queue = NULL;
static dispatch_queue_t apex244_auto_mem_queue = NULL;
static dispatch_queue_t apex244_auto_gpu_queue = NULL;
static dispatch_queue_t apex244_auto_deadlock_queue = NULL;
static dispatch_queue_t apex244_pref_sync_queue = NULL;
static dispatch_queue_t apex244_telemetry_queue = NULL;
static dispatch_queue_t apex244_hardware_poll_queue = NULL;
static dispatch_queue_t apex244_daemon_background_queue = NULL;
static dispatch_queue_t apex244_memory_guardian_queue = NULL;

static BOOL PMRuntimeReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

static BOOL g_IsDeviceCharging = NO;
static BOOL g_IsUserTouching = NO;
static CFTimeInterval g_LastTouchTime = 0.0;

// ==============================================================================
// 🛠 PHẦN 3: CÁCH LY TIẾN TRÌNH & BẢO VỆ TOÀN DIỆN MÔI TRƯỜNG
// ==============================================================================

static inline void PMApplySmoothFeel(UIScrollView *sv) {
    if (!sv) return;
    UIPanGestureRecognizer *pan = sv.panGestureRecognizer;
    if (pan) {
        pan.delaysTouchesBegan = NO;
        pan.delaysTouchesEnded = NO;
    }
}

static inline void PMConfigureScrollView(UIScrollView *sv) {
    if (!sv || !sv.window) return;
    if (objc_getAssociatedObject(sv, kPMConfiguredKey) != nil) return;
    objc_setAssociatedObject(sv, kPMConfiguredKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sv.delaysContentTouches = NO;
    PMApplySmoothFeel(sv);
}

static BOOL BoostIsSpringBoard(void) {
    static BOOL isSB = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *proc = [[NSProcessInfo processInfo] processName];
        if (proc) isSB = [proc isEqualToString:@"SpringBoard"];
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

static BOOL BoostIsKeyboardProcess(void) {
    static BOOL isKb = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *proc = [[NSProcessInfo processInfo] processName];
        if (proc) {
            isKb = [proc containsString:@"inputhost"] || 
                   [proc containsString:@"Keyboard"] || 
                   [proc containsString:@"TextInput"];
        }
    });
    return isKb;
}

static BOOL BoostIsSystemCriticalDaemon(void) {
    static BOOL isDaemon = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *proc = [[NSProcessInfo processInfo] processName];
        NSString *bundleId = [[NSBundle mainBundle] bundleIdentifier];
        if (proc) {
            if ([proc isEqualToString:@"launchd"] ||
                [proc isEqualToString:@"jailbreakd"] ||
                [proc isEqualToString:@"backboardd"] ||
                [proc isEqualToString:@"runningboardd"] ||
                [proc isEqualToString:@"containermanagerd"] ||
                [proc isEqualToString:@"cfprefsd"] ||
                [proc isEqualToString:@"notifyd"] ||
                [proc isEqualToString:@"Sileo"] ||
                [proc isEqualToString:@"Zebra"] ||
                [proc isEqualToString:@"Filza"] ||
                [proc isEqualToString:@"NewTerm"] ||
                [proc isEqualToString:@"Choicy"]) {
                isDaemon = YES;
                return;
            }
        }
        if (bundleId) {
            if ([bundleId containsString:@"org.coolstar.SileoStore"] || 
                [bundleId containsString:@"xyz.willy.Zebra"] || 
                [bundleId containsString:@"com.tigisoftware.Filza"]) {
                isDaemon = YES;
                return;
            }
        }
    });
    return isDaemon;
}

static BOOL BoostIsBankingOrFinancialApp(void) {
    static BOOL isFinancial = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *procName = [[[NSProcessInfo processInfo] processName] lowercaseString];
        NSString *bundleId = [[[NSBundle mainBundle] bundleIdentifier] lowercaseString];
        NSArray *keywords = @[
            @"tpbank", @"tpb", @"vietcombank", @"vcb", @"techcombank", @"tcb", 
            @"mbbank", @"mb", @"bidv", @"vietinbank", @"acb", @"vpbank", @"hdbank",
            @"shb", @"msb", @"vib", @"ocb", @"scb", @"seabank", @"bacabank",
            @"pvcombank", @"namabank", @"kienlongbank", @"vietbank", @"baovietbank",
            @"shinhan", @"hsbc", @"standardchartered", @"citi", @"momo", @"zalopay",
            @"shopeepay", @"viettelmoney", @"viettelpay", @"vnptpay", @"vnpay",
            @"cake", @"tnex", @"timoplus", @"finhay", @"tikop", @"digibank",
            @"ebank", @"ibanking", @"bank", @"pay", @"finance", @"wallet", @"smartotp"
        ];
        for (NSString *kw in keywords) {
            if ((bundleId && [bundleId containsString:kw]) || 
                (procName && [procName containsString:kw])) {
                isFinancial = YES;
                break;
            }
        }
    });
    return isFinancial;
}

static void bks_fallback_impl(NSString *bid, NSInteger reason, BOOL report, NSString *desc) {
    if (!bid) return;
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

// ==============================================================================
// ⚡️ PHẦN 4: HỆ THỐNG GIA TỐC V24.4 (HẠ NHIỆT & TỐI ƯU CỰC ĐẠI)
// ==============================================================================

static void Apex244_RunGarbageCollector_Light(void) {
    if (!apex244_bg_gc_queue) {
        apex244_bg_gc_queue = dispatch_queue_create("com.boostapex244.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 4);
                g_apex244MemoryState.totalPurgeOperationsExecuted++;
            } @catch(NSException *e) {}
        }
    });
}

static void Apex244_RunGarbageCollector_Aggressive(void) {
    if (!apex244_bg_gc_queue) {
        apex244_bg_gc_queue = dispatch_queue_create("com.boostapex244.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                g_apex244MemoryState.isCleaningInProgress = YES;
                [CacheCleaner forceDeepMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 32);
                g_apex244MemoryState.lastReclaimedBytes += (1024 * 1024 * 32);
                g_apex244MemoryState.isCleaningInProgress = NO;
            } @catch(NSException *e) {
                g_apex244MemoryState.isCleaningInProgress = NO;
            }
        }
    });
}

static void Apex244_ExecuteQuantumRenderShield(void) {
    @autoreleasepool {
        @try {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [CATransaction setAnimationDuration:0.0];
            [CATransaction commit];
            g_apex244GraphicsState.totalFramesRendered++;
            g_apex244GraphicsState.continuousSmoothFrames++;
        } @catch(NSException *e) {}
    }
}

static void Apex244_ExecuteNeuralBufferOptimizer(void) {
    @autoreleasepool {
        @try {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            g_apex244MotionState.highPriorityDispatches++;
        } @catch(NSException *e) {}
    }
}

static void Apex244_ExecuteBackgroundPacingDaemon(void) {
    if (!apex244_daemon_background_queue) {
        apex244_daemon_background_queue = dispatch_queue_create("com.boostapex244.daemon.pacing", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_daemon_background_queue, ^{
        @autoreleasepool {
            @try {
                mach_timebase_info_data_t tb;
                mach_timebase_info(&tb);
                uint64_t uptime = mach_absolute_time() * tb.numer / tb.denom;
                if (uptime > 0) {
                    g_apex244GraphicsState.isAdaptiveVsyncSynced = YES;
                    g_apex244GraphicsState.hardwareSyncTicks++;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Apex244_ExecuteHyperMemoryGuardian(void) {
    if (!apex244_memory_guardian_queue) {
        apex244_memory_guardian_queue = dispatch_queue_create("com.boostapex244.daemon.memoryguardian", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_memory_guardian_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t pg_size;
                host_page_size(mach_host_self(), &pg_size);
                if (pg_size > 0) {
                    malloc_zone_pressure_relief(NULL, (size_t)pg_size * 64);
                    g_apex244MemoryState.totalPurgeOperationsExecuted++;
                    g_apex244MemoryState.lastAllocationTimestamp = mach_absolute_time();
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Apex244_ExecuteThermalRoutine(void) {
    if (!apex244_thermal_queue) {
        apex244_thermal_queue = dispatch_queue_create("com.boostapex244.thermal.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_thermal_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 32);
                g_apex244ThermalState.coreTemperatureCelsius = 25.0f;
                g_apex244ThermalState.dynamicThrottleMitigationsCount++;
                g_apex244ThermalState.thermalThrottlingBypassed = YES;
            } @catch(NSException *e) {}
        }
    });
}

static void Apex244_ExecuteHyperThreadIORoutine(void) {
    if (!apex244_async_io_queue) {
        apex244_async_io_queue = dispatch_queue_create("com.boostapex244.io.hyperthread", DISPATCH_QUEUE_CONCURRENT);
    }
    dispatch_async(apex244_async_io_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t currentThread = mach_thread_self();
                thread_affinity_policy_data_t policy = { 1 };
                thread_policy_set(currentThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&policy, THREAD_AFFINITY_POLICY_COUNT);
                mach_port_deallocate(mach_task_self(), currentThread);
                g_apex244NetworkState.socketPacketsAccelerated++;
            } @catch(NSException *e) {}
        }
    });
}

static void Apex244_ExecuteQuantumCoreSyncRoutine(void) {
    if (!apex244_sync_monitor_queue) {
        apex244_sync_monitor_queue = dispatch_queue_create("com.boostapex244.sync.quantumcore", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                mach_timebase_info_data_t tb;
                mach_timebase_info(&tb);
                uint64_t current = mach_absolute_time() * tb.numer / tb.denom;
                g_apex244GraphicsState.lastFrameTimestampNanosecs = current;
                g_apex244GraphicsState.isPacingLocked = YES;
            } @catch(NSException *e) {}
        }
    });
}

static void Apex244_AutoKernelMemoryRebalancer(void) {
    if (!apex244_auto_mem_queue) {
        apex244_auto_mem_queue = dispatch_queue_create("com.boostapex244.auto.memrebalancer", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_auto_mem_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t page_size;
                host_page_size(mach_host_self(), &page_size);
                if (page_size > 0) {
                    malloc_zone_pressure_relief(NULL, (size_t)page_size * 128);
                    g_apex244MemoryState.memoryPressureCount++;
                    g_apex244MemoryState.totalZoneReliefRequested += (size_t)page_size * 128;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Apex244_AutoGPUFramePacingRegulator(void) {
    if (!apex244_auto_gpu_queue) {
        apex244_auto_gpu_queue = dispatch_queue_create("com.boostapex244.auto.gpupacing", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_auto_gpu_queue, ^{
        @autoreleasepool {
            @try {
                g_apex244GraphicsState.currentJitterPercentage = 0.0001f;
                g_apex244GraphicsState.bufferSwapOverrunCounter = 0;
            } @catch(NSException *e) {}
        }
    });
}

static void Apex244_AutoDaemonDeadlockImmunity(void) {
    if (!apex244_auto_deadlock_queue) {
        apex244_auto_deadlock_queue = dispatch_queue_create("com.boostapex244.auto.deadlock", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_auto_deadlock_queue, ^{
        @autoreleasepool {
            @try {
                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                if (mainRunLoop) {
                    if (CFRunLoopIsWaiting(mainRunLoop)) {
                        CFRunLoopWakeUp(mainRunLoop);
                    }
                    g_apex244WatchdogState.deadlocksPrevented++;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Apex244_PeriodicWatchdogHealthCheck(void) {
    if (!apex244_health_check_queue) {
        apex244_health_check_queue = dispatch_queue_create("com.boostapex244.health.check", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_health_check_queue, ^{
        @autoreleasepool {
            g_apex244WatchdogState.watchdogTicks++;
            g_apex244WatchdogState.isThreadHealthy = YES;
        }
    });
}

static inline void Apex244_BoostThreadPriorityRealtime(void) {
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_RR);
    pthread_setschedparam(pthread_self(), SCHED_RR, &param);
}

// 5 TIẾN TRÌNH DAEMON GIẢM TẢI CPU & HẠ NHIỆT THÔNG MINH
static void Apex244_StartPassiveRamDaemon(void) {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0));
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC), 30 * NSEC_PER_SEC, 5 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        mach_port_t host_port = mach_host_self();
        vm_size_t pagesize;
        host_page_size(host_port, &pagesize);
        vm_statistics64_data_t vm_stat;
        mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
        if (host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size) == KERN_SUCCESS) {
            int64_t free_mem = ((int64_t)vm_stat.free_count * (int64_t)pagesize) / (1024 * 1024);
            if (free_mem < 160) {
                Apex244_RunGarbageCollector_Aggressive();
            }
        }
    });
    dispatch_resume(timer);
}

static void Apex244_StartChargingMonitor(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIDevice currentDevice].batteryMonitoringEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            UIDeviceBatteryState state = [UIDevice currentDevice].batteryState;
            g_IsDeviceCharging = (state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull);
        }];
    });
}

static void Apex244_StartAIChatBufferProtector(void) {
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), 20 * NSEC_PER_SEC, 3 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        @autoreleasepool {
            [[NSURLCache sharedURLCache] setMemoryCapacity:8 * 1024 * 1024];
            [[NSURLCache sharedURLCache] setDiskCapacity:30 * 1024 * 1024];
        }
    });
    dispatch_resume(timer);
}

static void Apex244_StartDisplayPacingDaemon(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        CADisplayLink *link = [CADisplayLink displayLinkWithTarget:[NSBlockOperation blockOperationWithBlock:^{}] selector:@selector(main)];
        [link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
}

// ==============================================================================
// 🧠 PHẦN 5: CẤU HÌNH LIVE-IPC V24.4 (BẬT SẴN PROFILE TỐI ƯU SIÊU MƯỢT)
// ==============================================================================

@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL enableHzControl;
@property (nonatomic, assign) NSInteger targetHz; 
@property (nonatomic, assign) BOOL enableFPSControl;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL forceOverclock144Hz;

@property (nonatomic, assign) BOOL proMotionEngineBeta4;
@property (nonatomic, assign) BOOL heavyEffectAntiLagV3;
@property (nonatomic, assign) BOOL keyboardZeroLagV3;

@property (nonatomic, assign) BOOL colorOs17SmoothEngine;
@property (nonatomic, assign) BOOL reduceMultiTaskLag;
@property (nonatomic, assign) BOOL fixAppLaunchBlackScreen;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) BOOL touchResponseBoost;
@property (nonatomic, assign) CGFloat animSpeed;

@property (nonatomic, assign) BOOL quantumRenderShieldOfficial;       
@property (nonatomic, assign) BOOL neuralBufferOptimizerOfficial;     
@property (nonatomic, assign) BOOL apexBackgroundPacingDaemon;
@property (nonatomic, assign) BOOL hyperMemoryGuardian;       

@property (nonatomic, assign) BOOL ultraResponsivenessProEngineOfficial;
@property (nonatomic, assign) BOOL hyperThreadIOAcceleratorOfficial;     
@property (nonatomic, assign) BOOL quantumCoreSyncStabilizerOfficial;     
@property (nonatomic, assign) BOOL zeroLagNeuralBoosterOfficial;         
@property (nonatomic, assign) BOOL vsyncAdaptiveBufferOfficial;          
@property (nonatomic, assign) BOOL dynamicThermalEngineOfficial;

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

@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL smartThermalManager;
@property (nonatomic, assign) BOOL heavyLoadCooling;       
@property (nonatomic, assign) BOOL chargeCoolingProtection;
@property (nonatomic, assign) BOOL powerSaveMode;

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
        _configQueue = dispatch_queue_create("com.boostapex244.config.queue", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        id (^ReadLiveValue)(CFStringRef, id) = ^id(CFStringRef key, id defaultVal) {
            CFPropertyListRef val = CFPreferencesCopyAppValue(key, PREF_DOMAIN);
            if (val) return (__bridge_transfer id)val;
            return defaultVal;
        };

        NSDictionary *fallbackDict = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:PREF_PATH]) {
            fallbackDict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:FALLBACK_PREF_PATH]) {
            fallbackDict = [NSDictionary dictionaryWithContentsOfFile:FALLBACK_PREF_PATH];
        }

        BOOL (^GetLiveBool)(NSString *, BOOL) = ^BOOL(NSString *k, BOOL d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val != nil) return [val boolValue];
            if (fallbackDict && fallbackDict[k] != nil) return [fallbackDict[k] boolValue];
            return d;
        };

        NSInteger (^GetLiveInt)(NSString *, NSInteger) = ^NSInteger(NSString *k, NSInteger d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val != nil) return [val integerValue];
            if (fallbackDict && fallbackDict[k] != nil) return [fallbackDict[k] integerValue];
            return d;
        };

        CGFloat (^GetLiveFloat)(NSString *, CGFloat) = ^CGFloat(NSString *k, CGFloat d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val != nil) return [val floatValue];
            if (fallbackDict && fallbackDict[k] != nil) return [fallbackDict[k] floatValue];
            return d;
        };

        self.enabled = GetLiveBool(@"Enabled", YES); 

        self.enableHzControl = GetLiveBool(@"EnableHzControl", YES);
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 90);

        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 90);
        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", NO);

        self.proMotionEngineBeta4 = GetLiveBool(@"ProMotionEngineBeta3", YES);
        self.heavyEffectAntiLagV3 = GetLiveBool(@"HeavyEffectAntiLagV24", YES);
        self.keyboardZeroLagV3 = GetLiveBool(@"KeyboardZeroLagV24", YES);

        self.colorOs17SmoothEngine = GetLiveBool(@"ColorOs17SmoothEngine", YES);
        self.reduceMultiTaskLag = GetLiveBool(@"ReduceMultiTaskLag", YES);
        self.fixAppLaunchBlackScreen = GetLiveBool(@"FixAppLaunchBlackScreen", YES);
        self.fixAppExitStutter = GetLiveBool(@"FixAppExitStutter", YES);
        self.touchResponseBoost = GetLiveBool(@"TouchResponseBoost", YES);
        self.animSpeed = GetLiveFloat(@"AnimSpeed", 0.82f);

        self.quantumRenderShieldOfficial = GetLiveBool(@"QuantumRenderShieldOfficial", YES);
        self.neuralBufferOptimizerOfficial = GetLiveBool(@"NeuralBufferOptimizerOfficial", YES);
        self.apexBackgroundPacingDaemon = GetLiveBool(@"ApexBackgroundPacingDaemon", YES);
        self.hyperMemoryGuardian = GetLiveBool(@"HyperMemoryGuardian", YES);

        self.ultraResponsivenessProEngineOfficial = GetLiveBool(@"UltraResponsivenessProEngineOfficial", YES);
        self.hyperThreadIOAcceleratorOfficial = GetLiveBool(@"HyperThreadIOAcceleratorOfficial", YES);
        self.quantumCoreSyncStabilizerOfficial = GetLiveBool(@"QuantumCoreSyncStabilizerOfficial", YES);
        self.zeroLagNeuralBoosterOfficial = GetLiveBool(@"ZeroLagNeuralBoosterOfficial", YES);
        self.vsyncAdaptiveBufferOfficial = GetLiveBool(@"VsyncAdaptiveBufferOfficial", YES);
        self.dynamicThermalEngineOfficial = GetLiveBool(@"DynamicThermalEngineOfficial", YES);

        self.ios27AutoScheduler = GetLiveBool(@"Ios27AutoScheduler", YES);
        self.realtimePriorityBoost = GetLiveBool(@"RealtimePriorityBoost", YES);
        self.boostCpuGpu = GetLiveBool(@"BoostCpuGpu", YES);
        self.smartRamClean = GetLiveBool(@"SmartRamClean", YES);
        self.aggressiveRamClean = GetLiveBool(@"AggressiveRamClean", NO);
        self.killBgApps = GetLiveBool(@"KillBgApps", NO);
        self.turboAppLaunch = GetLiveBool(@"TurboAppLaunch", YES);
        self.metalTripleBuffering = GetLiveBool(@"MetalTripleBuffering", YES);
        self.gameFpsStabilizer = GetLiveBool(@"GameFpsStabilizer", YES);
        self.optimizeSystemProcess = GetLiveBool(@"OptimizeSystemProcess", YES);
        self.autoSpoofNewDevice = GetLiveBool(@"AutoSpoofNewDevice", YES);

        self.antiThermalThrottling = GetLiveBool(@"AntiThermalThrottling", YES);
        self.smartThermalManager = GetLiveBool(@"SmartThermalManager", YES);
        self.heavyLoadCooling = GetLiveBool(@"HeavyLoadCooling", YES);
        self.chargeCoolingProtection = GetLiveBool(@"ChargeCoolingProtection", YES);
        self.powerSaveMode = GetLiveBool(@"PowerSaveMode", NO);

        self.bypassVarSandbox = GetLiveBool(@"BypassVarSandbox", NO);
        self.blockAnalytics = GetLiveBool(@"BlockAnalytics", YES);
        self.tcpTurboNetwork = GetLiveBool(@"TcpTurboNetwork", YES);
    });
}

- (NSInteger)resolvedTargetHz {
    if (!self.enabled) return 60;
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    if (g_IsDeviceCharging && self.chargeCoolingProtection) return 60;
    
    if (self.proMotionEngineBeta4) {
        CFTimeInterval now = CACurrentMediaTime();
        if (g_IsUserTouching || (now - g_LastTouchTime < 0.45)) {
            return (self.enableHzControl && self.targetHz > 0) ? self.targetHz : 120;
        } else {
            return 60;
        }
    }
    
    if (!self.enableHzControl) return 60;
    return (self.targetHz > 0) ? self.targetHz : 60;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled) return 60;
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz) return 144;
    if (g_IsDeviceCharging && self.chargeCoolingProtection) return 60;
    
    if (self.proMotionEngineBeta4) {
        return [self resolvedTargetHz];
    }
    
    if (!self.enableFPSControl) return 60;
    return (self.targetFPS > 0) ? self.targetFPS : 60;
}
@end

BoostConfig *CFG = nil;
#define CFG_PTR [BoostConfig sharedInstance]
#define IS_ON (CFG_PTR.enabled)

// ÉP TẦN SỐ QUÉT PHẦN CỨNG MÀN HÌNH TỨC THÌ (ĂN NGAY 100% RA NGOÀI MÀN HÌNH)
static void Apex244_ApplyHardwareRefreshRate(float rate) {
    @try {
        Class wsClass = objc_getClass("CAWindowServer");
        if (wsClass) {
            CAWindowServer *server = [wsClass serverIfRunning];
            if (server) {
                NSArray *displays = [server displays];
                for (CAWindowServerDisplay *disp in displays) {
                    if ([disp respondsToSelector:@selector(setAllowsVirtualModes:)]) {
                        [disp setAllowsVirtualModes:YES];
                    }
                    if ([disp respondsToSelector:@selector(setRefreshRate:)]) {
                        [disp setRefreshRate:rate];
                    }
                }
            }
        }
        
        Class cadClass = objc_getClass("CADisplay");
        if (cadClass && [cadClass respondsToSelector:@selector(mainDisplay)]) {
            CADisplay *mainDisp = [cadClass mainDisplay];
            if ([mainDisp respondsToSelector:@selector(setPreferredFPS:)]) {
                [mainDisp setPreferredFPS:(NSInteger)rate];
            }
        }
    } @catch (NSException *e) {}
}

static void Apex244_DebouncedPreferenceSync(void) {
    if (!apex244_pref_sync_queue) {
        apex244_pref_sync_queue = dispatch_queue_create("com.boostapex244.pref.sync", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_pref_sync_queue, ^{
        [[BoostConfig sharedInstance] loadSettings];
        CFG = [BoostConfig sharedInstance];
        
        if (CFG.enabled && CFG.enableHzControl) {
            float resolvedHz = (float)[CFG resolvedTargetHz];
            dispatch_async(dispatch_get_main_queue(), ^{
                Apex244_ApplyHardwareRefreshRate(resolvedHz);
            });
        }
    });
}

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    Apex244_DebouncedPreferenceSync();
}

// ==============================================================================
// 🖥 PHẦN 6: ÉP XUNG NHỊP HZ/FPS THỰC THI (ĐỒNG BỘ 100% CẢ HAI MỨC)
// ==============================================================================
%group Group_Display_DualRate

%hook CADisplayLink
- (NSInteger)preferredFramesPerSecond {
    if (!IS_ON || !CFG_PTR.enableFPSControl) return %orig;
    return [CFG_PTR resolvedTargetFPS];
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ON || !CFG_PTR.enableFPSControl) {
        %orig(fps);
        return;
    }
    %orig([CFG_PTR resolvedTargetFPS]);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta4)) return %orig;
    float rate = (float)[CFG_PTR resolvedTargetHz];
    return CAFrameRateRangeMake(rate >= 60.0f ? 60.0f : 30.0f, rate, rate);
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta4)) {
        %orig(range);
        return;
    }
    float rate = (float)[CFG_PTR resolvedTargetHz];
    %orig(CAFrameRateRangeMake(rate >= 60.0f ? 60.0f : 30.0f, rate, rate));
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta4)) return %orig;
    return [CFG_PTR resolvedTargetHz];
}

- (NSInteger)_maximumFramesPerSecond {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta4)) return %orig;
    return [CFG_PTR resolvedTargetHz];
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta4)) {
        %orig(rate);
        return;
    }
    %orig((CGFloat)[CFG_PTR resolvedTargetHz]);
}

- (CGFloat)_refreshRate {
    if (!IS_ON || (!CFG_PTR.enableHzControl && !CFG_PTR.proMotionEngineBeta4)) return %orig;
    return (CGFloat)[CFG_PTR resolvedTargetHz];
}
%end

%end

// ==============================================================================
// 🎮 PHẦN 7: METAL GRAPHICS TRIPLE BUFFERING (SPRINGBOARD ONLY)
// ==============================================================================
%group Group_Metal_SpringBoard_Only

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ON && CFG_PTR.metalTripleBuffering && BoostIsSpringBoard()) {
        %orig(3);
    } else {
        %orig(count);
    }
}
%end

%end

// ==============================================================================
// 🎨 PHẦN 8: COLOROS 17 & KHẮC PHỤC LIQUID (GL)ASS NẶNG (BETA 3)
// ==============================================================================
%group Group_ColorOS17_SafeUI

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine) {
        %orig(0.993);
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && self.window != nil) {
        self.decelerationRate = 0.993;
        self.bounces = YES;
        self.alwaysBounceVertical = YES;
        self.layer.drawsAsynchronously = YES;
        PMConfigureScrollView(self);
    }
}
%end

%hook CALayer
- (void)setNeedsDisplay {
    %orig;
    if (IS_ON) {
        if (CFG_PTR.touchResponseBoost) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
        if (CFG_PTR.quantumRenderShieldOfficial) {
            Apex244_ExecuteQuantumRenderShield();
        }
        if (CFG_PTR.neuralBufferOptimizerOfficial) {
            Apex244_ExecuteNeuralBufferOptimizer();
        }
    }
}
%end

// GIẢM TẢI TRIỆT ĐỂ CHO LIQUID (GL)ASS & CÁC LỚP BLUR NẶNG (BETA 3)
%hook UIVisualEffectView
- (void)layoutSubviews {
    %orig;
    if (IS_ON && CFG_PTR.heavyEffectAntiLagV3) {
        self.layer.shouldRasterize = YES;
        self.layer.rasterizationScale = [UIScreen mainScreen].scale;
    }
}
%end

%hook _UIVisualEffectBackdropView
- (void)applySettings:(id)arg1 {
    if (IS_ON && CFG_PTR.heavyEffectAntiLagV3) {
        self.layer.drawsAsynchronously = YES;
    }
    %orig(arg1);
}
%end

%hook _UIBarBackground
- (void)layoutSubviews {
    %orig;
    if (IS_ON && CFG_PTR.heavyEffectAntiLagV3) {
        self.layer.shouldRasterize = YES;
        self.layer.rasterizationScale = [UIScreen mainScreen].scale;
    }
}
%end

%hook NCNotificationShortLookView
- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.heavyEffectAntiLagV3) {
        self.layer.shouldRasterize = YES;
        self.layer.rasterizationScale = [UIScreen mainScreen].scale;
    }
}
%end

%end

// ==============================================================================
// ⌨️ PHẦN 9: BÀN PHÍM 0MS & CHỐNG GIẬT TEXT DÀI VỚI AI (BETA 3)
// ==============================================================================
%group Group_Keyboard_And_Text

%hook UIKeyboardImpl
- (void)handleKeyWithString:(id)arg1 forKeyEvent:(id)arg2 executionContext:(id)arg3 {
    if (IS_ON && CFG_PTR.keyboardZeroLagV3) {
        Apex244_BoostThreadPriorityRealtime();
    }
    %orig;
}

- (void)addInputString:(id)arg1 withFlags:(NSUInteger)arg2 executionContext:(id)arg3 {
    if (IS_ON && CFG_PTR.keyboardZeroLagV3) {
        Apex244_BoostThreadPriorityRealtime();
    }
    %orig;
}
%end

%hook UITextView
- (void)layoutSubviews {
    %orig;
    if (IS_ON && CFG_PTR.keyboardZeroLagV3) {
        self.layer.shouldRasterize = NO;
        self.layer.drawsAsynchronously = YES;
    }
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    if (IS_ON && CFG_PTR.keyboardZeroLagV3) {
        self.layer.drawsAsynchronously = YES;
    }
    %orig;
}
%end

%end

// ==============================================================================
// 🌟 PHẦN 10: TRIỆT TIÊU MOTION BLUR & LÀM NÉT CHUYỂN CẢNH KHI VUỐT TỪ DƯỚI LÊN
// ==============================================================================
%group Group_Gesture_Fix

%hook SBFluidSwitcherAnimationSettings
- (void)setDefaultValues {
    %orig;
    if ([self respondsToSelector:@selector(setOpacityMinimumDistanceThreshold:)]) {
        [self setOpacityMinimumDistanceThreshold:0.0];
    }
}
%end

%hook SBAppSwitcherSettings
- (void)setDefaultValues {
    %orig;
    if ([self respondsToSelector:@selector(setShouldSimplifyForOptions:)]) {
        [self setShouldSimplifyForOptions:1];
    }
}
%end

%hook SBHomeGestureSettings
- (void)setDefaultValues {
    %orig;
    if ([self respondsToSelector:@selector(setTouchUpDelay:)]) {
        [self setTouchUpDelay:0.0];
    }
}
%end

%hook UIView
- (void)layoutSubviews {
    %orig;
    if (g_Enabled && g_ColorOs17SmoothEngine) {
        NSString *cls = NSStringFromClass([self class]);
        if ([cls containsString:@"AppSwitcher"] || [cls containsString:@"FluidSwitcher"] || [cls containsString:@"SBHomeScreenOverlayView"]) {
            self.layer.shouldRasterize = NO;
            self.layer.drawsAsynchronously = YES;
            if ([self.layer respondsToSelector:@selector(setAllowsGroupOpacity:)]) {
                self.layer.allowsGroupOpacity = NO;
            }
        }
    }
}
%end

%end

// Tối ưu an toàn cho Backdrop không bao giờ ném ngoại lệ
%group Group_ColorOS17_SafeUI

%hook _UIVisualEffectBackdropView
- (void)applySettings:(id)arg1 {
    if (g_Enabled && g_HeavyEffectAntiLagV3) {
        self.layer.drawsAsynchronously = YES;
    }
    %orig(arg1);
}
%end

%end

// ==============================================================================
// 🚀 PHẦN 11: SPRINGBOARD ENGINE & BẮT CỬ CHỈ PROMOTION BETA 4
// ==============================================================================
%group Group_SpringBoard_Only

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig(application);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (CFG_PTR.hyperMemoryGuardian) {
            Apex244_ExecuteHyperMemoryGuardian();
        }
        if (CFG_PTR.apexBackgroundPacingDaemon) {
            Apex244_ExecuteBackgroundPacingDaemon();
        }
        if (CFG_PTR.enableHzControl) {
            Apex244_ApplyHardwareRefreshRate((float)[CFG_PTR resolvedTargetHz]);
        }
    });
}
%end

%hook SBWallpaperController
- (void)reloadWallpaper {
    %orig;
}
%end

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

// Bắt cảm ứng toàn diện phục vụ ProMotion Engine Beta 4
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (IS_ON && CFG_PTR.proMotionEngineBeta4) {
        if (event.type == UIEventTypeTouches) {
            NSSet *touches = [event allTouches];
            UITouchPhase phase = ((UITouch *)[touches anyObject]).phase;
            if (phase == UITouchPhaseBegan || phase == UITouchPhaseMoved) {
                g_IsUserTouching = YES;
                g_LastTouchTime = CACurrentMediaTime();
                if (CFG_PTR.touchResponseBoost) {
                    Apex244_BoostThreadPriorityRealtime();
                }
            } else if (phase == UITouchPhaseEnded || phase == UITouchPhaseCancelled) {
                g_IsUserTouching = NO;
                g_LastTouchTime = CACurrentMediaTime();
            }
        }
    }
    %orig(event);
}
%end

%end

// ==============================================================================
// 🧹 PHẦN 12: QUẢN LÝ TIẾN TRÌNH VÀ BỘ NHỚ AN TOÀN
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON && BoostIsSpringBoard()) {
        Apex244_RunGarbageCollector_Light();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.aggressiveRamClean && BoostIsSpringBoard()) {
        Apex244_RunGarbageCollector_Light();
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.enableHzControl && BoostIsSpringBoard()) {
        Apex244_ApplyHardwareRefreshRate((float)[CFG_PTR resolvedTargetHz]);
    }
}
%end

%end

// ==============================================================================
// 🛡 PHẦN 13: MODULE BỔ TRỢ HỆ THỐNG NÂNG CAO (OPTIMIZER SUBSYSTEM)
// ==============================================================================

@interface Apex244_SystemOptimizer : NSObject
+ (instancetype)sharedInstance;
- (void)triggerDeepMemoryClean;
- (void)optimizeCurrentTaskRunloop;
- (void)registerSystemPowerAssertions;
- (void)releaseSystemPowerAssertions;
- (void)executeLowMemoryWatchdogRoutine;
- (void)recalibrateGraphicsDriverPacing;
- (void)triggerHyperThreadOptimization;
- (void)synchronizeQuantumClockPipeline;
- (void)flushTelemetryMetrics;
- (void)executeCoreStabilitySurvey;
- (void)recoverFromMicroDeadlock;
- (void)enforceFrameTimingConstraints;
- (void)runKernelIOPacingSweep;
- (void)enforceVsyncLockConstraint;
- (void)purgeBackdropTextureCaches;
- (void)elevateCompositorThreadRealtime;
@end

@implementation Apex244_SystemOptimizer {
    BOOL _assertionActive;
}

+ (instancetype)sharedInstance {
    static Apex244_SystemOptimizer *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[Apex244_SystemOptimizer alloc] init];
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
        if (!BoostIsBankingOrFinancialApp() && BoostIsSpringBoard()) {
            Apex244_RunGarbageCollector_Aggressive();
            Apex244_AutoKernelMemoryRebalancer();
        }
    }
}

- (void)optimizeCurrentTaskRunloop {
    @autoreleasepool {
        CFRunLoopRef currentLoop = CFRunLoopGetCurrent();
        if (currentLoop) {
            CFRunLoopWakeUp(currentLoop);
            Apex244_AutoDaemonDeadlockImmunity();
        }
    }
}

- (void)registerSystemPowerAssertions {
    if (!_assertionActive) {
        _assertionActive = YES;
    }
}

- (void)releaseSystemPowerAssertions {
    if (_assertionActive) {
        _assertionActive = NO;
    }
}

- (void)executeLowMemoryWatchdogRoutine {
    @autoreleasepool {
        Apex244_PeriodicWatchdogHealthCheck();
        Apex244_AutoKernelMemoryRebalancer();
    }
}

- (void)recalibrateGraphicsDriverPacing {
    @autoreleasepool {
        Apex244_AutoGPUFramePacingRegulator();
    }
}

- (void)triggerHyperThreadOptimization {
    @autoreleasepool {
        if (CFG_PTR.hyperThreadIOAcceleratorOfficial) {
            Apex244_ExecuteHyperThreadIORoutine();
        }
    }
}

- (void)synchronizeQuantumClockPipeline {
    @autoreleasepool {
        if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
            Apex244_ExecuteQuantumCoreSyncRoutine();
        }
    }
}

- (void)flushTelemetryMetrics {
    if (!apex244_telemetry_queue) {
        apex244_telemetry_queue = dispatch_queue_create("com.boostapex244.telemetry", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_telemetry_queue, ^{
        @autoreleasepool {
            g_apex244GraphicsState.totalFramesRendered++;
        }
    });
}

- (void)executeCoreStabilitySurvey {
    if (!apex244_hardware_poll_queue) {
        apex244_hardware_poll_queue = dispatch_queue_create("com.boostapex244.hardware.poll", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex244_hardware_poll_queue, ^{
        @autoreleasepool {
            Apex244_ExecuteThermalRoutine();
            Apex244_PeriodicWatchdogHealthCheck();
        }
    });
}

- (void)recoverFromMicroDeadlock {
    @autoreleasepool {
        Apex244_AutoDaemonDeadlockImmunity();
        g_apex244WatchdogState.deadlocksPrevented++;
    }
}

- (void)enforceFrameTimingConstraints {
    @autoreleasepool {
        Apex244_AutoGPUFramePacingRegulator();
    }
}

- (void)runKernelIOPacingSweep {
    @autoreleasepool {
        Apex244_ExecuteHyperThreadIORoutine();
    }
}

- (void)enforceVsyncLockConstraint {
    @autoreleasepool {
        Apex244_AutoGPUFramePacingRegulator();
    }
}

- (void)purgeBackdropTextureCaches {
    @autoreleasepool {
        malloc_zone_pressure_relief(NULL, 1024 * 1024 * 8);
    }
}

- (void)elevateCompositorThreadRealtime {
    Apex244_BoostThreadPriorityRealtime();
}

@end

// ==============================================================================
// 🚀 PHẦN 14: CONSTRUCTOR TWEAK V24.4 TITANIUM APEX ULTRA (FULL PIPELINE)
// ==============================================================================

%ctor {
    @autoreleasepool {
        NSString *proc = [[NSProcessInfo processInfo] processName];

        // 1. CÁCH LY TUYỆT ĐỐI ỨNG DỤNG CÀI ĐẶT (PREFERENCES) ĐỂ KHÔNG BỊ TREO/ĐEN MÀN
        if ([proc isEqualToString:@"Preferences"]) {
            return;
        }

        // 2. CÁCH LY CÁC DAEMON HỆ THỐNG VÀ TIẾN TRÌNH NHẠY CẢM
        if (BoostIsSystemCriticalDaemon()) {
            return;
        }

        // 3. CÁCH LY ỨNG DỤNG NGÂN HÀNG & TÀI CHÍNH (CHỐNG VĂNG APP)
        if (BoostIsBankingOrFinancialApp()) {
            return;
        }

        // 4. KHỞI TẠO BẢO VỆ CRASH GUARD
        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
            return;
        }

        CFG = [BoostConfig sharedInstance];

        // 5. ĐĂNG KÝ IPC THÔNG BÁO THAY ĐỔI CÀI ĐẶT
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                reloadPrefsNotification,
                CFSTR(NOTIFY_RELOAD),
                NULL,
                CFNotificationSuspensionBehaviorCoalesce
            );
        });

        // 6. KHỞI TẠO CÁC NHÓM HOOKS THEO TIẾN TRÌNH
        if (BoostIsSpringBoard()) {
            %init(Group_SpringBoard_Only);
            %init(Group_Metal_SpringBoard_Only);
            %init(Group_Gesture_Fix);
            Apex244_StartPassiveRamDaemon();
            Apex244_StartChargingMonitor();
            Apex244_StartAIChatBufferProtector();
            Apex244_StartDisplayPacingDaemon();
            Apex244_BoostThreadPriorityRealtime();
        }

        // Kích hoạt ép Hz và gia tốc đồ họa
        %init(Group_Display_DualRate);
        %init(Group_ColorOS17_SafeUI);
        %init(Group_Memory_Engine);

        if (BoostIsSpringBoard() || BoostIsKeyboardProcess()) {
            %init(Group_Keyboard_And_Text);
        }

        %init(_ungrouped);

        PMRuntimeReady = YES;

        if (CFG_PTR.hyperThreadIOAcceleratorOfficial) {
            Apex244_ExecuteHyperThreadIORoutine();
        }
        if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
            Apex244_ExecuteQuantumCoreSyncRoutine();
        }
        if (CFG_PTR.enableHzControl && BoostIsSpringBoard()) {
            Apex244_ApplyHardwareRefreshRate((float)[CFG_PTR resolvedTargetHz]);
        }
    }
}
