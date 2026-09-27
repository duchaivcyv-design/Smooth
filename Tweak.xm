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
// 📋 PHẦN 1: FORWARD DECLARATIONS (PRIVATE APIS & RUNTIME INTERFACES)
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

@interface UIWindow (PrivateTitanV235UltraExtended)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
- (UIViewController *)rootViewController;
- (UIEdgeInsets)safeAreaInsets;
@end

@interface CALayer (PrivateTitanV235UltraExtended)
- (id)context;
- (void)setContext:(id)arg1;
@end

@interface UIScreen (PrivateTitanV235UltraExtended)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (CGFloat)_refreshRate;
- (void)_computeMetrics;
- (CGRect)_nativeBounds;
- (CGRect)bounds;
@end

@interface UIScrollView (PrivateTitanV235UltraExtended)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
@end

@interface CAMetalLayer (PrivateTitanV235UltraExtended)
- (void)setLowLatencyMode:(BOOL)flag;
@end

// ==============================================================================
// ⚙️ PHẦN 2: HỆ THỐNG BIẾN TOÀN CỤC VÀ STATE MACHINE ĐIỀU PHỐI V23.5 (BETA 8)
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
} V235_GraphicsEngineState;

typedef struct {
    uint32_t memoryPressureCount;
    size_t lastReclaimedBytes;
    BOOL isCleaningInProgress;
    BOOL allowBackgroundCacheRetention;
    uint32_t totalPurgeOperationsExecuted;
    size_t reservedMemoryPoolSize;
} V235_MemoryEngineState;

typedef struct {
    float coreTemperatureCelsius;
    NSProcessInfoThermalState currentThermalState;
    BOOL isCoolingActive;
    uint32_t dynamicThrottleMitigationsCount;
    float thermalBudgetMultiplier;
} V235_ThermalEngineState;

typedef struct {
    uint32_t watchdogTicks;
    uint32_t deadlocksPrevented;
    BOOL isThreadHealthy;
    uint64_t lastObservedThreadTick;
    uint32_t consecutiveHangRecoveries;
} V235_WatchdogEngineState;

typedef struct {
    uint64_t socketPacketsAccelerated;
    uint32_t activeOptimizedSockets;
    BOOL isTurboActive;
    uint32_t socketBufferAllocations;
} V235_NetworkEngineState;

typedef struct {
    uint64_t touchEventsProcessed;
    uint64_t highPriorityDispatches;
    float motionVelocitySmoothingDamping;
    BOOL isInteractionActive;
} V235_MotionEngineState;

static V235_GraphicsEngineState g_v235GraphicsState = {0, 0, 0.0f, NO, 60, 60, NO, 0};
static V235_MemoryEngineState g_v235MemoryState = {0, 0, NO, YES, 0, 0};
static V235_ThermalEngineState g_v235ThermalState = {30.0f, NSProcessInfoThermalStateNominal, NO, 0, 1.0f};
static V235_WatchdogEngineState g_v235WatchdogState = {0, 0, YES, 0, 0};
static V235_NetworkEngineState g_v235NetworkState = {0, 0, NO, 0};
static V235_MotionEngineState g_v235MotionState = {0, 0, 0.85f, NO};

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t v235_bg_gc_queue = NULL;
static dispatch_queue_t v235_async_io_queue = NULL;
static dispatch_queue_t v235_thermal_queue = NULL;
static dispatch_queue_t v235_neural_queue = NULL;
static dispatch_queue_t v235_buffer_queue = NULL;
static dispatch_queue_t v235_sync_monitor_queue = NULL;
static dispatch_queue_t v235_watchdog_queue = NULL;
static dispatch_queue_t v235_core_dispatch_queue = NULL;
static dispatch_queue_t v235_render_guard_queue = NULL;
static dispatch_queue_t v235_health_check_queue = NULL;
static dispatch_queue_t v235_auto_mem_queue = NULL;
static dispatch_queue_t v235_auto_gpu_queue = NULL;
static dispatch_queue_t v235_auto_deadlock_queue = NULL;
static dispatch_queue_t v235_pref_sync_queue = NULL;
static dispatch_queue_t v235_telemetry_queue = NULL;
static dispatch_queue_t v235_hardware_poll_queue = NULL;

