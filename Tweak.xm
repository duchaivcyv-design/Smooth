// ==============================================================================
// 🚀 TWEAK.XM - SMOOTHIOS V21.4.4 HYPER-HANDSHAKE & ANTI-CRASH CORE
// 🎯 TARGET: iOS 14.0 -> iOS 18.x (Rootless /var/jb/ & Rootful)
// 🛡 BẢO TOÀN 100% TÍNH NĂNG - ĐẠI PHẪU THUẬT LỖI CRASH VĂNG VÀ ĐEN MÀN HÌNH
// ⚡️ RENDER HANDSHAKE PIPELINE + TRIPLE BUFFERING + OVERCLOCK 144HZ + FAKE A18 PRO
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
#import <netinet/in.h>
#import <netinet/tcp.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <CommonCrypto/CommonDigest.h>

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
@end

static void V2144_RunGarbageCollector_Aggressive(void);
static void V2144_RunGarbageCollector_Light(void);
static void V2144_AsyncMemoryPurgeSafe(void);
static void PMPrepareRuntime(void);
static BOOL PMIsUsableProcess(void);

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t v2144_bg_gc_queue = NULL;
static dispatch_queue_t v2144_async_io_queue = NULL;
static dispatch_queue_t v2144_render_sync_queue = NULL;

static BOOL PMRuntimeReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;
static const void *kMetalHandshakeKey = &kMetalHandshakeKey;
static const void *kMetalFrameCountKey = &kMetalFrameCountKey;

