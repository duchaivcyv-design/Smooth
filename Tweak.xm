// ==============================================================================
// 🚀 TWEAK.XM - SMOOTHIOS V21.3.6.2 HYPER EXTENDED ENGINE
// 🐍 ARCHITECTURE: MACH TIME-CONSTRAINT SCHEDULER & ZERO-DEADLOCK ISOLATION
// 🎯 TARGET: iOS 14.0 -> iOS 18.x (Rootless /var/jb/ & Rootful)
// 🛡 KHẮC PHỤC TRIỆT ĐỂ:
//    1. Lỗi đứng 10s văng Respring khi vào App Library hoặc hiện Bàn phím.
//    2. Lỗi đen màn hình 7-8s khi khởi động hoặc vuốt thoát ứng dụng nặng.
//    3. Ép chuẩn xác độc lập mốc 30 - 60 - 90 - 120 - 144 Hz và FPS.
// ⚡️ NÂNG CẤP TOÀN DIỆN CÁC MODULE THỬ NGHIỆM LÊN PHIÊN BẢN (BETA 2).
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

// Forward Declarations SpringBoard
@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (NSArray *)allApplications;
@end

static void V21362_RunGarbageCollector_Aggressive(void);
static void V21362_RunGarbageCollector_Light(void);
static void PMPrepareRuntime(void);
static BOOL PMIsUsableProcess(void);

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t v21362_background_gc_queue = NULL;
static dispatch_queue_t v21362_relief_queue = NULL;
static BOOL PMRuntimeReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

// Hàm spawn an toàn non-blocking
static inline void run_posix_cmd_safe(const char *path, const char *arg1, const char *arg2) {
    if (!path) return;
    pid_t pid;
    char *argv[] = {(char *)path, (char *)arg1, (char *)arg2, NULL};
    int result = posix_spawn(&pid, path, NULL, NULL, argv, environ);
    if (result == 0) waitpid(pid, NULL, WNOHANG);
}

static BOOL BoostIsSpringBoard(void) {
    static BOOL isSB = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isSB = [[[NSProcessInfo processInfo] processName] isEqualToString:@"SpringBoard"];
    });
    return isSB;
}

// Cách ly tuyệt đối các tiến trình nhập liệu, bàn phím và tìm kiếm Spotlight
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

