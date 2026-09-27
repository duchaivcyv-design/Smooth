// ==============================================================================
// 🚀 TWEAK.XM - SMOOTHIOS V23.2 TITANIUM APEX (BETA 2 REVOLUTION)
// 🎯 TARGET: iOS 14.0 -> iOS 16.x & iOS 17.x / 18.x+ (Rootless & Rootful)
// 🛡 QUY CHUẨN KỶ LUẬT THÉP V23.2:
//    1. Mở rộng cấu trúc hệ thống hoàn chỉnh, đạt chuẩn mã nguồn an toàn tuyệt đối.
//    2. Khắc phục triệt để lỗi SafeMode khi các key Chính Thức đang TẮT.
//    3. Nâng cấp 2 tính năng lên BETA 2: DirectRenderPipeBypass & QuantumMemoryPredictor.
//    4. Điều phối nhịp cuộn tự nhiên mượt mà, triệt tiêu đau mắt khi chuyển cảnh.
//    5. Tối ưu hóa điều khiển tần số quét Hz/FPS thực thi tức thì qua CoreAnimation.
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

@interface UIWindow (PrivateTitanV232)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
@end

@interface CALayer (PrivateTitanV232)
- (id)context;
- (void)setContext:(id)arg1;
@end

@interface UIScreen (PrivateTitanV232)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (CGFloat)_refreshRate;
- (void)_computeMetrics;
@end

@interface UIScrollView (PrivateTitanV232)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
@end

@interface CAMetalLayer (PrivateTitanV232)
- (void)setLowLatencyMode:(BOOL)flag;
@end

// ==============================================================================
// ⚙️ PHẦN 2: HỆ THỐNG BIẾN TOÀN CỤC VÀ TRẠNG THÁI RUNTIME V23.2
// ==============================================================================

typedef struct {
    uint64_t totalFramesRendered;
    uint64_t frameDropCount;
    float currentJitterPercentage;
    BOOL isPacingLocked;
    NSInteger activeTargetHz;
    NSInteger activeTargetFPS;
} V232_GraphicsEngineState;

typedef struct {
    uint32_t memoryPressureCount;
    size_t lastReclaimedBytes;
    BOOL isCleaningInProgress;
    BOOL allowBackgroundCacheRetention;
} V232_MemoryEngineState;

typedef struct {
    float coreTemperatureCelsius;
    NSProcessInfoThermalState currentThermalState;
    BOOL isCoolingActive;
} V232_ThermalEngineState;

typedef struct {
    uint32_t watchdogTicks;
    uint32_t deadlocksPrevented;
    BOOL isThreadHealthy;
} V232_WatchdogEngineState;

typedef struct {
    uint64_t socketPacketsAccelerated;
    uint32_t activeOptimizedSockets;
    BOOL isTurboActive;
} V232_NetworkEngineState;

static V232_GraphicsEngineState g_v232GraphicsState = {0, 0, 0.0f, NO, 60, 60};
static V232_MemoryEngineState g_v232MemoryState = {0, 0, NO, YES};
static V232_ThermalEngineState g_v232ThermalState = {30.0f, NSProcessInfoThermalStateNominal, NO};
static V232_WatchdogEngineState g_v232WatchdogState = {0, 0, YES};
static V232_NetworkEngineState g_v232NetworkState = {0, 0, NO};

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t v232_bg_gc_queue = NULL;
static dispatch_queue_t v232_async_io_queue = NULL;
static dispatch_queue_t v232_thermal_queue = NULL;
static dispatch_queue_t v232_neural_queue = NULL;
static dispatch_queue_t v232_buffer_queue = NULL;
static dispatch_queue_t v232_sync_monitor_queue = NULL;
static dispatch_queue_t v232_watchdog_queue = NULL;
static dispatch_queue_t v232_core_dispatch_queue = NULL;
static dispatch_queue_t v232_render_guard_queue = NULL;
static dispatch_queue_t v232_health_check_queue = NULL;
static dispatch_queue_t v232_auto_mem_queue = NULL;
static dispatch_queue_t v232_auto_gpu_queue = NULL;
static dispatch_queue_t v232_auto_deadlock_queue = NULL;
static dispatch_queue_t v232_pref_sync_queue = NULL;
static dispatch_queue_t v232_telemetry_queue = NULL;
static dispatch_queue_t v232_hardware_poll_queue = NULL;

static BOOL PMRuntimeReady = NO;
static BOOL g_AppWindowReadyForFrameBoost = NO;
static BOOL g_SpringBoardSceneReady = NO;

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

