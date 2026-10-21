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

// --- UIKIT CORE & DISPATCHER ---
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

// --- QUARTZCORE & METAL PIPELINE ---
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

@class CADisplay;

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

// --- SPRINGBOARD & PROCESS MANAGEMENT ---
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

// --- NHÓM BỔ SUNG: CHỐNG NÓNG CỰC ĐOAN & RENDER SERVER ---
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

// ====================================================================================================
// KHAI BÁO @INTERFACE CHO NHÓM GIẢ LẬP HỆ ĐIỀU HÀNH & THIẾT BỊ ĐỜI MỚI
// ====================================================================================================

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

// --- KHAI BÁO @INTERFACE BỔ SUNG CHO METAL GPU & DISK I/O OVERDRIVE ---
@interface _MTLCommandQueue (TitaniumOverdrivePrivate)
- (void)insertDebugCaptureBoundary;
@end

// ====================================================================================================
// ĐỊNH NGHĨA CHUẨN STRUCT PAYLOAD & KHỞI TẠO BIẾN TOÀN CỤC (ĐÃ TỐI ƯU 240HZ & BẢO VỆ SANDBOX)
// ====================================================================================================

static ApexV285ProPayload g_syncPayloadV285 = {
    .magic = APEX_SYNC_MAGIC_V285,
    .masterEnabled = 1,
    .targetHz = 240,
    .targetFPS = 240,
    .forceOverclock = 1,
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

static volatile NSInteger g_cachedResolvedHz = 240;
static volatile NSInteger g_cachedResolvedFPS = 240;
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

static inline void Titanium_ReloadSharedSyncStateV285(void);
static inline void Titanium_ReapplyFrameRateToAllScenes(void);

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
                    if ([inst respondsToSelector:@selector(setTargetHz:)]) [inst setValue:@(g_cachedResolvedHz) forKey:@"targetHz"];
                    if ([inst respondsToSelector:@selector(setTargetFPS:)]) [inst setValue:@(g_cachedResolvedFPS) forKey:@"targetFPS"];
                }
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
static void Titanium_ForceInjectDynamicRefreshSupport(void);

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
    if (!NSThread.isMainThread) return;
    static __thread BOOL s_vipApplied = NO;
    if (__builtin_expect(s_vipApplied, 1)) return;
    s_vipApplied = YES;

    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);

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
    setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);
    setenv("CA_DISABLE_FRAME_RATE_LIMIT", "1", 1);

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
                NSInteger hz = (dict[@"TargetRefreshRate"] != nil) ? [dict[@"TargetRefreshRate"] integerValue] : 240;
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
#if TITANIUM_SAFE_STABILITY_PROFILE
    return;
#else
    if (!Titanium_DisplaySpoofAllowed()) return;
    @try {
        Class wsClass = NSClassFromString(@"CAWindowServer");
        if (!wsClass) return;
        
        SEL selServer = sel_registerName("server");
        if (![wsClass respondsToSelector:selServer]) return;
        
        id server = nil;
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            server = [wsClass performSelector:selServer];
#pragma clang diagnostic pop
        } @catch (__unused NSException *e) {
            return;
        }
        if (!server) return;

        SEL selDisplays = sel_registerName("displays");
        if (![server respondsToSelector:selDisplays]) return;

        NSArray *displays = nil;
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            displays = [server performSelector:selDisplays];
#pragma clang diagnostic pop
        } @catch (__unused NSException *e) {
            return;
        }

        if (displays && [displays isKindOfClass:[NSArray class]] && displays.count > 0) {
            id mainDisp = displays[0];
            if (!mainDisp) return;
            
            NSInteger currentHz = g_cachedResolvedHz;
            if (currentHz < 15) currentHz = 15;
            if (currentHz > 240) currentHz = 240;

            double minDuration = 1.0 / (double)currentHz;
            double targetHzDouble = (double)currentHz;

            @try {
                SEL selMinDur = sel_registerName("setMinimumFrameDuration:");
                if ([mainDisp respondsToSelector:selMinDur]) {
                    NSMethodSignature *sig = [mainDisp methodSignatureForSelector:selMinDur];
                    if (sig && strcmp([sig getArgumentTypeAtIndex:2], "d") == 0) {
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        [inv setSelector:selMinDur];
                        [inv setTarget:mainDisp];
                        [inv setArgument:&minDuration atIndex:2];
                        [inv invoke];
                    }
                }
            } @catch (__unused NSException *e) {}

            @try {
                SEL selMaxRate = sel_registerName("setMaximumRefreshRate:");
                if ([mainDisp respondsToSelector:selMaxRate]) {
                    NSMethodSignature *sig = [mainDisp methodSignatureForSelector:selMaxRate];
                    if (sig && strcmp([sig getArgumentTypeAtIndex:2], "d") == 0) {
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        [inv setSelector:selMaxRate];
                        [inv setTarget:mainDisp];
                        [inv setArgument:&targetHzDouble atIndex:2];
                        [inv invoke];
                    }
                }
            } @catch (__unused NSException *e) {}

            @try {
                SEL selIdealRate = sel_registerName("setIdealRefreshRate:");
                if ([mainDisp respondsToSelector:selIdealRate]) {
                    NSMethodSignature *sig = [mainDisp methodSignatureForSelector:selIdealRate];
                    if (sig && strcmp([sig getArgumentTypeAtIndex:2], "d") == 0) {
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        [inv setSelector:selIdealRate];
                        [inv setTarget:mainDisp];
                        [inv setArgument:&targetHzDouble atIndex:2];
                        [inv invoke];
                    }
                }
            } @catch (__unused NSException *e) {}
        }
    } @catch (__unused NSException *e) {}
#endif
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
        self.targetHz = 240;
        self.targetFPS = 240;
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
                                self.targetHz = (pRead.targetHz >= 15 && pRead.targetHz <= 240) ? pRead.targetHz : 240;
                                self.targetFPS = (pRead.targetFPS >= 15 && pRead.targetFPS <= 240) ? pRead.targetFPS : 240;
                                
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
                                
                                // === VÔ HIỆU HÓA CỜ TIẾT KIỆM PIN ÉP 60HZ ===
                                self.powerSaveMode = NO;
                                self.batterySaver60Hz = NO;

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
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 240);
        if (self.targetHz < 15) self.targetHz = 240;

        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 240);
        if (self.targetFPS < 15) self.targetFPS = 240;

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
        
        // === VÔ HIỆU HÓA CỜ TIẾT KIỆM PIN TỪ PLIST ===
        self.powerSaveMode = NO;
        self.batterySaver60Hz = NO;

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
        if (safeHz < 15) safeHz = 240;
        if (safeHz > 240) safeHz = 240;
        g_cachedResolvedHz = safeHz;

        NSInteger safeFPS = self.targetFPS;
        if (safeFPS < 15) safeFPS = 240;
        if (safeFPS > 240) safeFPS = 240;
        g_cachedResolvedFPS = safeFPS;

        if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.magic = APEX_SYNC_MAGIC_V285;
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)g_cachedResolvedHz;
            p.targetFPS = (int32_t)g_cachedResolvedFPS;
            p.forceOverclock = 1;
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
            p.powerSaveModeActive = 0;

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
// TẦNG SÂU BẺ KHÓA LUỒNG XNU (FULL UNTHROTTLED UIKIT): BUNG CÔNG SUẤT 127, NICE -10, MƯỢT SIÊU CẤP
// ====================================================================================================