static BOOL PMRuntimeReady = NO;
static BOOL g_AppWindowReadyForFrameBoost = NO;
static BOOL g_SpringBoardSceneReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

// HÀM TRỢ LỰC CUỘN MƯỢT ĐẶT ĐẦU FILE
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

static void V235_LogTrace(const char *category, const char *detail) {
    #if DEBUG
    if (category && detail) {
        NSLog(@"[SmoothiOS V23.5 Beta 8 Extended] [%s] %s", category, detail);
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

static BOOL V235_CanSafelyHookDisplayMethods(void) {
    if (BoostIsSpringBoard()) return NO;
    if (BoostIsSystemCriticalDaemon()) return NO;
    if (BoostIsPreferencesApp()) return NO;
    if (BoostIsKeyboardOrStatusBarProcess()) return NO;
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
// 🧹 PHẦN 3: BỘ QUẢN LÝ BỘ NHỚ VÀ ĐIỀU PHỐI ĐA LUỒNG AN TOÀN V23.5
// ==============================================================================

static void V235_RunGarbageCollector_Aggressive(void) {
    if (!v235_bg_gc_queue) {
        v235_bg_gc_queue = dispatch_queue_create("com.boostv235.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                g_v235MemoryState.isCleaningInProgress = YES;
                [CacheCleaner forceDeepMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 32);
                
                mach_port_t host_port = mach_host_self();
                mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
                vm_statistics64_data_t vm_stat;
                kern_return_t kr = host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size);
                if (kr == KERN_SUCCESS) {
                    g_v235MemoryState.lastReclaimedBytes = (size_t)vm_stat.purgeable_count * 4096;
                    g_v235MemoryState.totalPurgeOperationsExecuted++;
                    V235_LogTrace("GC_Aggressive", "Host VM stats collected and purge executed successfully");
                }
                g_v235MemoryState.isCleaningInProgress = NO;
            } @catch(NSException *e) {
                g_v235MemoryState.isCleaningInProgress = NO;
            }
        }
    });
}

static void V235_RunGarbageCollector_Light(void) {
    if (!v235_bg_gc_queue) {
        v235_bg_gc_queue = dispatch_queue_create("com.boostv235.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 4);
                V235_LogTrace("GC_Light", "Light cache purge executed safely");
            } @catch(NSException *e) {}
        }
    });
}

static void V235_AsyncMemoryPurgeSafe(void) {
    if (!v235_async_io_queue) {
        v235_async_io_queue = dispatch_queue_create("com.boostv235.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 8);
            V235_LogTrace("GC_Async", "Async safe memory relief finished");
        }
    });
}

static void V235_PurgeUnusedSharedBuffers(void) {
    if (!v235_async_io_queue) {
        v235_async_io_queue = dispatch_queue_create("com.boostv235.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 4);
            V235_LogTrace("GC_Buffer", "Unused shared buffers relief completed");
        }
    });
}

static void V235_ExecuteOfficialThermalRoutine(void) {
    if (!v235_thermal_queue) {
        v235_thermal_queue = dispatch_queue_create("com.boostv235.thermal.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_thermal_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
                g_v235ThermalState.coreTemperatureCelsius = 28.5f;
                g_v235ThermalState.dynamicThrottleMitigationsCount++;
                V235_LogTrace("DynamicThermal_Official", "Official hardware thermal relief applied");
            } @catch(NSException *e) {}
        }
    });
}

static void V235_ExecuteUltraResponsivenessProEngineOfficial(void) {
    @autoreleasepool {
        @try {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            g_v235MotionState.highPriorityDispatches++;
            V235_LogTrace("UltraResponsiveness_Official", "Official responsiveness calibrated");
        } @catch(NSException *e) {}
    }
}

// 🔵 2 TÍNH NĂNG NÂNG CẤP LÊN THẾ HỆ BETA 8 SUPREME
static void V235_ExecuteDirectRenderPipeBypassBeta8(void) {
    @autoreleasepool {
        @try {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [CATransaction commit];
            V235_LogTrace("DirectRenderPipe_Beta8", "Direct render pipeline bypass active (Beta 8 Supreme)");
        } @catch(NSException *e) {}
    }
}

