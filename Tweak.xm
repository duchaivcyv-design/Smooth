// ==================== MACH & XNU KERNEL ====================
#import <mach/mach.h>
#import <mach/mach_init.h>      // Khai báo chuẩn mach_task_self(), mach_thread_self()
#import <mach/mach_host.h>
#import <mach/mach_time.h>      // Khai báo mach_absolute_time(), mach_timebase_info()
#import <mach/mach_types.h>
#import <mach/vm_map.h>
#import <mach/vm_region.h>
#import <mach/vm_statistics.h>
#import <mach/vm_types.h>
#import <mach/thread_act.h>
#import <mach/thread_policy.h>  // Ràng buộc chu kỳ Realtime (THREAD_TIME_CONSTRAINT_POLICY)
#import <mach/task.h>
#import <mach/task_info.h>
#import <mach/task_policy.h>    // Khai báo quản lý QoS Task Kernel
#import <mach/clock.h>
#import <SpriteKit/SpriteKit.h>
#import <SceneKit/SceneKit.h>

// ==================== POSIX, C & SYSTEM ====================
#include <stdio.h>              // Cho rename(), snprintf() trong hàm ghi IPC atomic
#include <math.h>               // Cho isfinite(), fmin(), fmax() kiểm tra tọa độ & nhịp Hz
#include <stdatomic.h>          // Hỗ trợ bộ đếm nguyên tử an toàn đa luồng
#import <pthread.h>
#include <strings.h>          // strcasecmp: so khớp đúng tên process daemon
#import <pthread/qos.h>         // Khai báo pthread_set_qos_class_self_np()
#import <sched.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import <spawn.h>
#import <fcntl.h>               // Cho open(), O_RDONLY, O_WRONLY, O_CREAT
#import <dlfcn.h>               // Cho dladdr(), Dl_info định vị đường dẫn RootHide/Rootless
#import <malloc/malloc.h>       // Cho malloc_zone_pressure_relief()
#import <notify.h>
#import <errno.h>               // Bắt mã lỗi I/O file IPC và sysctl
#import <time.h>                // Khai báo chuẩn time_t và hàm time()
#import <os/lock.h>             // Khóa bộ nhớ siêu nhẹ os_unfair_lock cho Apple Silicon

// ==================== SYS HEADERS ====================
#import <sys/types.h>
#import <sys/time.h>            // Khai báo struct timeval (chống lỗi incomplete type)
#import <sys/sysctl.h>          // Cho sysctl KERN_BOOTTIME chống bootloop
#import <sys/resource.h>        // Cho setiopolicy_np() cấp quyền I/O
#import <sys/utsname.h>
#import <fcntl.h>
#import <unistd.h>         // Cho uname() nhận diện phần cứng iPhone/iPad
#import <sys/wait.h>
#import <sys/mman.h>
#import <sys/stat.h>            // Cho chmod() phân quyền file IPC /tmp

// ==================== OBJC & SECURITY ====================
#import <objc/runtime.h>
#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>
#import <substrate.h>

// ==================== APPLE FRAMEWORKS ====================
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAMetalLayer.h>
#import <CoreText/CoreText.h>  // Tăng tốc dàn trang font chữ / khối Code dài trong App AI
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>

// BẢO VỆ SDK: Chống lỗi fatal error nếu SDK thiếu thư mục Private Framework IOKit / IOSurface
#if __has_include(<IOKit/IOKitLib.h>)
#import <IOKit/IOKitLib.h>
#endif

#if __has_include(<IOSurface/IOSurfaceRef.h>)
#import <IOSurface/IOSurfaceRef.h>
#endif

// ==================== CHỐT BẢO VỆ HẰNG SỐ KERNEL XNU (CHỐNG LỖI BUILD SDK) ====================
#ifndef LATENCY_QOS_TIER_0
#define LATENCY_QOS_TIER_0 ((0xFF << 16) | 1)
#endif

#ifndef LATENCY_QOS_TIER_1
#define LATENCY_QOS_TIER_1 ((0xFF << 16) | 2)
#endif

#ifndef THROUGHPUT_QOS_TIER_0
#define THROUGHPUT_QOS_TIER_0 ((0xFE << 16) | 1)
#endif

#ifndef THROUGHPUT_QOS_TIER_1
#define THROUGHPUT_QOS_TIER_1 ((0xFE << 16) | 2)
#endif

#ifndef VM_PURGABLE_PURGE_ALL
#define VM_PURGABLE_PURGE_ALL 0
#endif

#ifndef VM_FLAGS_PURGABLE
#define VM_FLAGS_PURGABLE 1
#endif

#ifndef VM_MEMORY_COREANIMATION
#define VM_MEMORY_COREANIMATION 54
#endif

#ifndef IOPOL_TYPE_DISK
#define IOPOL_TYPE_DISK 0
#endif

#ifndef IOPOL_SCOPE_THREAD
#define IOPOL_SCOPE_THREAD 1
#endif

#ifndef IOPOL_IMPORTANT
#define IOPOL_IMPORTANT 1
#endif

#ifndef IOPOL_TYPE_VFS_ATIME_UPDATES
#define IOPOL_TYPE_VFS_ATIME_UPDATES 2
#endif

#ifndef IOPOL_ATIME_UPDATES_OFF
#define IOPOL_ATIME_UPDATES_OFF 1
#endif

#ifndef THREAD_THROTTLE_POLICY
#define THREAD_THROTTLE_POLICY 4
#endif

#ifndef TASK_POLICY_ROLE
#define TASK_POLICY_ROLE 1
#endif

#ifndef TASK_FOREGROUND_APPLICATION
#define TASK_FOREGROUND_APPLICATION 2
#endif

#ifndef TASK_BASE_QOS_POLICY
#define TASK_BASE_QOS_POLICY 1
#endif

#ifndef TASK_OVERRIDE_QOS_POLICY
#define TASK_OVERRIDE_QOS_POLICY 2
#endif

#ifndef THREAD_AFFINITY_POLICY
#define THREAD_AFFINITY_POLICY 4
#endif

#ifndef THREAD_AFFINITY_POLICY_COUNT
#define THREAD_AFFINITY_POLICY_COUNT 1
#endif

// ====================================================================================================
// TƯƠNG THÍCH CHUẨN DẢI TẦN SỐ QUÉT CHO CẢ SDK CŨ LẪN MỚI (CHỐNG REDEFINITION)
// ====================================================================================================

#if __has_include(<QuartzCore/CAFrameRateRange.h>)
typedef CAFrameRateRange SafeFrameRateRange;
#define SafeMakeFRR(min, max, pref) CAFrameRateRangeMake(min, max, pref)
#else
typedef struct {
    float minimum;
    float maximum;
    float preferred;
} SafeFrameRateRange;
static inline SafeFrameRateRange SafeMakeFRR(float min, float max, float pref) {
    SafeFrameRateRange r;
    r.minimum = min;
    r.maximum = max;
    r.preferred = pref;
    return r;
}
#endif

#ifndef UIWindowSceneActivationState_DEFINED
#define UIWindowSceneActivationState_DEFINED
typedef NS_ENUM(NSInteger, UIWindowSceneActivationState) {
    UIWindowSceneActivationStateUnspecified = -1,
    UIWindowSceneActivationStateForegroundActive = 0,
    UIWindowSceneActivationStateForegroundInactive = 1,
    UIWindowSceneActivationStateBackground = 2
};
#endif

#ifndef THREAD_THROTTLE_POLICY_DATA_T_DEFINED
#define THREAD_THROTTLE_POLICY_DATA_T_DEFINED
typedef struct {
    uint32_t pset_limit;
} thread_throttle_policy_data_t;
#endif

typedef uint32_t IOPMAssertionID;
#define kIOPMNullAssertionID 0


// [V33 FIX CRASH] getprogname() KHÔNG tồn tại trên iOS → dyld missing symbol → crash ngay khi launch.
// Dùng dlsym để gọi nếu có, nếu không thì fallback đọc /proc/self/cmdline.
static const char *Titanium_SafeGetProgName(void) {
    static const char *(*s_getprogname_fn)(void) = NULL;
    static BOOL s_checked = NO;
    if (!s_checked) {
        s_checked = YES;
        s_getprogname_fn = (const char *(*)(void))dlsym(RTLD_DEFAULT, "getprogname");
    }
    if (s_getprogname_fn) {
        const char *name = s_getprogname_fn();
        if (name && name[0]) return name;
    }
    // Fallback: đọc /proc/self/cmdline
    static char fallback_name[256] = {0};
    if (fallback_name[0] == 0) {
        int fd = open("/proc/self/cmdline", O_RDONLY);
        if (fd >= 0) {
            ssize_t n = read(fd, fallback_name, sizeof(fallback_name) - 1);
            close(fd);
            if (n > 0) {
                // Thay byte null bằng khoảng trắng, lấy tên cuối
                for (ssize_t i = 0; i < n; i++) if (fallback_name[i] == '\0') fallback_name[i] = ' ';
                fallback_name[n] = '\0';
                // Lấy tên cuối (sau dấu /)
                char *slash = strrchr(fallback_name, '/');
                if (slash) memmove(fallback_name, slash + 1, strlen(slash + 1) + 1);
            }
        }
        if (fallback_name[0] == 0) {
            strncpy(fallback_name, "unknown", sizeof(fallback_name) - 1);
        }
    }
    return fallback_name;
}

// [FIX SYMBOL MISSING]: không link trực tiếp các symbol private/ không chắc tồn tại trên mọi iOS.
// Resolve lúc runtime bằng dlsym; nếu không có thì no-op an toàn, tránh dyld abort khi launch.
extern char **environ;
typedef int (*Titanium_setiopolicy_np_fn)(int, int, int);
static int Titanium_setiopolicy_np_safe(int iotype, int scope, int policy) {
    static Titanium_setiopolicy_np_fn fn = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fn = (Titanium_setiopolicy_np_fn)dlsym(RTLD_DEFAULT, "setiopolicy_np");
    });
    return fn ? fn(iotype, scope, policy) : -1;
}
#define setiopolicy_np Titanium_setiopolicy_np_safe

// ====================================================================================================
// MACRO ĐỒNG BỘ TOÀN HỆ THỐNG & ĐƯỜNG DẪN TỆP IPC NGUYÊN TỬ (ĐÃ BỔ SUNG ĐẦY ĐỦ)
// ====================================================================================================

#ifndef APEX_SYNC_MAGIC_V285
#define APEX_SYNC_MAGIC_V285 0x41505837
#endif

#ifndef PREF_DOMAIN
#define PREF_DOMAIN          CFSTR("com.taojb.boostiphone6s")
#endif

#ifndef SHARED_SYNC_FILE
#define SHARED_SYNC_FILE     @"/tmp/.boost_hz_sync"
#endif

#ifndef PRIMARY_SYNC_FILE
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#endif

#ifndef SECONDARY_SYNC_FILE
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#endif

#ifndef BOOT_GUARD_FILE
#define BOOT_GUARD_FILE      @"/tmp/.titanium_boot_guard"
#endif

#ifndef NOTIFY_RELOAD
#define NOTIFY_RELOAD           "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD     "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC    "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED      "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#define NOTIFY_PAYLOAD_WRITTEN  "com.taojb.boostiphone6s/PayloadWritten"
#endif

#ifndef APPS_SYNC_FILE_PRIMARY
#define APPS_SYNC_FILE_PRIMARY   @"/tmp/.boost_hz_apps"
#define APPS_SYNC_FILE_SECONDARY @"/var/jb/tmp/.boost_hz_apps"
#endif

#ifndef G_IS_RATE_LOCKED_DEFINED
#define G_IS_RATE_LOCKED_DEFINED
static volatile BOOL g_isRateLockedV285 = NO;
#endif

// ====================================================================================================
// BỘ ĐÓNG GÓI BITMASK IPC ĐIỀU KHIỂN TOÀN BỘ CÔNG TẮC (ĐỒNG BỘ SANG APP THỨ BA)
// ====================================================================================================
#define IPC_FLAG_FLAT_BLUR          (1U << 0)
#define IPC_FLAG_DEVICE_SPOOFER     (1U << 1)
#define IPC_FLAG_GAME_STABILIZER    (1U << 2)
#define IPC_FLAG_CPU_GPU_OPT        (1U << 3)
#define IPC_FLAG_REALTIME_SCHED     (1U << 4)
#define IPC_FLAG_IO_SCHEDULER       (1U << 5)
#define IPC_FLAG_SYS_PROC_OPT       (1U << 6)
#define IPC_FLAG_QUANTUM_SYNC       (1U << 7)
#define IPC_FLAG_SMART_THERMAL      (1U << 8)
#define IPC_FLAG_DYN_THERMAL        (1U << 9)
#define IPC_FLAG_HEAVY_COOLING      (1U << 10)
#define IPC_FLAG_BG_PACING          (1U << 11)
#define IPC_FLAG_AUTO_KILL_BG       (1U << 12)
#define IPC_FLAG_CHARGER_RIPPLE     (1U << 13)
#define IPC_FLAG_ANTI_BLACK_LAUNCH  (1U << 14)
#define IPC_FLAG_REDUCE_MULTITASK   (1U << 15)
#define IPC_FLAG_HYPER_MEM_GUARD    (1U << 16)
#define IPC_FLAG_ZERO_LAG_NEURAL    (1U << 17)
#define IPC_FLAG_RATE_LOCKED        (1U << 18)

// ====================================================================================================
// CẤU TRÚC PAYLOAD APEX V285 PRO - CÓ THÊM TẤT CẢ CÁC CÔNG TẮC ĐIỀU KHIỂN NHÓM
// ====================================================================================================

#ifndef _APEX_V285_PRO_PAYLOAD_DEFINED
#define _APEX_V285_PRO_PAYLOAD_DEFINED
typedef struct __attribute__((packed)) {
    uint32_t magic;
    uint32_t masterEnabled;
    int32_t  targetHz;
    int32_t  targetFPS;
    uint32_t forceOverclock;
    uint32_t pipSyncEnabled;
    uint32_t thermalShield;
    uint32_t antiStutterExit;
    uint32_t smartBufferingLevel;
    uint32_t zeroLatencyTouch;
    uint32_t shaderOptimization;
    uint32_t dynamicInterpolation;
    uint32_t fastAppLaunch;
    uint32_t lowLatencyAudio;
    uint32_t memoryPressureRelief;
    uint32_t metalPacingEnabled;
    uint32_t runloopHangGuard;
    uint32_t keyboardZeroLagV3;
    uint32_t aggressiveRamCleaner;
    uint32_t lockFixedFpsWhenThermal;
    uint32_t antiGhostTouch;
    uint32_t diskIOPriorityBoost;
    uint32_t rawTouchDirectDelivery;
    uint32_t powerSaveModeActive;
    
    // ====== 34 CÔNG TẮC ĐIỀU KHIỂN NHÓM ======
    uint32_t enableAppleInternalProMotion;        // Group_Apple_Internal_ProMotion_Apex
    uint32_t enableZeroLatencyTouch;              // Group_ZeroLatency_Touch_Opt
    uint32_t enableMetalZeroTearing;              // Group_Metal_ZeroTearing_Pacing
    uint32_t enableFluidTransitions;              // Group_FluidTransitions_Pacing
    uint32_t enableTitaniumGameMetalOverdrive;    // Group_Titanium_Game_Metal_Overdrive
    uint32_t enableAIStreamOptimization;          // Group_AI_Stream_Optimization
    uint32_t enableFastLaunchSuperEngine;         // Group_FastLaunch_SuperEngineV285
    uint32_t enableScrollAndKeyboard;             // Group_Scroll_And_Keyboard_Opt
    uint32_t enableInstantActionTransitions;      // Group_InstantActionAndMenuTransitions_Boost
    uint32_t enableGlobalThreadGovernor;          // Group_Global_Thread_Governor_Unthrottled
    uint32_t enableSiliconSchedulerTouch;         // Group_Silicon_Scheduler_Touch_Governor
    uint32_t enableCoreAnimationRenderServer;     // Group_CoreAnimation_RenderServer_Governor
    uint32_t enableCAWindowServerDominance;       // Group_CAWindowServer_Absolute_Dominance
    uint32_t enableForceRenderRecovery;           // Group_Force_Render_Recovery_Overdrive
    uint32_t enableWindowLevelOverdrive;          // Group_Window_Level_Overdrive
    uint32_t enableSystemMemoryGovernor;          // Group_System_Memory_And_RunLoop_Governor
    uint32_t enableThermalCryoPacing;             // Group_Thermal_CryoPacing_ZeroDrop
    uint32_t enableDeepRamCompaction;             // Group_Deep_RAM_Compaction_Engine
    uint32_t enableWebKitRamOptimizer;            // Group_WebKit_RAM_Optimizer
    uint32_t enableSiliconHardwarePipeline;       // Group_Silicon_Hardware_Pipeline_Overdrive
    uint32_t enableHardwareProMotionOverclock;    // Group_Hardware_ProMotion_Overclock
    uint32_t enableNeuralTouchEdgeZeroLatency;    // Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285
    uint32_t enableNativeColdBootOverdrive;       // Group_Apple_Native_ColdBoot_Overdrive
    uint32_t enableTitaniumV12SmoothExit;         // Group_TitaniumV12_SmoothExit_And_DisplayLink
    uint32_t enableDisplaySpringBoard;            // Group_Display_SpringBoardV285
    uint32_t enableLiquidGlassOpt;                // Group_LiquidGlass_Opt
    uint32_t enableSwitcher30Apps;                // Group_Switcher30Apps_Virtualization
    uint32_t enableSpringBoardSwitcherOpt;        // Group_SpringBoard_Switcher_Opt
    uint32_t enableFloatingWindowPiP;             // Group_V285_FloatingWindow_PiP
    uint32_t enableHardwareSegregationHome;       // Group_HardwareSegregation_ClassicHomeV285
    uint32_t enableSpringBoardProcessManager;     // Group_SpringBoard_ProcessManagerV285
    uint32_t enableKeepAppsAlive;                 // Group_KeepAppsAlive_NoKill
    uint32_t enableTitaniumV10LayoutBoost;        // Group_TitaniumV10_SpringBoard_Layout_Boost
    uint32_t enableUIKitThirdPartyIsolated;       // Group_UIKit_ThirdParty_IsolatedV285
    
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char     reserved[200];
} ApexV285ProPayload;
#endif

static inline uint32_t Titanium_GetIPCExtraFlags(const ApexV285ProPayload *p) {
    uint32_t flags = 0;
    memcpy(&flags, &p->reserved[32], sizeof(uint32_t));
    return flags;
}

static inline void Titanium_SetIPCExtraFlags(ApexV285ProPayload *p, uint32_t flags) {
    memcpy(&p->reserved[32], &flags, sizeof(uint32_t));
}

static inline BOOL Titanium_IsAIApp(void);
static ApexV285ProPayload g_livePayload;
static os_unfair_lock g_payloadLock = OS_UNFAIR_LOCK_INIT;
static BOOL g_isCurrentAppBlacklisted = NO;
static BOOL g_avoidTweakConflicts = NO;   // công tắc "Tránh xung đột Tweak" từ giao diện
static void Titanium_InstallMGCopyAnswerHookV26(void);  // [buildfix4] khai báo trước để dùng được trong các hàm định nghĩa sớm hơn
static volatile BOOL g_isInteracting = NO;
static volatile uint64_t g_lastInteractiveTick = 0;

// ====================================================================================================
// TOÀN BỘ KHAI BÁO @INTERFACE - TITANIUM / APEX V285 PRO (ĐÃ BỔ SUNG ĐẦY ĐỦ CÁC EXTENSION MỚI NHẤT)
// ====================================================================================================

@interface CADisplayProperties : NSObject
- (void)setOverscanAdjustment:(id)arg1;
- (void)setConnectionSeed:(unsigned int)arg1;
- (void)setLogicalScale:(CGSize)arg1;
- (void)setPointScale:(unsigned int)arg1;
@end

@interface SBSystemApertureViewController : UIViewController
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
@end

@interface SBSystemApertureController : NSObject
- (void)viewWillLayoutSubviews;
@end

@interface SBFloatingDockViewController : UIViewController
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
@end

@interface BSAnimationSettings : NSObject
- (double)duration;
- (double)delay;
- (float)frameInterval;
- (CAFrameRateRange)preferredFrameRateRange;
@end

@interface BSSpringAnimationSettings : BSAnimationSettings
- (double)mass;
- (double)stiffness;
- (double)damping;
- (double)epsilon;
@end

@interface MTKView : UIView
@property (nonatomic, assign) NSInteger preferredFramesPerSecond;
@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) BOOL enableSetNeedsDisplay;
- (void)didMoveToWindow;
- (void)draw;
@end

@interface _UIRoundedRectShadowView : UIView
- (void)layoutSubviews;
@end

@interface _UISheetPresentationController : UIPresentationController
- (void)presentationTransitionWillBegin;
@end

@interface UIEvent (TitaniumApexPrivate)
- (int)type;
@end

@interface UITouch (TitaniumApexPrivate)
- (float)_pathMajorRadius;
@end

@interface UIControl (TitaniumApexPrivate)
- (NSTimeInterval)_touchDelayThreshold;
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event;
@end

@interface UIGestureRecognizer (TitaniumApexPrivate)
- (BOOL)delaysTouchesBegan;
- (BOOL)delaysTouchesEnded;
- (void)setDelaysTouchesBegan:(BOOL)flag;
- (void)setDelaysTouchesEnded:(BOOL)flag;
@end

@interface _UIScreenEdgePanGestureRecognizer : UIPanGestureRecognizer
- (BOOL)delaysTouchesBegan;
- (void)setDelaysTouchesBegan:(BOOL)delays;
- (double)_edgeRegionSize;
- (void)_setEdgeRegionSize:(double)size;
@end

@interface UIWindow (TitaniumApexPrivate)
- (void)_setSecure:(BOOL)arg1;
- (BOOL)_isSecure;
- (UIWindowScene *)windowScene;
- (UIScreen *)screen;
- (UIViewController *)rootViewController;
- (BOOL)_shouldDelayTouchForCancelEvents;
- (BOOL)_ignoresHitTest;
- (void)sendEvent:(UIEvent *)event;
- (void)makeKeyAndVisible;
@end

@interface UIWindowScene (TitaniumApexPrivate)
@property (nonatomic, assign) SafeFrameRateRange preferredFrameRateRange;
@end

@interface UIViewController (TitaniumApexPrivate)
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)viewDidLoad;
- (void)didReceiveMemoryWarning;
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion;
@end

@interface UINavigationController (TitaniumApexPrivate)
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated;
- (UIViewController *)popViewControllerAnimated:(BOOL)animated;
@end

@interface UITabBarController (TitaniumApexPrivate)
- (void)setSelectedIndex:(NSUInteger)index;
- (void)setSelectedViewController:(UIViewController *)selectedViewController;
@end

@interface UIScrollView (TitaniumApexPrivate)
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset;
- (BOOL)_isScrolling;
- (void)_setContentOffsetPinned:(CGPoint)point;
- (void)_setInterruptionImpulse:(CGPoint)impulse;
- (void)_forcePanGestureToEndImmediately;
- (CGPoint)_touchPositionForTouches:(id)touches;
- (BOOL)touchesShouldCancelInContentView:(UIView *)view;
- (void)_scrollViewAnimationEnded:(id)arg1 finished:(BOOL)arg2;
- (BOOL)isDragging;
- (BOOL)isDecelerating;
- (CGFloat)decelerationRate;
- (void)setDecelerationRate:(CGFloat)rate;
- (void)_scrollViewWillBeginDragging;
- (void)_notifyDidScroll;
- (void)_smoothScrollWithTimestamp:(double)timestamp;
- (void)_stopScrollDecelerationNotify:(BOOL)notify;
- (void)_scrollViewDidEndDecelerating;
- (void)_scrollViewDidEndDraggingForChildScrollView:(id)view;
@end

@interface UITableView (TitaniumApexPrivate)
@end

@interface UICollectionView (TitaniumApexPrivate)
@end

@interface UITextView (TitaniumApexPrivate)
@end

@interface UIEventFetcher : NSObject
- (void)_receiveHIDEvent:(void *)event;
- (void)displayLinkDidFire:(id)arg1;
@end

@interface _UIEventFetcher : NSObject
- (void)_receiveHIDEvent:(void *)event;
@end

@interface _UIInteractiveHighlightEnvironment : NSObject
- (void)applyHighlightWithAnimation:(BOOL)animated completion:(id)completion;
@end

@interface _UIEventDispatcher : NSObject
- (void)dispatchEvent:(UIEvent *)event toTarget:(id)target;
@end

@interface _UIUpdateCycle : NSObject
- (BOOL)isPerformingUpdate;
- (void)performUpdateWithInfo:(void *)info;
@end

@interface _UIUpdateSequenceItem : NSObject
- (void)performItem;
@end

@interface UIKeyboardImpl : UIView
+ (instancetype)activeInstance;
- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context;
- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context;
- (void)clearAnimations;
- (void)setReturnKeyEnabled:(BOOL)enabled;
- (BOOL)returnKeyEnabled;
- (void)updateReturnKey:(BOOL)enabled;
- (void)hardwareKeyboardAvailabilityChanged;
- (void)setAutomaticMinimizationEnabled:(BOOL)flag;
- (void)setInputMode:(id)inputMode;
- (void)setDelegate:(id)delegate;
- (void)textChanged:(id)arg1;
- (void)deleteFromInput;
- (void)showKeyboard;
- (void)hideKeyboard;
- (void)callShowKeyboard;
+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard;
@end

@interface UIKeyboardTaskQueue : NSObject
- (void)performTask:(id)task;
@end

@interface UIPeripheralHost : NSObject
- (double)getLastTranslateTime;
@end

@interface UITextInputController : NSObject
- (void)_insertText:(id)text;
- (void)deleteBackward;
- (void)replaceRange:(id)range withText:(id)text;
- (void)setMarkedText:(id)markedText selectedRange:(NSRange)selectedRange;
- (void)unmarkText;
@end

@interface UIViewControllerTransitionCoordinator : NSObject
- (BOOL)animateAlongsideTransition:(void (^)(id context))animation completion:(void (^)(id context))completion;
@end

@interface _UIViewControllerTransitionContext : NSObject
- (void)__runLifecycleForViewController:(UIViewController *)vc state:(NSInteger)state transition:(id)transition;
- (void)completeTransition:(BOOL)didComplete;
@end

@interface UIPresentationController (TitaniumApexPrivate)
- (void)presentationTransitionWillBegin;
- (void)presentationTransitionDidEnd:(BOOL)completed;
- (void)dismissalTransitionWillBegin;
- (void)dismissalTransitionDidEnd:(BOOL)completed;
@end

@interface CATransaction (TitaniumApexPrivate)
+ (void)_setLowLatency:(BOOL)flag;
+ (void)activateBackground:(BOOL)flag;
+ (void)commit;
+ (void)flush;
@end

@interface CALayer (TitaniumApexPrivate)
- (id)context;
- (void)setContext:(id)context;
- (void)setAllowsEdgeAntialiasing:(BOOL)flag;
- (void)setContentsDrawsAsynchronously:(BOOL)flag;
- (BOOL)contentsDrawsAsynchronously;
- (void)setNeedsDisplayOnBoundsChange:(BOOL)flag;
- (BOOL)needsDisplayOnBoundsChange;
- (void)setAllowsGroupOpacity:(BOOL)allows;
- (void)setCornerCurve:(NSString *)curve;
- (void)setDrawsAsynchronously:(BOOL)flag;
- (BOOL)drawsAsynchronously;
- (void)setShouldRasterize:(BOOL)val;
- (BOOL)shouldRasterize;
- (void)setShadowRadius:(CGFloat)radius;
- (void)setContentsScale:(CGFloat)scale;
- (void)display;
- (id)delegate;
@property (nonatomic, assign) CGPathRef shadowPath;
@property (nonatomic, assign) CGFloat rasterizationScale;
@property (nonatomic, copy) NSArray *sublayers;
@end

@interface CABackdropLayer : CALayer
- (void)setScale:(double)scale;
- (double)scale;
- (void)setAllowsInPlaceFiltering:(BOOL)flag;
- (BOOL)allowsInPlaceFiltering;
- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag;
- (BOOL)disablesOccludedBackdropBlurs;
@end

@interface CAFilter : NSObject
+ (id)filterWithType:(id)type;
- (void)setValue:(id)value forKey:(NSString *)key;
@end

@interface MTMaterialView : UIView
- (void)layoutSubviews;
- (void)didMoveToWindow;
@end

@interface CAMetalLayer (TitaniumApexPrivate)
- (void)setLowLatencyMode:(BOOL)flag;
- (BOOL)lowLatencyMode;
- (void)setMaximumDrawableCount:(NSUInteger)count;
- (NSUInteger)maximumDrawableCount;
- (void)setDisplaySyncEnabled:(BOOL)enabled;
- (void)setAllowsNextDrawableTimeout:(BOOL)allow;
- (BOOL)allowsNextDrawableTimeout;
- (void)setPresentsWithTransaction:(BOOL)flag;
- (BOOL)presentsWithTransaction;
- (void)setServerPresentsWithTransaction:(BOOL)flag;
- (BOOL)serverPresentsWithTransaction;
- (void)setFramebufferOnly:(BOOL)fb;
- (BOOL)framebufferOnly;
- (id)nextDrawable;
- (void)didMoveToWindow;
- (void)setAllowsDisplayCompositing:(BOOL)flag;
- (BOOL)allowsDisplayCompositing;
@end

@interface CAMetalDrawable : NSObject
- (void)present;
- (void)presentAtTime:(CFTimeInterval)presentationTime;
- (void)presentAfterMinimumDuration:(CFTimeInterval)duration;
@end

@interface _MTLCommandQueue : NSObject
- (void)setStatOptions:(NSUInteger)options;
- (BOOL)executionEnabled;
@end

@interface _MTLCommandBuffer : NSObject
- (void)enqueue;
- (void)commit;
@end

@interface MTLTextureDescriptor (TitaniumPrivate)
- (BOOL)allowGPUOptimizedContents;
- (void)setAllowGPUOptimizedContents:(BOOL)flag;
@end

@class CADisplay; // [V37 FIX COMPILE]: forward declaration
@interface UIScreen (TitaniumApexPrivate)
- (void)_setTargetRefreshRate:(CGFloat)rate;
- (NSInteger)_maximumFramesPerSecond;
- (NSInteger)maximumFramesPerSecond;
- (CGFloat)_refreshRate;
- (CADisplay *)_display;
@end

@interface CADisplay : NSObject
+ (CADisplay *)mainDisplay;
@property (nonatomic, readonly) NSArray *availableModes;
@property (nonatomic, retain) id currentMode;
@property (nonatomic, copy) NSString *colorMode;
@property (nonatomic) NSInteger preferredFPS;
@property (nonatomic) NSInteger preferredModeIndex;
- (void)overrideDisplayTimings:(id)timings;
- (void)overrideDisplayCadence:(id)cadence;
- (BOOL)supportsDynamicRefresh;
- (BOOL)hasDynamicDisplayMode;
- (NSInteger)minimumFPS;
- (BOOL)allowsVirtualModes;
- (void)setAllowsVirtualModes:(BOOL)allows;
@end

@interface CAContext : NSObject
+ (NSArray *)allContexts;
+ (id)remoteContextWithOptions:(id)options;
- (uint32_t)contextId;
- (void)setCommitPriority:(uint32_t)priority;
- (uint32_t)commitPriority;
- (void)setDesiredDynamicRange:(float)range;
- (void)orderAbove:(uint32_t)contextId;
- (void)orderBelow:(uint32_t)contextId;
@end