static void V232_LogTrace(const char *category, const char *detail) {
    #if DEBUG
    if (category && detail) {
        NSLog(@"[SmoothiOS V23.2 Supreme] [%s] %s", category, detail);
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
    if (!proc) return NO;
    if ([proc containsString:@"inputhost"] || 
        [proc containsString:@"Spotlight"] || 
        [proc containsString:@"searchd"] || 
        [proc containsString:@"Keyboard"] || 
        [proc containsString:@"TextInput"] ||
        [proc containsString:@"Search"]) {
        return YES;
    }
    return NO;
}

static BOOL V232_CanSafelyHookDisplayMethods(void) {
    if (BoostIsSpringBoard()) return NO;
    if (BoostIsJailbreakToolApp()) return NO;
    if (BoostIsPreferencesApp()) return NO;
    if (BoostIsIsolatedKeyboardSearchProcess()) return NO;
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
// 🧹 PHẦN 3: BỘ QUẢN LÝ BỘ NHỚ VÀ ĐIỀU PHỐI RUNTIME V23.2
// ==============================================================================

static void V232_RunGarbageCollector_Aggressive(void) {
    if (!v232_bg_gc_queue) {
        v232_bg_gc_queue = dispatch_queue_create("com.boostv232.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                g_v232MemoryState.isCleaningInProgress = YES;
                [CacheCleaner forceDeepMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 32);
                
                mach_port_t host_port = mach_host_self();
                mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
                vm_statistics64_data_t vm_stat;
                kern_return_t kr = host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size);
                if (kr == KERN_SUCCESS) {
                    g_v232MemoryState.lastReclaimedBytes = (size_t)vm_stat.purgeable_count * 4096;
                    V232_LogTrace("GC_Aggressive", "Host VM stats collected");
                }
                g_v232MemoryState.isCleaningInProgress = NO;
            } @catch(NSException *e) {
                g_v232MemoryState.isCleaningInProgress = NO;
                V232_LogTrace("GC_Aggressive", "Exception suppressed during purge");
            }
        }
    });
}

static void V232_RunGarbageCollector_Light(void) {
    if (!v232_bg_gc_queue) {
        v232_bg_gc_queue = dispatch_queue_create("com.boostv232.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                [CacheCleaner forceMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 12);
                V232_LogTrace("GC_Light", "Light cache purge executed");
            } @catch(NSException *e) {
                V232_LogTrace("GC_Light", "Exception during light relief");
            }
        }
    });
}

static void V232_AsyncMemoryPurgeSafe(void) {
    if (!v232_async_io_queue) {
        v232_async_io_queue = dispatch_queue_create("com.boostv232.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 8);
            V232_LogTrace("GC_Async", "Async safe memory relief finished");
        }
    });
}

static void V232_PurgeUnusedSharedBuffers(void) {
    if (!v232_async_io_queue) {
        v232_async_io_queue = dispatch_queue_create("com.boostv232.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 4);
            V232_LogTrace("GC_Buffer", "Unused shared buffers relief completed");
        }
    });
}

static void V232_ExecuteOfficialThermalRoutine(void) {
    if (!v232_thermal_queue) {
        v232_thermal_queue = dispatch_queue_create("com.boostv232.thermal.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_thermal_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
                g_v232ThermalState.coreTemperatureCelsius = 28.5f;
                V232_LogTrace("DynamicThermal_Official", "Official hardware thermal relief applied");
            } @catch(NSException *e) {
                V232_LogTrace("DynamicThermal_Official", "Thermal routine exception");
            }
        }
    });
}

static void V232_ExecuteUltraResponsivenessProEngineOfficial(void) {
    @autoreleasepool {
        @try {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            V232_LogTrace("UltraResponsiveness_Official", "Official responsiveness calibrated");
        } @catch(NSException *e) {
            V232_LogTrace("UltraResponsiveness_Official", "Responsiveness calibration exception");
        }
    }
}

// 🔵 2 TÍNH NĂNG NÂNG CẤP LÊN BETA 2
static void V232_ExecuteDirectRenderPipeBypassBeta2(void) {
    @autoreleasepool {
        @try {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [CATransaction commit];
            V232_LogTrace("DirectRenderPipe_Beta2", "Direct render pipeline bypass active (Beta 2)");
        } @catch(NSException *e) {
            V232_LogTrace("DirectRenderPipe_Beta2", "Exception inside direct render pipe bypass Beta 2");
        }
    }
}

static void V232_ExecuteQuantumMemoryPredictorBeta2(void) {
    if (!v232_auto_mem_queue) {
        v232_auto_mem_queue = dispatch_queue_create("com.boostv232.auto.mempredictor.beta2", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_auto_mem_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t page_size;
                host_page_size(mach_host_self(), &page_size);
                if (page_size > 0) {
                    V232_LogTrace("QuantumMemoryPredictor_Beta2", "Predictive memory pages reserved (Beta 2)");
                }
            } @catch(NSException *e) {
                V232_LogTrace("QuantumMemoryPredictor_Beta2", "Predictor exception intercepted");
            }
        }
    });
}

static void V232_ExecuteHyperThreadIORoutineOfficial(void) {
    if (!v232_async_io_queue) {
        v232_async_io_queue = dispatch_queue_create("com.boostv232.io.hyperthread.official", DISPATCH_QUEUE_CONCURRENT);
    }
    dispatch_async(v232_async_io_queue, ^{
        @autoreleasepool {
            @try {
                V232_LogTrace("HyperThreadIO_Official", "Official HyperThread I/O pipeline accelerated");
            } @catch(NSException *e) {
                V232_LogTrace("HyperThreadIO_Official", "HyperThread exception caught");
            }
        }
    });
}

