// ==============================================================================
// Tweak.xm - Ultimate Performance, Thermal & Display Engine (Version 11.0)
// Target Architecture: arm64 / arm64e (iOS 14.0 - iOS 18.x)
// Hardware Range: iPhone 6s to iPhone 15 Pro Max
// Pure Code Output - Strictly Synchronized with DeviceBypass Infrastructure
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <unistd.h>
#import <spawn.h>
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/utsname.h>
#import <sys/wait.h>
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <CommonCrypto/CommonDigest.h>

extern char **environ;

#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

// ==============================================================================
// SECTION 0: CONFIGURATION INTERFACE & IMPLEMENTATION
// ==============================================================================

@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) CGFloat animSpeed;
@property (nonatomic, assign) CGFloat ramCleanIntensity;
@property (nonatomic, assign) BOOL aggressiveRAM;
@property (nonatomic, assign) BOOL killBgApps;
@property (nonatomic, assign) BOOL spoofModel;
@property (nonatomic, assign) BOOL disableThermal;
@property (nonatomic, assign) BOOL unlockProMotion;
@property (nonatomic, assign) BOOL forceRealtimePriority;
@property (nonatomic, assign) BOOL bypassSandboxChecks;
@property (nonatomic, assign) BOOL optimizeDiskIO;
@property (nonatomic, assign) BOOL enableAIAcceleration;
@property (nonatomic, assign) NSInteger networkBufferSize;
@property (nonatomic, assign) BOOL godModeForce120Hz;
@property (nonatomic, assign) BOOL godModeFakeiPhone16;
@property (nonatomic, assign) BOOL godModeMetalOverclock;
@property (nonatomic, assign) BOOL smartThermalManagement;
@property (nonatomic, assign) BOOL enableBlocker;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL gpuSafeOverclock;
@property (nonatomic, assign) BOOL blockAnalytics;
@property (nonatomic, assign) BOOL deepSleepOptimization;
@property (nonatomic, assign) BOOL safeSpoofGraphics;
@property (nonatomic, assign) BOOL ultraDeepRamClean;
@property (nonatomic, assign) BOOL tcpNoDelayBoost;
@property (nonatomic, assign) BOOL disableFrameThrottling;
@property (nonatomic, assign) BOOL pageCompressionOptimized;
@property (nonatomic, assign) NSInteger forcedRefreshRate;
@property (nonatomic, assign) BOOL hideJailbreak;
@property (nonatomic, assign) BOOL touchSamplingBoost;
@property (nonatomic, assign) BOOL liquidAssResolver;
@property (nonatomic, assign) BOOL neuralEngineUnlock;
@property (nonatomic, assign) BOOL lowPowerScheduler;
@property (nonatomic, assign) BOOL gpuBatchOptimization;
@property (nonatomic, assign) BOOL gameStutterFix;
@property (nonatomic, assign) BOOL batterySaverMax;
@property (nonatomic, assign) BOOL ios27Scheduler;
@property (nonatomic, assign) BOOL smoothFeelEngine;
@property (nonatomic, assign) BOOL deepImageProcessing;
@property (nonatomic, assign) BOOL cpuGpuBoost80;
@property (nonatomic, assign) BOOL ramBoost70;
@property (nonatomic, assign) BOOL adaptiveThermalFPS;
@property (nonatomic, assign) BOOL chargingThermalGuard;
@property (nonatomic, assign) BOOL backgroundPurgeOnExit;
+ (instancetype)sharedInstance;
- (void)loadSettings;
- (BOOL)isDeviceOldGeneration;
- (NSInteger)physicalCoreCount;
@end

@implementation BoostConfig {
    dispatch_queue_t _configQueue;
    BOOL _isOldDevice;
    NSInteger _cachedCoreCount;
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
        _configQueue = dispatch_queue_create("com.boostiphone6s.config.v12", DISPATCH_QUEUE_SERIAL);
        _isOldDevice = [self isDeviceOldGeneration];
        _cachedCoreCount = [self physicalCoreCount];
        [self loadSettings];
    }
    return self;
}

- (BOOL)isDeviceOldGeneration {
    NSString *machine = @"";
    size_t size = 0;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    if (size > 0) {
        char *buf = (char *)malloc(size);
        if (buf) {
            sysctlbyname("hw.machine", buf, &size, NULL, 0);
            machine = [NSString stringWithUTF8String:buf];
            free(buf);
        }
    }
    NSArray *oldPrefixes = @[@"iPhone8,", @"iPhone9,", @"iPhone10,", @"iPhone12,8"];
    for (NSString *prefix in oldPrefixes) {
        if ([machine hasPrefix:prefix]) return YES;
    }
    return NO;
}

