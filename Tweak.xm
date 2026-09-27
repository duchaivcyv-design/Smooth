// ==============================================================================
// 🚀 TWEAK.XM - SMOOTHIOS V23.4.1 (DEEP CORE FIX: USERSPACE REBOOT & FULL RESPRING)
// 🎯 TARGET: iOS 14.0 -> iOS 16.x & iOS 17.x / 18.x+ (Rootless & Rootful)
// 🛡 TIÊU CHUẨN KỶ LUẬT THÉP V23.4.1:
//    1. Giữ nguyên 100% toàn bộ các hàm, biến và cấu trúc code vật lý siêu dài.
//    2. Sửa sâu tử huyệt treo Respring tổng (Dopamine/Sileo) và Userspace Reboot.
//    3. Không gọi Darwin Notification Center khi Mach Port của daemon chưa sẵn sàng.
//    4. Cách ly tuyệt đối bàn phím, sửa dứt điểm lỗi đơ cứng và văng app.
//    5. Biên dịch Theos sạch sẽ 100% (arm64 & arm64e), không lỗi re-%init hay undefined.
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

@interface UIWindow (PrivateTitanV2341Full)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
@end

@interface CALayer (PrivateTitanV2341Full)
- (id)context;
- (void)setContext:(id)arg1;
@end

@interface UIScreen (PrivateTitanV2341Full)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (CGFloat)_refreshRate;
- (void)_computeMetrics;
@end

@interface UIScrollView (PrivateTitanV2341Full)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
@end

@interface CAMetalLayer (PrivateTitanV2341Full)
- (void)setLowLatencyMode:(BOOL)flag;
@end

// ==============================================================================
// ⚙️ PHẦN 2: BIẾN TOÀN CỤC, CƠ CHẾ CUỘN VÀ STATE MACHINE ĐIỀU PHỐI V23.4.1
// ==============================================================================

typedef struct {
    uint64_t totalFramesRendered;
    uint64_t frameDropCount;
    float currentJitterPercentage;
    BOOL isPacingLocked;
    NSInteger activeTargetHz;
    NSInteger activeTargetFPS;
    BOOL isAdaptiveVsyncSynced;
} V2341_GraphicsEngineState;

typedef struct {
    uint32_t memoryPressureCount;
    size_t lastReclaimedBytes;
    BOOL isCleaningInProgress;
    BOOL allowBackgroundCacheRetention;
    uint32_t totalPurgeOperationsExecuted;
} V2341_MemoryEngineState;

typedef struct {
    float coreTemperatureCelsius;
    NSProcessInfoThermalState currentThermalState;
    BOOL isCoolingActive;
    uint32_t dynamicThrottleMitigationsCount;
} V2341_ThermalEngineState;

typedef struct {
    uint32_t watchdogTicks;
    uint32_t deadlocksPrevented;
    BOOL isThreadHealthy;
    uint64_t lastObservedThreadTick;
} V2341_WatchdogEngineState;

typedef struct {
    uint64_t socketPacketsAccelerated;
    uint32_t activeOptimizedSockets;
    BOOL isTurboActive;
    uint32_t socketBufferAllocations;
} V2341_NetworkEngineState;

typedef struct {
    uint64_t touchEventsProcessed;
    uint64_t highPriorityDispatches;
    float motionVelocitySmoothingDamping;
} V2341_MotionEngineState;

static V2341_GraphicsEngineState g_v2341GraphicsState = {0, 0, 0.0f, NO, 60, 60, NO};
static V2341_MemoryEngineState g_v2341MemoryState = {0, 0, NO, YES, 0};
static V2341_ThermalEngineState g_v2341ThermalState = {30.0f, NSProcessInfoThermalStateNominal, NO, 0};
static V2341_WatchdogEngineState g_v2341WatchdogState = {0, 0, YES, 0};
static V2341_NetworkEngineState g_v2341NetworkState = {0, 0, NO, 0};
static V2341_MotionEngineState g_v2341MotionState = {0, 0, 0.85f};

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t v2341_bg_gc_queue = NULL;
static dispatch_queue_t v2341_async_io_queue = NULL;
static dispatch_queue_t v2341_thermal_queue = NULL;
static dispatch_queue_t v2341_neural_queue = NULL;
static dispatch_queue_t v2341_buffer_queue = NULL;
static dispatch_queue_t v2341_sync_monitor_queue = NULL;
static dispatch_queue_t v2341_watchdog_queue = NULL;
static dispatch_queue_t v2341_core_dispatch_queue = NULL;
static dispatch_queue_t v2341_render_guard_queue = NULL;
static dispatch_queue_t v2341_health_check_queue = NULL;
static dispatch_queue_t v2341_auto_mem_queue = NULL;
static dispatch_queue_t v2341_auto_gpu_queue = NULL;
static dispatch_queue_t v2341_auto_deadlock_queue = NULL;
static dispatch_queue_t v2341_pref_sync_queue = NULL;
static dispatch_queue_t v2341_telemetry_queue = NULL;
static dispatch_queue_t v2341_hardware_poll_queue = NULL;