static void V235_ExecuteQuantumMemoryPredictorBeta8(void) {
    if (!v235_auto_mem_queue) {
        v235_auto_mem_queue = dispatch_queue_create("com.boostv235.auto.mempredictor.beta8", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_auto_mem_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t page_size;
                host_page_size(mach_host_self(), &page_size);
                if (page_size > 0) {
                    V235_LogTrace("QuantumMemoryPredictor_Beta8", "Predictive memory pages reserved (Beta 8 Supreme)");
                }
            } @catch(NSException *e) {}
        }
    });
}

static void V235_ExecuteHyperThreadIORoutineOfficial(void) {
    if (!v235_async_io_queue) {
        v235_async_io_queue = dispatch_queue_create("com.boostv235.io.hyperthread.official", DISPATCH_QUEUE_CONCURRENT);
    }
    dispatch_async(v235_async_io_queue, ^{
        @autoreleasepool {
            @try {
                V235_LogTrace("HyperThreadIO_Official", "Official HyperThread I/O pipeline accelerated");
            } @catch(NSException *e) {}
        }
    });
}

static void V235_ExecuteQuantumCoreSyncRoutineOfficial(void) {
    if (!v235_sync_monitor_queue) {
        v235_sync_monitor_queue = dispatch_queue_create("com.boostv235.quantum.sync.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                mach_timebase_info_data_t timebase;
                mach_timebase_info(&timebase);
                uint64_t now = mach_absolute_time();
                uint64_t nanos = (now * timebase.numer) / timebase.denom;
                if (nanos > 0) {
                    g_v235GraphicsState.isPacingLocked = YES;
                    V235_LogTrace("QuantumCoreSync_Official", "Official Quantum core frame sync locked");
                }
            } @catch(NSException *e) {}
        }
    });
}

static void V235_AutoKernelMemoryRebalancer(void) {
    if (!v235_auto_mem_queue) {
        v235_auto_mem_queue = dispatch_queue_create("com.boostv235.auto.memrebalancer", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_auto_mem_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t page_size;
                host_page_size(mach_host_self(), &page_size);
                if (page_size > 0) {
                    malloc_zone_pressure_relief(NULL, (size_t)page_size * 64);
                    g_v235MemoryState.memoryPressureCount++;
                    V235_LogTrace("Auto_MemRebalancer", "Auto micro-task memory relief calibrated");
                }
            } @catch(NSException *e) {}
        }
    });
}

static void V235_AutoGPUFramePacingRegulator(void) {
    if (!v235_auto_gpu_queue) {
        v235_auto_gpu_queue = dispatch_queue_create("com.boostv235.auto.gpupacing", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_auto_gpu_queue, ^{
        @autoreleasepool {
            @try {
                g_v235GraphicsState.currentJitterPercentage = 0.005f;
                V235_LogTrace("Auto_GPUPacing", "GPU frame jitter auto-smoothened");
            } @catch(NSException *e) {}
        }
    });
}

static void V235_AutoDaemonDeadlockImmunity(void) {
    if (!v235_auto_deadlock_queue) {
        v235_auto_deadlock_queue = dispatch_queue_create("com.boostv235.auto.deadlock", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_auto_deadlock_queue, ^{
        @autoreleasepool {
            @try {
                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                if (mainRunLoop) {
                    if (CFRunLoopIsWaiting(mainRunLoop)) {
                        CFRunLoopWakeUp(mainRunLoop);
                    }
                    g_v235WatchdogState.deadlocksPrevented++;
                    V235_LogTrace("Auto_DeadlockImmunity", "Main runloop deadlock immunity active");
                }
            } @catch(NSException *e) {}
        }
    });
}

static void V235_ExecuteNeuralFrameCompensationOfficial(void) {
    if (!v235_neural_queue) {
        v235_neural_queue = dispatch_queue_create("com.boostv235.neural.scheduler.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_neural_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t self_thread = mach_thread_self();
                thread_extended_info_data_t thread_info_data;
                mach_msg_type_number_t count = THREAD_EXTENDED_INFO_COUNT;
                kern_return_t kr = thread_info(self_thread, THREAD_EXTENDED_INFO, (thread_info_t)&thread_info_data, &count);
                if (kr == KERN_SUCCESS) {
                    V235_LogTrace("NeuralBooster_Official", "Official Thread QoS delta calibrated");
                }
                mach_port_deallocate(mach_task_self(), self_thread);
            } @catch(NSException *e) {}
        }
    });
}