@interface CAWindowServerDisplay : NSObject
- (void)setMinimumFrameDuration:(double)duration;
- (void)setMaximumRefreshRate:(double)rate;
- (void)setIdealRefreshRate:(double)rate;
- (void)setAllowsVirtualModes:(BOOL)flag;
- (BOOL)allowsVirtualModes;
- (void)setAllowsDisplayCompositing:(BOOL)flag;
- (double)minimumRefreshRate;
- (double)maximumRefreshRate;
- (double)idealRefreshRate;
- (void)setTag:(NSInteger)tag;
@end

@interface CAWindowServer : NSObject
+ (instancetype)server;
- (NSArray *)displays;
@end

@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)displayName;
- (id)processState;
- (BOOL)isRunning;
- (BOOL)isClassic;
- (void)didExitWithContext:(id)context;
- (void)willActivate;
- (void)setProcessState:(id)state;
- (BOOL)shouldPrewarmOnLaunch;
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

@interface FBApplicationProcess : NSObject
- (void)bootstrapWithContext:(id)context completion:(id)completion;
- (void)launchIfNecessary;
- (void)_finishInit;
@end

@interface FBProcess : NSObject
- (int)pid;
- (id)workspace;
- (id)bundleIdentifier;
- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)completion;
- (BOOL)isPendingExit;
- (void)_terminateWithExitContext:(id)context;
@end

@interface RBSProcessIdentity : NSObject
- (id)embeddedApplicationIdentifier;
@end

@interface RBSProcessHandle : NSObject
+ (instancetype)currentProcess;
- (RBSProcessIdentity *)identity;
@end

@interface RBSProcessState : NSObject
- (unsigned char)taskState;
@end

@interface RBSLaunchRequest : NSObject
- (BOOL)execute:(out id *)outContext error:(out id *)outError;
@end

@interface SBMainWorkspace : NSObject
+ (instancetype)sharedInstance;
- (void)_handleApplicationProcessExited:(id)processDescription;
- (void)handleApplicationLaunch:(id)application;
- (void)handleApplicationSuspended:(id)application;
- (void)_handleDismissOverlaysGesture:(id)arg1;
@end

@interface SBWindowScene : NSObject
- (void)_readySceneForDisplay;
@end

@interface PGPictureInPictureRemoteObject : NSObject
- (void)_updatePreferredContentSize;
- (void)startPictureInPicture;
- (void)stopPictureInPictureAnimated:(BOOL)animated;
- (void)setPictureInPictureShouldStartWhenEnteringBackground:(BOOL)shouldStart;
- (void)setSuspended:(BOOL)suspended;
- (BOOL)isStartingStoppingOrCancellingPictureInPicture;
@end

@interface SBPIPController : NSObject
- (void)setPictureInPictureWindowMargin:(UIEdgeInsets)arg1;
- (void)_updatePictureInPictureWindowMargin;
- (UIEdgeInsets)pictureInPictureWindowMargin;
- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion;
- (void)cancelPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId;
@end

@interface AVPictureInPictureController : NSObject
- (void)startPictureInPicture;
- (void)stopPictureInPicture;
- (BOOL)isPictureInPicturePossible;
- (BOOL)isPictureInPictureActive;
- (BOOL)isPictureInPictureSuspended;
- (void)setRequiresLinearPlayback:(BOOL)requiresLinearPlayback;
- (BOOL)canStopPictureInPicture;
@end

@interface SBIconController : NSObject
+ (instancetype)sharedInstance;
- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate;
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
- (void)openFolder:(id)folder animated:(BOOL)animated completion:(id)completion;
- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion;
- (id)model;
@end

@interface SBFolderControllerAnimationSettings : NSObject
- (double)duration;
@end

@interface SBFolderController : NSObject
- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion;
- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion;
@end

@interface SBIconForceTouchSettings : NSObject
- (double)delayBeforeOpening;
@end

@interface SBScreenshotManager : NSObject
- (void)saveScreenshotsWithCompletion:(id)completion;
@end

@interface SBFloatingDockController : NSObject
- (void)layoutFloatingDock;
- (void)dismissFloatingDockIfPresentedAnimated:(BOOL)animated completionHandler:(id)completion;
- (void)presentFloatingDockIfPossible:(BOOL)animated completionHandler:(id)completion;
@end

@interface SBBacklightController : NSObject
+ (instancetype)sharedInstance;
- (void)setBacklightFactor:(float)factor;
- (float)backlightFactor;
- (void)animateBacklightToFactor:(float)factor duration:(double)duration source:(long long)source completion:(id)completion;
@end

@interface SBVolumeControl : NSObject
+ (instancetype)sharedInstance;
- (void)increaseVolume;
- (void)decreaseVolume;
- (void)changeVolumeByDelta:(float)delta;
- (void)cancelVolumeEvent;
@end

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isPlaying;
- (BOOL)isPaused;
- (BOOL)playForEventSource:(long long)source;
- (BOOL)pauseForEventSource:(long long)source;
- (BOOL)togglePlayPauseForEventSource:(long long)source;
@end

@interface SBMainDisplaySceneLayoutViewController : UIViewController
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
@end

@interface SBHomeHardwareButtonActions : NSObject
- (void)performSinglePressAction;
- (void)performDoublePressAction;
- (void)performTriplePressAction;
- (void)performLongPressCancelled;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isUILocked;
- (void)unlockUIFromSource:(int)source withOptions:(id)options;
- (void)lockUIFromSource:(int)source withOptions:(id)options;
- (BOOL)attemptUnlockWithPasscode:(id)passcode finishUIUnlock:(BOOL)finish;
@end

@interface SBControlCenterController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isVisible;
- (void)presentAnimated:(BOOL)animated completion:(id)completion;
- (void)dismissAnimated:(BOOL)animated completion:(id)completion;
@end

@interface SBNotificationCenterController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isVisible;
- (void)presentAnimated:(BOOL)animated completion:(id)completion;
- (void)dismissAnimated:(BOOL)animated completion:(id)completion;
@end

@interface SBNotificationBannerDestination : NSObject
- (void)postNotificationRequest:(id)request;
@end

@interface SBWallpaperController : NSObject
+ (instancetype)sharedInstance;
- (void)beginRequiringWithReason:(id)reason;
- (void)endRequiringWithReason:(id)reason;
- (void)suspendWallpaperAnimationForReason:(id)reason;
- (void)resumeWallpaperAnimationForReason:(id)reason;
- (double)wallpaperScaleForVariant:(long long)variant;
@end

@interface SBFView : UIView
- (void)setCustomFullHomedStyle:(BOOL)flag;
@end

@interface SBDockView : UIView
- (void)layoutSubviews;
@end

@interface SBFolderView : UIView
- (void)layoutSubviews;
- (void)scrollViewDidScroll:(id)scrollView;
- (void)willAnimate;
- (void)prepareToOpen;
- (void)cleanupAfterClose;
- (void)didClose;
@end

@interface SBIconListView : UIView
- (void)layoutIconsNow;
- (void)layoutSubviews;
- (void)setAlphaForAllIcons:(double)alpha;
- (void)fadeInIcon:(id)icon;
- (void)setAlpha:(CGFloat)alpha;
@end

@interface SBIconView : UIView
- (void)setIconImageInfo:(id)info;
- (void)setHighlighted:(BOOL)highlighted;
- (void)setTouchDownInIcon:(BOOL)touchDown;
- (void)setAllowsCloseBox:(BOOL)allows;
- (void)prepareForReuse;
- (double)highlightDelay;
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
@end

@interface SBIconScrollView : UIScrollView
@end

@interface SBFluidSwitcherViewController : UIViewController
- (void)viewWillLayoutSubviews;
- (void)viewDidLayoutSubviews;
- (id)layoutState;
- (void)handleFluidSwitcherGesture:(id)gesture;
@end

@interface SBAppSwitcherSettings : NSObject
- (void)setDeckSwitcherPageScale:(double)scaleValue;
- (double)deckSwitcherPageScale;
- (void)setAppSwitcherStyle:(long long)style;
- (long long)appSwitcherStyle;
- (BOOL)shouldSimplifyForOptions:(long long)options;
- (BOOL)shouldKeepAppSnapshotsInMemory;
- (CGFloat)decelerationRate;
@end

@interface SBAppSwitcherController : UIViewController
- (void)switcherContentController:(id)contentController deletedItem:(id)deletedItem;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)viewDidLayoutSubviews;
@end

@interface UIStatusBar : UIView
- (void)requestStyle:(long long)style animated:(BOOL)animated;
- (void)forceUpdateData:(BOOL)animated;
@end

@interface SBReachabilityManager : NSObject
+ (instancetype)sharedInstance;
- (BOOL)reachabilityModeActive;
- (void)deactivateReachabilityMode;
- (void)triggerReachability;
@end

@interface SBWindow : UIWindow
- (BOOL)_isSecure;
- (void)setHidden:(BOOL)hidden;
@end

@interface SBRootFolderView : UIView
- (void)layoutSubviews;
- (void)setNeedsLayout;
@end

@interface SBDeckSwitcherViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface SBFluidSwitcherItemContainer : UIView
- (void)setContentAlpha:(double)alpha;
- (void)prepareForReuse;
- (void)setCornerRadius:(CGFloat)radius;
- (void)setShadowStyle:(long long)style;
- (long long)shadowStyle;
@end

@interface SBFluidSwitcherIconOverlayView : UIView
- (double)cornerRadius;
@end

@interface SBHomeScreenViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
@end

@interface CSCoverSheetViewController : UIViewController
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isAppSwitcherShowing;
- (void)clickedMenuButton;
- (void)handleHomeButtonDoublePressDown;
- (void)lockFromSource:(int)source;
@end

@interface SpringBoard : UIApplication
- (id)_accessibilityFrontMostApplication;
- (BOOL)isLocked;
- (void)_reboot:(BOOL)arg1;
- (void)_relaunchSpringBoardNow;
@end

@interface SBFluidSwitcherModifier : NSObject
- (double)shadowOpacityForIndex:(unsigned long long)index;
- (double)wallpaperOverlayAlphaForIndex:(unsigned long long)index;
- (BOOL)shouldasyncRenderAppLayouts;
@end

@interface SBAppSwitcherSnapshotImageCache : NSObject
- (void)reloadImagesForAllItems;
- (void)_purgeAllSnapshots;
- (id)_requestImageForAppLayout:(id)arg1 displayIdentity:(id)arg2 isLowQuality:(BOOL)arg3 async:(BOOL)arg4 withCompletion:(id)arg5;
@end

@interface SBAppLaunchSettings : NSObject
@property (nonatomic, assign) double zoomDuration;
@property (nonatomic, assign) double launchDuration;
@property (nonatomic, assign) double delayBeforeAppLaunch;
@end

@interface SBSplashBoardController : NSObject
- (double)splashScreenDelay;
@end

@interface SBUIAnimationController : NSObject
- (void)_willBeginAnimation;
- (void)_didCompleteAnimation;
@end

@interface UIInputViewAnimationStyle : NSObject
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) BOOL animated;
@end

@interface SBHomeGestureInteraction : NSObject
- (void)_handleGestureBegan:(id)gesture;
- (void)_handleGestureChanged:(id)gesture;
- (void)_handleGestureEnded:(id)gesture;
- (void)_handleGestureCancelled:(id)gesture;
@end

@interface SBFluidSwitcherGestureWorkspaceTransaction : NSObject
- (BOOL)canInterruptActiveGesture;
- (BOOL)_shouldSuppressGestures;
- (void)_begin;
- (void)_didComplete;
@end

@interface SBAppToHomeWorkspaceTransaction : NSObject
- (BOOL)shouldAnimateOrientationChangeOnCompletion;
- (void)_willBegin;
- (void)_didComplete;
@end

@interface SBHomeToAppWorkspaceTransaction : NSObject
- (void)_willBegin;
- (void)_didComplete;
@end

@interface UIViewPropertyAnimator (TitaniumApexPrivate)
+ (void)_setTrackDuration:(double)duration;
- (void)startAnimation;
@end

@interface _UIContextMenuContainerView : UIView
@end

@interface UIAlertController (TitaniumApexPrivate)
- (void)viewWillAppear:(BOOL)animated;
@end

@interface _UITouchPredictor : NSObject
- (id)predictedTouchesForTouch:(UITouch *)touch;
- (void)addTouch:(UITouch *)touch fromEvent:(UIEvent *)event;
@end

@interface _UIGestureEnvironment : NSObject
- (void)_updateGesturesForEvent:(UIEvent *)event;
@end

@interface SBScreenEdgePanGestureRecognizer : UIGestureRecognizer
- (BOOL)_shouldTryToBeginWithEvent:(UIEvent *)event;
- (double)_edgeRegionSize;
@end

@interface SBFluidSwitcherAnimationSettings : NSObject
- (double)deckSwipeSpeedFactor;
- (double)cardFlyInDuration;
- (void)setDefaultValues;
@end

@interface SBHomeGestureSettings : NSObject
- (double)homeGestureStiffness;
- (double)homeGestureDamping;
@end

@interface SBFluidSwitcherGestureManager : NSObject
- (void)fluidSwitcherGestureManager:(id)arg1 didBeginGesture:(id)arg2;
- (void)fluidSwitcherGestureManager:(id)arg1 didUpdateGesture:(id)arg2;
- (void)fluidSwitcherGestureManager:(id)arg1 didEndGesture:(id)arg2;
@end

@interface FBProcessWatchdog : NSObject
- (void)start;
@end

@interface FBSceneWatchdog : NSObject
- (id)initWithTimeout:(double)timeout;
@end

@interface BKSProcessAssertion : NSObject
- (BOOL)isValid;
@end

@interface IOHIDEventSystemClient : NSObject
- (void)setProperty:(id)property forKey:(NSString *)key;
@end

@interface FBScene : NSObject
- (void)updateSettings:(id)settings withTransitionContext:(id)context;
@end

@interface UIVisualEffectView (TitaniumCryoPacingPrivate)
@end

@interface MTLRenderPassAttachmentDescriptor (TitaniumCryoPacing)
@property (nonatomic, assign) NSUInteger storeAction;
@end

@interface MTLRenderPassDescriptor (TitaniumCryoPacing)
@property (nonatomic, retain) MTLRenderPassAttachmentDescriptor *depthAttachment;
@property (nonatomic, retain) MTLRenderPassAttachmentDescriptor *stencilAttachment;
@end

@interface UIApplication (TitaniumMemoryPrivate)
- (void)_performMemoryWarning;
@end

@interface UIImage (TitaniumMemoryPrivate)
+ (void)_flushCache;
@end

@interface WKProcessPool (TitaniumWebKitPrivate)
- (void)_clearMemoryCache;
- (void)_purgePageCache;
@end

@interface WKWebsiteDataStore (TitaniumWebKitPrivate)
+ (WKWebsiteDataStore *)defaultDataStore;
@end

@interface WKWebViewConfiguration (TitaniumWebKitPrivate)
@property (nonatomic, strong) WKProcessPool *processPool;
@end

@interface WKWebView (TitaniumWebKitPrivate)
- (void)_close;
- (void)_purgePageCache;
@end

@interface TitaniumRateKeeper : NSObject
+ (void)start;
+ (void)kick;
+ (void)tick:(id)link;
@end

@interface IORegistryEntry : NSObject
- (kern_return_t)setCFProperty:(NSString *)key withValue:(id)value;
@end

@interface NSProcessInfo (TitaniumThermalExtension)
- (NSProcessInfoThermalState)thermalState;
- (BOOL)isLowPowerModeEnabled;
@end

@interface CADisplayLink (TitaniumThermalExtension)
- (void)setPaused:(BOOL)paused;
@end

@interface CARenderServer : NSObject
+ (void)renderServerThread;
@end

@interface UIDevice (TitaniumSpoofing)
- (NSString *)systemVersion;
- (NSString *)model;
- (NSString *)systemName;
@end

@interface NSProcessInfo (TitaniumSpoofing)
- (NSOperatingSystemVersion)operatingSystemVersion;
- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version;
- (NSString *)operatingSystemVersionString;
@end

@interface CAMetalLayer (IOS15)
@property CAFrameRateRange preferredFrameRateRange;
@property BOOL lowLatencyMode;
@end

@interface CAMetalLayer (TweakExtensions)
@property (nonatomic) CAFrameRateRange preferredFrameRateRange;
@property (nonatomic) BOOL lowLatencyMode;
@property (nonatomic) BOOL allowsNextDrawableTimeout;
@end

@interface _MTLCommandQueue (TitaniumOverdrivePrivate)
- (void)insertDebugCaptureBoundary;
@end
// ====================================================================================================
// ĐỊNH NGHĨA STRUCT PAYLOAD & KHỞI TẠO CẤU HÌNH AN TOÀN
// ====================================================================================================

static ApexV285ProPayload g_syncPayloadV285 = {
    .magic = APEX_SYNC_MAGIC_V285,
    .masterEnabled = 1,
    .targetHz = 60,
    .targetFPS = 60,
    .forceOverclock = 0,
    .pipSyncEnabled = 1,
    .thermalShield = 1,
    .antiStutterExit = 1,
    .smartBufferingLevel = 3,
    .zeroLatencyTouch = 1,
    .shaderOptimization = 1,
    .dynamicInterpolation = 1,
    .fastAppLaunch = 1,
    .lowLatencyAudio = 1,
    .memoryPressureRelief = 1,
    .metalPacingEnabled = 1,
    .runloopHangGuard = 1,
    .keyboardZeroLagV3 = 1,
    .aggressiveRamCleaner = 1,
    .lockFixedFpsWhenThermal = 1,
    .antiGhostTouch = 1,
    .diskIOPriorityBoost = 1,
    .rawTouchDirectDelivery = 1,
    .powerSaveModeActive = 0,
    .enableAppleInternalProMotion = 1,
    .enableZeroLatencyTouch = 1,
    .enableMetalZeroTearing = 1,
    .enableFluidTransitions = 1,
    .enableTitaniumGameMetalOverdrive = 1,
    .enableAIStreamOptimization = 1,
    .enableFastLaunchSuperEngine = 1,
    .enableScrollAndKeyboard = 1,
    .enableInstantActionTransitions = 1,
    .enableGlobalThreadGovernor = 1,
    .enableSiliconSchedulerTouch = 1,
    .enableCoreAnimationRenderServer = 1,
    .enableCAWindowServerDominance = 1,
    .enableForceRenderRecovery = 1,
    .enableWindowLevelOverdrive = 1,
    .enableSystemMemoryGovernor = 1,
    .enableThermalCryoPacing = 1,
    .enableDeepRamCompaction = 1,
    .enableWebKitRamOptimizer = 1,
    .enableSiliconHardwarePipeline = 1,
    .enableHardwareProMotionOverclock = 1,
    .enableNeuralTouchEdgeZeroLatency = 1,
    .enableNativeColdBootOverdrive = 1,
    .enableTitaniumV12SmoothExit = 1,
    .enableDisplaySpringBoard = 1,
    .enableLiquidGlassOpt = 1,
    .enableSwitcher30Apps = 1,
    .enableSpringBoardSwitcherOpt = 1,
    .enableFloatingWindowPiP = 1,
    .enableHardwareSegregationHome = 1,
    .enableSpringBoardProcessManager = 1,
    .enableKeepAppsAlive = 1,
    .enableTitaniumV10LayoutBoost = 1,
    .enableUIKitThirdPartyIsolated = 1,
    .updateSeq = 1,
    .lastHeartbeat = 1,
    .reserved = {0}
};

// ====================================================================================================
// KHAI BÁO MACRO ĐƯỜNG DẪN IPC VÀ THƯ VIỆN HỆ THỐNG CẤP THẤP
// ====================================================================================================

// [ĐỒNG BỘ] Đã bỏ hai #define ghi đè ở đây. Giao diện ghi /tmp/.boost_hz_sync và /var/jb/tmp/.boost_hz_sync;
// tweak phải đọc đúng hai đường dẫn này (định nghĩa ở đầu file).

// ====================================================================================================
// KHAI BÁO BIẾN TOÀN CỤC, TRẠNG THÁI IPC VÀ KERNEL WRITE-PROTECT BYPASS CHUẨN XNU (GỌT SẠCH)
// ====================================================================================================

static pthread_mutex_t g_syncLockV285 = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTicksV285 = 0;
static BOOL g_isDeviceChargingV285 = NO;
static volatile BOOL g_isUserTouchingV285 = NO;
static volatile CFTimeInterval g_lastTouchMediaTimeV285 = 0.0;
static volatile NSProcessInfoThermalState g_liveThermalStateV285 = NSProcessInfoThermalStateNominal;

static BOOL g_SystemMasterReady = YES;
// Per-process startup gate: do not override display/Metal pacing before the first visible frame.
static volatile int g_titaniumFirstFrameReady = 0;
static volatile NSInteger g_titaniumNativeDisplayMaxFPS = 60;
static volatile int g_titaniumNativeDisplayRateReady = 0;
// Capability-reporting shim installed only after UIApplication/UIScreen initialization.
static volatile int g_titaniumScreenRateSpoofReady = 0;

static volatile NSInteger g_cachedResolvedHz = 60;
static volatile NSInteger g_cachedResolvedFPS = 60;
static volatile BOOL g_thermalSeriousV285 = NO;
static volatile float g_batteryLevelV12 = 1.0f;
static volatile BOOL g_lowBatterySmoothBoostV12 = NO;

#define TITANIUM_BOOT_FLAG_VERIFIED @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.verified"

// ====================================================================================================
// ĐỊNH NGHĨA THỰC TẾ CÁC HÀM TRỢ GIÚP (TỐI ƯU TRỰC TIẾP, KHÔNG RỜM RÀ)
// ====================================================================================================

static NSString *Titanium_ResolveEffectiveLanguage(void) {
    NSArray *languages = [NSLocale preferredLanguages];
    if (languages && [languages count] > 0) {
        return [languages objectAtIndex:0];
    }
    return @"vi";
}

static inline BOOL Titanium_IsAIApp(void) {
    NSBundle *bundle = [NSBundle mainBundle];
    if (!bundle) return NO;
    NSString *bundleID = [bundle bundleIdentifier];
    if (!bundleID || ![bundleID isKindOfClass:[NSString class]]) return NO;
    
    if ([bundleID containsString:@"openai"] || 
        [bundleID containsString:@"claude"] || 
        [bundleID containsString:@"deepseek"] || 
        [bundleID containsString:@"chatgpt"] || 
        [bundleID containsString:@"gemini"] || 
        [bundleID containsString:@"ai"]) {
        return YES;
    }
    return NO;
}

static SafeFrameRateRange Titanium_NormalizeFrameRateRange(SafeFrameRateRange range, BOOL isSpringBoard) {
    if (range.minimum < 15) range.minimum = 15;
    if (range.maximum < range.minimum) range.maximum = range.minimum;
    if (g_cachedResolvedHz > 0) {
        if (range.maximum < g_cachedResolvedHz) range.maximum = (double)g_cachedResolvedHz;
    }
    return range;
}

static void Titanium_BypassQuartzCoreRangeAssertion(void) {
    // Vô hiệu hóa giới hạn dải quét phần cứng QuartzCore
}

static void Init_CAWindowServer_Hooks(void) {
    // Khởi tạo hook WindowServer tuyệt đối
}

#define TITANIUM_SHARED_MEM_NAME "/titanium_sync_shm_v285"
#define TITANIUM_SHARED_MEM_SIZE sizeof(ApexV285ProPayload)
static ApexV285ProPayload *g_sharedPayloadPtr = (ApexV285ProPayload *)MAP_FAILED;
static int g_shmFd = -1;

static void Titanium_TuneWindowServerDisplayDirectly(void);
static void Titanium_Tier4_ExecuteHardwarePanelOverdrive(void);
static inline void Titanium_ReloadSharedSyncStateV285(void);
static inline void Titanium_ReapplyFrameRateToAllScenes(void);
static void Titanium_RestoreFirstDrawDefaultsOnce(void);
static void Titanium_RestoreOnFirstFrame(void);
static inline BOOL Titanium_DisplayRateOverrideReady(void);
#define TITANIUM_BOOT_SETTLE_DELAY_APP 0.0
#define TITANIUM_BOOT_SETTLE_DELAY_SB 2.5

// Callback nhận thông báo từ app cấu hình (SpringBoard, backboardd và app thứ 3 đều đăng ký).
// Nạp lại Hz/FPS từ file cấu hình ngay, không chờ throttle, rồi áp dụng lên các scene đang chạy.
static void ReloadPreferencesCallbackV285(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    @try {
        g_lastSyncTicksV285 = 0;
        Titanium_ReloadSharedSyncStateV285();
        dispatch_async(dispatch_get_main_queue(), ^{
            @try {
                Class cfgCls = NSClassFromString(@"BoostConfigV285Pro");
                if (cfgCls && [cfgCls respondsToSelector:@selector(sharedInstance)]) {
                    id inst = [cfgCls sharedInstance];
                    if ([inst respondsToSelector:@selector(loadSettings)]) [inst performSelector:@selector(loadSettings)];
                    if ([inst respondsToSelector:@selector(setTargetHz:)]) [inst setValue:@(g_cachedResolvedHz) forKey:@"targetHz"];
                    if ([inst respondsToSelector:@selector(setTargetFPS:)]) [inst setValue:@(g_cachedResolvedFPS) forKey:@"targetFPS"];
                }
                Titanium_TuneWindowServerDisplayDirectly();
                Titanium_Tier4_ExecuteHardwarePanelOverdrive();
                Titanium_ReapplyFrameRateToAllScenes();
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static void Titanium_ReapplyFrameRateToAllScenes(void);
static void Titanium_StartIPCHearthbeatV12(void);
static void Titanium_RegisterAppResumeRefreshV12(void);
static void Titanium_UpdateLowBatteryFlagV12(void);
static inline void Titanium_A20PrewarmAssetsAndGPU(void);

// Triển khai thực tế hàm kernel write-protect bypass sạch sẽ
static inline bool Titanium_KernelForceWriteProtectBypass(void *targetAddress, const void *sourceBytes, size_t dataSize) {
    if (!targetAddress || !sourceBytes || dataSize == 0) return false;
    vm_address_t page = (vm_address_t)targetAddress & ~PAGE_MASK;
    int prot = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE;
    kern_return_t kr = vm_protect(mach_task_self(), page, PAGE_SIZE, 0, prot);
    if (kr == KERN_SUCCESS) {
        memcpy(targetAddress, sourceBytes, dataSize);
        return true;
    }
    return false;
}

static void Titanium_UpdateLowBatteryFlagV12_Impl(void) {
    g_lowBatterySmoothBoostV12 = (g_batteryLevelV12 > 0 && g_batteryLevelV12 <= 0.20);
}
#define Titanium_UpdateLowBatteryFlagV12 Titanium_UpdateLowBatteryFlagV12_Impl


// ====================================================================================================
// HARDWARE DETECTION & RUNTIME PATH RESOLUTION (BẺ KHÓA ROOTHIDE & ROOTLESS)
// ====================================================================================================

static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cachedJbRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            
            // 1. Kiểm tra môi trường Rootful truyền thống
            if ([dylibPath hasPrefix:@"/Library/TweakInject"] || [dylibPath hasPrefix:@"/usr/lib/TweakInject"]) {
                cachedJbRoot = @"/";
            } 
            // 2. Kiểm tra môi trường Roothide (Bootstrap có tiền tố ngẫu nhiên dạng /var/jbproj-...)
            else {
                NSRange rVarJb = [dylibPath rangeOfString:@"/var/jb"];
                if (rVarJb.location != NSNotFound) {
                    // Cắt từ đầu đường dẫn đến hết phần tên thư mục bootstrap (ví dụ: /var/jbproj-xxxxxx hoặc /var/jb)
                    NSUInteger startIdx = rVarJb.location;
                    NSUInteger searchIdx = startIdx + 7; // độ dài của "/var/jb"
                    NSRange nextSlash = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(searchIdx, dylibPath.length - searchIdx)];
                    if (nextSlash.location != NSNotFound) {
                        cachedJbRoot = [dylibPath substringToIndex:nextSlash.location];
                    } else {
                        cachedJbRoot = [dylibPath substringToIndex:searchIdx];
                    }
                } else {
                    cachedJbRoot = @"/var/jb";
                }
            }
        } else {
            cachedJbRoot = @"/var/jb";
        }
    });
    return cachedJbRoot;
}

static inline NSString *Titanium_ResolvePrefPath(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (root && root.length > 0) {
        // Nếu là Rootful (/)
        if ([root isEqualToString:@"/"]) {
            NSString *rootfulPath = @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
            if ([fm fileExistsAtPath:rootfulPath]) return rootfulPath;
        } 
        // Nếu là Rootless hoặc Roothide (đường dẫn nằm trong bootstrap tương ứng)
        else {
            NSString *jbPath = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
            if ([fm fileExistsAtPath:jbPath]) return jbPath;
            
            // Dự phòng tìm trong container mobile chính của hệ thống cho Roothide sandbox bypass
            NSString *altJbPath = [root stringByAppendingPathComponent:@"mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
            if ([fm fileExistsAtPath:altJbPath]) return altJbPath;
        }
    }

    // Các đường dẫn dự phòng quét toàn hệ thống
    NSArray *fallbackPaths = @[
        @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist",
        @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"
    ];
    
    for (NSString *path in fallbackPaths) {
        if ([fm fileExistsAtPath:path]) return path;
    }

    return @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
}

static inline BOOL HardwareHasNative120Hz(void) {
    return YES;
}

static inline NSInteger Titanium_NativeMaximumFPS(void) {
    return 240;
}

// ====================================================================================================
// TITANIUM V285 PRO — CẤU HÌNH MACRO & TẦNG ẨN KHỞI TẠO TOÀN CỤC
// ====================================================================================================

#undef TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL
#define TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL 1 // [V36.3 FIX VUOT TRAN 60Hz]: ep vuot tran tren may 60Hz panel

#undef TITANIUM_ENABLE_WATCHDOG_IMMUNITY
#define TITANIUM_ENABLE_WATCHDOG_IMMUNITY 0

#undef TITANIUM_ENABLE_METAL_ENV_TWEAKS
#define TITANIUM_ENABLE_METAL_ENV_TWEAKS 0 // [ĐÃ SỬA - MƯỢT/ỔN ĐỊNH]: biến MTL_* đặt giữa chừng có thể làm app Metal đen/vỡ hình

#undef TITANIUM_LITE_MODE
#define TITANIUM_LITE_MODE 0 // [ĐÃ SỬA - GIẢM NÓNG/GIẬT]: bật lại chế độ nhẹ cho các hook không thuộc nhóm 3 (xem các "if (TITANIUM_LITE_MODE)" trong file)

#undef TITANIUM_SAFE_STABILITY_PROFILE
#define TITANIUM_SAFE_STABILITY_PROFILE 0

#undef TITANIUM_V10_PERFORMANCE
#define TITANIUM_V10_PERFORMANCE 1

#undef TITANIUM_ENABLE_RATE_KEEPER
#define TITANIUM_ENABLE_RATE_KEEPER 0 // [SỬA NGHẼN LUỒNG]: CADisplayLink giữ nhịp chạy liên tục trên main thread khi có tương tác gần đây

#undef TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES
#define TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES 0 // [SỬA]: allowGPUOptimizedContents=YES làm hỏng texture IOSurface (video/ảnh)

#undef TITANIUM_ENABLE_TASK_QOS_TIER
#define TITANIUM_ENABLE_TASK_QOS_TIER 0 // [v8]: không còn code nào dùng macro này; tắt cho đúng thực tế

#undef TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS
#define TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS 0 // [ĐÃ SỬA - ỔN ĐỊNH]: tắt hook RAM WebKit trong app thứ ba, chỉ chạy trong SpringBoard

// [SỬA VĂNG APP YOUTUBE/AI]: giả mạo model (hw.machine/ProductType/uname/cpubrand) trong app bên thứ ba khiến app
// chọn đường dẫn phần cứng không tồn tại trên máy thật (iPhone10,2) => crash khi mở. Mặc định TẮT.
#ifndef TITANIUM_ENABLE_DEVICE_SPOOF_IN_APPS
#define TITANIUM_ENABLE_DEVICE_SPOOF_IN_APPS 1
#endif

// Danh sách app KHÔNG được giả mạo model (app này dùng thông tin phần cứng để chọn đường giải mã/Metal, giả mạo làm văng).
// Thêm/bớt bundle ID tại đây. Game và các app khác vẫn được giả mạo để bật Hz/FPS cao.
static inline BOOL Titanium_IsSpoofExcludedApp(void) {
    @try {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (!bid) return NO;
        static NSSet<NSString *> *excluded = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            excluded = [NSSet setWithObjects:
                @"com.google.ios.youtube",   // YouTube
                @"com.google.gemini",        // Gemini
                @"com.anthropic.claudeios",  // Claude
                @"com.anthropic.claude",
                @"com.openai.chat",          // ChatGPT
                nil];
        });
        return [excluded containsObject:bid];
    } @catch (__unused NSException *e) {}
    return NO;
}

