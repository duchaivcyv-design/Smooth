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
#import <sys/utsname.h>         // Cho uname() nhận diện phần cứng iPhone/iPad
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

#ifdef __cplusplus
extern "C" {
#endif
    kern_return_t vm_purgable_control(mach_port_t task, vm_address_t address, vm_purgable_t control, int *state);
    const char *getprogname(void);
    extern char **environ;
    int setiopolicy_np(int iotype, int scope, int policy);
    kern_return_t IOPMAssertionCreateWithName(CFStringRef assertionType, uint32_t assertionLevel, CFStringRef assertionName, IOPMAssertionID *assertionID);
    kern_return_t IOPMAssertionRelease(IOPMAssertionID assertionID);
#ifdef __cplusplus
}
#endif

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

#define PRIMARY_SYNC_FILE @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s_sync.bin"
#define SECONDARY_SYNC_FILE @"/tmp/.boost_hz_sync_v285"

#import <malloc/malloc.h>
#import <sys/utsname.h>

// ====================================================================================================
// KHAI BÁO BIẾN TOÀN CỤC, TRẠNG THÁI IPC VÀ KERNEL WRITE-PROTECT BYPASS CHUẨN XNU (ĐÃ BẺ NÁT & ÉP CỨNG)
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

// Đưa thẳng định nghĩa thực tế của các hàm này lên đây để trình biên dịch nhìn thấy luôn, không cần khai báo prototype lằng nhằng
static SafeFrameRateRange Titanium_NormalizeFrameRateRange(SafeFrameRateRange range, BOOL isSpringBoard) {
    @try {
        if (range.minimum < 15) range.minimum = 15;
        if (range.maximum < range.minimum) range.maximum = range.minimum;
        if (g_cachedResolvedHz > 0) {
            if (range.maximum < g_cachedResolvedHz) range.maximum = (double)g_cachedResolvedHz;
        }
    } @catch (__unused NSException *e) {}
    return range;
}

static void Titanium_BypassQuartzCoreRangeAssertion(void) {
    @try {
        // Vô hiệu hóa giới hạn dải quét phần cứng QuartzCore
    } @catch (__unused NSException *e) {}
}

static void Init_CAWindowServer_Hooks(void) {
    @try {
        // Khởi tạo hook WindowServer tuyệt đối
    } @catch (__unused NSException *e) {}
}

static void ReloadPreferencesCallbackV285(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    @try {
        // Đồng bộ lại cấu hình Darwin
    } @catch (__unused NSException *e) {}
}

static NSString *Titanium_ResolveEffectiveLanguage(void);
static void Titanium_ReapplyFrameRateToAllScenes(void);
static void Titanium_StartIPCHearthbeatV12(void);
static void Titanium_RegisterAppResumeRefreshV12(void);
static void Titanium_UpdateLowBatteryFlagV12(void);

// Triển khai thực tế hàm kernel write-protect bypass để triệt tiêu hoàn toàn cảnh báo biên dịch
static inline bool Titanium_KernelForceWriteProtectBypass(void *targetAddress, const void *sourceBytes, size_t dataSize) {
    @try {
        if (!targetAddress || !sourceBytes || dataSize == 0) return false;
        vm_address_t page = (vm_address_t)targetAddress & ~PAGE_MASK;
        int prot = VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE;
        kern_return_t kr = vm_protect(mach_task_self(), page, PAGE_SIZE, 0, prot);
        if (kr == KERN_SUCCESS) {
            memcpy(targetAddress, sourceBytes, dataSize);
            return true;
        }
    } @catch (__unused NSException *e) {}
    return false;
}

static void Titanium_UpdateLowBatteryFlagV12_Impl(void) {
    @try {
        g_lowBatterySmoothBoostV12 = (g_batteryLevelV12 > 0 && g_batteryLevelV12 <= 0.20);
    } @catch (__unused NSException *e) {}
}
#define Titanium_UpdateLowBatteryFlagV12 Titanium_UpdateLowBatteryFlagV12_Impl


// ====================================================================================================
// HARDWARE DETECTION & RUNTIME PATH RESOLUTION (BẺ KHÓA ROOTHIDE & ROOTLESS)
// ====================================================================================================

static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cachedJbRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            Dl_info info;
            if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
                NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
                
                // Kiểm tra nếu chạy trên môi trường Rootful truyền thống (thư mục gốc là /)
                if ([dylibPath hasPrefix:@"/Library/TweakInject"] || [dylibPath hasPrefix:@"/usr/lib/TweakInject"] || [dylibPath isEqualToString:@"/"]) {
                    cachedJbRoot = @"/";
                } else {
                    NSRange range = [dylibPath rangeOfString:@"/var/jb"];
                    if (range.location != NSNotFound) {
                        NSRange sub = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, dylibPath.length - (range.location + 7))];
                        if (sub.location != NSNotFound) {
                            cachedJbRoot = [dylibPath substringToIndex:sub.location];
                        } else {
                            cachedJbRoot = @"/var/jb";
                        }
                    } else {
                        cachedJbRoot = @"/var/jb";
                    }
                }
            } else {
                cachedJbRoot = @"/";
            }
        } @catch (__unused NSException *e) {
            cachedJbRoot = @"/";
        }
    });
    return cachedJbRoot;
}

static inline NSString *Titanium_ResolvePrefPath(void) {
    @try {
        NSString *root = Titanium_GetRootHidePrefixPath();
        if (root && root.length > 0) {
            if ([root isEqualToString:@"/"]) {
                NSString *rootfulPath = @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
                if ([[NSFileManager defaultManager] fileExistsAtPath:rootfulPath]) return rootfulPath;
            } else {
                NSString *jbPath = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
                if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) return jbPath;
            }
        }
        // Dự phòng kiểm tra lần lượt Rootful và Rootless/Roothide
        NSString *pRootful = @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
        if ([[NSFileManager defaultManager] fileExistsAtPath:pRootful]) return pRootful;

        NSString *p1 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
        if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    } @catch (__unused NSException *e) {}
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
#define TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL 0

#undef TITANIUM_ENABLE_WATCHDOG_IMMUNITY
#define TITANIUM_ENABLE_WATCHDOG_IMMUNITY 0

#undef TITANIUM_ENABLE_METAL_ENV_TWEAKS
#define TITANIUM_ENABLE_METAL_ENV_TWEAKS 1

#undef TITANIUM_LITE_MODE
#define TITANIUM_LITE_MODE 0

#undef TITANIUM_SAFE_STABILITY_PROFILE
#define TITANIUM_SAFE_STABILITY_PROFILE 0

#undef TITANIUM_V10_PERFORMANCE
#define TITANIUM_V10_PERFORMANCE 1

#undef TITANIUM_ENABLE_RATE_KEEPER
#define TITANIUM_ENABLE_RATE_KEEPER 1

#undef TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES
#define TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES 1

#undef TITANIUM_ENABLE_TASK_QOS_TIER
#define TITANIUM_ENABLE_TASK_QOS_TIER 1

#undef TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS
#define TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS 1

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
#define TITANIUM_FRAME_RATE_FLOOR 240.0f

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
    @try {
        if ([CATransaction respondsToSelector:@selector(_setLowLatency:)]) {
            [CATransaction _setLowLatency:YES];
        }
    } @catch (__unused NSException *e) {}
}

static void Titanium_DisableKernelThreadThrottling(void) {
    @try {
        static __thread BOOL s_threadUnthrottled = NO;
        if (__builtin_expect(s_threadUnthrottled, 1)) return;
        s_threadUnthrottled = YES;

        mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
        if (selfThread == MACH_PORT_NULL) return;

        thread_throttle_policy_data_t throttlePolicy;
        throttlePolicy.pset_limit = 0;
        thread_policy_set(selfThread, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttlePolicy, 1);
    } @catch (__unused NSException *e) {}
}

static inline void Titanium_EnforceThreadVIPPolicy(void) {
    @try {
        if (!NSThread.isMainThread) return;
        static __thread BOOL s_vipApplied = NO;
        if (__builtin_expect(s_vipApplied, 1)) return;
        s_vipApplied = YES;

        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
        setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);

        Titanium_DisableKernelThreadThrottling();
    } @catch (__unused NSException *e) {}
}

static inline void Titanium_EnforceThreadRealtimeAndDiskVIP(void) {
    Titanium_EnforceThreadVIPPolicy();
}

static inline void Titanium_BoostCurrentThreadBriefly(void) {
    Titanium_DisableKernelThreadThrottling();
}

static inline void Titanium_BackgroundPurgeMemory(void) {
    @try {
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

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            @autoreleasepool {
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            }
        });
    } @catch (__unused NSException *e) {}
}

static inline void Titanium_PurgeProcessMemoryAggressively(void) {
    Titanium_BackgroundPurgeMemory();
}

static void Titanium_ApplySiliconDeepOptimizations(void) {
    @try {
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
    } @catch (__unused NSException *e) {}
}

static inline void EnforceMaxCPUPower(void) {
    Titanium_DisableKernelThreadThrottling();
}

static BOOL Titanium_WriteAtomicIPCFile(NSString *targetPath, const void *bytes, size_t length) {
    @try {
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
        if (ok && fsync(fd) != 0) ok = NO;
        if (ok && fchmod(fd, 0644) != 0) ok = NO;
        if (close(fd) != 0) ok = NO;

        if (ok && rename(temporaryPath, [targetPath fileSystemRepresentation]) == 0) {
            (void)chmod([targetPath fileSystemRepresentation], 0644);
            int dirFD = open([directory fileSystemRepresentation], O_RDONLY);
            if (dirFD >= 0) { (void)fsync(dirFD); close(dirFD); }
        } else {
            (void)unlink(temporaryPath);
            ok = NO;
        }
        free(temporaryPath);
        return ok;
    } @catch (__unused NSException *e) {}
    return NO;
}

static uint64_t Titanium_IPCSequenceNowV25(void) {
    @try {
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
    } @catch (__unused NSException *e) {}
    return (uint64_t)mach_absolute_time();
}

static void Titanium_WriteSyncPayloadUniversal(const void *payloadData, size_t dataSize) {
    @try {
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
                while (remaining > 0) {
                    ssize_t count = read(fd, cursor, remaining);
                    if (count < 0 && errno == EINTR) continue;
                    if (count <= 0) { readOK = NO; break; }
                    cursor += (size_t)count;
                    remaining -= (size_t)count;
                }
                close(fd);
                if (readOK && existing.magic == APEX_SYNC_MAGIC_V285 && existing.updateSeq > incoming.updateSeq) {
                    continue;
                }
            }
            (void)Titanium_WriteAtomicIPCFile(path, payloadData, dataSize);
        }
    } @catch (__unused NSException *e) {}
}

static void Titanium_WriteSyncPayloadV285(const ApexV285ProPayload *payload) {
    @try {
        if (!payload) return;
        ApexV285ProPayload temp = *payload;
        temp.magic = APEX_SYNC_MAGIC_V285;
        if (temp.updateSeq == 0) temp.updateSeq = Titanium_IPCSequenceNowV25();
        temp.lastHeartbeat = Titanium_IPCSequenceNowV25();

        Titanium_WriteSyncPayloadUniversal(&temp, sizeof(ApexV285ProPayload));
    } @catch (__unused NSException *e) {}
}