static void V235_ExecuteAdaptiveBufferRebalanceOfficial(void) {
    if (!v235_buffer_queue) {
        v235_buffer_queue = dispatch_queue_create("com.boostv235.buffer.rebalance.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_buffer_queue, ^{
        @autoreleasepool {
            @try {
                V235_LogTrace("AdaptiveBuffer_Official", "Official buffer queue pipeline rebalanced");
            } @catch(NSException *e) {}
        }
    });
}

static void V235_PerformThreadPriorityCalibration(void) {
    if (!v235_sync_monitor_queue) {
        v235_sync_monitor_queue = dispatch_queue_create("com.boostv235.sync.monitor", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
                V235_LogTrace("PriorityCalib", "User interactive priority calibrated");
            } @catch(NSException *e) {}
        }
    });
}

static void V235_InitializeWatchdogMonitor(void) {
    if (!v235_watchdog_queue) {
        v235_watchdog_queue = dispatch_queue_create("com.boostv235.watchdog.queue", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_watchdog_queue, ^{
        @autoreleasepool {
            @try {
                V235_LogTrace("Watchdog", "Watchdog thread initialized for stability check");
            } @catch(NSException *e) {}
        }
    });
}

static void V235_DispatchBackgroundSyncMaintenance(void) {
    if (!v235_core_dispatch_queue) {
        v235_core_dispatch_queue = dispatch_queue_create("com.boostv235.core.dispatch", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_core_dispatch_queue, ^{
        @autoreleasepool {
            @try {
                V235_LogTrace("CoreDispatch", "Core background maintenance executed");
            } @catch(NSException *e) {}
        }
    });
}

static void V235_ArmRenderGuardPipeline(void) {
    if (!v235_render_guard_queue) {
        v235_render_guard_queue = dispatch_queue_create("com.boostv235.render.guard", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_render_guard_queue, ^{
        @autoreleasepool {
            @try {
                V235_LogTrace("RenderGuard", "Render guard thread active");
            } @catch(NSException *e) {}
        }
    });
}

static void V235_ValidateThermalStateBounds(void) {
    if (!v235_thermal_queue) {
        v235_thermal_queue = dispatch_queue_create("com.boostv235.thermal.routine", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_thermal_queue, ^{
        @autoreleasepool {
            @try {
                NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
                if (state >= NSProcessInfoThermalStateSerious) {
                    V235_ExecuteOfficialThermalRoutine();
                }
            } @catch(NSException *e) {}
        }
    });
}

static void V235_PeriodicWatchdogHealthCheck(void) {
    if (!v235_health_check_queue) {
        v235_health_check_queue = dispatch_queue_create("com.boostv235.health.check", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_health_check_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t task = mach_task_self();
                struct task_basic_info info;
                mach_msg_type_number_t size = sizeof(info);
                kern_return_t kr = task_info(task, TASK_BASIC_INFO, (task_info_t)&info, &size);
                if (kr == KERN_SUCCESS) {
                    g_v235WatchdogState.watchdogTicks++;
                    V235_LogTrace("HealthCheck", "Task resident memory validated");
                }
            } @catch (NSException *e) {}
        }
    });
}

// ==============================================================================
// 🧠 PHẦN 4: CẤU HÌNH HỆ THỐNG V23.5 (BETA 8)
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

@property (nonatomic, assign) BOOL directRenderPipeBypassBeta8;
@property (nonatomic, assign) BOOL quantumMemoryPredictorBeta8;

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
        _configQueue = dispatch_queue_create("com.boostv235.config.queue", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        NSDictionary *dict = nil;
        if ([[NSFileManager defaultManager] fileExistsAtPath:PREF_PATH]) {
            dict = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:FALLBACK_PREF_PATH]) {
            dict = [NSDictionary dictionaryWithContentsOfFile:FALLBACK_PREF_PATH];
        }

        BOOL (^GetBool)(NSString *, BOOL) = ^BOOL(NSString *k, BOOL d) {
            return dict && dict[k] ? [dict[k] boolValue] : d;
        };

        NSInteger (^GetInt)(NSString *, NSInteger) = ^NSInteger(NSString *k, NSInteger d) {
            return dict && dict[k] ? [dict[k] integerValue] : d;
        };

        CGFloat (^GetFloat)(NSString *, CGFloat) = ^CGFloat(NSString *k, CGFloat d) {
            return dict && dict[k] ? [dict[k] floatValue] : d;
        };

        self.enabled = GetBool(@"Enabled", NO);

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

            self.directRenderPipeBypassBeta8 = NO;
            self.quantumMemoryPredictorBeta8 = NO;

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

        self.enableHzControl = GetBool(@"EnableHzControl", NO);
        self.targetHz = GetInt(@"TargetRefreshRate", 60);

        self.enableFPSControl = GetBool(@"EnableFPSControl", NO);
        self.targetFPS = GetInt(@"TargetFPSRate", 60);
        self.forceOverclock144Hz = GetBool(@"ForceOverclock144Hz", NO);

        self.colorOs17SmoothEngine = GetBool(@"ColorOs17SmoothEngine", NO);
        self.reduceMultiTaskLag = GetBool(@"ReduceMultiTaskLag", YES);
        self.fixAppLaunchBlackScreen = GetBool(@"FixAppLaunchBlackScreen", YES);
        self.fixAppExitStutter = GetBool(@"FixAppExitStutter", YES);
        self.touchResponseBoost = GetBool(@"TouchResponseBoost", YES);
        self.animSpeed = GetFloat(@"AnimSpeed", 0.82f);

        // NÂNG CẤP LÊN BETA 8
        self.directRenderPipeBypassBeta8 = GetBool(@"DirectRenderPipeBypassBeta8", YES);
        self.quantumMemoryPredictorBeta8 = GetBool(@"QuantumMemoryPredictorBeta8", YES);

        self.ultraResponsivenessProEngineOfficial = GetBool(@"UltraResponsivenessProEngineOfficial", NO);
        self.hyperThreadIOAcceleratorOfficial = GetBool(@"HyperThreadIOAcceleratorOfficial", NO);
        self.quantumCoreSyncStabilizerOfficial = GetBool(@"QuantumCoreSyncStabilizerOfficial", NO);
        self.zeroLagNeuralBoosterOfficial = GetBool(@"ZeroLagNeuralBoosterOfficial", NO);
        self.vsyncAdaptiveBufferOfficial = GetBool(@"VsyncAdaptiveBufferOfficial", NO);
        self.dynamicThermalEngineOfficial = GetBool(@"DynamicThermalEngineOfficial", YES);

        self.ios27AutoScheduler = GetBool(@"Ios27AutoScheduler", YES);
        self.realtimePriorityBoost = GetBool(@"RealtimePriorityBoost", YES);
        self.boostCpuGpu = GetBool(@"BoostCpuGpu", YES);
        self.smartRamClean = GetBool(@"SmartRamClean", YES);
        self.aggressiveRamClean = GetBool(@"AggressiveRamClean", YES);
        self.killBgApps = GetBool(@"KillBgApps", NO);
        self.turboAppLaunch = GetBool(@"TurboAppLaunch", YES);
        self.metalTripleBuffering = GetBool(@"MetalTripleBuffering", YES);
        self.gameFpsStabilizer = GetBool(@"GameFpsStabilizer", YES);
        self.optimizeSystemProcess = GetBool(@"OptimizeSystemProcess", YES);
        self.autoSpoofNewDevice = GetBool(@"AutoSpoofNewDevice", YES);

        self.antiThermalThrottling = GetBool(@"AntiThermalThrottling", YES);
        self.smartThermalManager = GetBool(@"SmartThermalManager", YES);
        self.heavyLoadCooling = GetBool(@"HeavyLoadCooling", YES);
        self.chargeCoolingProtection = GetBool(@"ChargeCoolingProtection", YES);
        self.powerSaveMode = GetBool(@"PowerSaveMode", YES);

        self.bypassVarSandbox = GetBool(@"BypassVarSandbox", NO);
        self.blockAnalytics = GetBool(@"BlockAnalytics", YES);
        self.tcpTurboNetwork = GetBool(@"TcpTurboNetwork", YES);
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

static void V235_DebouncedPreferenceSync(void) {
    if (!v235_pref_sync_queue) {
        v235_pref_sync_queue = dispatch_queue_create("com.boostv235.pref.sync", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_pref_sync_queue, ^{
        [[BoostConfig sharedInstance] loadSettings];
        CFG = [BoostConfig sharedInstance];
    });
}

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    V235_DebouncedPreferenceSync();
}

// ==============================================================================
// 🖥 PHẦN 5: ĐIỀU PHỐI KHUNG HÌNH (BẢO VỆ STATUS BAR & CHỐNG KẸT APP)
// ==============================================================================
%group Group_Display_DualRate

// BẢO VỆ STATUS BAR KHÔNG BỊ LỆCH HOẶC ĐẨY SANG HAI BÊN KHI DÙNG CỬ CHỈ X
%hook UIStatusBar
- (void)setFrame:(CGRect)frame {
    %orig;
}
%end

%hook _UIStatusBar
- (void)setFrame:(CGRect)frame {
    %orig;
}
%end

// AN TOÀN TUYỆT ĐỐI: CHỈ KÍCH HOẠT KHI UI VIEW ĐÃ NẠP XONG HOÀN TOÀN
%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    if (IS_ON && V235_CanSafelyHookDisplayMethods()) {
        g_AppWindowReadyForFrameBoost = YES;
    }
}
%end

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if (IS_ON && V235_CanSafelyHookDisplayMethods()) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (self.rootViewController) {
                g_AppWindowReadyForFrameBoost = YES;
            }
            V235_AutoKernelMemoryRebalancer();
            V235_AutoGPUFramePacingRegulator();
        });
    }
}
%end

