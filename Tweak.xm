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

#define PREF_PATH @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define FALLBACK_PREF_PATH @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist"
#define NOTIFY_RELOAD "com.duchaivcy.boostiphone6s/ReloadPrefs"
#define SHARED_MMAP_FILE "/tmp/.smoothios_shared_config.bin"

extern char **environ;

// Module phụ trợ hệ thống
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

// Forward Declarations các thực thể Private của iOS SpringBoard & BackBoard
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

@interface UIWindow (Private)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
@end

@interface CALayer (PrivateBridge)
- (id)context;
- (void)setContext:(id)arg1;
@end

@interface UIScreen (PrivateMethods)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (CGFloat)_refreshRate;
- (void)_computeMetrics;
@end

// Khai báo nguyên mẫu các hàm điều khiển runtime nội bộ
static void V2201_RunGarbageCollector_Aggressive(void);
static void V2201_RunGarbageCollector_Light(void);
static void V2201_AsyncMemoryPurgeSafe(void);
static void V2201_ExecuteDynamicCoolingRoutine(void);
static void V2201_ExecuteNeuralFrameCompensation(void);
static void PMPrepareRuntime(void);
static BOOL PMIsUsableProcess(void);

// Con trỏ hàm đóng ứng dụng ngầm
static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

// Định danh hàng đợi điều phối luồng
static dispatch_queue_t v2201_bg_gc_queue = NULL;
static dispatch_queue_t v2201_async_io_queue = NULL;
static dispatch_queue_t v2201_thermal_monitor_queue = NULL;
static dispatch_queue_t v2201_neural_scheduler_queue = NULL;
static dispatch_queue_t v2201_ipc_sync_queue = NULL;

static BOOL PMRuntimeReady = NO;
static BOOL g_AppWindowReadyForFrameBoost = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;
static const void *kSmoothLayerHandshakeKey = &kSmoothLayerHandshakeKey;

// Khởi chạy an toàn không treo luồng giao diện
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
        isSB = [[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"];
    });
    return isSB;
}

static BOOL BoostIsPreferencesApp(void) {
    static BOOL isPrefs = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *name = [[NSProcessInfo processInfo] processName];
        isPrefs = [name isEqualToString:@"Preferences"] || [name isEqualToString:@"Settings"] || [name isEqualToString:@"TweakSettings"];
    });
    return isPrefs;
}

static BOOL BoostIsIsolatedKeyboardSearchProcess(void) {
    NSString *proc = [[NSProcessInfo processInfo] processName];
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
    if (!bid) return;
    pid_t pid;
    char *argv[] = {(char *)"/var/jb/bin/launchctl", (char *)"kill", (char *)[bid UTF8String], NULL};
    posix_spawn(&pid, "/var/jb/bin/launchctl", NULL, NULL, argv, environ);
}

static void load_bks_terminate(void) {
    dispatch_once(&g_bksTerminate_once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (!handle) handle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        if (handle) {
            g_bksTerminate = (BKSTerminateFunc)dlsym(handle, "BKSTerminateApplicationForReasonAndReportWithDescription");
        }
        if (!g_bksTerminate) g_bksTerminate = &bks_fallback_impl;
    });
}

static void PMPrepareRuntime(void) {
    if (PMRuntimeReady) return;
    PMRuntimeReady = YES;
}

static BOOL PMIsUsableProcess(void) {
    return [[NSProcessInfo processInfo] processName].length > 0;
}

// ==============================================================================
// 🧹 BỘ QUẢN LÝ TẢN NHIỆT, DỌN DẸP BỘ NHỚ VÀ NEURAL ENGINE (BETA 1)
// ==============================================================================
static void V2201_RunGarbageCollector_Aggressive(void) {
    if (!v2201_bg_gc_queue) {
        v2201_bg_gc_queue = dispatch_queue_create("com.boostv2201.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2201_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                [[NSURLCache sharedURLCache] removeAllCachedResponses];
                [CacheCleaner forceDeepMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 64);
                
                mach_port_t host_port = mach_host_self();
                mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
                vm_statistics64_data_t vm_stat;
                host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size);
            } @catch(NSException *e) {}
        }
    });
}