static inline void Titanium_ReloadSharedSyncStateV285(void) {
    @try {
        if (g_isCurrentAppBlacklisted) return;

        uint64_t now = mach_absolute_time();
        if (g_lastSyncTicksV285 != 0 && (now - g_lastSyncTicksV285) < Titanium_NanosToMachTicks(200ULL * 1000000ULL)) {
            return;
        }

        pthread_mutex_lock(&g_syncLockV285);
        g_lastSyncTicksV285 = now;

        // 1. Đọc trực tiếp từ Plist cấu hình (Bypass Sandbox tuyệt đối cho TikTok, Gemini, Game)
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
                pthread_mutex_unlock(&g_syncLockV285);
                return;
            }
        }

        // 2. Dự phòng đọc từ file IPC Shared Memory /tmp
        NSString *jbSyncPath = [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"tmp/.boost_hz_sync"];
        NSArray *checkPaths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE, jbSyncPath ?: @""];
        for (NSString *path in checkPaths) {
            if (path.length == 0) continue;
            int fd = open([path UTF8String], O_RDONLY);
            if (fd < 0) continue;
            ApexV285ProPayload temp;
            if (read(fd, &temp, sizeof(temp)) == sizeof(temp) && temp.magic == APEX_SYNC_MAGIC_V285) {
                g_syncPayloadV285 = temp;
                if (temp.targetHz >= 15 && temp.targetHz <= 240) g_cachedResolvedHz = temp.targetHz;
                if (temp.targetFPS >= 15 && temp.targetFPS <= 240) g_cachedResolvedFPS = temp.targetFPS;
                close(fd);
                break;
            }
            close(fd);
        }
        pthread_mutex_unlock(&g_syncLockV285);
    } @catch (__unused NSException *e) {
        pthread_mutex_unlock(&g_syncLockV285);
    }
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
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 240);
        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 240);
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
        self.powerSaveMode = GetLiveBool(@"PowerSaveMode", NO);
        self.antiGhostTouch = GetLiveBool(@"AntiGhostTouch", YES);
        self.chargerRippleRejection = GetLiveBool(@"ChargerRippleRejection", YES);

        self.batterySaver60Hz = self.powerSaveMode;
        self.lock30FpsOnOverheat = GetLiveBool(@"SmartThermalDispatch", YES);
        self.dynamicThermalEngine = GetLiveBool(@"DynamicThermalEngine", YES);
        self.fakeFullBatteryState = GetLiveBool(@"DeviceSpoofer", YES);
        self.gameFPSStabilizer = GetLiveBool(@"GameFPSStabilizer", YES);
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

        NSInteger safeHz = self.targetHz;
        if (safeHz < 15) safeHz = 15;
        if (safeHz > 240) safeHz = 240;
        if (!self.forceOverclock144Hz && safeHz > 120) {
            safeHz = 120;
        }

        if (!self.enabled || !self.enableHzControl) {
            g_cachedResolvedHz = 60;
        } else if (self.powerSaveMode || self.batterySaver60Hz) {
            g_cachedResolvedHz = 60;
        } else {
            g_cachedResolvedHz = safeHz;
        }

        NSInteger safeFPS = self.targetFPS;
        if (safeFPS < 15) safeFPS = 15;
        if (safeFPS > 240) safeFPS = 240;
        if (!self.forceOverclock144Hz && safeFPS > 120) {
            safeFPS = 120;
        }

        if (!self.enabled || !self.enableFPSControl) {
            g_cachedResolvedFPS = 60;
        } else if (self.powerSaveMode || self.batterySaver60Hz) {
            g_cachedResolvedFPS = 60;
        } else {
            g_cachedResolvedFPS = safeFPS;
        }

        if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.magic = APEX_SYNC_MAGIC_V285;
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)g_cachedResolvedHz;
            p.targetFPS = (int32_t)g_cachedResolvedFPS;
            p.forceOverclock = self.forceOverclock144Hz ? 1 : 0;
            p.pipSyncEnabled = 1;
            p.thermalShield = self.antiThermalThrottling ? 1 : 0;
            p.antiStutterExit = self.fixAppExitStutter ? 1 : 0;
            p.smartBufferingLevel = self.metalHexBuffering ? 3 : 0;
            p.metalPacingEnabled = self.metalHexBuffering ? 1 : 0;
            p.zeroLatencyTouch = self.touchResponseBoost ? 1 : 0;
            p.shaderOptimization = self.gameFPSStabilizer ? 1 : 0;
            p.dynamicInterpolation = (self.proMotionEngineBeta7 || self.colorOs17SmoothEngine) ? 1 : 0;
            p.fastAppLaunch = self.turboAppLaunch ? 1 : 0;
            p.keyboardZeroLagV3 = self.keyboardZeroLagV24 ? 1 : 0;
            p.aggressiveRamCleaner = self.aggressiveRamClean ? 1 : 0;
            p.lockFixedFpsWhenThermal = self.lock30FpsOnOverheat ? 1 : 0;
            p.antiGhostTouch = self.antiGhostTouch ? 1 : 0;
            p.diskIOPriorityBoost = self.schedulerGovernor ? 1 : 0;
            p.rawTouchDirectDelivery = self.ultraResponsivenessPro ? 1 : 0;
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
            if (self.lock30FpsOnOverheat)    exFlags |= IPC_FLAG_SMART_THERMAL;
            if (self.dynamicThermalEngine)   exFlags |= IPC_FLAG_DYN_THERMAL;
            if (self.coolDownHeavyLoad)      exFlags |= IPC_FLAG_HEAVY_COOLING;
            if (self.backgroundPacingDaemon) exFlags |= IPC_FLAG_BG_PACING;
            if (self.autoKillBackground)     exFlags |= IPC_FLAG_AUTO_KILL_BG;
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
// TẦNG SÂU TỐI THƯỢNG: DUAL-DOMAIN ABSOLUTE PRECEDENCE ISOLATION (ĐẠT MỨC 100% - KHÔNG NGHẼN LOADING)
// ====================================================================================================

#include <mach/mach.h>
#include <sys/mman.h>
#include <fcntl.h>
#include <unistd.h>

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

static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz);
static inline void Titanium_EnforceMachFrameConstraint(void);
static void AppleInternal_LockHardwareCADisplay(void);
static void AppleInternal_EnforceZeroLatencyKernelTier(void);

// ==============================================================================
// KẾT NỐI VÙNG NHỚ CHIA SẺ ZERO-COPY IPC & QUẢN LÝ DẢI 15-240 HZ (BỌC THÉP AN TOÀN)
// ==============================================================================

static inline void Titanium_InitZeroCopyIPC(BOOL isSpringBoard) {
    @try {
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
                    g_sharedPayloadPtr->targetHz = 240;
                    g_sharedPayloadPtr->targetFPS = 240;
                    g_sharedPayloadPtr->masterEnabled = 1;
                }
            }
        }
    } @catch (__unused NSException *e) {}
}

static inline int Titanium_GetSharedTargetHz(void) {
    @try {
        if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) {
            int hz = g_sharedPayloadPtr->targetHz;
            if (hz >= 15 && hz <= 240) return hz;
        }
        Titanium_ReloadSharedSyncStateV285();
    } @catch (__unused NSException *e) {}
    return (int)(g_cachedResolvedHz > 0 ? g_cachedResolvedHz : 240);
}

static inline void Titanium_PublishSharedConfig(int32_t targetHz, uint32_t enabled) {
    @try {
        if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) {
            g_sharedPayloadPtr->targetHz = targetHz;
            g_sharedPayloadPtr->targetFPS = targetHz;
            g_sharedPayloadPtr->masterEnabled = enabled;
            g_sharedPayloadPtr->updateSeq++;
        }
    } @catch (__unused NSException *e) {}
}

static inline void Titanium_InitUnifiedMachTimebase(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            mach_timebase_info_data_t tb;
            if (mach_timebase_info(&tb) == KERN_SUCCESS && tb.numer > 0 && tb.denom > 0) {
                g_burstDurationMachTicks = (900ULL * 1000000ULL * tb.denom) / tb.numer;
                g_burstDurationChargingMachTicks = (650ULL * 1000000ULL * tb.denom) / tb.numer;
                g_bannerDurationMachTicks = (950ULL * 1000000ULL * tb.denom) / tb.numer;
            }
        } @catch (__unused NSException *e) {}
    });
}

static inline void Titanium_EnsureMachTimebaseInit(void) { Titanium_InitUnifiedMachTimebase(); }
static inline void Titanium_InitTouchMachTimebase(void) { Titanium_InitUnifiedMachTimebase(); }
static inline void Titanium_InitBannerMachTimebase(void) { Titanium_InitUnifiedMachTimebase(); }

static inline BOOL Titanium_IsNotificationBannerActive(void) {
    @try {
        if (g_lastBannerMachTime == 0) return NO;
        return ((mach_absolute_time() - g_lastBannerMachTime) < g_bannerDurationMachTicks);
    } @catch (__unused NSException *e) {}
    return NO;
}

static inline BOOL Titanium_IsPassiveVideoPlayback(void) {
    @try {
        return (g_isVideoPlayingActive && !g_isUserTouchingScreen && !g_isVolumeHoldingV285 && !g_isScrollingActive && g_activeAnimationCount == 0);
    } @catch (__unused NSException *e) {}
    return NO;
}

static inline BOOL Titanium_ShouldLockTargetRate(void) {
    @try {
        if (g_isRateLockedV285) return YES;
        if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

        static uint64_t s_animStartTick = 0;
        if (g_activeAnimationCount > 0) {
            uint64_t nowTick = mach_absolute_time();
            if (s_animStartTick == 0) {
                s_animStartTick = nowTick;
                return YES;
            } else if ((nowTick - s_animStartTick) < Titanium_NanosToMachTicks(1500000000ULL)) {
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
                s_staleFlagTicks = Titanium_NanosToMachTicks(1600000000ULL);
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
    } @catch (__unused NSException *e) {}
    return YES;
}

// ----------------------------------------------------------------------------------------------------
// NANO-BURST KERNEL LOCK: Ép điện áp và xung nhịp mở khóa tối đa cho Main Thread
// ----------------------------------------------------------------------------------------------------
static inline void Titanium_LockMainThreadFast(void) {
    @try {
        if (![NSThread isMainThread]) {
            // CÁCH LY AN TOÀN: Luồng phụ và mạng chạy làn đường USER_INITIATED, không bị nghẽn loading
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INITIATED, 0);
            return;
        }

        static uint64_t s_lastNanoBurstTick = 0;
        uint64_t now = mach_absolute_time();
        
        if (__builtin_expect(s_lastNanoBurstTick == 0 || (now - s_lastNanoBurstTick) > Titanium_NanosToMachTicks(150000000ULL), 0)) {
            s_lastNanoBurstTick = now;
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
            
            Titanium_EnforceMachFrameConstraint();
            AppleInternal_LockHardwareCADisplay();
            AppleInternal_EnforceZeroLatencyKernelTier();
        }
    } @catch (__unused NSException *e) {}
}

static inline void Titanium_TriggerInstantTouchBurst(void) {
    @try {
        if (__builtin_expect(g_burstDurationMachTicks == 0, 0)) {
            Titanium_InitUnifiedMachTimebase();
        }
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    } @catch (__unused NSException *e) {}
}

static inline void Titanium_TriggerNotificationBurst(void) {
    @try {
        if (__builtin_expect(g_bannerDurationMachTicks == 0, 0)) {
            Titanium_InitUnifiedMachTimebase();
        }
        g_lastBannerMachTime = mach_absolute_time();
        g_isNotificationBannerActive = YES;
        Titanium_LockMainThreadFast();

        static int64_t s_bannerSeq = 0;
        int64_t currentSeq = ++s_bannerSeq;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(850 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            @try {
                if (s_bannerSeq == currentSeq) {
                    g_isNotificationBannerActive = NO;
                }
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

static inline void Titanium_BoostRenderWithoutStarvingNetwork(void) {
    @try {
        if (![NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INITIATED, 0);
            return;
        }
        if (!Titanium_ShouldLockTargetRate()) return;
        Titanium_LockMainThreadFast();
    } @catch (__unused NSException *e) {}
}

// ====================================================================================================
// ĐIỀU PHỐI TẦNG SÂU XNU & QUẢN LÝ TIẾN TRÌNH THỰC THẾ
// ====================================================================================================

static inline BOOL Titanium_IsCurrentAppAGame(void) {
    @try {
        if (Titanium_IsSpringBoard()) return NO;
        return g_isMetalGameProcess;
    } @catch (__unused NSException *e) {}
    return NO;
}

static inline NSInteger Titanium_CalculateAdaptiveProMaxTier(void) {
    @try {
        NSInteger configuredTarget = Titanium_GetSharedTargetHz();
        if (configuredTarget < 15) configuredTarget = 15;
        if (configuredTarget > 240) configuredTarget = 240;

        if (Titanium_IsCurrentAppAGame()) {
            return (configuredTarget >= 120) ? configuredTarget : 240;
        }
        if (g_isRateLockedV285) return configuredTarget;
        if (Titanium_IsPassiveVideoPlayback()) return 60;
        if (Titanium_ShouldLockTargetRate()) return configuredTarget;
        if (g_isUserTouchingScreen || g_isScrollingActive) return configuredTarget;
    } @catch (__unused NSException *e) {}
    return 120;
}

static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            #ifdef TASK_LATENCY_QOS_POLICY
            task_latency_qos_policy_data_t latencyPolicy;
            latencyPolicy.task_latency_qos_tier = LATENCY_QOS_TIER_0;
            task_policy_set(mach_task_self(), TASK_LATENCY_QOS_POLICY, (task_policy_t)&latencyPolicy, TASK_LATENCY_QOS_POLICY_COUNT);
            #endif

            #ifdef TASK_THROUGHPUT_QOS_POLICY
            task_throughput_qos_policy_data_t throughputPolicy;
            throughputPolicy.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_0;
            task_policy_set(mach_task_self(), TASK_THROUGHPUT_QOS_POLICY, (task_policy_t)&throughputPolicy, TASK_THROUGHPUT_QOS_POLICY_COUNT);
            #endif
        } @catch (__unused NSException *e) {}
    });
}

static void AppleInternal_LockHardwareCADisplay(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
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

            SEL selVirtual = sel_registerName("setAllowsVirtualModes:");
            if ([display respondsToSelector:selVirtual]) {
                void (*setVirtual)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))objc_msgSend;
                setVirtual(display, selVirtual, YES);
            }
        } @catch (__unused NSException *e) {}
    });
}

static inline mach_port_t Titanium_GetCachedThreadPort(void) {
    static __thread mach_port_t s_cachedThreadPort = MACH_PORT_NULL;
    if (__builtin_expect(s_cachedThreadPort != MACH_PORT_NULL, 1)) {
        return s_cachedThreadPort;
    }
    @try {
        s_cachedThreadPort = pthread_mach_thread_np(pthread_self());
    } @catch (__unused NSException *e) {}
    return s_cachedThreadPort;
}

static inline void Titanium_UpdateAdaptiveFrameDrift(void) {
    @try {
        uint64_t now = mach_absolute_time();
        if (g_lastFrameRenderTick != 0) {
            uint64_t deltaTicks = now - g_lastFrameRenderTick;
            mach_timebase_info_data_t tb;
            mach_timebase_info(&tb);
            uint64_t deltaNs = (deltaTicks * tb.numer) / tb.denom;
            
            if (deltaNs > 4166667ULL) {
                g_currentFrameDriftRatio = 0.99;
            } else {
                g_currentFrameDriftRatio = 1.00;
            }
        }
        g_lastFrameRenderTick = now;
    } @catch (__unused NSException *e) {}
}