- (NSInteger)physicalCoreCount {
    int cores = 0;
    size_t size = sizeof(cores);
    sysctlbyname("hw.physicalcpu", &cores, &size, NULL, 0);
    return cores > 0 ? cores : 4;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        NSString *plistPath = @"/var/jb/Library/Preferences/com.taojb.boostiphone6s.plist";
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        if (!prefs) {
            plistPath = @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
            prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        }
        
        #define GET_BOOL(key, def) (prefs[key] ? [prefs[key] boolValue] : def)
        #define GET_FLOAT(key, def) (prefs[key] ? [prefs[key] floatValue] : def)
        #define GET_INT(key, def) (prefs[key] ? [prefs[key] integerValue] : def)
        
        self.enabled = GET_BOOL(@"Enabled", NO);
        
        if (self.enabled) {
            self.animSpeed = GET_FLOAT(@"AnimSpeed", 0.3);
            self.ramCleanIntensity = GET_FLOAT(@"RamCleanIntensity", 50.0);
            self.aggressiveRAM = GET_BOOL(@"AggressiveRAM", NO);
            self.killBgApps = GET_BOOL(@"KillBackgroundApps", NO);
            self.spoofModel = GET_BOOL(@"SpoofModel", YES);
            self.disableThermal = GET_BOOL(@"DisableThermal", YES);
            self.unlockProMotion = GET_BOOL(@"UnlockProMotion", YES);
            self.forceRealtimePriority = GET_BOOL(@"ForceRealtime", YES);
            self.bypassSandboxChecks = GET_BOOL(@"BypassSandbox", YES);
            self.optimizeDiskIO = GET_BOOL(@"OptimizeDisk", YES);
            self.enableAIAcceleration = GET_BOOL(@"EnableAIBoost", YES);
            self.networkBufferSize = GET_INT(@"NetBufSize", 2048);
            self.godModeForce120Hz = GET_BOOL(@"GodMode120Hz", YES);
            self.godModeFakeiPhone16 = GET_BOOL(@"GodModeFake16", YES);
            self.godModeMetalOverclock = GET_BOOL(@"GodModeMetal", YES);
            self.smartThermalManagement = GET_BOOL(@"SmartThermal", YES);
            self.enableBlocker = GET_BOOL(@"EnableBlocker", NO);
            self.turboAppLaunch = GET_BOOL(@"TurboAppLaunch", YES);
            self.gpuSafeOverclock = GET_BOOL(@"GPUSafeOverclock", YES);
            self.blockAnalytics = GET_BOOL(@"BlockAnalytics", YES);
            self.deepSleepOptimization = GET_BOOL(@"DeepSleepOpt", NO);
            self.safeSpoofGraphics = GET_BOOL(@"SafeSpoofGraphics", YES);
            self.ultraDeepRamClean = GET_BOOL(@"UltraDeepRam", YES);
            self.tcpNoDelayBoost = GET_BOOL(@"TCPNoDelayBoost", YES);
            self.disableFrameThrottling = GET_BOOL(@"DisableFrameThrottling", YES);
            self.pageCompressionOptimized = GET_BOOL(@"PageCompressionOptimized", YES);
            self.forcedRefreshRate = GET_INT(@"ForcedRefreshRate", 120);
            self.hideJailbreak = GET_BOOL(@"HideJailbreak", YES);
            self.touchSamplingBoost = GET_BOOL(@"TouchSamplingBoost", YES);
            self.liquidAssResolver = GET_BOOL(@"LiquidAssResolver", YES);
            self.neuralEngineUnlock = GET_BOOL(@"NeuralEngineUnlock", YES);
            self.lowPowerScheduler = GET_BOOL(@"LowPowerScheduler", YES);
            self.gpuBatchOptimization = GET_BOOL(@"GPUBatchOptimization", YES);
            self.gameStutterFix = GET_BOOL(@"GameStutterFix", YES);
            self.batterySaverMax = GET_BOOL(@"BatterySaverMax", NO);
            self.ios27Scheduler = GET_BOOL(@"IOS27Scheduler", YES);
            self.smoothFeelEngine = GET_BOOL(@"SmoothFeelEngine", YES);
            self.deepImageProcessing = GET_BOOL(@"DeepImageProcessing", YES);
            self.cpuGpuBoost80 = GET_BOOL(@"CPUGPUBoost80", YES);
            self.ramBoost70 = GET_BOOL(@"RamBoost70", YES);
            self.adaptiveThermalFPS = GET_BOOL(@"AdaptiveThermalFPS", YES);
            self.chargingThermalGuard = GET_BOOL(@"ChargingThermalGuard", YES);
            self.backgroundPurgeOnExit = GET_BOOL(@"BackgroundPurgeOnExit", YES);
            
            if (_isOldDevice && self.forcedRefreshRate > 60) self.forcedRefreshRate = 60;
            if (self.ramCleanIntensity < 0.1) self.ramCleanIntensity = 0.1;
            if (self.ramCleanIntensity > 100.0) self.ramCleanIntensity = 100.0;
            if (_cachedCoreCount <= 2 && self.animSpeed < 0.4) self.animSpeed = 0.4;
        } else {
            self.animSpeed = 1.0;
            self.ramCleanIntensity = 50.0;
            self.aggressiveRAM = NO;
            self.killBgApps = NO;
            self.spoofModel = NO;
            self.disableThermal = NO;
            self.unlockProMotion = NO;
            self.forceRealtimePriority = NO;
            self.bypassSandboxChecks = NO;
            self.optimizeDiskIO = NO;
            self.enableAIAcceleration = NO;
            self.networkBufferSize = 64;
            self.godModeForce120Hz = NO;
            self.godModeFakeiPhone16 = NO;
            self.godModeMetalOverclock = NO;
            self.smartThermalManagement = NO;
            self.enableBlocker = NO;
            self.turboAppLaunch = NO;
            self.gpuSafeOverclock = NO;
            self.blockAnalytics = NO;
            self.deepSleepOptimization = NO;
            self.safeSpoofGraphics = NO;
            self.ultraDeepRamClean = NO;
            self.tcpNoDelayBoost = NO;
            self.disableFrameThrottling = NO;
            self.pageCompressionOptimized = NO;
            self.forcedRefreshRate = 60;
            self.hideJailbreak = NO;
            self.touchSamplingBoost = NO;
            self.liquidAssResolver = NO;
            self.neuralEngineUnlock = NO;
            self.lowPowerScheduler = NO;
            self.gpuBatchOptimization = NO;
            self.gameStutterFix = NO;
            self.batterySaverMax = NO;
            self.ios27Scheduler = NO;
            self.smoothFeelEngine = NO;
            self.deepImageProcessing = NO;
            self.cpuGpuBoost80 = NO;
            self.ramBoost70 = NO;
            self.adaptiveThermalFPS = NO;
            self.chargingThermalGuard = NO;
            self.backgroundPurgeOnExit = NO;
        }
    });
}
@end