static void V2201_RunGarbageCollector_Light(void) {
    if (!v2201_bg_gc_queue) {
        v2201_bg_gc_queue = dispatch_queue_create("com.boostv2201.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2201_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                [CacheCleaner forceMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 20);
            } @catch(NSException *e) {}
        }
    });
}

static void V2201_AsyncMemoryPurgeSafe(void) {
    if (!v2201_async_io_queue) {
        v2201_async_io_queue = dispatch_queue_create("com.boostv2201.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2201_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
        }
    });
}

// Dynamic Thermal Engine Routine (Beta 1): Tự động giảm tải theo chu kỳ nhiệt
static void V2201_ExecuteDynamicCoolingRoutine(void) {
    if (!v2201_thermal_monitor_queue) {
        v2201_thermal_monitor_queue = dispatch_queue_create("com.boostv2201.thermal.routine", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2201_thermal_monitor_queue, ^{
        @autoreleasepool {
            @try {
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 32);
                [CATransaction begin];
                [CATransaction setAnimationDuration:0.06];
                [CATransaction commit];
            } @catch(NSException *e) {}
        }
    });
}

// Zero-Lag Neural Frame Booster Routine (Beta 1): Đồng bộ hóa luồng chạm và render
static void V2201_ExecuteNeuralFrameCompensation(void) {
    if (!v2201_neural_scheduler_queue) {
        v2201_neural_scheduler_queue = dispatch_queue_create("com.boostv2201.neural.scheduler", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2201_neural_scheduler_queue, ^{
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

static void PMApplySmoothFeel(UIScrollView *sv) {
    if (!sv) return;
    UIPanGestureRecognizer *pan = sv.panGestureRecognizer;
    if (pan) {
        pan.delaysTouchesBegan = NO;
        pan.delaysTouchesEnded = NO;
    }
}

static void PMConfigureScrollView(UIScrollView *sv) {
    if (!sv || !sv.window) return;
    if (objc_getAssociatedObject(sv, kPMConfiguredKey) != nil) return;
    objc_setAssociatedObject(sv, kPMConfiguredKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    sv.delaysContentTouches = NO;
    PMApplySmoothFeel(sv);
}

// ==============================================================================
// 🧠 PHẦN 1: CẤU HÌNH HỆ THỐNG V22.0.1 (IPC SHARED MEMORY SYNC CHỐNG LIỆT)
// ==============================================================================

typedef struct {
    uint32_t magic;
    uint32_t enabled;
    uint32_t enableHzControl;
    uint32_t targetHz;
    uint32_t enableFPSControl;
    uint32_t targetFPS;
    uint32_t forceOverclock144Hz;
    uint32_t dynamicThermalEngineBeta1;
    uint32_t zeroLagNeuralBoosterBeta1;
    uint32_t vsyncAdaptiveBufferBeta1;
    float animSpeed;
} __attribute__((packed)) SmoothSharedConfig;

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

// Nhóm 3: Hiệu năng Lõi, Auto Fake iPhone 16 Pro & Điều phối
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

// Nhóm 4: Nhiệt độ Cực Đoan & 3 TÍNH NĂNG MỚI (BETA 1)
@property (nonatomic, assign) BOOL dynamicThermalEngineBeta1;       // TÍNH NĂNG MỚI 1
@property (nonatomic, assign) BOOL zeroLagNeuralBoosterBeta1;       // TÍNH NĂNG MỚI 2
@property (nonatomic, assign) BOOL vsyncAdaptiveBufferBeta1;        // TÍNH NĂNG MỚI 3
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
- (void)syncSharedMemoryBuffer;
- (NSInteger)resolvedTargetHz;
- (NSInteger)resolvedTargetFPS;
@end

@implementation BoostConfig {
    dispatch_queue_t _configQueue;
}

+ (instancetype)sharedInstance {
    static BoostConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _configQueue = dispatch_queue_create("com.boostv2201.config.queue", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)syncSharedMemoryBuffer {
    if (BoostIsSpringBoard()) {
        int fd = open(SHARED_MMAP_FILE, O_RDWR | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) {
            SmoothSharedConfig sharedCfg;
            memset(&sharedCfg, 0, sizeof(SmoothSharedConfig));
            sharedCfg.magic = 0x534D5448; // "SMTH"
            sharedCfg.enabled = self.enabled ? 1 : 0;
            sharedCfg.enableHzControl = self.enableHzControl ? 1 : 0;
            sharedCfg.targetHz = (uint32_t)self.targetHz;
            sharedCfg.enableFPSControl = self.enableFPSControl ? 1 : 0;
            sharedCfg.targetFPS = (uint32_t)self.targetFPS;
            sharedCfg.forceOverclock144Hz = self.forceOverclock144Hz ? 1 : 0;
            sharedCfg.dynamicThermalEngineBeta1 = self.dynamicThermalEngineBeta1 ? 1 : 0;
            sharedCfg.zeroLagNeuralBoosterBeta1 = self.zeroLagNeuralBoosterBeta1 ? 1 : 0;
            sharedCfg.vsyncAdaptiveBufferBeta1 = self.vsyncAdaptiveBufferBeta1 ? 1 : 0;
            sharedCfg.animSpeed = (float)self.animSpeed;
            
            write(fd, &sharedCfg, sizeof(SmoothSharedConfig));
            close(fd);
            chmod(SHARED_MMAP_FILE, 0666);
        }
    }
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        NSString *plistPath = PREF_PATH;
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        if (!prefs) {
            plistPath = FALLBACK_PREF_PATH;
            prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        }

        // ĐỌC DỮ LIỆU TỪ SHARED MEMORY NẾU APP CON BỊ SANDBOX CHẶN PLIST
        if (!prefs && !BoostIsSpringBoard()) {
            int fd = open(SHARED_MMAP_FILE, O_RDONLY);
            if (fd >= 0) {
                SmoothSharedConfig sharedCfg;
                if (read(fd, &sharedCfg, sizeof(SmoothSharedConfig)) == sizeof(SmoothSharedConfig)) {
                    if (sharedCfg.magic == 0x534D5448) {
                        self.enabled = (sharedCfg.enabled == 1);
                        self.enableHzControl = (sharedCfg.enableHzControl == 1);
                        self.targetHz = (NSInteger)sharedCfg.targetHz;
                        self.enableFPSControl = (sharedCfg.enableFPSControl == 1);
                        self.targetFPS = (NSInteger)sharedCfg.targetFPS;
                        self.forceOverclock144Hz = (sharedCfg.forceOverclock144Hz == 1);
                        self.dynamicThermalEngineBeta1 = (sharedCfg.dynamicThermalEngineBeta1 == 1);
                        self.zeroLagNeuralBoosterBeta1 = (sharedCfg.zeroLagNeuralBoosterBeta1 == 1);
                        self.vsyncAdaptiveBufferBeta1 = (sharedCfg.vsyncAdaptiveBufferBeta1 == 1);
                        self.animSpeed = (CGFloat)sharedCfg.animSpeed;
                        close(fd);
                        return;
                    }
                }
                close(fd);
            }
        }

        #define GET_B(k, d) (prefs[k] ? [prefs[k] boolValue] : d)
        #define GET_I(k, d) (prefs[k] ? [prefs[k] integerValue] : d)
        #define GET_F(k, d) (prefs[k] ? [prefs[k] floatValue] : d)

        self.enabled = GET_B(@"Enabled", YES);
        if (self.enabled) {
            self.enableHzControl = GET_B(@"EnableHzControl", YES);
            self.targetHz = GET_I(@"TargetRefreshRate", 60);

            self.enableFPSControl = GET_B(@"EnableFPSControl", YES);
            self.targetFPS = GET_I(@"TargetFPSRate", 60);
            self.forceOverclock144Hz = GET_B(@"ForceOverclock144Hz", YES);

            self.colorOs17SmoothEngine = GET_B(@"ColorOs17SmoothEngine", YES);
            self.reduceMultiTaskLag = GET_B(@"ReduceMultiTaskLag", YES);
            self.fixAppLaunchBlackScreen = GET_B(@"FixAppLaunchBlackScreen", YES);
            self.fixAppExitStutter = GET_B(@"FixAppExitStutter", YES);
            self.touchResponseBoost = GET_B(@"TouchResponseBoost", YES);
            self.animSpeed = GET_F(@"AnimSpeed", 0.82);

            self.ios27AutoScheduler = GET_B(@"Ios27AutoScheduler", YES);
            self.realtimePriorityBoost = GET_B(@"RealtimePriorityBoost", YES);
            self.boostCpuGpu = GET_B(@"BoostCpuGpu", YES);
            self.smartRamClean = GET_B(@"SmartRamClean", YES);
            self.aggressiveRamClean = GET_B(@"AggressiveRamClean", NO);
            self.killBgApps = GET_B(@"KillBgApps", NO);
            self.turboAppLaunch = GET_B(@"TurboAppLaunch", YES);
            self.metalTripleBuffering = GET_B(@"MetalTripleBuffering", YES);
            self.gameFpsStabilizer = GET_B(@"GameFpsStabilizer", YES);
            self.optimizeSystemProcess = GET_B(@"OptimizeSystemProcess", YES);
            self.autoSpoofNewDevice = GET_B(@"AutoSpoofNewDevice", YES);

            // 3 TÍNH NĂNG MỚI (BETA 1)
            self.dynamicThermalEngineBeta1 = GET_B(@"DynamicThermalEngineBeta1", YES);
            self.zeroLagNeuralBoosterBeta1 = GET_B(@"ZeroLagNeuralBoosterBeta1", YES);
            self.vsyncAdaptiveBufferBeta1 = GET_B(@"VsyncAdaptiveBufferBeta1", YES);

            self.antiThermalThrottling = GET_B(@"AntiThermalThrottling", YES);
            self.smartThermalManager = GET_B(@"SmartThermalManager", YES);
            self.heavyLoadCooling = GET_B(@"HeavyLoadCooling", YES);
            self.chargeCoolingProtection = GET_B(@"ChargeCoolingProtection", YES);
            self.powerSaveMode = GET_B(@"PowerSaveMode", NO);

            self.bypassVarSandbox = GET_B(@"BypassVarSandbox", YES);
            self.blockAnalytics = GET_B(@"BlockAnalytics", YES);
            self.tcpTurboNetwork = GET_B(@"TcpTurboNetwork", YES);
        } else {
            self.enableHzControl = NO;
            self.enableFPSControl = NO;
            self.targetHz = 60;
            self.targetFPS = 60;
            self.forceOverclock144Hz = NO;
            self.animSpeed = 1.0;
        }

        [self syncSharedMemoryBuffer];
    });
}

- (NSInteger)resolvedTargetHz {
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz && self.targetHz == 144) return 144;
    if (!self.enableHzControl || self.targetHz == 0) return 60;
    return self.targetHz;
}

- (NSInteger)resolvedTargetFPS {
    if (self.powerSaveMode) return 30;
    if (self.forceOverclock144Hz && self.targetFPS == 144) return 144;
    if (!self.enableFPSControl || self.targetFPS == 0) return 60;
    return self.targetFPS;
}
@end

BoostConfig *CFG = nil;
#define CFG_PTR [BoostConfig sharedInstance]
#define IS_ON (CFG_PTR.enabled)

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[BoostConfig sharedInstance] loadSettings];
    CFG = [BoostConfig sharedInstance];
}

// ==============================================================================
// ⚡️ PHẦN 2: AUTO FAKE IPHONE 16 PRO (A18 PRO) & SCHEDULER TIME CONSTRAINT
// ==============================================================================

%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ON || !pathname) return %orig(pathname, mode);
    @try {
        if (CFG_PTR.bypassVarSandbox) {
            if (strstr(pathname, "/var/jb/") || strstr(pathname, "/Library/MobileSubstrate/")) return 0;
        }
    } @catch (NSException *e) {}
    return %orig(pathname, mode);
}

