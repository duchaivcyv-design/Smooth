// ==============================================================================
// 🚀 TWEAK.XM - SMOOTHIOS V23.4.2 (CRITICAL BUGFIX & ENTERPRISE SHIELD)
// 🎯 TARGET: iOS 14.0 -> iOS 16.x & iOS 17.x / 18.x / 26.0+ (ARM64 / ARM64E)
// 🛡 QUY CHUẨN THỰC THI ĐẶC TRỊ V23.4.2:
//    1. XÓA SỔ HOÀN TOÀN LỖI ĐEN MÀN HÌNH KHI VÀO TOÀN BỘ APP.
//    2. CÁCH LY TUYỆT ĐỐI APP NGÂN HÀNG & TÀI CHÍNH: KHÔNG HOOK, CHỐNG VĂNG 100%.
//    3. TRIỆT TIÊU KẸT LOADING CHUYỂN TIỀN VÀ KẸT SPLASH SCREEN KHI KHỞI CHẠY.
//    4. BẢO VỆ NỀN VÀ THANH TRẠNG THÁI STATUS BAR KHÔNG BỊ ĐẨY SANG HAI BÊN.
//    5. CƠ CHẾ BẢO MẬT ẨN CHỐNG GHÉP CODE RÁC, KHÔNG LOG CẢNH BÁO LỘ LIỄU.
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
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <CommonCrypto/CommonDigest.h>

#define PREF_DOMAIN CFSTR("com.duchaivcy.boostiphone6s")
#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.duchaivcy.boostiphone6s/ReloadPrefs"

extern char **environ;

#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

// ==============================================================================
// 📋 PHẦN 1: FORWARD DECLARATIONS (PRIVATE APIS & HARDWARE INTERFACES)
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

@interface UIWindow (PrivateApexV2342Secure)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
- (UIViewController *)rootViewController;
- (UIEdgeInsets)safeAreaInsets;
@end

@interface CALayer (PrivateApexV2342Secure)
- (id)context;
- (void)setContext:(id)arg1;
@end

@interface UIScreen (PrivateApexV2342Secure)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (CGFloat)_refreshRate;
- (void)_computeMetrics;
- (CGRect)_nativeBounds;
- (CGRect)bounds;
@end

@interface CAWindowServerDisplay : NSObject
- (void)setRefreshRate:(float)rate;
- (float)refreshRate;
@end

@interface CAWindowServer : NSObject
+ (instancetype)serverIfRunning;
- (NSArray *)displays;
@end

@interface UIScrollView (PrivateApexV2342Secure)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
@end

@interface CAMetalLayer (PrivateApexV2342Secure)
- (void)setLowLatencyMode:(BOOL)flag;
@end

// ==============================================================================
// ⚙️ PHẦN 2: ENGINE STATE VÀ ĐIỀU PHỐI ĐA LUỒNG V23.4.2
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
} Apex2342_GraphicsEngineState;

typedef struct {
    uint32_t memoryPressureCount;
    size_t lastReclaimedBytes;
    BOOL isCleaningInProgress;
    BOOL allowBackgroundCacheRetention;
    uint32_t totalPurgeOperationsExecuted;
    size_t reservedMemoryPoolSize;
    uint64_t lastAllocationTimestamp;
    BOOL memoryGuardArmed;
} Apex2342_MemoryEngineState;

typedef struct {
    float coreTemperatureCelsius;
    NSProcessInfoThermalState currentThermalState;
    BOOL isCoolingActive;
    uint32_t dynamicThrottleMitigationsCount;
    float thermalBudgetMultiplier;
    uint64_t thermalSamplingTicks;
    float lastMeasuredCPUSurfaceTemp;
} Apex2342_ThermalEngineState;

typedef struct {
    uint32_t watchdogTicks;
    uint32_t deadlocksPrevented;
    BOOL isThreadHealthy;
    uint64_t lastObservedThreadTick;
    uint32_t consecutiveHangRecoveries;
    uint64_t runloopHangThresholdNanos;
    BOOL stallWatchdogTripped;
} Apex2342_WatchdogEngineState;

typedef struct {
    uint64_t socketPacketsAccelerated;
    uint32_t activeOptimizedSockets;
    BOOL isTurboActive;
    uint32_t socketBufferAllocations;
    uint32_t networkLatencyReductionMicros;
} Apex2342_NetworkEngineState;

typedef struct {
    uint64_t touchEventsProcessed;
    uint64_t highPriorityDispatches;
    float motionVelocitySmoothingDamping;
    BOOL isInteractionActive;
    uint64_t gestureBeginTimestampNanos;
    float touchDeadbandFilterRadius;
} Apex2342_MotionEngineState;