BoostConfig *CFG = nil;
BOOL IS_ENABLED = NO;
#define CFG_PTR [BoostConfig sharedInstance]
#define IS_ON (CFG_PTR.enabled)
#define IS_OLD_DEVICE ([CFG_PTR isDeviceOldGeneration])

// ==============================================================================
// SECTION 1: C HELPER FUNCTIONS (FILE SCOPE — TRƯỚC TẤT CẢ LOGOS HOOKS)
// ==============================================================================

static inline void run_posix_cmd_safe(const char *path, const char *arg1, const char *arg2) {
    pid_t pid;
    char *argv[] = {(char *)path, (char *)arg1, (char *)arg2, NULL};
    int result = posix_spawn(&pid, path, NULL, NULL, argv, environ);
    if (result == 0) {
        int status;
        waitpid(pid, &status, 0);
    }
}

static BOOL BoostIsSpringBoard(void) {
    return [[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"];
}

typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;
static dispatch_once_t g_bksTerminate_once;

static void bks_fallback_impl(NSString *bid, NSInteger reason, BOOL report, NSString *desc) {
    pid_t pid;
    char *argv[] = {(char *)"/var/jb/bin/launchctl", (char *)"kill", (char *)[bid UTF8String], NULL};
    posix_spawn(&pid, "/var/jb/bin/launchctl", NULL, NULL, argv, environ);
}

static void load_bks_terminate(void) {
    dispatch_once(&g_bksTerminate_once, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (handle) {
            g_bksTerminate = (BKSTerminateFunc)dlsym(handle, "BKSTerminateApplicationForReasonAndReportWithDescription");
            if (g_bksTerminate) return;
        }
        handle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        if (handle) {
            g_bksTerminate = (BKSTerminateFunc)dlsym(handle, "BKSTerminateApplicationForReasonAndReportWithDescription");
            if (g_bksTerminate) return;
        }
        g_bksTerminate = &bks_fallback_impl;
    });
}

static void reloadPrefsNotification(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    [[BoostConfig sharedInstance] loadSettings];
    CFG = [BoostConfig sharedInstance];
    IS_ENABLED = CFG.enabled;
}

static void BoostApplyUnifiedPerformance(void) {
    if (!IS_ON) return;
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    setpriority(PRIO_PROCESS, 0, -20);
    if (CFG_PTR.ramBoost70 || CFG_PTR.ramCleanIntensity > 0) {
        size_t goalBytes = (size_t)(CFG_PTR.ramCleanIntensity * 1024 * 1024);
        malloc_zone_pressure_relief(NULL, goalBytes);
    }
}

static const BOOL PMEnabled = YES;
static const BOOL PMTouchResponseEnabled = YES;
static const BOOL PMSmoothScrollEnabled = YES;
static const BOOL PMReduceRepeatedWork = YES;
static const BOOL PMDiagnosticsEnabled = NO;

static BOOL PMRuntimeReady = NO;
static NSObject *PMConfiguredMarker = nil;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

static void PMDebugLog(NSString *format, ...) {
    if (!PMDiagnosticsEnabled) return;
    if (!format || format.length == 0) return;
    va_list args; 
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[ProMotionControl] %@", msg);
}

static void PMPrepareRuntime(void) {
    if (PMRuntimeReady) return;
    PMConfiguredMarker = [NSObject new];
    PMRuntimeReady = YES;
    PMDebugLog(@"Runtime initialized");
}

static BOOL PMIsUsableProcess(void) {
    if (!PMRuntimeReady) return NO;
    return [[NSProcessInfo processInfo] processName].length > 0;
}

static BOOL PMScrollViewWasConfigured(UIScrollView *sv) {
    if (!sv) return NO;
    return objc_getAssociatedObject(sv, kPMConfiguredKey) != nil;
}

static void PMMarkScrollViewConfigured(UIScrollView *sv) {
    if (!sv || !PMConfiguredMarker) return;
    objc_setAssociatedObject(sv, kPMConfiguredKey, PMConfiguredMarker, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static BOOL PMIsSuitableScrollView(UIScrollView *sv) {
    if (!PMEnabled || !PMRuntimeReady || !sv) return NO;
    if (!sv.window || sv.hidden || !sv.userInteractionEnabled) return NO;
    if (PMReduceRepeatedWork && PMScrollViewWasConfigured(sv)) return NO;
    return YES;
}

static void PMApplyTouchOptimisation(UIScrollView *sv) {
    if (!PMTouchResponseEnabled) return;
    if (sv.delaysContentTouches) sv.delaysContentTouches = NO;
}

static void PMApplySmoothFeel(UIScrollView *sv) {
    if (!IS_ON || !CFG_PTR.smoothFeelEngine) return;
    UIPanGestureRecognizer *pan = sv.panGestureRecognizer;
    if (pan) {
        pan.delaysTouchesBegan = NO;
        pan.delaysTouchesEnded = NO;
    }
}

static void PMApplyScrollOptimisation(UIScrollView *sv) {
    if (!PMSmoothScrollEnabled) return;
    (void)sv;
}

static void PMApplyGestureStability(UIScrollView *sv) {
    if (sv == nil) return;
}

static void PMConfigureTableView(UITableView *tv) {
    if (tv == nil) return;
    (void)tv;
}

static void PMConfigureCollectionView(UICollectionView *cv) {
    if (cv == nil) return;
    (void)cv;
}

static void PMConfigureScrollView(UIScrollView *sv) {
    if (!PMIsSuitableScrollView(sv)) return;
    PMMarkScrollViewConfigured(sv);
    PMApplyTouchOptimisation(sv);
    PMApplySmoothFeel(sv);
    PMApplyScrollOptimisation(sv);
    PMApplyGestureStability(sv);
    if ([sv isKindOfClass:[UITableView class]]) PMConfigureTableView((UITableView *)sv);
    else if ([sv isKindOfClass:[UICollectionView class]]) PMConfigureCollectionView((UICollectionView *)sv);
    if (PMDiagnosticsEnabled) PMDebugLog(@"Configured: %@", NSStringFromClass([sv class]));
}

static void BoostInjectEnvironmentVariables(void) {
    if (!IS_ON) return;
    if (CFG_PTR.enableAIAcceleration) setenv("MALLOC_OPTIONS", "AFGN", 1);
    if (CFG_PTR.turboAppLaunch) {
        setenv("DYLD_DISABLE_DOFS", "1", 1);
        setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
    }
    if (CFG_PTR.pageCompressionOptimized) setenv("VM_COMPRESSION_RATIO", "MAX", 1);
    setenv("CFNETWORK_DIAGNOSTICS", "0", 1);
    setenv("IOKIT_AUTOCLEAN", "1", 1);
}

// ==============================================================================
// SECTION 2: %hookf AT FILE SCOPE (C FUNCTION HOOKS)
// ==============================================================================

%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ON || !CFG_PTR.bypassSandboxChecks || !pathname) return %orig(pathname, mode);
    if (strstr(pathname, "/Caches/") || strstr(pathname, "/tmp/") || 
        strstr(pathname, "/var/mobile/Containers/") || strstr(pathname, "/var/jb/") ||
        strstr(pathname, "/Library/PreferenceBundles/") || strstr(pathname, "/Library/MobileSubstrate/")) {
        return 0;
    }
    return %orig(pathname, mode);
}

%hookf(ssize_t, write, int fd, const void *buf, size_t count) {
    if (!IS_ON || !CFG_PTR.optimizeDiskIO) return %orig(fd, buf, count);
    return %orig(fd, buf, count);
}

%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ON || !CFG_PTR.forceRealtimePriority || !policy_info) return %orig(target_thread, flavor, policy_info, policy_count);
    if (flavor == THREAD_TIME_CONSTRAINT_POLICY) {
        struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
        NSInteger hz = CFG_PTR.forcedRefreshRate > 0 ? CFG_PTR.forcedRefreshRate : 60;
        uint64_t periodNs = 1000000000ULL / (uint64_t)hz;
        ttcp->period = (uint32_t)(periodNs);
        ttcp->computation = (uint32_t)(periodNs * 0.4);
        ttcp->constraint = (uint32_t)(periodNs * 0.6);
    }
    return %orig(target_thread, flavor, policy_info, policy_count);
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ON || !name) return %orig(name, oldp, oldlenp, newp, newlen);
    if (CFG_PTR.disableThermal && strcmp(name, "kern.thermal.temperature") == 0) {
        float fakeTemp = 35.0f;
        if (oldp && oldlenp && *oldlenp >= sizeof(float)) {
            memcpy(oldp, &fakeTemp, sizeof(float));
            *oldlenp = sizeof(float);
            return 0;
        }
    }
    if (CFG_PTR.godModeFakeiPhone16 && (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0)) {
        const char *fakeModel = "iPhone16,2";
        if (oldp && oldlenp) {
            strlcpy((char *)oldp, fakeModel, *oldlenp);
            *oldlenp = strlen(fakeModel) + 1;
        } else if (oldlenp) {
            *oldlenp = strlen(fakeModel) + 1;
        }
        return 0;
    }
    if (CFG_PTR.godModeFakeiPhone16 && (strcmp(name, "hw.ncpu") == 0 || strcmp(name, "hw.activecpu") == 0)) {
        int fakeCores = 6;
        if (oldp && oldlenp) {
            memcpy(oldp, &fakeCores, sizeof(fakeCores));
            *oldlenp = sizeof(fakeCores);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakeCores);
        }
        return 0;
    }
    if (CFG_PTR.godModeFakeiPhone16 && (strcmp(name, "hw.physicalcpu") == 0 || strcmp(name, "hw.logicalcpu") == 0)) {
        int fakeCores = 6;
        if (oldp && oldlenp) {
            memcpy(oldp, &fakeCores, sizeof(fakeCores));
            *oldlenp = sizeof(fakeCores);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakeCores);
        }
        return 0;
    }
    if (CFG_PTR.godModeFakeiPhone16 && strcmp(name, "hw.memsize") == 0) {
        uint64_t fakeMem = 8ULL * 1024 * 1024 * 1024;
        if (oldp && oldlenp) {
            memcpy(oldp, &fakeMem, sizeof(fakeMem));
            *oldlenp = sizeof(fakeMem);
        } else if (oldlenp) {
            *oldlenp = sizeof(fakeMem);
        }
        return 0;
    }
    if (CFG_PTR.tcpNoDelayBoost && strcmp(name, "net.inet.tcp.mscanned") == 0) {
        int val = 1;
        if (oldp && oldlenp) {
            memcpy(oldp, &val, sizeof(val));
            *oldlenp = sizeof(val);
        }
        return 0;
    }
    return %orig(name, oldp, oldlenp, newp, newlen);
}