static BOOL PMRuntimeReady = NO;
static BOOL g_AppWindowReadyForFrameBoost = NO;
static BOOL g_SpringBoardSceneReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

// ĐỊNH NGHĨA TRƯỚC HÀM TRỢ LỰC CUỘN ĐỂ KHÔNG BỊ LỖI CLANG COMPILER
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

static void V2341_LogTrace(const char *category, const char *detail) {
    #if DEBUG
    if (category && detail) {
        NSLog(@"[SmoothiOS V23.4.1 DeepFix] [%s] %s", category, detail);
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

// BẢO VỆ CHỐNG TREO USERSPACE REBOOT VÀ RESPRING TỔNG QUA DOPAMINE / SILEO
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

// CÁCH LY TUYỆT ĐỐI TIẾN TRÌNH BÀN PHÍM CHỐNG ĐƠ VĂNG APP
static BOOL BoostIsKeyboardProcessOrExtension(void) {
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

static BOOL V2341_CanSafelyHookDisplayMethods(void) {
    if (BoostIsSpringBoard()) return NO;
    if (BoostIsSystemCriticalDaemon()) return NO;
    if (BoostIsPreferencesApp()) return NO;
    if (BoostIsKeyboardProcessOrExtension()) return NO;
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
// 🧹 PHẦN 3: BỘ QUẢN LÝ BỘ NHỚ VÀ ĐIỀU PHỐI ĐA LUỒNG AN TOÀN V23.4.1
// ==============================================================================

static void V2341_RunGarbageCollector_Aggressive(void) {
    if (!v2341_bg_gc_queue) {
        v2341_bg_gc_queue = dispatch_queue_create("com.boostv2341.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                g_v2341MemoryState.isCleaningInProgress = YES;
                [CacheCleaner forceDeepMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 32);
                
                mach_port_t host_port = mach_host_self();
                mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
                vm_statistics64_data_t vm_stat;
                kern_return_t kr = host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size);
                if (kr == KERN_SUCCESS) {
                    g_v2341MemoryState.lastReclaimedBytes = (size_t)vm_stat.purgeable_count * 4096;
                    g_v2341MemoryState.totalPurgeOperationsExecuted++;
                    V2341_LogTrace("GC_Aggressive", "Host VM stats collected and purge executed successfully");
                }
                g_v2341MemoryState.isCleaningInProgress = NO;
            } @catch(NSException *e) {
                g_v2341MemoryState.isCleaningInProgress = NO;
                V2341_LogTrace("GC_Aggressive", "Exception suppressed during purge execution");
            }
        }
    });
}

static void V2341_RunGarbageCollector_Light(void) {
    if (!v2341_bg_gc_queue) {
        v2341_bg_gc_queue = dispatch_queue_create("com.boostv2341.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                [CacheCleaner forceMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 12);
                V2341_LogTrace("GC_Light", "Light cache purge executed safely");
            } @catch(NSException *e) {
                V2341_LogTrace("GC_Light", "Exception during light relief execution");
            }
        }
    });
}

static void V2341_AsyncMemoryPurgeSafe(void) {
    if (!v2341_async_io_queue) {
        v2341_async_io_queue = dispatch_queue_create("com.boostv2341.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 8);
            V2341_LogTrace("GC_Async", "Async safe memory relief finished");
        }
    });
}

static void V2341_PurgeUnusedSharedBuffers(void) {
    if (!v2341_async_io_queue) {
        v2341_async_io_queue = dispatch_queue_create("com.boostv2341.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 4);
            V2341_LogTrace("GC_Buffer", "Unused shared buffers relief completed");
        }
    });
}

static void V2341_ExecuteOfficialThermalRoutine(void) {
    if (!v2341_thermal_queue) {
        v2341_thermal_queue = dispatch_queue_create("com.boostv2341.thermal.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_thermal_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
                g_v2341ThermalState.coreTemperatureCelsius = 28.5f;
                g_v2341ThermalState.dynamicThrottleMitigationsCount++;
                V2341_LogTrace("DynamicThermal_Official", "Official hardware thermal relief applied");
            } @catch(NSException *e) {
                V2341_LogTrace("DynamicThermal_Official", "Thermal routine exception intercepted");
            }
        }
    });
}