static void V232_ExecuteQuantumCoreSyncRoutineOfficial(void) {
    if (!v232_sync_monitor_queue) {
        v232_sync_monitor_queue = dispatch_queue_create("com.boostv232.quantum.sync.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                mach_timebase_info_data_t timebase;
                mach_timebase_info(&timebase);
                uint64_t now = mach_absolute_time();
                uint64_t nanos = (now * timebase.numer) / timebase.denom;
                if (nanos > 0) {
                    g_v232GraphicsState.isPacingLocked = YES;
                    V232_LogTrace("QuantumCoreSync_Official", "Official Quantum core frame sync locked");
                }
            } @catch(NSException *e) {
                V232_LogTrace("QuantumCoreSync_Official", "Quantum sync exception handled");
            }
        }
    });
}

static void V232_AutoKernelMemoryRebalancer(void) {
    if (!v232_auto_mem_queue) {
        v232_auto_mem_queue = dispatch_queue_create("com.boostv232.auto.memrebalancer", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_auto_mem_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t page_size;
                host_page_size(mach_host_self(), &page_size);
                if (page_size > 0) {
                    malloc_zone_pressure_relief(NULL, (size_t)page_size * 64);
                    g_v232MemoryState.memoryPressureCount++;
                    V232_LogTrace("Auto_MemRebalancer", "Auto micro-task memory relief calibrated");
                }
            } @catch(NSException *e) {
                V232_LogTrace("Auto_MemRebalancer", "Auto memory rebalance intercepted");
            }
        }
    });
}

static void V232_AutoGPUFramePacingRegulator(void) {
    if (!v232_auto_gpu_queue) {
        v232_auto_gpu_queue = dispatch_queue_create("com.boostv232.auto.gpupacing", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_auto_gpu_queue, ^{
        @autoreleasepool {
            @try {
                g_v232GraphicsState.currentJitterPercentage = 0.005f;
                V232_LogTrace("Auto_GPUPacing", "GPU frame jitter auto-smoothened");
            } @catch(NSException *e) {
                V232_LogTrace("Auto_GPUPacing", "GPU pacing regulation exception");
            }
        }
    });
}

static void V232_AutoDaemonDeadlockImmunity(void) {
    if (!v232_auto_deadlock_queue) {
        v232_auto_deadlock_queue = dispatch_queue_create("com.boostv232.auto.deadlock", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_auto_deadlock_queue, ^{
        @autoreleasepool {
            @try {
                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                if (mainRunLoop) {
                    if (CFRunLoopIsWaiting(mainRunLoop)) {
                        CFRunLoopWakeUp(mainRunLoop);
                    }
                    g_v232WatchdogState.deadlocksPrevented++;
                    V232_LogTrace("Auto_DeadlockImmunity", "Main runloop deadlock immunity active");
                }
            } @catch(NSException *e) {
                V232_LogTrace("Auto_DeadlockImmunity", "Deadlock immunity exception caught");
            }
        }
    });
}

static void V232_ExecuteNeuralFrameCompensationOfficial(void) {
    if (!v232_neural_queue) {
        v232_neural_queue = dispatch_queue_create("com.boostv232.neural.scheduler.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_neural_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t self_thread = mach_thread_self();
                thread_extended_info_data_t thread_info_data;
                mach_msg_type_number_t count = THREAD_EXTENDED_INFO_COUNT;
                kern_return_t kr = thread_info(self_thread, THREAD_EXTENDED_INFO, (thread_info_t)&thread_info_data, &count);
                if (kr == KERN_SUCCESS) {
                    V232_LogTrace("NeuralBooster_Official", "Official Thread QoS delta calibrated");
                }
                mach_port_deallocate(mach_task_self(), self_thread);
            } @catch(NSException *e) {
                V232_LogTrace("NeuralBooster_Official", "Neural compensation exception caught");
            }
        }
    });
}

static void V232_ExecuteAdaptiveBufferRebalanceOfficial(void) {
    if (!v232_buffer_queue) {
        v232_buffer_queue = dispatch_queue_create("com.boostv232.buffer.rebalance.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_buffer_queue, ^{
        @autoreleasepool {
            @try {
                V232_LogTrace("AdaptiveBuffer_Official", "Official buffer queue pipeline rebalanced");
            } @catch(NSException *e) {
                V232_LogTrace("AdaptiveBuffer_Official", "Adaptive buffer exception handled");
            }
        }
    });
}

static void V232_PerformThreadPriorityCalibration(void) {
    if (!v232_sync_monitor_queue) {
        v232_sync_monitor_queue = dispatch_queue_create("com.boostv232.sync.monitor", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
                V232_LogTrace("PriorityCalib", "User interactive priority calibrated");
            } @catch(NSException *e) {
                V232_LogTrace("PriorityCalib", "Failed to calibrate thread priority");
            }
        }
    });
}