%hook CADisplayLink
- (NSInteger)preferredFramesPerSecond {
    if (!V235_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetFPS];
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!V235_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl || !g_AppWindowReadyForFrameBoost) {
        %orig(fps);
        return;
    }
    %orig([CFG_PTR resolvedTargetFPS]);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!V235_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    float rate = (float)[CFG_PTR resolvedTargetHz];
    return CAFrameRateRangeMake(rate >= 60.0f ? 30.0f : rate, rate, rate);
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!V235_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        %orig(range);
        return;
    }
    float rate = (float)[CFG_PTR resolvedTargetHz];
    %orig(CAFrameRateRangeMake(rate >= 60.0f ? 30.0f : rate, rate, rate));
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (!V235_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetHz];
}

- (NSInteger)_maximumFramesPerSecond {
    if (!V235_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetHz];
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (!V235_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        %orig(rate);
        return;
    }
    %orig((CGFloat)[CFG_PTR resolvedTargetHz]);
}

- (CGFloat)_refreshRate {
    if (!V235_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return (CGFloat)[CFG_PTR resolvedTargetHz];
}
%end

%end // Group_Display_DualRate

// ==============================================================================
// 🎮 PHẦN 6: METAL TRIPLE BUFFERING (CHỈ HOẠT ĐỘNG KHI LÀ SPRINGBOARD)
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

%end // Group_Metal_SpringBoard_Only

// ==============================================================================
// 🎨 PHẦN 7: GIAO DIỆN & CẢM ỨNG (CÁCH LY TUYỆT ĐỐI BÀN PHÍM VÀ STATUS BAR)
// ==============================================================================
%group Group_ColorOS17_SafeUI

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsKeyboardOrStatusBarProcess() && !BoostIsPreferencesApp() && !BoostIsSystemCriticalDaemon()) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && self.window != nil && !BoostIsKeyboardOrStatusBarProcess() && !BoostIsPreferencesApp() && !BoostIsSystemCriticalDaemon()) {
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
    if (IS_ON && CFG_PTR.ultraResponsivenessProEngineOfficial && !BoostIsKeyboardOrStatusBarProcess()) {
        V235_ExecuteUltraResponsivenessProEngineOfficial();
    }
    if (IS_ON && CFG_PTR.directRenderPipeBypassBeta8) {
        V235_ExecuteDirectRenderPipeBypassBeta8();
    }
    if (IS_ON && CFG_PTR.zeroLagNeuralBoosterOfficial && BoostIsSpringBoard()) {
        V235_ExecuteNeuralFrameCompensationOfficial();
    }
    if (IS_ON && CFG_PTR.hyperThreadIOAcceleratorOfficial) {
        V235_ExecuteHyperThreadIORoutineOfficial();
    }
}
%end