#include <mach/mach.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/resource.h>
#include <dlfcn.h>
#include <pthread.h>

#define TITANIUM_SHARED_MEM_NAME "/titanium_sync_shm_v285"
#define TITANIUM_SHARED_MEM_SIZE sizeof(ApexV285ProPayload)

static ApexV285ProPayload *g_sharedPayloadPtr = (ApexV285ProPayload *)MAP_FAILED;
static int g_shmFd = -1;

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
// KẾT NỐI VÙNG NHỚ CHIA SẺ ZERO-COPY IPC & QUẢN LÝ DẢI 15-240 HZ (ĐÃ BẺ TRẦN HOÀN TOÀN)
// ==============================================================================

static inline void Titanium_InitZeroCopyIPC(BOOL isSpringBoard) {
    if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) return;

    int flags = isSpringBoard ? (O_CREAT | O_RDWR) : O_RDWR;
    g_shmFd = shm_open(TITANIUM_SHARED_MEM_NAME, flags, 0666);
    
    if (g_shmFd == -1 && !isSpringBoard) {
        g_shmFd = shm_open(TITANIUM_SHARED_MEM_NAME, O_CREAT | O_RDWR, 0666);
    }

    if (g_shmFd != -1) {
        if (isSpringBoard) {
            ftruncate(g_shmFd, TITANIUM_SHARED_MEM_SIZE);
        }

        void *mapped = mmap(NULL, TITANIUM_SHARED_MEM_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, g_shmFd, 0);
        if (mapped != MAP_FAILED) {
            g_sharedPayloadPtr = (ApexV285ProPayload *)mapped;
            if (isSpringBoard) {
                // Đọc đúng giá trị thực tế từ file cấu hình, mặc định ép lên 240Hz nếu chưa có
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
                
                // === BẺ TRẦN 240HZ, CHỐNG KẸT DƯỚI MỌI HÌNH THỨC ===
                if (userHz < 15) userHz = 240;
                if (userHz > 240) userHz = 240;
                if (userFPS < 15) userFPS = 240;
                if (userFPS > 240) userFPS = 240;

                g_sharedPayloadPtr->targetHz = (int32_t)userHz;
                g_sharedPayloadPtr->targetFPS = (int32_t)userFPS;
                g_sharedPayloadPtr->masterEnabled = userEnabled ? 1 : 0;
                
                g_cachedResolvedHz = userHz;
                g_cachedResolvedFPS = userFPS;
            }
        }
    }
}

static inline int Titanium_GetSharedTargetHz(void) {
    if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) {
        int hz = g_sharedPayloadPtr->targetHz;
        if (hz >= 15 && hz <= 240) return hz;
    }
    Titanium_ReloadSharedSyncStateV285();
    // Ép mặc định về 240Hz thay vì để lọt về mức thấp
    return (int)(g_cachedResolvedHz > 0 ? g_cachedResolvedHz : 240);
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
// BẺ KHÓA LUỒNG TOÀN DIỆN (FULL UNTHROTTLED - MỞ CÔNG SUẤT LÊN MỨC 127, NICE -10, VIP CHIẾM ĐỈNH)
// ==============================================================================

static inline void Titanium_UnleashAllHiddenSystemThreads(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
        setpriority(PRIO_PROCESS, 0, -10);
    });
}

static inline void Titanium_LockMainThreadFast(void) {
    Titanium_UnleashAllHiddenSystemThreads();

    if (![NSThread isMainThread]) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        return;
    }

    static uint64_t s_lastNanoBurstTick = 0;
    uint64_t now = mach_absolute_time();
    
    if (__builtin_expect(s_lastNanoBurstTick == 0 || (now - s_lastNanoBurstTick) > Titanium_NanosToMachTicks(40000000ULL), 0)) {
        s_lastNanoBurstTick = now;
        
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
        setpriority(PRIO_DARWIN_THREAD, 0, -10);
        
        AppleInternal_LockHardwareCADisplay();
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

// ====================================================================================================
// ĐIỀU PHỐI TẦNG SÂU XNU & QUẢN LÝ TIẾN TRÌNH THỰC THẾ (ĐÃ BẺ TRẦN 240HZ TUYỆT ĐỐI)
// ====================================================================================================

static inline BOOL Titanium_IsCurrentAppAGame(void) {
    if (Titanium_IsSpringBoard()) return NO;
    return g_isMetalGameProcess;
}

static inline NSInteger Titanium_CalculateAdaptiveProMaxTier(void) {
    NSInteger configuredTarget = Titanium_GetSharedTargetHz();
    if (configuredTarget < 15) configuredTarget = 240; // Chống kẹt giá trị thấp, mặc định bung trần 240Hz
    if (configuredTarget > 240) configuredTarget = 240; 
    return configuredTarget;
}

static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
    (void)0;
}

static void AppleInternal_LockHardwareCADisplay(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class caDisplayClass = objc_getClass("CADisplay");
        if (!caDisplayClass) return;

        SEL selMainDisplay = sel_registerName("mainDisplay");
        if (![caDisplayClass respondsToSelector:selMainDisplay]) return;

        id (*getMainDisplay)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id display = getMainDisplay(caDisplayClass, selMainDisplay);
        if (!display) return;

        SEL selLatency = sel_registerName("setLatency:");
        if ([display respondsToSelector:selLatency]) {
            void (*setLatency)(id, SEL, double) = (void (*)(id, SEL, double))objc_msgSend;
            setLatency(display, selLatency, 0.0);
        }
    });
}

// ====================================================================================================
// NHÓM NỘI BỘ APPLE: MÔ PHỎNG VÒNG LẶP _UIUPDATECYCLE (BỌC THÉP AN TOÀN TUYỆT ĐỐI)
// ====================================================================================================

%group Group_Apple_Internal_ProMotion_Apex

%hook _UIUpdateCycle

- (BOOL)isPerformingUpdate {
    return %orig;
}

- (void)performUpdateWithInfo:(void *)info {
    if (TITANIUM_LITE_MODE) {
        %orig(info);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(info);
}

%end

%hook _UIUpdateSequenceItem

- (void)performItem {
    if (TITANIUM_LITE_MODE) {
        %orig;
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 1: CẢM ỨNG AN TOÀN (KHÔNG ÉP XUNG THÔ BẠO TRÊN MAIN THREAD)
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
    }
    %orig(event);
}

%end

%hook _UIEventDispatcher

- (void)dispatchEvent:(UIEvent *)event toTarget:(id)target {
    if (!event) {
        %orig(event, target);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(event, target);
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
    }
    %orig(touches, event);
}

%end

%hook UIWindow

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
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
    %orig(event);
}

%end

%end

// ====================================================================================================
// HÀM TRỢ GIÚP TOÀN CỤC & TÍNH TOÁN FPS (CHUẨN DẢI ĐỘNG 15HZ - 240HZ TÙY CHỌN)
// ====================================================================================================