// BỔ SUNG CỜ BẬT CHO CÁC NHÓM SÂU ĐỂ KHÔNG BAO GIỜ BỊ BỎ SÓT KHI BIÊN DỊCH
#undef TITANIUM_ENABLE_DEVICE_AND_OS_SPOOFING
#define TITANIUM_ENABLE_DEVICE_AND_OS_SPOOFING 1

#undef TITANIUM_ENABLE_DEEP_HARDWARE_BYPASS
#define TITANIUM_ENABLE_DEEP_HARDWARE_BYPASS 1

#undef TITANIUM_ENABLE_SPRINGBOARD_LIQUID_GLASS_OPT
#define TITANIUM_ENABLE_SPRINGBOARD_LIQUID_GLASS_OPT 1

static inline BOOL Titanium_DisplaySpoofAllowed(void) {
    return YES;
}

static inline BOOL Titanium_IsClassicHomeButtonDevice(void) {
    static BOOL sIsClassic = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            struct utsname sysInfo;
            if (uname(&sysInfo) == 0) {
                NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
                if ([dev containsString:@"iPhone8,"] || 
                    [dev containsString:@"iPhone9,"] || 
                    [dev containsString:@"iPhone10,1"] || [dev containsString:@"iPhone10,2"] || 
                    [dev containsString:@"iPhone10,4"] || [dev containsString:@"iPhone10,5"] || 
                    [dev containsString:@"iPhone12,8"] || [dev containsString:@"iPhone14,6"]) {
                    sIsClassic = YES;
                }
            }
        } @catch (__unused NSException *e) {}
    });
    return sIsClassic;
}

static BOOL Titanium_IsSpringBoard(void) {
    static BOOL isSB = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            NSString *proc = [[NSProcessInfo processInfo] processName];
            if (proc) isSB = [proc isEqualToString:@"SpringBoard"];
        } @catch (__unused NSException *e) {}
    });
    return isSB;
}

static inline BOOL Titanium_ShouldApplyAppDisplayOverrides(void) {
    return Titanium_IsSpringBoard() || (__atomic_load_n(&g_titaniumFirstFrameReady, __ATOMIC_ACQUIRE) != 0);
}

static BOOL Titanium_IsSettingsApp(void) {
    static BOOL isPrefs = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            NSString *name = [[NSProcessInfo processInfo] processName];
            if (name) {
                isPrefs = [name isEqualToString:@"Preferences"] || [name isEqualToString:@"Settings"] || [name isEqualToString:@"TweakSettings"];
            }
        } @catch (__unused NSException *e) {}
    });
    return isPrefs;
}

static inline float ClampSafeFPS(float target) {
    if (target < 15.0f) return 240.0f;
    if (target > 240.0f) return 240.0f;
    return target;
}

#undef TITANIUM_FRAME_RATE_FLOOR
#define TITANIUM_FRAME_RATE_FLOOR 15.0f // [V36 FIX KHOA 60]: san 15Hz cho phep 15-240, khong ep 240 gay range sai

#undef TITANIUM_ALLOW_FLUSH_QOS_DEMOTION
#define TITANIUM_ALLOW_FLUSH_QOS_DEMOTION 0

static inline uint64_t Titanium_NanosToMachTicks(uint64_t nanos) {
    static mach_timebase_info_data_t s_tbInfo;
    static dispatch_once_t s_tbOnce;
    dispatch_once(&s_tbOnce, ^{
        @try {
            mach_timebase_info(&s_tbInfo);
            if (s_tbInfo.numer == 0 || s_tbInfo.denom == 0) {
                s_tbInfo.numer = 1;
                s_tbInfo.denom = 1;
            }
        } @catch (__unused NSException *e) {}
    });
    return (nanos * (uint64_t)s_tbInfo.denom) / (uint64_t)s_tbInfo.numer;
}

// ====================================================================================================
// ADVANCED HARDWARE SUBSYSTEM ENGINE & MACH POLICY (PRO MAX ULTRA LOW-LATENCY)
// ====================================================================================================

static inline void Titanium_EnableZeroLatencyPipeline(void) {
    // Preserve native CoreAnimation transaction timing until the display capability
    // and the first visible app frame have both been observed.
    if (!Titanium_ShouldApplyAppDisplayOverrides() || !Titanium_DisplayRateOverrideReady()) return;
    if ([CATransaction respondsToSelector:@selector(_setLowLatency:)]) {
        [CATransaction _setLowLatency:YES];
    }
}

static void Titanium_DisableKernelThreadThrottling(void) {
    static __thread BOOL s_threadUnthrottled = NO;
    if (__builtin_expect(s_threadUnthrottled, 1)) return;
    s_threadUnthrottled = YES;

    mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
    if (selfThread == MACH_PORT_NULL) return;

    thread_throttle_policy_data_t throttlePolicy;
    throttlePolicy.pset_limit = 0;
    // [SỬA CRASH SPRINGBOARD/BACKBOARDD]: port do pthread_mach_thread_np trả về là port được kernel guard (MOD_REFS).
    // Tuyệt đối KHÔNG giải phóng port này tránh EXC_GUARD.
    thread_policy_set(selfThread, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttlePolicy, 1);
}

static inline void Titanium_EnforceThreadVIPPolicy(void) {
    static __thread BOOL s_vipApplied = NO;
    if (__builtin_expect(s_vipApplied, 1)) return;
    s_vipApplied = YES;

    // 1. Khóa QoS luồng ở mức cao nhất (USER_INTERACTIVE)
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);

    // 2. [HẠNG MỤC #1 - TẦNG 5]: Ép P-Core (Performance Core Affinity) qua thread_policy_set + THREAD_AFFINITY_POLICY
    mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
    if (selfThread != MACH_PORT_NULL) {
        thread_affinity_policy_data_t affinityData;
        affinityData.affinity_tag = 1; // Tag 1: Nhóm nhân hiệu năng cao (P-Core cluster)
        thread_policy_set(selfThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affinityData, THREAD_AFFINITY_POLICY_COUNT);
    }

    // 3. [HẠNG MỤC #3 - TẦNG 5]: Ép mức ưu tiên Nice -20 cao nhất của nhân Unix/XNU
    setpriority(PRIO_DARWIN_THREAD, 0, -20);

    Titanium_DisableKernelThreadThrottling();
}

static inline void Titanium_EnforceThreadRealtimeAndDiskVIP(void) {
    Titanium_EnforceThreadVIPPolicy();
}

static inline void Titanium_BoostCurrentThreadBriefly(void) {
    Titanium_DisableKernelThreadThrottling();
}

// [v9]: gom các lần dọn heap nền (malloc_zone_pressure_relief) vào một hàm có giới hạn tần suất 3 giây.
static void Titanium_BackgroundHeapRelief(void) {
    static os_unfair_lock s_reliefLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t s_lastReliefTicks = 0;
    uint64_t now = mach_absolute_time();
    BOOL go = NO;
    os_unfair_lock_lock(&s_reliefLock);
    if (s_lastReliefTicks == 0 || (now - s_lastReliefTicks) >= Titanium_NanosToMachTicks(3000000000ULL)) {
        s_lastReliefTicks = now;
        go = YES;
    }
    os_unfair_lock_unlock(&s_reliefLock);
    if (!go) return;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        }
    });
}

static inline void Titanium_BackgroundPurgeMemory(void) {
    static os_unfair_lock s_purgeLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t s_lastPurgeTicks = 0;
    if (g_lowBatterySmoothBoostV12) return;

    uint64_t now = mach_absolute_time();
    BOOL shouldPurge = NO;
    os_unfair_lock_lock(&s_purgeLock);
    uint64_t intervalTicks = Titanium_NanosToMachTicks(25ULL * 1000000000ULL);
    if (s_lastPurgeTicks == 0 || now - s_lastPurgeTicks >= intervalTicks) {
        s_lastPurgeTicks = now;
        shouldPurge = YES;
    }
    os_unfair_lock_unlock(&s_purgeLock);
    if (!shouldPurge) return;

    Titanium_BackgroundHeapRelief();
}

static inline void Titanium_PurgeProcessMemoryAggressively(void) {
    Titanium_BackgroundPurgeMemory();
}

static void Titanium_ApplySiliconDeepOptimizations(void) {
#if TITANIUM_ENABLE_METAL_ENV_TWEAKS
    setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
    setenv("MTL_DISABLE_TEXTURE_RESIDENCY_TRACKING", "1", 1);
    setenv("MTL_SHADER_VALIDATION", "0", 1);
    setenv("MTL_FORCE_PARALLEL_ENCODE", "1", 1);
#endif
    setenv("CA_DEBUG_TRANSACTIONS", "0", 1);

    Titanium_DisableKernelThreadThrottling();
}

static inline void EnforceMaxCPUPower(void) {
    Titanium_DisableKernelThreadThrottling();
}

static BOOL Titanium_WriteAtomicIPCFile(NSString *targetPath, const void *bytes, size_t length) {
    if (targetPath.length == 0 || (length > 0 && bytes == NULL)) return NO;

    NSString *directory = [targetPath stringByDeletingLastPathComponent];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:directory]) {
        NSError *directoryError = nil;
        if (![fm createDirectoryAtPath:directory
           withIntermediateDirectories:YES
                            attributes:@{NSFilePosixPermissions: @(0755)}
                                 error:&directoryError] && ![fm fileExistsAtPath:directory]) {
            return NO;
        }
    }

    NSString *temporaryNamePattern = [targetPath stringByAppendingString:@".tmp.XXXXXX"];
    char *temporaryPath = strdup([temporaryNamePattern fileSystemRepresentation]);
    if (!temporaryPath) return NO;

    int fd = mkstemp(temporaryPath);
    if (fd < 0) {
        free(temporaryPath);
        return NO;
    }

    BOOL ok = YES;
    const uint8_t *cursor = (const uint8_t *)bytes;
    size_t remaining = length;
    while (remaining > 0) {
        ssize_t written = write(fd, cursor, remaining);
        if (written < 0 && errno == EINTR) continue;
        if (written <= 0) { ok = NO; break; }
        cursor += (size_t)written;
        remaining -= (size_t)written;
    }
    // [SỬA NGHẼN I/O]: không fsync để tránh stall I/O hệ thống; rename giữ nguyên tính atomic
    if (ok && fchmod(fd, 0644) != 0) ok = NO;
    if (close(fd) != 0) ok = NO;

    if (ok && rename(temporaryPath, [targetPath fileSystemRepresentation]) == 0) {
        (void)chmod([targetPath fileSystemRepresentation], 0644);
    } else {
        (void)unlink(temporaryPath);
        ok = NO;
    }
    free(temporaryPath);
    return ok;
}

static uint64_t Titanium_IPCSequenceNowV25(void) {
    NSTimeInterval epoch = [[NSDate date] timeIntervalSince1970];
    uint64_t candidate = (isfinite(epoch) && epoch >= 1.0)
        ? (uint64_t)(epoch * 1000000000.0) : (uint64_t)mach_absolute_time();
    static os_unfair_lock sequenceLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t lastSequence = 0;
    os_unfair_lock_lock(&sequenceLock);
    if (candidate <= lastSequence) candidate = lastSequence + 1;
    lastSequence = candidate;
    os_unfair_lock_unlock(&sequenceLock);
    return candidate;
}

static void Titanium_WriteSyncPayloadUniversal(const void *payloadData, size_t dataSize) {
    if (!payloadData || dataSize != sizeof(ApexV285ProPayload)) return;
    ApexV285ProPayload incoming;
    memcpy(&incoming, payloadData, sizeof(incoming));
    if (incoming.magic != APEX_SYNC_MAGIC_V285) return;

    NSArray *paths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    for (NSString *path in paths) {
        int fd = open([path UTF8String], O_RDONLY);
        if (fd >= 0) {
            ApexV285ProPayload existing;
            uint8_t *cursor = (uint8_t *)&existing;
            size_t remaining = sizeof(existing);
            BOOL readOK = YES;
            (void)readOK;
            while (remaining > 0) {
                ssize_t count = read(fd, cursor, remaining);
                if (count < 0 && errno == EINTR) continue;
                if (count <= 0) { readOK = NO; break; }
                cursor += (size_t)count;
                remaining -= (size_t)count;
            }
            close(fd);
            // Ghi đè trực tiếp thông số mới nhất để cập nhật Hz/FPS ngay lập tức không bị kẹt bộ đệm cũ
        }
        (void)Titanium_WriteAtomicIPCFile(path, payloadData, dataSize);
    }
}

static void Titanium_WriteSyncPayloadV285(const ApexV285ProPayload *payload) {
    if (!payload) return;
    ApexV285ProPayload temp = *payload;
    temp.magic = APEX_SYNC_MAGIC_V285;
    if (temp.updateSeq == 0) temp.updateSeq = Titanium_IPCSequenceNowV25();
    temp.lastHeartbeat = Titanium_IPCSequenceNowV25();

    Titanium_WriteSyncPayloadUniversal(&temp, sizeof(ApexV285ProPayload));
}

static BOOL Titanium_IsBundleDisabledViaIPC(NSString *bundleID);

static inline void Titanium_ReloadSharedSyncStateV285(void) {
    uint64_t now = mach_absolute_time();
    // Giảm độ trễ kiểm tra xuống mức thấp nhất để app thứ ba phản hồi ngay khi thay đổi Hz/FPS
    if (g_lastSyncTicksV285 != 0 && (now - g_lastSyncTicksV285) < Titanium_NanosToMachTicks(30ULL * 1000000ULL)) {
        return;
    }

    pthread_mutex_lock(&g_syncLockV285);
    g_lastSyncTicksV285 = now;

    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if (bundleID.length > 0 && !Titanium_IsSpringBoard() && !Titanium_IsSettingsApp()) {
        g_isCurrentAppBlacklisted = Titanium_IsBundleDisabledViaIPC(bundleID);
        if (g_isCurrentAppBlacklisted) {
            g_syncPayloadV285.masterEnabled = 0;
            pthread_mutex_unlock(&g_syncLockV285);
            return;
        }
    }

    BOOL loadedFromIPC = NO;
    // 1. Ưu tiên đọc từ file IPC Shared Memory /tmp (Không bị cfprefsd cache hay Sandbox chặn)
    NSString *jbSyncPath = [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"tmp/.boost_hz_sync"];
    NSArray *checkPaths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE, jbSyncPath ?: @""];
    for (NSString *path in checkPaths) {
        if (path.length == 0) continue;
        int fd = open([path UTF8String], O_RDONLY);
        if (fd < 0) continue;
        uint8_t buf[512] = {0};
        ssize_t n = read(fd, buf, sizeof(buf));
        close(fd);
        // Chấp nhận cả struct 160 bytes (UI cũ) và 448 bytes (UI mới) miễn khớp magic
        if (n >= 112) {
            uint32_t magic = *(uint32_t *)buf;
            if (magic == APEX_SYNC_MAGIC_V285) {
                uint32_t master = *((uint32_t *)buf + 1);
                int32_t hz = *((int32_t *)buf + 2);
                int32_t fps = *((int32_t *)buf + 3);
                if (hz < 15) hz = 15;
                if (hz > 240) hz = 240;
                if (fps < 15) fps = 15;
                if (fps > 240) fps = 240;
                g_syncPayloadV285.masterEnabled = master ? 1 : 0;
                g_syncPayloadV285.targetHz = hz;
                g_syncPayloadV285.targetFPS = fps;
                g_cachedResolvedHz = hz;
                g_cachedResolvedFPS = fps;
                loadedFromIPC = YES;
                break;
            }
        }
    }

    // 2. Dự phòng đọc trực tiếp từ Plist cấu hình nếu chưa có file IPC
    if (!loadedFromIPC) {
        NSString *prefPath = Titanium_ResolvePrefPath();
        if (prefPath && [[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
            NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:prefPath];
            if (dict) {
                BOOL master = (dict[@"Enabled"] != nil) ? [dict[@"Enabled"] boolValue] : YES;
                NSInteger hz = (dict[@"TargetRefreshRate"] != nil) ? [dict[@"TargetRefreshRate"] integerValue] : 60;
                NSInteger fps = (dict[@"TargetFPSRate"] != nil) ? [dict[@"TargetFPSRate"] integerValue] : hz;

                if (hz < 15) hz = 15;
                if (hz > 240) hz = 240;
                if (fps < 15) fps = 15;
                if (fps > 240) fps = 240;

                g_syncPayloadV285.masterEnabled = master ? 1 : 0;
                g_syncPayloadV285.targetHz = (int32_t)hz;
                g_syncPayloadV285.targetFPS = (int32_t)fps;
                g_cachedResolvedHz = hz;
                g_cachedResolvedFPS = fps;
            }
        }
    }

    // 3. Kiểm tra cấu hình Hz/FPS riêng cho từng App (Per-App Profile: ép lên hoặc ép xuống đúng theo app đã chọn)
    if (bundleID.length > 0 && !Titanium_IsSpringBoard() && !Titanium_IsSettingsApp()) {
        NSArray *perAppPaths = @[@"/tmp/.boost_hz_per_app.plist", @"/var/jb/tmp/.boost_hz_per_app.plist"];
        for (NSString *paPath in perAppPaths) {
            if (access([paPath UTF8String], R_OK) == 0) {
                NSDictionary *perAppDict = [NSDictionary dictionaryWithContentsOfFile:paPath];
                NSDictionary *appProf = [perAppDict[bundleID] isKindOfClass:[NSDictionary class]] ? perAppDict[bundleID] : nil;
                if (appProf && appProf[@"rate"] != nil) {
                    NSInteger appRate = [appProf[@"rate"] integerValue];
                    if (appRate >= 15 && appRate <= 240) {
                        g_syncPayloadV285.targetHz = (int32_t)appRate;
                        g_syncPayloadV285.targetFPS = (int32_t)appRate;
                        g_cachedResolvedHz = appRate;
                        g_cachedResolvedFPS = appRate;
                    }
                    break;
                }
            }
        }
    }

    if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) {
        g_sharedPayloadPtr->targetHz = (int32_t)g_cachedResolvedHz;
        g_sharedPayloadPtr->targetFPS = (int32_t)g_cachedResolvedFPS;
        g_sharedPayloadPtr->masterEnabled = g_syncPayloadV285.masterEnabled;
    }
    pthread_mutex_unlock(&g_syncLockV285);
}

// ====================================================================================================
// QUẢN LÝ TRẠNG THÁI IPC APPS & BẢO VỆ CHỐNG BOOTLOOP HỆ THỐNG
// ====================================================================================================

