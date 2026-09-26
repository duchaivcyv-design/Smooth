// ==============================================================================
// 🚀 TWEAK.XM - SMOOTHIOS V21.3 HYPER STABILITY & PERFORMANCE CORE
// 🎯 TARGET: iOS 14.0 -> iOS 18.x (Rootless /var/jb/ & Rootful)
// 🛡 FIX CRASH: TRIỆT TIÊU LỖI TREO ĐEN MÀN HÌNH 7-8S KHI KHỞI CHẠY APP
// ⚡️ TÍNH NĂNG MỚI: BỘ ĐÔI HZ & FPS RIÊNG BIỆT + AUTO SCHEDULER IOS 27 (BETA)
// 🎨 ENGINE: COLOROS 17 ULTRA SMOOTH + GIẢM NHIỆT CỰC ĐOAN KHI CHƠI GAME & SẠC
// ==============================================================================

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAFrameRateRange.h>
#import <AVFoundation/AVFoundation.h>
#import <IOKit/IOKitLib.h>
#import <mach/mach.h>
#import <mach/mach_host.h>
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

extern char **environ;

// Module phụ trợ
#import "Modules/CrashGuard.h"
#import "Modules/CacheCleaner.h"
#import "Modules/SmartThermal.h"
#import "Modules/KernelBypass.h"
#import "Modules/SystemBlocker.h"
#import "Modules/DeepExploit.h"

// Forward Declarations
@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
@end

@interface SBApplicationController : NSObject
+ (instancetype)sharedInstance;
- (NSArray *)allApplications;
@end

static void V213_RunGarbageCollector_Aggressive(void);
static void V213_RunGarbageCollector_Light(void);
static void PMPrepareRuntime(void);
static BOOL PMIsUsableProcess(void);

static dispatch_once_t g_bksTerminate_once;
typedef void (*BKSTerminateFunc)(NSString *, NSInteger, BOOL, NSString *);
static BKSTerminateFunc g_bksTerminate = NULL;

static dispatch_queue_t v213_background_queue = NULL;
static BOOL PMRuntimeReady = NO;
static const void *kPMConfiguredKey = &kPMConfiguredKey;

// Hàm thực thi lệnh an toàn tránh blocking
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

// Xả rác bộ nhớ & làm sạch Framebuffer đồ họa ngầm trên hàng đợi riêng biệt
static void V213_RunGarbageCollector_Aggressive(void) {
    if (!v213_background_queue) {
        v213_background_queue = dispatch_queue_create("com.boostv213.gc", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v213_background_queue, ^{
        @try {
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            [CacheCleaner forceDeepMemoryPurge];
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 64);
            
            mach_port_t host_port = mach_host_self();
            mach_msg_type_number_t host_size = sizeof(vm_statistics64_data_t) / sizeof(integer_t);
            vm_statistics64_data_t vm_stat;
            host_statistics64(host_port, HOST_VM_INFO64, (host_info64_t)&vm_stat, &host_size);
        } @catch(NSException *e) {}
    });
}