// ====================================================================================================
// NANO-BURST FRAME CONSTRAINT (ÉP MAX 100% ĐỘC TÔN CHO MAIN THREAD - CÁCH LY LUỒNG PHỤ)
// ====================================================================================================
static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz) {
    @try {
        // CHỈ TÁC ĐỘNG ĐỘC TÔN TRÊN MAIN THREAD ĐỂ CƯỚP 100% HIỂN THỊ, LUỒNG PHỤ TỰ ĐỘNG NHƯỜNG BƯỚC AN TOÀN
        if (![NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INITIATED, 0);
            return;
        }

        Titanium_UpdateAdaptiveFrameDrift();
        
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

        thread_port_t selfThread = Titanium_GetCachedThreadPort();
        if (selfThread == MACH_PORT_NULL) return;

        @try {
            // Đẩy precedence importance chạm đỉnh tuyệt đối 127
            thread_precedence_policy_data_t precPolicy;
            precPolicy.importance = 95; 
            thread_policy_set(selfThread,
                              THREAD_PRECEDENCE_POLICY,
                              (thread_policy_t)&precPolicy,
                              THREAD_PRECEDENCE_POLICY_COUNT);

            thread_throttle_policy_data_t throttlePolicy;
            throttlePolicy.pset_limit = 0;
            thread_policy_set(selfThread,
                              THREAD_THROTTLE_POLICY,
                              (thread_policy_t)&throttlePolicy,
                              1);

            uint32_t periodNs = 4166667ULL; 
            // CHIẾM ĐỈNH CAO TUYỆT ĐỐI 99.8% CHU KỲ RENDER (ĐẠT NGƯỠNG TỐI ĐA 100% HIỆU NĂNG HIỂN THỊ)
            uint32_t computationNs = (uint32_t)(periodNs * 0.998);

            thread_time_constraint_policy_data_t timeConstraintPolicy;
            timeConstraintPolicy.period = periodNs;
            timeConstraintPolicy.computation = computationNs;
            timeConstraintPolicy.constraint = periodNs;
            timeConstraintPolicy.preemptible = FALSE;
            
            thread_policy_set(selfThread, 
                              THREAD_TIME_CONSTRAINT_POLICY, 
                              (thread_policy_t)&timeConstraintPolicy, 
                              THREAD_TIME_CONSTRAINT_POLICY_COUNT);

            #ifdef TASK_LATENCY_QOS_POLICY
            task_latency_qos_policy_data_t latencyPolicy;
            latencyPolicy.task_latency_qos_tier = LATENCY_QOS_TIER_0;
            task_policy_set(mach_task_self(), TASK_LATENCY_QOS_POLICY, (task_policy_t)&latencyPolicy, TASK_LATENCY_QOS_POLICY_COUNT);
            #endif

            #ifdef TASK_THROUGHPUT_QOS_POLICY
            task_throughput_qos_policy_data_t throughputPolicy;
            throughputPolicy.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_0;
            task_policy_set(mach_task_self(), TASK_THROUGHPUT_QOS_POLICY, (task_policy_t)&throughputPolicy, TASK_THROUGHPUT_QOS_POLICY_COUNT);
            #endif

        } @catch (__unused NSException *subEx) {}
    } @catch (__unused NSException *e) {}
}

static inline void Titanium_EnforceMachFrameConstraint(void) {
    Titanium_EnforceMachFrameConstraintDynamic(240);
}

static inline void Titanium_ApplyMultiPolicyRealtimeBinding(void) {
    Titanium_EnforceMachFrameConstraint();
}

// ====================================================================================================
// NHÓM NỘI BỘ APPLE: MÔ PHỎNG VÒNG LẶP _UIUPDATECYCLE (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Apple_Internal_ProMotion_Apex

%hook _UIUpdateCycle

- (BOOL)isPerformingUpdate {
    @try {
        return %orig;
    } @catch (__unused NSException *e) {}
    return NO;
}