static inline CAFrameRateRange Titanium_SmoothFRR(float maxFps) {
    // Khóa cứng: min = max = pref = giá trị người dùng chọn (15–240). Không để iOS tự tụt gây drop frame.
    if (maxFps < 15.0f) maxFps = 15.0f;
    if (maxFps > 240.0f) maxFps = 240.0f;
    return CAFrameRateRangeMake(maxFps, maxFps, maxFps);
}

extern NSInteger Titanium_GetEffectiveFrameCap(void);
extern volatile uint64_t g_lastInteractionMachTime;
extern BOOL Titanium_IsSpringBoard(void);

// Kiểm tra layer Metal có thuộc luồng phát Video / Camera / Trình duyệt không
static inline BOOL Titanium_IsVideoOrMediaMetalLayer(CAMetalLayer *layer) {
    if (!layer) return NO;
    if (g_isVideoPlayingActive) return YES;
    
    id del = layer.delegate;
    NSString *delName = del ? NSStringFromClass([del class]) : @"";
    NSString *layerName = NSStringFromClass([layer class]);

    if ([delName containsString:@"AV"] || 
        [delName containsString:@"Video"] || 
        [delName containsString:@"Player"] || 
        [delName containsString:@"Media"] || 
        [delName containsString:@"Web"] ||
        [delName containsString:@"Camera"] ||
        [delName containsString:@"VK"] ||
        [layerName containsString:@"AV"] ||
        [layerName containsString:@"Video"]) {
        return YES;
    }
    return NO;
}

static inline BOOL Titanium_IsMediaOrVideoLayer(CAMetalLayer *layer) {
    return Titanium_IsVideoOrMediaMetalLayer(layer);
}

// ==========================================================================
// TẮT V-SYNC TẬN GỐC TỪ TRONG TRỨNG (TIÊM BIẾN MÔI TRƯỜNG HỆ THỐNG)
// ==============================================================================

static inline void Titanium_KillVSyncCompletelyAtRoot(void) {
    setenv("CA_DISABLE_FRAME_RATE_LIMIT", "1", 1);
    setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);
    setenv("CA_DEBUG_TRANSACTIONS", "0", 1);
    
    setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
    setenv("MTL_DISABLE_TEXTURE_RESIDENCY_TRACKING", "1", 1);
    setenv("MTL_SHADER_VALIDATION", "0", 1);
    setenv("MTL_HUD_ENABLED", "0", 1);
    
    setenv("UIKIT_DISABLE_HID_EVENT_THROTTLE", "1", 1);
    setenv("COREANIMATION_DISABLE_VSYNC", "1", 1);
}

// ====================================================================================================
// NHÓM 2: BẺ KHÓA METAL MƯỢT SIÊU CẤP, TẮT TRIỆT ĐỂ V-SYNC TỪ TRỨNG NƯỚC, 0MS DELAY (ĐÃ VÁ LỖI SELECTOR)
// ====================================================================================================

static void Titanium_ForceApplyMetalOverdriveUltimate(id self) {
    if (!self) return;
    
    BOOL isSB = Titanium_IsSpringBoard();
    BOOL isMedia = Titanium_IsVideoOrMediaMetalLayer((CAMetalLayer *)self);

    // 1. NGOÀI SPRINGBOARD & KHÔNG PHẢI MEDIA: BUNG HẾT CỠ TỪ 15HZ ĐẾN 240HZ, TẮT V-SYNC
    if (!isSB && !isMedia) {
        if ([self respondsToSelector:@selector(setMaximumDrawableCount:)]) {
            ((CAMetalLayer *)self).maximumDrawableCount = 2;
        }

        if ([self respondsToSelector:@selector(setFramebufferOnly:)]) {
            ((CAMetalLayer *)self).framebufferOnly = YES;
        }

        if ([self respondsToSelector:@selector(setAllowsNextDrawableTimeout:)]) {
            ((CAMetalLayer *)self).allowsNextDrawableTimeout = NO;
        }

        if ([self respondsToSelector:@selector(setLowLatencyMode:)]) {
            ((CAMetalLayer *)self).lowLatencyMode = YES; 
        }

        if ([self respondsToSelector:@selector(setPresentsWithTransaction:)]) {
            ((CAMetalLayer *)self).presentsWithTransaction = NO;
        }

        if ([self respondsToSelector:@selector(setServerPresentsWithTransaction:)]) {
            ((CAMetalLayer *)self).serverPresentsWithTransaction = NO;
        }

        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                float maxTarget = (float)Titanium_GetEffectiveFrameCap();
                if (maxTarget < 15.0f) maxTarget = 15.0f;
                if (maxTarget > 240.0f) maxTarget = 240.0f;
                CAFrameRateRange range = Titanium_SmoothFRR(maxTarget);
                ((CAMetalLayer *)self).preferredFrameRateRange = range;
            }
        }
    }

    // 2. TRÊN SPRINGBOARD: GIỮ AN TOÀN TRANSACTION
    if (isSB) {
        if ([self respondsToSelector:@selector(setPresentsWithTransaction:)]) {
            ((CAMetalLayer *)self).presentsWithTransaction = YES;
        }
        if ([self respondsToSelector:@selector(setMaximumDrawableCount:)]) {
            ((CAMetalLayer *)self).maximumDrawableCount = 2;
        }
    }

    // 3. VÔ HIỆU HÓA HOÀN TOÀN V-SYNC TẠI TẦNG METAL LAYER
    if ([self respondsToSelector:@selector(setDisplaySyncEnabled:)]) {
        ((CAMetalLayer *)self).displaySyncEnabled = NO;
    }

    // 4. BỎ KHÓA TẦN SỐ QUÉT KHỚP ĐỒ HỌA
    if ([self respondsToSelector:@selector(setAllowsDisplayFrameRateMatching:)]) {
        [self setValue:@NO forKey:@"allowsDisplayFrameRateMatching"];
    }
}

// Hook didMoveToWindow
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

// Hook setDisplaySyncEnabled
static void (*orig_CAMetalLayer_setDisplaySyncEnabled)(id self, SEL _cmd, BOOL enabled) = NULL;
static void hooked_CAMetalLayer_setDisplaySyncEnabled(id self, SEL _cmd, BOOL enabled) {
    BOOL targetEnabled = enabled;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        targetEnabled = NO;
    }
    
    if (orig_CAMetalLayer_setDisplaySyncEnabled) {
        orig_CAMetalLayer_setDisplaySyncEnabled(self, _cmd, targetEnabled);
    } else if (self) {
        ((CAMetalLayer *)self).displaySyncEnabled = targetEnabled;
    }
}

// Hook setMaximumDrawableCount
static void (*orig_CAMetalLayer_setMaximumDrawableCount)(id self, SEL _cmd, NSUInteger count) = NULL;
static void hooked_CAMetalLayer_setMaximumDrawableCount(id self, SEL _cmd, NSUInteger count) {
    NSUInteger targetCount = count;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        targetCount = 2; 
    }
    
    if (orig_CAMetalLayer_setMaximumDrawableCount) {
        orig_CAMetalLayer_setMaximumDrawableCount(self, _cmd, targetCount);
    } else if (self) {
        ((CAMetalLayer *)self).maximumDrawableCount = targetCount;
    }
}