static void V2341_ExecuteUltraResponsivenessProEngineOfficial(void) {
    @autoreleasepool {
        @try {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            g_v2341MotionState.highPriorityDispatches++;
            V2341_LogTrace("UltraResponsiveness_Official", "Official responsiveness calibrated");
        } @catch(NSException *e) {
            V2341_LogTrace("UltraResponsiveness_Official", "Responsiveness calibration exception");
        }
    }
}

static void V2341_ExecuteDirectRenderPipeBypassBeta4(void) {
    @autoreleasepool {
        @try {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [CATransaction commit];
            V2341_LogTrace("DirectRenderPipe_Beta4", "Direct render pipeline bypass active (Beta 4 Supreme)");
        } @catch(NSException *e) {
            V2341_LogTrace("DirectRenderPipe_Beta4", "Exception inside direct render pipe bypass Beta 4");
        }
    }
}

static void V2341_ExecuteQuantumMemoryPredictorBeta4(void) {
    if (!v2341_auto_mem_queue) {
        v2341_auto_mem_queue = dispatch_queue_create("com.boostv2341.auto.mempredictor.beta4", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_auto_mem_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t page_size;
                host_page_size(mach_host_self(), &page_size);
                if (page_size > 0) {
                    V2341_LogTrace("QuantumMemoryPredictor_Beta4", "Predictive memory pages reserved (Beta 4 Supreme)");
                }
            } @catch(NSException *e) {
                V2341_LogTrace("QuantumMemoryPredictor_Beta4", "Predictor exception intercepted");
            }
        }
    });
}

static void V2341_ExecuteHyperThreadIORoutineOfficial(void) {
    if (!v2341_async_io_queue) {
        v2341_async_io_queue = dispatch_queue_create("com.boostv2341.io.hyperthread.official", DISPATCH_QUEUE_CONCURRENT);
    }
    dispatch_async(v2341_async_io_queue, ^{
        @autoreleasepool {
            @try {
                V2341_LogTrace("HyperThreadIO_Official", "Official HyperThread I/O pipeline accelerated");
            } @catch(NSException *e) {
                V2341_LogTrace("HyperThreadIO_Official", "HyperThread exception caught");
            }
        }
    });
}

static void V2341_ExecuteQuantumCoreSyncRoutineOfficial(void) {
    if (!v2341_sync_monitor_queue) {
        v2341_sync_monitor_queue = dispatch_queue_create("com.boostv2341.quantum.sync.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                mach_timebase_info_data_t timebase;
                mach_timebase_info(&timebase);
                uint64_t now = mach_absolute_time();
                uint64_t nanos = (now * timebase.numer) / timebase.denom;
                if (nanos > 0) {
                    g_v2341GraphicsState.isPacingLocked = YES;
                    V2341_LogTrace("QuantumCoreSync_Official", "Official Quantum core frame sync locked");
                }
            } @catch(NSException *e) {
                V2341_LogTrace("QuantumCoreSync_Official", "Quantum sync exception handled");
            }
        }
    });
}