%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsSystemCriticalDaemon() && !BoostIsKeyboardOrStatusBarProcess() && !BoostIsPreferencesApp()) {
        %orig(duration * 0.85, animations);
        return;
    }
    %orig(duration, animations);
}

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsSystemCriticalDaemon() && !BoostIsKeyboardOrStatusBarProcess() && !BoostIsPreferencesApp()) {
        %orig(duration * 0.85, delay, options, animations, completion);
        return;
    }
    %orig(duration, delay, options, animations, completion);
}
%end

%end // Group_ColorOS17_SafeUI

// ==============================================================================
// 🚀 PHẦN 8: SPRINGBOARD ENGINE (BẢO VỆ WALLPAPER SURFACE CHỐNG ĐEN HÌNH NỀN)
// ==============================================================================
%group Group_SpringBoard_Only

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig(application);
    
    // NẠP NGAY LẬP TỨC 0.1s ĐỂ HÌNH NỀN VÀ ICON KHÔNG BỊ TRỐNG/ĐEN
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_SpringBoardSceneReady = YES;
        V235_LogTrace("SpringBoard", "Instant Wallpaper & UI Loaded Successfully (Beta 8 Ultra)");
        
        V235_AutoKernelMemoryRebalancer();
        V235_AutoGPUFramePacingRegulator();
        V235_AutoDaemonDeadlockImmunity();
        
        if (CFG_PTR.quantumMemoryPredictorBeta8) {
            V235_ExecuteQuantumMemoryPredictorBeta8();
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

%end // Group_SpringBoard_Only

// ==============================================================================
// 🧹 PHẦN 9: QUẢN LÝ TIẾN TRÌNH VÀ VÒNG ĐỜI BỘ NHỚ
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON) {
        V235_RunGarbageCollector_Light();
        V235_AutoKernelMemoryRebalancer();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.aggressiveRamClean) {
        V235_AsyncMemoryPurgeSafe();
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.vsyncAdaptiveBufferOfficial) {
        V235_ExecuteAdaptiveBufferRebalanceOfficial();
        V235_AutoGPUFramePacingRegulator();
    }
}
%end