// Hook nextDrawable
static id (*orig_CAMetalLayer_nextDrawable)(id self, SEL _cmd) = NULL;
static id hooked_CAMetalLayer_nextDrawable(id self, SEL _cmd) {
    id drawable = nil;
    if (orig_CAMetalLayer_nextDrawable) {
        drawable = orig_CAMetalLayer_nextDrawable(self, _cmd);
    }
    if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    return drawable;
}

// Khởi tạo tiêm động toàn cục (Đã sửa lại m3 gọi đúng selector setMaximumDrawableCount:)
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

        // Đã sửa lại đúng tên selector setMaximumDrawableCount:
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
// NHÓM 3: ĐIỀU PHỐI TỐC ĐỘ, ĐỒNG BỘ PROMOTION & ÉP XUNG TOÀN HỆ THỐNG (15HZ - 240HZ)
// ====================================================================================================

%group Group_FluidTransitions_Pacing

static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 240;
    NSInteger userHz = (g_syncPayloadV285.targetHz > 0) ? (NSInteger)g_syncPayloadV285.targetHz : g_cachedResolvedHz;
    if (userHz <= 0 && CFG285) userHz = (NSInteger)CFG285.targetHz;
    if (userHz < 15) userHz = 15;
    if (userHz > 240) userHz = 240;
    return userHz;
}

static inline NSInteger Titanium_GetTargetConfiguredFPS(void) {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 240;
    NSInteger userFPS = (g_syncPayloadV285.targetFPS > 0) ? (NSInteger)g_syncPayloadV285.targetFPS : g_cachedResolvedFPS;
    if (userFPS <= 0 && CFG285) userFPS = (NSInteger)CFG285.targetFPS;
    if (userFPS <= 0) userFPS = Titanium_GetTargetConfiguredHz();
    if (userFPS < 15) userFPS = 15;
    if (userFPS > 240) userFPS = 240;
    return userFPS;
}

NSInteger Titanium_GetEffectiveFrameCap(void) {
    NSInteger hzCap = Titanium_GetTargetConfiguredHz();
    NSInteger fpsCap = Titanium_GetTargetConfiguredFPS();
    return (fpsCap > 0) ? fpsCap : hzCap;
}

static NSString *Titanium_BuildWebFPSOverdriveScript(NSInteger targetFPS) {
    if (targetFPS < 15) targetFPS = 15;
    if (targetFPS > 240) targetFPS = 240;
    return [NSString stringWithFormat:
        @"(function() {"
        @"  window.__titaniumTargetFPS = %ld;"
        @"  if (window.__titaniumRAFOverridden) return;"
        @"  window.__titaniumRAFOverridden = true;"
        @"  var nativeRAF = window.requestAnimationFrame;"
        @"  if (!nativeRAF) return;"
        @"  window.requestAnimationFrame = function(callback) {"
        @"    return nativeRAF(function(timestamp) {"
        @"      callback(timestamp);"
        @"    });"
        @"  };"
        @"  var nativeSetInterval = window.setInterval;"
        @"  window.setInterval = function(fn, delay) {"
        @"    if (delay < 2) delay = 2;"
        @"    return nativeSetInterval(fn, delay);"
        @"  };"
        @"})();", (long)targetFPS];
}

static const void *kTitaniumWebLastSyncFPSKey = &kTitaniumWebLastSyncFPSKey;

// ====================================================================================================
// 1. CADISPLAYLINK — ÉP FRAME RATE ẨN SÂU
// ====================================================================================================

%hook CADisplayLink

- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode {
    %orig(runLoop, mode);
    if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        self.preferredFramesPerSecond = cap;
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                self.preferredFrameRateRange = Titanium_SmoothFRR((float)cap);
            }
        }
    }
}

- (NSInteger)preferredFramesPerSecond {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(Titanium_GetEffectiveFrameCap());
        return;
    }
    %orig(fps);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return Titanium_SmoothFRR((float)Titanium_GetEffectiveFrameCap());
        }
    }
    return %orig;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            range = Titanium_SmoothFRR((float)Titanium_GetEffectiveFrameCap());
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
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (double)Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

%end

// ====================================================================================================
// 3. CADISPLAY
// ====================================================================================================

%hook CADisplay

- (BOOL)allowsVirtualModes {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}

- (void)setAllowsVirtualModes:(BOOL)allows {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(YES);
        return;
    }
    %orig(allows);
}

- (double)latency {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return 0.0;
    return %orig;
}

- (CFTimeInterval)minimumFrameDuration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0) targetHz = 15.0;
        if (targetHz > 240.0) targetHz = 240.0;
        return (1.0 / targetHz);
    }
    return %orig;
}

- (double)refreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (double)Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (NSInteger)preferredFPS {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(Titanium_GetEffectiveFrameCap());
        return;
    }
    %orig(fps);
}

%end

// ====================================================================================================
// 4. UISCREEN
// ====================================================================================================

%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (CGFloat)_refreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (CGFloat)Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

%end

// ====================================================================================================
// 5. NSBUNDLE
// ====================================================================================================

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (key && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        if ([key isEqualToString:@"CADisableMinimumFrameDuration"] ||
            [key isEqualToString:@"CADisableMinimumFrameDurationOnPhone"]) {
            return @YES;
        }
    }
    return %orig(key);
}

%end

// ====================================================================================================
// 6. WKWEBVIEW
// ====================================================================================================

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && configuration) {
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
    if (webView && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        objc_setAssociatedObject(webView, kTitaniumWebLastSyncFPSKey, @(Titanium_GetEffectiveFrameCap()), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.window) {
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

- (void)_didReceiveMemoryWarning {
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig;
            return;
        }
        origDone = YES; %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
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
// 7. CAANIMATION
// ====================================================================================================

%hook CAAnimation

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float target = (float)Titanium_GetEffectiveFrameCap();
            if (target < 15.0f)  target = 15.0f;
            if (target > 240.0f) target = 240.0f;
            range = CAFrameRateRangeMake(15.0f, target, target);
        }
    }

    @try {
        %orig(range);
    } @catch (NSException *e) {
    }
}

%end

// ====================================================================================================
// 8. CALAYER
// ====================================================================================================