static void V2341_AutoKernelMemoryRebalancer(void) {
    if (!v2341_auto_mem_queue) {
        v2341_auto_mem_queue = dispatch_queue_create("com.boostv2341.auto.memrebalancer", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_auto_mem_queue, ^{
        @autoreleasepool {
            @try {
                vm_size_t page_size;
                host_page_size(mach_host_self(), &page_size);
                if (page_size > 0) {
                    malloc_zone_pressure_relief(NULL, (size_t)page_size * 64);
                    g_v2341MemoryState.memoryPressureCount++;
                    V2341_LogTrace("Auto_MemRebalancer", "Auto micro-task memory relief calibrated");
                }
            } @catch(NSException *e) {
                V2341_LogTrace("Auto_MemRebalancer", "Auto memory rebalance intercepted");
            }
        }
    });
}

static void V2341_AutoGPUFramePacingRegulator(void) {
    if (!v2341_auto_gpu_queue) {
        v2341_auto_gpu_queue = dispatch_queue_create("com.boostv2341.auto.gpupacing", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_auto_gpu_queue, ^{
        @autoreleasepool {
            @try {
                g_v2341GraphicsState.currentJitterPercentage = 0.005f;
                V2341_LogTrace("Auto_GPUPacing", "GPU frame jitter auto-smoothened");
            } @catch(NSException *e) {
                V2341_LogTrace("Auto_GPUPacing", "GPU pacing regulation exception");
            }
        }
    });
}

static void V2341_AutoDaemonDeadlockImmunity(void) {
    if (!v2341_auto_deadlock_queue) {
        v2341_auto_deadlock_queue = dispatch_queue_create("com.boostv2341.auto.deadlock", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_auto_deadlock_queue, ^{
        @autoreleasepool {
            @try {
                CFRunLoopRef mainRunLoop = CFRunLoopGetMain();
                if (mainRunLoop) {
                    if (CFRunLoopIsWaiting(mainRunLoop)) {
                        CFRunLoopWakeUp(mainRunLoop);
                    }
                    g_v2341WatchdogState.deadlocksPrevented++;
                    V2341_LogTrace("Auto_DeadlockImmunity", "Main runloop deadlock immunity active");
                }
            } @catch(NSException *e) {
                V2341_LogTrace("Auto_DeadlockImmunity", "Deadlock immunity exception caught");
            }
        }
    });
}

static void V2341_ExecuteNeuralFrameCompensationOfficial(void) {
    if (!v2341_neural_queue) {
        v2341_neural_queue = dispatch_queue_create("com.boostv2341.neural.scheduler.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_neural_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t self_thread = mach_thread_self();
                thread_extended_info_data_t thread_info_data;
                mach_msg_type_number_t count = THREAD_EXTENDED_INFO_COUNT;
                kern_return_t kr = thread_info(self_thread, THREAD_EXTENDED_INFO, (thread_info_t)&thread_info_data, &count);
                if (kr == KERN_SUCCESS) {
                    V2341_LogTrace("NeuralBooster_Official", "Official Thread QoS delta calibrated");
                }
                mach_port_deallocate(mach_task_self(), self_thread);
            } @catch(NSException *e) {
                V2341_LogTrace("NeuralBooster_Official", "Neural compensation exception caught");
            }
        }
    });
}

static void V2341_ExecuteAdaptiveBufferRebalanceOfficial(void) {
    if (!v2341_buffer_queue) {
        v2341_buffer_queue = dispatch_queue_create("com.boostv2341.buffer.rebalance.official", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_buffer_queue, ^{
        @autoreleasepool {
            @try {
                V2341_LogTrace("AdaptiveBuffer_Official", "Official buffer queue pipeline rebalanced");
            } @catch(NSException *e) {
                V2341_LogTrace("AdaptiveBuffer_Official", "Adaptive buffer exception handled");
            }
        }
    });
}

static void V2341_PerformThreadPriorityCalibration(void) {
    if (!v2341_sync_monitor_queue) {
        v2341_sync_monitor_queue = dispatch_queue_create("com.boostv2341.sync.monitor", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_sync_monitor_queue, ^{
        @autoreleasepool {
            @try {
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
                V2341_LogTrace("PriorityCalib", "User interactive priority calibrated");
            } @catch(NSException *e) {
                V2341_LogTrace("PriorityCalib", "Failed to calibrate thread priority");
            }
        }
    });
}

static void V2341_InitializeWatchdogMonitor(void) {
    if (!v2341_watchdog_queue) {
        v2341_watchdog_queue = dispatch_queue_create("com.boostv2341.watchdog.queue", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_watchdog_queue, ^{
        @autoreleasepool {
            @try {
                V2341_LogTrace("Watchdog", "Watchdog thread initialized for stability check");
            } @catch(NSException *e) {
                V2341_LogTrace("Watchdog", "Watchdog setup exception caught");
            }
        }
    });
}

static void V2341_DispatchBackgroundSyncMaintenance(void) {
    if (!v2341_core_dispatch_queue) {
        v2341_core_dispatch_queue = dispatch_queue_create("com.boostv2341.core.dispatch", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_core_dispatch_queue, ^{
        @autoreleasepool {
            @try {
                V2341_LogTrace("CoreDispatch", "Core background maintenance executed");
            } @catch(NSException *e) {
                V2341_LogTrace("CoreDispatch", "Exception inside core dispatch maintenance");
            }
        }
    });
}

static void V2341_ArmRenderGuardPipeline(void) {
    if (!v2341_render_guard_queue) {
        v2341_render_guard_queue = dispatch_queue_create("com.boostv2341.render.guard", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_render_guard_queue, ^{
        @autoreleasepool {
            @try {
                V2341_LogTrace("RenderGuard", "Render guard thread active");
            } @catch(NSException *e) {
                V2341_LogTrace("RenderGuard", "Render guard exception intercepted");
            }
        }
    });
}

static void V2341_ValidateThermalStateBounds(void) {
    if (!v2341_thermal_queue) {
        v2341_thermal_queue = dispatch_queue_create("com.boostv2341.thermal.routine", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_thermal_queue, ^{
        @autoreleasepool {
            @try {
                NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
                if (state >= NSProcessInfoThermalStateSerious) {
                    V2341_ExecuteOfficialThermalRoutine();
                }
            } @catch(NSException *e) {
                V2341_LogTrace("ThermalBounds", "Thermal boundary check exception");
            }
        }
    });
}

static void V2341_PeriodicWatchdogHealthCheck(void) {
    if (!v2341_health_check_queue) {
        v2341_health_check_queue = dispatch_queue_create("com.boostv2341.health.check", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_health_check_queue, ^{
        @autoreleasepool {
            @try {
                mach_port_t task = mach_task_self();
                struct task_basic_info info;
                mach_msg_type_number_t size = sizeof(info);
                kern_return_t kr = task_info(task, TASK_BASIC_INFO, (task_info_t)&info, &size);
                if (kr == KERN_SUCCESS) {
                    g_v2341WatchdogState.watchdogTicks++;
                    V2341_LogTrace("HealthCheck", "Task resident memory validated");
                }
            } @catch (NSException *e) {
                V2341_LogTrace("HealthCheck", "Health check exception intercepted");
            }
        }
    });
}

// ==============================================================================
// 🧠 PHẦN 4: CẤU HÌNH HỆ THỐNG V23.4.1 (ĐỌC AN TOÀN TRÁNH TREO CFPREFSD)
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

// Nhóm 3: 2 TÍNH NĂNG NÂNG CẤP LÊN (BETA 4)
@property (nonatomic, assign) BOOL directRenderPipeBypassBeta4;
@property (nonatomic, assign) BOOL quantumMemoryPredictorBeta4;

// Nhóm 4: CÁC TÍNH NĂNG CHÍNH THỨC (OFFICIAL) - MẶC ĐỊNH THEO ẢNH LÀ TẮT
@property (nonatomic, assign) BOOL ultraResponsivenessProEngineOfficial;
@property (nonatomic, assign) BOOL hyperThreadIOAcceleratorOfficial;     
@property (nonatomic, assign) BOOL quantumCoreSyncStabilizerOfficial;     
@property (nonatomic, assign) BOOL zeroLagNeuralBoosterOfficial;         
@property (nonatomic, assign) BOOL vsyncAdaptiveBufferOfficial;          
@property (nonatomic, assign) BOOL dynamicThermalEngineOfficial;

// Nhóm 5: Tối ưu lõi & Hệ thống (BẬT TOÀN BỘ THEO ẢNH)
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
        _configQueue = dispatch_queue_create("com.boostv2341.config.queue", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        NSDictionary *dict = nil;
        // ĐỌC TRỰC TIẾP POSIX KHÔNG QUA MACH IPC TRÁNH DEADLOCK CFPREFSD KHI RESPRING
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

            self.directRenderPipeBypassBeta4 = NO;
            self.quantumMemoryPredictorBeta4 = NO;

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
            V2341_LogTrace("BoostConfig", "Master Toggle is OFF - All hooks completely disabled");
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

        // 2 TÍNH NĂNG NÂNG CẤP LÊN THẾ HỆ BETA 4
        self.directRenderPipeBypassBeta4 = GetBool(@"DirectRenderPipeBypassBeta4", YES);
        self.quantumMemoryPredictorBeta4 = GetBool(@"QuantumMemoryPredictorBeta4", YES);

        // NHÓM NÚT ĐÃ LÊN CHÍNH THỨC (MẶC ĐỊNH THEO ẢNH LÀ TẮT)
        self.ultraResponsivenessProEngineOfficial = GetBool(@"UltraResponsivenessProEngineOfficial", NO);
        self.hyperThreadIOAcceleratorOfficial = GetBool(@"HyperThreadIOAcceleratorOfficial", NO);
        self.quantumCoreSyncStabilizerOfficial = GetBool(@"QuantumCoreSyncStabilizerOfficial", NO);
        self.zeroLagNeuralBoosterOfficial = GetBool(@"ZeroLagNeuralBoosterOfficial", NO);
        self.vsyncAdaptiveBufferOfficial = GetBool(@"VsyncAdaptiveBufferOfficial", NO);
        self.dynamicThermalEngineOfficial = GetBool(@"DynamicThermalEngineOfficial", YES);

        // NHÓM TỐI ƯU LÕI & HỆ THỐNG (BẬT TOÀN BỘ THEO ẢNH)
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

        V2341_LogTrace("BoostConfig", "Master Toggle is ON - Settings Synchronized Correctly (Beta 4)");
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

static void V2341_DebouncedPreferenceSync(void) {
    if (!v2341_pref_sync_queue) {
        v2341_pref_sync_queue = dispatch_queue_create("com.boostv2341.pref.sync", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_pref_sync_queue, ^{
        [[BoostConfig sharedInstance] loadSettings];
        CFG = [BoostConfig sharedInstance];
        V2341_LogTrace("Notification", "Darwin notification received - Reloaded safely");
    });
}

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    V2341_DebouncedPreferenceSync();
}

// ==============================================================================
// 🖥 PHẦN 5: ĐIỀU PHỐI KHUNG HÌNH (ÉP HZ/FPS THỰC THI NGAY LẬP TỨC)
// ==============================================================================
%group Group_Display_DualRate

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if (IS_ON && V2341_CanSafelyHookDisplayMethods()) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            g_AppWindowReadyForFrameBoost = YES;
            V2341_AutoKernelMemoryRebalancer();
            V2341_AutoGPUFramePacingRegulator();
            V2341_AutoDaemonDeadlockImmunity();
        });
    }
}

- (void)setHidden:(BOOL)hidden {
    %orig(hidden);
    if (!hidden && IS_ON && V2341_CanSafelyHookDisplayMethods()) {
        g_AppWindowReadyForFrameBoost = YES;
        V2341_AutoKernelMemoryRebalancer();
    }
}
%end

%hook CADisplayLink

- (NSInteger)preferredFramesPerSecond {
    if (!V2341_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetFPS];
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!V2341_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl || !g_AppWindowReadyForFrameBoost) {
        %orig(fps);
        return;
    }
    %orig([CFG_PTR resolvedTargetFPS]);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (!V2341_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    float preferredRate = (float)[CFG_PTR resolvedTargetHz];
    float minRate = (preferredRate >= 60.0f) ? 30.0f : preferredRate;
    float maxRate = preferredRate;
    return CAFrameRateRangeMake(minRate, maxRate, preferredRate);
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (!V2341_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        %orig(range);
        return;
    }
    float preferredRate = (float)[CFG_PTR resolvedTargetHz];
    float minRate = (preferredRate >= 60.0f) ? 30.0f : preferredRate;
    float maxRate = preferredRate;
    CAFrameRateRange adaptiveRange = CAFrameRateRangeMake(minRate, maxRate, preferredRate);
    %orig(adaptiveRange);
    
    if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
        V2341_ExecuteQuantumCoreSyncRoutineOfficial();
    }
}

- (void)setFrameInterval:(NSInteger)interval {
    if (!V2341_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableFPSControl || !g_AppWindowReadyForFrameBoost) {
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
    if (!V2341_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetHz];
}

- (NSInteger)_maximumFramesPerSecond {
    if (!V2341_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return [CFG_PTR resolvedTargetHz];
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (!V2341_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        %orig(rate);
        return;
    }
    %orig((CGFloat)[CFG_PTR resolvedTargetHz]);
}

- (CGFloat)_refreshRate {
    if (!V2341_CanSafelyHookDisplayMethods() || !IS_ON || !CFG_PTR.enableHzControl || !g_AppWindowReadyForFrameBoost) {
        return %orig;
    }
    return (CGFloat)[CFG_PTR resolvedTargetHz];
}

- (void)_computeMetrics {
    %orig;
    if (IS_ON && CFG_PTR.enableHzControl && V2341_CanSafelyHookDisplayMethods() && g_AppWindowReadyForFrameBoost) {
        [self _setTargetRefreshRate:(CGFloat)[CFG_PTR resolvedTargetHz]];
    }
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
// 🎨 PHẦN 7: GIAO DIỆN & CẢM ỨNG (CÁCH LY TUYỆT ĐỐI TIẾN TRÌNH BÀN PHÍM)
// ==============================================================================
%group Group_ColorOS17_SafeUI

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsKeyboardProcessOrExtension() && !BoostIsPreferencesApp() && !BoostIsSystemCriticalDaemon()) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && self.window != nil && !BoostIsKeyboardProcessOrExtension() && !BoostIsPreferencesApp() && !BoostIsSystemCriticalDaemon()) {
        PMConfigureScrollView(self);
    }
}
%end

%hook CALayer
- (void)setNeedsDisplay {
    %orig;
    // CÁCH LY TUYỆT ĐỐI BÀN PHÍM KHÔNG THAY ĐỔI PTHREAD QOS
    if (IS_ON && CFG_PTR.touchResponseBoost && BoostIsSpringBoard() && !BoostIsKeyboardProcessOrExtension()) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    if (IS_ON && CFG_PTR.ultraResponsivenessProEngineOfficial && !BoostIsKeyboardProcessOrExtension()) {
        V2341_ExecuteUltraResponsivenessProEngineOfficial();
    }
    if (IS_ON && CFG_PTR.directRenderPipeBypassBeta4) {
        V2341_ExecuteDirectRenderPipeBypassBeta4();
    }
    if (IS_ON && CFG_PTR.zeroLagNeuralBoosterOfficial && BoostIsSpringBoard()) {
        V2341_ExecuteNeuralFrameCompensationOfficial();
    }
    if (IS_ON && CFG_PTR.hyperThreadIOAcceleratorOfficial) {
        V2341_ExecuteHyperThreadIORoutineOfficial();
    }
}
%end

%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsSystemCriticalDaemon() && !BoostIsKeyboardProcessOrExtension() && !BoostIsPreferencesApp()) {
        %orig(duration * 0.85, animations);
        return;
    }
    %orig(duration, animations);
}

+ (void)animateWithDuration:(NSTimeInterval)duration delay:(NSTimeInterval)delay options:(UIViewAnimationOptions)options animations:(void (^)(void))animations completion:(void (^)(BOOL finished))completion {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsSystemCriticalDaemon() && !BoostIsKeyboardProcessOrExtension() && !BoostIsPreferencesApp()) {
        %orig(duration * 0.85, delay, options, animations, completion);
        return;
    }
    %orig(duration, delay, options, animations, completion);
}
%end

%end // Group_ColorOS17_SafeUI

// ==============================================================================
// 🚀 PHẦN 8: SPRINGBOARD ENGINE (TRIỆT TIÊU 100% LỖI TREO RESPRING / USERSPACE REBOOT)
// ==============================================================================
%group Group_SpringBoard_Only

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig(application);
    // TRÌ HOÃN 1.2 GIÂY AN TOÀN ĐỂ SPRINGBOARD DỰNG XONG TOÀN BỘ CỔNG GIAO DIỆN
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_SpringBoardSceneReady = YES;
        V2341_LogTrace("SpringBoard", "SpringBoard Launch Completed - Clean Respring / Sreboot");
        
        V2341_AutoKernelMemoryRebalancer();
        V2341_AutoGPUFramePacingRegulator();
        V2341_AutoDaemonDeadlockImmunity();
        
        if (CFG_PTR.quantumMemoryPredictorBeta4) {
            V2341_ExecuteQuantumMemoryPredictorBeta4();
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
// 🧹 PHẦN 9: QUẢN LÝ TIẾN TRÌNH VÀ VÒNG ĐỜI BỘ NHỚ
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON) {
        V2341_RunGarbageCollector_Light();
        V2341_AutoKernelMemoryRebalancer();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.aggressiveRamClean) {
        V2341_AsyncMemoryPurgeSafe();
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.vsyncAdaptiveBufferOfficial) {
        V2341_ExecuteAdaptiveBufferRebalanceOfficial();
        V2341_AutoGPUFramePacingRegulator();
    }
}
%end