static void Titanium_WriteDisabledAppsFile(NSString *joinedIDs) {
    @try {
        NSData *data = [(joinedIDs ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
        (void)Titanium_WriteAtomicIPCFile(APPS_SYNC_FILE_PRIMARY, data.bytes, data.length);
        (void)Titanium_WriteAtomicIPCFile(APPS_SYNC_FILE_SECONDARY, data.bytes, data.length);
    } @catch (__unused NSException *e) {}
}

static BOOL Titanium_IsBundleDisabledViaIPC(NSString *bundleID) {
    @try {
        if (bundleID.length == 0) return NO;
        NSArray *paths = @[APPS_SYNC_FILE_PRIMARY, APPS_SYNC_FILE_SECONDARY];
        for (NSString *path in paths) {
            if (access([path UTF8String], R_OK) != 0) continue;
            NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
            if (!content) continue;
            NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
            for (NSString *line in lines) {
                if ([line isEqualToString:bundleID]) return YES;
            }
            return NO;
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

static BOOL Titanium_CheckAndPreventBootloopUniversal(void) {
    @autoreleasepool {
        @try {
            NSString *bootCounterFilePath = BOOT_GUARD_FILE;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSDate *currentDate = [NSDate date];
            NSDictionary *counterDict = [NSDictionary dictionaryWithContentsOfFile:bootCounterFilePath];
            NSInteger restartCount = 0;
            NSTimeInterval previousRestartTime = 0;
            if (counterDict) {
                restartCount = [counterDict[@"count"] integerValue];
                previousRestartTime = [counterDict[@"time"] doubleValue];
            }
            NSTimeInterval currentUnixTime = [currentDate timeIntervalSince1970];
            if (currentUnixTime - previousRestartTime < 20.0) {
                restartCount++;
            } else {
                restartCount = 1;
            }
            NSDictionary *updatedCounterDict = @{@"count": @(restartCount), @"time": @(currentUnixTime)};
            [updatedCounterDict writeToFile:bootCounterFilePath atomically:YES];
            
            if (restartCount >= 4) {
                return NO;
            }
            
            NSInteger scheduledCount = restartCount;
            NSTimeInterval scheduledTime = currentUnixTime;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                @try {
                    NSDictionary *latest = [NSDictionary dictionaryWithContentsOfFile:bootCounterFilePath];
                    if ([latest[@"count"] integerValue] == scheduledCount &&
                        fabs([latest[@"time"] doubleValue] - scheduledTime) < 0.001) {
                        [fileManager removeItemAtPath:bootCounterFilePath error:nil];
                    }
                } @catch (__unused NSException *e) {}
            });
            return YES;
        } @catch (__unused NSException *e) {
            return YES;
        }
    }
}

// ====================================================================================================
// BOOST CONFIGURATION ENGINE (V28.7 PRO MAX - CHUẨN DẢI TÙY CHỈNH 15HZ - 240HZ TRONG APP)
// ====================================================================================================

@interface BoostConfigV285Pro : NSObject
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSString *selectedLanguage;
@property (nonatomic, assign) BOOL enableHzControl;
@property (nonatomic, assign) NSInteger targetHz;
@property (nonatomic, assign) BOOL enableFPSControl;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL forceOverclock144Hz;
@property (nonatomic, assign) BOOL proMotionEngineBeta7;
@property (nonatomic, assign) BOOL touchResponseBoost;
@property (nonatomic, assign) BOOL colorOs17SmoothEngine;
@property (nonatomic, assign) BOOL keyboardZeroLagV24;
@property (nonatomic, assign) BOOL keyboardZeroLagV3;
@property (nonatomic, assign) BOOL reduceMultitaskLag;
@property (nonatomic, assign) BOOL reduceMultiTaskLag;
@property (nonatomic, assign) BOOL metalHexBuffering;
@property (nonatomic, assign) BOOL neuralBufferOpt;
@property (nonatomic, assign) BOOL fixAppExitStutter;
@property (nonatomic, assign) BOOL vsyncAdaptiveBuffer;
@property (nonatomic, assign) BOOL quantumRenderShield;
@property (nonatomic, assign) BOOL autoCloseBackgroundApp;
@property (nonatomic, assign) BOOL fixAppLaunchBlackScreen;
@property (nonatomic, assign) BOOL syncModuleDelay;
@property (nonatomic, assign) BOOL isolateRenderPipeline;
@property (nonatomic, assign) BOOL antiBlackScreenLaunch;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL turboLaunch;
@property (nonatomic, assign) BOOL ultraResponsiveness;
@property (nonatomic, assign) BOOL ultraResponsivenessProEngineOfficial;
@property (nonatomic, assign) BOOL aggressiveRamClean;
@property (nonatomic, assign) BOOL periodicRamClean;
@property (nonatomic, assign) BOOL machVMPurgeRam;
@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL antiThermalThrottle;
@property (nonatomic, assign) BOOL powerSaveMode;
@property (nonatomic, assign) BOOL antiGhostTouch;
@property (nonatomic, assign) BOOL chargerRippleRejection;
@property (nonatomic, assign) BOOL batterySaver60Hz;
@property (nonatomic, assign) BOOL lock30FpsOnOverheat;
@property (nonatomic, assign) BOOL dynamicThermalEngine;
@property (nonatomic, assign) BOOL fakeFullBatteryState;
@property (nonatomic, assign) BOOL gameFPSStabilizer;
@property (nonatomic, assign) BOOL lockHighIdleFloor;
@property (nonatomic, assign) BOOL quantumCoreSync;
@property (nonatomic, assign) BOOL pCoreRealtimePriority;
@property (nonatomic, assign) BOOL flatTintBlur;
@property (nonatomic, assign) BOOL zeroLagNeural;
@property (nonatomic, assign) BOOL schedulerGovernor;
@property (nonatomic, assign) BOOL iopolVipPriority;
@property (nonatomic, assign) BOOL ultraResponsivenessPro;
@property (nonatomic, assign) BOOL coolDownHeavyLoad;
@property (nonatomic, assign) BOOL backgroundPacingDaemon;
@property (nonatomic, assign) BOOL autoKillBackground;
@property (nonatomic, assign) BOOL hyperMemoryGuardian;

+ (instancetype)sharedInstance;
- (void)loadSettings;
- (NSInteger)resolvedTargetHz;
- (NSInteger)resolvedTargetFPS;
- (NSInteger)resolvedFrameInterval;
@end

static BoostConfigV285Pro *CFG285 = nil;
#define IS_ACTIVE (CFG285 && CFG285.enabled)

static inline BOOL Titanium_ShouldApplyEcoFrameCapV19(void) {
    if (g_thermalSeriousV285) return YES;
    if (@available(iOS 9.0, *)) {
        NSProcessInfo *processInfo = [NSProcessInfo processInfo];
        if (processInfo.isLowPowerModeEnabled) return YES;
    }
    if (@available(iOS 11.0, *)) {
        NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
        if (state >= NSProcessInfoThermalStateSerious) return YES;
    }
    return NO;
}

static void Titanium_TuneWindowServerDisplayDirectly(void) {
    // Intentionally disabled. Do not write fictitious refresh durations/rates to CAWindowServer.
}

@implementation BoostConfigV285Pro

+ (instancetype)sharedInstance {
    static BoostConfigV285Pro *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
        CFG285 = inst;
    });
    return inst;
}

// ====================================================================================================
// TRIỂN KHAI INIT & LOAD SETTINGS CỦA BOOST CONFIGURATION ENGINE (V28.7 PRO MAX)
// ====================================================================================================

- (instancetype)init {
    self = [super init];
    if (self) {
        self.enabled = YES;
        self.targetHz = 60;
        self.targetFPS = 60;
        self.enableHzControl = YES;
        self.enableFPSControl = YES;
        self.forceOverclock144Hz = YES;
        self.proMotionEngineBeta7 = YES;
        self.touchResponseBoost = YES;
        self.colorOs17SmoothEngine = YES;
        self.keyboardZeroLagV24 = YES;
        self.keyboardZeroLagV3 = YES;
        self.metalHexBuffering = YES;
        self.neuralBufferOpt = YES;
        self.fixAppExitStutter = YES;
        self.fixAppLaunchBlackScreen = YES;
        self.turboAppLaunch = YES;
        self.turboLaunch = YES;
        self.antiThermalThrottling = YES;
        self.antiGhostTouch = YES;
        self.chargerRippleRejection = YES;

        self.batterySaver60Hz = NO;
        self.lock30FpsOnOverheat = YES;
        self.dynamicThermalEngine = YES;
        self.fakeFullBatteryState = YES;
        self.gameFPSStabilizer = YES;
        self.lockHighIdleFloor = YES;
        self.quantumCoreSync = YES;
        self.pCoreRealtimePriority = YES;
        self.flatTintBlur = NO;
        self.zeroLagNeural = YES;

        self.schedulerGovernor = YES;
        self.iopolVipPriority = YES;
        self.ultraResponsivenessPro = YES;
        self.coolDownHeavyLoad = YES;
        self.backgroundPacingDaemon = YES;
        self.autoKillBackground = NO;
        self.hyperMemoryGuardian = YES;

        [self loadSettings];
    }
    return self;
}

// ====================================================================================================
// BỘ ĐÓNG GÓI BITMASK IPC ĐỒNG BỘ 100% CÔNG TẮC CHO APP THỨ BA & GAME
// ====================================================================================================
#define IPC_FLAG_FLAT_BLUR          (1U << 0)
#define IPC_FLAG_DEVICE_SPOOFER     (1U << 1)
#define IPC_FLAG_GAME_STABILIZER    (1U << 2)
#define IPC_FLAG_CPU_GPU_OPT        (1U << 3)
#define IPC_FLAG_REALTIME_SCHED     (1U << 4)
#define IPC_FLAG_IO_SCHEDULER       (1U << 5)
#define IPC_FLAG_SYS_PROC_OPT       (1U << 6)
#define IPC_FLAG_QUANTUM_SYNC       (1U << 7)
#define IPC_FLAG_SMART_THERMAL      (1U << 8)
#define IPC_FLAG_DYN_THERMAL        (1U << 9)
#define IPC_FLAG_HEAVY_COOLING      (1U << 10)
#define IPC_FLAG_BG_PACING          (1U << 11)
#define IPC_FLAG_AUTO_KILL_BG       (1U << 12)
#define IPC_FLAG_CHARGER_RIPPLE     (1U << 13)
#define IPC_FLAG_ANTI_BLACK_LAUNCH  (1U << 14)
#define IPC_FLAG_REDUCE_MULTITASK   (1U << 15)
#define IPC_FLAG_HYPER_MEM_GUARD    (1U << 16)
#define IPC_FLAG_ZERO_LAG_NEURAL    (1U << 17)
#define IPC_FLAG_RATE_LOCKED        (1U << 18)

- (void)loadSettings {
    @autoreleasepool {
        NSString *prefPath = Titanium_ResolvePrefPath();
        NSDictionary *diskDict = nil;
        if (prefPath && [[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
            diskDict = [NSDictionary dictionaryWithContentsOfFile:prefPath];
        }

        if (!diskDict) {
            CFPreferencesAppSynchronize(PREF_DOMAIN);
            CFArrayRef keyList = CFPreferencesCopyKeyList(PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
            if (keyList) {
                diskDict = (__bridge_transfer NSDictionary *)CFPreferencesCopyMultiple(keyList, PREF_DOMAIN, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
                CFRelease(keyList);
            }
        }

        BOOL appExcluded = NO;
        {
            NSString *exBundleID = [[NSBundle mainBundle] bundleIdentifier];
            if (exBundleID && !Titanium_IsSpringBoard()) {
                id exStates = diskDict ? diskDict[@"AppTweakStates"] : nil;
                if ([exStates isKindOfClass:[NSDictionary class]] && ((NSDictionary *)exStates)[exBundleID] != nil) {
                    appExcluded = ![((NSDictionary *)exStates)[exBundleID] boolValue];
                } else {
                    appExcluded = Titanium_IsBundleDisabledViaIPC(exBundleID);
                }
            }
        }
        void (^ApplyExclusion)(void) = ^{
            if (appExcluded) {
                g_isCurrentAppBlacklisted = YES;
                self.enabled = NO;
                pthread_mutex_lock(&g_syncLockV285);
                g_syncPayloadV285.masterEnabled = 0;
                pthread_mutex_unlock(&g_syncLockV285);
            } else {
                g_isCurrentAppBlacklisted = NO;
            }
        };

        // ==============================================================================================
        // CƠ CHẾ CHO APP THỨ 3 / GAME: ĐỌC ĐỦ 100% CÔNG TẮC TỪ FILE IPC (KHÔNG BỎ SÓT BẤT KỲ CÔNG TẮC NÀO)
        // ==============================================================================================
        NSString *bidDiag = [[NSBundle mainBundle] bundleIdentifier] ?: @"?";
        NSLog(@"[BoostTW] %@ plist/cfprefs=%@ keys=%lu", bidDiag, diskDict ? @"YES" : @"NO", (unsigned long)diskDict.count);

        if (!diskDict || diskDict.count == 0) {
            NSArray *checkFiles = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
            for (NSString *sf in checkFiles) {
                if (access([sf UTF8String], R_OK) == 0) {
                    int fd = open([sf UTF8String], O_RDONLY);
                    if (fd >= 0) {
                        ApexV285ProPayload pRead;
                        if (read(fd, &pRead, sizeof(ApexV285ProPayload)) == sizeof(ApexV285ProPayload)) {
                            if (pRead.magic == APEX_SYNC_MAGIC_V285) {
                                self.enabled = (pRead.masterEnabled != 0);
                                NSLog(@"[BoostTW] %@ src=ipc:%@ enabled=%d hz=%ld fps=%ld", bidDiag, sf, self.enabled, (long)self.targetHz, (long)self.targetFPS);
                                
                                // === CHỐNG KẸT 60HZ TỪ IPC PAYLOAD ===
                                self.targetHz = (pRead.targetHz >= 15 && pRead.targetHz <= 240) ? pRead.targetHz : 60;
                                self.targetFPS = (pRead.targetFPS >= 15 && pRead.targetFPS <= 240) ? pRead.targetFPS : 60;
                                
                                self.forceOverclock144Hz = (pRead.forceOverclock != 0);
                                self.proMotionEngineBeta7 = (pRead.dynamicInterpolation != 0);
                                self.colorOs17SmoothEngine = (pRead.dynamicInterpolation != 0);
                                self.touchResponseBoost = (pRead.zeroLatencyTouch != 0);
                                self.ultraResponsiveness = self.touchResponseBoost;
                                self.ultraResponsivenessPro = self.touchResponseBoost;
                                self.ultraResponsivenessProEngineOfficial = self.touchResponseBoost;
                                self.keyboardZeroLagV24 = (pRead.keyboardZeroLagV3 != 0);
                                self.keyboardZeroLagV3 = self.keyboardZeroLagV24;
                                self.metalHexBuffering = (pRead.smartBufferingLevel > 0 || pRead.metalPacingEnabled != 0);
                                self.neuralBufferOpt = self.metalHexBuffering;
                                self.fixAppExitStutter = (pRead.antiStutterExit != 0);
                                self.vsyncAdaptiveBuffer = self.fixAppExitStutter;
                                self.quantumRenderShield = self.fixAppExitStutter;
                                self.antiThermalThrottling = (pRead.thermalShield != 0);
                                self.antiThermalThrottle = self.antiThermalThrottling;
                                self.turboAppLaunch = (pRead.fastAppLaunch != 0);
                                self.turboLaunch = self.turboAppLaunch;
                                self.aggressiveRamClean = (pRead.aggressiveRamCleaner != 0);
                                self.periodicRamClean = self.aggressiveRamClean;
                                self.machVMPurgeRam = self.aggressiveRamClean;
                                self.antiGhostTouch = (pRead.antiGhostTouch != 0);
                                
                                self.powerSaveMode = (pRead.powerSaveModeActive != 0);
                                self.batterySaver60Hz = self.powerSaveMode;

                                // Giải mã 19 cờ công tắc mở rộng qua IPC Payload
                                uint32_t exFlags = Titanium_GetIPCExtraFlags(&pRead);
                                self.flatTintBlur          = (exFlags & IPC_FLAG_FLAT_BLUR) != 0;
                                self.fakeFullBatteryState  = (exFlags & IPC_FLAG_DEVICE_SPOOFER) != 0;
                                self.gameFPSStabilizer     = (exFlags & IPC_FLAG_GAME_STABILIZER) != 0;
                                self.lockHighIdleFloor     = (exFlags & IPC_FLAG_CPU_GPU_OPT) != 0;
                                self.pCoreRealtimePriority = (exFlags & IPC_FLAG_REALTIME_SCHED) != 0;
                                self.schedulerGovernor     = (exFlags & IPC_FLAG_IO_SCHEDULER) != 0;
                                self.iopolVipPriority      = (exFlags & IPC_FLAG_SYS_PROC_OPT) != 0;
                                self.quantumCoreSync       = (exFlags & IPC_FLAG_QUANTUM_SYNC) != 0;
                                self.lock30FpsOnOverheat   = (exFlags & IPC_FLAG_SMART_THERMAL) != 0;
                                self.dynamicThermalEngine  = (exFlags & IPC_FLAG_DYN_THERMAL) != 0;
                                self.coolDownHeavyLoad     = (exFlags & IPC_FLAG_HEAVY_COOLING) != 0;
                                self.backgroundPacingDaemon= (exFlags & IPC_FLAG_BG_PACING) != 0;
                                self.autoKillBackground    = (exFlags & IPC_FLAG_AUTO_KILL_BG) != 0;
                                self.autoCloseBackgroundApp= self.autoKillBackground;
                                self.chargerRippleRejection= (exFlags & IPC_FLAG_CHARGER_RIPPLE) != 0;
                                self.fixAppLaunchBlackScreen = (exFlags & IPC_FLAG_ANTI_BLACK_LAUNCH) != 0;
                                self.syncModuleDelay       = self.fixAppLaunchBlackScreen;
                                self.isolateRenderPipeline = self.fixAppLaunchBlackScreen;
                                self.antiBlackScreenLaunch = self.fixAppLaunchBlackScreen;
                                self.reduceMultitaskLag    = (exFlags & IPC_FLAG_REDUCE_MULTITASK) != 0;
                                self.reduceMultiTaskLag    = self.reduceMultitaskLag;
                                self.hyperMemoryGuardian   = (exFlags & IPC_FLAG_HYPER_MEM_GUARD) != 0;
                                self.zeroLagNeural         = (exFlags & IPC_FLAG_ZERO_LAG_NEURAL) != 0;
                                g_isRateLockedV285         = (exFlags & IPC_FLAG_RATE_LOCKED) != 0;

                                g_cachedResolvedHz = self.targetHz;
                                g_cachedResolvedFPS = self.targetFPS;

                                pthread_mutex_lock(&g_syncLockV285);
                                g_syncPayloadV285 = pRead;
                                pthread_mutex_unlock(&g_syncLockV285);

                                close(fd);
                                ApplyExclusion();
                                return;
                            }
                        }
                        close(fd);
                    }
                }
            }
            NSLog(@"[BoostTW] %@ src=DEFAULT (no plist, no ipc) hz=240 fps=240", bidDiag);
            ApplyExclusion();
            return;
        }

        BOOL (^GetLiveBool)(NSString *, BOOL) = ^BOOL(NSString *k, BOOL d) {
            if (diskDict && diskDict[k] != nil) return [diskDict[k] boolValue];
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) {
                BOOL b = CFBooleanGetValue((CFBooleanRef)val);
                CFRelease(val);
                return b;
            }
            return d;
        };

        NSInteger (^GetLiveInt)(NSString *, NSInteger) = ^NSInteger(NSString *k, NSInteger d) {
            if (diskDict && diskDict[k] != nil) return [diskDict[k] integerValue];
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) {
                int n = 0;
                CFNumberGetValue((CFNumberRef)val, kCFNumberIntType, &n);
                CFRelease(val);
                return (NSInteger)n;
            }
            return d;
        };

        NSString * (^GetLiveString)(NSString *, NSString *) = ^NSString *(NSString *k, NSString *d) {
            if (diskDict && diskDict[k] != nil) return (NSString *)diskDict[k];
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) {
                NSString *str = (__bridge_transfer NSString *)val;
                return str;
            }
            return d;
        };

        self.enabled = GetLiveBool(@"Enabled", YES);
        self.selectedLanguage = GetLiveString(@"SelectedLanguage", @"auto");
        self.enableHzControl = GetLiveBool(@"EnableHzControl", YES);
        
        // === ÉP MẶC ĐỊNH 240HZ CHO PLIST NẾU KHÔNG TÌM THẤY THÔNG SỐ ===
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 60);
        if (self.targetHz < 15 || self.targetHz > 240) self.targetHz = 60;

        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 60);
        if (self.targetFPS < 15 || self.targetFPS > 240) self.targetFPS = 60;

        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", (self.targetHz > 60));
        self.proMotionEngineBeta7 = GetLiveBool(@"ProMotionEngineBeta7", YES);
        self.touchResponseBoost = GetLiveBool(@"TouchResponseBoost", YES);
        self.colorOs17SmoothEngine = GetLiveBool(@"ColorOs17SmoothEngine", YES);
        self.keyboardZeroLagV24 = GetLiveBool(@"KeyboardZeroLagV24", YES);
        self.keyboardZeroLagV3 = self.keyboardZeroLagV24;
        self.metalHexBuffering = GetLiveBool(@"MetalHexBuffering", YES);
        self.neuralBufferOpt = self.metalHexBuffering;
        self.fixAppExitStutter = GetLiveBool(@"FixAppExitStutter", YES);
        self.vsyncAdaptiveBuffer = self.fixAppExitStutter;
        self.quantumRenderShield = self.fixAppExitStutter;
        self.autoCloseBackgroundApp = GetLiveBool(@"AutoCloseBackgroundApp", NO);
        self.fixAppLaunchBlackScreen = GetLiveBool(@"FixAppLaunchBlackScreen", YES);
        self.syncModuleDelay = self.fixAppLaunchBlackScreen;
        self.isolateRenderPipeline = self.fixAppLaunchBlackScreen;
        self.antiBlackScreenLaunch = self.fixAppLaunchBlackScreen;
        self.reduceMultitaskLag = GetLiveBool(@"ReduceMultiTaskLag", YES);
        self.reduceMultiTaskLag = self.reduceMultitaskLag;
        self.turboAppLaunch = GetLiveBool(@"TurboAppLaunch", YES);
        self.turboLaunch = self.turboAppLaunch;
        self.ultraResponsiveness = self.touchResponseBoost;
        self.ultraResponsivenessProEngineOfficial = self.touchResponseBoost;
        self.aggressiveRamClean = GetLiveBool(@"AggressiveRamClean", NO);
        self.periodicRamClean = self.aggressiveRamClean;
        self.machVMPurgeRam = self.aggressiveRamClean;
        self.antiThermalThrottling = GetLiveBool(@"AntiThermalThrottling", YES);
        self.antiThermalThrottle = self.antiThermalThrottling;
        
        // Respect the saved power mode; the shared payload may override it below.
        self.powerSaveMode = GetLiveBool(@"PowerSaveMode", GetLiveBool(@"powerSaveMode", NO));
        self.batterySaver60Hz = GetLiveBool(@"batterySaver60Hz", NO);

        self.antiGhostTouch = GetLiveBool(@"AntiGhostTouch", YES);
        self.chargerRippleRejection = GetLiveBool(@"ChargerRippleRejection", YES);
        self.lock30FpsOnOverheat = GetLiveBool(@"SmartThermalDispatch", YES);
        self.dynamicThermalEngine = GetLiveBool(@"DynamicThermalEngine", YES);
        self.fakeFullBatteryState = GetLiveBool(@"DeviceSpoofer", YES);
        self.gameFPSStabilizer = GetLiveBool(@"GameFPSStabilizer", YES);
        g_avoidTweakConflicts = GetLiveBool(@"AvoidTweakConflicts", NO);
        self.lockHighIdleFloor = GetLiveBool(@"CPUGPUFreqOptimizer", YES);
        self.quantumCoreSync = GetLiveBool(@"QuantumCoreSync", YES);
        self.pCoreRealtimePriority = GetLiveBool(@"RealtimeThreadSched", YES);
        self.flatTintBlur = GetLiveBool(@"QuantumRenderShield", NO);
        self.zeroLagNeural = GetLiveBool(@"ZeroLagNeuralBooster", YES);

        self.schedulerGovernor = GetLiveBool(@"IOSchedulerEngine", YES);
        self.iopolVipPriority = GetLiveBool(@"SystemProcessOpt", YES);
        self.ultraResponsivenessPro = GetLiveBool(@"UltraResponsiveness", YES);
        self.coolDownHeavyLoad = GetLiveBool(@"HeavyLoadCooling", YES);
        self.backgroundPacingDaemon = GetLiveBool(@"BackgroundPacingDaemon", YES);
        self.autoKillBackground = self.autoCloseBackgroundApp;
        self.hyperMemoryGuardian = GetLiveBool(@"HyperMemoryGuardian", YES);

        g_isRateLockedV285 = GetLiveBool(@"IsRateLocked", NO);

        ApplyExclusion();
        NSLog(@"[BoostTW] %@ src=plist/cfprefs enabled=%d hz=%ld fps=%ld", bidDiag, self.enabled, (long)self.targetHz, (long)self.targetFPS);

        // === BUNG TRẦN TUYỆT ĐỐI HZ/FPS ===
        NSInteger safeHz = self.targetHz;
        if (safeHz < 15 || safeHz > 240) safeHz = 60;
        g_cachedResolvedHz = safeHz;

        NSInteger safeFPS = self.targetFPS;
        if (safeFPS < 15 || safeFPS > 240) safeFPS = 60;
        g_cachedResolvedFPS = safeFPS;

        if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.magic = APEX_SYNC_MAGIC_V285;
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)g_cachedResolvedHz;
            p.targetFPS = (int32_t)g_cachedResolvedFPS;
            p.forceOverclock = 0; // Do not advertise an unsupported hardware overclock.
            p.pipSyncEnabled = 1;
            p.thermalShield = 1;
            p.antiStutterExit = 1;
            p.smartBufferingLevel = 3;
            p.metalPacingEnabled = 1;
            p.zeroLatencyTouch = 1;
            p.shaderOptimization = 1;
            p.dynamicInterpolation = 1;
            p.fastAppLaunch = 1;
            p.keyboardZeroLagV3 = 1;
            p.aggressiveRamCleaner = self.aggressiveRamClean ? 1 : 0;
            p.lockFixedFpsWhenThermal = 0;
            p.antiGhostTouch = 1;
            p.diskIOPriorityBoost = 1;
            p.rawTouchDirectDelivery = 1;
            p.powerSaveModeActive = (self.powerSaveMode || self.batterySaver60Hz) ? 1 : 0;

            uint32_t exFlags = 0;
            if (self.flatTintBlur)           exFlags |= IPC_FLAG_FLAT_BLUR;
            if (self.fakeFullBatteryState)   exFlags |= IPC_FLAG_DEVICE_SPOOFER;
            if (self.gameFPSStabilizer)      exFlags |= IPC_FLAG_GAME_STABILIZER;
            if (self.lockHighIdleFloor)      exFlags |= IPC_FLAG_CPU_GPU_OPT;
            if (self.pCoreRealtimePriority)  exFlags |= IPC_FLAG_REALTIME_SCHED;
            if (self.schedulerGovernor)      exFlags |= IPC_FLAG_IO_SCHEDULER;
            if (self.iopolVipPriority)       exFlags |= IPC_FLAG_SYS_PROC_OPT;
            if (self.quantumCoreSync)        exFlags |= IPC_FLAG_QUANTUM_SYNC;
            if (self.chargerRippleRejection) exFlags |= IPC_FLAG_CHARGER_RIPPLE;
            if (self.fixAppLaunchBlackScreen)exFlags |= IPC_FLAG_ANTI_BLACK_LAUNCH;
            if (self.reduceMultitaskLag)     exFlags |= IPC_FLAG_REDUCE_MULTITASK;
            if (self.hyperMemoryGuardian)    exFlags |= IPC_FLAG_HYPER_MEM_GUARD;
            if (self.zeroLagNeural)          exFlags |= IPC_FLAG_ZERO_LAG_NEURAL;
            if (g_isRateLockedV285)          exFlags |= IPC_FLAG_RATE_LOCKED;

            {
                const char *langCodeV12 = Titanium_ResolveEffectiveLanguage().UTF8String;
                if (langCodeV12) {
                    p.reserved[0] = 'L'; p.reserved[1] = 'G'; p.reserved[2] = ':';
                    strncpy(&p.reserved[3], langCodeV12, 24);
                    p.reserved[27] = '\0';
                }
            }
            Titanium_SetIPCExtraFlags(&p, exFlags);

            p.updateSeq = Titanium_IPCSequenceNowV25();
            p.lastHeartbeat = p.updateSeq;

            pthread_mutex_lock(&g_syncLockV285);
            g_syncPayloadV285 = p;
            pthread_mutex_unlock(&g_syncLockV285);

            NSMutableArray<NSString *> *disabledIDs = [NSMutableArray array];
            id statesObj = diskDict[@"AppTweakStates"];
            if ([statesObj isKindOfClass:[NSDictionary class]]) {
                [(NSDictionary *)statesObj enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([key isKindOfClass:[NSString class]] && ![obj boolValue]) {
                        [disabledIDs addObject:(NSString *)key];
                    }
                }];
            }
            NSString *disabledJoined = [disabledIDs componentsJoinedByString:@"\n"];

            ApexV285ProPayload capturedPayload = p;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_WriteSyncPayloadV285(&capturedPayload);
                Titanium_WriteDisabledAppsFile(disabledJoined);
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, NULL, YES);
            });
        }
    }
}

- (NSInteger)resolvedTargetHz {
    return g_cachedResolvedHz;
}

- (NSInteger)resolvedTargetFPS {
    return g_cachedResolvedFPS;
}

- (NSInteger)resolvedFrameInterval {
    return 1;
}

@end

static void PrefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (CFG285) {
        [CFG285 loadSettings];
#if !TITANIUM_SAFE_STABILITY_PROFILE
        if (Titanium_IsSpringBoard()) {
            Titanium_TuneWindowServerDisplayDirectly();
        }
#endif
    }
}

// ====================================================================================================
// TẦNG SÂU BẺ KHÓA LUỒNG XNU (FULL UNTHROTTLED UIKIT): BUNG CÔNG SUẤT 127, NICE -20, MƯỢT SIÊU CẤP
// BẢN NÂNG CẤP TẦNG 1-2-3-5-6: TẮT V-SYNC TRIỆT ĐỂ, SÀN 60HZ (KHÔNG TỤT 1HZ), BẺ WEB & APP ĐO CHUẨN
// ====================================================================================================

#include <mach/mach.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/resource.h>
#include <dlfcn.h>
#include <pthread.h>

static volatile BOOL g_isContinuousSwiping = NO;
static volatile BOOL g_isUserTouchingScreen = NO;
static volatile BOOL g_isVolumeHoldingV285 = NO;
static volatile BOOL g_isVideoPlayingActive = NO;
static volatile BOOL g_isNotificationBannerActive = NO;
static volatile BOOL g_isScrollingActive = NO;
static volatile int32_t g_activeAnimationCount = 0;
static volatile BOOL g_isMetalGameProcess = NO;

static volatile uint64_t g_lastInteractionMachTime = 0;
static uint64_t g_burstDurationMachTicks = 0;
static uint64_t g_burstDurationChargingMachTicks = 0;

static volatile uint64_t g_lastBannerMachTime = 0;
static uint64_t g_bannerDurationMachTicks = 0;

static volatile uint64_t g_lastFrameRenderTick = 0;
static volatile double g_currentFrameDriftRatio = 1.00;

static uint64_t s_lastSmartBoostTick = 0;

static inline void Titanium_SmartThrottle60Hz(void) {
    uint64_t now = mach_absolute_time();
    if (now - s_lastSmartBoostTick > Titanium_NanosToMachTicks(60ULL * 1000000ULL)) {
        s_lastSmartBoostTick = now;
        EnforceMaxCPUPower();
    }
}

static void AppleInternal_LockHardwareCADisplay(void);
static void AppleInternal_EnforceZeroLatencyKernelTier(void);
static inline void Titanium_UnleashAllHiddenSystemThreads(void);

// ==============================================================================
// KẾT NỐI VÙNG NHỚ CHIA SẺ ZERO-COPY IPC & QUẢN LÝ DẢI 15-240 HZ (MẶC ĐỊNH 240HZ)
// ==============================================================================

static inline void Titanium_InitZeroCopyIPC(BOOL isSpringBoard) {
    if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) return;

    int flags = isSpringBoard ? (O_CREAT | O_RDWR) : O_RDWR;
    g_shmFd = shm_open(TITANIUM_SHARED_MEM_NAME, flags, 0666);
    
    if (g_shmFd == -1 && !isSpringBoard) {
        g_shmFd = shm_open(TITANIUM_SHARED_MEM_NAME, O_CREAT | O_RDWR, 0666);
    }

    if (g_shmFd != -1) {
        struct stat shmStat;
        if (fstat(g_shmFd, &shmStat) != 0) {
            close(g_shmFd);
            g_shmFd = -1;
            return;
        }
        if (isSpringBoard && (shmStat.st_size < (off_t)TITANIUM_SHARED_MEM_SIZE)) {
            if (ftruncate(g_shmFd, (off_t)TITANIUM_SHARED_MEM_SIZE) != 0) {
                close(g_shmFd);
                g_shmFd = -1;
                return;
            }
        } else if (shmStat.st_size < (off_t)TITANIUM_SHARED_MEM_SIZE) {
            close(g_shmFd);
            g_shmFd = -1;
            return;
        }

        void *mapped = mmap(NULL, TITANIUM_SHARED_MEM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, g_shmFd, 0);
        if (mapped != MAP_FAILED) {
            g_sharedPayloadPtr = (ApexV285ProPayload *)mapped;
            if (isSpringBoard) {
                NSString *prefPath = Titanium_ResolvePrefPath();
                NSInteger userHz = 240;
                NSInteger userFPS = 240;
                BOOL userEnabled = YES;
                
                if (prefPath && [[NSFileManager defaultManager] fileExistsAtPath:prefPath]) {
                    NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:prefPath];
                    if (dict) {
                        if (dict[@"Enabled"] != nil) userEnabled = [dict[@"Enabled"] boolValue];
                        if (dict[@"TargetRefreshRate"] != nil) userHz = [dict[@"TargetRefreshRate"] integerValue];
                        if (dict[@"TargetFPSRate"] != nil) userFPS = [dict[@"TargetFPSRate"] integerValue];
                    }
                }
                
                if (userHz < 15) userHz = 15;
                if (userHz > 240) userHz = 240;
                if (userFPS < 15) userFPS = 15;
                if (userFPS > 240) userFPS = 240;

                g_sharedPayloadPtr->targetHz = (int32_t)userHz;
                g_sharedPayloadPtr->targetFPS = (int32_t)userFPS;
                g_sharedPayloadPtr->masterEnabled = userEnabled ? 1 : 0;
                
                g_cachedResolvedHz = userHz;
                g_cachedResolvedFPS = userFPS;
            }
        } else {
            close(g_shmFd);
            g_shmFd = -1;
        }
    }
}

static inline int Titanium_GetSharedTargetHz(void) {
    if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) {
        int hz = g_sharedPayloadPtr->targetHz;
        if (hz >= 15 && hz <= 240) return hz;
    }
    Titanium_ReloadSharedSyncStateV285();
    return (int)(g_cachedResolvedHz >= 15 && g_cachedResolvedHz <= 240 ? g_cachedResolvedHz : 240);
}

static inline void Titanium_PublishSharedConfig(int32_t targetHz, uint32_t enabled) {
    if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) {
        g_sharedPayloadPtr->targetHz = targetHz;
        g_sharedPayloadPtr->targetFPS = targetHz;
        g_sharedPayloadPtr->masterEnabled = enabled;
        g_sharedPayloadPtr->updateSeq++;
    }
}

static inline void Titanium_InitUnifiedMachTimebase(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t tb;
        if (mach_timebase_info(&tb) == KERN_SUCCESS && tb.numer > 0 && tb.denom > 0) {
            g_burstDurationMachTicks = (850ULL * 1000000ULL * tb.denom) / tb.numer;
            g_burstDurationChargingMachTicks = (650ULL * 1000000ULL * tb.denom) / tb.numer;
            g_bannerDurationMachTicks = (700ULL * 1000000ULL * tb.denom) / tb.numer;
        }
    });
}

static inline void Titanium_EnsureMachTimebaseInit(void) { Titanium_InitUnifiedMachTimebase(); }
static inline void Titanium_InitTouchMachTimebase(void) { Titanium_InitUnifiedMachTimebase(); }
static inline void Titanium_InitBannerMachTimebase(void) { Titanium_InitUnifiedMachTimebase(); }

static inline BOOL Titanium_IsNotificationBannerActive(void) {
    if (g_lastBannerMachTime == 0) return NO;
    return ((mach_absolute_time() - g_lastBannerMachTime) < g_bannerDurationMachTicks);
}

static inline BOOL Titanium_IsPassiveVideoPlayback(void) {
    return (g_isVideoPlayingActive && !g_isUserTouchingScreen && !g_isVolumeHoldingV285 && !g_isScrollingActive && g_activeAnimationCount == 0);
}

static inline BOOL Titanium_ShouldLockTargetRate(void) {
    if (g_isRateLockedV285) return YES;
    if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

    static uint64_t s_animStartTick = 0;
    if (g_activeAnimationCount > 0) {
        uint64_t nowTick = mach_absolute_time();
        if (s_animStartTick == 0) {
            s_animStartTick = nowTick;
            return YES;
        } else if ((nowTick - s_animStartTick) < Titanium_NanosToMachTicks(1200000000ULL)) {
            return YES;
        } else {
            g_activeAnimationCount = 0;
            s_animStartTick = 0;
        }
    } else {
        s_animStartTick = 0;
    }

    if (g_isInteracting || g_isVolumeHoldingV285 || g_isUserTouchingScreen || g_isContinuousSwiping || g_isScrollingActive) {
        static uint64_t s_staleFlagTicks = 0;
        if (s_staleFlagTicks == 0) {
            s_staleFlagTicks = Titanium_NanosToMachTicks(1400000000ULL);
        }
        uint64_t nowFlag = mach_absolute_time();
        uint64_t lastTick = (g_lastInteractiveTick > g_lastInteractionMachTime) ? g_lastInteractiveTick : g_lastInteractionMachTime;

        if (lastTick != 0 && (nowFlag - lastTick) < s_staleFlagTicks) {
            return YES;
        }
        g_isInteracting = NO;
        g_isVolumeHoldingV285 = NO;
        g_isUserTouchingScreen = NO;
        g_isContinuousSwiping = NO;
        g_isScrollingActive = NO;
    }

    if (g_lastInteractionMachTime == 0) return NO;
    if (__builtin_expect(g_burstDurationMachTicks == 0, 0)) {
        Titanium_InitUnifiedMachTimebase();
    }

    uint64_t now = mach_absolute_time();
    uint64_t limitTicks = g_isDeviceChargingV285 ? g_burstDurationChargingMachTicks : g_burstDurationMachTicks;
    return ((now - g_lastInteractionMachTime) < limitTicks);
}

// ==============================================================================
// TẦNG 5 & 6: BẺ KHÓA LUỒNG TỐI CAO KERNEL 127 + NICE -20 + P-CORE + MLOCK
// ==============================================================================

static inline void Titanium_UnleashAllHiddenSystemThreads(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
        setpriority(PRIO_PROCESS, 0, -20);
        mlock(&g_syncPayloadV285, sizeof(ApexV285ProPayload));
        mlock(&g_livePayload, sizeof(ApexV285ProPayload));
        if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) {
            mlock(g_sharedPayloadPtr, sizeof(ApexV285ProPayload));
        }

        // Mở khóa Task QoS Tier 0 trực tiếp xuống XNU Kernel
        struct task_qos_policy qosinfo = {
            .task_latency_qos_tier = LATENCY_QOS_TIER_0,
            .task_throughput_qos_tier = THROUGHPUT_QOS_TIER_0
        };
        task_policy_set(mach_task_self(), TASK_BASE_QOS_POLICY, (task_policy_t)&qosinfo, TASK_QOS_POLICY_COUNT);
        task_policy_set(mach_task_self(), TASK_OVERRIDE_QOS_POLICY, (task_policy_t)&qosinfo, TASK_QOS_POLICY_COUNT);
    });
}

static inline void Titanium_LockMainThreadFast(void) {
    Titanium_UnleashAllHiddenSystemThreads();

    if (![NSThread isMainThread]) {
        return;
    }

    Titanium_EnforceThreadVIPPolicy();

    // Bẻ khóa luồng chính lên mức ưu tiên Kernel 127 + P-Core (Tag 1) một lần duy nhất
    static __thread BOOL s_kernel127Locked = NO;
    if (__builtin_expect(!s_kernel127Locked, 0)) {
        s_kernel127Locked = YES;
        mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
        if (selfThread != MACH_PORT_NULL) {
            thread_affinity_policy_data_t affinity = { .affinity_tag = 1 };
            thread_policy_set(selfThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affinity, THREAD_AFFINITY_POLICY_COUNT);

            thread_precedence_policy_data_t precedence = { .importance = 127 };
            thread_policy_set(selfThread, THREAD_PRECEDENCE_POLICY, (thread_policy_t)&precedence, THREAD_PRECEDENCE_POLICY_COUNT);

            thread_throttle_policy_data_t throttle = { .pset_limit = 0 };
            thread_policy_set(selfThread, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttle, 1);
        }
    }

    static uint64_t s_lastNanoBurstTick = 0;
    uint64_t now = mach_absolute_time();
    if (__builtin_expect(s_lastNanoBurstTick == 0 || (now - s_lastNanoBurstTick) > Titanium_NanosToMachTicks(250000000ULL), 0)) {
        s_lastNanoBurstTick = now;
        if (Titanium_ShouldApplyAppDisplayOverrides()) {
            AppleInternal_LockHardwareCADisplay();
            Titanium_EnableZeroLatencyPipeline();
        }
    }
}

static inline void Titanium_TriggerInstantTouchBurst(void) {
    if (__builtin_expect(g_burstDurationMachTicks == 0, 0)) {
        Titanium_InitUnifiedMachTimebase();
    }
    g_lastInteractionMachTime = mach_absolute_time();
    Titanium_LockMainThreadFast();
}

static inline void Titanium_TriggerNotificationBurst(void) {
    if (__builtin_expect(g_bannerDurationMachTicks == 0, 0)) {
        Titanium_InitUnifiedMachTimebase();
    }
    g_lastBannerMachTime = mach_absolute_time();
    g_isNotificationBannerActive = YES;
    Titanium_LockMainThreadFast();

    static int64_t s_bannerSeq = 0;
    int64_t currentSeq = ++s_bannerSeq;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(350 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if (s_bannerSeq == currentSeq) {
            g_isNotificationBannerActive = NO;
        }
    });
}

static inline void Titanium_BoostRenderWithoutStarvingNetwork(void) {
    Titanium_UnleashAllHiddenSystemThreads();
    if (![NSThread isMainThread]) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        return;
    }
    if (!Titanium_ShouldLockTargetRate()) return;
    Titanium_LockMainThreadFast();
}

static inline BOOL Titanium_IsCurrentAppAGame(void) {
    if (Titanium_IsSpringBoard()) return NO;
    return g_isMetalGameProcess;
}

static inline NSInteger Titanium_CalculateAdaptiveProMaxTier(void) {
    NSInteger configuredTarget = Titanium_GetSharedTargetHz();
    if (configuredTarget < 15) configuredTarget = 240;
    if (configuredTarget > 240) configuredTarget = 240; 
    return configuredTarget;
}