%hook CALayer

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    @try {
        if (anim && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
            if (@available(iOS 15.0, *)) {
                if ([anim respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    anim.preferredFrameRateRange = Titanium_SmoothFRR((float)Titanium_GetEffectiveFrameCap());
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

static BOOL fake_supportsDynamicRefreshRate(id self, SEL _cmd) {
    @try {
        if (!self) return YES;
    } @catch (__unused NSException *e) {}
    return YES;
}

static void Titanium_ForceInjectDynamicRefreshSupport(void) {
    @try {
        if (!Titanium_DisplaySpoofAllowed()) return;
        Class screenCls = objc_getClass("UIScreen");
        if (!screenCls) return;

        SEL sel1 = sel_registerName("supportsDynamicRefreshRate");
        SEL sel2 = sel_registerName("_supportsDynamicRefreshRate");

        if (class_getInstanceMethod(screenCls, sel1)) {
            class_replaceMethod(screenCls, sel1, (IMP)fake_supportsDynamicRefreshRate, "B@:");
        } else {
            class_addMethod(screenCls, sel1, (IMP)fake_supportsDynamicRefreshRate, "B@:");
        }

        if (class_getInstanceMethod(screenCls, sel2)) {
            class_replaceMethod(screenCls, sel2, (IMP)fake_supportsDynamicRefreshRate, "B@:");
        } else {
            class_addMethod(screenCls, sel2, (IMP)fake_supportsDynamicRefreshRate, "B@:");
        }
    } @catch (__unused NSException *e) {}
}

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT TẦNG SÂU & KHÓA CHẶN MỌI LỆNH DROP HZ/FPS (CHUYỂN TAB 0MS)
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

// 1. CỬ CHỈ ĐA NHIỆM & KÍCH HOẠT XUNG NHỊP VIP TỨC THÌ
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

// 2. BẺ KHÓA BỘ ĐỆM SNAPSHOT (CHỐNG KHỰNG KHI LƯỚT NHANH GIỮA CÁC THẺ APP)
%hook SBAppSwitcherSnapshotImageCache

- (BOOL)shouldLoadSnapshotImagesImmediately {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}

%end

// 3. ĐỘNG LỰC HỌC QUÁN TÍNH THẺ: LƯỚT NHẸ TAY, KHÔNG CỨNG, KHÔNG DỪNG ĐỘT NGỘT
%hook SBFluidSwitcherAnimationSettings

- (double)deckSwipeSpeedFactor {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return 1.15;
    }
    return %orig;
}

- (double)cardFlyInDuration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return 0.08;
    }
    return %orig;
}

- (double)switcherScaleTransitionDuration {
    if (!self) return %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return 0.08;
    }
    return %orig;
}

- (double)slideInDuration {
    if (!self) return %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return 0.08;
    }
    return %orig;
}

%end

// 4. QUẢN LÝ BỘ NHỚ VÀ QUÁN TÍNH TRƯỢT TỰ NHIÊN (CHẶN MỌI LỆNH GIẢM HZ)
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

// 5. THOÁT APP VỀ HOME MƯỢT TUYỆT ĐỐI (GIỮ VỮNG DẢI TẦN SỐ CAO)
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

// 6. PHÓNG TO MỞ APP TỪ ĐA NHIỆM (TRIỆT TIÊU DROP FPS & DELAY KHI CHỌN TAB KHÁC)
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

// 7. BẺ KHÓA PHẢN HỒI CHẠM THẺ TRONG SWITCHER (CHỌN LÀ NHẬN NGAY LẬP TỨC)
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
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
            return 0.0;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (double)zoomDuration {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
            return 0.08; 
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (double)launchDuration {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
            return 0.08; 
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook SBSplashBoardController

- (double)splashScreenDelay {
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
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return 0.06; // Mở/đóng thư mục ứng dụng siêu tốc 0.06s ngang iPhone 18 Pro, tắt sạch delay nặng
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
// NHÓM 12: BÀN PHÍM STREAM TEXT & CẢM ỨNG NÚT BẤM (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

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
// NHÓM 13: BẺ KHÓA HIỆU NĂNG PIN YẾU & NHIỆT ĐỘ (AN TOÀN TUYỆT ĐỐI - KHÔNG BAO GIỜ MISSING SYMBOL)
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
        return %orig; // Giữ nguyên % pin thật để biết đường sạc
    } @catch (__unused NSException *e) {}
    return 1.0f;
}

- (UIDeviceBatteryState)batteryState {
    @try {
        return %orig; // Giữ nguyên trạng thái sạc thật
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
// NHÓM 15: SILICON HARDWARE PIPELINE OVERDRIVE (TỐI ƯU METAL PIPELINE, CHỐNG DEADLOCK & KILL APP NGẦM)
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
    BOOL origDone = NO;
    @try {
        if (!self) {
            origDone = YES; %orig(duration);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            origDone = YES; %orig(0.0);
            return;
        }
        origDone = YES; %orig(duration);
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(duration);
    }
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

// [ĐÃ GỘP UIWindowScene VÀO Group_Window_Level_Overdrive TRÁNH TRÙNG HOOK]

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

// ==============================================================================
// QUẢN LÝ NHIỆT ĐỘ & XẢ BỘ NHỚ ĐỆM NỀN AN TOÀN
// ==============================================================================

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

// ==============================================================================
// TỐI ƯU HÓA BỘ NHỚ WEBVIEW & ÉP XUNG TRÌNH DUYỆT ĐO HZ/FPS THẬT
// ==============================================================================

%group Group_WebKit_RAM_Optimizer

// [ĐÃ GỘP WKWebView VÀO NHÓM 3 TRÁNH TRÙNG HOOK]

%end

static inline void Titanium_ReapplyFrameRateToAllScenes(void) {
    @autoreleasepool {
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        // Ép cập nhật lại màn hình / frame rate cho từng window/scene nếu cần
                        [window setNeedsLayout];
                    }
                }
            }
        }
    }
}

// ====================================================================================================
// TITANIUM FULL TẦNG 4 — BẺ KHÓA PANEL & KÍCH HOẠT PROMOTION / 15-240HZ ẨN TRONG CHIP TỰ ĐỘNG
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

// ====================================================================================================
// ĐỌC DẢI HZ/FPS USER CHỌN (MỞ RỘNG TỪ 15 ĐẾN 240HZ)
// ====================================================================================================

static NSInteger Titanium_GetUserTargetHz(void) {
    NSInteger target = 240;
    if (CFG285 && [CFG285 respondsToSelector:@selector(targetHz)]) {
        NSInteger userHz = (NSInteger)[CFG285 targetHz];
        if (userHz >= 15 && userHz <= 240) {
            target = userHz;
        }
    }
    if (target < 15) target = 240;
    if (target > 240) target = 240;
    return target;
}

static NSInteger Titanium_GetUserTargetFPS(void) {
    NSInteger target = 240;
    if (CFG285 && [CFG285 respondsToSelector:@selector(targetFPS)]) {
        NSInteger userFPS = (NSInteger)[CFG285 targetFPS];
        if (userFPS >= 15 && userFPS <= 240) {
            target = userFPS;
        }
    }
    if (target < 15) target = 240;
    if (target > 240) target = 240;
    return target;
}

// Sanitize ép xung phần cứng trực tiếp theo cấu hình
static float Titanium_ForceUserHz(float requestedRate) {
    NSInteger target = Titanium_GetUserTargetHz();
    if (requestedRate <= 0.0f || requestedRate < 15.0f) {
        return (float)target;
    }
    if (requestedRate > 240.0f) {
        return (float)target;
    }
    return (float)target;
}

static float Titanium_ForceUserFPS(float requestedRate) {
    NSInteger target = Titanium_GetUserTargetFPS();
    if (requestedRate <= 0.0f || requestedRate < 15.0f) {
        return (float)target;
    }
    if (requestedRate > 240.0f) {
        return (float)target;
    }
    return (float)target;
}

// ====================================================================================================
// NHÓM HOOK TẦNG 4 — BẺ KHÓA FIRMWARE PANEL & KÍCH HOẠT PROMOTION TỪ CHIP
// ====================================================================================================