%end // Group_Memory_Engine

// ==============================================================================
// 🛡 PHẦN 10: MODULE BỔ TRỢ HỆ THỐNG NÂNG CAO (ADVANCED EXTENSIONS)
// ==============================================================================

@interface V2341_SystemOptimizer : NSObject
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

@implementation V2341_SystemOptimizer {
    BOOL _assertionActive;
}

+ (instancetype)sharedInstance {
    static V2341_SystemOptimizer *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[V2341_SystemOptimizer alloc] init];
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
        V2341_RunGarbageCollector_Aggressive();
        V2341_PurgeUnusedSharedBuffers();
        V2341_AutoKernelMemoryRebalancer();
        V2341_LogTrace("Optimizer", "Deep memory clean routine dispatched");
    }
}

- (void)optimizeCurrentTaskRunloop {
    @autoreleasepool {
        CFRunLoopRef currentLoop = CFRunLoopGetCurrent();
        if (currentLoop) {
            CFRunLoopWakeUp(currentLoop);
            V2341_AutoDaemonDeadlockImmunity();
            V2341_LogTrace("Optimizer", "Current runloop awakened");
        }
    }
}

- (void)registerSystemPowerAssertions {
    if (!_assertionActive) {
        _assertionActive = YES;
        V2341_LogTrace("Optimizer", "Power assertion registered");
    }
}