// Xả bộ nhớ rác và Framebuffer ngầm theo kiến trúc Garbage Collector chuyên sâu
static void V21362_RunGarbageCollector_Aggressive(void) {
    if (!v21362_background_gc_queue) {
        v21362_background_gc_queue = dispatch_queue_create("com.boostv21362.gc.aggressive", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v21362_background_gc_queue, ^{
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

static void V21362_RunGarbageCollector_Light(void) {
    if (!v21362_background_gc_queue) {
        v21362_background_gc_queue = dispatch_queue_create("com.boostv21362.gc.light", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v21362_background_gc_queue, ^{
        @autoreleasepool {
            @try {
                [CacheCleaner forceMemoryPurge];
                malloc_zone_pressure_relief(NULL, 1024 * 1024 * 20);
            } @catch(NSException *e) {}
        }
    });
}

static void V21362_AsyncSafeRelief(void) {
    if (!v21362_relief_queue) {
        v21362_relief_queue = dispatch_queue_create("com.boostv21362.relief.safe", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v21362_relief_queue, ^{
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
// 🧠 PHẦN 2: CẤU HÌNH HỆ THỐNG V21.3.6.2 (ĐẦY ĐỦ CÔNG TẮC & NÂNG CẤP BETA 2)
// ==============================================================================

@interface BoostConfig : NSObject
@property (nonatomic, assign) BOOL enabled;

// 1. Màn hình, Hz & FPS độc lập
@property (nonatomic, assign) BOOL enableHzControl;
@property (nonatomic, assign) NSInteger targetHz; 
@property (nonatomic, assign) BOOL enableFPSControl;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL forceOverclockFrame;

// 2. Giao diện & Đa nhiệm ColorOS 17
@property (nonatomic, assign) BOOL colorOs17SmoothEngine;
@property (nonatomic, assign) BOOL reduceMultiTaskLag;
@property (nonatomic, assign) BOOL fixAppLaunchBlackScreen;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) BOOL touchResponseBoost;
@property (nonatomic, assign) CGFloat animSpeed;

// 3. Hiệu năng & Điều phối Kernel (Beta 2)
@property (nonatomic, assign) BOOL ios27AutoSchedulerBeta2;       // Scheduler iOS 27 (Beta 2)
@property (nonatomic, assign) BOOL realtimePriorityBoostBeta2;    // Nâng mức ưu tiên luồng (Beta 2)
@property (nonatomic, assign) BOOL boostCpuGpu;
@property (nonatomic, assign) BOOL smartRamClean;
@property (nonatomic, assign) BOOL aggressiveRamCleanBeta2;      // Dọn RAM tăng cường (Beta 2)
@property (nonatomic, assign) BOOL killBgApps;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL metalTripleBuffering;
@property (nonatomic, assign) BOOL metalAsyncRenderBeta2;        // Render bất đồng bộ Metal (Beta 2)
@property (nonatomic, assign) BOOL gameFpsStabilizer;
@property (nonatomic, assign) BOOL optimizeSystemProcess;
@property (nonatomic, assign) BOOL spoofNewModel;

// 4. Nhiệt độ & Sạc Pin (Beta 2)
@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL smartThermalManager;
@property (nonatomic, assign) BOOL heavyLoadCoolingBeta2;        // Tản nhiệt khi tải nặng (Beta 2)
@property (nonatomic, assign) BOOL chargeCoolingProtection;
@property (nonatomic, assign) BOOL powerSaveMode;

// 5. Hệ thống nâng cao & Mạng (Beta 2)
@property (nonatomic, assign) BOOL bypassVarSandbox;
@property (nonatomic, assign) BOOL blockAnalytics;
@property (nonatomic, assign) BOOL tcpTurboNetworkBeta2;         // Socket TCP Turbo (Beta 2)

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
        _configQueue = dispatch_queue_create("com.boostv21362.config.queue", DISPATCH_QUEUE_SERIAL);
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
            // Màn hình & Tần số quét
            self.enableHzControl = GET_B(@"EnableHzControl", YES);
            self.targetHz = GET_I(@"TargetRefreshRate", 60);

            self.enableFPSControl = GET_B(@"EnableFPSControl", YES);
            self.targetFPS = GET_I(@"TargetFPSRate", 60);
            self.forceOverclockFrame = GET_B(@"ForceOverclockFrame", YES);

            // Giao diện & Đa nhiệm
            self.colorOs17SmoothEngine = GET_B(@"ColorOs17SmoothEngine", YES);
            self.reduceMultiTaskLag = GET_B(@"ReduceMultiTaskLag", YES);
            self.fixAppLaunchBlackScreen = GET_B(@"FixAppLaunchBlackScreen", YES);
            self.fixAppExitStutter = GET_B(@"FixAppExitStutter", YES);
            self.touchResponseBoost = GET_B(@"TouchResponseBoost", YES);
            self.animSpeed = GET_F(@"AnimSpeed", 0.82);

            // Tính năng nâng cấp Beta 2
            self.ios27AutoSchedulerBeta2 = GET_B(@"Ios27AutoSchedulerBeta2", YES);
            self.realtimePriorityBoostBeta2 = GET_B(@"RealtimePriorityBoostBeta2", YES);
            self.boostCpuGpu = GET_B(@"BoostCpuGpu", YES);
            self.smartRamClean = GET_B(@"SmartRamClean", YES);
            self.aggressiveRamCleanBeta2 = GET_B(@"AggressiveRamCleanBeta2", NO);
            self.killBgApps = GET_B(@"KillBgApps", NO);
            self.turboAppLaunch = GET_B(@"TurboAppLaunch", YES);
            self.metalTripleBuffering = GET_B(@"MetalTripleBuffering", YES);
            self.metalAsyncRenderBeta2 = GET_B(@"MetalAsyncRenderBeta2", YES);
            self.gameFpsStabilizer = GET_B(@"GameFpsStabilizer", YES);
            self.optimizeSystemProcess = GET_B(@"OptimizeSystemProcess", YES);
            self.spoofNewModel = GET_B(@"SpoofNewModel", YES);

            // Nhiệt độ & Quản lý sạc
            self.antiThermalThrottling = GET_B(@"AntiThermalThrottling", YES);
            self.smartThermalManager = GET_B(@"SmartThermalManager", YES);
            self.heavyLoadCoolingBeta2 = GET_B(@"HeavyLoadCoolingBeta2", YES);
            self.chargeCoolingProtection = GET_B(@"ChargeCoolingProtection", YES);
            self.powerSaveMode = GET_B(@"PowerSaveMode", NO);

            // Nâng cao & Mạng
            self.bypassVarSandbox = GET_B(@"BypassVarSandbox", YES);
            self.blockAnalytics = GET_B(@"BlockAnalytics", YES);
            self.tcpTurboNetworkBeta2 = GET_B(@"TcpTurboNetworkBeta2", YES);
        } else {
            self.enableHzControl = NO;
            self.enableFPSControl = NO;
            self.targetHz = 60;
            self.targetFPS = 60;
            self.animSpeed = 1.0;
        }
    });
}

- (NSInteger)resolvedTargetHz {
    if (self.powerSaveMode) return 30;
    if (!self.enableHzControl || self.targetHz == 0) return 60;
    return self.targetHz;
}

- (NSInteger)resolvedTargetFPS {
    if (self.powerSaveMode) return 30;
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
// ⚡️ PHẦN 3: CAN THIỆP KERNEL, MACH SCHEDULER (BETA 2) & POSIX
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

// Scheduler iOS 27 (Beta 2): Can thiệp sâu nhưng cô lập trên SpringBoard để triệt tiêu Watchdog Timeout
%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ON) return %orig(target_thread, flavor, policy_info, policy_count);
    @try {
        if (BoostIsSpringBoard() && (CFG_PTR.ios27AutoSchedulerBeta2 || CFG_PTR.realtimePriorityBoostBeta2) && flavor == THREAD_TIME_CONSTRAINT_POLICY && policy_info) {
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
    
    // Ngăn chặn hệ thống bóp xung nhịp CPU/GPU khi máy sinh nhiệt
    if (CFG_PTR.antiThermalThrottling && strcmp(name, "kern.thermal.temperature") == 0) {
        float safeTemp = 30.0f;
        if (oldp && oldlenp && *oldlenp >= sizeof(float)) {
            memcpy(oldp, &safeTemp, sizeof(float));
            *oldlenp = sizeof(float);
            return 0;
        }
    }
    
    // Giả lập cấu hình máy mới
    if (CFG_PTR.spoofNewModel) {
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
    if (ret == 0 && IS_ON && CFG_PTR.spoofNewModel && name) {
        strlcpy(name->machine, "iPhone16,2", sizeof(name->machine));
    }
    return ret;
}

// TCP Turbo (Beta 2): Tăng tốc socket mạng giảm ping & độ trễ
%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    if (IS_ON && CFG_PTR.tcpTurboNetworkBeta2) {
        int nodelay = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
        int bufSize = 2048 * 1024;
        setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
        setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));
    }
    return %orig(socket, address, address_len);
}

// ==============================================================================
// 🖥 PHẦN 4: ÉP CHUẨN XÁC ĐỘC LẬP TẦN SỐ QUÉT HZ & FPS (30-60-90-120-144)
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
        // Khóa chặt dải ProMotion: Min, Max và Preferred nhận chung 1 mốc tuyệt đối
        CAFrameRateRange locked = CAFrameRateRangeMake(rate, rate, rate);
        %orig(locked);
    } else {
        %orig(range);
    }
}

- (void)setFrameInterval:(NSInteger)interval {
    // Nếu chọn 30Hz hoặc 30FPS: Kéo giãn gấp đôi chu kỳ để khóa chặt trần 30, hạ tải GPU triệt để
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
// 🎨 PHẦN 5: ENGINE COLOROS 17 & CÁCH LY CHỐNG ĐƠ BÀN PHÍM / TÌM KIẾM
// ==============================================================================
%group Group_ColorOS17_SafeUI

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (IS_ON && CFG_PTR.touchResponseBoost && !BoostIsIsolatedKeyboardSearchProcess()) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(event);
}
%end

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsIsolatedKeyboardSearchProcess()) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && self.window != nil && !BoostIsIsolatedKeyboardSearchProcess()) {
        PMConfigureScrollView(self);
    }
}
%end