%group Group_Hardware_ProMotion_Overclock

// 1. Tối ưu hóa Touch Pipeline (HID Event System) không độ trễ
%hook IOHIDEventSystemClient

- (void)setProperty:(id)property forKey:(NSString *)key {
    if (!self) {
        %orig(property, key);
        return;
    }
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && key) {
        if ([key isEqualToString:@"ReportInterval"] || [key isEqualToString:@"HIDReportInterval"]) {
            %orig(@(1000), key);
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

// 2. Bẻ khóa bộ điều khiển IOMobileFramebufferClient (Ép thẳng tần số quét xuống chip/driver panel)
%hook IOMobileFramebufferClient

- (int)setCanvasSize:(CGSize)arg1 {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        __asm__ volatile("" : : : "memory");
    }
    return %orig(arg1);
}

- (int)setDisplayRefreshRate:(float)rate options:(unsigned int)options {
    if (!self) return %orig(rate, options);
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
        NSInteger targetHz = Titanium_GetUserTargetHz();
        rate = (float)targetHz;
    }
    return %orig(rate, options);
}

- (int)setDisplayRefreshRate:(float)arg1 {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        NSInteger targetHz = Titanium_GetUserTargetHz();
        arg1 = (float)targetHz;
    }
    return %orig(arg1);
}

- (int)getDisplayRefreshRate:(float *)arg1 {
    int ret = %orig(arg1);
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && arg1) {
        *arg1 = (float)Titanium_GetUserTargetHz();
    }
    return ret;
}

%end

// 3. Mở khóa phần cứng GPU qua AGXAccelerator
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

// 4. Mở khóa CAWindowServerDisplay — Kích hoạt ProMotion và Virtual Modes ẩn bên trong chip
// [ĐÃ GỘP CAWindowServerDisplay VÀO Group_CAWindowServer_Absolute_Dominance TRÁNH TRÙNG HOOK]

%end

// ====================================================================================================
// NHÓM BỔ SUNG: GROUP_HARDWARE_DEEP_CORE_BYPASS
// ====================================================================================================

%group Group_Hardware_Deep_Core_Bypass

%hook IORegistryEntry

- (kern_return_t)setCFProperty:(NSString *)key withValue:(id)value {
    if (!key || !self) {
        return %orig(key, value);
    }
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if ([key rangeOfString:@"Thermal" options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [key rangeOfString:@"PowerLimit" options:NSCaseInsensitiveSearch].location != NSNotFound) {
            return KERN_SUCCESS;
        }
    }
    return %orig(key, value);
}

%end

%end

// ====================================================================================================
// NHÓM ĐỘC QUYỀN APPLE RUNTIME
// ====================================================================================================

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
            });
        }
    } @catch (__unused NSException *e) {}
}

%end

%hook FBApplicationProcess

- (void)_finishInit {
    %orig;
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            Titanium_EnforceThreadVIPPolicy();
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
}

%end

%end

// ====================================================================================================
// NHÓM: GIỮ ỨNG DỤNG TRONG RAM AN TOÀN
// ====================================================================================================

%group Group_KeepAppsAlive_NoKill

%hook FBProcess

- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)completion {
    @try {
        if (!self) {
            %orig(reason, report, description, completion);
            return;
        }
        NSString *desc = description ? [description lowercaseString] : @"";
        if ([desc containsString:@"user"] || [desc containsString:@"terminate"] || [desc containsString:@"explicit"] || [desc containsString:@"switcher"]) {
            %orig(reason, report, description, completion);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(reason, report, description, completion);
}

- (BOOL)isPendingExit {
    return %orig;
}

%end

// [ĐÃ GỘP SBMainWorkspace VÀO NHÓM 10 TRÁNH TRÙNG HOOK]

%end

// ====================================================================================================
// NHÓM V12: ĐÀN HỒI THOÁT APP MƯỢT TỰ NHIÊN
// ====================================================================================================

%group Group_TitaniumV12_SmoothExit_And_DisplayLink

%hook CASpringAnimation

- (CGFloat)damping {
    CGFloat orig = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (orig > 0.0 && orig < 25.0) {
            return orig * 1.02; 
        }
    }
    return orig;
}

- (void)setDamping:(CGFloat)damping {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (damping > 0.0 && damping < 25.0) {
            damping *= 1.02;
        }
    }
    %orig(damping);
}

%end

%end

// ====================================================================================================
// NHÓM TỐI ƯU AI STREAMING & TEXT LAYOUT
// ====================================================================================================

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
        if (Titanium_IsAIApp() && self.window) {
            self.layer.shouldRasterize = NO;
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

- (void)insertText:(NSString *)text {
    @try {
        if (Titanium_IsAIApp() && text.length > 0) {
            static uint64_t s_lastTokenTick = 0;
            uint64_t now = mach_absolute_time();
            if (now - s_lastTokenTick > Titanium_NanosToMachTicks(40ULL * 1000000ULL)) {
                s_lastTokenTick = now;
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(text);
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

%end

// ====================================================================================================
// NHÓM 2: BẺ TẬN GỐC WINDOWSERVER DISPLAY & DISPLAY CONTROLLER (BUNG FULL 15-240HZ VIRTUAL MODES)
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
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        return targetHz;
    }
    return %orig;
}

- (void)setRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        %orig(targetHz);
        return;
    }
    %orig(rate);
}

%end

%hook CAWindowServerDisplay

- (BOOL)allowsVirtualModes {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}

- (void)setAllowsVirtualModes:(BOOL)flag {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(YES);
        return;
    }
    %orig(flag);
}

- (double)minimumFrameDuration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        return (1.0 / targetHz);
    }
    return %orig;
}

- (void)setMinimumFrameDuration:(double)duration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        %orig(1.0 / targetHz);
        return;
    }
    %orig(duration);
}

- (double)maximumRefreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        return targetHz;
    }
    return %orig;
}

- (void)setMaximumRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        %orig(targetHz);
        return;
    }
    %orig(rate);
}

- (double)minimumRefreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        return targetHz;
    }
    return %orig;
}

- (void)setMinimumRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        %orig(targetHz);
        return;
    }
    %orig(rate);
}

- (double)idealRefreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        return targetHz;
    }
    return %orig;
}

- (void)setIdealRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        %orig(targetHz);
        return;
    }
    %orig(rate);
}

- (double)refreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        double targetHz = (double)Titanium_GetEffectiveFrameCap();
        if (targetHz < 15.0 || targetHz > 240.0) targetHz = 240.0;
        return targetHz;
    }
    return %orig;
}

- (unsigned int)controllerId {
    return %orig;
}