%hookf(int, uname, struct utsname *name) {
    int ret = %orig(name);
    if (ret == 0 && IS_ON && CFG_PTR.godModeFakeiPhone16 && name) {
        strlcpy(name->machine, "iPhone16,2", sizeof(name->machine));
    }
    return ret;
}

%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    if (IS_ON && CFG_PTR.tcpNoDelayBoost) {
        int nodelay = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
        int bufSize = (int)(CFG_PTR.networkBufferSize * 1024);
        if (bufSize > 0 && bufSize <= 4 * 1024 * 1024) {
            setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
            setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));
        }
    }
    return %orig(socket, address, address_len);
}

// ==============================================================================
// SECTION 3: LOGOS GROUPS (OBJECTIVE-C CLASS HOOKS)
// ==============================================================================

%group FramePacingEngine

%hook CADisplayLink

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (!IS_ON || !CFG_PTR.godModeForce120Hz) {
        %orig(fps);
        return;
    }
    NSInteger target = CFG_PTR.forcedRefreshRate;
    if (IS_OLD_DEVICE && target > 60) target = 60;
    
    if (target > 0) {
        %orig(target);
        return;
    }
    %orig(fps);
}

- (NSInteger)preferredFramesPerSecond {
    if (!IS_ON || !CFG_PTR.godModeForce120Hz) return %orig;
    NSInteger target = CFG_PTR.forcedRefreshRate;
    if (IS_OLD_DEVICE && target > 60) target = 60;
    return target > 0 ? target : %orig;
}