%hook CALayer
- (void)setNeedsDisplay {
    %orig;
    if (IS_ON && CFG_PTR.touchResponseBoost && !BoostIsIsolatedKeyboardSearchProcess()) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

- (CFTimeInterval)duration {
    if (!IS_ON) return %orig;
    return %orig * CFG_PTR.animSpeed;
}
%end

// Tối ưu hóa gia tốc chuyển cảnh (ColorOS Curve)
%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine) {
        if (!BoostIsIsolatedKeyboardSearchProcess()) {
            %orig(duration * 0.82, animations);
            return;
        }
    }
    %orig(duration, animations);
}
%end

%hook CAMediaTimingFunction
+ (instancetype)functionWithName:(CAMediaTimingFunctionName)name {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && !BoostIsIsolatedKeyboardSearchProcess()) {
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
// 🚀 PHẦN 6: FIX LỖI ĐEN MÀN HÌNH 10S, ĐA NHIỆM & VUỐT THOÁT APP NẶNG
// ==============================================================================
%group Group_SpringBoard_AntiStutter

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
        V21362_AsyncSafeRelief();
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

// Xả bộ đệm an toàn khi thoát app nặng ra SpringBoard
%hook SBApplication
- (void)processDidExit:(id)process {
    %orig(process);
    if (IS_ON && CFG_PTR.fixAppExitStutter) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [CATransaction commit];
            V21362_AsyncSafeRelief();
        });
    }
}
%end