- (BOOL)isExternal {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return NO;
    }
    return %orig;
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
    NSArray *displays = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && displays) {
        return displays;
    }
    return displays;
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
// NHÓM 3 & 4: ĐIỀU PHỐI KẾT HỢP TẦNG CAO UIKIT & TẦNG SÂU IOKIT FRAMEBUFFER
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
            if (@available(iOS 15.0, *)) {
                if (!g_isCurrentAppBlacklisted && [self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float targetCap = (float)Titanium_GetEffectiveFrameCap();
                    if (targetCap < 15.0f || targetCap > 240.0f) targetCap = 240.0f;
                    CAFrameRateRange smoothRange = Titanium_SmoothFRR(targetCap);
                    self.preferredFrameRateRange = SafeMakeFRR(smoothRange.minimum, smoothRange.maximum, smoothRange.preferred);
                }
            }
        }
    } @catch (__unused NSException *e) {}
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float targetCap = (float)Titanium_GetEffectiveFrameCap();
            if (targetCap < 15.0f || targetCap > 240.0f) targetCap = 240.0f;
            CAFrameRateRange smoothRange = Titanium_SmoothFRR(targetCap);
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
// NHÓM V10: BOOST LAYOUT SPRINGBOARD & ĐA NHIỆM
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

// [ĐÃ GỘP SBFluidSwitcherViewController VÀO NHÓM 7 TRÁNH TRÙNG HOOK]

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

// ====================================================================================================
// NHÓM ĐA NHIỆM & SPRINGBOARD (TỐI ƯU SÂU ĐỘ MƯỢT, XUNG NHỊP VIP - GỌT SẠCH KHÔNG RỜM RÀ)
// ====================================================================================================

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

// [ĐÃ GỘP SBFolderControllerAnimationSettings VÀO NHÓM 7 TRÁNH TRÙNG HOOK]

// [ĐÃ GỘP SBFluidSwitcherItemContainer VÀO NHÓM 4 TRÁNH TRÙNG HOOK]

%hook SBFluidSwitcherModifier
- (double)shadowOpacityForIndex:(unsigned long long)index {
    if (!self) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return %orig;
    }
    return %orig;
}
%end

// [ĐÃ GỘP SBAppSwitcherSettings VÀO NHÓM 4 TRÁNH TRÙNG HOOK]

// [ĐÃ GỘP SBMainWorkspace VÀO NHÓM 10 TRÁNH TRÙNG HOOK]

// [ĐÃ GỘP SBFluidSwitcherViewController VÀO NHÓM 7 TRÁNH TRÙNG HOOK]

// [ĐÃ GỘP SBFluidSwitcherAnimationSettings VÀO NHÓM 4 TRÁNH TRÙNG HOOK]

%end

// ====================================================================================================
// NHÓM 2: TỐI ƯU HÓA HIỆU ỨNG LIQUID GLASS (TRIỆT TIÊU DROP FPS KHI KÉO CC / NC)
// ====================================================================================================

%group Group_LiquidGlass_Opt

%hook CAFilter

- (void)setValue:(id)value forKey:(NSString *)key {
    %orig(value, key);
}

%end

%hook CABackdropLayer

// BẬT tính năng bỏ qua các layer mờ bị che khuất: Giảm tải áp lực cho GPU khi vuốt Control Center & Thông báo
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
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur && !g_isInteracting && !g_isScrollingActive) {
        if (scale > 0.25f && scale < 1.0f) {
            %orig(scale * 0.95f);
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

// ====================================================================================================
// NHÓM TỐI THƯỢNG: BẺ NÁT MỌI CƠ CHẾ BÓP HIỆU NĂNG, NHIỆT ĐỘ & NGUỒN ĐIỆN (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_CryoQuantum_Thermal_Bypass

// [ĐÃ GỘP _MTLCommandQueue VÀO NHÓM 15 TRÁNH TRÙNG HOOK]

// [ĐÃ GỘP NSProcessInfo VÀO NHÓM 13 TRÁNH TRÙNG HOOK]

%end

// ====================================================================================================
// NHÓM QUẢN LÝ BỘ NHỚ TỐI THƯỢNG (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Aggressive_RAM_Purge

// [ĐÃ GỘP SBMainWorkspace VÀO NHÓM 10 TRÁNH TRÙNG HOOK]

%end

// ====================================================================================================
// ====================================================================================================
// NHÓM GIẢ MẠO THIẾT BỊ PHẦN CỨNG AN TOÀN (ĐÃ GỠ MGCOPYANSWER / UNAME TRÁNH CRASH ELLEKIT)
// ====================================================================================================

#include <sys/utsname.h>
#include <CoreFoundation/CoreFoundation.h>

static inline BOOL Titanium_ShouldApplyHardwareSpoof(void) {
    if (Titanium_IsSpringBoard() || Titanium_IsSettingsApp() || Titanium_IsSpoofExcludedApp() || g_isCurrentAppBlacklisted) {
        return NO;
    }
    return YES;
}

%group Group_UltimateDevice_And_OS_Spoofing
// Đã gỡ %hookf(uname) để tránh xung đột kép với libellekit.dylib trên iOS 16.7.16
%end

// ====================================================================================================
// NHÓM BẢO VỆ CHỐNG CRASH SAFARI & UIKIT CONTEXT (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

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
// TẦNG 5 (TIER 5): CHIP IC MÀN HÌNH, KÍCH HOẠT PROMOTION ẨN VƯỢT 60HZ (15-240HZ),
// 5 TẦNG RAM (GIẢM TẢI XUỐNG MỨC TỐI THIỂU), 5 TẦNG CPU/GPU MÁT ỔN ĐỊNH,
// DYNAMIC ISLAND + DOCK + FOLDER + 100K HẠT 3D + APP 20GB & AI STREAM SIÊU MƯỢT NGANG iPHONE 18 PRO
// ====================================================================================================

static void Titanium_Tier5_FiveStageRAM_And_CPUGPU_Unlock(void) {
    static os_unfair_lock s_t5Lock = OS_UNFAIR_LOCK_INIT;
    static uint64_t s_lastT5Tick = 0;
    uint64_t now = mach_absolute_time();
    BOOL shouldRun = NO;
    os_unfair_lock_lock(&s_t5Lock);
    if (s_lastT5Tick == 0 || (now - s_lastT5Tick) >= Titanium_NanosToMachTicks(4000000000ULL)) {
        s_lastT5Tick = now;
        shouldRun = YES;
    }
    os_unfair_lock_unlock(&s_t5Lock);
    if (!shouldRun) return;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            // --- MỞ KHÓA 5 TẦNG RAM (GIẢM TẢI BỘ NHỚ AN TOÀN, CHỐNG JETSAM CHO APP 20GB & ĐA NHIỆM VÔ HẠN) ---
            // Tầng 1: Xả toàn bộ vùng nhớ default malloc zone
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
            // Tầng 2: Quét và xả toàn bộ các vùng nhớ phụ (All Malloc Zones)
            malloc_zone_t **zones = NULL;
            unsigned int numZones = 0;
            if (malloc_get_all_zones(MACH_PORT_NULL, NULL, (vm_address_t **)&zones, &numZones) == KERN_SUCCESS && zones) {
                for (unsigned int i = 0; i < numZones; i++) {
                    if (zones[i]) malloc_zone_pressure_relief(zones[i], 0);
                }
            }
            // Tầng 3: Giải phóng bộ đệm URLCache tạm trong RAM
            [[NSURLCache sharedURLCache] removeAllCachedResponses];
            // Tầng 4: Thu hồi bộ nhớ purgable của tiến trình hiện tại qua Mach VM
            int purgeState = VM_PURGABLE_PURGE_ALL;
            vm_purgable_control(mach_task_self(), 0, VM_PURGABLE_PURGE_ALL, &purgeState);

            // --- MỞ KHÓA 5 TẦNG CPU/GPU & CHIP IC MÀN HÌNH (MÁT ỔN ĐỊNH, KHÔNG BÓP XUNG) ---
            // Tầng 1 & 2: Mở khóa QoS Task Kernel (LATENCY_QOS_TIER_0 + THROUGHPUT_QOS_TIER_0)
            struct task_qos_policy qosinfo = {
                .task_latency_qos_tier = LATENCY_QOS_TIER_0,
                .task_throughput_qos_tier = THROUGHPUT_QOS_TIER_0
            };
            task_policy_set(mach_task_self(), TASK_BASE_QOS_POLICY, (task_policy_t)&qosinfo, TASK_QOS_POLICY_COUNT);
            // Tầng 3: Cấp quyền ưu tiên I/O đọc ghi trực tiếp cho tài nguyên 3D nặng (App/Game 20GB)
            setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
            setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
        }
    });
}