%end

%hook UIScrollView

- (void)setContentOffset:(CGPoint)offset animated:(BOOL)animated { 
    %orig(offset, animated); 
}

- (void)_setContentOffset:(CGPoint)offset animated:(BOOL)animated { 
    %orig(offset, animated); 
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && self.window != nil) {
        PMConfigureScrollView(self);
    }
}

%end

%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (IS_ON && CFG_PTR.godModeForce120Hz) {
        NSInteger target = CFG_PTR.forcedRefreshRate;
        if (IS_OLD_DEVICE && target > 60) target = 60;
        return target > 0 ? target : 60;
    }
    return %orig;
}

- (BOOL)isProMotionEnabled {
    if (IS_ON && CFG_PTR.godModeForce120Hz && !IS_OLD_DEVICE) return YES;
    return %orig;
}

- (CGFloat)nativeScale {
    if (IS_ON && CFG_PTR.spoofModel) return 3.0;
    return %orig;
}

- (CGFloat)scale {
    if (IS_ON && CFG_PTR.spoofModel) return 3.0;
    return %orig;
}

%end

%end // FramePacingEngine

%group ThermalBypassEngine

%hook NSProcessInfo

- (NSProcessInfoThermalState)thermalState {
    if (IS_ON && CFG_PTR.disableThermal) return NSProcessInfoThermalStateNominal;
    return %orig;
}