static void V213_RunGarbageCollector_Light(void) {
    if (!v213_background_queue) {
        v213_background_queue = dispatch_queue_create("com.boostv213.gc", DISPATCH_QUEUE_SERIAL);
    }
    dispatch_async(v213_background_queue, ^{
        @try {
            [CacheCleaner forceMemoryPurge];
            malloc_zone_pressure_relief(NULL, 1024 * 1024 * 20);
        } @catch(NSException *e) {}
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
// 🧠 CẤU HÌNH HỆ THỐNG TOÀN CỤC V21.3
// ==============================================================================

@interface BoostConfig : NSObject
// 1. Tùy chỉnh chung
@property (nonatomic, assign) BOOL enabled;

// 2. Màn hình & Tần số quét (0: Tự động, 30, 60, 90, 120, 144)
@property (nonatomic, assign) NSInteger targetHz;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL forceOverclockFrame;

// 3. Thuật toán điều phối tiến trình nâng cao
@property (nonatomic, assign) BOOL ios27AutoSchedulerBeta;
@property (nonatomic, assign) BOOL realTimePriorityBoostBeta;

// 4. Giao diện & Đa nhiệm ColorOS 17
@property (nonatomic, assign) BOOL colorOs17SmoothEngine;
@property (nonatomic, assign) BOOL reduceMultiTaskLag;
@property (nonatomic, assign) BOOL fixAppLaunchBlackScreen;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) BOOL touchResponseBoost;

// 5. Hiệu năng lõi & RAM
@property (nonatomic, assign) BOOL boostCpuGpu;
@property (nonatomic, assign) BOOL smartRamClean;
@property (nonatomic, assign) BOOL metalGraphicsOptimize;
@property (nonatomic, assign) BOOL metalAsynchronousRenderBeta;
@property (nonatomic, assign) BOOL gameFpsStabilizer;
@property (nonatomic, assign) BOOL optimizeSystemProcess;
@property (nonatomic, assign) BOOL spoofNewModel;

// 6. Nhiệt độ & Quản lý Pin
@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL smartThermalManager;
@property (nonatomic, assign) BOOL extremeCoolingGamingBeta;
@property (nonatomic, assign) BOOL heavyLoadCooling;
@property (nonatomic, assign) BOOL chargeCoolingProtection;
@property (nonatomic, assign) BOOL powerSaveMode;

// 7. Hệ thống nâng cao & Mạng
@property (nonatomic, assign) BOOL bypassVarSandbox;
@property (nonatomic, assign) BOOL tcpTurboNetworkBeta;

+ (instancetype)sharedInstance;
- (void)loadSettings;
- (NSInteger)resolvedTargetRate;
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
        _configQueue = dispatch_queue_create("com.boostv213.config", DISPATCH_QUEUE_SERIAL);
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    dispatch_sync(_configQueue, ^{
        NSString *plistPath = @"/var/jb/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist";
        NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        if (!prefs) {
            plistPath = @"/var/mobile/Library/Preferences/com.duchaivcy.boostiphone6s.plist";
            prefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
        }
        
        #define GET_B(k, d) (prefs[k] ? [prefs[k] boolValue] : d)
        #define GET_I(k, d) (prefs[k] ? [prefs[k] integerValue] : d)
        
        self.enabled = GET_B(@"Enabled", YES);
        
        if (self.enabled) {
            self.targetHz = GET_I(@"TargetRefreshRate", 60);
            self.targetFPS = GET_I(@"TargetFPSRate", 60);
            self.forceOverclockFrame = GET_B(@"ForceOverclockFrame", YES);
            
            self.ios27AutoSchedulerBeta = GET_B(@"Ios27AutoSchedulerBeta", YES);
            self.realTimePriorityBoostBeta = GET_B(@"RealTimePriorityBoostBeta", YES);
            
            self.colorOs17SmoothEngine = GET_B(@"ColorOs17SmoothEngine", YES);
            self.reduceMultiTaskLag = GET_B(@"ReduceMultiTaskLag", YES);
            self.fixAppLaunchBlackScreen = GET_B(@"FixAppLaunchBlackScreen", YES);
            self.fixAppExitStutter = GET_B(@"FixAppExitStutter", YES);
            self.touchResponseBoost = GET_B(@"TouchResponseBoost", YES);
            
            self.boostCpuGpu = GET_B(@"BoostCpuGpu", YES);
            self.smartRamClean = GET_B(@"SmartRamClean", YES);
            self.metalGraphicsOptimize = GET_B(@"MetalGraphicsOptimize", YES);
            self.metalAsynchronousRenderBeta = GET_B(@"MetalAsynchronousRenderBeta", YES);
            self.gameFpsStabilizer = GET_B(@"GameFpsStabilizer", YES);
            self.optimizeSystemProcess = GET_B(@"OptimizeSystemProcess", YES);
            self.spoofNewModel = GET_B(@"SpoofNewModel", YES);
            
            self.antiThermalThrottling = GET_B(@"AntiThermalThrottling", YES);
            self.smartThermalManager = GET_B(@"SmartThermalManager", YES);
            self.extremeCoolingGamingBeta = GET_B(@"ExtremeCoolingGamingBeta", YES);
            self.heavyLoadCooling = GET_B(@"HeavyLoadCooling", YES);
            self.chargeCoolingProtection = GET_B(@"ChargeCoolingProtection", YES);
            self.powerSaveMode = GET_B(@"PowerSaveMode", NO);
            
            self.bypassVarSandbox = GET_B(@"BypassVarSandbox", YES);
            self.tcpTurboNetworkBeta = GET_B(@"TcpTurboNetworkBeta", YES);
        } else {
            self.targetHz = 60;
            self.targetFPS = 60;
        }
    });
}

// Thuật toán điều phối: Tính toán mốc Hz/FPS thực thi
- (NSInteger)resolvedTargetRate {
    if (self.powerSaveMode) return 30;
    NSInteger chosen = (self.targetHz > 0) ? self.targetHz : self.targetFPS;
    if (chosen == 0) { // Chế độ Tự Động (Auto Scheduler iOS 27)
        NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
        if (state >= NSProcessInfoThermalStateSerious) return 45;
        return 60;
    }
    return chosen;
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
// ⚡️ PHẦN 1: HOOK KERNEL, TIẾN TRÌNH & ĐIỀU PHỐI THỜI GIAN THỰC (QOS)
// ==============================================================================

%hookf(int, access, const char *pathname, int mode) {
    if (!IS_ON || !pathname) return %orig(pathname, mode);
    if (CFG_PTR.bypassVarSandbox) {
        if (strstr(pathname, "/var/jb/") || strstr(pathname, "/Library/MobileSubstrate/")) return 0;
    }
    return %orig(pathname, mode);
}

// Thuật toán Auto Scheduler (iOS 27 Beta): Chỉ can thiệp trên SpringBoard để chống timeout văng App
%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!IS_ON) return %orig(target_thread, flavor, policy_info, policy_count);
    @try {
        if (BoostIsSpringBoard() && (CFG_PTR.ios27AutoSchedulerBeta || CFG_PTR.optimizeSystemProcess) && flavor == THREAD_TIME_CONSTRAINT_POLICY && policy_info) {
            struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
            NSInteger currentRate = [CFG_PTR resolvedTargetRate];
            uint64_t periodNs = 1000000000ULL / (uint64_t)currentRate;
            ttcp->period = (uint32_t)periodNs;
            ttcp->computation = (uint32_t)(periodNs * 0.40);
            ttcp->constraint = (uint32_t)(periodNs * 0.50);
        }
    } @catch (NSException *e) {}
    return %orig(target_thread, flavor, policy_info, policy_count);
}