%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ON) return %orig(target_thread, flavor, policy_info, policy_count);
    @try {
        if (BoostIsSpringBoard() && (CFG_PTR.ios27AutoScheduler || CFG_PTR.realtimePriorityBoost) && flavor == THREAD_TIME_CONSTRAINT_POLICY && policy_info) {
            struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
            NSInteger currentHz = [CFG_PTR resolvedTargetHz];
            uint64_t periodNs = 1000000000ULL / (uint64_t)currentHz;
            ttcp->period = (uint32_t)periodNs;
            ttcp->computation = (uint32_t)(periodNs * 0.40);
            ttcp->constraint = (uint32_t)(periodNs * 0.50);
        }
    } @catch (NSException *e) {}
    return %orig(target_thread, flavor, policy_info, policy_count);
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ON || !name) return %orig(name, oldp, oldlenp, newp, newlen);
    
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
            if (oldp && oldlenp) {
                strlcpy((char *)oldp, model, *oldlenp);
                *oldlenp = strlen(model) + 1;
            }
            return 0;
        }
        if (strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.activecpu") == 0) {
            int fakeCores = 6;
            if (oldp && oldlenp) {
                memcpy(oldp, &fakeCores, sizeof(fakeCores));
                *oldlenp = sizeof(fakeCores);
            }
            return 0;
        }
    }
    return %orig(name, oldp, oldlenp, newp, newlen);
}