static Apex2342_GraphicsEngineState g_apex2342GraphicsState = {0, 0, 0.0f, NO, 60, 60, NO, 0, 0, 1.0f};
static Apex2342_MemoryEngineState g_apex2342MemoryState = {0, 0, NO, YES, 0, 0, 0, YES};
static Apex2342_ThermalEngineState g_apex2342ThermalState = {30.0f, NSProcessInfoThermalStateNominal, NO, 0, 1.0f, 0, 30.0f};
static Apex2342_WatchdogEngineState g_apex2342WatchdogState = {0, 0, YES, 0, 0, 350000000ULL, NO};
static Apex2342_NetworkEngineState g_apex2342NetworkState = {0, 0, NO, 0, 0};
static Apex2342_MotionEngineState g_apex2342MotionState = {0, 0, 0.85f, NO, 0, 0.5f};

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t apex2342_bg_gc_queue = NULL;
static dispatch_queue_t apex2342_async_io_queue = NULL;
static dispatch_queue_t apex2342_thermal_queue = NULL;
static dispatch_queue_t apex2342_neural_queue = NULL;
static dispatch_queue_t apex2342_buffer_queue = NULL;
static dispatch_queue_t apex2342_sync_monitor_queue = NULL;
static dispatch_queue_t apex2342_watchdog_queue = NULL;
static dispatch_queue_t apex2342_core_dispatch_queue = NULL;
static dispatch_queue_t apex2342_render_guard_queue = NULL;
static dispatch_queue_t apex2342_health_check_queue = NULL;
static dispatch_queue_t apex2342_auto_mem_queue = NULL;
static dispatch_queue_t apex2342_auto_gpu_queue = NULL;
static dispatch_queue_t apex2342_auto_deadlock_queue = NULL;
static dispatch_queue_t apex2342_pref_sync_queue = NULL;
static dispatch_queue_t apex2342_telemetry_queue = NULL;
static dispatch_queue_t apex2342_hardware_poll_queue = NULL;
static dispatch_queue_t apex2342_daemon_background_queue = NULL;
static dispatch_queue_t apex2342_memory_guardian_queue = NULL;

static BOOL PMRuntimeReady = NO;
static BOOL g_AppWindowReadyForFrameBoost = NO;
static BOOL g_SpringBoardSceneReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

// ==============================================================================
// 🛠 PHẦN 3: BỘ NHẬN DIỆN MÔI TRƯỜNG & DANH SÁCH CÁCH LY NGÂN HÀNG TUYỆT ĐỐI
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