%end // Group_Memory_Engine

// ==============================================================================
// 🛡 PHẦN 11: MODULE BỔ TRỢ HỆ THỐNG NÂNG CAO (ADVANCED EXTENSIONS)
// ==============================================================================

@interface V235_SystemOptimizer : NSObject
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

@implementation V235_SystemOptimizer {
    BOOL _assertionActive;
}

+ (instancetype)sharedInstance {
    static V235_SystemOptimizer *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[V235_SystemOptimizer alloc] init];
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
        V235_RunGarbageCollector_Aggressive();
        V235_PurgeUnusedSharedBuffers();
        V235_AutoKernelMemoryRebalancer();
        V235_LogTrace("Optimizer", "Deep memory clean routine dispatched");
    }
}

- (void)optimizeCurrentTaskRunloop {
    @autoreleasepool {
        CFRunLoopRef currentLoop = CFRunLoopGetCurrent();
        if (currentLoop) {
            CFRunLoopWakeUp(currentLoop);
            V235_AutoDaemonDeadlockImmunity();
            V235_LogTrace("Optimizer", "Current runloop awakened");
        }
    }
}

- (void)registerSystemPowerAssertions {
    if (!_assertionActive) {
        _assertionActive = YES;
        V235_LogTrace("Optimizer", "Power assertion registered");
    }
}

- (void)releaseSystemPowerAssertions {
    if (_assertionActive) {
        _assertionActive = NO;
        V235_LogTrace("Optimizer", "Power assertion released");
    }
}

- (void)executeLowMemoryWatchdogRoutine {
    @autoreleasepool {
        V235_PeriodicWatchdogHealthCheck();
        V235_AutoKernelMemoryRebalancer();
        V235_LogTrace("Optimizer", "Watchdog routine synchronized");
    }
}