%hookf(int, uname, struct utsname *name) {
    int ret = %orig(name);
    if (ret == 0 && IS_ON && CFG_PTR.autoSpoofNewDevice && name) {
        strlcpy(name->machine, "iPhone16,2", sizeof(name->machine));
    }
    return ret;
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
// 🖥 PHẦN 3: ĐIỀU PHỐI KHUNG HÌNH (SỬA ĂN NGAY 30 HZ & 144 HZ)
// ==============================================================================
%group Group_Display_DualRate

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_AppWindowReadyForFrameBoost = YES;
    });
}
%end

%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ON && CFG_PTR.enableFPSControl) {
        %orig([CFG_PTR resolvedTargetFPS]);
    } else {
        %orig(fps);
    }
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (IS_ON && CFG_PTR.enableHzControl) {
        float rate = (float)[CFG_PTR resolvedTargetHz];
        CAFrameRateRange locked = CAFrameRateRangeMake(rate, rate, rate);
        %orig(locked);
    } else {
        %orig(range);
    }
}

- (void)setFrameInterval:(NSInteger)interval {
    if (IS_ON && (([CFG_PTR resolvedTargetHz] == 30) || ([CFG_PTR resolvedTargetFPS] == 30))) {
        %orig(2); // KHÓA CỨNG 30 FPS ĂN NGAY LẬP TỨC
    } else {
        %orig(1);
    }
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (IS_ON && CFG_PTR.enableHzControl) {
        return [CFG_PTR resolvedTargetHz];
    }
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ON && CFG_PTR.enableHzControl) {
        return [CFG_PTR resolvedTargetHz];
    }
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.enableHzControl) {
        %orig((CGFloat)[CFG_PTR resolvedTargetHz]);
    } else {
        %orig(rate);
    }
}