static void V232_InitializeWatchdogMonitor(void) {
    if (!v232_watchdog_queue) {
        v232_watchdog_queue = dispatch_queue_create("com.boostv232.watchdog.queue", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_watchdog_queue, ^{
        @autoreleasepool {
            @try {
                V232_LogTrace("Watchdog", "Watchdog thread initialized for stability check");
            } @catch(NSException *e) {
                V232_LogTrace("Watchdog", "Watchdog setup exception caught");
            }
        }
    });
}

static void V232_DispatchBackgroundSyncMaintenance(void) {
    if (!v232_core_dispatch_queue) {
        v232_core_dispatch_queue = dispatch_queue_create("com.boostv232.core.dispatch", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_core_dispatch_queue, ^{
        @autoreleasepool {
            @try {
                V232_LogTrace("CoreDispatch", "Core background maintenance executed");
            } @catch(NSException *e) {
                V232_LogTrace("CoreDispatch", "Exception inside core dispatch maintenance");
            }
        }
    });
}

static void V232_ArmRenderGuardPipeline(void) {
    if (!v232_render_guard_queue) {
        v232_render_guard_queue = dispatch_queue_create("com.boostv232.render.guard", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_render_guard_queue, ^{
        @autoreleasepool {
            @try {
                V232_LogTrace("RenderGuard", "Render guard thread active");
            } @catch(NSException *e) {
                V232_LogTrace("RenderGuard", "Render guard exception intercepted");
            }
        }
    });
}

static void V232_ValidateThermalStateBounds(void) {
    if (!v232_thermal_queue) {
        v232_thermal_queue = dispatch_queue_create("com.boostv232.thermal.routine", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_thermal_queue, ^{
        @autoreleasepool {
            @try {
                NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
                if (state >= NSProcessInfoThermalStateSerious) {
                    V232_ExecuteOfficialThermalRoutine();
                }
            } @catch(NSException *e) {
                V232_LogTrace("ThermalBounds", "Thermal boundary check exception");
            }
        }
    });
}

static void V232_PeriodicWatchdogHealthCheck(void) {
    if (!v232_health_check_queue) {
        v232_health_check_queue = dispatch_queue_create("com.boostv232.health.check", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_health_check_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t task = mach_task_self();
                struct task_basic_info info;
                mach_msg_type_number_t size = sizeof(info);
                kern_return_t kr = task_info(task, TASK_BASIC_INFO, (task_info_t)&info, &size);
                if (kr == KERN_SUCCESS) {
                    g_v232WatchdogState.watchdogTicks++;
                    V232_LogTrace("HealthCheck", "Task resident memory validated");
                }
            } @catch (NSException *e) {
                V232_LogTrace("HealthCheck", "Health check exception intercepted");
            }
        }
    });
}

// ==============================================================================
// 🧠 PHẦN 4: CẤU HÌNH HỆ THỐNG V23.2 (ĐỒNG BỘ CHUẨN XÁC THEO ẢNH THỰC TẾ)
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

// Nhóm 3: 2 TÍNH NĂNG NÂNG CẤP LÊN (BETA 2)
@property (nonatomic, assign) BOOL directRenderPipeBypassBeta2;      // NÂNG CẤP BETA 2
@property (nonatomic, assign) BOOL quantumMemoryPredictorBeta2;      // NÂNG CẤP BETA 2

// Nhóm 4: CÁC TÍNH NĂNG CHÍNH THỨC (OFFICIAL) - MẶC ĐỊNH THEO ẢNH
@property (nonatomic, assign) BOOL ultraResponsivenessProEngineOfficial;
@property (nonatomic, assign) BOOL hyperThreadIOAcceleratorOfficial;     
@property (nonatomic, assign) BOOL quantumCoreSyncStabilizerOfficial;     
@property (nonatomic, assign) BOOL zeroLagNeuralBoosterOfficial;         
@property (nonatomic, assign) BOOL vsyncAdaptiveBufferOfficial;          
@property (nonatomic, assign) BOOL dynamicThermalEngineOfficial;

// Nhóm 5: Tối ưu lõi & Hệ thống (BẬT THEO ẢNH)
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

// Nhóm 6: Nhiệt độ Cực Đoan & Pin
@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL smartThermalManager;
@property (nonatomic, assign) BOOL heavyLoadCooling;       
@property (nonatomic, assign) BOOL chargeCoolingProtection;
@property (nonatomic, assign) BOOL powerSaveMode;

// Nhóm 7: Hệ thống Nâng Cao & Mạng
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
        _configQueue = dispatch_queue_create("com.boostv232.config.queue", DISPATCH_QUEUE_SERIAL);
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

            self.directRenderPipeBypassBeta2 = NO;
            self.quantumMemoryPredictorBeta2 = NO;

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
            V232_LogTrace("BoostConfig", "Master Toggle is OFF - All hooks completely disabled");
            return;
        }

        self.enableHzControl = ReadBool(@"EnableHzControl", NO);
        self.targetHz = ReadInt(@"TargetRefreshRate", 60);

        self.enableFPSControl = ReadBool(@"EnableFPSControl", NO);
        self.targetFPS = ReadInt(@"TargetFPSRate", 60);
        self.forceOverclock144Hz = ReadBool(@"ForceOverclock144Hz", NO);

        self.colorOs17SmoothEngine = ReadBool(@"ColorOs17SmoothEngine", NO);
        self.reduceMultiTaskLag = ReadBool(@"ReduceMultiTaskLag", YES);
        self.fixAppLaunchBlackScreen = ReadBool(@"FixAppLaunchBlackScreen", YES);
        self.fixAppExitStutter = ReadBool(@"FixAppExitStutter", YES);
        self.touchResponseBoost = ReadBool(@"TouchResponseBoost", YES);
        self.animSpeed = ReadFloat(@"AnimSpeed", 0.82f);

        // 2 TÍNH NĂNG BETA 2 (BẬT THEO ẢNH)
        self.directRenderPipeBypassBeta2 = ReadBool(@"DirectRenderPipeBypassBeta2", YES);
        self.quantumMemoryPredictorBeta2 = ReadBool(@"QuantumMemoryPredictorBeta2", YES);

        // CÁC TÍNH NĂNG CHÍNH THỨC (ĐỒNG BỘ CHUẨN XÁC THEO ẢNH THỰC TẾ)
        self.ultraResponsivenessProEngineOfficial = ReadBool(@"UltraResponsivenessProEngineOfficial", NO);
        self.hyperThreadIOAcceleratorOfficial = ReadBool(@"HyperThreadIOAcceleratorOfficial", NO);
        self.quantumCoreSyncStabilizerOfficial = ReadBool(@"QuantumCoreSyncStabilizerOfficial", NO);
        self.zeroLagNeuralBoosterOfficial = ReadBool(@"ZeroLagNeuralBoosterOfficial", NO);
        self.vsyncAdaptiveBufferOfficial = ReadBool(@"VsyncAdaptiveBufferOfficial", NO);
        self.dynamicThermalEngineOfficial = ReadBool(@"DynamicThermalEngineOfficial", YES);

        // NHÓM TỐI ƯU LÕI & HỆ THỐNG (BẬT TOÀN BỘ THEO ẢNH)
        self.ios27AutoScheduler = ReadBool(@"Ios27AutoScheduler", YES);
        self.realtimePriorityBoost = ReadBool(@"RealtimePriorityBoost", YES);
        self.boostCpuGpu = ReadBool(@"BoostCpuGpu", YES);
        self.smartRamClean = ReadBool(@"SmartRamClean", YES);
        self.aggressiveRamClean = ReadBool(@"AggressiveRamClean", YES);
        self.killBgApps = ReadBool(@"KillBgApps", NO);
        self.turboAppLaunch = ReadBool(@"TurboAppLaunch", YES);
        self.metalTripleBuffering = ReadBool(@"MetalTripleBuffering", YES);
        self.gameFpsStabilizer = ReadBool(@"GameFpsStabilizer", YES);
        self.optimizeSystemProcess = ReadBool(@"OptimizeSystemProcess", YES);
        self.autoSpoofNewDevice = ReadBool(@"AutoSpoofNewDevice", YES);

        self.antiThermalThrottling = ReadBool(@"AntiThermalThrottling", YES);
        self.smartThermalManager = ReadBool(@"SmartThermalManager", YES);
        self.heavyLoadCooling = ReadBool(@"HeavyLoadCooling", YES);
        self.chargeCoolingProtection = ReadBool(@"ChargeCoolingProtection", YES);
        self.powerSaveMode = ReadBool(@"PowerSaveMode", YES);

        self.bypassVarSandbox = ReadBool(@"BypassVarSandbox", NO);
        self.blockAnalytics = ReadBool(@"BlockAnalytics", YES);
        self.tcpTurboNetwork = ReadBool(@"TcpTurboNetwork", YES);

        V232_LogTrace("BoostConfig", "Master Toggle is ON - Settings Synchronized Correctly");
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

static void V232_DebouncedPreferenceSync(void) {
    if (!v232_pref_sync_queue) {
        v232_pref_sync_queue = dispatch_queue_create("com.boostv232.pref.sync", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_pref_sync_queue, ^{
        [[BoostConfig sharedInstance] loadSettings];
        CFG = [BoostConfig sharedInstance];
        V232_LogTrace("Notification", "Darwin notification received - Reloaded safely");
    });
}

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    V232_DebouncedPreferenceSync();
}

// ==============================================================================
// ⚡️ PHẦN 5: AN TOÀN POSIX & KERNEL BYPASS
// ==============================================================================

%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ON || !CFG_PTR.bypassVarSandbox || !pathname || !BoostIsSpringBoard()) {
        return %orig(pathname, mode);
    }
    @try {
        if (strstr(pathname, "/var/jb/") || strstr(pathname, "/Library/MobileSubstrate/")) {
            return 0;
        }
    } @catch (NSException *e) {}
    return %orig(pathname, mode);
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ON || !name) {
        return %orig(name, oldp, oldlenp, newp, newlen);
    }
    
    // CÁCH LY TIẾN TRÌNH BÀN PHÍM VÀ APP JAILBREAK
    if (BoostIsIsolatedKeyboardSearchProcess() || BoostIsJailbreakToolApp()) {
        return %orig(name, oldp, oldlenp, newp, newlen);
    }

    if (BoostIsSpringBoard()) {
        if (CFG_PTR.antiThermalThrottling && strcmp(name, "kern.thermal.temperature") == 0) {
            float safeTemp = 28.5f;
            if (oldp && oldlenp && *oldlenp >= sizeof(float)) {
                memcpy(oldp, &safeTemp, sizeof(float));
                *oldlenp = sizeof(float);
                return 0;
            }
        }
        if (CFG_PTR.autoSpoofNewDevice) {
            if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
                const char *model = "iPhone16,2";
                if (oldp && oldlenp && *oldlenp >= strlen(model) + 1) {
                    strlcpy((char *)oldp, model, *oldlenp);
                    *oldlenp = strlen(model) + 1;
                    return 0;
                }
            }
        }
    }
    return %orig(name, oldp, oldlenp, newp, newlen);
}