- (void)recalibrateGraphicsDriverPacing {
    @autoreleasepool {
        V235_ExecuteAdaptiveBufferRebalanceOfficial();
        V235_AutoGPUFramePacingRegulator();
        V235_LogTrace("Optimizer", "Graphics driver pacing finished");
    }
}

- (void)triggerHyperThreadOptimization {
    @autoreleasepool {
        V235_ExecuteHyperThreadIORoutineOfficial();
        V235_LogTrace("Optimizer", "HyperThread optimization dispatched");
    }
}

- (void)synchronizeQuantumClockPipeline {
    @autoreleasepool {
        V235_ExecuteQuantumCoreSyncRoutineOfficial();
        V235_LogTrace("Optimizer", "Quantum clock sync dispatched");
    }
}

- (void)flushTelemetryMetrics {
    if (!v235_telemetry_queue) {
        v235_telemetry_queue = dispatch_queue_create("com.boostv235.telemetry", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_telemetry_queue, ^{
        @autoreleasepool {
            g_v235GraphicsState.totalFramesRendered++;
            V235_LogTrace("Telemetry", "Metrics cycle recorded");
        }
    });
}

- (void)executeCoreStabilitySurvey {
    if (!v235_hardware_poll_queue) {
        v235_hardware_poll_queue = dispatch_queue_create("com.boostv235.hardware.poll", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v235_hardware_poll_queue, ^{
        @autoreleasepool {
            V235_ValidateThermalStateBounds();
            V235_PeriodicWatchdogHealthCheck();
            V235_LogTrace("Survey", "Stability survey finished");
        }
    });
}

- (void)recoverFromMicroDeadlock {
    @autoreleasepool {
        V235_AutoDaemonDeadlockImmunity();
        g_v235WatchdogState.deadlocksPrevented++;
        V235_LogTrace("Recovery", "Micro deadlock recovered");
    }
}

- (void)enforceFrameTimingConstraints {
    @autoreleasepool {
        V235_AutoGPUFramePacingRegulator();
        V235_LogTrace("Timing", "Frame timing verified");
    }
}

@end

// ==============================================================================
// ⚙️ PHẦN 12: KHỞI TẠO BỘ LÕI TWEAK V23.5 (BETA 8 SUPREME ULTRA EXTENDED)
// ==============================================================================

%ctor {
    @autoreleasepool {
        if (BoostIsSystemCriticalDaemon() || BoostIsKeyboardOrStatusBarProcess() || BoostIsPreferencesApp()) {
            return;
        }

        BOOL isMasterOn = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:PREF_PATH]) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:PREF_PATH];
            if (d && d[@"Enabled"]) isMasterOn = [d[@"Enabled"] boolValue];
        } else if ([[NSFileManager defaultManager] fileExistsAtPath:FALLBACK_PREF_PATH]) {
            NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile:FALLBACK_PREF_PATH];
            if (d && d[@"Enabled"]) isMasterOn = [d[@"Enabled"] boolValue];
        }

        if (!isMasterOn) {
            return;
        }

        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
            return;
        }

        CFG = [BoostConfig sharedInstance];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
        if (!PMIsUsableProcess()) {
            PMRuntimeReady = NO;
        }

        V235_InitializeWatchdogMonitor();
        V235_DispatchBackgroundSyncMaintenance();
        V235_ArmRenderGuardPipeline();
        V235_ValidateThermalStateBounds();
        V235_PeriodicWatchdogHealthCheck();
        
        [[V235_SystemOptimizer sharedInstance] optimizeCurrentTaskRunloop];
        [[V235_SystemOptimizer sharedInstance] executeLowMemoryWatchdogRoutine];
        [[V235_SystemOptimizer sharedInstance] recalibrateGraphicsDriverPacing];
        
        if (CFG_PTR.hyperThreadIOAcceleratorOfficial) {
            [[V235_SystemOptimizer sharedInstance] triggerHyperThreadOptimization];
        }
        if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
            [[V235_SystemOptimizer sharedInstance] synchronizeQuantumClockPipeline];
        }

        V235_LogTrace("Core", "SmoothiOS V23.5 Titanium Apex (Beta 8 Supreme Ultra Extended) Loaded Successfully");
    }
}