- (CGFloat)_refreshRate {
    if (IS_ON && CFG_PTR.enableHzControl) {
        return (CGFloat)[CFG_PTR resolvedTargetHz];
    }
    return %orig;
}
%end

%end // Group_Display_DualRate

// ==============================================================================
// 🎮 PHẦN 4: ZERO-BLACK SCREEN & METAL PIPELINE (CÔ LẬP CHO SPRINGBOARD)
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
    if (IS_ON && CFG_PTR.vsyncAdaptiveBufferBeta1) {
        return NO;
    }
    return %orig;
}
%end

%end // Group_Metal_SpringBoard_Only

// ==============================================================================
// 🎨 PHẦN 5: GIAO DIỆN COLOROS 17 AN TOÀN & CÁCH LY CHỐNG ĐƠ 10S
// ==============================================================================
%group Group_ColorOS17_SafeUI

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp()) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && self.window != nil && !BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp()) {
        PMConfigureScrollView(self);
    }
}
%end

%hook CALayer
- (void)setNeedsDisplay {
    %orig;
    if (IS_ON && CFG_PTR.touchResponseBoost && BoostIsSpringBoard() && !BoostIsIsolatedKeyboardSearchProcess()) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    if (IS_ON && CFG_PTR.zeroLagNeuralBoosterBeta1) {
        V2201_ExecuteNeuralFrameCompensation();
    }
}