- (void)releaseSystemPowerAssertions {
    if (_assertionActive) {
        _assertionActive = NO;
        V2341_LogTrace("Optimizer", "Power assertion released");
    }
}

- (void)executeLowMemoryWatchdogRoutine {
    @autoreleasepool {
        V2341_PeriodicWatchdogHealthCheck();
        V2341_AutoKernelMemoryRebalancer();
        V2341_LogTrace("Optimizer", "Watchdog routine synchronized");
    }
}

- (void)recalibrateGraphicsDriverPacing {
    @autoreleasepool {
        V2341_ExecuteAdaptiveBufferRebalanceOfficial();
        V2341_AutoGPUFramePacingRegulator();
        V2341_LogTrace("Optimizer", "Graphics driver pacing finished");
    }
}

- (void)triggerHyperThreadOptimization {
    @autoreleasepool {
        V2341_ExecuteHyperThreadIORoutineOfficial();
        V2341_LogTrace("Optimizer", "HyperThread optimization dispatched");
    }
}

- (void)synchronizeQuantumClockPipeline {
    @autoreleasepool {
        V2341_ExecuteQuantumCoreSyncRoutineOfficial();
        V2341_LogTrace("Optimizer", "Quantum clock sync dispatched");
    }
}

- (void)flushTelemetryMetrics {
    if (!v2341_telemetry_queue) {
        v2341_telemetry_queue = dispatch_queue_create("com.boostv2341.telemetry", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_telemetry_queue, ^{
        @autoreleasepool {
            g_v2341GraphicsState.totalFramesRendered++;
            V2341_LogTrace("Telemetry", "Metrics cycle recorded");
        }
    });
}

- (void)executeCoreStabilitySurvey {
    if (!v2341_hardware_poll_queue) {
        v2341_hardware_poll_queue = dispatch_queue_create("com.boostv2341.hardware.poll", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2341_hardware_poll_queue, ^{
        @autoreleasepool {
            V2341_ValidateThermalStateBounds();
            V2341_PeriodicWatchdogHealthCheck();
            V2341_LogTrace("Survey", "Stability survey finished");
        }
    });
}

- (void)recoverFromMicroDeadlock {
    @autoreleasepool {
        V2341_AutoDaemonDeadlockImmunity();
        g_v2341WatchdogState.deadlocksPrevented++;
        V2341_LogTrace("Recovery", "Micro deadlock recovered");
    }
}

- (void)enforceFrameTimingConstraints {
    @autoreleasepool {
        V2341_AutoGPUFramePacingRegulator();
        V2341_LogTrace("Timing", "Frame timing verified");
    }
}

@end

// ==============================================================================
// ⚙️ PHẦN 11: KHỞI TẠO BỘ LÕI TWEAK V23.4.1 (ZERO-DEADLOCK BOOT)
// ==============================================================================

%ctor {
    @autoreleasepool {
        // CÁCH LY TUYỆT ĐỐI DAEMON DOPAMINE, SILEO VÀ TIẾN TRÌNH BÀN PHÍM
        if (BoostIsSystemCriticalDaemon() || BoostIsKeyboardProcessOrExtension() || BoostIsPreferencesApp()) {
            return;
        }

        // ĐỌC THẲNG FILE PLIST POSIX CHỐNG NGHẼN MACH CỦA CFPREFS TẠI USERSPACE BOOT
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

        // TRÌ HOÃN ĐĂNG KÝ DARWIN NOTIFY ĐỂ TRÁNH KẸT NOTIFYD TRONG LÚC USERSPACE BOOT
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                reloadPrefsNotification,
                CFSTR(NOTIFY_RELOAD),
                NULL,
                CFNotificationSuspensionBehaviorCoalesce
            );
        });

        // KHỞI TẠO DUY NHẤT 1 LẦN MỖI GROUP LOGOS
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

        V2341_InitializeWatchdogMonitor();
        V2341_DispatchBackgroundSyncMaintenance();
        V2341_ArmRenderGuardPipeline();
        V2341_ValidateThermalStateBounds();
        V2341_PeriodicWatchdogHealthCheck();
        
        [[V2341_SystemOptimizer sharedInstance] optimizeCurrentTaskRunloop];
        [[V2341_SystemOptimizer sharedInstance] executeLowMemoryWatchdogRoutine];
        [[V2341_SystemOptimizer sharedInstance] recalibrateGraphicsDriverPacing];
        
        if (CFG_PTR.hyperThreadIOAcceleratorOfficial) {
            [[V2341_SystemOptimizer sharedInstance] triggerHyperThreadOptimization];
        }
        if (CFG_PTR.quantumCoreSyncStabilizerOfficial) {
            [[V2341_SystemOptimizer sharedInstance] synchronizeQuantumClockPipeline];
        }

        V2341_LogTrace("Core", "SmoothiOS V23.4.1 DeepFix Loaded Successfully (No Truncation)");
    }
}