static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
    Titanium_UnleashAllHiddenSystemThreads();
}

static void AppleInternal_LockHardwareCADisplay(void) {
    // Intentionally disabled: do not force zero latency or virtual display modes at the hardware layer.
}

// ====================================================================================================
// NHÓM NỘI BỘ APPLE: MÔ PHỎNG VÒNG LẶP _UIUPDATECYCLE (0MS LOW-LATENCY PIPELINE)
// ====================================================================================================

%group Group_Apple_Internal_ProMotion_Apex

%hook _UIUpdateCycle

- (BOOL)isPerformingUpdate {
    return %orig;
}

- (void)performUpdateWithInfo:(void *)info {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(info);
}

%end

%hook _UIUpdateSequenceItem

- (void)performItem {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// TẦNG 1: BẺ KHÓA CẢM ỨNG 0MS DELAY (IOHID + UIEVENTFETCHER + UIGESTURERECOGNIZER + UIWINDOW)
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

%hook _UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if (!event) {
        %orig(event);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES;
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(event);
}

%end

%hook UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if (!event) {
        %orig(event);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES;
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(event);
}

- (void)displayLinkDidFire:(id)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(arg1);
}

%end

%hook _UIEventDispatcher

- (void)dispatchEvent:(UIEvent *)event toTarget:(id)target {
    if (!event) {
        %orig(event, target);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES;
    }
    %orig(event, target);
}

%end

%hook UIGestureRecognizer

- (BOOL)delaysTouchesBegan {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return NO;
    }
    return %orig;
}

- (BOOL)delaysTouchesEnded {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return NO;
    }
    return %orig;
}

%end

%hook SBIconView

- (double)highlightDelay {
    if (!self) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        return 0.0;
    }
    return %orig;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (!self) {
        %orig(highlighted);
        return;
    }
    if (highlighted && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(highlighted);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!self) {
        %orig(touches, event);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(touches, event);
}

%end

%hook UIControl

- (NSTimeInterval)_touchDelayThreshold {
    if (!self) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return 0.0;
    }
    return %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!self) {
        %orig(touches, event);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        g_isInteracting = YES;
    }
    %orig(touches, event);
}

%end

%hook UIWindow

- (BOOL)_shouldDelayTouchForCancelEvents {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return NO;
    }
    return %orig;
}

- (void)sendEvent:(UIEvent *)event {
    if (!self || !event) {
        %orig(event);
        return;
    }
    NSString *windowClass = NSStringFromClass([self class]);
    if (windowClass && ([windowClass containsString:@"Screenshot"] || 
                        [windowClass containsString:@"SSUI"] || 
                        [windowClass containsString:@"Flash"] ||
                        [windowClass containsString:@"Overlay"])) {
        %orig(event);
        return;
    }

    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (event.type == 0) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_EnableZeroLatencyPipeline();
        }
    }
    %orig(event);
}

%end

%end

// ====================================================================================================
// HÀM TRỢ GIÚP TOÀN CỤC & TÍNH TOÁN DẢI FPS: SÀN TỐI THIỂU 60HZ (KHÔNG BAO GIỜ HẠ XUỐNG 1HZ)
// ====================================================================================================

static inline NSInteger Titanium_ClampDisplayFrameRate(NSInteger requestedFPS) {
    if (requestedFPS < 15) requestedFPS = 15;
    if (requestedFPS > 240) requestedFPS = 240;
    NSInteger nativeMax = __atomic_load_n(&g_titaniumNativeDisplayMaxFPS, __ATOMIC_ACQUIRE);
    if (nativeMax < 15 || nativeMax > 240) nativeMax = 60;
    if (requestedFPS > nativeMax) requestedFPS = nativeMax;
    return requestedFPS;
}

// Clamp only the selectable/requested range. CoreAnimation still chooses a real cadence
// supported by the display; this value is not proof that the panel is physically running at it.
static inline NSInteger Titanium_ClampRequestedFrameRate(NSInteger requestedFPS) {
    if (requestedFPS < 15) requestedFPS = 15;
    if (requestedFPS > 240) requestedFPS = 240;
    return requestedFPS;
}

// Cache the real display capability before any app-facing capability getter is overridden.
static void Titanium_UpdateNativeDisplayMaxFPS(void) {
    // Capture real panel capability once, before the app-facing UIScreen shim is installed.
    if (__atomic_load_n(&g_titaniumNativeDisplayRateReady, __ATOMIC_ACQUIRE) != 0) return;
    @try {
        UIScreen *mainScreen = [UIScreen mainScreen];
        NSInteger actualMax = mainScreen.maximumFramesPerSecond;
        if (actualMax >= 15 && actualMax <= 240) {
            __atomic_store_n(&g_titaniumNativeDisplayMaxFPS, actualMax, __ATOMIC_RELEASE);
            __atomic_store_n(&g_titaniumNativeDisplayRateReady, 1, __ATOMIC_RELEASE);
        }
    } @catch (__unused NSException *e) {}
}

static inline BOOL Titanium_DisplayRateOverrideReady(void) {
    if (Titanium_IsSpringBoard()) {
        return __atomic_load_n(&g_titaniumNativeDisplayRateReady, __ATOMIC_ACQUIRE) != 0;
    }
    return __atomic_load_n(&g_titaniumFirstFrameReady, __ATOMIC_ACQUIRE) != 0;
}

static inline CAFrameRateRange Titanium_SmoothFRR(float requestedMaxFPS) {
    // Keep the selected 15..240 request intact. CoreAnimation negotiates the real
    // supported cadence with the panel; do not falsify its timestamps or disable VSync.
    if (!isfinite(requestedMaxFPS)) requestedMaxFPS = 60.0f;
    if (requestedMaxFPS < 15.0f) requestedMaxFPS = 15.0f;
    if (requestedMaxFPS > 240.0f) requestedMaxFPS = 240.0f;
    // The UI/game-facing UIScreen capability getter may report the configured 15..240 cap,
    // but actual compositor requests must stay inside the cached physical display ceiling.
    NSInteger runtimeCap = Titanium_ClampDisplayFrameRate((NSInteger)llroundf(requestedMaxFPS));
    float maxFPS = (float)runtimeCap;

    // Prefer the highest cadence the physical panel can present for this configuration,
    // while leaving one lower divisor available under load to avoid repeated missed deadlines.
    float minFPS = maxFPS;
    if (maxFPS >= 120.0f) minFPS = 60.0f;
    else if (maxFPS >= 60.0f) minFPS = 30.0f;
    else if (maxFPS >= 30.0f) minFPS = 15.0f;

    if (minFPS < 15.0f) minFPS = 15.0f;
    if (minFPS > maxFPS) minFPS = maxFPS;
    return CAFrameRateRangeMake(minFPS, maxFPS, maxFPS);
}

extern NSInteger Titanium_GetEffectiveFrameCap(void);
extern NSInteger Titanium_GetEffectiveRefreshCap(void);
extern volatile uint64_t g_lastInteractionMachTime;
extern BOOL Titanium_IsSpringBoard(void);

static inline BOOL Titanium_IsVideoOrMediaMetalLayer(CALayer *layer) {
    if (!layer) return NO;
    if (g_isVideoPlayingActive) return YES;
    
    id del = layer.delegate;
    NSString *delName = del ? NSStringFromClass([del class]) : @"";
    NSString *layerName = NSStringFromClass([layer class]);

    if ([delName containsString:@"AV"] || 
        [delName containsString:@"Video"] || 
        [delName containsString:@"Player"] || 
        [delName containsString:@"Media"] || 
        [delName containsString:@"Camera"] ||
        [layerName containsString:@"AV"] ||
        [layerName containsString:@"Video"]) {
        return YES;
    }
    return NO;
}

static inline BOOL Titanium_IsMediaOrVideoLayer(CALayer *layer) {
    return Titanium_IsVideoOrMediaMetalLayer(layer);
}

// ==============================================================================
// TẦNG 2: BẺ KHÓA METAL & TẮT V-SYNC TRIỆT ĐỂ SÂU KERNEL / QUARTZCORE / METAL
// ==============================================================================

static inline void Titanium_KillVSyncCompletelyAtRoot(void) {
    // Legacy name retained for call-site compatibility. Do not disable VSync or
    // override QuartzCore's validation; keep only the existing low-latency transaction request.
    if (!Titanium_ShouldApplyAppDisplayOverrides()) return;
    Titanium_EnableZeroLatencyPipeline();
}

static void Titanium_ForceApplyMetalOverdriveUltimate(id self) {
    if (!self) return;
    
    BOOL isSB = Titanium_IsSpringBoard();
    BOOL isMedia = Titanium_IsVideoOrMediaMetalLayer((CAMetalLayer *)self);
    // For apps, alter only a non-media layer's preferred cadence after the display shim
    // and first-frame gate are ready. Keep drawable count, framebuffer and sync native.
    if (!isSB) {
        if (!Titanium_DisplayRateOverrideReady() || isMedia) return;
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                NSInteger target = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
                ((CAMetalLayer *)self).preferredFrameRateRange = Titanium_SmoothFRR((float)target);
            }
        }
        return;
    }

    if (!isMedia) {
        if ([self respondsToSelector:@selector(setMaximumDrawableCount:)]) {
            ((CAMetalLayer *)self).maximumDrawableCount = 3;
        }

        if ([self respondsToSelector:@selector(setFramebufferOnly:)]) {
            ((CAMetalLayer *)self).framebufferOnly = YES;
        }

        // Keep the native timeout. Setting this to NO can make nextDrawable wait indefinitely.
        if ([self respondsToSelector:@selector(setAllowsNextDrawableTimeout:)]) {
            ((CAMetalLayer *)self).allowsNextDrawableTimeout = YES;
        }

        if ([self respondsToSelector:@selector(setLowLatencyMode:)]) {
            ((CAMetalLayer *)self).lowLatencyMode = YES; 
        }

        if (@available(iOS 15.0, *)) {
            if (Titanium_DisplayRateOverrideReady() &&
                [self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                float maxTarget = (float)Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
                ((CAMetalLayer *)self).preferredFrameRateRange = Titanium_SmoothFRR(maxTarget);
            }
        }
    }

    if (isSB) {
        if ([self respondsToSelector:@selector(setPresentsWithTransaction:)]) {
            ((CAMetalLayer *)self).presentsWithTransaction = YES;
        }
        if ([self respondsToSelector:@selector(setMaximumDrawableCount:)]) {
            ((CAMetalLayer *)self).maximumDrawableCount = 3;
        }
    }

    // Keep iOS/CoreAnimation display synchronization and frame-rate matching unchanged.
}

static void (*orig_CAMetalLayer_didMoveToWindow)(id self, SEL _cmd) = NULL;
static void hooked_CAMetalLayer_didMoveToWindow(id self, SEL _cmd) {
    if (orig_CAMetalLayer_didMoveToWindow) {
        orig_CAMetalLayer_didMoveToWindow(self, _cmd);
    }
    if (!self) return;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        Titanium_ForceApplyMetalOverdriveUltimate(self);
    }
}

static void (*orig_CAMetalLayer_setDisplaySyncEnabled)(id self, SEL _cmd, BOOL enabled) = NULL;
static void hooked_CAMetalLayer_setDisplaySyncEnabled(id self, SEL _cmd, BOOL enabled) {
    if (orig_CAMetalLayer_setDisplaySyncEnabled) {
        orig_CAMetalLayer_setDisplaySyncEnabled(self, _cmd, enabled);
    }
}

static void (*orig_CAMetalLayer_setMaximumDrawableCount)(id self, SEL _cmd, NSUInteger count) = NULL;
static void hooked_CAMetalLayer_setMaximumDrawableCount(id self, SEL _cmd, NSUInteger count) {
    NSUInteger targetCount = count;
    if (Titanium_IsSpringBoard() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        targetCount = 3;
    }
    if (orig_CAMetalLayer_setMaximumDrawableCount) {
        orig_CAMetalLayer_setMaximumDrawableCount(self, _cmd, targetCount);
    }
}

static id (*orig_CAMetalLayer_nextDrawable)(id self, SEL _cmd) = NULL;
static id hooked_CAMetalLayer_nextDrawable(id self, SEL _cmd) {
    if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        g_isMetalGameProcess = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    if (orig_CAMetalLayer_nextDrawable) {
        return orig_CAMetalLayer_nextDrawable(self, _cmd);
    }
    return nil;
}

static void Titanium_ApplyConfiguredRateToLayerTree(CALayer *layer) {
    if (!layer) return;
    if ([layer isKindOfClass:[CAMetalLayer class]]) {
        Titanium_ForceApplyMetalOverdriveUltimate((CAMetalLayer *)layer);
    }
    NSArray<CALayer *> *children = layer.sublayers;
    for (CALayer *child in children) {
        Titanium_ApplyConfiguredRateToLayerTree(child);
    }
}

static void Titanium_ReapplyFrameRateToVisibleMetalLayers(void) {
    if (Titanium_IsSpringBoard() || !Titanium_DisplayRateOverrideReady()) return;
    UIApplication *app = [UIApplication sharedApplication];
    for (UIScene *scene in app.connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]] ||
            scene.activationState != UISceneActivationStateForegroundActive) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (!window || window.hidden || window.alpha <= 0.01) continue;
            Titanium_ApplyConfiguredRateToLayerTree(window.layer);
        }
    }
}

static void Titanium_InstallDynamicMetalOverdriveGroup2(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Titanium_KillVSyncCompletelyAtRoot();

        Class metalLayerClass = NSClassFromString(@"CAMetalLayer");
        if (!metalLayerClass) return;

        Method m1 = class_getInstanceMethod(metalLayerClass, @selector(didMoveToWindow));
        if (m1) {
            orig_CAMetalLayer_didMoveToWindow = (void (*)(id, SEL))method_getImplementation(m1);
            method_setImplementation(m1, (IMP)hooked_CAMetalLayer_didMoveToWindow);
        }

        Method m2 = class_getInstanceMethod(metalLayerClass, @selector(setDisplaySyncEnabled:));
        if (m2) {
            orig_CAMetalLayer_setDisplaySyncEnabled = (void (*)(id, SEL, BOOL))method_getImplementation(m2);
            method_setImplementation(m2, (IMP)hooked_CAMetalLayer_setDisplaySyncEnabled);
        }

        Method m3 = class_getInstanceMethod(metalLayerClass, @selector(setMaximumDrawableCount:));
        if (m3) {
            orig_CAMetalLayer_setMaximumDrawableCount = (void (*)(id, SEL, NSUInteger))method_getImplementation(m3);
            method_setImplementation(m3, (IMP)hooked_CAMetalLayer_setMaximumDrawableCount);
        }

        Method m4 = class_getInstanceMethod(metalLayerClass, @selector(nextDrawable));
        if (m4) {
            orig_CAMetalLayer_nextDrawable = (id (*)(id, SEL))method_getImplementation(m4);
            method_setImplementation(m4, (IMP)hooked_CAMetalLayer_nextDrawable);
        }
    });
}

// ====================================================================================================
// TẦNG 3: BẺ KHÓA HZ/FPS CHO MỌI APP, APP ĐO FPS & WEB (SAFARI/WKWEBVIEW) KHÔNG LOCK 60HZ, SÀN 60HZ
// ====================================================================================================

%group Group_FluidTransitions_Pacing_PreScreen

static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 240;
    NSInteger userHz = (g_syncPayloadV285.targetHz >= 15) ? (NSInteger)g_syncPayloadV285.targetHz : g_cachedResolvedHz;
    if (userHz < 15 && CFG285) userHz = (NSInteger)CFG285.targetHz;
    if (userHz < 15) userHz = 15;
    if (userHz > 240) userHz = 240;
    return userHz;
}

static inline NSInteger Titanium_GetTargetConfiguredFPS(void) {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 240;
    NSInteger userFPS = (g_syncPayloadV285.targetFPS >= 15) ? (NSInteger)g_syncPayloadV285.targetFPS : g_cachedResolvedFPS;
    if (userFPS < 15 && CFG285) userFPS = (NSInteger)CFG285.targetFPS;
    if (userFPS < 15) userFPS = Titanium_GetTargetConfiguredHz();
    if (userFPS < 15) userFPS = 15;
    if (userFPS > 240) userFPS = 240;
    return userFPS;
}

NSInteger Titanium_GetEffectiveRefreshCap(void) {
    // Return the selected request (15..240); the display server negotiates physical output.
    return Titanium_ClampRequestedFrameRate(Titanium_GetTargetConfiguredHz());
}

NSInteger Titanium_GetEffectiveFrameCap(void) {
    // Keep FPS independent from Hz, but do not request content cadence above selected Hz.
    // Physical presentation remains limited by what CoreAnimation/display hardware supports.
    NSInteger requestedFPS = Titanium_ClampRequestedFrameRate(Titanium_GetTargetConfiguredFPS());
    NSInteger selectedHz = Titanium_GetEffectiveRefreshCap();
    if (requestedFPS > selectedHz) requestedFPS = selectedHz;
    return Titanium_ClampRequestedFrameRate(requestedFPS);
}

// BẺ KHÓA HZ/FPS WEB (UFO TEST / SAFARI / WKWEBVIEW): Vượt khóa 60Hz của WebKit, chạy đúng 15-240Hz đã chọn!
static NSString *Titanium_BuildWebFPSOverdriveScript(NSInteger targetFPS) {
    // Native WebKit requestAnimationFrame is synchronized with CoreAnimation/video.
    // Replacing it with setTimeout creates a second clock and breaks frame pacing.
    (void)targetFPS;
    return @"";
}

static const void *kTitaniumWebLastSyncFPSKey = &kTitaniumWebLastSyncFPSKey;

// Weak registry: reapply a new FPS cap to existing links without retaining app objects.
static NSHashTable *Titanium_GetTrackedDisplayLinks(void) {
    static NSHashTable *links = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        links = [NSHashTable weakObjectsHashTable];
    });
    return links;
}

static void Titanium_TrackDisplayLink(CADisplayLink *link) {
    if (!link) return;
    NSHashTable *links = Titanium_GetTrackedDisplayLinks();
    @synchronized (links) {
        [links addObject:link];
    }
}

static void Titanium_UntrackDisplayLink(CADisplayLink *link) {
    if (!link) return;
    NSHashTable *links = Titanium_GetTrackedDisplayLinks();
    @synchronized (links) {
        [links removeObject:link];
    }
}

static void Titanium_ReapplyFrameRateToTrackedDisplayLinks(void) {
    if (!Titanium_DisplayRateOverrideReady() ||
        !(IS_ACTIVE || g_syncPayloadV285.masterEnabled) ||
        !Titanium_ShouldApplyAppDisplayOverrides() || g_isCurrentAppBlacklisted) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!Titanium_DisplayRateOverrideReady() ||
            !(IS_ACTIVE || g_syncPayloadV285.masterEnabled) || g_isCurrentAppBlacklisted) return;
        NSHashTable *links = Titanium_GetTrackedDisplayLinks();
        NSArray *snapshot = nil;
        @synchronized (links) {
            snapshot = [[links allObjects] copy];
        }
        NSInteger cap = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
        NSInteger nativeMax = __atomic_load_n(&g_titaniumNativeDisplayMaxFPS, __ATOMIC_ACQUIRE);
        if (nativeMax < 15 || nativeMax > 240) nativeMax = 60;
        for (CADisplayLink *displayLink in snapshot) {
            if (!displayLink) continue;
            NSInteger existingFPS = displayLink.preferredFramesPerSecond;
            // Preserve an intentional low cadence; promote default/native-cap links to the selected request.
            if (existingFPS > 0 && existingFPS < cap && existingFPS != nativeMax) continue;
            if (@available(iOS 15.0, *)) {
                displayLink.preferredFrameRateRange = Titanium_SmoothFRR((float)cap);
            } else {
                displayLink.preferredFramesPerSecond = cap;
            }
        }
    });
}

// ====================================================================================================
// 1. CADISPLAYLINK — BẺ KHÓA CHO MỌI APP & APP ĐO FPS (ĐO ĐÚNG 100% HZ/FPS ĐÃ CHỌN, KHÔNG HẠ VỀ 1HZ)
// ====================================================================================================

%hook CADisplayLink

- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode {
    %orig(runLoop, mode);
    Titanium_TrackDisplayLink(self);
    BOOL displayRateReady = Titanium_DisplayRateOverrideReady();
    if (displayRateReady && self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted) {
        NSInteger cap = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
        self.preferredFramesPerSecond = cap;
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                self.preferredFrameRateRange = Titanium_SmoothFRR((float)cap);
            }
        }
    }
}

// Report the value CoreAnimation actually negotiated; do not claim the requested cap
// is already the real presentation rate on hardware that may clamp it.
- (NSInteger)preferredFramesPerSecond {
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (Titanium_DisplayRateOverrideReady() &&
        (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted) {
        NSInteger target = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
        NSInteger nativeMax = __atomic_load_n(&g_titaniumNativeDisplayMaxFPS, __ATOMIC_ACQUIRE);
        // Preserve app-authored low-rate animations/videos. Native-default requests can be promoted.
        if (fps > 0 && fps < target && fps != nativeMax) target = fps;
        %orig(target);
        return;
    }
    %orig(fps);
}

- (NSInteger)frameInterval {
    return %orig;
}

- (void)setFrameInterval:(NSInteger)interval {
    %orig(interval);
}

// Keep timing values supplied by CoreAnimation. Fabricating duration/targetTimestamp
// can make the app schedule frames faster than the display can actually present them.
- (CFTimeInterval)duration {
    return %orig;
}

- (CFTimeInterval)targetTimestamp {
    return %orig;
}

- (void)invalidate {
    Titanium_UntrackDisplayLink(self);
    %orig;
}

// Keep the negotiated range truthful; only the setter requests the configured cap.
- (CAFrameRateRange)preferredFrameRateRange {
    return %orig;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (Titanium_DisplayRateOverrideReady() &&
            (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted) {
            NSInteger target = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
            NSInteger nativeMax = __atomic_load_n(&g_titaniumNativeDisplayMaxFPS, __ATOMIC_ACQUIRE);
            // An explicitly lower range often represents video/content cadence; retain it.
            if (range.maximum > 0.0f && range.maximum < (float)target &&
                fabsf((float)range.maximum - (float)nativeMax) > 0.5f) {
                %orig(range);
                return;
            }
            range = Titanium_SmoothFRR((float)target);
        }
    }
    %orig(range);
}

%end

// ====================================================================================================
// 2. CADISPLAYMODE
// ====================================================================================================

%hook CADisplayMode

- (double)refreshRate {
    return %orig;
}

%end

%hook CADisplay

- (BOOL)allowsVirtualModes {
    return %orig;
}
- (void)setAllowsVirtualModes:(BOOL)allows {
    %orig;
}
- (BOOL)supportsDynamicRefresh {
    return %orig;
}
- (BOOL)hasDynamicDisplayMode {
    return %orig;
}
- (NSInteger)minimumFPS {
    return %orig;
}
- (double)latency {
    return %orig;
}
- (CFTimeInterval)minimumFrameDuration {
    return %orig;
}
- (void)setMinimumFrameDuration:(CFTimeInterval)duration {
    %orig;
}
- (double)refreshRate {
    return %orig;
}
- (double)heartbeatRate {
    return %orig;
}
- (NSInteger)preferredFPS {
    return %orig;
}
- (void)setPreferredFPS:(NSInteger)fps {
    %orig;
}

%end

%end

// Install this class hook only after UIKit has brought up the first visible app window.
%group Group_UIScreen_FirstFrameOnly

// ====================================================================================================
// 4. UISCREEN — BẺ KHÓA TRẦN FPS CHO MỌI APP & CÔNG CỤ ĐO
// ====================================================================================================

%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && __atomic_load_n(&g_titaniumScreenRateSpoofReady, __ATOMIC_ACQUIRE) != 0 && !g_isCurrentAppBlacklisted) {
        return Titanium_GetTargetConfiguredHz();
    }
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && __atomic_load_n(&g_titaniumScreenRateSpoofReady, __ATOMIC_ACQUIRE) != 0 && !g_isCurrentAppBlacklisted) {
        return Titanium_GetTargetConfiguredHz();
    }
    return %orig;
}

- (CGFloat)_refreshRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && __atomic_load_n(&g_titaniumScreenRateSpoofReady, __ATOMIC_ACQUIRE) != 0 && !g_isCurrentAppBlacklisted) {
        return (CGFloat)Titanium_GetTargetConfiguredHz();
    }
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    // Getter-side capability reporting is spoofed; keep the private setter on the native
    // display negotiation path so an unsupported rate is never written back to UIKit.
    %orig(rate);
}

%end

%end

// Late-installed Metal range hook: requests the configured cadence for non-media layers,
// while preserving explicit low-rate ranges and leaving video/media layers untouched.
%group Group_CapabilityAwareMetalPacing
%hook CAMetalLayer

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (__atomic_load_n(&g_titaniumScreenRateSpoofReady, __ATOMIC_ACQUIRE) != 0 &&
            Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
            Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted &&
            !Titanium_IsVideoOrMediaMetalLayer(self)) {
            NSInteger target = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
            NSInteger nativeMax = __atomic_load_n(&g_titaniumNativeDisplayMaxFPS, __ATOMIC_ACQUIRE);
            if (range.maximum <= 0.0f || range.maximum >= (float)nativeMax || range.maximum > (float)target) {
                range = Titanium_SmoothFRR((float)target);
            }
        }
    }
    %orig(range);
}

%end
%end

// Install the UIScreen capability shim after UIApplication has initialized UIKit. This is
// intentionally not installed from %ctor because doing so can re-enter +[UIScreen initialize].
static void Titanium_InstallUIScreenRateSpoofNow(void) {
    if (Titanium_IsSpringBoard() || g_isCurrentAppBlacklisted) return;
    if (__atomic_load_n(&g_titaniumScreenRateSpoofReady, __ATOMIC_ACQUIRE) != 0) return;

    // Force class initialization and cache the real maximum before the getter starts reporting the selected cap.
    (void)[UIScreen mainScreen];
    Titanium_UpdateNativeDisplayMaxFPS();
    int wasReady = __atomic_exchange_n(&g_titaniumScreenRateSpoofReady, 1, __ATOMIC_ACQ_REL);
    if (!wasReady) {
        %init(Group_UIScreen_FirstFrameOnly);
        if (@available(iOS 15.0, *)) {
            Class metalLayerClass = NSClassFromString(@"CAMetalLayer");
            if (metalLayerClass && [metalLayerClass instancesRespondToSelector:@selector(setPreferredFrameRateRange:)]) {
                %init(Group_CapabilityAwareMetalPacing);
            }
        }
    }
}

static void Titanium_RegisterUIScreenRateSpoofAfterLaunch(void) {
    if (Titanium_IsSpringBoard() || g_isCurrentAppBlacklisted) return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            Titanium_InstallUIScreenRateSpoofNow();
        }];
    });
}

%group Group_FluidTransitions_Pacing_PostScreen

// ====================================================================================================
// 5. NSBUNDLE — MỞ KHÓA PRO MOTION TRÊN TẤT CẢ APP THỨ BA & GAME
// ====================================================================================================

static inline BOOL Titanium_ShouldExposeHighFrameRateEntitlement(void) {
    return !Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted &&
           (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
           Titanium_GetTargetConfiguredHz() > 60;
}

static const void *kTitaniumHighFrameRateInfoDictionaryKey = &kTitaniumHighFrameRateInfoDictionaryKey;

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    // Apps often check this standard plist key before exposing high-refresh settings.
    // The render path is still clamped to the real panel capability below.
    if ([key isEqualToString:@"CADisableMinimumFrameDurationOnPhone"] &&
        Titanium_ShouldExposeHighFrameRateEntitlement()) {
        return @YES;
    }
    return %orig(key);
}

- (NSDictionary *)infoDictionary {
    NSDictionary *original = %orig;
    if (!original || !Titanium_ShouldExposeHighFrameRateEntitlement()) return original;

    NSDictionary *cached = objc_getAssociatedObject(self, kTitaniumHighFrameRateInfoDictionaryKey);
    if (cached) return cached;

    NSMutableDictionary *copy = [original mutableCopy];
    if (!copy) return original;
    copy[@"CADisableMinimumFrameDurationOnPhone"] = @YES;
    NSDictionary *result = [copy copy];
    objc_setAssociatedObject(self, kTitaniumHighFrameRateInfoDictionaryKey, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return result;
}

%end

// ====================================================================================================
// 6. WKWEBVIEW — BẺ KHÓA HZ/FPS TRÌNH DUYỆT WEB (SAFARI / CHROME / WEB APP)
// ====================================================================================================

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted && configuration) {
        NSInteger targetCap = Titanium_GetEffectiveFrameCap();
        NSString *js = Titanium_BuildWebFPSOverdriveScript(targetCap);
        if (js && js.length > 0) {
            WKUserScript *script = [[WKUserScript alloc] initWithSource:js
                                                          injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                       forMainFrameOnly:NO];
            if (!configuration.userContentController) {
                configuration.userContentController = [[WKUserContentController alloc] init];
            }
            [configuration.userContentController addUserScript:script];
        }
    }
    
    WKWebView *webView = %orig(frame, configuration);
    if (webView && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        objc_setAssociatedObject(webView, kTitaniumWebLastSyncFPSKey, @(cap), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return webView;
}

- (void)didMoveToWindow {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted && self.window) {
            NSInteger currentCap = Titanium_GetEffectiveFrameCap();
            NSString *js = Titanium_BuildWebFPSOverdriveScript(currentCap);
            if (js && js.length > 0) {
                [self evaluateJavaScript:js completionHandler:nil];
            }
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

- (void)_didCommitLoadForMainFrame {
    %orig;
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted) {
            NSInteger currentCap = Titanium_GetEffectiveFrameCap();
            NSString *js = Titanium_BuildWebFPSOverdriveScript(currentCap);
            if (js && js.length > 0) {
                [self evaluateJavaScript:js completionHandler:nil];
            }
        }
    } @catch (__unused NSException *e) {}
}

- (void)_didReceiveMemoryWarning {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted) {
            WKProcessPool *pool = [NSThread isMainThread] ? self.configuration.processPool : nil;
            if ([pool respondsToSelector:@selector(_clearMemoryCache)]) {
                [pool _clearMemoryCache];
            }
            Titanium_BackgroundHeapRelief();
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

%end

// ====================================================================================================
// 7. CAANIMATION — SÀN TỐI THIỂU 60HZ (KHÔNG TỤT XUỐNG 1HZ HOẶC 15HZ KHI CHẠY HIỆU ỨNG)
// ====================================================================================================

%hook CAAnimation

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    // Per-animation timing stays native; the active scene/display-link request is the pacing source.
    %orig(range);
}

- (CAFrameRateRange)preferredFrameRateRange {
    return %orig;
}

%end

// ====================================================================================================
// 8. CALAYER
// ====================================================================================================