- (CFTimeInterval)duration {
    if (!IS_ON) return %orig;
    return %orig * CFG_PTR.animSpeed;
}
%end

%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine) {
        if (!BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp()) {
            %orig(duration * 0.82, animations);
            return;
        }
    }
    %orig(duration, animations);
}
%end

%hook CAMediaTimingFunction
+ (instancetype)functionWithName:(CAMediaTimingFunctionName)name {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsIsolatedKeyboardSearchProcess() && !BoostIsPreferencesApp()) {
        if ([name isEqualToString:kCAMediaTimingFunctionDefault] || 
            [name isEqualToString:kCAMediaTimingFunctionEaseInEaseOut]) {
            return %orig(kCAMediaTimingFunctionEaseOut);
        }
    }
    return %orig(name);
}
%end

%end // Group_ColorOS17_SafeUI

// ==============================================================================
// 🚀 PHẦN 6: SPRINGBOARD ENGINE & TẢN NHIỆT DYNAMIC (BETA 1)
// ==============================================================================
%group Group_SpringBoard_Only

%hook SBAppSwitcherController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ON && CFG_PTR.reduceMultiTaskLag) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        [UIView setAnimationDuration:0.16];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseOut];
    }
    %orig(animated);
}

- (void)viewWillDisappear:(BOOL)animated {
    if (IS_ON && CFG_PTR.reduceMultiTaskLag) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        V2201_AsyncMemoryPurgeSafe();
    }
    %orig(animated);
}
%end

%hook SBFluidSwitcherViewController
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig(scrollView);
    if (IS_ON && CFG_PTR.reduceMultiTaskLag) {
        scrollView.layer.shadowOpacity = 0.0;
    }
}

- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ON && CFG_PTR.reduceMultiTaskLag) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(gesture);
}
%end

%hook SBApplication
- (void)processDidExit:(id)process {
    %orig(process);
    if (IS_ON && CFG_PTR.fixAppExitStutter) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [CATransaction commit];
            V2201_AsyncMemoryPurgeSafe();
        });
    }
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
    if (IS_ON && CFG_PTR.antiThermalThrottling) return NO;
    return %orig;
}
%end

%hook UIDevice
- (void)setBatteryMonitoringEnabled:(BOOL)enabled {
    %orig(YES);
}
%end

%hook IOPMPowerSource
- (void)updateStatus {
    %orig;
    if (IS_ON && CFG_PTR.chargeCoolingProtection) {
        UIDeviceBatteryState bState = [[UIDevice currentDevice] batteryState];
        if (bState == UIDeviceBatteryStateCharging || bState == UIDeviceBatteryStateFull) {
            if (CFG_PTR.dynamicThermalEngineBeta1) {
                V2201_ExecuteDynamicCoolingRoutine();
            }
        }
    }
}
%end