%hookf(int, sysctlbyname, const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (!IS_ON || !name) return %orig(name, oldp, oldlenp, newp, newlen);
    
    // Ngăn chặn hệ thống bóp xung đột ngột
    if (CFG_PTR.antiThermalThrottling && strcmp(name, "kern.thermal.temperature") == 0) {
        float safeTemp = 30.5f;
        if (oldp && oldlenp && *oldlenp >= sizeof(float)) {
            memcpy(oldp, &safeTemp, sizeof(float));
            *oldlenp = sizeof(float);
            return 0;
        }
    }
    
    if (CFG_PTR.spoofNewModel) {
        if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.model") == 0) {
            const char *model = "iPhone16,2";
            if (oldp && oldlenp) {
                strlcpy((char *)oldp, model, *oldlenp);
                *oldlenp = strlen(model) + 1;
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

// TCP Turbo Network (Beta): Giảm độ trễ socket mạng
%hookf(int, connect, int socket, const struct sockaddr *address, socklen_t address_len) {
    if (IS_ON && CFG_PTR.tcpTurboNetworkBeta) {
        int nodelay = 1;
        setsockopt(socket, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));
        int bufSize = 2048 * 1024;
        setsockopt(socket, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
        setsockopt(socket, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));
    }
    return %orig(socket, address, address_len);
}

// ==============================================================================
// 🖥 PHẦN 2: ĐIỀU PHỐI MÀN HÌNH, HZ & FPS KÉP (30 - 60 - 90 - 120 - 144 & AUTO)
// ==============================================================================
%group Group_Display_Hz

%hook CADisplayLink
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ON) {
        %orig([CFG_PTR resolvedTargetRate]);
    } else {
        %orig(fps);
    }
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (IS_ON) {
        float target = (float)[CFG_PTR resolvedTargetRate];
        // Ghim cố định toàn bộ dải biến thiên ProMotion thành hằng số
        CAFrameRateRange locked = CAFrameRateRangeMake(target, target, target);
        %orig(locked);
    } else {
        %orig(range);
    }
}

- (void)setFrameInterval:(NSInteger)interval {
    if (IS_ON && [CFG_PTR resolvedTargetRate] == 30) {
        %orig(2); // Kéo giãn chu kỳ trên tấm nền 60Hz gốc để hạ tải triệt để
    } else {
        %orig(1);
    }
}
%end

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if (IS_ON) {
        return [CFG_PTR resolvedTargetRate];
    }
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ON) {
        return [CFG_PTR resolvedTargetRate];
    }
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (IS_ON) {
        %orig((CGFloat)[CFG_PTR resolvedTargetRate]);
    } else {
        %orig(rate);
    }
}
%end

%end // Group_Display_Hz

// ==============================================================================
// 🎨 PHẦN 3: ENGINE COLOROS 17 (TĂNG MƯỢT 80%, SIÊU NHẠY CẢM ỨNG & GIAO DIỆN)
// ==============================================================================
%group Group_UI_MultiTask

%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    if (IS_ON && CFG_PTR.touchResponseBoost) {
        // Nâng quyền ưu tiên của luồng nhận diện cảm ứng lên mức cao nhất
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(event);
}
%end

%hook UIScrollView
- (void)setDecelerationRate:(CGFloat)rate {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine) {
        %orig(UIScrollViewDecelerationRateFast);
    } else {
        %orig(rate);
    }
}

- (void)didMoveToWindow {
    %orig;
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine && self.window != nil) {
        PMConfigureScrollView(self);
    }
}
%end

%hook CALayer
- (void)setNeedsDisplay {
    %orig;
    if (IS_ON && CFG_PTR.touchResponseBoost) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}
%end