+ (BOOL)isThermalPressureCritical {
    if (IS_ON && CFG_PTR.disableThermal) return NO;
    return %orig;
}

%end

%hook CALayer

- (CFTimeInterval)duration {
    if (!IS_ON) return %orig;
    CFTimeInterval base = %orig;
    CGFloat speed = CFG_PTR.animSpeed;
    speed *= 0.7;
    if (CFG_PTR.smartThermalManagement) {
        CGFloat thermalFactor = [[SmartThermal sharedInstance] recommendedAnimationMultiplier];
        speed *= thermalFactor;
    }
    return base * speed;
}

%end

%end // ThermalBypassEngine

%group GPUEngine

%hook CAMetalLayer

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ON && CFG_PTR.godModeMetalOverclock) {
        NSUInteger optimalCount = CFG_PTR.gameStutterFix ? 3 : 2;
        %orig(optimalCount);
        return;
    }
    %orig(count);
}

- (BOOL)presentsWithTransaction {
    if (IS_ON && CFG_PTR.godModeMetalOverclock) return NO;
    return %orig;
}

- (void)setFramebufferOnly:(BOOL)flag {
    if (IS_ON && CFG_PTR.godModeMetalOverclock) {
        %orig(NO);
        return;
    }
    %orig(flag);
}

%end

%hook MTLTextureDescriptor

- (void)setPixelFormat:(NSUInteger)pixelFormat {
    if (!IS_ON) { %orig(pixelFormat); return; }
    if (CFG_PTR.godModeMetalOverclock && pixelFormat == 80) pixelFormat = 75;
    %orig(pixelFormat);
}