%hook ATXAnalyticsManager
- (void)sendEvent:(id)eventData {
    if (IS_ON && CFG_PTR.blockAnalytics) return;
    %orig(eventData);
}
%end

%end // Group_SpringBoard_Only

// ==============================================================================
// 🧹 PHẦN 7: QUẢN LÝ TIẾN TRÌNH & DỌN DẸP BỘ NHỚ AN TOÀN
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON) {
        V2201_RunGarbageCollector_Light();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && (CFG_PTR.smartRamClean || CFG_PTR.aggressiveRamClean)) {
        V2201_RunGarbageCollector_Aggressive();
    }
}
%end

%hook FBSSystemService
- (void)openApplication:(id)application withOptions:(NSDictionary *)options {
    if (!IS_ON) { 
        %orig(application, options); 
        return; 
    }
    
    if (CFG_PTR.killBgApps && BoostIsSpringBoard()) {
        @try {
            load_bks_terminate();
            if (g_bksTerminate != NULL && [application respondsToSelector:@selector(bundleIdentifier)]) {
                NSString *openingBid = [application performSelector:@selector(bundleIdentifier)];
                Class sac = objc_getClass("SBApplicationController");
                if (sac) {
                    id controller = [sac performSelector:@selector(sharedInstance)];
                    NSArray *apps = [controller performSelector:@selector(allApplications)];
                    for (id app in apps) {
                        NSString *bid = [app performSelector:@selector(bundleIdentifier)];
                        if (bid && ![bid isEqualToString:openingBid] && ![bid hasPrefix:@"com.apple."]) {
                            g_bksTerminate(bid, 5, NO, @"V22.0.1 Kill Background");
                        }
                    }
                }
            }
        } @catch (NSException *e) {}
    }

    %orig(application, options);
}
%end

%end // Group_Memory_Engine

// ==============================================================================
// ⚙️ PHẦN 8: KHỞI TẠO BỘ LÕI TWEAK V22.0.1 HYPER ARCHITECTURE
// ==============================================================================

%ctor {
    @autoreleasepool {
        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) {
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

        if (!IS_ON) return;

        // Bỏ qua Bàn phím / Spotlight / Search
        if (BoostIsIsolatedKeyboardSearchProcess()) {
            return;
        }

        // BẢO VỆ CÀI ĐẶT / PREFERENCES: Chống crash và treo
        if (BoostIsPreferencesApp()) {
            return;
        }

        // Khởi tạo Kernel trong SpringBoard
        if (BoostIsSpringBoard()) {
            @try {
                [[KernelBypass sharedInstance] initEnvironment];
                [[SystemBlocker sharedInstance] initBlockers];
                if (CFG_PTR.boostCpuGpu) [[KernelBypass sharedInstance] boostCurrentThreadPriority];
                if (CFG_PTR.smartRamClean) [[KernelBypass sharedInstance] forceMachPurge];
                if (CFG_PTR.bypassVarSandbox) init_privilege_escalation();
            } @catch (NSException *e) {}

            %init(Group_SpringBoard_Only);
            %init(Group_Metal_SpringBoard_Only);
        }

        setenv("MALLOC_OPTIONS", "AFGN", 1);
        if (CFG_PTR.turboAppLaunch) {
            setenv("DYLD_DISABLE_DOFS", "1", 1);
            setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
        }
        if (CFG_PTR.tcpTurboNetwork) setenv("CFNETWORK_DIAGNOSTICS", "0", 1);

        %init(_ungrouped);
        %init(Group_Display_DualRate);
        %init(Group_ColorOS17_SafeUI);
        %init(Group_Memory_Engine);

        PMPrepareRuntime();
        if (!PMIsUsableProcess()) PMRuntimeReady = NO;
    }
}