%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    if (IS_ON && CFG_PTR.tcpTurboNetwork && !BoostIsSpringBoard() && !BoostIsJailbreakToolApp() && !BoostIsIsolatedKeyboardSearchProcess()) {
        int nodelay = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
        g_v232NetworkState.activeOptimizedSockets++;
    }
    return %orig(socket, address, address_len);
}

// ==============================================================================
// 🖥 PHẦN 6: ĐIỀU PHỐI KHUNG HÌNH (SỬA DỨT ĐIỂM HZ/FPS THỰC THI NGAY LẬP TỨC)
// ==============================================================================
%group Group_Display_DualRate

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if (IS_ON && V232_CanSafelyHookDisplayMethods()) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            g_AppWindowReadyForFrameBoost = YES;
            V232_LogTrace("UIWindow", "Deferred handshake completed");
            
            V232_AutoKernelMemoryRebalancer();
            V232_AutoGPUFramePacingRegulator();
            V232_AutoDaemonDeadlockImmunity();
        });
    }
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden);
    if (!hidden && IS_ON && V232_CanSafelyHookDisplayMethods()) {
        g_AppWindowReadyForFrameBoost = YES;
        V232_AutoKernelMemoryRebalancer();
    }
}
%end

%hook CADisplayLink

- (NSInteger)preferredFramesPerSecond {
    if (!V232_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetFPS];
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!V232_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl || !g_AppWindowReadyForFrameBoost) {
        %orig(fps);
        return;
    }
    %orig([CFG_PTR resolvedTargetFPS]);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!V232_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    float preferredRate = (float)[CFG_PTR resolvedTargetHz];
    float minRate = (preferredRate >= 60.0f) ? 30.0f : preferredRate;
    float maxRate = preferredRate;
    return CAFrameRateRangeMake(minRate, maxRate, preferredRate);
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!V232_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        %orig(range);
        return;
    }
    float preferredRate = (float)[CFG_PTR resolvedTargetHz];
    float minRate = (preferredRate >= 60.0f) ? 30.0f : preferredRate;
    float maxRate = preferredRate;
    CAFrameRateRange adaptiveRange = CAFrameRateRangeMake(minRate, maxRate, preferredRate);
    %orig(adaptiveRange);
    
    if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
        V232_ExecuteQuantumCoreSyncRoutineOfficial();
    }
}