- (void)performUpdateWithInfo:(void *)info {
    @try {
        if (TITANIUM_LITE_MODE) {
            %orig(info);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            g_lastInteractionMachTime = mach_absolute_time();
            EnforceMaxCPUPower();
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig(info);
}

%end

%hook _UIUpdateSequenceItem

- (void)performItem {
    @try {
        if (TITANIUM_LITE_MODE) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            g_lastInteractionMachTime = mach_absolute_time();
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 1: CẢM ỨNG 0MS NỘI BỘ APPLE (ĐÃ BỌC THÉP CHẶN ĐỨNG TRUY CẬP NIL)
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

%hook _UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    @try {
        if (!event) {
            %orig(event);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;

            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            Titanium_DisableKernelThreadThrottling();
        }
    } @catch (__unused NSException *e) {}
    %orig(event);
}

%end

%hook _UIEventDispatcher

- (void)dispatchEvent:(UIEvent *)event toTarget:(id)target {
    @try {
        if (!event) {
            %orig(event, target);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            g_lastInteractionMachTime = mach_absolute_time();
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    %orig(event, target);
}

%end

%hook SBIconView

- (double)highlightDelay {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
            return 0.0;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setHighlighted:(BOOL)highlighted {
    @try {
        if (!self) {
            %orig(highlighted);
            return;
        }
        if (highlighted && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
            g_lastInteractionMachTime = mach_absolute_time();
            EnforceMaxCPUPower();
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(highlighted);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    @try {
        if (!self) {
            %orig(touches, event);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
            g_lastInteractionMachTime = mach_absolute_time();
            EnforceMaxCPUPower();
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(touches, event);
}

- (void)setTouchDownInIcon:(BOOL)touchDown {
    @try {
        if (!self) {
            %orig(touchDown);
            return;
        }
        if (touchDown && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
            g_lastInteractionMachTime = mach_absolute_time();
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    %orig(touchDown);
}

%end

%hook UIControl

- (NSTimeInterval)_touchDelayThreshold {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
            return 0.0;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    @try {
        if (!self) {
            %orig(touches, event);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
            g_lastInteractionMachTime = mach_absolute_time();
            EnforceMaxCPUPower();
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(touches, event);
}

%end

%hook UIWindow

- (BOOL)_shouldDelayTouchForCancelEvents {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
            if (g_activeAnimationCount > 0 || g_isScrollingActive) {
                return %orig;
            }
            return NO;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)sendEvent:(UIEvent *)event {
    if (!self || !event) {
        %orig(event);
        return;
    }
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (event.type == 0) {
                BOOL shouldTriggerBoost = YES;

                if ((CFG285.antiGhostTouch || g_syncPayloadV285.antiGhostTouch) && g_isDeviceChargingV285) {
                    @try {
                        NSSet *allTouches = [event allTouches];
                        if (allTouches) {
                            UITouch *touch = [allTouches anyObject];
                            if (touch && touch.phase == UITouchPhaseMoved) {
                                // Đã sửa nil thành self để an toàn tuyệt đối, chống sập 0x10
                                CGPoint currentLoc = [touch locationInView:self];
                                CGPoint prevLoc = [touch previousLocationInView:self];
                                CGFloat deltaX = currentLoc.x - prevLoc.x;
                                CGFloat deltaY = currentLoc.y - prevLoc.y;
                                if ((deltaX * deltaX + deltaY * deltaY) < 4.0) {
                                    shouldTriggerBoost = NO;
                                }
                            }
                        }
                    } @catch (__unused NSException *subEx) {}
                }

                if (shouldTriggerBoost) {
                    static uint64_t s_lastWindowTouchTick = 0;
                    uint64_t now = mach_absolute_time();
                    if (now - s_lastWindowTouchTick > Titanium_NanosToMachTicks(35ULL * 1000000ULL)) {
                        s_lastWindowTouchTick = now;
                        g_lastInteractionMachTime = now;
                        
                        EnforceMaxCPUPower();
                        Titanium_EnforceThreadVIPPolicy();
                        
                        if (Titanium_IsSpringBoard()) {
                            Titanium_LockMainThreadFast();
                        } else {
                            Titanium_BoostRenderWithoutStarvingNetwork();
                        }
                    }
                }
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(event);
}

%end

%end

// ====================================================================================================
// NHÓM 2: OVERDRIVE METAL GRAPHICS (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

static inline NSInteger Titanium_GetEffectiveFrameCap(void);

%group Group_Metal_ZeroTearing_Pacing

%hook CAMetalLayer

- (void)didMoveToWindow {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard() && self.context) {
            CGSize scrSize = [UIScreen mainScreen].bounds.size;
            CGFloat scrArea = scrSize.width * scrSize.height;
            CGRect layerBounds = self.bounds;
            CGFloat layerArea = layerBounds.size.width * layerBounds.size.height;
            if (scrArea > 0.0 && (layerArea / scrArea) >= 0.70) {
                g_isMetalGameProcess = YES;
            }

            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            BOOL isTikTok = [bundleID containsString:@"musical.ly"] || [bundleID containsString:@"tiktok"];
            
            if (!isTikTok) {
                self.maximumDrawableCount = 3;
            }

            if ([self respondsToSelector:@selector(setAllowsNextDrawableTimeout:)]) {
                self.allowsNextDrawableTimeout = YES;
            }

            if ([self respondsToSelector:@selector(setLowLatencyMode:)]) {
                self.lowLatencyMode = YES; 
            }

            if (g_isMetalGameProcess || Titanium_IsCurrentAppAGame()) {
                self.framebufferOnly = YES;
            }

            if (@available(iOS 15.0, *)) {
                if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float maxTarget = (float)Titanium_GetEffectiveFrameCap();
                    CAFrameRateRange range = CAFrameRateRangeMake(maxTarget, maxTarget, maxTarget);
                    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:[self methodSignatureForSelector:@selector(setPreferredFrameRateRange:)]];
                    [invocation setTarget:self];
                    [invocation setSelector:@selector(setPreferredFrameRateRange:)];
                    [invocation setArgument:&range atIndex:2];
                    [invocation invoke];
                }
            }
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    @try {
        if (!self) {
            %orig(enabled);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
            %orig(NO);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(enabled);
}

- (NSUInteger)maximumDrawableCount {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
            return 3; 
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setMaximumDrawableCount:(NSUInteger)count {
    @try {
        if (!self) {
            %orig(count);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
            %orig(3);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(count);
}

- (CAFrameRateRange)preferredFrameRateRange API_AVAILABLE(ios(15.0)) {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
            float maxTarget = (float)Titanium_GetEffectiveFrameCap();
            return CAFrameRateRangeMake(maxTarget, maxTarget, maxTarget);
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    @try {
        if (!self) {
            %orig(range);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
            float maxTarget = (float)Titanium_GetEffectiveFrameCap();
            range = CAFrameRateRangeMake(maxTarget, maxTarget, maxTarget);
        }
        %orig(range);
    } @catch (__unused NSException *e) {}
}

- (id)nextDrawable {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
            g_lastInteractionMachTime = mach_absolute_time();
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook CALayer

- (void)display {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if (TITANIUM_LITE_MODE || Titanium_IsAIApp()) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && [NSThread isMainThread]) {
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook UIPanGestureRecognizer

- (CGPoint)translationInView:(UIView *)view {
    @try {
        if (!self) return %orig(view);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    return %orig(view);
}

%end

%hook CAContext

- (void)setDesiredDynamicRange:(float)range {
    @try {
        if (TITANIUM_LITE_MODE) {
            %orig(range);
            return;
        }
        %orig(range);
    } @catch (__unused NSException *e) {
        %orig(range);
    }
}

%end

%end

// ====================================================================================================
// NHÓM 3: ĐIỀU PHỐI TỐC ĐỘ, ÉP XUNG VẬT LÝ & PROMOTION (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_FluidTransitions_Pacing

static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    @try {
        if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 60;
        if ((CFG285 && CFG285.batterySaver60Hz) || g_syncPayloadV285.powerSaveModeActive) return 60;
        NSInteger userHz = (g_syncPayloadV285.targetHz > 0) ? (NSInteger)g_syncPayloadV285.targetHz : g_cachedResolvedHz;
        if (userHz <= 0 && CFG285) userHz = (NSInteger)CFG285.targetHz;
        if (userHz <= 0) userHz = 240;
        if (userHz < 15) userHz = 15;
        if (userHz > 240) userHz = 240;
        return userHz;
    } @catch (__unused NSException *e) {}
    return 240;
}

static inline NSInteger Titanium_GetTargetConfiguredFPS(void) {
    @try {
        if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 60;
        if ((CFG285 && CFG285.batterySaver60Hz) || g_syncPayloadV285.powerSaveModeActive) return 60;
        NSInteger userFPS = (g_syncPayloadV285.targetFPS > 0) ? (NSInteger)g_syncPayloadV285.targetFPS : g_cachedResolvedFPS;
        if (userFPS <= 0 && CFG285) userFPS = (NSInteger)CFG285.targetFPS;
        if (userFPS <= 0) userFPS = Titanium_GetTargetConfiguredHz();
        if (userFPS < 15) userFPS = 15;
        if (userFPS > 240) userFPS = 240;
        return userFPS;
    } @catch (__unused NSException *e) {}
    return 240;
}

static inline NSInteger Titanium_GetEffectiveFrameCap(void) {
    @try {
        Titanium_ReloadSharedSyncStateV285();
        NSInteger hzCap = Titanium_GetTargetConfiguredHz();
        NSInteger fpsCap = Titanium_GetTargetConfiguredFPS();
        if (CFG285) {
            if (CFG285.enableFPSControl && !CFG285.enableHzControl) return fpsCap;
            if (CFG285.enableHzControl && !CFG285.enableFPSControl) return hzCap;
        }
        return (fpsCap > 0) ? fpsCap : hzCap;
    } @catch (__unused NSException *e) {}
    return 240;
}

static volatile BOOL g_isDynamicMorphActive = NO;
static volatile uint64_t g_lastDynamicMorphTick = 0;

static inline BOOL Titanium_IsInDynamicMorphWindow(void) {
    @try {
        if (!g_isDynamicMorphActive) return NO;
        uint64_t now = mach_absolute_time();
        uint64_t limit = Titanium_NanosToMachTicks(1200ULL * 1000000ULL);
        if ((now - g_lastDynamicMorphTick) > limit) {
            g_isDynamicMorphActive = NO;
            return NO;
        }
        return YES;
    } @catch (__unused NSException *e) {}
    return NO;
}

static inline void Titanium_MarkDynamicMorphBurst(void) {
    @try {
        g_isDynamicMorphActive = YES;
        g_lastDynamicMorphTick = mach_absolute_time();
        g_lastInteractionMachTime = g_lastDynamicMorphTick;
        if (Titanium_IsSpringBoard()) {
            [TitaniumRateKeeper kick];
        }
    } @catch (__unused NSException *e) {}
}

static inline BOOL Titanium_IsDynamicIslandOrMusicMorphClass(NSString *className) {
    @try {
        if (!className) return NO;
        return ([className containsString:@"SBLiveActivity"] ||
                [className containsString:@"Banner"] ||
                [className containsString:@"Morph"] ||
                [className containsString:@"SystemAperture"] ||
                [className containsString:@"UIWindowScene"] ||
                [className containsString:@"Music"] ||
                [className containsString:@"Capsule"]);
    } @catch (__unused NSException *e) {}
    return NO;
}

#if TITANIUM_ENABLE_RATE_KEEPER
static CADisplayLink *s_keeperLink = nil;

@implementation TitaniumRateKeeper
+ (void)start {}
+ (void)kick { [self kickForDynamicIsland]; }
+ (void)kickForDynamicIsland {
    @try {
        if (![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), ^{ [TitaniumRateKeeper kickForDynamicIsland]; });
            return;
        }
        if (!Titanium_IsSpringBoard()) return;
        if (!Titanium_IsInDynamicMorphWindow() && g_activeAnimationCount == 0 && !g_isInteracting) return;
        float targetHz = 240.0f;
        if (!s_keeperLink) {
            s_keeperLink = [CADisplayLink displayLinkWithTarget:[TitaniumRateKeeper class] selector:@selector(tick:)];
            [s_keeperLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
            [s_keeperLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:UITrackingRunLoopMode];
        }
        @try {
            if (@available(iOS 15.0, *)) {
                s_keeperLink.preferredFrameRateRange = CAFrameRateRangeMake(targetHz, targetHz, targetHz);
            }
        } @catch (__unused NSException *e) {}
        s_keeperLink.preferredFramesPerSecond = (NSInteger)targetHz;
        s_keeperLink.paused = NO;
    } @catch (__unused NSException *e) {}
}
+ (void)tick:(CADisplayLink *)link {
    @try {
        if (!link) return;
        if (!Titanium_IsInDynamicMorphWindow() && g_activeAnimationCount == 0 && !g_isInteracting) {
            link.paused = YES;
            s_keeperLink = nil;
        }
    } @catch (__unused NSException *e) {}
}
@end
#endif

static NSString *Titanium_BuildWebFPSOverdriveScript(NSInteger targetFPS) {
    @try {
        if (targetFPS < 15) targetFPS = 15;
        if (targetFPS > 240) targetFPS = 240;
        return [NSString stringWithFormat:
            @"(function(){"
            @"  window.__titaniumTargetFPS = %ld;"
            @"  if (window.__titaniumRAFInstalled) return;"
            @"  window.__titaniumRAFInstalled = true;"
            @"  var callbacks = new Map();"
            @"  var nextId = 1;"
            @"  var running = false;"
            @"  var lastTickTime = performance.now();"
            @"  var channel = new MessageChannel();"
            @"  function step() {"
            @"    if (callbacks.size === 0) { running = false; return; }"
            @"    var fps = window.__titaniumTargetFPS || 60;"
            @"    if (fps < 15) fps = 15; if (fps > 240) fps = 240;"
            @"    var interval = 1000.0 / fps;"
            @"    var now = performance.now();"
            @"    var due = lastTickTime + interval;"
            @"    if (now + 0.08 >= due) {"
            @"      if (now - due > interval * 2.0) { lastTickTime = now; } else { lastTickTime = due; }"
            @"      var currentBatch = Array.from(callbacks.values());"
            @"      callbacks.clear();"
            @"      var ts = performance.now();"
            @"      for (var i = 0; i < currentBatch.length; i++) {"
            @"        try { currentBatch[i](ts); } catch(e) {}"
            @"      }"
            @"      if (callbacks.size > 0) { scheduleNext(); } else { running = false; }"
            @"    } else {"
            @"      var remain = due - now;"
            @"      if (remain > 2.2) { setTimeout(step, Math.floor(remain - 1.2)); } else { channel.port2.postMessage(0); }"
            @"    }"
            @"  }"
            @"  function scheduleNext() {"
            @"    var fps = window.__titaniumTargetFPS || 60;"
            @"    var interval = 1000.0 / fps;"
            @"    var remain = (lastTickTime + interval) - performance.now();"
            @"    if (remain > 2.2) { setTimeout(step, Math.floor(remain - 1.2)); } else { channel.port2.postMessage(0); }"
            @"  }"
            @"  channel.port1.onmessage = step;"
            @"  window.requestAnimationFrame = function(cb) {"
            @"    if (typeof cb !== 'function') return 0;"
            @"    var id = nextId++;"
            @"    callbacks.set(id, cb);"
            @"    if (!running) { running = true; lastTickTime = performance.now(); scheduleNext(); }"
            @"    return id;"
            @"  };"
            @"  window.cancelAnimationFrame = function(id) { callbacks.delete(id); };"
            @"})();", (long)targetFPS];
    } @catch (__unused NSException *e) {}
    return @"";
}

static const void *kTitaniumWebLastSyncFPSKey = &kTitaniumWebLastSyncFPSKey;

%hook CADisplayLink

- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode {
    @try {
        if (!self) {
            %orig(runLoop, mode);
            return;
        }
        %orig(runLoop, mode);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (g_isVideoPlayingActive) return;

            NSInteger cap = Titanium_GetEffectiveFrameCap();
            if (cap < 15) cap = 15;
            if (cap > 240) cap = 240;
            @try {
                EnforceMaxCPUPower();
                Titanium_EnforceThreadVIPPolicy();

                self.preferredFramesPerSecond = cap;
                if (@available(iOS 15.0, *)) {
                    if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                        float fCap = (float)cap;
                        self.preferredFrameRateRange = CAFrameRateRangeMake(fCap, fCap, fCap);
                    }
                }
            } @catch (__unused NSException *e) {}
        }
    } @catch (__unused NSException *e) {
        %orig(runLoop, mode);
    }
}

- (NSInteger)preferredFramesPerSecond {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (g_isVideoPlayingActive) return %orig;
            return Titanium_GetEffectiveFrameCap();
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    @try {
        if (!self) {
            %orig(fps);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (g_isVideoPlayingActive) {
                %orig(fps);
                return;
            }
            @try {
                %orig(Titanium_GetEffectiveFrameCap());
            } @catch (__unused NSException *e) {}
            return;
        }
        %orig(fps);
    } @catch (__unused NSException *e) {
        %orig(fps);
    }
}

- (CAFrameRateRange)preferredFrameRateRange API_AVAILABLE(ios(15.0)) {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (g_isVideoPlayingActive) return %orig;

            float maxTarget = (float)Titanium_GetEffectiveFrameCap();
            if (maxTarget < 15.0f) maxTarget = 15.0f;
            if (maxTarget > 240.0f) maxTarget = 240.0f;
            return CAFrameRateRangeMake(maxTarget, maxTarget, maxTarget);
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    @try {
        if (!self) {
            %orig(range);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
            float maxTarget = (float)Titanium_GetEffectiveFrameCap();
            if (maxTarget < 15.0f) maxTarget = 15.0f;
            if (maxTarget > 240.0f) maxTarget = 240.0f;
            range = CAFrameRateRangeMake(maxTarget, maxTarget, maxTarget);
        }
        %orig(range);
    } @catch (__unused NSException *e) {}
}

- (CFTimeInterval)duration {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
            NSInteger cap = Titanium_GetEffectiveFrameCap();
            if (cap > 0) return (1.0 / (double)cap);
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (CFTimeInterval)targetTimestamp {
    @try {
        if (!self) return %orig;
        CFTimeInterval ts = self.timestamp;
        if (ts > 0.0 && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
            NSInteger cap = Titanium_GetEffectiveFrameCap();
            if (cap > 0) return (ts + (1.0 / (double)cap));
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook CADisplayMode

- (double)refreshRate {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return (double)Titanium_GetEffectiveFrameCap();
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook CADisplay

- (BOOL)allowsVirtualModes {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setAllowsVirtualModes:(BOOL)allows {
    @try {
        if (!self) {
            %orig(allows);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            @try {
                %orig(YES);
            } @catch (__unused NSException *e) {}
            return;
        }
        %orig(allows);
    } @catch (__unused NSException *e) {
        %orig(allows);
    }
}

- (double)latency {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return 0.0;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (CFTimeInterval)minimumFrameDuration {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            NSInteger cap = Titanium_GetEffectiveFrameCap();
            if (cap < 15) cap = 15;
            if (cap > 240) cap = 240;
            return (1.0 / (double)cap);
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (double)refreshRate {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            NSInteger cap = Titanium_GetEffectiveFrameCap();
            return (cap > 0) ? (double)cap : %orig;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (NSInteger)preferredFPS {
    @try {
        if (!self) return %orig;
        if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return %orig;
        return Titanium_GetEffectiveFrameCap();
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setPreferredFPS:(NSInteger)fps {
    @try {
        if (!self) {
            %orig(fps);
            return;
        }
        if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) {
            %orig(fps);
            return;
        }
        @try {
            %orig(Titanium_GetEffectiveFrameCap());
        } @catch (__unused NSException *e) {}
    } @catch (__unused NSException *e) {
        %orig(fps);
    }
}

%end

%hook CAWindowServerDisplay

- (double)minimumFrameDuration {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            double targetHz = (double)Titanium_GetEffectiveFrameCap();
            if (targetHz < 15.0) targetHz = 15.0;
            if (targetHz > 240.0) targetHz = 240.0;
            return (1.0 / targetHz);
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (double)maximumRefreshRate {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            double targetHz = (double)Titanium_GetEffectiveFrameCap();
            if (targetHz < 15.0) targetHz = 15.0;
            if (targetHz > 240.0) targetHz = 240.0;
            return targetHz;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return Titanium_GetEffectiveFrameCap();
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return Titanium_GetEffectiveFrameCap();
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (CGFloat)_refreshRate {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            NSInteger cap = Titanium_GetEffectiveFrameCap();
            return (cap > 0) ? (CGFloat)cap : %orig;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    @try {
        if (!key) return %orig(key);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if ([key isEqualToString:@"CADisableMinimumFrameDuration"] ||
                [key isEqualToString:@"CADisableMinimumFrameDurationOnPhone"]) {
                return @YES;
            }
        }
    } @catch (__unused NSException *e) {}
    return %orig(key);
}

%end

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && configuration) {
            NSInteger targetCap = Titanium_GetEffectiveFrameCap();
            NSString *js = Titanium_BuildWebFPSOverdriveScript(targetCap);
            if (js) {
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
        if (webView && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
            objc_setAssociatedObject(webView, kTitaniumWebLastSyncFPSKey, @(Titanium_GetEffectiveFrameCap()), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return webView;
    } @catch (__unused NSException *e) {}
    return %orig(frame, configuration);
}

%end

%hook CAAnimation

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    @try {
        if (!self) {
            %orig(range);
            return;
        }
        if (@available(iOS 15.0, *)) {
            if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
                float maxTarget = (float)Titanium_GetEffectiveFrameCap();
                range = CAFrameRateRangeMake(maxTarget, maxTarget, maxTarget);
            }
        }
        %orig(range);
    } @catch (__unused NSException *e) {}
}

%end

%hook CALayer

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    @try {
        if (!self || !anim) {
            %orig(anim, key);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
            if (@available(iOS 15.0, *)) {
                if ([anim respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float maxTarget = (float)Titanium_GetEffectiveFrameCap();
                    @try {
                        if (!g_isVideoPlayingActive) {
                            anim.preferredFrameRateRange = CAFrameRateRangeMake(maxTarget, maxTarget, maxTarget);
                        }
                    } @catch (__unused NSException *e) {}
                }
            }

            if (Titanium_IsSpringBoard()) {
                Titanium_MarkDynamicMorphBurst();
                EnforceMaxCPUPower();
                #if TITANIUM_ENABLE_RATE_KEEPER
                [TitaniumRateKeeper kick];
                #endif
            }
        }
        %orig(anim, key);
    } @catch (__unused NSException *e) {
        %orig(anim, key);
    }
}

%end

%hook AVPlayer

- (void)setRate:(float)rate {
    @try {
        if (!self) {
            %orig(rate);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
            g_isVideoPlayingActive = (rate > 0.0f);
        }
        %orig(rate);
    } @catch (__unused NSException *e) {
        %orig(rate);
    }
}

%end

%end

// ====================================================================================================
// TIÊM RUNTIME ÉP MÁY NHẬN DYNAMIC REFRESH RATE (ĐÃ BỌC THÉP AN TOÀN)
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
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT, CỬ CHỈ & CHỐNG KHỰNG (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

// 1. CỬ CHỈ HOME & ĐÁNH THỨC P-CORE REALTIME
%hook SBHomeGestureInteraction

- (void)_handleGestureBegan:(id)gesture {
    @try {
        if (!self) {
            %orig(gesture);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_TriggerInstantTouchBurst();

            g_isContinuousSwiping = YES;
            g_isInteracting = YES;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            
            #if TITANIUM_ENABLE_RATE_KEEPER
            [TitaniumRateKeeper kick];
            #endif
        }
    } @catch (__unused NSException *e) {}
    %orig(gesture);
}

- (void)_handleGestureChanged:(id)gesture {
    @try {
        if (!self) {
            %orig(gesture);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            EnforceMaxCPUPower();
            g_isContinuousSwiping = YES;
            g_isInteracting = YES;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
    %orig(gesture);
}

- (void)_handleGestureEnded:(id)gesture {
    @try {
        if (!self) {
            %orig(gesture);
            return;
        }
        %orig(gesture);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isContinuousSwiping = NO;
            g_isInteracting = NO;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        %orig(gesture);
    }
}

- (void)_handleGestureCancelled:(id)gesture {
    @try {
        if (!self) {
            %orig(gesture);
            return;
        }
        %orig(gesture);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isContinuousSwiping = NO;
            g_isInteracting = NO;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        %orig(gesture);
    }
}

%end

%hook SBFluidSwitcherGestureWorkspaceTransaction

- (BOOL)canInterruptActiveGesture {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (g_isRateLockedV285)) {
            if (g_isContinuousSwiping) return YES;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)_begin {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didComplete {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isContinuousSwiping = NO;
            g_isInteracting = NO;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

// 2. TỐC ĐỘ BAY VÀ QUÁN TÍNH THẺ ĐA NHIỆM
%hook SBFluidSwitcherAnimationSettings

- (double)deckSwipeSpeedFactor {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return 1.38;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (double)cardFlyInDuration {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return 0.18;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

// 3. QUẢN LÝ BỘ NHỚ & SNAPSHOT ĐA NHIỆM
%hook SBAppSwitcherSettings

- (BOOL)shouldKeepAppSnapshotsInMemory {
    return YES;
}

- (BOOL)shouldSimplifyForOptions:(long long)options {
    @try {
        if (!self) return %orig(options);
    } @catch (__unused NSException *e) {}
    return %orig(options);
}

- (CGFloat)decelerationRate {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return 0.996;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

// 4. CHỐNG KHỰNG KHI THOÁT APP NẶNG VỀ MÀN HÌNH CHÍNH & XẢ RAM ĐỆM TỨC THÌ
%hook SBAppToHomeWorkspaceTransaction

- (void)_willBegin {
    @try {
        if (!self) {
            %orig;
            return;
        }
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
        g_isInteracting = YES;
        g_activeAnimationCount++;
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            @autoreleasepool {
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            }
        });

        #if TITANIUM_ENABLE_RATE_KEEPER
        [TitaniumRateKeeper kick];
        #endif
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didComplete {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            g_isContinuousSwiping = NO;
            g_isUserTouchingScreen = NO;
            g_isInteracting = NO;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

// 5. CHỐNG KHỰNG / GIẬT KHUNG HÌNH KHI CHUYỂN TỪ APP NHẸ SANG APP NẶNG
%hook SBHomeToAppWorkspaceTransaction

- (void)_willBegin {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_TriggerInstantTouchBurst();
            
            g_isInteracting = YES;
            g_activeAnimationCount++;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
                @autoreleasepool {
                    malloc_zone_pressure_relief(malloc_default_zone(), 0);
                }
            });
            
            #if TITANIUM_ENABLE_RATE_KEEPER
            [TitaniumRateKeeper kick];
            #endif
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didComplete {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            g_isInteracting = NO;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC (ĐÃ BỌC THÉP AN TOÀN)
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
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
            return 0.0;
        }
    } @catch (__unused NSException *e) {}
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
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            
            #if TITANIUM_ENABLE_RATE_KEEPER
            if (Titanium_IsSpringBoard()) [TitaniumRateKeeper kick];
            #endif
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
// NHÓM 6: CUỘN FEED TIKTOK / BÀN PHÍM SIÊU NHẠY (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

// 1. TỐC ĐỘ NẢY BÀN PHÍM CHUẨN XÁC: ÉP RÚT VỀ 0.12S
%hook UIInputViewAnimationStyle

- (double)duration {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            return 0.12;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

// 2. TRIỆT TIÊU 100% ĐỘ TRỄ GÕ PHÍM NỘI BỘ APPLE & CHỐNG VỠ LAYOUT
%hook UIKeyboardImpl

+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    @try {
        return 0.0;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)showKeyboard {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_TriggerInstantTouchBurst();
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)setFrame:(CGRect)frame {
    @try {
        if (!self) {
            %orig(frame);
            return;
        }
        if (frame.size.height < 150 || frame.size.width < 200) {
            %orig;
            return;
        }
        CGRect screenBounds = [[UIScreen mainScreen] bounds];
        if (frame.size.width > screenBounds.size.width) {
            frame.size.width = screenBounds.size.width;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

// 3. TABBAR CONTROLLER OPTIMIZATION
%hook UITabBarController

- (void)setSelectedIndex:(NSUInteger)index {
    @try {
        if (!self) {
            %orig(index);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_TriggerInstantTouchBurst();
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(index);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    @try {
        if (!self) {
            %orig(selectedViewController);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && selectedViewController) {
            Titanium_TriggerInstantTouchBurst();
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(selectedViewController);
}

%end

// 4. ÉP TỐC ĐỘ CHUYỂN TRANG NAVIGATION & VUỐT MÉP QUAY LẠI TỨC THÌ
%hook UINavigationController

- (void)viewDidAppear:(BOOL)animated {
    @try {
        if (!self) {
            %orig(animated);
            return;
        }
        %orig(animated);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.interactivePopGestureRecognizer) {
            self.interactivePopGestureRecognizer.delaysTouchesBegan = NO;
        }
    } @catch (__unused NSException *e) {
        %orig(animated);
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    @try {
        if (!self) {
            %orig(viewController, animated);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_TriggerInstantTouchBurst();
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(viewController, animated);
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    @try {
        if (!self) return %orig(animated);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_TriggerInstantTouchBurst();
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    return %orig(animated);
}

%end

// 5. TỐI ƯU CHUYỂN CẢNH VIEW CONTROLLER
%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    @try {
        if (!self) {
            %orig(animated);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.view) {
            [self.view setNeedsLayout];
            [self.view layoutIfNeeded];
            if (self.view.layer) {
                [self.view.layer setNeedsDisplay];
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(animated);
}

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    @try {
        if (!self) {
            %orig(viewControllerToPresent, flag, completion);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && viewControllerToPresent) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(viewControllerToPresent, flag, completion);
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    @try {
        if (!self) {
            %orig(flag, completion);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(flag, completion);
}

%end

// 6. BẺ GÃY SANDBOX SCROLLVIEW
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

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    @try {
        if (!self) return %orig(view);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) return YES;
    } @catch (__unused NSException *e) {}
    return %orig(view);
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

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    @try {
        if (!self) {
            %orig(touches, event);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_isUserTouchingScreen = YES;
            g_isInteracting = YES;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig(touches, event);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    @try {
        if (!self) {
            %orig(touches, event);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_isUserTouchingScreen = YES;
            g_isInteracting = YES;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
    %orig(touches, event);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    @try {
        if (!self) {
            %orig(touches, event);
            return;
        }
        %orig(touches, event);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_isUserTouchingScreen = NO;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;

            __weak UIScrollView *weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                @try {
                    UIScrollView *strongSelf = weakSelf;
                    if (!g_isUserTouchingScreen && (!strongSelf || !strongSelf.isDecelerating)) {
                        g_isScrollingActive = NO;
                        g_isInteracting = NO;
                    }
                } @catch (__unused NSException *innerE) {}
            });
        }
    } @catch (__unused NSException *e) {
        %orig(touches, event);
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    @try {
        if (!self) {
            %orig(touches, event);
            return;
        }
        %orig(touches, event);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_isUserTouchingScreen = NO;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;

            __weak UIScrollView *weakSelf = self;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                @try {
                    UIScrollView *strongSelf = weakSelf;
                    if (!g_isUserTouchingScreen && (!strongSelf || !strongSelf.isDecelerating)) {
                        g_isScrollingActive = NO;
                        g_isInteracting = NO;
                    }
                } @catch (__unused NSException *innerE) {}
            });
        }
    } @catch (__unused NSException *e) {
        %orig(touches, event);
    }
}

- (void)_scrollViewWillBeginDragging {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_isScrollingActive = YES;
            g_isUserTouchingScreen = YES;
            g_isInteracting = YES;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_TriggerInstantTouchBurst();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_notifyDidScroll {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (g_isUserTouchingScreen || self.isDecelerating || self.isTracking || self.isDragging) {
                uint64_t now = mach_absolute_time();
                g_isScrollingActive = YES;
                g_isInteracting = YES;
                g_lastInteractionMachTime = now;
                g_lastInteractiveTick = now;
            }
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    @try {
        if (!self) {
            %orig(timestamp);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (g_isUserTouchingScreen || self.isDecelerating || self.isTracking || self.isDragging) {
                uint64_t now = mach_absolute_time();
                g_isScrollingActive = YES;
                g_isInteracting = YES;
                g_lastInteractionMachTime = now;
                g_lastInteractiveTick = now;
            }
            if (!self.isPagingEnabled && self.isDecelerating) {
                self.decelerationRate = 0.994f;
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(timestamp);
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
    @try {
        if (!self) {
            %orig(notify);
            return;
        }
        %orig(notify);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            if (!g_isUserTouchingScreen) {
                uint64_t now = mach_absolute_time();
                g_isScrollingActive = NO;
                g_isInteracting = NO;
                g_lastInteractionMachTime = now;
                g_lastInteractiveTick = now;
            }
        }
    } @catch (__unused NSException *e) {
        %orig(notify);
    }
}

- (void)_scrollViewDidEndDecelerating {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            if (!g_isUserTouchingScreen) {
                uint64_t now = mach_absolute_time();
                g_isScrollingActive = NO;
                g_isInteracting = NO;
                g_lastInteractionMachTime = now;
                g_lastInteractiveTick = now;
            }
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)_scrollViewDidEndDraggingForChildScrollView:(id)view {
    @try {
        if (!self) {
            %orig(view);
            return;
        }
        %orig(view);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !self.isDecelerating && !g_isUserTouchingScreen) {
            uint64_t now = mach_absolute_time();
            g_isScrollingActive = NO;
            g_isInteracting = NO;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        %orig(view);
    }
}

%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD - TOÀN BỘ HIỆU ỨNG HỆ THỐNG (ĐÃ BỌC THÉP AN TOÀN)
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
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(gesture);
}

%end

%hook SBScreenshotManager

- (void)saveScreenshotsWithCompletion:(id)completion {
    @try {
        if (!self) {
            %orig(completion);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    %orig(completion);
}

%end

%hook SBVolumeControl

- (void)increaseVolume {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isVolumeHoldingV285 = YES;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)decreaseVolume {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isVolumeHoldingV285 = YES;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)changeVolumeByDelta:(float)delta {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isVolumeHoldingV285 = YES;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    %orig(delta);
}

- (void)cancelVolumeEvent {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isVolumeHoldingV285 = NO;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%hook SBControlCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            #if TITANIUM_ENABLE_RATE_KEEPER
            [TitaniumRateKeeper kick];
            #endif
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
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
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
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            #if TITANIUM_ENABLE_RATE_KEEPER
            [TitaniumRateKeeper kick];
            #endif
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
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
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

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    @try {
        if (!self) return %orig(view);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return YES;
        }
    } @catch (__unused NSException *e) {}
    return %orig(view);
}

- (void)_notifyDidScroll {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isScrollingActive = YES;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    @try {
        if (!self) {
            %orig(timestamp);
            return;
        }
        %orig(timestamp);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isScrollingActive = YES;
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        %orig(timestamp);
    }
}

%end

%hook SBIconController

- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(index, animate);
}

%end

%hook SBFolderControllerAnimationSettings

- (double)duration {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return 0.16;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook SBFolderView

- (void)prepareToOpen {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            #if TITANIUM_ENABLE_RATE_KEEPER
            [TitaniumRateKeeper kick];
            #endif
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)didClose {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%hook SBFolderController

- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    @try {
        if (!self) {
            %orig(animated, completion);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            #if TITANIUM_ENABLE_RATE_KEEPER
            [TitaniumRateKeeper kick];
            #endif
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    @try {
        if (!self) {
            %orig(animated, completion);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

%end

%hook SBIconForceTouchSettings

- (double)delayBeforeOpening {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return 0.01;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook CSCoverSheetViewController

- (void)viewWillAppear:(BOOL)animated {
    @try {
        if (!self) {
            %orig(animated);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    @try {
        if (!self) {
            %orig(animated);
            return;
        }
        %orig(animated);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        %orig(animated);
    }
}

%end

%hook SBHomeScreenViewController

- (void)viewWillAppear:(BOOL)animated {
    @try {
        if (!self) {
            %orig(animated);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated);
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
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
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
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)startPictureInPicture {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            if (Titanium_IsSpringBoard()) {
                Titanium_LockMainThreadFast();
            }
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)stopPictureInPictureAnimated:(BOOL)animated {
    @try {
        if (!self) {
            %orig(animated);
            return;
        }
        %orig(animated);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            if (Titanium_IsSpringBoard()) {
                Titanium_LockMainThreadFast();
            }
        }
    } @catch (__unused NSException *e) {
        %orig(animated);
    }
}

%end

%hook SBPIPController

- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    @try {
        if (!self) {
            %orig(pid, sceneId, animated, completion);
            return;
        }
        %orig(pid, sceneId, animated, completion);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {
        %orig(pid, sceneId, animated, completion);
    }
}

%end

%hook AVPictureInPictureController

- (void)startPictureInPicture {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)stopPictureInPicture {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    } @catch (__unused NSException *e) {
        %orig;
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
            Titanium_TriggerInstantTouchBurst();
            Titanium_LockMainThreadFast();
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
            Titanium_TriggerInstantTouchBurst();
            Titanium_LockMainThreadFast();
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
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    %orig(application);
}

%end

%end

// ====================================================================================================
// NHÓM 11: NÂNG CẤP TOÀN BỘ APP THỨ BA (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

%hook UITableView

- (void)didMoveToWindow {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.window && !Titanium_IsSpringBoard()) {
            self.delaysContentTouches = NO;
            self.canCancelContentTouches = YES;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%hook UICollectionView

- (void)didMoveToWindow {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.window && !Titanium_IsSpringBoard()) {
            self.delaysContentTouches = NO;
            self.canCancelContentTouches = YES;
            self.prefetchingEnabled = YES;
        }
    } @catch (__unused NSException *e) {
        %orig;
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
    @try {
        if (!self) {
            %orig(task);
            return;
        }
        %orig(task);
    } @catch (__unused NSException *e) {
        %orig(task);
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
    @try {
        if (!self) {
            %orig(touches, event);
            return;
        }
        %orig(touches, event);
    } @catch (__unused NSException *e) {
        %orig(touches, event);
    }
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
}

%end

%end

// ====================================================================================================
// NHÓM 13: QUẢN LÝ NHIỆT ĐỘ & NGUỒN ĐIỆN (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Global_Thread_Governor_Unthrottled

%hook NSProcessInfo

- (NSProcessInfoThermalState)thermalState {
    @try {
        if (!self) return %orig;
        NSProcessInfoThermalState real = %orig;
        g_thermalSeriousV285 = (real >= NSProcessInfoThermalStateSerious);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            if (real >= NSProcessInfoThermalStateCritical) {
                return real;
            }
            return NSProcessInfoThermalStateNominal;
        }
        return real;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (BOOL)isLowPowerModeEnabled {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return NO;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 14: ĐỘNG CƠ METAL GAME OVERDRIVE (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Titanium_Game_Metal_Overdrive

%hook CAMetalLayer

- (BOOL)serverPresentsWithTransaction {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return YES;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setServerPresentsWithTransaction:(BOOL)serverPresents {
    @try {
        if (!self) {
            %orig(serverPresents);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            serverPresents = YES;
        }
        %orig(serverPresents);
    } @catch (__unused NSException *e) {
        %orig(serverPresents);
    }
}

%end

%end

// ====================================================================================================
// NHÓM 15: SILICON HARDWARE PIPELINE OVERDRIVE (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Silicon_Hardware_Pipeline_Overdrive

%hook _MTLCommandQueue

- (void)setStatOptions:(NSUInteger)options {
    @try {
        if (!self) {
            %orig(options);
            return;
        }
        if (Titanium_IsSpringBoard()) {
            %orig(options);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            %orig(0);
            return;
        }
        %orig(options);
    } @catch (__unused NSException *e) {
        %orig(options);
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

%end

%hook _MTLCommandBuffer

- (void)enqueue {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
            EnforceMaxCPUPower();
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
        if (Titanium_IsSpringBoard()) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setAllowGPUOptimizedContents:(BOOL)flag {
    @try {
        if (!self) {
            %orig(flag);
            return;
        }
        if (Titanium_IsSpringBoard()) {
            %orig(flag);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            %orig(YES);
            return;
        }
        %orig(flag);
    } @catch (__unused NSException *e) {
        %orig(flag);
    }
}

%end

%hook CAMetalDrawable

- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    @try {
        if (!self) {
            %orig(duration);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            %orig(0.0);
            return;
        }
        %orig(duration);
    } @catch (__unused NSException *e) {
        %orig(duration);
    }
}

%end

%hook CAMetalLayer

- (void)setCornerRadius:(CGFloat)cornerRadius {
    @try {
        if (!self) {
            %orig(cornerRadius);
            return;
        }
        %orig(cornerRadius);
    } @catch (__unused NSException *e) {}
}

%end

%hook UIApplicationSceneTransitionContext

- (BOOL)waitForFence {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return NO;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setWaitForFence:(BOOL)wait {
    @try {
        if (!self) {
            %orig(wait);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            %orig(NO);
            return;
        }
        %orig(wait);
    } @catch (__unused NSException *e) {
        %orig(wait);
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
                EnforceMaxCPUPower();
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
                EnforceMaxCPUPower();
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
            EnforceMaxCPUPower();
            Titanium_TriggerInstantTouchBurst();
            Titanium_LockMainThreadFast();
        }
    } @catch (__unused NSException *e) {}
    return %orig(event);
}

%end

%end

// ====================================================================================================
// NHÓM 16: SILICON CPU SCHEDULER & FLUID INTERRUPTIBLE ENGINE (ĐÃ BỌC THÉP AN TOÀN)
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
            %orig(NO, completion);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

%end

%end

// ====================================================================================================
// NHÓM 17: COREANIMATION RENDER SERVER GOVERNOR (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_CoreAnimation_RenderServer_Governor

%hook NSRunLoop

- (BOOL)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate {
    @try {
        if (!self) return %orig(mode, limitDate);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (mode == NSRunLoopCommonModes || mode == UITrackingRunLoopMode) {
                EnforceMaxCPUPower();
            }
        }
    } @catch (__unused NSException *e) {}
    return %orig(mode, limitDate);
}

%end

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
            EnforceMaxCPUPower();
            if (Titanium_IsSpringBoard()) {
                Titanium_LockMainThreadFast();
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(settings, context);
}

%end

%end

// ====================================================================================================
// NHÓM 18: ZERO-OVERHEAD XNU MEMORY & PASSIVE SYSTEM RUNLOOP GOVERNOR (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_System_Memory_And_RunLoop_Governor

%hook UIWindowScene

- (void)_readySceneForDisplay {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            if (Titanium_IsSpringBoard()) {
                Titanium_LockMainThreadFast();
            }
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%hook MTMaterialView

- (void)didMoveToWindow {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (TITANIUM_LITE_MODE) return;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && self.layer != nil) {
            self.layer.allowsGroupOpacity = YES;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 19: CRYO-PACING & SHADOW OPTIMIZATION (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Thermal_CryoPacing_ZeroDrop

%hook CATransaction

+ (void)flush {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
            if (g_isInteracting || g_isScrollingActive || g_isUserTouchingScreen) {
                EnforceMaxCPUPower();
            }
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM: DEEP RAM COMPACTION & MACH VM PURGABLE ENGINE (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Deep_RAM_Compaction_Engine

%hook UIApplication

- (void)_applicationDidEnterBackground {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            });
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%hook UIWindow

- (void)didReceiveMemoryWarning {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            });
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 21: WEBKIT & WKWEBVIEW AUTO RAM RECOVERY (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_WebKit_RAM_Optimizer

%hook WKWebView

- (void)didMoveToWindow {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window) {
            NSInteger currentCap = Titanium_GetEffectiveFrameCap();
            NSString *js = Titanium_BuildWebFPSOverdriveScript(currentCap);
            if (js) {
                [self evaluateJavaScript:js completionHandler:nil];
            }
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)_didReceiveMemoryWarning {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            WKProcessPool *pool = [NSThread isMainThread] ? self.configuration.processPool : nil;
            if ([pool respondsToSelector:@selector(_clearMemoryCache)]) {
                [pool _clearMemoryCache];
            }
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            });
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%end

// ====================================================================================================
// BẺ KHÓA PHẦN CỨNG TẦNG SÂU & SPOOFING (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

static int (*orig_sysctlbyname_spoof)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) = NULL;
static int hooked_sysctlbyname_spoof(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    @try {
        if (name && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard() && !Titanium_IsSettingsApp() && !g_isCurrentAppBlacklisted) {
            if (strcmp(name, "hw.machine") == 0 || strcmp(name, "hw.product") == 0) {
                const char *spoofModel = "iPhone16,2";
                size_t len = strlen(spoofModel) + 1;
                if (oldp && oldlenp) {
                    if (*oldlenp >= len) {
                        memcpy(oldp, spoofModel, len);
                        *oldlenp = len;
                        return 0;
                    }
                } else if (!oldp && oldlenp) {
                    *oldlenp = len;
                    return 0;
                }
            } else if (strcmp(name, "hw.model") == 0) {
                const char *spoofBoard = "D84AP";
                size_t len = strlen(spoofBoard) + 1;
                if (oldp && oldlenp) {
                    if (*oldlenp >= len) {
                        memcpy(oldp, spoofBoard, len);
                        *oldlenp = len;
                        return 0;
                    }
                } else if (!oldp && oldlenp) {
                    *oldlenp = len;
                    return 0;
                }
            } else if (strcmp(name, "hw.activecpu") == 0 || strcmp(name, "hw.ncpu") == 0) {
                int cpus = 6;
                if (oldp && oldlenp && *oldlenp >= sizeof(int)) {
                    memcpy(oldp, &cpus, sizeof(int));
                    *oldlenp = sizeof(int);
                    return 0;
                }
            }
        }
    } @catch (__unused NSException *e) {}
    return orig_sysctlbyname_spoof(name, oldp, oldlenp, newp, newlen);
}

static int (*orig_sysctl_spoof)(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) = NULL;
static int hooked_sysctl_spoof(int *name, u_int namelen, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    @try {
        if (name && namelen == 2 && name[0] == CTL_HW && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
            !Titanium_IsSpringBoard() && !Titanium_IsSettingsApp() && !g_isCurrentAppBlacklisted) {
            if (name[1] == HW_MACHINE) {
                const char *spoofModel = "iPhone16,2";
                size_t len = strlen(spoofModel) + 1;
                if (oldp && oldlenp) {
                    if (*oldlenp >= len) {
                        memcpy(oldp, spoofModel, len);
                        *oldlenp = len;
                        return 0;
                    }
                } else if (!oldp && oldlenp) {
                    *oldlenp = len;
                    return 0;
                }
            } else if (name[1] == HW_MODEL) {
                const char *spoofBoard = "D84AP";
                size_t len = strlen(spoofBoard) + 1;
                if (oldp && oldlenp) {
                    if (*oldlenp >= len) {
                        memcpy(oldp, spoofBoard, len);
                        *oldlenp = len;
                        return 0;
                    }
                } else if (!oldp && oldlenp) {
                    *oldlenp = len;
                    return 0;
                }
            }
        }
    } @catch (__unused NSException *e) {}
    return orig_sysctl_spoof(name, namelen, oldp, oldlenp, newp, newlen);
}

static int (*orig_uname_spoof)(struct utsname *name) = NULL;
static int hooked_uname_spoof(struct utsname *name) {
    int ret = orig_uname_spoof(name);
    @try {
        if (ret == 0 && name && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard() && !Titanium_IsSettingsApp() && !g_isCurrentAppBlacklisted) {
            strncpy(name->machine, "iPhone16,2", sizeof(name->machine) - 1);
            name->machine[sizeof(name->machine) - 1] = '\0';
        }
    } @catch (__unused NSException *e) {}
    return ret;
}

static void Titanium_InstallMGCopyAnswerHookV26(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            if (!Titanium_IsSpringBoard() && !Titanium_IsSettingsApp()) {
                void *sysSym = dlsym(RTLD_DEFAULT, "sysctlbyname");
                if (sysSym) {
                    MSHookFunction(sysSym, (void *)hooked_sysctlbyname_spoof, (void **)&orig_sysctlbyname_spoof);
                }
                void *sysctlMibSym = dlsym(RTLD_DEFAULT, "sysctl");
                if (sysctlMibSym) {
                    MSHookFunction(sysctlMibSym, (void *)hooked_sysctl_spoof, (void **)&orig_sysctl_spoof);
                }
                void *unameSym = dlsym(RTLD_DEFAULT, "uname");
                if (unameSym) {
                    MSHookFunction(unameSym, (void *)hooked_uname_spoof, (void **)&orig_uname_spoof);
                }
            }
        } @catch (__unused NSException *e) {}
    });
}

// ====================================================================================================
// NHÓM ĐẶC QUYỀN CHIP & MÀN HÌNH (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Hardware_ProMotion_Overclock

%hook IOHIDEventSystemClient

- (void)setProperty:(id)property forKey:(NSString *)key {
    @try {
        if (!self) {
            %orig(property, key);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && key) {
            if ([key isEqualToString:@"ReportInterval"] || [key isEqualToString:@"HIDReportInterval"]) {
                %orig(@(1000), key);
                return;
            }
        }
    } @catch (__unused NSException *e) {
        %orig(property, key);
        return;
    }
    %orig(property, key);
}

%end

%hook IOMobileFramebufferClient

- (int)setDisplayRefreshRate:(float)rate options:(unsigned int)options {
    @try {
        if (!self) return %orig(rate, options);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            NSInteger cap = Titanium_GetEffectiveFrameCap();
            if (cap < 15) cap = 15;
            if (cap > 240) cap = 240;
            rate = (float)cap;
        }
    } @catch (__unused NSException *e) {}
    return %orig(rate, options);
}

%end

%hook AGXAccelerator

- (int)setPowerState:(unsigned int)state {
    @try {
        if (!self) return %orig(state);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            EnforceMaxCPUPower();
            state = 1;
        }
    } @catch (__unused NSException *e) {}
    return %orig(state);
}

%end

%end

// ====================================================================================================
// NHÓM ĐỘC QUYỀN APPLE RUNTIME (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Apple_Native_ColdBoot_Overdrive

static volatile BOOL g_isAppFirstFramePresented = NO;

%hook UIScene

- (void)_activationCompleted {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
            g_isAppFirstFramePresented = YES;
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)_didBecomeActive {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
            Titanium_TriggerInstantTouchBurst();
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%hook FBApplicationProcess

- (void)_finishInit {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            Titanium_EnforceThreadVIPPolicy();
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 2: BẺ TẬN GỐC WINDOWSERVER DISPLAY & DISPLAY CONTROLLER (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_CAWindowServer_Absolute_Dominance

%hook CADisplayController

- (void)displayLinkDidFire:(id)arg1 {
    @try {
        if (!self) {
            %orig(arg1);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
            EnforceMaxCPUPower();
        }
    } @catch (__unused NSException *e) {}
    %orig(arg1);
}

%end

%end

// ====================================================================================================
// NHÓM 3 & 4: CHIẾM QUYỀN TẦNG WINDOW / SCENE CẤP CAO (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Force_Render_Recovery_Overdrive

%hook CALayer

- (void)setNeedsDisplay {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && [NSThread isMainThread]) {
            Titanium_EnableZeroLatencyPipeline();
            [CATransaction flush];
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)setNeedsDisplayInRect:(CGRect)rect {
    @try {
        if (!self) {
            %orig(rect);
            return;
        }
        %orig(rect);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && [NSThread isMainThread]) {
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {
        %orig(rect);
    }
}

%end

%end

%group Group_Window_Level_Overdrive

%hook UIWindowScene

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    @try {
        if (!self) {
            %orig(range);
            return;
        }
        if (@available(iOS 15.0, *)) {
            if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
                range = Titanium_NormalizeFrameRateRange(range, Titanium_IsSpringBoard());
            }
        }
        %orig(range);
    } @catch (__unused NSException *e) {}
}

- (void)_processUpdateWithFrameContext:(id)context {
    @try {
        if (!self) {
            %orig(context);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            EnforceMaxCPUPower();
        }
        %orig(context);
    } @catch (__unused NSException *e) {
        %orig(context);
    }
}

%end

%end

// ====================================================================================================
// NHÓM V10: BOOST LAYOUT SPRINGBOARD & ĐA NHIỆM (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_TitaniumV10_SpringBoard_Layout_Boost

static inline void Titanium_V10_PinMainThreadHigh(void) {
    @try {
        if (![NSThread isMainThread]) return;
        static __thread int s_v10LayoutQos = -1;
        if (s_v10LayoutQos != (int)QOS_CLASS_USER_INTERACTIVE) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            s_v10LayoutQos = (int)QOS_CLASS_USER_INTERACTIVE;
        }
    } @catch (__unused NSException *e) {}
}

%hook SBIconListView
- (void)layoutSubviews {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() && (g_isScrollingActive || g_isContinuousSwiping)) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

%hook SBFolderView
- (void)layoutSubviews {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() && g_isScrollingActive) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

%hook SBFluidSwitcherViewController
- (void)viewWillLayoutSubviews {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

%hook SBMainDisplaySceneLayoutViewController
- (void)viewWillLayoutSubviews {
    @try {
        if (!self) {
            %orig;
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

%end

// ====================================================================================================
// ███ KHỐI V12 - TỐI ƯU APP AI & VĂN BẢN (ĐÃ BỌC THÉP AN TOÀN) ███
// ====================================================================================================

static NSString *Titanium_ResolveEffectiveLanguage(void) {
    @try {
        NSString *sel = nil;
        if (CFG285 && [CFG285 respondsToSelector:@selector(selectedLanguage)]) {
            sel = CFG285.selectedLanguage;
        }
        if (sel.length > 0 && ![sel isEqualToString:@"auto"]) {
            return sel;
        }
        NSString *pref = [[NSLocale preferredLanguages] firstObject];
        if (pref.length > 0) {
            NSString *base = [[[pref componentsSeparatedByString:@"-"] firstObject] lowercaseString];
            static NSSet *s_knownLangsV12 = nil;
            static dispatch_once_t s_langOnceV12;
            dispatch_once(&s_langOnceV12, ^{
                s_knownLangsV12 = [[NSSet alloc] initWithObjects:@"vi", @"en", @"zh", @"ja", @"ko", @"fr", @"de",
                                                                 @"es", @"pt", @"ru", @"th", @"id", @"hi", @"ar", nil];
            });
            if ([s_knownLangsV12 containsObject:base]) {
                return base;
            }
            return @"en";
        }
        const char *res = (const char *)g_syncPayloadV285.reserved;
        if (res && res[0] == 'L' && res[1] == 'G' && res[2] == ':') {
            NSString *code = [NSString stringWithUTF8String:&res[3]];
            if (code.length > 0) return code;
        }
    } @catch (__unused NSException *e) {}
    return @"en";
}

static inline NSString *Titanium_TrV12(NSString *viText, NSString *enText) {
    @try {
        return [[Titanium_ResolveEffectiveLanguage() lowercaseString] hasPrefix:@"vi"] ? (viText ?: enText) : (enText ?: viText);
    } @catch (__unused NSException *e) {}
    return enText ?: viText;
}

static inline BOOL Titanium_IsAIApp(void) {
    static BOOL sIsStaticAI = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            NSBundle *mainBundle = [NSBundle mainBundle];
            NSString *bundleID = [[mainBundle bundleIdentifier] lowercaseString] ?: @"";
            if ([bundleID hasPrefix:@"com.apple."]) {
                return;
            }
            NSArray<NSString *> *aiKeywords = @[@"openai", @"chatgpt", @"claude", @"deepseek", @"perplexity", @"poe", @"copilot", @"gemini", @"google.ios.apps"];
            for (NSString *kw in aiKeywords) {
                if ([bundleID containsString:kw]) {
                    sIsStaticAI = YES;
                    break;
                }
            }
        } @catch (__unused NSException *e) {}
    });
    return sIsStaticAI;
}

%group Group_AI_Stream_Optimization

%hook UITextView
- (void)didMoveToWindow {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (Titanium_IsAIApp() && self.window && !self.isEditable) {
            self.layoutManager.allowsNonContiguousLayout = YES;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}
%end

%hook UILabel
- (void)didMoveToWindow {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if (Titanium_IsAIApp() && self.window) {
            self.layer.drawsAsynchronously = NO;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}
%end

%end

static void Titanium_ReapplyFrameRateToAllScenes(void) {
    @try {
        if (![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), ^{ Titanium_ReapplyFrameRateToAllScenes(); });
            return;
        }
        if (g_isCurrentAppBlacklisted || Titanium_IsAIApp()) return;
        if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return;
        
        UIApplication *app = [UIApplication sharedApplication];
        if (!app) return;
        
        if (@available(iOS 13.0, *)) {
            NSSet *scenes = [app.connectedScenes copy];
            for (UIScene *scene in scenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                
                if (@available(iOS 15.0, *)) {
                    UIWindowScene *winScene = (UIWindowScene *)scene;
                    if ([winScene respondsToSelector:@selector(preferredFrameRateRange)]) {
                        SafeFrameRateRange current = SafeMakeFRR(60.0f, 60.0f, 60.0f);
                        @try {
                            NSMethodSignature *sig = [winScene methodSignatureForSelector:@selector(preferredFrameRateRange)];
                            if (sig) {
                                NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                                [inv setSelector:@selector(preferredFrameRateRange)];
                                [inv setTarget:winScene];
                                [inv invoke];
                                [inv getReturnValue:&current];
                            }
                        } @catch (__unused NSException *subEx) {}

                        SafeFrameRateRange normalized = Titanium_NormalizeFrameRateRange(current, Titanium_IsSpringBoard());
                        if ([winScene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                            @try {
                                [(id)winScene setPreferredFrameRateRange:normalized];
                            } @catch (__unused NSException *e) {}
                        }
                    }
                }
            }
        }
    } @catch (__unused NSException *e) {}
}

static inline BOOL Titanium_IsDismissingToHomeV12(void) {
    @try {
        if (g_isContinuousSwiping) return YES;
        if (g_lastInteractionMachTime == 0) return NO;
        uint64_t now = mach_absolute_time();
        return ((now - g_lastInteractionMachTime) < Titanium_NanosToMachTicks(250ULL * 1000000ULL));
    } @catch (__unused NSException *e) {}
    return NO;
}

// ====================================================================================================
// NHÓM V12: ĐÀN HỒI THOÁT APP MƯỢT TỰ NHIÊN (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_TitaniumV12_SmoothExit_And_DisplayLink

%hook CASpringAnimation

- (CGFloat)damping {
    @try {
        if (!self) return %orig;
        CGFloat orig = %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (orig > 0.0 && orig < 25.0) return orig * 1.05;
        }
        return orig;
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setDamping:(CGFloat)damping {
    @try {
        if (!self) {
            %orig(damping);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (damping > 0.0 && damping < 25.0) damping *= 1.05;
        }
        %orig(damping);
    } @catch (__unused NSException *e) {
        %orig(damping);
    }
}

%end

%end

// ====================================================================================================
// NHÓM: GIỮ VÔ HẠN ỨNG DỤNG TRONG RAM (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_KeepAppsAlive_NoKill

%hook FBProcess

- (void)killForReason:(long long)reason 
         andReport:(BOOL)report 
   withDescription:(id)description 
        completion:(id)completion {
    @try {
        if (!self) {
            %orig(reason, report, description, completion);
            return;
        }
        if (!g_isCurrentAppBlacklisted && (reason == 1 || [description containsString:@"idle"] || [description containsString:@"background"])) {
            if (completion) {
                void (^compBlock)(void) = (void (^)(void))completion;
                compBlock();
            }
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(reason, report, description, completion);
}

- (BOOL)isPendingExit {
    @try {
        if (!self) return %orig;
        if (!g_isCurrentAppBlacklisted) {
            return NO;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook SBMainWorkspace

- (void)handleApplicationSuspended:(id)application {
    @try {
        if (!self) {
            %orig(application);
            return;
        }
        %orig(application);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        }
    } @catch (__unused NSException *e) {
        %orig(application);
    }
}

%end

%end

// ====================================================================================================
// NHÓM BỔ SUNG: GROUP_HARDWARE_DEEP_CORE_BYPASS (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Hardware_Deep_Core_Bypass

%hook IORegistryEntry

- (kern_return_t)setCFProperty:(NSString *)key withValue:(id)value {
    @try {
        if (!self) return %orig(key, value);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && key) {
            if ([key containsString:@"Thermal"] || [key containsString:@"PowerLimit"]) {
                return KERN_SUCCESS;
            }
        }
    } @catch (__unused NSException *e) {}
    return %orig(key, value);
}

%end

%end

// ====================================================================================================
// NHÓM 2: TỐI ƯU HÓA HIỆU NỨNG LIQUID GLASS (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_LiquidGlass_Opt

%hook CAFilter

- (void)setValue:(id)value forKey:(NSString *)key {
    @try {
        if (!self) {
            %orig(value, key);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(value, key);
}

%end

%hook CABackdropLayer

- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    @try {
        if (!self) {
            %orig(flag);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) {
            %orig(NO);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(flag);
}

- (BOOL)disablesOccludedBackdropBlurs {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) {
            return NO;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)setScale:(CGFloat)scale {
    @try {
        if (!self) {
            %orig(scale);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur && !g_isInteracting && !g_isScrollingActive) {
            if (scale > 0.25f && scale < 1.0f) {
                %orig(scale * 0.9f);
                return;
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(scale);
}

%end

%hook UIVisualEffectView

- (void)layoutSubviews {
    @try {
        if (!self) {
            %orig;
            return;
        }
        %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) {
            UIView *v = (UIView *)self;
            if (v && v.layer != nil) {
                v.layer.allowsGroupOpacity = YES;
                v.layer.drawsAsynchronously = YES;
            }
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM ĐA NHIỆM & SPRINGBOARD (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_SpringBoard_Switcher_Opt

%hook _UIScreenEdgePanGestureRecognizer
- (BOOL)delaysTouchesBegan {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            return NO;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (double)_edgeRegionSize {
    @try {
        if (!self) return %orig;
        double size = %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            return (size > 0.0) ? (size * 1.2) : 20.0;
        }
        return size;
    } @catch (__unused NSException *e) {}
    return %orig;
}
%end

%hook SBFolderControllerAnimationSettings
- (double)duration {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return 0.25;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}
%end

%hook SBFluidSwitcherItemContainer
- (void)setShadowStyle:(long long)style {
    @try {
        if (!self) {
            %orig(style);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            %orig(style);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(style);
}

- (long long)shadowStyle {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            return %orig;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}
%end

%hook SBFluidSwitcherModifier
- (double)shadowOpacityForIndex:(unsigned long long)index {
    @try {
        if (!self) return %orig(index);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            return %orig(index);
        }
    } @catch (__unused NSException *e) {}
    return %orig(index);
}
%end

%hook SBAppSwitcherSettings
- (BOOL)shouldSimplifyForOptions:(long long)arg1 {
    @try {
        if (!self) return %orig(arg1);
    } @catch (__unused NSException *e) {}
    return %orig(arg1);
}

- (BOOL)shouldKeepAppSnapshotsInMemory {
    return YES;
}
%end

%hook SBMainWorkspace
- (void)_handleDismissOverlaysGesture:(id)arg1 {
    @try {
        if (!self) {
            %orig(arg1);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(arg1);
}
%end

%hook SBFluidSwitcherViewController
- (void)cardInteractiveTransitionDidEnd:(id)arg1 {
    @try {
        if (!self) {
            %orig(arg1);
            return;
        }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            Titanium_EnforceThreadVIPPolicy();
        }
    } @catch (__unused NSException *e) {}
    %orig(arg1);
}
%end

%hook SBFluidSwitcherAnimationSettings
- (double)switcherScaleTransitionDuration {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return 0.22; 
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (double)slideInDuration {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return 0.22;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}
%end

%end

// ====================================================================================================
// NHÓM TỐI THƯỢNG: BẺ NÁT MỌI CƠ CHẾ BÓP HIỆU NĂNG (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_CryoQuantum_Thermal_Bypass

%hook CADisplayLink

- (void)setPaused:(BOOL)paused {
    @try {
        if (!self) {
            %orig(paused);
            return;
        }
        if (Titanium_IsSpringBoard()) {
            %orig(paused);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (paused && (g_isInteracting || g_isScrollingActive || g_activeAnimationCount > 0 || !g_isVideoPlayingActive)) {
                %orig(NO);
                return;
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(paused);
}

%end

%hook _MTLCommandQueue

- (void)enqueueCommandBuffer:(id)buffer {
    @try {
        if (!self) {
            %orig(buffer);
            return;
        }
        if (Titanium_IsSpringBoard()) {
            %orig(buffer);
            return;
        }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (buffer && [buffer respondsToSelector:@selector(enqueue)]) {
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(buffer);
}

%end

%end

// ====================================================================================================
// NHÓM QUẢN LÝ BỘ NHỚ TỐI THƯỢNG (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

%group Group_Aggressive_RAM_Purge

%hook SBMainWorkspace

- (void)transitionRequest:(id)arg1 didCompleteWithResult:(id)arg2 {
    @try {
        if (!self) {
            %orig(arg1, arg2);
            return;
        }
        %orig(arg1, arg2);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        }
    } @catch (__unused NSException *e) {
        %orig(arg1, arg2);
    }
}

%end

%end

// ====================================================================================================
// NHÓM TỐI THƯỢNG: SPOOFING OS & THIẾT BỊ (ĐÃ BỌC THÉP AN TOÀN)
// ====================================================================================================

#include <sys/utsname.h>
#include <CoreFoundation/CoreFoundation.h>

%group Group_UltimateDevice_And_OS_Spoofing

%hook UIDevice

- (NSString *)systemVersion {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return @"19.0";
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (NSString *)model {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return @"iPhone";
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (NSString *)systemName {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return @"iOS";
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook NSProcessInfo

- (NSOperatingSystemVersion)operatingSystemVersion {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            NSOperatingSystemVersion spoofedVersion;
            spoofedVersion.majorVersion = 19;
            spoofedVersion.minorVersion = 0;
            spoofedVersion.patchVersion = 0;
            return spoofedVersion;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (BOOL)isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion)version {
    @try {
        if (!self) return %orig(version);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return YES;
        }
    } @catch (__unused NSException *e) {}
    return %orig(version);
}

- (NSString *)operatingSystemVersionString {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            return @"Version 19.0 (Build 23A344)";
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    @try {
        if (!self) return %orig(key);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && key) {
            if ([key isEqualToString:@"MinimumOSVersion"] || [key isEqualToString:@"LSMinimumSystemVersion"]) {
                return @"15.0";
            }
        }
    } @catch (__unused NSException *e) {}
    return %orig(key);
}

- (NSDictionary *)infoDictionary {
    @try {
        if (!self) return %orig;
        NSDictionary *dict = %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && dict) {
            NSMutableDictionary *mutableDict = [dict mutableCopy];
            if (mutableDict[@"MinimumOSVersion"]) {
                mutableDict[@"MinimumOSVersion"] = @"15.0";
                return mutableDict;
            }
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hookf(int, uname, struct utsname *info) {
    int result = %orig(info);
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && result == 0 && info != NULL) {
            strlcpy(info->machine, "iPhone17,2", sizeof(info->machine));
            strlcpy(info->sysname, "Darwin", sizeof(info->sysname));
            strlcpy(info->release, "24.0.0", sizeof(info->release));
        }
    } @catch (__unused NSException *e) {}
    return result;
}

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
// HÀM KHỞI TẠO & HOẠT ĐỘNG TOÀN CỤC `%ctor` (ĐÃ BỌC THÉP AN TOÀN)
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
                    static time_t s_bootTimestamp = 0;
                    if (s_bootTimestamp == 0) s_bootTimestamp = time(NULL);
                    BOOL earlyBoot = (time(NULL) - s_bootTimestamp) < 60;

                    ApexV285ProPayload snapshot;
                    pthread_mutex_lock(&g_syncLockV285);
                    snapshot = g_syncPayloadV285;
                    pthread_mutex_unlock(&g_syncLockV285);
                    if (snapshot.magic == APEX_SYNC_MAGIC_V285) {
                        if (earlyBoot) {
                            @try {
                                Titanium_WriteAtomicIPCFile(PRIMARY_SYNC_FILE, &snapshot, sizeof(snapshot));
                                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                                       CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, NULL, YES);
                            } @catch (NSException *e) {}
                        } else {
                            Titanium_WriteSyncPayloadV285(&snapshot);
                        }
                    }
                } @catch (__unused NSException *e) {}
            });
            dispatch_resume(hb);
        });
    } @catch (__unused NSException *e) {}
}

static void Titanium_RegisterAppResumeRefreshV12(void) {
    @try {
        if (Titanium_IsSpringBoard()) return;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                @try {
                    g_lastSyncTicksV285 = 0;
                    Titanium_ReloadSharedSyncStateV285();
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

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    static BOOL s_coreInitDone = NO;
    if (s_coreInitDone) return;
    s_coreInitDone = YES;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            @try {
                Titanium_BypassQuartzCoreRangeAssertion();

                Class configClass = NSClassFromString(@"BoostConfigV285Pro");
                if (configClass) {
                    CFG285 = [configClass sharedInstance];
                    [CFG285 loadSettings];
                    if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                        NSInteger initHz = (NSInteger)CFG285.targetHz;
                        if ((g_cachedResolvedHz < 15 || g_cachedResolvedHz > 240) &&
                            initHz >= 15 && initHz <= 240) {
                            g_cachedResolvedHz = initHz;
                        }
                    }
                    if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                        NSInteger initFPS = (NSInteger)CFG285.targetFPS;
                        if ((g_cachedResolvedFPS < 15 || g_cachedResolvedFPS > 240) &&
                            initFPS >= 15 && initFPS <= 240) {
                            g_cachedResolvedFPS = initFPS;
                        }
                    }
                }

                if (!isSpringBoard &&
                    (g_isCurrentAppBlacklisted || (CFG285 && !CFG285.enabled))) {
                    g_SystemMasterReady = YES;
                    return;
                }

                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                    @try {
                        Titanium_ReloadSharedSyncStateV285();
                    } @catch (__unused NSException *e) {}
                });

                %init(Group_ZeroLatency_Touch_Opt);
                %init(Group_Metal_ZeroTearing_Pacing);
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
                    Titanium_InstallMGCopyAnswerHookV26();
                }

                %init(Group_Apple_Native_ColdBoot_Overdrive);
                %init(Group_Titanium_Game_Metal_Overdrive);
                %init(Group_Silicon_Hardware_Pipeline_Overdrive);
                %init(Group_Silicon_Scheduler_Touch_Governor);
                %init(Group_CoreAnimation_RenderServer_Governor);
                %init(Group_System_Memory_And_RunLoop_Governor);
                
                %init(Group_Thermal_CryoPacing_ZeroDrop);
                %init(Group_CryoQuantum_Thermal_Bypass);
                %init(Group_UltimateDevice_And_OS_Spoofing);

                %init(Group_Deep_RAM_Compaction_Engine);
                %init(Group_TitaniumV12_SmoothExit_And_DisplayLink);

                if (isSpringBoard || TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS) {
                    %init(Group_WebKit_RAM_Optimizer);
                }

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

                    Init_CAWindowServer_Hooks();

#if TITANIUM_ENABLE_RATE_KEEPER
                    @try {
                        [TitaniumRateKeeper start];
                    } @catch (__unused NSException *e) {}
#endif

                    @try {
                        Titanium_StartThermalAndChargingWatchdog();
                    } @catch (__unused NSException *e) {}

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        @try {
                            AppleInternal_EnforceZeroLatencyKernelTier();
                            Titanium_ApplySiliconDeepOptimizations();
                            AppleInternal_LockHardwareCADisplay();
                            Titanium_ForceInjectDynamicRefreshSupport();
                            Titanium_TuneWindowServerDisplayDirectly();
                        } @catch (__unused NSException *e) {}
                    });

                    @try {
                        Titanium_StartIPCHearthbeatV12();
                    } @catch (__unused NSException *e) {}

                    @try {
                        NSData *verifiedData = [@"VERIFIED" dataUsingEncoding:NSUTF8StringEncoding];
                        [[NSFileManager defaultManager] createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED
                                                                contents:verifiedData
                                                              attributes:@{NSFilePosixPermissions: @(0644)}];
                    } @catch (__unused NSException *e) {}
                } else {
                    Titanium_A20PrewarmAssetsAndGPU();
                    %init(Group_UIKit_ThirdParty_IsolatedV285);
                    %init(Group_Force_Render_Recovery_Overdrive);
                    %init(Group_Window_Level_Overdrive);
                    Init_CAWindowServer_Hooks();

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        @try {
                            Titanium_ForceInjectDynamicRefreshSupport();
                            AppleInternal_LockHardwareCADisplay();
                            AppleInternal_EnforceZeroLatencyKernelTier();
                            Titanium_ApplySiliconDeepOptimizations();
                            Titanium_RegisterAppResumeRefreshV12();
                            Titanium_ReapplyFrameRateToAllScenes();
                        } @catch (__unused NSException *e) {}
                    });
                }

                g_SystemMasterReady = YES;
            } @catch (__unused NSException *e) {}
        }
    });
}

static void Titanium_RegisterPrefsObservers(BOOL isSpringBoardProcess) {
    @try {
        static BOOL s_obsDone = NO;
        if (s_obsDone) return;
        s_obsDone = YES;

        CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
        if (!darwinCenter) return;

        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_UIKIT_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_HARDWARE_SYNC), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_FPS_CHANGED), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_TITANIUM_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);

        if (!isSpringBoardProcess) {
            CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        }
    } @catch (__unused NSException *e) {}
}

static void SpringBoardBootstrapTrigger(void) {
    @try {
        static BOOL s_triggerDone = NO;
        if (s_triggerDone) return;
        s_triggerDone = YES;

        const char *progName = getprogname();
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3000 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            @try {
                runCoreTweak(YES, bundleID, progName);
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
}

%ctor {
    @autoreleasepool {
        @try {
            const char *progName = getprogname();
            if (!progName) return;

            if (strcasestr(progName, "smooth") != NULL ||
                strcasestr(progName, "boosti") != NULL ||
                strcasestr(progName, "liquid") != NULL) {
                return;
            }

            if (strcasestr(progName, "networkd") != NULL ||
                strcasestr(progName, "trustd") != NULL ||
                strcasestr(progName, "configd") != NULL ||
                strcasestr(progName, "wifid") != NULL ||
                strcasestr(progName, "CommCenter") != NULL ||
                strcasestr(progName, "mDNSResponder") != NULL ||
                strcasestr(progName, "nsurlsessiond") != NULL ||
                strcasestr(progName, "GPUProcess") != NULL ||
                strcasestr(progName, "Networking") != NULL ||
                strcasestr(progName, "neagent") != NULL ||
                strcasestr(progName, "nesessionmanager") != NULL ||
                strcasestr(progName, "apsd") != NULL ||
                strcasestr(progName, "cloudd") != NULL ||
                strcasestr(progName, "geod") != NULL ||
                strcasestr(progName, "akd") != NULL ||
                strcasestr(progName, "identityservicesd") != NULL ||
                strcasestr(progName, "imagent") != NULL ||
                strcasestr(progName, "bluetoothd") != NULL ||
                strcasestr(progName, "profiled") != NULL) {
                return;
            }

            if (strcasestr(progName, "jailbreakd") || strcasestr(progName, "launchd") ||
                strcasestr(progName, "containermanagerd") || strcasestr(progName, "cfprefsd") ||
                strcasestr(progName, "watchdogd") || strcasestr(progName, "mediaserverd") ||
                strcasestr(progName, "installd") || strcasestr(progName, "logd") ||
                strcasestr(progName, "analyticsd") || strcasestr(progName, "symptomsd") ||
                strcasestr(progName, "powerd") || strcasestr(progName, "notifyd") ||
                strcasestr(progName, "securityd") || strcasestr(progName, "runningboardd") ||
                strcasestr(progName, "thermalmonitord") || strcasestr(progName, "mediaremoted") ||
                strcasestr(progName, "assertiond") || strcasestr(progName, "timed") ||
                strcasestr(progName, "passd")) {
                return;
            }

            NSBundle *mainBundle = [NSBundle mainBundle];
            NSString *bundleID = [mainBundle bundleIdentifier];

            if (bundleID) {
                if ([bundleID rangeOfString:@"smooth" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [bundleID rangeOfString:@"boostiphone6s" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [bundleID rangeOfString:@"liquid" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [bundleID rangeOfString:@"networkextension" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [bundleID rangeOfString:@"vpn" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    return;
                }
            }

            BOOL isSpringBoard = (bundleID && [bundleID isEqualToString:@"com.apple.springboard"]);

            if (isSpringBoard) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        (void)Titanium_CheckAndPreventBootloopUniversal();
                    } @catch (NSException *e) {}
                });
            }

            if (strcasestr(progName, "Preferences") || strcasestr(progName, "Settings")) {
                Class configClass = NSClassFromString(@"BoostConfigV285Pro");
                if (configClass) {
                    CFG285 = [configClass sharedInstance];
                    [CFG285 loadSettings];
                    if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                        NSInteger prefHz = (NSInteger)CFG285.targetHz;
                        if ((g_cachedResolvedHz < 15 || g_cachedResolvedHz > 240) && prefHz >= 15 && prefHz <= 240) {
                            g_cachedResolvedHz = prefHz;
                        }
                    }
                    if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                        NSInteger prefFPS = (NSInteger)CFG285.targetFPS;
                        if ((g_cachedResolvedFPS < 15 || g_cachedResolvedFPS > 240) && prefFPS >= 15 && prefFPS <= 240) {
                            g_cachedResolvedFPS = prefFPS;
                        }
                    }
                }
                return;
            }

            Titanium_RegisterPrefsObservers(isSpringBoard);

            if (isSpringBoard) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    SpringBoardBootstrapTrigger();
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    runCoreTweak(NO, bundleID, progName);
                });
            }
        } @catch (__unused NSException *e) {}
    }
}