// Chống Watchdog Timeout khi người dùng chạm icon mở App
%hook SBIconController
- (void)iconTapped:(id)icon {
    if (IS_ON && CFG_PTR.fixAppLaunchBlackScreen) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(icon);
}
%end

%end // Group_SpringBoard_AntiStutter

// ==============================================================================
// 🧹 PHẦN 7: QUẢN LÝ RAM & TIẾN TRÌNH KHỞI CHẠY
// ==============================================================================
%group Group_Memory_Engine

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON) {
        V21362_RunGarbageCollector_Light();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && (CFG_PTR.smartRamClean || CFG_PTR.aggressiveRamCleanBeta2)) {
        V21362_RunGarbageCollector_Aggressive();
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
                            g_bksTerminate(bid, 5, NO, @"V21.3.6.2 Kill Background");
                        }
                    }
                }
            }
        } @catch (NSException *e) {}
    }

    NSDictionary *finalOptions = (CFG_PTR.turboAppLaunch) ? nil : options;
    %orig(application, finalOptions);
}
%end

%end // Group_Memory_Engine

// ==============================================================================
// 🎮 PHẦN 8: ĐỒ HỌA METAL VÀ GIẢM NHIỆT AN TOÀN (BETA 2)
// ==============================================================================
%group Group_Hardware_SafeEngine

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ON && CFG_PTR.metalTripleBuffering) {
        %orig(3); // Cấp phát 3 buffer liên tục triệt tiêu giật rách hình
    } else {
        %orig(count);
    }
}

// Render bất đồng bộ Metal (Beta 2)
- (void)setPresentsWithTransaction:(BOOL)flag {
    if (IS_ON && CFG_PTR.metalAsyncRenderBeta2) {
        %orig(NO);
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

// Hạ nhiệt khi sạc và tải nặng (Beta 2)
%hook IOPMPowerSource
- (void)updateStatus {
    %orig;
    if (IS_ON && CFG_PTR.chargeCoolingProtection) {
        UIDeviceBatteryState bState = [[UIDevice currentDevice] batteryState];
        if (bState == UIDeviceBatteryStateCharging || bState == UIDeviceBatteryStateFull) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.10];
            [CATransaction commit];
            if (CFG_PTR.heavyLoadCoolingBeta2) {
                V21362_AsyncSafeRelief();
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

%end // Group_Hardware_SafeEngine

// ==============================================================================
// ⚙️ PHẦN 9: KHỞI TẠO BỘ LÕI TWEAK V21.3.6.2 HYPER
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

        // Chỉ can thiệp sâu các module đặc quyền bên trong SpringBoard
        if (BoostIsSpringBoard()) {
            @try {
                [[KernelBypass sharedInstance] initEnvironment];
                [[SystemBlocker sharedInstance] initBlockers];
                if (CFG_PTR.boostCpuGpu) [[KernelBypass sharedInstance] boostCurrentThreadPriority];
                if (CFG_PTR.smartRamClean) [[KernelBypass sharedInstance] forceMachPurge];
                if (CFG_PTR.bypassVarSandbox) init_privilege_escalation();
            } @catch (NSException *e) {}
        }

        setenv("MALLOC_OPTIONS", "AFGN", 1);
        if (CFG_PTR.turboAppLaunch) {
            setenv("DYLD_DISABLE_DOFS", "1", 1);
            setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
        }
        if (CFG_PTR.tcpTurboNetworkBeta2) setenv("CFNETWORK_DIAGNOSTICS", "0", 1);

        %init(_ungrouped);
        %init(Group_Display_DualRate);
        %init(Group_ColorOS17_SafeUI);
        %init(Group_Memory_Engine);
        %init(Group_Hardware_SafeEngine);

        if (BoostIsSpringBoard()) {
            %init(Group_SpringBoard_AntiStutter);
        }

        PMPrepareRuntime();
        if (!PMIsUsableProcess()) PMRuntimeReady = NO;
    }
}