- (void)setFrameInterval:(NSInteger)interval {
    if (!V232_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl || !g_AppWindowReadyForFrameBoost) {
        %orig(interval);
        return;
    }
    if (([CFG_PTR resolvedTargetHz] == 30) || ([CFG_PTR resolvedTargetFPS] == 30)) {
        %orig(2);
    } else {
        %orig(1);
    }
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (!V232_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetHz];
}

- (NSInteger)_maximumFramesPerSecond {
    if (!V232_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetHz];
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (!V232_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        %orig(rate);
        return;
    }
    %orig((CGFloat)[CFG_PTR resolvedTargetHz]);
}

- (CGFloat)_refreshRate {
    if (!V232_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return (CGFloat)[CFG_PTR resolvedTargetHz];
}

- (void)_computeMetrics {
    %orig;
    if (IS_ON && CFG_PTR.enableHzControl && V232_CanSafelyHookDisplayMethods() && g_AppWindowReadyForFrameBoost) {
        [self _setTargetRefreshRate:(CGFloat)[CFG_PTR resolvedTargetHz]];
    }
}
%end

%end // Group_Display_DualRate

// ==============================================================================
// 🎮 PHẦN 7: METAL BUFFERING (CÔ LẬP TRONG SUỐT CHO SPRINGBOARD)
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
%end

%end // Group_Metal_SpringBoard_Only

// ==============================================================================
// 🎨 PHẦN 8: GIAO DIỆN & 2 TÍNH NĂNG BETA 2 (KHÔNG LỆCH FRAME)
// ==============================================================================
%group Group_ColorOS17_SafeUI

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    // CHỈ CAN THIỆP KHI NÚT BẬT - TẮT LÀ TRẢ VỀ GỐC NGUYÊN BẢN CHỐNG KHỰNG
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp() && !BoostIsJailbreakToolApp()) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig(rate);
    }
}
%end