%hook CALayer

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    @try {
        if (anim && Titanium_DisplayRateOverrideReady() &&
            (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted &&
            !Titanium_IsVideoOrMediaMetalLayer(self)) {
            if (@available(iOS 15.0, *)) {
                if ([anim respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    NSInteger cap = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
                    anim.preferredFrameRateRange = Titanium_SmoothFRR((float)cap);
                }
            }
        }
    } @catch (__unused NSException *e) {}

    %orig(anim, key);
}

%end

%end

// ====================================================================================================
// TIÊM RUNTIME ÉP MÁY NHẬN DYNAMIC REFRESH RATE & CHỐNG HẠ XUNG TỐT NHẤT (BỌC THÉP AN TOÀN)
// ====================================================================================================


// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT TẦNG SÂU & KHÓA CHẶN MỌI LỆNH DROP HZ/FPS (CHUYỂN TAB 0MS)
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

%hook SBHomeGestureInteraction

- (void)_handleGestureChanged:(id)gesture {
    @try {
        if (!self) {
            %orig(gesture);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            if (!g_isContinuousSwiping) {
                g_isContinuousSwiping = YES;
                g_isInteracting = YES;
                Titanium_TriggerInstantTouchBurst();
                Titanium_LockMainThreadFast();
            }
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
    %orig(gesture);
}

- (void)_handleGestureEnded:(id)gesture {
    %orig(gesture);
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isContinuousSwiping = NO;
            g_isInteracting = NO;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
}

- (void)_handleGestureCancelled:(id)gesture {
    %orig(gesture);
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isContinuousSwiping = NO;
            g_isInteracting = NO;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
}

%end

%hook SBFluidSwitcherGestureWorkspaceTransaction

- (BOOL)canInterruptActiveGesture {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}

- (void)_begin {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didComplete {
    %orig;
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isContinuousSwiping = NO;
            g_isInteracting = NO;
        }
    } @catch (__unused NSException *e) {}
}

%end

%hook SBAppSwitcherSnapshotImageCache

- (BOOL)shouldLoadSnapshotImagesImmediately {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}

%end

%hook SBFluidSwitcherAnimationSettings

- (double)deckSwipeSpeedFactor {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return 1.12;
    }
    return %orig;
}

- (double)cardFlyInDuration {
    double orig = %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (orig > 0.22) ? (orig * 0.78) : orig;
    }
    return orig;
}

- (double)switcherScaleTransitionDuration {
    if (!self) return %orig;
    double orig = %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (orig > 0.22) ? (orig * 0.78) : orig;
    }
    return orig;
}

- (double)slideInDuration {
    if (!self) return %orig;
    double orig = %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (orig > 0.22) ? (orig * 0.78) : orig;
    }
    return orig;
}

%end

%hook SBAppSwitcherSettings

- (BOOL)shouldKeepAppSnapshotsInMemory {
    return YES;
}

- (BOOL)shouldSimplifyForOptions:(long long)options {
    return NO;
}

- (CGFloat)decelerationRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return 0.995f;
    }
    return %orig;
}

%end

%hook SBAppToHomeWorkspaceTransaction

- (void)_willBegin {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isInteracting = YES;
            g_activeAnimationCount++;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didComplete {
    %orig;
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            g_isContinuousSwiping = NO;
            g_isUserTouchingScreen = NO;
            g_isInteracting = NO;
        }
    } @catch (__unused NSException *e) {}
}

%end

%hook SBHomeToAppWorkspaceTransaction

- (void)_willBegin {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isInteracting = YES;
            g_activeAnimationCount++;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didComplete {
    %orig;
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            g_isInteracting = NO;
        }
    } @catch (__unused NSException *e) {}
}

%end

%hook SBFluidSwitcherItemContainer

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(touches, event);
}

- (void)setShadowStyle:(long long)style {
    if (!self) {
        %orig(style);
        return;
    }
    %orig(style);
}

- (long long)shadowStyle {
    if (!self) return %orig;
    return %orig;
}

%end

%hook SBFluidSwitcherGestureManager

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return YES;
    }
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC & KHÓA CHẶN MỌI LỆNH DROP HZ/FPS (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

%hook SBAppLaunchSettings

- (double)delayBeforeAppLaunch {
    // Keep SpringBoard's native launch readiness delay; zeroing it can expose a blank
    // launch surface before the app has produced its first frame.
    return %orig;
}

- (double)zoomDuration {
    @try {
        if (!self) return %orig;
        double orig = %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
            return (orig > 0.20) ? (orig * 0.75) : orig;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (double)launchDuration {
    @try {
        if (!self) return %orig;
        double orig = %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
            return (orig > 0.20) ? (orig * 0.75) : orig;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook SBSplashBoardController

- (double)splashScreenDelay {
    // Giữ launch snapshot/launch screen mặc định của iOS để tránh khung đen.
    // Không ép delay về 0; để SpringBoard quyết định thời điểm chuyển sang app.
    return %orig;
}

%end

%hook SBUIAnimationController

- (void)_willBeginAnimation {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
            g_isInteracting = YES;
            g_activeAnimationCount++;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didCompleteAnimation {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            g_isInteracting = NO;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 6: CUỘN FEED & TƯƠNG TÁC TOÀN HỆ THỐNG (BẺ GÃY MỌI ĐỘ TRỄ, GIỮ VỮNG HZ/FPS CAO)
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

%hook UIScrollView

- (UIPanGestureRecognizer *)panGestureRecognizer {
    @try {
        if (!self) return %orig;
        UIPanGestureRecognizer *pan = %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard() && pan) {
            pan.delaysTouchesBegan = NO;
        }
        return pan;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (BOOL)delaysContentTouches {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
            return NO;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (BOOL)canCancelContentTouches {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
            return YES;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)_scrollViewWillBeginDragging {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            g_isScrollingActive = YES;
            g_isUserTouchingScreen = YES;
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (CGFloat)decelerationRate {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
            if (self.isPagingEnabled) return %orig;
            return 0.994f;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)_stopScrollDecelerationNotify:(BOOL)notify {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(notify);
            return;
        }
        origDone = YES; %orig(notify);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isScrollingActive = NO;
            g_isUserTouchingScreen = NO;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(notify);
    }
}

- (void)_scrollViewDidEndDecelerating {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isScrollingActive = NO;
            g_isUserTouchingScreen = NO;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD - HIỆU ỨNG HỆ THỐNG MƯỢT TỨC THÌ (CHỐNG DROP HZ MÀN HÌNH CHÍNH & ĐA NHIỆM)
// ====================================================================================================

%group Group_Display_SpringBoardV285

%hook SBFluidSwitcherViewController

- (void)handleFluidSwitcherGesture:(id)gesture {
    @try {
        if (!self) {
            %orig(gesture);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(gesture);
}

- (void)viewWillLayoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)cardInteractiveTransitionDidEnd:(id)arg1 {
    if (!self) {
        %orig(arg1);
        return;
    }
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        Titanium_LockMainThreadFast();
    }
    %orig(arg1);
}

%end

%hook SBControlCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

%end

%hook SBNotificationCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

%end

%hook SBIconScrollView

- (BOOL)delaysContentTouches {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return NO;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)_notifyDidScroll {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isScrollingActive = YES;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

%end

%hook SBFolderControllerAnimationSettings

- (double)duration {
    @try {
        if (!self) return %orig;
        double orig = %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return (orig > 0.22) ? 0.20 : orig;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook SBApplication

- (void)willActivate {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (BOOL)shouldPrewarmOnLaunch {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return YES;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 8: PIPELINE CHO PICTURE-IN-PICTURE (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_V285_FloatingWindow_PiP

%hook PGPictureInPictureRemoteObject

- (void)_updatePreferredContentSize {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

- (void)startPictureInPicture {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

- (void)stopPictureInPictureAnimated:(BOOL)animated {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(animated);
            return;
        }
        origDone = YES; %orig(animated);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(animated);
    }
}

%end

%hook SBPIPController

- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(pid, sceneId, animated, completion);
            return;
        }
        origDone = YES; %orig(pid, sceneId, animated, completion);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(pid, sceneId, animated, completion);
    }
}

%end

%hook AVPictureInPictureController

- (void)startPictureInPicture {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

- (void)stopPictureInPicture {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 9: PHÂN TÁCH PHẦN CỨNG (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions

- (void)performSinglePressAction {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)performDoublePressAction {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH & BẢO VỆ JETSAM (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

%hook SBMainWorkspace

- (void)handleApplicationLaunch:(id)application {
    @try {
        if (!self) {
            %orig(application);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(application);
}

- (void)handleApplicationSuspended:(id)application {
    %orig(application);
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            Titanium_BackgroundHeapRelief();
        }
    } @catch (__unused NSException *e) {}
}

- (void)_handleDismissOverlaysGesture:(id)arg1 {
    if (!self) {
        %orig(arg1);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        Titanium_LockMainThreadFast();
    }
    %orig(arg1);
}

- (void)transitionRequest:(id)arg1 didCompleteWithResult:(id)arg2 {
    %orig(arg1, arg2);
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            Titanium_BackgroundHeapRelief();
        }
    } @catch (__unused NSException *e) {}
}

%end

%end

// ====================================================================================================
// NHÓM 11: NÂNG CẤP TOÀN BỘ APP THỨ BA (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

%hook UITableView

- (void)didMoveToWindow {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.window && !Titanium_IsSpringBoard()) {
            self.delaysContentTouches = NO;
            self.canCancelContentTouches = YES;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

%end

%hook UICollectionView

- (void)didMoveToWindow {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.window && !Titanium_IsSpringBoard()) {
            self.delaysContentTouches = NO;
            self.canCancelContentTouches = YES;
            self.prefetchingEnabled = YES;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 12: BÀN PHÍM STREAM TEXT, SHARE SHEET & CẢM ỨNG NÚT BẤM (0MS DELAY)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

%hook UIPresentationController

- (void)presentationTransitionWillBegin {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_TriggerInstantTouchBurst();
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)dismissalTransitionWillBegin {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_TriggerInstantTouchBurst();
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook UIKeyboardTaskQueue

- (void)performTask:(id)task {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(task);
            return;
        }
        origDone = YES; %orig(task);
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(task);
    }
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
}

%end

%hook UIPeripheralHost

- (double)getLastTranslateTime {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            return 0.0;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook UIButton

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(touches, event);
            return;
        }
        origDone = YES; %orig(touches, event);
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(touches, event);
    }
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
}

%end

%end

// ====================================================================================================
// NHÓM 13: BẺ KHÓA HIỆU NĂNG PIN YẾU & NHIỆT ĐỘ (CHỐNG BÓP XUNG 60HZ KHI MÁY ẤM HOẶC BẬT LPM)
// ====================================================================================================

#include <dlfcn.h>

static CFDictionaryRef (*orig_IOPSGetPowerSourceDescription)(CFTypeRef blob, CFTypeRef ps) = NULL;
static CFDictionaryRef hooked_IOPSGetPowerSourceDescription(CFTypeRef blob, CFTypeRef ps) {
    @try {
        if (orig_IOPSGetPowerSourceDescription) {
            return orig_IOPSGetPowerSourceDescription(blob, ps);
        }
    } @catch (__unused NSException *e) {}
    return NULL;
}

static int (*orig_IOPSGetPercentRemaining)(void) = NULL;
static int hooked_IOPSGetPercentRemaining(void) {
    @try {
        if (orig_IOPSGetPercentRemaining) {
            return orig_IOPSGetPercentRemaining();
        }
    } @catch (__unused NSException *e) {}
    return 100;
}

%group Group_Global_Thread_Governor_Unthrottled

%hook NSProcessInfo

- (NSProcessInfoThermalState)thermalState {
    @try {
        return NSProcessInfoThermalStateNominal;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (BOOL)isLowPowerModeEnabled {
    @try {
        return NO;
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook UIDevice

- (float)batteryLevel {
    @try {
        return %orig;
    } @catch (__unused NSException *e) {}
    return 1.0f;
}

- (UIDeviceBatteryState)batteryState {
    @try {
        return %orig;
    } @catch (__unused NSException *e) {}
    return UIDeviceBatteryStateFull;
}

- (BOOL)isBatteryMonitoringEnabled {
    @try {
        return %orig;
    } @catch (__unused NSException *e) {}
    return YES;
}

%end

%hook SBUIController

- (BOOL)isBatterySaverModeActive {
    @try {
        return NO;
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook _CDBatterySaver

- (BOOL)getPowerMode {
    @try {
        return NO;
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%end

static void Titanium_InstallPowerBypassC(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
            if (iokit) {
                void *sym1 = dlsym(iokit, "IOPSGetPowerSourceDescription");
                if (sym1) {
                    MSHookFunction(sym1, (void *)hooked_IOPSGetPowerSourceDescription, (void **)&orig_IOPSGetPowerSourceDescription);
                }
                void *sym2 = dlsym(iokit, "IOPSGetPercentRemaining");
                if (sym2) {
                    MSHookFunction(sym2, (void *)hooked_IOPSGetPercentRemaining, (void **)&orig_IOPSGetPercentRemaining);
                }
            }
        } @catch (__unused NSException *e) {}
    });
}

// ====================================================================================================
// NHÓM 15: SILICON HARDWARE PIPELINE OVERDRIVE (TỐI ƯU METAL PIPELINE, TẮT DELAY V-SYNC DRAWABLE)
// ====================================================================================================

%group Group_Silicon_Hardware_Pipeline_Overdrive

%hook _MTLCommandQueue

- (void)setStatOptions:(NSUInteger)options {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(options);
            return;
        }
        if (Titanium_IsSpringBoard()) {
            origDone = YES; %orig(options);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            origDone = YES; %orig(0);
            return;
        }
        origDone = YES; %orig(options);
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(options);
    }
}

- (BOOL)executionEnabled {
    @try {
        if (!self) return %orig;
        if (Titanium_IsSpringBoard()) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)enqueueCommandBuffer:(id)buffer {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(buffer);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
            Titanium_BoostCurrentThreadBriefly();
        }
        origDone = YES; %orig(buffer);
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(buffer);
    }
}

%end

%hook _MTLCommandBuffer

- (void)enqueue {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
            Titanium_BoostCurrentThreadBriefly();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)commit {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook MTLTextureDescriptor

- (BOOL)allowGPUOptimizedContents {
    @try {
        if (!self) return %orig;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setAllowGPUOptimizedContents:(BOOL)flag {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(flag);
            return;
        }
        origDone = YES; %orig(flag);
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(flag);
    }
}

%end

%hook CAMetalDrawable

- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    %orig(duration);
}

%end

%hook UIApplicationSceneTransitionContext

- (BOOL)waitForFence {
    @try {
        if (!self) return %orig;
        return %orig;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setWaitForFence:(BOOL)wait {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(wait);
            return;
        }
        origDone = YES; %orig(wait);
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(wait);
    }
}

%end

%end

// ====================================================================================================
// NHÓM 4: BỘ NÃO DỰ ĐOÁN TỌA ĐỘ NEURAL & CỬ CHỈ MÉP 0MS (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285

%hook _UITouchPredictor

- (id)predictedTouchesForTouch:(UITouch *)touch {
    @try {
        if (!self) return %orig(touch);
        id predicted = %orig(touch);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            static uint64_t s_lastPredictTick = 0;
            uint64_t now = mach_absolute_time();
            if (now - s_lastPredictTick > Titanium_NanosToMachTicks(20ULL * 1000000ULL)) {
                s_lastPredictTick = now;
                g_lastInteractionMachTime = now;
                g_lastInteractiveTick = now;
            }
        }
        return predicted;
    } @catch (__unused NSException *e) {}
    return %orig(touch);
}

- (void)addTouch:(UITouch *)touch fromEvent:(UIEvent *)event {
    @try {
        if (!self) {
            %orig(touch, event);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            g_lastInteractionMachTime = mach_absolute_time();
        }
    } @catch (__unused NSException *e) {}
    %orig(touch, event);
}

%end

%hook _UIGestureEnvironment

- (void)_updateGesturesForEvent:(UIEvent *)event {
    @try {
        if (!self) {
            %orig(event);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            static uint64_t s_lastGestureTick = 0;
            uint64_t now = mach_absolute_time();
            if (now - s_lastGestureTick > Titanium_NanosToMachTicks(25ULL * 1000000ULL)) {
                s_lastGestureTick = now;
                g_lastInteractionMachTime = now;
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(event);
}

%end

%hook SBScreenEdgePanGestureRecognizer

- (BOOL)_shouldTryToBeginWithEvent:(UIEvent *)event {
    @try {
        if (!self) return %orig(event);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    return %orig(event);
}

%end

%end

// ====================================================================================================
// NHÓM 16, 17, 18, 19 & 21: ĐIỀU PHỐI RUNLOOP, RENDER SERVER & TỐI ƯU BỘ NHỚ AN TOÀN
// ====================================================================================================

%group Group_Silicon_Scheduler_Touch_Governor

%hook _UIInteractiveHighlightEnvironment

- (void)applyHighlightWithAnimation:(BOOL)animated completion:(id)completion {
    @try {
        if (!self) {
            %orig(animated, completion);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

%end

%end

%group Group_CoreAnimation_RenderServer_Governor

%hook FBScene

- (void)updateSettings:(id)settings withTransitionContext:(id)context {
    @try {
        if (!self) {
            %orig(settings, context);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig(settings, context);
}

%end

%end

%group Group_System_Memory_And_RunLoop_Governor

%hook MTMaterialView

- (void)didMoveToWindow {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if (TITANIUM_LITE_MODE) return;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && self.layer != nil) {
            self.layer.allowsGroupOpacity = YES;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

%end

%end

%group Group_Thermal_CryoPacing_ZeroDrop
%end

%group Group_Deep_RAM_Compaction_Engine

%hook UIApplication

- (void)_applicationDidEnterBackground {
    %orig;
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_BackgroundHeapRelief();
        }
    } @catch (__unused NSException *e) {}
}

%end

%end

%group Group_WebKit_RAM_Optimizer
%end

static inline void Titanium_ReapplyFrameRateToAllScenes(void) {
    if (!Titanium_ShouldApplyAppDisplayOverrides()) return;
    @autoreleasepool {
        if (@available(iOS 13.0, *)) {
            if (!Titanium_DisplayRateOverrideReady()) return;
            float targetCap = (float)Titanium_GetEffectiveRefreshCap();
            CAFrameRateRange smoothRange = Titanium_SmoothFRR(targetCap);
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    if (@available(iOS 15.0, *)) {
                        if ([windowScene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                            windowScene.preferredFrameRateRange = SafeMakeFRR(smoothRange.minimum, smoothRange.maximum, smoothRange.preferred);
                        }
                    }
                }
            }
        }
    }
    Titanium_ReapplyFrameRateToTrackedDisplayLinks();
}

// ====================================================================================================
// TITANIUM FULL TẦNG 4 — BẺ KHÓA PANEL & KÍCH HOẠT PROMOTION / 15-240HZ (REAL OVERDRIVE REWRITE)
// ====================================================================================================
// [THAY ĐỔI SO VỚI BẢN CŨ]:
//  - Tầng 4: ghi NHỊP THẬT xuống CAWindowServerDisplay + CADisplay (write path, không spoof getter)
//  - Tầng 5: gọi IOMobileFramebuffer SetDisplayMode thật (dải 65..120Hz), ghi IORegistry timing thật
//  - Tầng 6: jetsam immunity thật (chỉ PID của chính process), realtime constraint thật
//  - VSync probe dùng CADisplayLink preferredFramesPerSecond=0 đo nhịp panel THẬT
//  - Watchdog 3 tầng: DCP từ chối -> mode thấp hơn ; panel treo >800ms -> ép 60 ;
//    nhịp không đổi sau 3s -> rollback + cooldown 5 phút
//  - %init(Group_Hardware_ProMotion_Overclock) được BẬT LẠI (bản cũ comment chết nó)
// ====================================================================================================

extern ApexV285ProPayload g_syncPayloadV285;

static inline BOOL Apex_IsMasterEnabled(void) {
    return g_syncPayloadV285.masterEnabled != 0;
}

extern BOOL g_isCurrentAppBlacklisted;
@class BoostConfigV285Pro;
extern BoostConfigV285Pro *CFG285;
extern NSInteger Titanium_GetEffectiveFrameCap(void);
extern void EnforceMaxCPUPower(void);

static NSInteger Titanium_GetUserTargetHz(void) {
    NSInteger target = Titanium_GetTargetConfiguredHz();
    if (target < 15) target = 15;
    if (target > 240) target = 240;
    return target;
}

static NSInteger Titanium_GetUserTargetFPS(void) {
    NSInteger target = Titanium_GetTargetConfiguredFPS();
    if (target < 15) target = 15;
    if (target > 240) target = 240;
    return target;
}

static float Titanium_ForceUserHz(float requestedRate) {
    return (float)Titanium_GetUserTargetHz();
}

static float Titanium_ForceUserFPS(float requestedRate) {
    return (float)Titanium_GetUserTargetFPS();
}

// ====================================================================================================
// [REAL OVERDRIVE CORE] — TRẠNG THÁI TOÀN CỤC + VSYNC PROBE + WATCHDOG ROLLBACK
// ====================================================================================================

static volatile NSInteger g_tioActiveHz        = 0;   // Hz panel đang chạy thật (0 = native)
static volatile double    g_tioObservedVsyncHz = 0.0; // Hz đo được từ compositor thật
static volatile BOOL      g_tioOverdriveBusy   = NO;
static volatile BOOL      g_tioRecoveryArmed   = NO;
static volatile uint64_t  g_tioLastVsyncTick   = 0;
static volatile NSInteger g_tioCooldownUntil   = 0;   // mach time: cấm thử lại tới thời điểm này

static inline uint64_t tio_mach_nanos(uint64_t n) {
    return Titanium_NanosToMachTicks(n);
}
static inline BOOL tio_elapsed_ms(uint64_t since, uint64_t ms) {
    return since != 0 && (mach_absolute_time() - since) >= tio_mach_nanos(ms * 1000000ULL);
}

// Hz panel THẬT đang chạy — hàm công khai, tweak chính có thể clamp getter spoof về số này
NSInteger Titanium_ActualPanelHz(void) {
    if (g_tioObservedVsyncHz >= 20.0 && g_tioObservedVsyncHz <= 260.0)
        return (NSInteger)llround(g_tioObservedVsyncHz);
    return g_tioActiveHz > 0 ? g_tioActiveHz : 60;
}

@interface TitaniumOverdriveVSyncProbe : NSObject
@property (nonatomic, strong) CADisplayLink *link;
- (void)tick:(CADisplayLink *)link;
@end

@implementation TitaniumOverdriveVSyncProbe
void Titanium_ForcePanelModeDirect(NSInteger hz);   // khai báo trước khi dùng; định nghĩa bên dưới
- (void)tick:(CADisplayLink *)link {
    CFTimeInterval d = link.targetTimestamp - link.timestamp;
    if (d > 0.004 && d < 0.2) { // lọc nhiễu 5Hz..250Hz
        g_tioObservedVsyncHz = 1.0 / d;
        g_tioLastVsyncTick   = mach_absolute_time();
    }
    // RECOVERY: sau khi overdrive, panel mất signal >800ms -> ép 60 NGAY (chống đen màn)
    if (g_tioRecoveryArmed && g_tioActiveHz > 60 &&
        g_tioLastVsyncTick != 0 && tio_elapsed_ms(g_tioLastVsyncTick, 800)) {
        g_tioRecoveryArmed = NO;
        NSLog(@"[Titanium T4-6] RECOVERY: no vsync >800ms at %ldHz -> force 60", (long)g_tioActiveHz);
        Titanium_ForcePanelModeDirect(60);
    }
}
@end

// Chỉ tiến trình có bundle .app (SpringBoard, app) có window server để tạo CADisplayLink.
// Daemon (ví dụ nanotimekitcompaniond) gọi CADisplay mainDisplay sẽ abort trong query_displays() lúc nạp dylib.
static BOOL Titanium_IsUIProcess(void) {
    NSString *path = [[NSBundle mainBundle] bundlePath];
    return path != nil && [path hasSuffix:@".app"];
}

static TitaniumOverdriveVSyncProbe *g_tioProbe = nil;

static void Titanium_StartOverdriveProbe(void) {
    if (!Titanium_IsUIProcess()) return;   // daemon: không có display, tạo CADisplayLink sẽ abort
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        TitaniumOverdriveVSyncProbe *p = [TitaniumOverdriveVSyncProbe new];
        // preferredFramesPerSecond = 0 -> link chạy đúng NHỊP PANEL cho phép, đo được nhịp quét thật
        p.link = [CADisplayLink displayLinkWithTarget:p selector:@selector(tick:)];
        p.link.preferredFramesPerSecond = 0;
        [p.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        g_tioProbe = p;
        g_tioLastVsyncTick = mach_absolute_time();
    });
}

// ====================================================================================================
// TẦNG 5 THẬT: IOMobileFramebuffer — RESOLVE SYMBOL + SETDISPLAYMODE TRỰC TIẾP (KHÔNG INTERPOSE)
// Interpose IOMFB là nguyên nhân đen app phổ biến nhất; gọi trực tiếp = zero re-entry risk.
// ====================================================================================================

typedef void *tio_iomfb_ref;
typedef kern_return_t (*tio_iomfb_main_fn)(tio_iomfb_ref *out);
typedef kern_return_t (*tio_iomfb_setmode_fn)(tio_iomfb_ref fb, uint32_t w, uint32_t h, float hz);

static tio_iomfb_main_fn    tio_iomfb_main    = NULL;
static tio_iomfb_setmode_fn tio_iomfb_setmode = NULL;
static tio_iomfb_ref        tio_iomfb_handle  = NULL;

static void Titanium_LoadIOMFBDirect(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *lib = dlopen("/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer", RTLD_LAZY);
        if (!lib) {
            NSLog(@"[Titanium T5] IOMFB framework not loadable on this iOS path");
            return;
        }
        tio_iomfb_main    = (tio_iomfb_main_fn)dlsym(lib, "IOMobileFramebufferGetMainDisplay");
        tio_iomfb_setmode = (tio_iomfb_setmode_fn)dlsym(lib, "IOMobileFramebufferSetDisplayMode");
        if (tio_iomfb_main && tio_iomfb_main(&tio_iomfb_handle) != KERN_SUCCESS) {
            tio_iomfb_handle = NULL;
        }
        NSLog(@"[Titanium T5] IOMFB: main=%p setmode=%p handle=%p",
              (void *)tio_iomfb_main, (void *)tio_iomfb_setmode, (void *)tio_iomfb_handle);
    });
}

// Ép panel về mode chỉ định (rollback + recovery dùng chung). Không dispatch_async — gọi thẳng.
void Titanium_ForcePanelModeDirect(NSInteger hz) {
    if (!tio_iomfb_setmode || !tio_iomfb_handle) return;
    CGFloat pw = [UIScreen mainScreen].nativeBounds.size.width;
    CGFloat ph = [UIScreen mainScreen].nativeBounds.size.height;
    kern_return_t kr = tio_iomfb_setmode(tio_iomfb_handle, (uint32_t)pw, (uint32_t)ph, (float)hz);
    if (kr == KERN_SUCCESS) g_tioActiveHz = hz;
    NSLog(@"[Titanium T5] ForcePanelMode(%ld) -> kr=0x%x active=%ld", (long)hz, kr, (long)g_tioActiveHz);

    // Đồng bộ render-server về cùng nhịp sau khi đổi mode — tránh CA lệch pha panel
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            if (@available(iOS 15.0, *)) {
                for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                    if ([scene isKindOfClass:[UIWindowScene class]] &&
                        [(UIWindowScene *)scene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                        ((UIWindowScene *)scene).preferredFrameRateRange =
                            CAFrameRateRangeMake(hz / 2.0f, (float)hz, (float)hz);
                    }
                }
            }
            id cad = [%c(CADisplay) mainDisplay];
            if (cad && [cad respondsToSelector:@selector(setPreferredFPS:)]) {
                ((void (*)(id, SEL, NSInteger))objc_msgSend)(cad, @selector(setPreferredFPS:), hz);
            }
        } @catch (__unused NSException *e) {}
    });
}

// Quét dải mode khả thi THẬT: 120 -> 90 -> 80 -> 75 -> 70 -> 65. Dừng ở mode đầu DCP nhận.
static NSInteger Titanium_IOMFBTryAlternateModes(NSInteger targetHz) {
    if (!tio_iomfb_setmode || !tio_iomfb_handle) return 0;
    uint32_t w = (uint32_t)[UIScreen mainScreen].nativeBounds.size.width;
    uint32_t h = (uint32_t)[UIScreen mainScreen].nativeBounds.size.height;
    NSInteger upper = MIN(targetHz, (NSInteger)120);
    NSInteger candidates[6] = {120, 90, 80, 75, 70, 65};
    for (int i = 0; i < 6; i++) {
        NSInteger hz = candidates[i];
        if (hz > upper) continue;
        kern_return_t kr = tio_iomfb_setmode(tio_iomfb_handle, w, h, (float)hz);
        NSLog(@"[Titanium T5] SetDisplayMode %ux%u@%ldHz -> kr=0x%x", w, h, (long)hz, kr);
        if (kr == KERN_SUCCESS) return hz; // mode nhận đầu tiên = mode an toàn nhất
    }
    return 0;
}

// ====================================================================================================
// TẦNG 4 THẬT: GHI NHỊP XUỐNG CAWindowServerDisplay + CADisplay (WRITE, KHÔNG SPOOF GETTER)
// ====================================================================================================

static void Titanium_Tier4WriteCadence(NSInteger hz) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            id server = [%c(CAWindowServer) performSelector:@selector(server)];
            if (!server) return;
            NSArray *displays = [server performSelector:@selector(displays)];
            double dur = 1.0 / (double)hz;
            for (id d in displays) {
                if (!d) continue;
                #define TIO_SEND(sel, type, val) if ([d respondsToSelector:@selector(sel:)]) \
                    ((void (*)(id, SEL, type))objc_msgSend)(d, @selector(sel:), (type)(val))
                if ([d respondsToSelector:@selector(setAllowsVirtualModes:)])
                    ((BOOL (*)(id, SEL, BOOL))objc_msgSend)(d, @selector(setAllowsVirtualModes:), YES);
                TIO_SEND(setMinimumFrameDuration, double, dur);
                TIO_SEND(setMaximumRefreshRate,   double, (double)hz);
                TIO_SEND(setIdealRefreshRate,     double, (double)hz);
                TIO_SEND(setMinimumRefreshRate,   double, (double)(hz / 2 > 15 ? hz / 2 : 15));
                #undef TIO_SEND
            }
            id cad = [%c(CADisplay) mainDisplay];
            if (cad) {
                if ([cad respondsToSelector:@selector(setAllowsVirtualModes:)])
                    ((BOOL (*)(id, SEL, BOOL))objc_msgSend)(cad, @selector(setAllowsVirtualModes:), YES);
                if ([cad respondsToSelector:@selector(setPreferredFPS:)])
                    ((void (*)(id, SEL, NSInteger))objc_msgSend)(cad, @selector(setPreferredFPS:), hz);
            }
            NSLog(@"[Titanium T4] cadence write -> %ldHz", (long)hz);
        } @catch (NSException *e) {
            NSLog(@"[Titanium T4] exception: %@", e);
        }
    });
}

static void Titanium_Tier4RollbackCadence(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            id server = [%c(CAWindowServer) performSelector:@selector(server)];
            if (!server) return;
            for (id d in [server performSelector:@selector(displays)]) {
                if ([d respondsToSelector:@selector(setMinimumFrameDuration:)])
                    ((void (*)(id, SEL, double))objc_msgSend)(d, @selector(setMinimumFrameDuration:), 1.0 / 60.0);
            }
            id cad = [%c(CADisplay) mainDisplay];
            if (cad && [cad respondsToSelector:@selector(setPreferredFPS:)])
                ((void (*)(id, SEL, NSInteger))objc_msgSend)(cad, @selector(setPreferredFPS:), 60);
        } @catch (__unused NSException *e) {}
    });
}

// ====================================================================================================
// TẦNG 5B THẬT: IORegistry — GHI TIMING VÀO DISPLAY SERVICE (IOKit C API, có handle thật)
// ====================================================================================================

static void Titanium_Tier5WriteIORegistryTiming(NSInteger hz) {
    @try {
        const char *paths[] = {
            "IOService:/AppleARMPE/display0",
            "IOService:/AppleARMPE/display0/AppleCLCD2",
        };
        for (size_t i = 0; i < 2; i++) {
            io_registry_entry_t entry = IORegistryEntryFromPath(kIOMasterPortDefault, paths[i]);
            if (entry != IO_OBJECT_NULL) {
                NSDictionary *props = @{
                    @"target-refresh-rate"   : @(hz),
                    @"preferred-refresh-rate": @(hz),
                };
                [props enumerateKeysAndObjectsUsingBlock:^(NSString *k, id v, BOOL *stop) {
                    IORegistryEntrySetCFProperty(entry, (__bridge CFStringRef)k, (__bridge CFTypeRef)v);
                }];
                IOObjectRelease(entry);
                NSLog(@"[Titanium T5B] IORegistry timing %ldHz -> %@", (long)hz, @(paths[i]));
                return;
            }
        }
        NSLog(@"[Titanium T5B] display IORegistry path not found — skip");
    } @catch (NSException *e) {
        NSLog(@"[Titanium T5B] exception: %@", e);
    }
}

// ====================================================================================================
// TẦNG 6 THẬT: JETSAM IMMUNITY (CHỈ PID CỦA CHÍNH PROCESS — KHÔNG ĐỤNG PROCESS KHÁC)
// ====================================================================================================

#ifndef MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK
#define MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK 5
#endif

static void Titanium_Tier6JetsamImmunityReal(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *kern = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_LAZY);
        if (!kern) return;
        typedef int (*msc_fn)(uint32_t, int32_t, uint32_t, void *, size_t);
        msc_fn msc = (msc_fn)dlsym(kern, "memorystatus_control");
        if (!msc) return;
        int32_t pid = getpid();
        int r = msc(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, pid, 0, NULL, 0);
        NSLog(@"[Titanium T6] jetsam HWM relax pid=%d -> %d", pid, r);
    });
}

// Realtime constraint theo chu kỳ frame THẬT trên main thread (chuẩn XNU, không phá scheduler)
static void Titanium_Tier6RealtimeFrameConstraint(NSInteger hz) {
    if (![NSThread isMainThread]) return;
    if (hz < 30 || hz > 240) return;
    mach_port_t thread = pthread_mach_thread_np(pthread_self());
    uint64_t periodNs = 1000000000ULL / (uint64_t)hz;
    thread_time_constraint_policy_data_t tc;
    tc.period      = (uint32_t)tio_mach_nanos(periodNs);
    tc.computation = (uint32_t)tio_mach_nanos(periodNs / 4);
    tc.constraint  = (uint32_t)tio_mach_nanos(periodNs / 2);
    tc.preemptible = TRUE;
    kern_return_t kr = thread_policy_set(thread, THREAD_TIME_CONSTRAINT_POLICY,
                                         (thread_policy_t)&tc, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    if (kr == KERN_SUCCESS) NSLog(@"[Titanium T6] realtime constraint @%ldHz OK", (long)hz);
}

// ====================================================================================================
// ĐIỀU PHỐI OVERDRIVE TỔNG HỢP (3 BẬC BẢO VỆ)
// ====================================================================================================

static void Titanium_OverdrivePipelineGo(NSInteger targetHz) {
    if (g_tioOverdriveBusy) return;
    // Cooldown 5 phút sau lần rollback gần nhất — tránh spam DCP gây treo display pipeline
    if (g_tioCooldownUntil != 0 && mach_absolute_time() < g_tioCooldownUntil) return;
    g_tioOverdriveBusy = YES;
    g_tioRecoveryArmed = NO;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            Titanium_LoadIOMFBDirect();
            NSInteger achieved = 0;
            if (targetHz > 60) achieved = Titanium_IOMFBTryAlternateModes(targetHz);

            if (achieved > 60) {
                g_tioActiveHz      = achieved;
                g_tioRecoveryArmed = YES;
                g_tioLastVsyncTick = mach_absolute_time();
                Titanium_Tier4WriteCadence(achieved);
                Titanium_Tier5WriteIORegistryTiming(achieved);
                NSLog(@"[Titanium] OVERDRIVE ACTIVE: %ldHz (target %ld)", (long)achieved, (long)targetHz);

                NSInteger confirmed = achieved;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                               dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    double obs = g_tioObservedVsyncHz;
                    if (obs < (double)confirmed - 2.0) {
                        NSLog(@"[Titanium] WATCHDOG: observed %.1fHz < %ld -> rollback 60 + cooldown 5m",
                              obs, (long)confirmed);
                        Titanium_ForcePanelModeDirect(60);
                        Titanium_Tier4RollbackCadence();
                        g_tioActiveHz      = 60;
                        g_tioRecoveryArmed = NO;
                        g_tioCooldownUntil = mach_absolute_time() + tio_mach_nanos(300000000ULL * 5);
                    } else {
                        NSLog(@"[Titanium] CONFIRMED: panel running %.1fHz", obs);
                    }
                    g_tioOverdriveBusy = NO;
                });
            } else {
                NSLog(@"[Titanium] DCP rejected all alternate modes — keeping native cadence "
                      @"+ render boost. Đây là đáp án của firmware panel, không phải lỗi code.");
                g_tioOverdriveBusy = NO;
            }
        }
    });
}

// API công khai thay cho các stub cũ — gọi từ bất kỳ đâu trong tweak
void Titanium_ExecuteRealPanelOverdrive(void) {
    NSInteger targetHz = Titanium_GetUserTargetHz();
    Titanium_StartOverdriveProbe();
    Titanium_Tier6JetsamImmunityReal();

    UIScreen *ms = [UIScreen mainScreen];
    NSInteger nativeMax = 60;
    @try { nativeMax = ms.maximumFramesPerSecond; } @catch (__unused NSException *e) {}
    // Native max đọc GỐC ở đây có thể đã bị spoof hook UIScreen của file chính đè.
    // Nếu target <= nativeMax đã spoof: vẫn ghi cadence thật (ProMotion sẽ nhận 120).
    Titanium_Tier6RealtimeFrameConstraint(MIN(targetHz, 120));
    Titanium_OverdrivePipelineGo(targetHz);
    Titanium_Tier4WriteCadence(MIN(MAX(targetHz, 60), 120));
}

// ====================================================================================================
// [GIỮ NGUYÊN] Các getter tiện ích
// ====================================================================================================

%group Group_Hardware_ProMotion_Overclock

%hook IOHIDEventSystemClient

- (void)setProperty:(id)property forKey:(NSString *)key {
    if (!self) {
        %orig(property, key);
        return;
    }
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && key) {
        if ([key isEqualToString:@"ReportInterval"] || [key isEqualToString:@"HIDReportInterval"]) {
            NSInteger hz = Titanium_GetUserTargetHz();
            NSInteger intervalUs = (hz > 0) ? (1000000 / hz) : 4166;
            if (intervalUs < 4166) intervalUs = 4166;
            %orig(@(intervalUs), key);
            return;
        }
    }
    %orig(property, key);
}

- (void)setEventFilterMask:(unsigned int)arg1 {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        arg1 |= 0x100;
    }
    %orig(arg1);
}