- (void)setStorageMode:(NSUInteger)storageMode {
    if (!IS_ON) { %orig(storageMode); return; }
    if (CFG_PTR.godModeMetalOverclock) {
        %orig(0);
        return;
    }
    %orig(storageMode);
}

%end

%end // GPUEngine

%group MemoryEngine

%hook UIApplication

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    if (!IS_ON) { %orig(application); return; }
    SEL sel = NSSelectorFromString(@"_purgeMemoryCache");
    if ([self respondsToSelector:sel]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [self performSelector:sel];
        #pragma clang diagnostic pop
    }
    if (CFG_PTR.aggressiveRAM || CFG_PTR.ultraDeepRamClean) {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            if (CFG_PTR.ultraDeepRamClean) [CacheCleaner forceDeepMemoryPurge];
            else [CacheCleaner forceMemoryPurge];
            if (CFG_PTR.ramBoost70) {
                size_t goalBytes = (size_t)(CFG_PTR.ramCleanIntensity * 1024 * 1024);
                malloc_zone_pressure_relief(NULL, goalBytes);
            }
        });
    }
    %orig(application);
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    if (IS_ON && CFG_PTR.backgroundPurgeOnExit) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            if (CFG_PTR.ramBoost70) {
                size_t goalBytes = (size_t)(CFG_PTR.ramCleanIntensity * 1024 * 1024);
                malloc_zone_pressure_relief(NULL, goalBytes);
            }
            [CacheCleaner forceMemoryPurge];
        });
    }
    %orig(application);
}

%end

%hook FBSSystemService

- (void)openApplication:(id)application withOptions:(NSDictionary *)options {
    if (!IS_ON) { 
        %orig(application, options); 
        return; 
    }
    
    if (CFG_PTR.killBgApps && BoostIsSpringBoard()) {
        load_bks_terminate();
        if (g_bksTerminate != NULL) {
            NSString *openingBid = nil;
            if ([application respondsToSelector:@selector(bundleIdentifier)]) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                openingBid = (NSString *)[application performSelector:@selector(bundleIdentifier)];
                #pragma clang diagnostic pop
            }
            Class sac = objc_getClass("SBApplicationController");
            if (sac) {
                #pragma clang diagnostic push
                #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                id controller = [sac performSelector:@selector(sharedInstance)];
                if (controller && [controller respondsToSelector:@selector(allApplications)]) {
                    NSArray *apps = (NSArray *)[controller performSelector:@selector(allApplications)];
                    for (id app in apps) {
                        if (![app respondsToSelector:@selector(bundleIdentifier)]) continue;
                        NSString *bid = (NSString *)[app performSelector:@selector(bundleIdentifier)];
                        if (!bid || [bid isEqualToString:openingBid] || [bid hasPrefix:@"com.apple."]) continue;
                        g_bksTerminate(bid, 5, NO, @"BoostiPhone6s v12 cleanup");
                    }
                }
                #pragma clang diagnostic pop
            }
        }
    }

    // ĐÃ SỬA: Dùng chung một biến định danh duy nhất và gọi %orig một lần duy nhất
    NSDictionary *finalOptions = options;
    if (CFG_PTR.turboAppLaunch) {
        finalOptions = nil;
    }
    %orig(application, finalOptions);
}

%end

%end // MemoryEngine

%group UIEngine

%hook UIView

- (void)setAlpha:(CGFloat)alpha {
    if (!IS_ON) { %orig(alpha); return; }
    if (alpha >= 0.95) alpha = 1.0;
    %orig(alpha);
}

%end

%hook UIVisualEffectView

- (void)didMoveToSuperview {
    if (!IS_ON) { %orig; return; }
    [self removeFromSuperview];
}

%end

%hook UITextView

- (void)layoutSubviews {
    if (!IS_ON || !CFG_PTR.enableAIAcceleration) { %orig; return; }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    %orig;
    [CATransaction commit];
}

%end

%hook UIKeyboardImpl

- (void)updateFrame:(CGRect)frame {
    if (!IS_ON || !CFG_PTR.enableAIAcceleration) { %orig(frame); return; }
    [UIView animateWithDuration:0.0 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
        %orig(frame);
    } completion:nil];
}

%end

%hook UIWindow

- (void)sendEvent:(UIEvent *)event { 
    %orig(event); 
}

%end

%hook CALayer

- (BOOL)allowsGroupOpacity {
    if (IS_ON && CFG_PTR.deepImageProcessing) return NO;
    return %orig;
}