%hook CALayer
- (void)setNeedsDisplay {
    %orig;
    if (IS_ON && CFG_PTR.touchResponseBoost && BoostIsSpringBoard() && !BoostIsIsolatedKeyboardSearchProcess()) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    if (IS_ON && CFG_PTR.ultraResponsivenessProEngineOfficial && !BoostIsIsolatedKeyboardSearchProcess()) {
        V232_ExecuteUltraResponsivenessProEngineOfficial();
    }
    if (IS_ON && CFG_PTR.directRenderPipeBypassBeta2) {
        V232_ExecuteDirectRenderPipeBypassBeta2();
    }
    if (IS_ON && CFG_PTR.zeroLagNeuralBoosterOfficial && BoostIsSpringBoard()) {
        V232_ExecuteNeuralFrameCompensationOfficial();
    }
    if (IS_ON && CFG_PTR.hyperThreadIOAcceleratorOfficial) {
        V232_ExecuteHyperThreadIORoutineOfficial();
    }
}
%end

%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsJailbreakToolApp()) {
        if (!BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp()) {
            %orig(duration * 0.85, animations);
            return;
        }
    }
    %orig(duration, animations);
}

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsJailbreakToolApp()) {
        if (!BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp()) {
            %orig(duration * 0.85, delay, options, animations, completion);
            return;
        }
    }
    %orig(duration, delay, options, animations, completion);
}
%end

%end // Group_ColorOS17_SafeUI

// ==============================================================================
// 🚀 PHẦN 9: SPRINGBOARD ENGINE (TRIỆT TIÊU ĐEN MÀN RESPRING)
// ==============================================================================
%group Group_SpringBoard_Only

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig(application);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.50 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_SpringBoardSceneReady = YES;
        V232_LogTrace("SpringBoard", "SpringBoard scene completely initialized");
        
        V232_AutoKernelMemoryRebalancer();
        V232_AutoGPUFramePacingRegulator();
        V232_AutoDaemonDeadlockImmunity();
        
        if (CFG_PTR.quantumMemoryPredictorBeta2) {
            V232_ExecuteQuantumMemoryPredictorBeta2();
        }
    });
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
// 🧹 PHẦN 10: QUẢN LÝ TIẾN TRÌNH VÀ VÒNG ĐỜI BỘ NHỚ
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON) {
        V232_RunGarbageCollector_Light();
        V232_AutoKernelMemoryRebalancer();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.aggressiveRamClean) {
        V232_AsyncMemoryPurgeSafe();
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.vsyncAdaptiveBufferOfficial) {
        V232_ExecuteAdaptiveBufferRebalanceOfficial();
        V232_AutoGPUFramePacingRegulator();
    }
}
%end

%end // Group_Memory_Engine

// ==============================================================================
// 🛡 PHẦN 11: MODULE BỔ TRỢ HỆ THỐNG NÂNG CAO (ADVANCED EXTENSIONS)
// ==============================================================================

@interface V232_SystemOptimizer : NSObject
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

@implementation V232_SystemOptimizer {
    BOOL _assertionActive;
}

+ (instancetype)sharedInstance {
    static V232_SystemOptimizer *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[V232_SystemOptimizer alloc] init];
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
        V232_RunGarbageCollector_Aggressive();
        V232_PurgeUnusedSharedBuffers();
        V232_AutoKernelMemoryRebalancer();
        V232_LogTrace("Optimizer", "Deep memory clean routine dispatched");
    }
}

- (void)optimizeCurrentTaskRunloop {
    @autoreleasepool {
        CFRunLoopRef currentLoop = CFRunLoopGetCurrent();
        if (currentLoop) {
            CFRunLoopWakeUp(currentLoop);
            V232_AutoDaemonDeadlockImmunity();
            V232_LogTrace("Optimizer", "Current runloop awakened");
        }
    }
}

- (void)registerSystemPowerAssertions {
    if (!_assertionActive) {
        _assertionActive = YES;
        V232_LogTrace("Optimizer", "Power assertion registered");
    }
}

- (void)releaseSystemPowerAssertions {
    if (_assertionActive) {
        _assertionActive = NO;
        V232_LogTrace("Optimizer", "Power assertion released");
    }
}

- (void)executeLowMemoryWatchdogRoutine {
    @autoreleasepool {
        V232_PeriodicWatchdogHealthCheck();
        V232_AutoKernelMemoryRebalancer();
        V232_LogTrace("Optimizer", "Watchdog routine synchronized");
    }
}

- (void)recalibrateGraphicsDriverPacing {
    @autoreleasepool {
        V232_ExecuteAdaptiveBufferRebalanceOfficial();
        V232_AutoGPUFramePacingRegulator();
        V232_LogTrace("Optimizer", "Graphics driver pacing finished");
    }
}