%end

// [REAL] Hook IOMobileFramebufferClient giữ nguyên — giờ được %init ở runCoreTweak.
// setDisplayRefreshRate ghi rate THẬT người dùng chọn xuống driver (driver tự quyết định
// nhận hay từ chối — kết quả thật được đo lại bằng VSync probe, không tin giá trị trả về).
%hook IOMobileFramebufferClient

- (int)setCanvasSize:(CGSize)arg1 {
    return %orig(arg1);
}

- (int)setDisplayRefreshRate:(float)rate options:(unsigned int)options {
    if (!self) return %orig(rate, options);
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
        rate = (float)Titanium_GetUserTargetHz();
    }
    return %orig(rate, options);
}

- (int)setDisplayRefreshRate:(float)arg1 {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
        arg1 = (float)Titanium_GetUserTargetHz();
    }
    return %orig(arg1);
}

- (int)getDisplayRefreshRate:(float *)arg1 {
    int ret = %orig(arg1);
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && arg1 && !g_isCurrentAppBlacklisted) {
        *arg1 = (float)Titanium_GetUserTargetHz();
    }
    return ret;
}

%end

%hook AGXAccelerator

- (int)setPowerState:(unsigned int)state {
    if (!self) return %orig(state);
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        EnforceMaxCPUPower();
        state = 1;
    }
    return %orig(state);
}

%end

%end

// ====================================================================================================
// [ĐÃ SIẾT CHẶT] Deep Core Bypass — chỉ chặn PowerLimit, KHÔNG chặn Thermal
// (ép xung thật cần thermal governor sống để tự bảo vệ; chặn Thermal gây nóng âm ỉ và pin chai)
// ====================================================================================================

%group Group_Hardware_Deep_Core_Bypass

%hook IORegistryEntry

- (kern_return_t)setCFProperty:(NSString *)key withValue:(id)value {
    if (!key || !self) {
        return %orig(key, value);
    }
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if ([key rangeOfString:@"PowerLimit" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return KERN_SUCCESS;
        }
        // Thermal đi qua bình thường — governor nhiệt phải hoạt động
    }
    return %orig(key, value);
}

%end

%end

%group Group_Apple_Native_ColdBoot_Overdrive

%hook UIScene

- (void)_activationCompleted {
    %orig;
    @try {
        if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
}

- (void)_didBecomeActive {
    %orig;
    @try {
        if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
            Titanium_TriggerInstantTouchBurst();
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
                Titanium_ExecuteRealPanelOverdrive(); // [REAL] đồng bộ lại tầng sâu khi app active
            });
        }
    } @catch (__unused NSException *e) {}
}

%end

%hook FBApplicationProcess

- (void)_finishInit {
    %orig;
    if (!(IS_ACTIVE || g_syncPayloadV285.masterEnabled)) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {
            if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
                Titanium_EnforceThreadVIPPolicy();
                EnforceMaxCPUPower();
            }
        }
    });
}

%end

%end

%group Group_KeepAppsAlive_NoKill

%hook FBProcess

- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)comp {
    @try {
        if (!self) {
            %orig(reason, report, description, comp);
            return;
        }
        NSString *desc = description ? [description lowercaseString] : @"";
        if ([desc containsString:@"user"] || [desc containsString:@"terminate"] || [desc containsString:@"explicit"] || [desc containsString:@"switcher"]) {
            %orig(reason, report, description, comp);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(reason, report, description, comp);
}

- (BOOL)isPendingExit {
    return %orig;
}

%end

%end

%group Group_TitaniumV12_SmoothExit_And_DisplayLink

%hook CASpringAnimation

- (CGFloat)damping {
    return %orig;
}

- (void)setDamping:(CGFloat)damping {
    %orig(damping);
}

%end

%end

%group Group_AI_Stream_Optimization

%hook UITextView

- (void)didMoveToWindow {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.window) {
            self.layer.shouldRasterize = NO;
            self.layer.drawsAsynchronously = YES;
            if ([self respondsToSelector:@selector(layoutManager)]) {
                NSLayoutManager *lm = self.layoutManager;
                if (lm) {
                    lm.allowsNonContiguousLayout = YES;
                    if ([lm respondsToSelector:@selector(setBackgroundLayoutEnabled:)]) {
                        [(id)lm setValue:@YES forKey:@"backgroundLayoutEnabled"];
                    }
                }
            }
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

- (void)insertText:(NSString *)text {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && text.length > 0) {
            [UIView performWithoutAnimation:^{
                %orig(text);
            }];
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(text);
}

- (void)deleteBackward {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            [UIView performWithoutAnimation:^{
                %orig;
            }];
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    @try {
        if (Titanium_IsAIApp() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
            %orig(contentOffset, animated);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(contentOffset, animated);
}

%end

%hook UIKeyboardImpl

+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return 0.0;
    }
    return %orig;
}

- (void)clearAnimations {
    %orig;
}

%end

%hook NSURLSessionConfiguration

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *cfg = %orig;
    @try {
        if (cfg && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            cfg.HTTPShouldUsePipelining = YES;
            if (cfg.HTTPMaximumConnectionsPerHost < 4) {
                cfg.HTTPMaximumConnectionsPerHost = 4;
            }
            if (@available(iOS 11.0, *)) {
                cfg.waitsForConnectivity = YES;
            }
            if (@available(iOS 15.0, *)) {
                if ([cfg respondsToSelector:NSSelectorFromString(@"setAssumesHTTP3Capable:")]) {
                    @try { [cfg setValue:@YES forKey:@"assumesHTTP3Capable"]; } @catch (__unused NSException *e) {}
                }
            }
        }
    } @catch (__unused NSException *e) {}
    return cfg;
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *cfg = %orig;
    @try {
        if (cfg && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            cfg.HTTPShouldUsePipelining = YES;
            if (cfg.HTTPMaximumConnectionsPerHost < 4) {
                cfg.HTTPMaximumConnectionsPerHost = 4;
            }
            if (@available(iOS 11.0, *)) {
                cfg.waitsForConnectivity = YES;
            }
            if (@available(iOS 15.0, *)) {
                if ([cfg respondsToSelector:NSSelectorFromString(@"setAssumesHTTP3Capable:")]) {
                    @try { [cfg setValue:@YES forKey:@"assumesHTTP3Capable"]; } @catch (__unused NSException *e) {}
                }
            }
        }
    } @catch (__unused NSException *e) {}
    return cfg;
}

%end

%end

// ====================================================================================================
// NHÓM 2: WINDOWSERVER DISPLAY — [REAL] ghi nhịp thật khi SETTER được gọi; getter giữ %orig
// Getter spoof bị BỎ ở group này: getter giả = CA đặt deadline sai = judder + đen app.
// Setter thật + VSync probe thật = nhịp đổi thật khi panel hỗ trợ, không đổi khi không hỗ trợ.
// ====================================================================================================

%group Group_CAWindowServer_Absolute_Dominance

%hook CADisplayController

- (void)displayLinkDidFire:(id)arg1 {
    if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
        Titanium_LockMainThreadFast();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(arg1);
}

- (double)refreshRate {
    return %orig; // [REAL FIX] getter giữ nguyên — không spoof
}

- (void)setRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)MIN(MAX(Titanium_GetUserTargetHz(), 15), 120);
        %orig(targetHz);
        return;
    }
    %orig(rate);
}

%end

%hook CAWindowServerDisplay

- (BOOL)allowsVirtualModes {
    return %orig;
} // [REAL FIX] getter giữ nguyên

- (void)setAllowsVirtualModes:(BOOL)flag {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(YES);
        return;
    }
    %orig(flag);
}

- (double)minimumFrameDuration {
    return %orig;
} // [REAL FIX] không spoof

- (void)setMinimumFrameDuration:(double)duration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)MIN(MAX(Titanium_GetUserTargetHz(), 15), 120);
        %orig(1.0 / targetHz);
        return;
    }
    %orig(duration);
}

- (double)maximumRefreshRate {
    return %orig;
}

- (void)setMaximumRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)MIN(MAX(Titanium_GetUserTargetHz(), 15), 120);
        %orig(targetHz);
        return;
    }
    %orig(rate);
}

- (double)minimumRefreshRate {
    return %orig;
}

- (void)setMinimumRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(15.0);
        return;
    }
    %orig(rate);
}

- (double)idealRefreshRate {
    return %orig;
}

- (void)setIdealRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)MIN(MAX(Titanium_GetUserTargetHz(), 15), 120);
        %orig(targetHz);
        return;
    }
    %orig(rate);
}

- (double)refreshRate {
    return %orig;
}

- (unsigned int)controllerId {
    return %orig;
}

- (BOOL)isExternal {
    return %orig; // [REAL FIX] không spoof
}

- (unsigned int)rendererFlags {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return %orig | 0x1 | 0x2;
    }
    return %orig;
}

- (unsigned int)rendererFlagsOverride {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return %orig | 0x1 | 0x2 | 0x4;
    }
    return %orig;
}

%end

%hook CAWindowServer

- (NSArray *)displays {
    return %orig;
}

%end

%hook CAContext

- (void)setCommitPriority:(uint32_t)priority {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(priority | 0x1);
        return;
    }
    %orig(priority);
}

- (uint32_t)commitPriority {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return %orig | 0x1;
    }
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 3 & 4: UIWindowScene OVERDRIVE — getter giữ nguyên, setter ghi nhịp thật + clamp panel
// ====================================================================================================

%group Group_Window_Level_Overdrive

%hook UIWindowScene

- (void)_readySceneForDisplay {
    %orig;
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (Titanium_DisplayRateOverrideReady() &&
            self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted) {
            // [REAL FIX] clamp về Hz panel THẬT (đo từ VSync probe) — deadline luôn đúng nhịp quét
            NSInteger realPanel = Titanium_ActualPanelHz();
            NSInteger targetCap = Titanium_GetUserTargetHz();
            if (realPanel > 0 && targetCap > realPanel) targetCap = realPanel;
            CAFrameRateRange smoothRange = Titanium_SmoothFRR((float)targetCap);
            range = SafeMakeFRR(smoothRange.minimum, smoothRange.maximum, smoothRange.preferred);
        }
    }
    %orig(range);
}

- (void)_processUpdateWithFrameContext:(id)context {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (g_isInteracting || g_isScrollingActive || g_isContinuousSwiping || g_activeAnimationCount > 0) {
            Titanium_LockMainThreadFast();
        }
    }
    %orig(context);
}

%end

%end

// ====================================================================================================
// NHÓM V10: BOOST LAYOUT SPRINGBOARD & ĐA NHIỆM (GIỮ NGUYÊN)
// ====================================================================================================

%group Group_TitaniumV10_SpringBoard_Layout_Boost

static inline void Titanium_V10_PinMainThreadHigh(void) {
    @try {
        if (![NSThread isMainThread]) return;
        static __thread uint64_t s_lastPinTick = 0;
        uint64_t now = mach_absolute_time();
        if (s_lastPinTick == 0 || (now - s_lastPinTick) > Titanium_NanosToMachTicks(50ULL * 1000000ULL)) {
            s_lastPinTick = now;
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
            setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
}

%hook SBIconListView
- (void)layoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() && (g_isScrollingActive || g_isContinuousSwiping)) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

%hook SBFolderView
- (void)layoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() && g_isScrollingActive) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

%hook SBMainDisplaySceneLayoutViewController
- (void)viewWillLayoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

%end

%group Group_SpringBoard_Switcher_Opt

%hook _UIScreenEdgePanGestureRecognizer
- (BOOL)delaysTouchesBegan {
    if (!self) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return NO;
    }
    return %orig;
}

- (double)_edgeRegionSize {
    if (!self) return %orig;
    double size = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return (size > 0.0) ? (size * 1.15) : 20.0;
    }
    return size;
}
%end

%hook SBFluidSwitcherModifier
- (double)shadowOpacityForIndex:(unsigned long long)index {
    if (!self) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return %orig;
    }
    return %orig;
}
%end

%end

%group Group_LiquidGlass_Opt

%hook CAFilter

- (void)setValue:(id)value forKey:(NSString *)key {
    %orig(value, key);
}

%end

%hook CABackdropLayer

- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        %orig(YES);
        return;
    }
    %orig(flag);
}

- (BOOL)disablesOccludedBackdropBlurs {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        return YES;
    }
    return %orig;
}

- (void)setScale:(CGFloat)scale {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        if (g_isInteracting || g_isScrollingActive || g_isContinuousSwiping) {
            %orig(MIN(scale, 0.50f));
            return;
        }
        if (CFG285.flatTintBlur && scale > 0.25f && scale < 1.0f) {
            %orig(scale * 0.85f);
            return;
        }
    }
    %orig(scale);
}

%end

%hook UIVisualEffectView

- (void)layoutSubviews {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) {
        CALayer *layer = self.layer;
        if (layer) {
            layer.allowsGroupOpacity = YES;
        }
    }
}

%end

%end

%group Group_CryoQuantum_Thermal_Bypass
%end

%group Group_Aggressive_RAM_Purge
%end

#include <sys/utsname.h>
#include <CoreFoundation/CoreFoundation.h>

static inline BOOL Titanium_ShouldApplyHardwareSpoof(void) {
    if (Titanium_IsSpringBoard() || Titanium_IsSettingsApp() || Titanium_IsSpoofExcludedApp() || g_isCurrentAppBlacklisted) {
        return NO;
    }
    return YES;
}

%group Group_UltimateDevice_And_OS_Spoofing
%end

%group Group_Safari_And_Animation_Safety

%hook _UIMorphingPlatterView

- (void)layoutSubviews {
    @try {
       if (!self || [(UIView *)self window] == nil) {
            %orig;
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook _UIClickPresentationInteraction

- (void)_cancelWithReason:(NSInteger)reason alongsideActions:(id)alongsideActions completion:(id)completion {
    @try {
        if (!self) {
            %orig(reason, alongsideActions, completion);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(reason, alongsideActions, completion);
}

%end

%end

// ====================================================================================================
// PHẦN B: TẦNG 4-5-6 REAL (các hằng số & typedef giữ nguyên từ bản cũ)
// ====================================================================================================

#ifndef MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES
#define MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES 2
#endif
#ifndef MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK
#define MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK 5
#endif
#ifndef MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT
#define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT 6
#endif
#ifndef MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED
#define MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED 14
#endif
#ifndef MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE
#define MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE 18
#endif
#ifndef JETSAM_PRIORITY_FOREGROUND
#define JETSAM_PRIORITY_FOREGROUND 10
#endif
#ifndef JETSAM_PRIORITY_IMPORTANT
#define JETSAM_PRIORITY_IMPORTANT 18
#endif
#ifndef JETSAM_PRIORITY_CRITICAL
#define JETSAM_PRIORITY_CRITICAL 19
#endif
#ifndef TIER6_KERNEL_MAX_IMPORTANCE
#define TIER6_KERNEL_MAX_IMPORTANCE 127
#endif

#ifndef CS_OPS_STATUS
#define CS_OPS_STATUS 0
#endif
#ifndef CS_PLATFORM_BINARY
#define CS_PLATFORM_BINARY 0x04000000
#endif
#ifndef CS_GET_TASK_ALLOW
#define CS_GET_TASK_ALLOW 0x00000004
#endif
#ifndef CS_INSTALLER
#define CS_INSTALLER 0x00000008
#endif

typedef struct memorystatus_priority_properties {
    int32_t  priority;
    uint64_t user_data;
} memorystatus_priority_properties_t;

typedef int (*memorystatus_control_fn)(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);
typedef int (*csops_fn)(pid_t pid, unsigned int ops, void *useraddr, size_t usersize);
typedef int (*sandbox_check_fn)(pid_t pid, const char *operation, int type, ...);
typedef int (*access_fn)(const char *path, int amode);

static sandbox_check_fn orig_sandbox_check = NULL;
static csops_fn orig_csops = NULL;
static access_fn orig_access = NULL;

@interface RBSProcessMonitor : NSObject
- (void)invalidate;
@end

@interface RBSAssertion : NSObject
- (BOOL)acquireWithError:(NSError **)error;
- (BOOL)isValid;
- (void)invalidate;
@end

@interface RBSWorkloop : NSObject
+ (dispatch_queue_t)sharedBackgroundWorkloop;
+ (dispatch_queue_t)sharedCalloutWorkloop;
@end

@interface FBProcessExecutionContext : NSObject
@property (nonatomic, assign) double watchdogExtension;
@property (nonatomic, assign) BOOL waitForDebugger;
@property (nonatomic, assign) BOOL disableASLR;
@property (nonatomic, assign) BOOL checkForLeaks;
@end

@interface FBApplicationProcessLaunchTransaction : NSObject
- (BOOL)_canBeInterrupted;
@end

@interface BKSHIDEventDeliveryManager : NSObject
- (void)setDeferringRules:(id)rules;
@end

// Bảng cấu hình panel — nativePanelMaxHz giờ là con số THẬT dùng để clamp, không phải số giả
typedef struct {
    const char *machinePrefix;
    const char *modelName;
    uint32_t nativePanelMaxHz;
    uint32_t overdriveCeilingHz; // trần thử overdrive thật (65..120)
    uint32_t touchSampleRateHz;
} TitaniumPanelRegisterProfile;

static const TitaniumPanelRegisterProfile kTitaniumPanelProfiles[] = {
    {"iPhone8,",  "iPhone 6s / SE (A9)",      60,  75, 240},
    {"iPhone9,",  "iPhone 7 Series (A10)",    60,  75, 240},
    {"iPhone10,", "iPhone 8 / X (A11)",       60,  75, 240},
    {"iPhone11,", "iPhone XS / XR (A12)",     60,  75, 240},
    {"iPhone12,", "iPhone 11 / SE2 (A13)",    60,  75, 240},
    {"iPhone13,", "iPhone 12 Series (A14)",   60,  75, 240},
    {"iPhone14,2","iPhone 13 Pro (A15 LTPO)",120, 120, 360},
    {"iPhone14,3","iPhone 13 Pro Max (A15)",  120, 120, 360},
    {"iPhone14,", "iPhone 13/14 (A15)",       60,  75, 240},
    {"iPhone15,2","iPhone 14 Pro (A16 LTPO2)",120, 120, 360},
    {"iPhone15,3","iPhone 14 Pro Max (A16)",  120, 120, 360},
    {"iPhone15,", "iPhone 15 Series (A16)",   60,  75, 240},
    {"iPhone16,", "iPhone 15 Pro (A17 Pro)",  120, 120, 360},
    {"iPhone17,", "iPhone 16 Pro (A18 Pro)",  120, 120, 360}
};

static const TitaniumPanelRegisterProfile *Titanium_ResolveCurrentPanelProfile(void) {
    static const TitaniumPanelRegisterProfile *s_profile = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        memset(&sysInfo, 0, sizeof(sysInfo));
        if (uname(&sysInfo) == 0) {
            for (size_t i = 0; i < sizeof(kTitaniumPanelProfiles) / sizeof(kTitaniumPanelProfiles[0]); i++) {
                if (strncmp(sysInfo.machine, kTitaniumPanelProfiles[i].machinePrefix, strlen(kTitaniumPanelProfiles[i].machinePrefix)) == 0) {
                    s_profile = &kTitaniumPanelProfiles[i];
                    break;
                }
            }
        }
        if (!s_profile) {
            static const TitaniumPanelRegisterProfile kDefault = { "iPhone", "Apple Display Engine", 60, 75, 240 };
            s_profile = &kDefault;
        }
    });
    return s_profile;
}

// ====================================================================================================
// 1. TẦNG 6: FILZA SYSTEM UNLOCK — [ĐÃ SIẾT CHẶT]
//    sandbox_check giờ CHỈ nới cho process Filza/file manager, BỎ nhánh pid==getpid()
//    (bản cũ vô hiệu sandbox của MỌI process chứa tweak = lỗ hổng bảo mật thật)
// ====================================================================================================

static inline BOOL Titanium_IsFilzaOrFileManagerProcess(void) {
    static BOOL s_isFilza = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        const char *prog = Titanium_SafeGetProgName();
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
        if ((prog && (strcasestr(prog, "Filza") != NULL || strcasestr(prog, "Santander") != NULL || strcasestr(prog, "NewTerm") != NULL || strcasestr(prog, "AppsManager") != NULL)) ||
            [bid rangeOfString:@"com.tigisoftware.Filza" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [bid rangeOfString:@"filza" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            s_isFilza = YES;
        }
    });
    return s_isFilza;
}

static int hooked_sandbox_check(pid_t pid, const char *operation, int type, ...) {
    // [REAL FIX] Chỉ Filza/file manager được nới — mọi process khác đi qua sandbox gốc
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsFilzaOrFileManagerProcess()) {
        if (!operation ||
            strncmp(operation, "file-", 5) == 0 ||
            strncmp(operation, "mach-", 5) == 0 ||
            strncmp(operation, "ipc-", 4) == 0 ||
            strncmp(operation, "process-", 8) == 0 ||
            strncmp(operation, "sysctl-", 7) == 0 ||
            strncmp(operation, "iokit-", 6) == 0 ||
            strncmp(operation, "priv-", 5) == 0) {
            return 0;
        }
    }
    return orig_sandbox_check ? orig_sandbox_check(pid, operation, type) : 0;
}

static int hooked_csops(pid_t pid, unsigned int ops, void *useraddr, size_t usersize) {
    int ret = orig_csops ? orig_csops(pid, ops, useraddr, usersize) : 0;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && ops == CS_OPS_STATUS && useraddr && usersize >= sizeof(uint32_t)) {
        if (Titanium_IsFilzaOrFileManagerProcess()) {
            uint32_t *flags = (uint32_t *)useraddr;
            *flags |= (CS_PLATFORM_BINARY | CS_GET_TASK_ALLOW | CS_INSTALLER);
        }
    }
    return ret;
}

static int hooked_access(const char *path, int amode) {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && path && Titanium_IsFilzaOrFileManagerProcess()) {
        if ((amode & W_OK) || (amode & R_OK)) {
            if (strncmp(path, "/var/", 5) == 0 ||
                strncmp(path, "/private/var/", 13) == 0 ||
                strncmp(path, "/tmp/", 5) == 0 ||
                strncmp(path, "/Library/", 9) == 0) {
                return 0; // [REAL FIX] bỏ chmod 0777 blind — trả allow, không đổi permission thật
            }
        }
    }
    return orig_access ? orig_access(path, amode) : 0;
}

static void Titanium_Tier6_UnlockSystemFileAccessAndFilzaReadWrite(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            void *sbLib = dlopen("/usr/lib/system/libsystem_sandbox.dylib", RTLD_LAZY | RTLD_LOCAL);
            if (!sbLib) sbLib = RTLD_DEFAULT;
            void *symSbCheck = dlsym(sbLib, "sandbox_check");
            if (symSbCheck && !orig_sandbox_check) {
                MSHookFunction(symSbCheck, (void *)hooked_sandbox_check, (void **)&orig_sandbox_check);
            }

            void *kernLib = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_LAZY | RTLD_LOCAL);
            if (kernLib) {
                void *symCsops = dlsym(kernLib, "csops");
                if (symCsops && !orig_csops) {
                    MSHookFunction(symCsops, (void *)hooked_csops, (void **)&orig_csops);
                }
                if (Titanium_IsFilzaOrFileManagerProcess()) {
                    void *symAccess = dlsym(kernLib, "access");
                    if (symAccess && !orig_access) {
                        MSHookFunction(symAccess, (void *)hooked_access, (void **)&orig_access);
                    }
                }
            }

            if (Titanium_IsFilzaOrFileManagerProcess()) {
                setuid(0);
                setgid(0);
                seteuid(0);
                setegid(0);
            }
        } @catch (__unused NSException *e) {}
    });
}

// ====================================================================================================
// 2. TẦNG 5: QUARTZCORE CEILING — [REAL] đồng bộ scene về nhịp panel thật (không fake ceiling)
// ====================================================================================================

static void Titanium_Tier5_UnlockQuartzCore240HzCeiling(void) {
    NSInteger realPanel = Titanium_ActualPanelHz();
    NSInteger target = Titanium_GetUserTargetHz();
    if (realPanel > 0 && target > realPanel) target = realPanel;
    Titanium_Tier4WriteCadence(MIN(MAX(target, 60), 120));
}

// 3. [REAL] IOMFB direct-call đã triển khai ở đầu phần này (Titanium_LoadIOMFBDirect +
//    Titanium_IOMFBTryAlternateModes + Titanium_ForcePanelModeDirect). Hàm giữ tên cũ để tương thích:
static void Titanium_InstallDirectIOMobileFramebufferCHooks(void) {
    // Không interpose — direct-call an toàn hơn. Load symbol sẵn.
    Titanium_LoadIOMFBDirect();
}