// Khởi chạy an toàn không treo luồng
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
        isPrefs = [name isEqualToString:@"Preferences"] || [name isEqualToString:@"Settings"];
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
// 🧹 BỘ THU HỒI BỘ NHỚ VÀ FRAMEBUFFER ĐA TẦNG V21.4.4
// ==============================================================================
static void V2144_RunGarbageCollector_Aggressive(void) {
    if (!v2144_bg_gc_queue) {
        v2144_bg_gc_queue = dispatch_queue_create("com.boostv2144.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2144_bg_gc_queue, ^{
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

static void V2144_RunGarbageCollector_Light(void) {
    if (!v2144_bg_gc_queue) {
        v2144_bg_gc_queue = dispatch_queue_create("com.boostv2144.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2144_bg_gc_queue, ^{
        @autoreleasepool {
            @try {
                [CacheCleaner forceMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 20);
            } @catch(NSException *e) {}
        }
    });
}

static void V2144_AsyncMemoryPurgeSafe(void) {
    if (!v2144_async_io_queue) {
        v2144_async_io_queue = dispatch_queue_create("com.boostv2144.async.purge", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v2144_async_io_queue, ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 16);
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
// 🧠 PHẦN 1: CẤU HÌNH HỆ THỐNG V21.4.4 (NÂNG CẤP NHÃN BETA 3.2)
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

// Nhóm 3: Hiệu năng Lõi, Auto Fake iPhone 16 Pro & Điều phối (BETA 3.2)
@property (nonatomic, assign) BOOL ios27AutoSchedulerBeta32;      
@property (nonatomic, assign) BOOL realtimePriorityBoostBeta32;   
@property (nonatomic, assign) BOOL boostCpuGpu;
@property (nonatomic, assign) BOOL smartRamClean;
@property (nonatomic, assign) BOOL aggressiveRamCleanBeta32;     
@property (nonatomic, assign) BOOL killBgApps;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL metalTripleBuffering;
@property (nonatomic, assign) BOOL metalHandshakePipeline;        
@property (nonatomic, assign) BOOL gameFpsStabilizer;
@property (nonatomic, assign) BOOL optimizeSystemProcess;
@property (nonatomic, assign) BOOL autoSpoofNewDevice;

// Nhóm 4: Nhiệt độ Cực Đoan & Sạc Pin (BETA 3.2)
@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL smartThermalManager;
@property (nonatomic, assign) BOOL heavyLoadCoolingBeta32;       
@property (nonatomic, assign) BOOL chargeCoolingProtection;
@property (nonatomic, assign) BOOL powerSaveMode;

// Nhóm 5: Hệ thống Nâng Cao & Mạng (BETA 3.2)
@property (nonatomic, assign) BOOL bypassVarSandbox;
@property (nonatomic, assign) BOOL blockAnalytics;
@property (nonatomic, assign) BOOL tcpTurboNetworkBeta32;        

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
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _configQueue = dispatch_queue_create("com.boostv2144.config.queue", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        NSString *plistPath = PREF_PATH;
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        if (!prefs) {
            plistPath = FALLBACK_PREF_PATH;
            prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
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

            // BETA 3.2
            self.ios27AutoSchedulerBeta32 = GET_B(@"Ios27AutoSchedulerBeta32", YES);
            self.realtimePriorityBoostBeta32 = GET_B(@"RealtimePriorityBoostBeta32", YES);
            self.boostCpuGpu = GET_B(@"BoostCpuGpu", YES);
            self.smartRamClean = GET_B(@"SmartRamClean", YES);
            self.aggressiveRamCleanBeta32 = GET_B(@"AggressiveRamCleanBeta32", NO);
            self.killBgApps = GET_B(@"KillBgApps", NO);
            self.turboAppLaunch = GET_B(@"TurboAppLaunch", YES);
            self.metalTripleBuffering = GET_B(@"MetalTripleBuffering", YES);
            self.metalHandshakePipeline = GET_B(@"MetalHandshakePipeline", YES);
            self.gameFpsStabilizer = GET_B(@"GameFpsStabilizer", YES);
            self.optimizeSystemProcess = GET_B(@"OptimizeSystemProcess", YES);
            self.autoSpoofNewDevice = GET_B(@"AutoSpoofNewDevice", YES);

            self.antiThermalThrottling = GET_B(@"AntiThermalThrottling", YES);
            self.smartThermalManager = GET_B(@"SmartThermalManager", YES);
            self.heavyLoadCoolingBeta32 = GET_B(@"HeavyLoadCoolingBeta32", YES);
            self.chargeCoolingProtection = GET_B(@"ChargeCoolingProtection", YES);
            self.powerSaveMode = GET_B(@"PowerSaveMode", NO);

            self.bypassVarSandbox = GET_B(@"BypassVarSandbox", YES);
            self.blockAnalytics = GET_B(@"BlockAnalytics", YES);
            self.tcpTurboNetworkBeta32 = GET_B(@"TcpTurboNetworkBeta32", YES);
        } else {
            self.enableHzControl = NO;
            self.enableFPSControl = NO;
            self.targetHz = 60;
            self.targetFPS = 60;
            self.forceOverclock144Hz = NO;
            self.animSpeed = 1.0;
        }
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
// ⚡️ PHẦN 2: AUTO FAKE IPHONE 16 PRO (A18 PRO) & SCHEDULER BETA 3.2
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
        if (BoostIsSpringBoard() && (CFG_PTR.ios27AutoSchedulerBeta32 || CFG_PTR.realtimePriorityBoostBeta32) && flavor == THREAD_TIME_CONSTRAINT_POLICY && policy_info) {
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
        float safeTemp = 30.0f;
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
    if (IS_ON && CFG_PTR.tcpTurboNetworkBeta32) {
        int nodelay = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
        int bufSize = 2048 * 1024;
        setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
        setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));
    }
    return %orig(socket, address, address_len);
}

// ==============================================================================
// 🖥 PHẦN 3: ÉP TRẦN HZ & FPS ĐỘC LẬP (30 - 60 - 90 - 120 - 144)
// ==============================================================================
%group Group_Display_DualRate

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
        %orig(2);
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
%end

%end // Group_Display_DualRate

// ==============================================================================
// 🎮 PHẦN 4: CƠ CHẾ RENDER HANDSHAKE PIPELINE (THÔNG LUỒNG KHÔNG ĐEN MÀN)
// ==============================================================================
%group Group_Metal_Handshake_Engine

%hook CAMetalLayer

- (id)init {
    self = %orig;
    if (self && IS_ON && CFG_PTR.metalTripleBuffering) {
        if (BoostIsSpringBoard()) {
            [self setMaximumDrawableCount:3];
        } else {
            objc_setAssociatedObject(self, kMetalHandshakeKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, kMetalFrameCountKey, @(0), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return self;
}

- (id<CAMetalDrawable>)nextDrawable {
    if (!IS_ON || !CFG_PTR.metalHandshakePipeline || BoostIsSpringBoard()) {
        return %orig;
    }

    NSNumber *handshakeDone = objc_getAssociatedObject(self, kMetalHandshakeKey);
    NSNumber *frameCount = objc_getAssociatedObject(self, kMetalFrameCountKey);
    NSInteger currentCount = frameCount ? [frameCount integerValue] : 0;

    // FRAME 0 -> 2: Chạy handshake nhả luồng an toàn cho UIKit dựng Splash Window
    if (!handshakeDone || ![handshakeDone boolValue] || currentCount < 3) {
        id<CAMetalDrawable> firstDrawable = %orig;
        if (firstDrawable) {
            currentCount++;
            objc_setAssociatedObject(self, kMetalFrameCountKey, @(currentCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (currentCount >= 3) {
                objc_setAssociatedObject(self, kMetalHandshakeKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                if (CFG_PTR.metalTripleBuffering) {
                    [self setMaximumDrawableCount:3];
                }
            }
        }
        return firstDrawable;
    }

    return %orig;
}

- (void)setPresentsWithTransaction:(BOOL)flag {
    if (IS_ON && CFG_PTR.metalHandshakePipeline) {
        if (BoostIsSpringBoard()) {
            %orig(NO);
        } else {
            NSNumber *handshakeDone = objc_getAssociatedObject(self, kMetalHandshakeKey);
            if (!handshakeDone || ![handshakeDone boolValue]) {
                %orig(flag);
            } else {
                %orig(NO);
            }
        }
    } else {
        %orig(flag);
    }
}

- (BOOL)allowsNextDrawableTimeout {
    if (IS_ON && CFG_PTR.metalTripleBuffering) {
        return NO;
    }
    return %orig;
}

- (void)setFramebufferOnly:(BOOL)only {
    if (IS_ON && CFG_PTR.metalTripleBuffering) {
        %orig(YES);
    } else {
        %orig(only);
    }
}

%end

%end // Group_Metal_Handshake_Engine

// ==============================================================================
// 🎨 PHẦN 5: GIAO DIỆN COLOROS 17 & CÁCH LY CHỐNG ĐƠ BÀN PHÍM/SETTINGS
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
// 🚀 PHẦN 6: SPRINGBOARD ENGINE & KIỂM SOÁT NHIỆT ĐỘ CỰC ĐOAN
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
        V2144_AsyncMemoryPurgeSafe();
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
            V2144_AsyncMemoryPurgeSafe();
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
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.10];
            [CATransaction commit];
            if (CFG_PTR.heavyLoadCoolingBeta32) {
                V2144_AsyncMemoryPurgeSafe();
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
// 🧹 PHẦN 7: QUẢN LÝ RAM & THU HỒI TIẾN TRÌNH KHỞI CHẠY
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON) {
        V2144_RunGarbageCollector_Light();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && (CFG_PTR.smartRamClean || CFG_PTR.aggressiveRamCleanBeta32)) {
        V2144_RunGarbageCollector_Aggressive();
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
                            g_bksTerminate(bid, 5, NO, @"V21.4.4 Kill Background");
                        }
                    }
                }
            }
        } @catch (NSException *e) {}
    }

    // Bảo tồn trọn vẹn context options gốc để UIKit không bị đen màn hình
    %orig(application, options);
}
%end

%end // Group_Memory_Engine

// ==============================================================================
// ⚙️ PHẦN 8: KHỞI TẠO BỘ LÕI TWEAK V21.4.4
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

        // Bỏ qua nạp hook hoàn toàn nếu là tiến trình Bàn phím / Spotlight / Search
        if (BoostIsIsolatedKeyboardSearchProcess()) {
            return;
        }

        // BẢO VỆ PREFERENCES: Không inject hook nặng vào Cài đặt để chống văng khi Safe Mode
        if (BoostIsPreferencesApp()) {
            return;
        }

        // Khai thác Kernel chỉ bên trong SpringBoard
        if (BoostIsSpringBoard()) {
            @try {
                [[KernelBypass sharedInstance] initEnvironment];
                [[SystemBlocker sharedInstance] initBlockers];
                if (CFG_PTR.boostCpuGpu) [[KernelBypass sharedInstance] boostCurrentThreadPriority];
                if (CFG_PTR.smartRamClean) [[KernelBypass sharedInstance] forceMachPurge];
                if (CFG_PTR.bypassVarSandbox) init_privilege_escalation();
            } @catch (NSException *e) {}

            %init(Group_SpringBoard_Only);
        }

        setenv("MALLOC_OPTIONS", "AFGN", 1);
        if (CFG_PTR.turboAppLaunch) {
            setenv("DYLD_DISABLE_DOFS", "1", 1);
            setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
        }
        if (CFG_PTR.tcpTurboNetworkBeta32) setenv("CFNETWORK_DIAGNOSTICS", "0", 1);

        %init(_ungrouped);
        %init(Group_Display_DualRate);
        %init(Group_Metal_Handshake_Engine);
        %init(Group_ColorOS17_SafeUI);
        %init(Group_Memory_Engine);

        PMPrepareRuntime();
        if (!PMIsUsableProcess()) PMRuntimeReady = NO;
    }
}