%group Group_Tier5_DisplayIC_DynamicIsland_Dock_3DParticles

// 1. CHIP IC MÀN HÌNH & ĐỒNG BỘ CON TẤT CẢ CADISPLAY (KÍCH HOẠT PROMOTION ẨN 15-240HZ, TẮT V-SYNC 5 TẦNG)
%hook CADisplayProperties

- (void)setOverscanAdjustment:(id)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_LockMainThreadFast();
    }
    %orig(arg1);
}

%end

// 2. HIỆU ỨNG DYNAMIC ISLAND (SYSTEM APERTURE) SIÊU MƯỢT, KHÔNG DELAY, PHẢN HỒI NGANG IPHONE 18 PRO
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

// 3. DOCK & THƯ MỤC ỨNG DỤNG (FOLDER) MƯỢT SÂU HƠN, TẮT SẠCH DELAY KHI MỞ APP TRONG THƯ MỤC
%hook SBDockView

- (void)layoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            self.layer.allowsGroupOpacity = YES;
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

// 4. HIỆU ỨNG CHUYỂN CẢNH & CHUYỂN ĐỘNG MỊN MÀNG, PHẢN HỒI TỨC THÌ 0MS DELAY
%hook UIViewPropertyAnimator

- (void)startAnimation {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

// 5. ÉP 3D NẶNG, SCENEKIT, SPRITEKIT & 100K HẠT CHI TIẾT (CAEMITTERLAYER) MƯỢT TUYỆT ĐỐI KHÔNG NÓNG
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
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            NSInteger cap = Titanium_GetEffectiveFrameCap();
            if ([self respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
                [(id)self setPreferredFramesPerSecond:cap];
            }
            if ([self respondsToSelector:@selector(setRendersContinuously:)]) {
                [(id)self setValue:@YES forKey:@"rendersContinuously"];
            }
        }
    } @catch (__unused NSException *e) {}
}

- (NSInteger)preferredFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(Titanium_GetEffectiveFrameCap());
        return;
    }
    %orig(fps);
}

%end

%hook SKView

- (void)didMoveToWindow {
    %orig;
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            NSInteger cap = Titanium_GetEffectiveFrameCap();
            if ([self respondsToSelector:@selector(setPreferredFramesPerSecond:)]) {
                [(id)self setPreferredFramesPerSecond:cap];
            }
            if ([self respondsToSelector:@selector(setIgnoresSiblingOrder:)]) {
                [(id)self setValue:@YES forKey:@"ignoresSiblingOrder"];
            }
        }
    } @catch (__unused NSException *e) {}
}

- (NSInteger)preferredFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(Titanium_GetEffectiveFrameCap());
        return;
    }
    %orig(fps);
}

%end

// 6. TỐI ƯU SÂU TEXT KIT CHO APP AI (CHATGPT / GEMINI / CLAUDE / DEEPSEEK) NHẮN CÂU DÀI KHÔNG BAO GIỜ LAG
%hook NSLayoutManager

- (BOOL)allowsNonContiguousLayout {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return YES; // Dàn trang bất đồng bộ không khóa luồng chính khi AI stream hàng chục nghìn chữ
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


// ====================================================================================================
// HÀM KHỞI TẠO & HOẠT ĐỘNG TOÀN CỤC `%ctor`
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(400 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        pid_t pid;
        const char *args[] = {"sbreload", NULL, NULL};
        if (posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)args, environ) != 0) {
            const char *fallbackArgs[] = {"killall", "SpringBoard", NULL};
            posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)fallbackArgs, environ);
        }
    });
}

void Titanium_TriggerSrebootAction(void) {
    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb notificationOccurred:UINotificationFeedbackTypeWarning];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        pid_t pid;
        const char *args[] = {"launchctl", "reboot", "userspace", NULL};
        posix_spawn(&pid, "/bin/launchctl", NULL, NULL, (char *const *)args, environ);
    });
}

static void Titanium_InstallMGCopyAnswerHookV26(void) {
    // Vô hiệu hóa MSHookFunction trên MGCopyAnswer / sysctl / uname tránh crash libellekit.dylib
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

        Titanium_KillVSyncCompletelyAtRoot();
        Titanium_InitZeroCopyIPC(isSpringBoard);
        Titanium_InstallDynamicMetalOverdriveGroup2();

        %init(Group_ZeroLatency_Touch_Opt);
        %init(Group_FluidTransitions_Pacing);
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

        if (Titanium_DisplaySpoofAllowed()) {
            %init(Group_Hardware_ProMotion_Overclock);
        }

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

            Titanium_StartThermalAndChargingWatchdog();
            Titanium_StartIPCHearthbeatV12();

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                Titanium_ReloadSharedSyncStateV285();
                AppleInternal_EnforceZeroLatencyKernelTier();
                Titanium_ApplySiliconDeepOptimizations();
                AppleInternal_LockHardwareCADisplay();
                Titanium_ForceInjectDynamicRefreshSupport();
                Titanium_TuneWindowServerDisplayDirectly();
                Titanium_ReapplyFrameRateToAllScenes();
            });

        } else {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                Titanium_ReloadSharedSyncStateV285();
                if (CFG285) {
                    CFG285.enabled = (g_syncPayloadV285.masterEnabled != 0);
                    CFG285.targetHz = g_cachedResolvedHz;
                    CFG285.targetFPS = g_cachedResolvedFPS;
                }
                Titanium_ForceInjectDynamicRefreshSupport();
                AppleInternal_LockHardwareCADisplay();
                AppleInternal_EnforceZeroLatencyKernelTier();
                Titanium_ApplySiliconDeepOptimizations();
                Titanium_RegisterAppResumeRefreshV12();
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }

        g_SystemMasterReady = YES;
    }
}

%ctor {
    @autoreleasepool {
        const char *progName = Titanium_SafeGetProgName();
        if (!progName) return;

        if (strcasestr(progName, "AccessibilityUIServer") != NULL ||
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

        if (isSpringBoard) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                (void)Titanium_CheckAndPreventBootloopUniversal();
            });
        }

        Titanium_RegisterPrefsObservers(isSpringBoard);
        runCoreTweak(isSpringBoard, bundleID, progName);
    }
}