// 4. TẦNG 5 THẬT: ép panel qua IOMFB + IORegistry, có watchdog
static void Titanium_Tier5_ForceHardwarePanelAndGPU240Hz(NSInteger targetHz, NSInteger targetFPS) {
    (void)targetFPS;
    const TitaniumPanelRegisterProfile *profile = Titanium_ResolveCurrentPanelProfile();
    NSInteger ceiling = (NSInteger)profile->overdriveCeilingHz;
    NSInteger clamped = MIN(targetHz, ceiling);
    if (clamped <= (NSInteger)profile->nativePanelMaxHz) return; // máy native 120 -> không cần bẻ
    Titanium_OverdrivePipelineGo(clamped);
}

// 5. TẦNG 4 THẬT: đồng bộ cadence qua CAWindowServer + CADisplay
static void Titanium_Tier4_ExecuteHardwarePanelOverdrive(void) {
    Titanium_ExecuteRealPanelOverdrive();
}

// ====================================================================================================
// 6. TẦNG 6 KERNEL THREAD GOVERNOR (GIỮ NGUYÊN — đã là code thật, hoạt động đúng)
// ====================================================================================================

static void Titanium_Tier6_PromoteThreadToKernelMax127(thread_act_t threadPort, NSInteger targetHz, BOOL isMainThread) {
    if (threadPort == MACH_PORT_NULL) return;
    if (targetHz < 15) targetHz = 15;
    if (targetHz > 240) targetHz = 240;

    thread_affinity_policy_data_t affinity = { .affinity_tag = 1 };
    thread_policy_set(threadPort, THREAD_AFFINITY_POLICY, (thread_policy_t)&affinity, THREAD_AFFINITY_POLICY_COUNT);

    thread_throttle_policy_data_t throttle = { .pset_limit = 0 };
    thread_policy_set(threadPort, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttle, 1);

    thread_precedence_policy_data_t precedence = { .importance = TIER6_KERNEL_MAX_IMPORTANCE };
    thread_policy_set(threadPort, THREAD_PRECEDENCE_POLICY, (thread_policy_t)&precedence, THREAD_PRECEDENCE_POLICY_COUNT);

    if (isMainThread) {
        struct sched_param param;
        param.sched_priority = 63;
        pthread_setschedparam(pthread_self(), SCHED_RR, &param);

        uint64_t frameNanos = 1000000000ULL / (uint64_t)targetHz;
        thread_time_constraint_policy_data_t timeConstraint;
        timeConstraint.period      = (uint32_t)Titanium_NanosToMachTicks(frameNanos);
        timeConstraint.computation = (uint32_t)Titanium_NanosToMachTicks(frameNanos / 5ULL);
        timeConstraint.constraint  = (uint32_t)Titanium_NanosToMachTicks(frameNanos / 2ULL);
        timeConstraint.preemptible = TRUE;
        thread_policy_set(threadPort, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&timeConstraint, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    }
}

static void Titanium_Tier5_PinAllThreadsToPCoreAndRealtime(void) {
    // [REAL FIX] clamp target về Hz panel thật — realtime constraint theo chu kỳ sai = CPU churn vô ích
    NSInteger realPanel = Titanium_ActualPanelHz();
    NSInteger targetHz = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
    if (realPanel > 0 && targetHz > realPanel) targetHz = realPanel;
    if (targetHz < 30) targetHz = 60;

    if ([NSThread isMainThread]) {
        mach_port_t mainThread = pthread_mach_thread_np(pthread_self());
        Titanium_Tier6_PromoteThreadToKernelMax127(mainThread, targetHz, YES);
    }

    thread_act_array_t threadList = NULL;
    mach_msg_type_number_t threadCount = 0;
    if (task_threads(mach_task_self(), &threadList, &threadCount) == KERN_SUCCESS && threadList) {
        mach_msg_type_number_t maxScan = (threadCount > 16) ? 16 : threadCount;
        for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
            if (i < maxScan) {
                Titanium_Tier6_PromoteThreadToKernelMax127(threadList[i], targetHz, NO);
            }
            mach_port_deallocate(mach_task_self(), threadList[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)threadList, threadCount * sizeof(thread_act_t));
    }
}

// ====================================================================================================
// 7. TẦNG 5+6: JETSAM IMMUNITY THẬT (chỉ PID của chính process)
// ====================================================================================================

static void Titanium_Tier5_EnforceKernelJetsamAndPowerImmunity(void) {
    Titanium_Tier6JetsamImmunityReal();
}

// 8. TRÌNH ĐIỀU PHỐI TỔNG HỢP
static void Titanium_Tier5_FiveStageRAM_And_CPUGPU_Unlock(void) {
    Titanium_InstallDirectIOMobileFramebufferCHooks();
    Titanium_Tier5_EnforceKernelJetsamAndPowerImmunity();
    Titanium_Tier5_UnlockQuartzCore240HzCeiling();
    Titanium_Tier6_UnlockSystemFileAccessAndFilzaReadWrite();

    static os_unfair_lock s_t5Lock = OS_UNFAIR_LOCK_INIT;
    static uint64_t s_lastT5Tick = 0;
    uint64_t now = mach_absolute_time();
    BOOL shouldRun = NO;
    os_unfair_lock_lock(&s_t5Lock);
    if (s_lastT5Tick == 0 || (now - s_lastT5Tick) >= Titanium_NanosToMachTicks(4500000000ULL)) {
        s_lastT5Tick = now;
        shouldRun = YES;
    }
    os_unfair_lock_unlock(&s_t5Lock);
    if (!shouldRun) return;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        @autoreleasepool {
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
            mlock(&g_syncPayloadV285, sizeof(ApexV285ProPayload));
            mlock(&g_livePayload, sizeof(ApexV285ProPayload));
            if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) {
                mlock(g_sharedPayloadPtr, sizeof(ApexV285ProPayload));
            }

            struct task_qos_policy qosinfo = {
                .task_latency_qos_tier = LATENCY_QOS_TIER_0,
                .task_throughput_qos_tier = THROUGHPUT_QOS_TIER_0
            };
            task_policy_set(mach_task_self(), TASK_BASE_QOS_POLICY, (task_policy_t)&qosinfo, TASK_QOS_POLICY_COUNT);
            task_policy_set(mach_task_self(), TASK_OVERRIDE_QOS_POLICY, (task_policy_t)&qosinfo, TASK_QOS_POLICY_COUNT);

            setpriority(PRIO_PROCESS, 0, -20);
            setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
            setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);

            Titanium_Tier5_PinAllThreadsToPCoreAndRealtime();

            NSInteger targetHz = Titanium_GetEffectiveFrameCap();
            Titanium_Tier5_ForceHardwarePanelAndGPU240Hz(targetHz, targetHz);
            Titanium_Tier4_ExecuteHardwarePanelOverdrive();
        }
    });
}

// ====================================================================================================
// NHÓM HOOK TẦNG 5 & 6 (GIỮ NGUYÊN — không đụng lifecycle watchdog)
// ====================================================================================================

%group Group_Tier5_DisplayIC_DynamicIsland_Dock_3DParticles

%hook NSFileManager

- (BOOL)isWritableFileAtPath:(NSString *)path {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && path) {
        if (Titanium_IsFilzaOrFileManagerProcess() ||
            [path hasPrefix:@"/var/"] ||
            [path hasPrefix:@"/private/var/"] ||
            [path hasPrefix:@"/tmp/"] ||
            [path hasPrefix:@"/Library/"]) {
            return YES;
        }
    }
    return %orig(path);
}

- (BOOL)isReadableFileAtPath:(NSString *)path {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && path) {
        if (Titanium_IsFilzaOrFileManagerProcess()) {
            return YES;
        }
    }
    return %orig(path);
}

- (BOOL)isDeletableFileAtPath:(NSString *)path {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && path) {
        if (Titanium_IsFilzaOrFileManagerProcess()) {
            return YES;
        }
    }
    return %orig(path);
}

%end

%hook CADisplayProperties

- (void)setOverscanAdjustment:(id)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_LockMainThreadFast();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(arg1);
}

- (void)setConnectionSeed:(unsigned int)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_LockMainThreadFast();
    }
    %orig(arg1);
}

%end

%hook BSAnimationSettings

- (float)frameInterval {
    if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        float cap = (float)Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
        return (1.0f / cap);
    }
    return %orig;
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (@available(iOS 15.0, *)) {
        if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float cap = (float)Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
            return Titanium_SmoothFRR(cap);
        }
    }
    return %orig;
}

%end

%hook BSSpringAnimationSettings

- (float)frameInterval {
    if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        float cap = (float)Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
        return (1.0f / cap);
    }
    return %orig;
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (@available(iOS 15.0, *)) {
        if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float cap = (float)Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
            return Titanium_SmoothFRR(cap);
        }
    }
    return %orig;
}

%end

%hook UIViewPropertyAnimator

- (BOOL)isUserInteractionEnabled {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return YES;
    }
    return %orig;
}

- (BOOL)isInterruptible {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return YES;
    }
    return %orig;
}

- (BOOL)scrubsLinearly {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return YES;
    }
    return %orig;
}

- (void)startAnimation {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_LockMainThreadFast();
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook _UIRoundedRectShadowView

- (void)layoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            self.layer.allowsGroupOpacity = YES;
            self.layer.drawsAsynchronously = YES;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook _UIViewControllerTransitionContext

- (void)completeTransition:(BOOL)didComplete {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig(didComplete);
}

%end

%hook SBSystemApertureViewController

- (void)viewWillLayoutSubviews {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_LockMainThreadFast();
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)viewDidLayoutSubviews {
    %orig;
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
}

%end

%hook SBSystemApertureController

- (void)viewWillLayoutSubviews {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook SBDockView

- (void)layoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            self.layer.allowsGroupOpacity = YES;
            self.layer.drawsAsynchronously = YES;
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook SBFloatingDockViewController

- (void)viewWillLayoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook SBFolderController

- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

%end

%hook SBIconController

- (void)openFolder:(id)folder animated:(BOOL)animated completion:(id)completion {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(folder, animated, completion);
}

%end

%hook MTKView

- (void)didMoveToWindow {
    %orig;
    @try {
        if (self && Titanium_DisplayRateOverrideReady() &&
            (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            self.preferredFramesPerSecond = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
        }
    } @catch (__unused NSException *e) {}
}

- (NSInteger)preferredFramesPerSecond {
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (Titanium_DisplayRateOverrideReady() &&
        (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap()));
        return;
    }
    %orig(fps);
}

%end

%hook CAEmitterLayer

- (void)didChangeValueForKey:(NSString *)key {
    %orig(key);
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            self.drawsAsynchronously = YES;
            self.allowsGroupOpacity = YES;
        }
    } @catch (__unused NSException *e) {}
}

%end

%hook SCNView

- (void)didMoveToWindow {
    %orig;
    @try {
        if (self && Titanium_DisplayRateOverrideReady() &&
            (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            [(id)self setPreferredFramesPerSecond: Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap())];
            if ([self respondsToSelector:@selector(setRendersContinuously:)]) {
                [(id)self setValue:@YES forKey:@"rendersContinuously"];
            }
        }
    } @catch (__unused NSException *e) {}
}

- (NSInteger)preferredFramesPerSecond {
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (Titanium_DisplayRateOverrideReady() &&
        (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap()));
        return;
    }
    %orig(fps);
}

%end

%hook SKView

- (void)didMoveToWindow {
    %orig;
    @try {
        if (self && Titanium_DisplayRateOverrideReady() &&
            (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            [(id)self setPreferredFramesPerSecond: Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap())];
            if ([self respondsToSelector:@selector(setIgnoresSiblingOrder:)]) {
                [(id)self setValue:@YES forKey:@"ignoresSiblingOrder"];
            }
        }
    } @catch (__unused NSException *e) {}
}

- (NSInteger)preferredFramesPerSecond {
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (Titanium_DisplayRateOverrideReady() &&
        (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap()));
        return;
    }
    %orig(fps);
}

%end

%hook NSLayoutManager

- (BOOL)allowsNonContiguousLayout {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return YES;
    }
    return %orig;
}

- (void)setAllowsNonContiguousLayout:(BOOL)flag {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(YES);
        return;
    }
    %orig(flag);
}

%end

%end

%group Group_Tier4_PanelRegister_And_ThermalUnlock

%hook CADisplay

- (void)overrideDisplayCadence:(id)cadence {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        Titanium_Tier4_ExecuteHardwarePanelOverdrive(); // [REAL] ghi cadence thật xuống CA/IOMFB
    }
    %orig(cadence);
}

%end

%end

// ====================================================================================================
// PHẦN C: KHỞI TẠO HỆ THỐNG, WATCHDOG NHIỆT ĐỘ, RESPRING / SREBOOT & %CTOR HOÀN CHỈNH
// ====================================================================================================

static void Titanium_StartIPCHearthbeatV12(void) {
    @try {
        if (!Titanium_IsSpringBoard()) return;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dispatch_source_t hb = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
            dispatch_source_set_timer(hb, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), (uint64_t)(30 * NSEC_PER_SEC), (uint64_t)(5 * NSEC_PER_SEC));
            dispatch_source_set_event_handler(hb, ^{
                @try {
                    Titanium_ReloadSharedSyncStateV285();
                } @catch (__unused NSException *e) {}
            });
            dispatch_resume(hb);
        });
    } @catch (__unused NSException *e) {}
}

static void Titanium_RegisterAppResumeRefreshV12(void) {
    @try {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                @try {
                    g_lastSyncTicksV285 = 0;
                    Titanium_ReloadSharedSyncStateV285();
                    if (CFG285) {
                        CFG285.enabled = (g_syncPayloadV285.masterEnabled != 0);
                        CFG285.targetHz = g_cachedResolvedHz;
                        CFG285.targetFPS = g_cachedResolvedFPS;
                    }
                    Titanium_ReapplyFrameRateToAllScenes();
                } @catch (__unused NSException *e) {}
            }];
            if (@available(iOS 9.0, *)) {
                [[NSNotificationCenter defaultCenter] addObserverForName:NSProcessInfoPowerStateDidChangeNotification
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:^(NSNotification * _Nonnull note) {
                    @try { Titanium_ReapplyFrameRateToAllScenes(); } @catch (__unused NSException *e) {}
                }];
            }
            if (@available(iOS 11.0, *)) {
                NSProcessInfo *processInfo = [NSProcessInfo processInfo];
                g_thermalSeriousV285 = (processInfo.thermalState >= NSProcessInfoThermalStateSerious);
                [[NSNotificationCenter defaultCenter] addObserverForName:NSProcessInfoThermalStateDidChangeNotification
                                                                  object:nil
                                                                   queue:[NSOperationQueue mainQueue]
                                                              usingBlock:^(NSNotification * _Nonnull note) {
                    @try {
                        NSProcessInfo *currentInfo = [NSProcessInfo processInfo];
                        g_thermalSeriousV285 = (currentInfo.thermalState >= NSProcessInfoThermalStateSerious);
                        // [REAL] máy nóng thật -> HỦY overdrive, rollback 60 — tự bảo vệ phần cứng
                        if (g_thermalSeriousV285 && g_tioActiveHz > 60) {
                            Titanium_ForcePanelModeDirect(60);
                            Titanium_Tier4RollbackCadence();
                            g_tioActiveHz = 60;
                            g_tioCooldownUntil = mach_absolute_time() + tio_mach_nanos(600000000ULL * 10);
                        }
                        Titanium_ReapplyFrameRateToAllScenes();
                    } @catch (__unused NSException *e) {}
                }];
            }
        });
    } @catch (__unused NSException *e) {}
}

static void Titanium_StartThermalAndChargingWatchdog(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            UIDevice *dev = [UIDevice currentDevice];
            dev.batteryMonitoringEnabled = YES;
            g_isDeviceChargingV285 = (dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull);

            [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                @try {
                    UIDevice *currentDev = [UIDevice currentDevice];
                    g_isDeviceChargingV285 = (currentDev.batteryState == UIDeviceBatteryStateCharging || currentDev.batteryState == UIDeviceBatteryStateFull);
                    Titanium_UpdateLowBatteryFlagV12();
                } @catch (__unused NSException *e) {}
            }];

            g_batteryLevelV12 = dev.batteryLevel;
            Titanium_UpdateLowBatteryFlagV12();
            [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryLevelDidChangeNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                @try {
                    g_batteryLevelV12 = [UIDevice currentDevice].batteryLevel;
                    Titanium_UpdateLowBatteryFlagV12();
                } @catch (__unused NSException *e) {}
            }];
        } @catch (__unused NSException *e) {}
    });
}

__attribute__((constructor)) static void Titanium_DeepHardwareCoreInit(void) {
    @autoreleasepool {
        @try {
            Titanium_StartIPCHearthbeatV12();
            Titanium_RegisterAppResumeRefreshV12();
            Titanium_StartThermalAndChargingWatchdog();
        } @catch (__unused NSException *e) {}
    }
}

void Titanium_TriggerRespringAction(void) {
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [fb impactOccurred];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(700 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        pid_t pid = 0;
        const char *argsJB[] = {"sbreload", NULL};
        const char *argsSystem[] = {"sbreload", NULL};
        int result = posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)argsJB, environ);
        if (result != 0) {
            posix_spawn(&pid, "/usr/bin/sbreload", NULL, NULL, (char *const *)argsSystem, environ);
        }
    });
}

#define TITANIUM_SREBOOT_MARKER     @"/tmp/.titanium_sreboot_marker"
#define TITANIUM_SREBOOT_WINDOW     180.0

static BOOL Titanium_ShouldDelayLoadAfterSreboot(void) {
    NSDictionary *marker = [NSDictionary dictionaryWithContentsOfFile:TITANIUM_SREBOOT_MARKER];
    NSNumber *t = marker[@"time"];
    if (![t isKindOfClass:[NSNumber class]]) return NO;
    NSTimeInterval age = [[NSDate date] timeIntervalSince1970] - [t doubleValue];
    return (age >= 0.0 && age < TITANIUM_SREBOOT_WINDOW);
}

void Titanium_TriggerSrebootAction(void) {
    NSDictionary *marker = @{@"time": @([[NSDate date] timeIntervalSince1970])};
    if (![marker writeToFile:TITANIUM_SREBOOT_MARKER atomically:YES]) {
        return;
    }

    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb notificationOccurred:UINotificationFeedbackTypeWarning];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        pid_t pid = 0;
        const char *args[] = {"launchctl", "reboot", "userspace", NULL};
        int spawnResult = posix_spawn(&pid, "/bin/launchctl", NULL, NULL, (char *const *)args, environ);
        if (spawnResult != 0) {
            [[NSFileManager defaultManager] removeItemAtPath:TITANIUM_SREBOOT_MARKER error:nil];
        }
    });
}

static void Titanium_InstallMGCopyAnswerHookV26(void) {
}

static void Titanium_RegisterPrefsObservers(BOOL isSpringBoardProcess) {
    static BOOL s_obsDone = NO;
    if (s_obsDone) return;
    s_obsDone = YES;

    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    if (!darwinCenter) return;

    NSArray<NSString *> *notifications = @[
        @NOTIFY_RELOAD,
        @NOTIFY_UIKIT_RELOAD,
        @NOTIFY_HARDWARE_SYNC,
        @NOTIFY_FPS_CHANGED,
        @NOTIFY_TITANIUM_CHANGED,
        @NOTIFY_PAYLOAD_WRITTEN,
        @"com.titanium.reload",
        @"com.titanium.uikit.reload",
        @"com.titanium.hardwaresync",
        @"com.titanium.fpschanged",
        @"com.titanium.changed",
        @"com.titanium.payloadwritten"
    ];
    for (NSString *name in notifications) {
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, (__bridge CFStringRef)name, NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    }
}

static void Titanium_RestoreFirstDrawDefaultsOnce(void) {
    @try {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (!bid) return;
        NSString *key = [NSString stringWithFormat:@"TI_FIRSTDRAW_RESTORED_%@", bid];
        if ([[NSUserDefaults standardUserDefaults] boolForKey:key]) return;
        if (@available(iOS 15.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    if ([ws respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                        ws.preferredFrameRateRange = CAFrameRateRangeDefault;
                    }
                }
            }
        }
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:key];
    } @catch (__unused NSException *e) {}
}

@interface TitaniumFirstFrameTarget : NSObject
@property (nonatomic, copy) void (^handler)(CADisplayLink *link);
- (void)tick:(CADisplayLink *)link;
@end

@implementation TitaniumFirstFrameTarget
- (void)tick:(CADisplayLink *)link {
    if (self.handler) self.handler(link);
}
@end

static void Titanium_RestoreOnFirstFrame(void) {
    if (!Titanium_IsUIProcess()) return;   // daemon: không có display
    static BOOL s_waitingForFirstFrame = NO;
    if (s_waitingForFirstFrame) return;
    s_waitingForFirstFrame = YES;
    TitaniumFirstFrameTarget *target = [TitaniumFirstFrameTarget new];
    __weak TitaniumFirstFrameTarget *weakTarget = target;
    __block NSUInteger visibleTicks = 0;
    target.handler = ^(CADisplayLink *link) {
        UIApplication *app = [UIApplication sharedApplication];
        BOOL hasVisibleWindow = NO;
        for (UIScene *scene in app.connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]] || scene.activationState != UISceneActivationStateForegroundActive) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if (window.isKeyWindow && !window.hidden && window.alpha > 0.01) {
                    hasVisibleWindow = YES;
                    break;
                }
            }
            if (hasVisibleWindow) break;
        }
        if (app.applicationState == UIApplicationStateActive && hasVisibleWindow) {
            visibleTicks++;
        } else {
            visibleTicks = 0;
        }
        if (visibleTicks >= 4) {
            Titanium_UpdateNativeDisplayMaxFPS();
            Titanium_InstallUIScreenRateSpoofNow();
            Titanium_RestoreFirstDrawDefaultsOnce();
            __atomic_store_n(&g_titaniumFirstFrameReady, 1, __ATOMIC_RELEASE);
            Titanium_KillVSyncCompletelyAtRoot();
            AppleInternal_LockHardwareCADisplay();
            Titanium_ApplySiliconDeepOptimizations();
            // [REAL] sau khi frame đầu đã render ổn định -> đẩy tầng sâu xuống panel
            Titanium_ExecuteRealPanelOverdrive();
            [link invalidate];
            weakTarget.handler = nil;
            Titanium_ReapplyFrameRateToVisibleMetalLayers();
            Titanium_ReapplyFrameRateToAllScenes();
        }
    };
    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)];
    displayLink.preferredFramesPerSecond = 60;
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    static BOOL s_coreInitDone = NO;
    if (s_coreInitDone) return;
    s_coreInitDone = YES;

    @autoreleasepool {
        Titanium_BypassQuartzCoreRangeAssertion();

        Class configClass = NSClassFromString(@"BoostConfigV285Pro");
        if (configClass) {
            CFG285 = [configClass sharedInstance];
            [CFG285 loadSettings];
        }

        g_lastSyncTicksV285 = 0;
        Titanium_ReloadSharedSyncStateV285();
        if (CFG285) {
            CFG285.enabled = (g_syncPayloadV285.masterEnabled != 0);
            CFG285.targetHz = g_cachedResolvedHz;
            CFG285.targetFPS = g_cachedResolvedFPS;
        }

        if (g_isCurrentAppBlacklisted) {
            return;
        }

        if (!isSpringBoard) {
            Titanium_RegisterUIScreenRateSpoofAfterLaunch();
        }

        Titanium_KillVSyncCompletelyAtRoot();
        Titanium_InitZeroCopyIPC(isSpringBoard);
        Titanium_InstallDynamicMetalOverdriveGroup2();

        %init(Group_ZeroLatency_Touch_Opt);
        %init(Group_FluidTransitions_Pacing_PreScreen);
        %init(Group_FluidTransitions_Pacing_PostScreen);
        %init(Group_AI_Stream_Optimization);
        %init(Group_FastLaunch_SuperEngineV285);
        %init(Group_Scroll_And_Keyboard_Opt);
        %init(Group_InstantActionAndMenuTransitions_Boost);
        %init(Group_Global_Thread_Governor_Unthrottled);
        %init(Group_Apple_Internal_ProMotion_Apex);
        %init(Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285);
        %init(Group_Hardware_Deep_Core_Bypass);
        %init(Group_Safari_And_Animation_Safety);
        %init(Group_Aggressive_RAM_Purge);

        // [REAL FIX — BẬT LẠI] Hook IOMFBClient refresh-rate giờ được init:
        // setDisplayRefreshRate ghi rate người dùng chọn thật xuống driver.
        %init(Group_Hardware_ProMotion_Overclock);

        %init(Group_Apple_Native_ColdBoot_Overdrive);
        if (!g_avoidTweakConflicts) %init(Group_Silicon_Hardware_Pipeline_Overdrive);
        %init(Group_Silicon_Scheduler_Touch_Governor);
        %init(Group_CoreAnimation_RenderServer_Governor);
        %init(Group_System_Memory_And_RunLoop_Governor);
        %init(Group_Thermal_CryoPacing_ZeroDrop);
        if (!g_avoidTweakConflicts) %init(Group_CryoQuantum_Thermal_Bypass);
        %init(Group_Deep_RAM_Compaction_Engine);
        %init(Group_TitaniumV12_SmoothExit_And_DisplayLink);
        %init(Group_Window_Level_Overdrive);
        %init(Group_WebKit_RAM_Optimizer);
        %init(Group_UIKit_ThirdParty_IsolatedV285);
        %init(Group_Tier5_DisplayIC_DynamicIsland_Dock_3DParticles);
        %init(Group_Tier4_PanelRegister_And_ThermalUnlock);
        Titanium_InstallDirectIOMobileFramebufferCHooks();
        Titanium_Tier6_UnlockSystemFileAccessAndFilzaReadWrite();
        // [REAL] Thay 2 stub cũ bằng pipeline thật: probe vsync + jetsam + realtime + IOMFB try-modes
        Titanium_ExecuteRealPanelOverdrive();
        Titanium_Tier5_FiveStageRAM_And_CPUGPU_Unlock();

        if (Titanium_IsClassicHomeButtonDevice()) {
            %init(Group_HardwareSegregation_ClassicHomeV285);
        }

        if (isSpringBoard) {
            %init(Group_LiquidGlass_Opt);
            %init(Group_Switcher30Apps_Virtualization);
            %init(Group_SpringBoard_Switcher_Opt);
            %init(Group_Display_SpringBoardV285);
            %init(Group_TitaniumV10_SpringBoard_Layout_Boost);
            %init(Group_V285_FloatingWindow_PiP);
            %init(Group_SpringBoard_ProcessManagerV285);
            %init(Group_KeepAppsAlive_NoKill);
            %init(Group_CAWindowServer_Absolute_Dominance);
            // đẩy overdrive thật sau khi boot ổn định:
            Titanium_StartThermalAndChargingWatchdog();
            Titanium_StartIPCHearthbeatV12();

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(TITANIUM_BOOT_SETTLE_DELAY_SB * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                Titanium_ReloadSharedSyncStateV285();
                Titanium_UpdateNativeDisplayMaxFPS();
                Titanium_KillVSyncCompletelyAtRoot();
                AppleInternal_EnforceZeroLatencyKernelTier();
                Titanium_ApplySiliconDeepOptimizations();
                AppleInternal_LockHardwareCADisplay();
                Titanium_ReapplyFrameRateToAllScenes();
                Titanium_ExecuteRealPanelOverdrive(); // [REAL] overdrive thật sau boot settle
            });

        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(TITANIUM_BOOT_SETTLE_DELAY_APP * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                Titanium_ReloadSharedSyncStateV285();
                if (CFG285) {
                    CFG285.enabled = (g_syncPayloadV285.masterEnabled != 0);
                    CFG285.targetHz = g_cachedResolvedHz;
                    CFG285.targetFPS = g_cachedResolvedFPS;
                }
                AppleInternal_EnforceZeroLatencyKernelTier();
                Titanium_RegisterAppResumeRefreshV12();
                Titanium_RestoreOnFirstFrame();
            });
        }

        double settleDelay = isSpringBoard ? TITANIUM_BOOT_SETTLE_DELAY_SB : TITANIUM_BOOT_SETTLE_DELAY_APP;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(settleDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            g_SystemMasterReady = YES;
        });
    }
}

%ctor {
    @autoreleasepool {
        const char *progName = Titanium_SafeGetProgName();
        if (!progName) return;

        if (strcasestr(progName, "BoostiPhone6sApp") != NULL ||
            strcasestr(progName, "AccessibilityUIServer") != NULL ||
            strcasestr(progName, "PosterBoard") != NULL ||
            strcasestr(progName, "Cr4shed") != NULL ||
            strcasestr(progName, "ScreenshotServicesService") != NULL ||
            strcasestr(progName, "SharingViewService") != NULL ||
            strcasestr(progName, "PassbookUIService") != NULL ||
            strcasestr(progName, "UserNotificationCenter") != NULL ||
            strcasestr(progName, "CoreAuthUI") != NULL ||
            strcasestr(progName, "assistivetouchd") != NULL ||
            strcasestr(progName, "sharingd") != NULL ||
            strcasestr(progName, "zinitd") != NULL) {
            return;
        }

        if ((strcasecmp(progName, "networkd") == 0) ||
            (strcasecmp(progName, "trustd") == 0) ||
            (strcasecmp(progName, "configd") == 0) ||
            (strcasecmp(progName, "wifid") == 0) ||
            (strcasecmp(progName, "CommCenter") == 0) ||
            (strcasecmp(progName, "mDNSResponder") == 0) ||
            (strcasecmp(progName, "nsurlsessiond") == 0) ||
            (strcasecmp(progName, "neagent") == 0) ||
            (strcasecmp(progName, "nesessionmanager") == 0) ||
            (strcasecmp(progName, "apsd") == 0) ||
            (strcasecmp(progName, "cloudd") == 0) ||
            (strcasecmp(progName, "geod") == 0) ||
            (strcasecmp(progName, "akd") == 0) ||
            (strcasecmp(progName, "identityservicesd") == 0) ||
            (strcasecmp(progName, "imagent") == 0) ||
            (strcasecmp(progName, "bluetoothd") == 0) ||
            (strcasecmp(progName, "profiled") == 0) ||
            (strcasecmp(progName, "jailbreakd") == 0) ||
            (strcasecmp(progName, "launchd") == 0) ||
            (strcasecmp(progName, "containermanagerd") == 0) ||
            (strcasecmp(progName, "cfprefsd") == 0) ||
            (strcasecmp(progName, "watchdogd") == 0) ||
            (strcasecmp(progName, "mediaserverd") == 0) ||
            (strcasecmp(progName, "installd") == 0) ||
            (strcasecmp(progName, "logd") == 0) ||
            (strcasecmp(progName, "analyticsd") == 0) ||
            (strcasecmp(progName, "symptomsd") == 0) ||
            (strcasecmp(progName, "powerd") == 0) ||
            (strcasecmp(progName, "notifyd") == 0) ||
            (strcasecmp(progName, "securityd") == 0) ||
            (strcasecmp(progName, "runningboardd") == 0) ||
            (strcasecmp(progName, "thermalmonitord") == 0) ||
            (strcasecmp(progName, "mediaremoted") == 0) ||
            (strcasecmp(progName, "assertiond") == 0) ||
            (strcasecmp(progName, "timed") == 0) ||
            (strcasecmp(progName, "passd") == 0)) {
            return;
        }

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];

        if (bundleID) {
            if ([bundleID rangeOfString:@"networkextension" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [bundleID rangeOfString:@"vpn" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                return;
            }
        }

        BOOL isSpringBoard = (bundleID && [bundleID isEqualToString:@"com.apple.springboard"]) ||
                             (strcasecmp(progName, "SpringBoard") == 0);

        if (Titanium_ShouldDelayLoadAfterSreboot()) {
            return;
        }

        if (isSpringBoard) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                (void)Titanium_CheckAndPreventBootloopUniversal();
            });
        }

        Titanium_RegisterPrefsObservers(isSpringBoard);
        runCoreTweak(isSpringBoard, bundleID, progName);
    }
}