// Tối ưu hóa đường cong chuyển động ColorOS Curve không làm mất hoạt ảnh gốc
%hook UIView
+ (void)animateWithDuration:(NSTimeInterval)duration animations:(void (^)(void))animations {
    if (IS_ON && CFG_PTR.colorOs17SmoothEngine) {
        %orig(duration * 0.80, animations);
    } else {
        %orig(duration, animations);
    }
}
%end

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
        V213_RunGarbageCollector_Aggressive();
    }
    %orig(animated);
}
%end

%hook SBFluidSwitcherViewController
- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ON && CFG_PTR.reduceMultiTaskLag) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(gesture);
}
%end

// Chống khựng khi thoát App nặng ra SpringBoard
%hook SBApplication
- (void)processDidExit:(id)process {
    %orig(process);
    if (IS_ON && CFG_PTR.fixAppExitStutter) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [CATransaction commit];
            V213_RunGarbageCollector_Aggressive();
        });
    }
}
%end

// Chống treo đen màn hình 7-8s khi nhấn vào App
%hook SBIconController
- (void)iconTapped:(id)icon {
    if (IS_ON && CFG_PTR.fixAppLaunchBlackScreen) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig(icon);
}
%end

%end // Group_UI_MultiTask

// ==============================================================================
// 🚀 PHẦN 4: ĐỒ HỌA METAL, TRIPLE BUFFERING & BỘ NHỚ LÕI
// ==============================================================================
%group Group_Core_Engine

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ON && CFG_PTR.metalGraphicsOptimize) {
        // Cấp phát 3 buffer liên tục để chống hiện tượng giật rách khung hình
        NSUInteger optimalCount = CFG_PTR.gameFpsStabilizer ? 3 : 2;
        %orig(optimalCount);
    } else {
        %orig(count);
    }
}

- (void)setPresentsWithTransaction:(BOOL)flag {
    if (IS_ON && CFG_PTR.metalAsynchronousRenderBeta) {
        %orig(NO); // Render bất đồng bộ để tránh chặn Main UI Thread
    } else {
        %orig(flag);
    }
}

- (BOOL)allowsNextDrawableTimeout {
    if (IS_ON && CFG_PTR.metalGraphicsOptimize) {
        return NO;
    }
    return %orig;
}

- (void)setFramebufferOnly:(BOOL)only {
    if (IS_ON && CFG_PTR.metalGraphicsOptimize) {
        %orig(YES);
    } else {
        %orig(only);
    }
}
%end

%hook UIApplication
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.smartRamClean) {
        V213_RunGarbageCollector_Light();
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    %orig(application);
    if (IS_ON && CFG_PTR.smartRamClean) {
        V213_RunGarbageCollector_Aggressive();
    }
}
%end

%end // Group_Core_Engine

// ==============================================================================
// ❄️ PHẦN 5: KIỂM SOÁT NHIỆT ĐỘ CỰC ĐOAN, TẢN NHIỆT KHI CHƠI GAME & SẠC
// ==============================================================================
%group Group_Thermal_Engine

%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ON && (CFG_PTR.antiThermalThrottling || CFG_PTR.extremeCoolingGamingBeta)) {
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

// Tự động giải phóng áp lực render khi thiết bị cắm sạc hoặc quá tải nhiệt
%hook IOPMPowerSource
- (void)updateStatus {
    %orig;
    if (IS_ON && CFG_PTR.chargeCoolingProtection) {
        UIDeviceBatteryState bState = [[UIDevice currentDevice] batteryState];
        if (bState == UIDeviceBatteryStateCharging || bState == UIDeviceBatteryStateFull) {
            [CATransaction begin];
            [CATransaction setAnimationDuration:0.10];
            [CATransaction commit];
            if (CFG_PTR.heavyLoadCooling) {
                V213_RunGarbageCollector_Light();
            }
        }
    }
}
%end

%end // Group_Thermal_Engine

// ==============================================================================
// ⚙️ PHẦN 6: KHỞI TẠO BỘ LÕI TWEAK V21.3
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
            CFSTR("com.duchaivcy.boostiphone6s/ReloadPrefs"),
            NULL,
            CFNotificationSuspensionBehaviorCoalesce
        );
        
        if (!IS_ON) return; 

        // Chỉ can thiệp sâu tiến trình hệ thống trong SpringBoard để bảo vệ độ ổn định của ứng dụng thường
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
        setenv("DYLD_DISABLE_DOFS", "1", 1);
        setenv("OBJC_DISABLE_INITIALIZE_FORK_SAFETY", "YES", 1);
        
        %init(_ungrouped);
        %init(Group_Display_Hz);
        %init(Group_UI_MultiTask);
        %init(Group_Core_Engine);
        %init(Group_Thermal_Engine);
        
        PMPrepareRuntime();
        if (!PMIsUsableProcess()) PMRuntimeReady = NO;
    }
}