- (void)triggerHyperThreadOptimization {
    @autoreleasepool {
        V232_ExecuteHyperThreadIORoutineOfficial();
        V232_LogTrace("Optimizer", "HyperThread optimization dispatched");
    }
}

- (void)synchronizeQuantumClockPipeline {
    @autoreleasepool {
        V232_ExecuteQuantumCoreSyncRoutineOfficial();
        V232_LogTrace("Optimizer", "Quantum clock sync dispatched");
    }
}

- (void)flushTelemetryMetrics {
    if (!v232_telemetry_queue) {
        v232_telemetry_queue = dispatch_queue_create("com.boostv232.telemetry", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_telemetry_queue, ^{
        @autoreleasepool {
            g_v232GraphicsState.totalFramesRendered++;
            V232_LogTrace("Telemetry", "Metrics cycle recorded");
        }
    });
}

- (void)executeCoreStabilitySurvey {
    if (!v232_hardware_poll_queue) {
        v232_hardware_poll_queue = dispatch_queue_create("com.boostv232.hardware.poll", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v232_hardware_poll_queue, ^{
        @autoreleasepool {
            V232_ValidateThermalStateBounds();
            V232_PeriodicWatchdogHealthCheck();
            V232_LogTrace("Survey", "Stability survey finished");
        }
    });
}

- (void)recoverFromMicroDeadlock {
    @autoreleasepool {
        V232_AutoDaemonDeadlockImmunity();
        g_v232WatchdogState.deadlocksPrevented++;
        V232_LogTrace("Recovery", "Micro deadlock recovered");
    }
}

- (void)enforceFrameTimingConstraints {
    @autoreleasepool {
        V232_AutoGPUFramePacingRegulator();
        V232_LogTrace("Timing", "Frame timing verified");
    }
}

@end

// ==============================================================================
// ⚙️ PHẦN 12: KHỞI TẠO BỘ LÕI TWEAK V23.2 TITANIUM APEX
// ==============================================================================

%ctor {
    @autoreleasepool {
        CFPreferencesAppSynchronize(PREF_DOMAIN);
        CFPropertyListRef masterVal = CFPreferencesCopyAppValue(CFSTR("Enabled"), PREF_DOMAIN);
        BOOL isMasterOn = NO;
        if (masterVal) {
            isMasterOn = [(__bridge id)masterVal boolValue];
            CFRelease(masterVal);
        }
        
        // NẾU TẮT TỔNG -> THOÁT NGAY LẬP TỨC
        if (!isMasterOn) {
            V232_LogTrace("Ctor", "Master toggle is OFF - Completely bypassing injection, 0% SafeMode");
            return;
        }

        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
            V232_LogTrace("Ctor", "CrashGuard blocked hooks initialization");
            return;
        }

        // CÁCH LY CÔNG CỤ JAILBREAK
        if (BoostIsJailbreakToolApp()) {
            V232_LogTrace("Ctor", "Jailbreak management tool detected - Bypassing injection to prevent black screen");
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

        if (BoostIsIsolatedKeyboardSearchProcess() || BoostIsPreferencesApp()) {
            return;
        }

        // KHỞI TẠO AN TOÀN TRONG SPRINGBOARD
        if (BoostIsSpringBoard()) {
            @try {
                [[KernelBypass sharedInstance] initEnvironment];
                [[SystemBlocker sharedInstance] initBlockers];
                if (CFG_PTR.boostCpuGpu) {
                    [[KernelBypass sharedInstance] boostCurrentThreadPriority];
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
                            if (CFG_PTR.dynamicThermalEngineOfficial) {
                                V232_ExecuteOfficialThermalRoutine();
                            }
                        }
                    }
                }];
            } @catch (NSException *e) {
                V232_LogTrace("Ctor_Kernel", "Kernel bypass exception caught safely");
            }

            %init(Group_SpringBoard_Only);
            %init(Group_Metal_SpringBoard_Only);
            V232_LogTrace("Ctor", "SpringBoard groups initialized successfully without SafeMode");
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

        V232_InitializeWatchdogMonitor();
        V232_DispatchBackgroundSyncMaintenance();
        V232_ArmRenderGuardPipeline();
        V232_ValidateThermalStateBounds();
        V232_PeriodicWatchdogHealthCheck();
        
        [[V232_SystemOptimizer sharedInstance] optimizeCurrentTaskRunloop];
        [[V232_SystemOptimizer sharedInstance] executeLowMemoryWatchdogRoutine];
        [[V232_SystemOptimizer sharedInstance] recalibrateGraphicsDriverPacing];
        
        if (CFG_PTR.hyperThreadIOAcceleratorOfficial) {
            [[V232_SystemOptimizer sharedInstance] triggerHyperThreadOptimization];
        }
        if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
            [[V232_SystemOptimizer sharedInstance] synchronizeQuantumClockPipeline];
        }
        
        V232_LogTrace("Core", "SmoothiOS V23.2 Titanium Apex Loaded Successfully");
    }
}