%end

%end // UIEngine

%group BatteryEngine

%hook NSTimer

+ (NSTimer *)timerWithTimeInterval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)u repeats:(BOOL)r {
    if (IS_ON && CFG_PTR.batterySaverMax && r && ti > 0 && ti < 0.033) ti = 0.033;
    return %orig(ti, t, s, u, r);
}

+ (NSTimer *)scheduledTimerWithTimeInterval:(NSTimeInterval)ti target:(id)t selector:(SEL)s userInfo:(id)u repeats:(BOOL)r {
    if (IS_ON && CFG_PTR.batterySaverMax && r && ti > 0 && ti < 0.033) ti = 0.033;
    return %orig(ti, t, s, u, r);
}

%end

%end // BatteryEngine

%group SystemHooks

%hook ATXAnalyticsManager

- (void)sendEvent:(id)eventData {
    if (IS_ON && CFG_PTR.blockAnalytics) return;
    %orig(eventData);
}

%end

%hook SleepManager

- (void)enterDeepSleep {
    if (!IS_ON || !CFG_PTR.deepSleepOptimization) { %orig; return; }
    run_posix_cmd_safe("/var/jb/bin/launchctl", "stop", "com.apple.analyticsd");
    %orig;
}

%end

%hook GraphicsQualityManager

- (void)setQualityLevel:(NSUInteger)quality {
    if (IS_ON && CFG_PTR.safeSpoofGraphics) {
        %orig(3);
        return;
    }
    %orig(quality);
}

%end

%end // SystemHooks

// ==============================================================================
// SECTION 4: CONSTRUCTOR & SUBSYSTEM INITIALIZATION
// ==============================================================================

%ctor {
    @autoreleasepool {
        CFG = [BoostConfig sharedInstance];
        IS_ENABLED = CFG.enabled;
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            NULL,
            reloadPrefsNotification,
            CFSTR("com.taojb.boostiphone6s.settings/reload"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );
        
        [[CrashGuard sharedInstance] startMonitoring];
        if (![[CrashGuard sharedInstance] canExecuteHooks]) return;
        if (!IS_ON) return;
        
        %init(_ungrouped);
        
        [[KernelBypass sharedInstance] initEnvironment];
        if (CFG_PTR.enableBlocker) [[SystemBlocker sharedInstance] initBlockers];
        if (CFG_PTR.forceRealtimePriority) [[KernelBypass sharedInstance] boostCurrentThreadPriority];
        if (CFG_PTR.aggressiveRAM || CFG_PTR.ultraDeepRamClean) [[KernelBypass sharedInstance] forceMachPurge];
        if (CFG_PTR.bypassSandboxChecks || CFG_PTR.optimizeDiskIO) init_privilege_escalation();
        
        if (CFG_PTR.cpuGpuBoost80 || CFG_PTR.ios27Scheduler || CFG_PTR.ramBoost70) {
            BoostApplyUnifiedPerformance();
        }
        
        if (CFG_PTR.godModeForce120Hz || CFG_PTR.disableFrameThrottling || CFG_PTR.spoofModel) {
            %init(FramePacingEngine);
        }
        if (CFG_PTR.disableThermal || CFG_PTR.smartThermalManagement) {
            %init(ThermalBypassEngine);
        }
        if (CFG_PTR.godModeMetalOverclock || CFG_PTR.gpuSafeOverclock || CFG_PTR.gameStutterFix) {
            %init(GPUEngine);
        }
        if (CFG_PTR.aggressiveRAM || CFG_PTR.killBgApps || CFG_PTR.turboAppLaunch ||
            CFG_PTR.ramBoost70 || CFG_PTR.backgroundPurgeOnExit) {
            %init(MemoryEngine);
        }
        if (CFG_PTR.enableAIAcceleration || CFG_PTR.touchSamplingBoost ||
            CFG_PTR.deepImageProcessing || CFG_PTR.smoothFeelEngine) {
            %init(UIEngine);
        }
        if (CFG_PTR.batterySaverMax || CFG_PTR.lowPowerScheduler) {
            %init(BatteryEngine);
        }
        if (CFG_PTR.blockAnalytics || CFG_PTR.deepSleepOptimization || CFG_PTR.safeSpoofGraphics) {
            %init(SystemHooks);
        }
        
        BoostInjectEnvironmentVariables();
        
        PMPrepareRuntime();
        if (!PMIsUsableProcess()) PMRuntimeReady = NO;
    }
}