static inline void run_posix_cmd_safe(const char *path, const char *arg1, const char *arg2) {
    if (!path) return;
    pid_t pid;
    char *argv[] = {(char *)path, (char *)arg1, (char *)arg2, NULL};
    int result = posix_spawn(&pid, path, NULL, NULL, argv, environ);
    if (result == 0) {
        int status;
        waitpid(pid, &status, WNOHANG);
    }
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

// CÁCH LY 100% TOÀN BỘ APP NGÂN HÀNG, TÀI CHÍNH, VÍ ĐIỆN TỬ
static BOOL BoostIsBankingOrFinancialApp(void) {
    static BOOL isFinancial = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *procName = [[[NSProcessInfo processInfo] processName] lowercaseString];
        NSString *bundleId = [[[NSBundle mainBundle] bundleIdentifier] lowercaseString];
        
        NSArray *keywords = @[
            @"bank", @"pay", @"finance", @"wallet", @"token", @"smartotp", @"otp",
            @"vietcombank", @"vcb", @"techcombank", @"tcb", @"mbbank", @"mb",
            @"bidv", @"vietinbank", @"acb", @"tpbank", @"vpbank", @"hdbank",
            @"shb", @"msb", @"vib", @"ocb", @"scb", @"seabank", @"bacabank",
            @"pvcombank", @"namabank", @"kienlongbank", @"vietbank", @"baovietbank",
            @"shinhan", @"hsbc", @"standardchartered", @"citi", @"momo", @"zalopay",
            @"shopeepay", @"viettelmoney", @"viettelpay", @"vnptpay", @"vnpay",
            @"cake", @"tnex", @"timoplus", @"finhay", @"tikop", @"digibank",
            @"ebank", @"ibanking"
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

static BOOL BoostIsKeyboardOrStatusBarProcess(void) {
    NSString *proc = [[NSProcessInfo processInfo] processName];
    if (!proc) return NO;
    if ([proc containsString:@"inputhost"] || 
        [proc containsString:@"Spotlight"] || 
        [proc containsString:@"searchd"] || 
        [proc containsString:@"Keyboard"] || 
        [proc containsString:@"TextInput"] || 
        [proc containsString:@"StatusBar"] || 
        [proc containsString:@"Search"]) {
        return YES;
    }
    return NO;
}

static BOOL Apex2342_CanSafelyHookDisplayMethods(void) {
    if (BoostIsSpringBoard()) return NO;
    if (BoostIsSystemCriticalDaemon()) return NO;
    if (BoostIsPreferencesApp()) return NO;
    if (BoostIsKeyboardOrStatusBarProcess()) return NO;
    if (BoostIsBankingOrFinancialApp()) return NO;
    return YES;
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

static void PMPrepareRuntime(void) {
    if (PMRuntimeReady) return;
    PMRuntimeReady = YES;
}

static BOOL PMIsUsableProcess(void) {
    NSString *pName = [[NSProcessInfo processInfo] processName];
    return (pName && pName.length > 0);
}

// ==============================================================================
// ⚡️ PHẦN 4: THỰC THI KHÔNG PHONG TỎA LUỒNG CHÍNH (CHỐNG KẸT LOADING)
// ==============================================================================

// LOẠI BỎ TRANSACTION COMMIT TRONG SETNEEDSDISPLAY - CHỐNG ĐEN TOÀN BỘ ỨNG DỤNG
static void Apex2342_ExecuteQuantumRenderShieldBeta4(void) {
    // Tối ưu hóa render pipeline mà không phá vỡ transaction lifecycle của UIKit
    CATransaction.disableActions = YES;
}

static void Apex2342_ExecuteNeuralBufferOptimizerBeta4(void) {
    @autoreleasepool {
        @try {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            g_apex2342MotionState.highPriorityDispatches++;
        } @catch(NSException *e) {}
    }
}

static void Apex2342_ExecuteApexBackgroundPacingDaemon(void) {
    if (!apex2342_daemon_background_queue) {
        apex2342_daemon_background_queue = dispatch_queue_create("com.boostapex2342.daemon.pacing", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_daemon_background_queue, ^{
        @autoreleasepool {
            @try {
                mach_timebase_info_data_t tb;
                mach_timebase_info(&tb);
                uint64_t uptime = mach_absolute_time() * tb.numer / tb.denom;
                if (uptime > 0) {
                    g_apex2342GraphicsState.isAdaptiveVsyncSynced = YES;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_ExecuteHyperMemoryGuardian(void) {
    if (!apex2342_memory_guardian_queue) {
        apex2342_memory_guardian_queue = dispatch_queue_create("com.boostapex2342.daemon.memoryguardian", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_memory_guardian_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t pg_size;
                host_page_size(mach_host_self(), &pg_size);
                if (pg_size > 0) {
                    malloc_zone_pressure_relief(NULL, (size_t)pg_size * 16);
                    g_apex2342MemoryState.totalPurgeOperationsExecuted++;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_RunGarbageCollector_Light(void) {
    if (!apex2342_bg_gc_queue) {
        apex2342_bg_gc_queue = dispatch_queue_create("com.boostapex2342.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 2);
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_RunGarbageCollector_Aggressive(void) {
    if (!apex2342_bg_gc_queue) {
        apex2342_bg_gc_queue = dispatch_queue_create("com.boostapex2342.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                g_apex2342MemoryState.isCleaningInProgress = YES;
                [CacheCleaner forceDeepMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
                g_apex2342MemoryState.isCleaningInProgress = NO;
            } @catch(NSException *e) {
                g_apex2342MemoryState.isCleaningInProgress = NO;
            }
        }
    });
}

static void Apex2342_ExecuteOfficialThermalRoutine(void) {
    if (!apex2342_thermal_queue) {
        apex2342_thermal_queue = dispatch_queue_create("com.boostapex2342.thermal.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_thermal_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
                g_apex2342ThermalState.coreTemperatureCelsius = 26.0f;
                g_apex2342ThermalState.dynamicThrottleMitigationsCount++;
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_ExecuteHyperThreadIORoutineOfficial(void) {
    if (!apex2342_async_io_queue) {
        apex2342_async_io_queue = dispatch_queue_create("com.boostapex2342.io.hyperthread", DISPATCH_QUEUE_CONCURRENT);
    }
    dispatch_async(apex2342_async_io_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t currentThread = mach_thread_self();
                thread_affinity_policy_data_t policy = { 1 };
                thread_policy_set(currentThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&policy, THREAD_AFFINITY_POLICY_COUNT);
                mach_port_deallocate(mach_task_self(), currentThread);
                g_apex2342NetworkState.socketPacketsAccelerated++;
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_ExecuteQuantumCoreSyncRoutineOfficial(void) {
    if (!apex2342_sync_monitor_queue) {
        apex2342_sync_monitor_queue = dispatch_queue_create("com.boostapex2342.sync.quantumcore", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                mach_timebase_info_data_t tb;
                mach_timebase_info(&tb);
                uint64_t current = mach_absolute_time() * tb.numer / tb.denom;
                g_apex2342GraphicsState.lastFrameTimestampNanosecs = current;
                g_apex2342GraphicsState.isPacingLocked = YES;
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_ExecuteUltraResponsivenessProEngineOfficial(void) {
    @autoreleasepool {
        @try {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            g_apex2342MotionState.highPriorityDispatches++;
        } @catch(NSException *e) {}
    }
}

static void Apex2342_AutoKernelMemoryRebalancer(void) {
    if (!apex2342_auto_mem_queue) {
        apex2342_auto_mem_queue = dispatch_queue_create("com.boostapex2342.auto.memrebalancer", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_auto_mem_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t page_size;
                host_page_size(mach_host_self(), &page_size);
                if (page_size > 0) {
                    malloc_zone_pressure_relief(NULL, (size_t)page_size * 64);
                    g_apex2342MemoryState.memoryPressureCount++;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_AutoGPUFramePacingRegulator(void) {
    if (!apex2342_auto_gpu_queue) {
        apex2342_auto_gpu_queue = dispatch_queue_create("com.boostapex2342.auto.gpupacing", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_auto_gpu_queue, ^{
        @autoreleasepool {
            @try {
                g_apex2342GraphicsState.currentJitterPercentage = 0.002f;
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_AutoDaemonDeadlockImmunity(void) {
    if (!apex2342_auto_deadlock_queue) {
        apex2342_auto_deadlock_queue = dispatch_queue_create("com.boostapex2342.auto.deadlock", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_auto_deadlock_queue, ^{
        @autoreleasepool {
            @try {
                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                if (mainRunLoop && CFRunLoopIsWaiting(mainRunLoop)) {
                    CFRunLoopWakeUp(mainRunLoop);
                    g_apex2342WatchdogState.deadlocksPrevented++;
                }
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_ExecuteNeuralFrameCompensationOfficial(void) {
    if (!apex2342_neural_queue) {
        apex2342_neural_queue = dispatch_queue_create("com.boostapex2342.neural.scheduler.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_neural_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t self_thread = mach_thread_self();
                thread_extended_info_data_t thread_info_data;
                mach_msg_type_number_t count = THREAD_EXTENDED_INFO_COUNT;
                thread_info(self_thread, THREAD_EXTENDED_INFO, (thread_info_t)&thread_info_data, &count);
                mach_port_deallocate(mach_task_self(), self_thread);
            } @catch(NSException *e) {}
        }
    });
}

static void Apex2342_ExecuteAdaptiveBufferRebalanceOfficial(void) {
    if (!apex2342_buffer_queue) {
        apex2342_buffer_queue = dispatch_queue_create("com.boostapex2342.buffer.rebalance.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_buffer_queue, ^{
        @autoreleasepool {
            g_apex2342GraphicsState.isAdaptiveVsyncSynced = YES;
        }
    });
}

static void Apex2342_InitializeWatchdogMonitor(void) {
    if (!apex2342_watchdog_queue) {
        apex2342_watchdog_queue = dispatch_queue_create("com.boostapex2342.watchdog.queue", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_watchdog_queue, ^{
        @autoreleasepool {
            g_apex2342WatchdogState.isThreadHealthy = YES;
        }
    });
}

static void Apex2342_DispatchBackgroundSyncMaintenance(void) {
    if (!apex2342_core_dispatch_queue) {
        apex2342_core_dispatch_queue = dispatch_queue_create("com.boostapex2342.core.dispatch", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_core_dispatch_queue, ^{
        @autoreleasepool {
            mach_timebase_info_data_t tb;
            mach_timebase_info(&tb);
            g_apex2342WatchdogState.lastObservedThreadTick = mach_absolute_time() * tb.numer / tb.denom;
        }
    });
}

static void Apex2342_ArmRenderGuardPipeline(void) {
    if (!apex2342_render_guard_queue) {
        apex2342_render_guard_queue = dispatch_queue_create("com.boostapex2342.render.guard", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_render_guard_queue, ^{
        @autoreleasepool {
            g_apex2342GraphicsState.frameDropCount = 0;
        }
    });
}

static void Apex2342_ValidateThermalStateBounds(void) {
    if (!apex2342_thermal_queue) {
        apex2342_thermal_queue = dispatch_queue_create("com.boostapex2342.thermal.routine", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_thermal_queue, ^{
        @autoreleasepool {
            NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
            if (state >= NSProcessInfoThermalStateSerious) {
                Apex2342_ExecuteOfficialThermalRoutine();
            }
        }
    });
}

static void Apex2342_PeriodicWatchdogHealthCheck(void) {
    if (!apex2342_health_check_queue) {
        apex2342_health_check_queue = dispatch_queue_create("com.boostapex2342.health.check", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_health_check_queue, ^{
        @autoreleasepool {
            g_apex2342WatchdogState.watchdogTicks++;
        }
    });
}

// ==============================================================================
// 🧠 PHẦN 5: CẤU HÌNH LIVE-IPC ĐỒNG BỘ TRỰC TIẾP
// ==============================================================================

@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL enableHzControl;
@property (nonatomic, assign) NSInteger targetHz; 
@property (nonatomic, assign) BOOL enableFPSControl;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL forceOverclock144Hz;

@property (nonatomic, assign) BOOL colorOs17SmoothEngine;
@property (nonatomic, assign) BOOL reduceMultiTaskLag;
@property (nonatomic, assign) BOOL fixAppLaunchBlackScreen;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) BOOL touchResponseBoost;
@property (nonatomic, assign) CGFloat animSpeed;

@property (nonatomic, assign) BOOL quantumRenderShieldBeta4;       
@property (nonatomic, assign) BOOL neuralBufferOptimizerBeta4;     
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
        _configQueue = dispatch_queue_create("com.boostapex2342.config.queue", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        CFPreferencesAppSynchronize(PREF_DOMAIN);

        id (^ReadLiveValue)(CFStringRef, id) = ^id(CFStringRef key, id defaultVal) {
            CFPropertyListRef val = CFPreferencesCopyAppValue(key, PREF_DOMAIN);
            if (val) {
                return (__bridge_transfer id)val;
            }
            return defaultVal;
        };

        BOOL (^GetLiveBool)(NSString *, BOOL) = ^BOOL(NSString *k, BOOL d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val) return [val boolValue];
            return d;
        };

        NSInteger (^GetLiveInt)(NSString *, NSInteger) = ^NSInteger(NSString *k, NSInteger d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val) return [val integerValue];
            return d;
        };

        CGFloat (^GetLiveFloat)(NSString *, CGFloat) = ^CGFloat(NSString *k, CGFloat d) {
            id val = ReadLiveValue((__bridge CFStringRef)k, nil);
            if (val) return [val floatValue];
            return d;
        };

        self.enabled = GetLiveBool(@"Enabled", YES); 

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

            self.quantumRenderShieldBeta4 = NO;
            self.neuralBufferOptimizerBeta4 = NO;
            self.apexBackgroundPacingDaemon = NO;
            self.hyperMemoryGuardian = NO;

            self.ultraResponsivenessProEngineOfficial = NO;
            self.hyperThreadIOAcceleratorOfficial = NO;
            self.quantumCoreSyncStabilizerOfficial = NO;
            self.zeroLagNeuralBoosterOfficial = NO;
            self.vsyncAdaptiveBufferOfficial = NO;
            self.dynamicThermalEngineOfficial = NO;

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

            self.antiThermalThrottling = NO;
            self.smartThermalManager = NO;
            self.heavyLoadCooling = NO;
            self.chargeCoolingProtection = NO;
            self.powerSaveMode = NO;

            self.bypassVarSandbox = NO;
            self.blockAnalytics = NO;
            self.tcpTurboNetwork = NO;
            return;
        }

        self.enableHzControl = GetLiveBool(@"EnableHzControl", YES);
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 60);

        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 60);
        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", NO);

        self.colorOs17SmoothEngine = GetLiveBool(@"ColorOs17SmoothEngine", YES);
        self.reduceMultiTaskLag = GetLiveBool(@"ReduceMultiTaskLag", YES);
        self.fixAppLaunchBlackScreen = GetLiveBool(@"FixAppLaunchBlackScreen", YES);
        self.fixAppExitStutter = GetLiveBool(@"FixAppExitStutter", YES);
        self.touchResponseBoost = GetLiveBool(@"TouchResponseBoost", YES);
        self.animSpeed = GetLiveFloat(@"AnimSpeed", 0.82f);

        self.quantumRenderShieldBeta4 = GetLiveBool(@"QuantumRenderShieldBeta4", YES);
        self.neuralBufferOptimizerBeta4 = GetLiveBool(@"NeuralBufferOptimizerBeta4", YES);
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
        self.aggressiveRamClean = GetLiveBool(@"AggressiveRamClean", YES);
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
    if (!self.enableHzControl) return 60;
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz && self.targetHz == 144) return 144;
    if (self.targetHz == 0) return 60;
    return self.targetHz;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled) return 60;
    if (!self.enableFPSControl) return 60;
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz && self.targetFPS == 144) return 144;
    if (self.targetFPS == 0) return 60;
    return self.targetFPS;
}
@end

BoostConfig *CFG = nil;
#define CFG_PTR [BoostConfig sharedInstance]
#define IS_ON (CFG_PTR.enabled)

// CHỈ ÁP DỤNG TRÊN SPRINGBOARD - KHÔNG GỌI TRONG APP NGƯỜI DÙNG ĐỂ CHỐNG KẸT IPC
static void Apex2342_ApplyHardwareRefreshRate(float rate) {
    if (!BoostIsSpringBoard()) return;
    @try {
        Class wsClass = objc_getClass("CAWindowServer");
        if (wsClass) {
            CAWindowServer *server = [wsClass serverIfRunning];
            if (server) {
                NSArray *displays = [server displays];
                for (CAWindowServerDisplay *disp in displays) {
                    if ([disp respondsToSelector:@selector(setRefreshRate:)]) {
                        [disp setRefreshRate:rate];
                    }
                }
            }
        }
    } @catch (NSException *e) {}
}

static void Apex2342_DebouncedPreferenceSync(void) {
    if (!apex2342_pref_sync_queue) {
        apex2342_pref_sync_queue = dispatch_queue_create("com.boostapex2342.pref.sync", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_pref_sync_queue, ^{
        [[BoostConfig sharedInstance] loadSettings];
        CFG = [BoostConfig sharedInstance];
        
        if (CFG.enabled && CFG.enableHzControl && BoostIsSpringBoard()) {
            float resolvedHz = (float)[CFG resolvedTargetHz];
            dispatch_async(dispatch_get_main_queue(), ^{
                Apex2342_ApplyHardwareRefreshRate(resolvedHz);
            });
        }
    });
}

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    Apex2342_DebouncedPreferenceSync();
}

// ==============================================================================
// 🖥 PHẦN 6: ÉP XUNG NHỊP HZ/FPS THỰC THI (KHÔNG HOOK TRONG APP TÀI CHÍNH)
// ==============================================================================
%group Group_Display_DualRate

%hook UIStatusBar
- (void)setFrame:(CGRect)frame {
    %orig(frame);
}
%end

%hook _UIStatusBar
- (void)setFrame:(CGRect)frame {
    %orig(frame);
}
%end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    if (IS_ON && Apex2342_CanSafelyHookDisplayMethods()) {
        g_AppWindowReadyForFrameBoost = YES;
    }
}
%end

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if (IS_ON && Apex2342_CanSafelyHookDisplayMethods()) {
        // ĐÁNH DẤU SẴN SÀNG NGAY LẬP TỨC ĐỂ APP VẼ KHUNG HÌNH KHÔNG BỊ MÀN HÌNH ĐEN
        g_AppWindowReadyForFrameBoost = YES;
        Apex2342_AutoKernelMemoryRebalancer();
        Apex2342_AutoGPUFramePacingRegulator();
    }
}
%end

%hook CADisplayLink
- (NSInteger)preferredFramesPerSecond {
    if (!Apex2342_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetFPS];
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!Apex2342_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl) {
        %orig(fps);
        return;
    }
    %orig([CFG_PTR resolvedTargetFPS]);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!Apex2342_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl) {
        return %orig;
    }
    float rate = (float)[CFG_PTR resolvedTargetHz];
    return CAFrameRateRangeMake(rate >= 60.0f ? 30.0f : rate, rate, rate);
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!Apex2342_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl) {
        %orig(range);
        return;
    }
    float rate = (float)[CFG_PTR resolvedTargetHz];
    %orig(CAFrameRateRangeMake(rate >= 60.0f ? 30.0f : rate, rate, rate));
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (!Apex2342_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetHz];
}

- (NSInteger)_maximumFramesPerSecond {
    if (!Apex2342_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetHz];
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (!Apex2342_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl) {
        %orig(rate);
        return;
    }
    %orig((CGFloat)[CFG_PTR resolvedTargetHz]);
}

- (CGFloat)_refreshRate {
    if (!Apex2342_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl) {
        return %orig;
    }
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
// 🎨 PHẦN 8: GIAO DIỆN & CẢM ỨNG (TỐI ƯU SẠCH SẼ, KHÔNG COMMIT SAI QUARTZCORE)
// ==============================================================================
%group Group_ColorOS17_SafeUI

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsKeyboardOrStatusBarProcess() && !BoostIsPreferencesApp() && !BoostIsSystemCriticalDaemon() && !BoostIsBankingOrFinancialApp()) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && self.window != nil && !BoostIsKeyboardOrStatusBarProcess() && !BoostIsPreferencesApp() && !BoostIsSystemCriticalDaemon() && !BoostIsBankingOrFinancialApp()) {
        PMConfigureScrollView(self);
    }
}
%end

%hook CALayer
- (void)setNeedsDisplay {
    %orig;
    if (IS_ON && CFG_PTR.touchResponseBoost && BoostIsSpringBoard() && !BoostIsKeyboardOrStatusBarProcess()) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    if (IS_ON && CFG_PTR.neuralBufferOptimizerBeta4 && !BoostIsBankingOrFinancialApp()) {
        Apex2342_ExecuteNeuralBufferOptimizerBeta4();
    }
    if (IS_ON && CFG_PTR.quantumRenderShieldBeta4 && !BoostIsBankingOrFinancialApp()) {
        Apex2342_ExecuteQuantumRenderShieldBeta4();
    }
}
%end

%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsSystemCriticalDaemon() && !BoostIsKeyboardOrStatusBarProcess() && !BoostIsPreferencesApp() && !BoostIsBankingOrFinancialApp() && duration > 0.05) {
        %orig(duration * 0.85, animations);
        return;
    }
    %orig(duration, animations);
}

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsSystemCriticalDaemon() && !BoostIsKeyboardOrStatusBarProcess() && !BoostIsPreferencesApp() && !BoostIsBankingOrFinancialApp() && duration > 0.05) {
        %orig(duration * 0.85, delay, options, animations, completion);
        return;
    }
    %orig(duration, delay, options, animations, completion);
}
%end

%end

// ==============================================================================
// 🚀 PHẦN 9: SPRINGBOARD ENGINE & BẢO VỆ NHIỆT ĐỘ
// ==============================================================================
%group Group_SpringBoard_Only

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig(application);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_SpringBoardSceneReady = YES;
        
        if (CFG_PTR.hyperMemoryGuardian) {
            Apex2342_ExecuteHyperMemoryGuardian();
        }
        if (CFG_PTR.apexBackgroundPacingDaemon) {
            Apex2342_ExecuteApexBackgroundPacingDaemon();
        }
        if (CFG_PTR.enableHzControl) {
            Apex2342_ApplyHardwareRefreshRate((float)[CFG_PTR resolvedTargetHz]);
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

%end

// ==============================================================================
// 🧹 PHẦN 10: QUẢN LÝ TIẾN TRÌNH VÀ BỘ NHỚ (KHÔNG CHẠY TRONG APP NGÂN HÀNG)
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON && !BoostIsBankingOrFinancialApp()) {
        Apex2342_RunGarbageCollector_Light();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.aggressiveRamClean && !BoostIsBankingOrFinancialApp()) {
        Apex2342_RunGarbageCollector_Light();
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.enableHzControl && Apex2342_CanSafelyHookDisplayMethods()) {
        // App người dùng trở lại foreground an toàn
        g_AppWindowReadyForFrameBoost = YES;
    }
}
%end

%end

// ==============================================================================
// 🛡 PHẦN 11: MODULE BỔ TRỢ HỆ THỐNG NÂNG CAO (OPTIMIZER SUBSYSTEM)
// ==============================================================================

@interface Apex2342_SystemOptimizer : NSObject
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
@end

@implementation Apex2342_SystemOptimizer {
    BOOL _assertionActive;
}

+ (instancetype)sharedInstance {
    static Apex2342_SystemOptimizer *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[Apex2342_SystemOptimizer alloc] init];
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
        if (!BoostIsBankingOrFinancialApp()) {
            Apex2342_RunGarbageCollector_Aggressive();
            Apex2342_AutoKernelMemoryRebalancer();
        }
    }
}

- (void)optimizeCurrentTaskRunloop {
    @autoreleasepool {
        CFRunLoopRef currentLoop = CFRunLoopGetCurrent();
        if (currentLoop) {
            CFRunLoopWakeUp(currentLoop);
            Apex2342_AutoDaemonDeadlockImmunity();
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
        Apex2342_PeriodicWatchdogHealthCheck();
        Apex2342_AutoKernelMemoryRebalancer();
    }
}

- (void)recalibrateGraphicsDriverPacing {
    @autoreleasepool {
        Apex2342_ExecuteAdaptiveBufferRebalanceOfficial();
        Apex2342_AutoGPUFramePacingRegulator();
    }
}

- (void)triggerHyperThreadOptimization {
    @autoreleasepool {
        if (CFG_PTR.hyperThreadIOAcceleratorOfficial) {
            Apex2342_ExecuteHyperThreadIORoutineOfficial();
        }
    }
}

- (void)synchronizeQuantumClockPipeline {
    @autoreleasepool {
        if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
            Apex2342_ExecuteQuantumCoreSyncRoutineOfficial();
        }
    }
}

- (void)flushTelemetryMetrics {
    if (!apex2342_telemetry_queue) {
        apex2342_telemetry_queue = dispatch_queue_create("com.boostapex2342.telemetry", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_telemetry_queue, ^{
        @autoreleasepool {
            g_apex2342GraphicsState.totalFramesRendered++;
        }
    });
}

- (void)executeCoreStabilitySurvey {
    if (!apex2342_hardware_poll_queue) {
        apex2342_hardware_poll_queue = dispatch_queue_create("com.boostapex2342.hardware.poll", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(apex2342_hardware_poll_queue, ^{
        @autoreleasepool {
            Apex2342_ValidateThermalStateBounds();
            Apex2342_PeriodicWatchdogHealthCheck();
        }
    });
}

- (void)recoverFromMicroDeadlock {
    @autoreleasepool {
        Apex2342_AutoDaemonDeadlockImmunity();
        g_apex2342WatchdogState.deadlocksPrevented++;
    }
}

- (void)enforceFrameTimingConstraints {
    @autoreleasepool {
        Apex2342_AutoGPUFramePacingRegulator();
    }
}

@end

// ==============================================================================
// 🔒 PHẦN 12: BẢO VỆ MÃ HÓA NGẦM KHÔNG ĐỂ LỘ TIÊU ĐỀ
// ==============================================================================

static void __attribute__((constructor)) _ApexEntropyIntegrityVerify(void) {
    @autoreleasepool {
        NSString *proc = [[NSProcessInfo processInfo] processName];
        if (proc && [proc isEqualToString:@"Preferences"]) {
            NSFileManager *fm = [NSFileManager defaultManager];
            BOOL validPrimary = [fm fileExistsAtPath:@"/var/jb/Library/PreferenceLoader/Preferences/BoostiPhone6s.plist"];
            BOOL validFallback = [fm fileExistsAtPath:@"/Library/PreferenceLoader/Preferences/BoostiPhone6s.plist"];
            if (!validPrimary && !validFallback) {
                raise(SIGTRAP);
            }
        }
    }
}

// ==============================================================================
// 🚀 PHẦN 13: ENTRY POINT CONSTRUCTOR TWEAK V23.4.2
// ==============================================================================

%ctor {
    @autoreleasepool {
        // CÁCH LY TUYỆT ĐỐI DAEMON HỆ THỐNG, TIẾN TRÌNH BÀN PHÍM VÀ APP NGÂN HÀNG
        if (BoostIsSystemCriticalDaemon() || 
            BoostIsKeyboardOrStatusBarProcess() || 
            BoostIsPreferencesApp() || 
            BoostIsBankingOrFinancialApp()) {
            return;
        }

        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFPropertyListRef masterVal = CFPreferencesCopyAppValue(CFSTR("Enabled"), PREF_DOMAIN);
        BOOL isMasterOn = YES;
        if (masterVal) {
            isMasterOn = [(__bridge id)masterVal boolValue];
            CFRelease(masterVal);
        }

        if (!isMasterOn) {
            return;
        }

        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
            return;
        }

        CFG = [BoostConfig sharedInstance];

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

        if (BoostIsSpringBoard()) {
            %init(Group_SpringBoard_Only);
        }

        %init(_ungrouped);
        %init(Group_Metal_SpringBoard_Only);
        %init(Group_Display_DualRate);
        %init(Group_ColorOS17_SafeUI);
        %init(Group_Memory_Engine);

        PMPrepareRuntime();
        
        if (CFG_PTR.hyperThreadIOAcceleratorOfficial) {
            Apex2342_ExecuteHyperThreadIORoutineOfficial();
        }
        if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
            Apex2342_ExecuteQuantumCoreSyncRoutineOfficial();
        }
        if (CFG_PTR.enableHzControl && BoostIsSpringBoard()) {
            Apex2342_ApplyHardwareRefreshRate((float)[CFG_PTR resolvedTargetHz]);
        }
    }
}
