// ==================== MACH & XNU KERNEL ====================
#import <mach/mach.h>
#import <mach/mach_init.h>
#import <mach/mach_host.h>
#import <mach/mach_time.h>
#import <mach/mach_types.h>
#import <mach/vm_map.h>
#import <mach/vm_region.h>
#import <mach/vm_statistics.h>
#import <mach/vm_types.h>
#import <mach/thread_act.h>
#import <mach/thread_policy.h>
#import <mach/task.h>
#import <mach/task_info.h>
#import <mach/task_policy.h>
#import <mach/clock.h>
#import <SpriteKit/SpriteKit.h>
#import <SceneKit/SceneKit.h>

// ==================== POSIX, C & SYSTEM ====================
#include <stdio.h>
#include <math.h>
#include <stdatomic.h>
#import <pthread.h>
#include <strings.h>
#import <pthread/qos.h>
#import <sched.h>
#import <unistd.h>
#import <stdlib.h>
#import <string.h>
#import <spawn.h>
#import <fcntl.h>
#import <dlfcn.h>
#import <malloc/malloc.h>
#import <notify.h>
#import <errno.h>
#import <time.h>
#import <os/lock.h>

// ==================== SYS HEADERS ====================
#import <sys/types.h>
#import <sys/time.h>
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/utsname.h>
#import <sys/wait.h>
#import <sys/mman.h>
#import <sys/stat.h>

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
#import <CoreText/CoreText.h>
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>

#if __has_include(<IOKit/IOKitLib.h>)
#import <IOKit/IOKitLib.h>
#endif

#if __has_include(<IOSurface/IOSurfaceRef.h>)
#import <IOSurface/IOSurfaceRef.h>
#endif

// ==================== CHỐT BẢO VỆ HẰNG SỐ KERNEL XNU ====================
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
// TƯƠNG THÍCH CHUẨN DẢI TẦN SỐ QUÉT
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
    static char fallback_name[256] = {0};
    if (fallback_name[0] == 0) {
        int fd = open("/proc/self/cmdline", O_RDONLY);
        if (fd >= 0) {
            ssize_t n = read(fd, fallback_name, sizeof(fallback_name) - 1);
            close(fd);
            if (n > 0) {
                for (ssize_t i = 0; i < n; i++) if (fallback_name[i] == '\0') fallback_name[i] = ' ';
                fallback_name[n] = '\0';
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
// MACRO ĐỒNG BỘ TOÀN HỆ THỐNG
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
// BỘ ĐÓNG GÓI BITMASK IPC
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
// CẤU TRÚC PAYLOAD APEX V285
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
    uint32_t enableAppleInternalProMotion;
    uint32_t enableZeroLatencyTouch;
    uint32_t enableMetalZeroTearing;
    uint32_t enableFluidTransitions;
    uint32_t enableTitaniumGameMetalOverdrive;
    uint32_t enableAIStreamOptimization;
    uint32_t enableFastLaunchSuperEngine;
    uint32_t enableScrollAndKeyboard;
    uint32_t enableInstantActionTransitions;
    uint32_t enableGlobalThreadGovernor;
    uint32_t enableSiliconSchedulerTouch;
    uint32_t enableCoreAnimationRenderServer;
    uint32_t enableCAWindowServerDominance;
    uint32_t enableForceRenderRecovery;
    uint32_t enableWindowLevelOverdrive;
    uint32_t enableSystemMemoryGovernor;
    uint32_t enableThermalCryoPacing;
    uint32_t enableDeepRamCompaction;
    uint32_t enableWebKitRamOptimizer;
    uint32_t enableSiliconHardwarePipeline;
    uint32_t enableHardwareProMotionOverclock;
    uint32_t enableNeuralTouchEdgeZeroLatency;
    uint32_t enableNativeColdBootOverdrive;
    uint32_t enableTitaniumV12SmoothExit;
    uint32_t enableDisplaySpringBoard;
    uint32_t enableLiquidGlassOpt;
    uint32_t enableSwitcher30Apps;
    uint32_t enableSpringBoardSwitcherOpt;
    uint32_t enableFloatingWindowPiP;
    uint32_t enableHardwareSegregationHome;
    uint32_t enableSpringBoardProcessManager;
    uint32_t enableKeepAppsAlive;
    uint32_t enableTitaniumV10LayoutBoost;
    uint32_t enableUIKitThirdPartyIsolated;
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
static BOOL g_avoidTweakConflicts = NO;
static void Titanium_InstallMGCopyAnswerHookV26(void);
static volatile BOOL g_isInteracting = NO;
static volatile uint64_t g_lastInteractiveTick = 0;

// Forward Declarations for functions used later
static void Titanium_PushRateToDriverV4(NSInteger hz, BOOL force);
static void Titanium_PushRateToDriverV4(NSInteger hz);   // compat wrapper

static NSInteger Titanium_GetUserTargetHz(void);
static void Titanium_ReapplyFrameRateToAllScenes(void);
static void Titanium_EnableZeroLatencyPipeline(void);
static void Titanium_V57_ForceReapplyIfNeeded(void);
static NSInteger Push_ResolveTargetHz(void);            // forward decl only — body ở sau line 1394
// [FORWARD DECL] — phải ở ĐẦU file, trước mọi call
static void Titanium_V60_Log(NSString *msg);

// ====================================================================================================
// KHAI BÁO @INTERFACE
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
- (void)_setDisplayRefreshRate:(double)rate; // <-- THÊM DÒNG NÀY
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
    .targetHz = 240,
    .targetFPS = 240,
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
// KHAI BÁO BIẾN TOÀN CỤC, TRẠNG THÁI IPC VÀ KERNEL WRITE-PROTECT BYPASS CHUẨN XNU (GỌT SẠCH)
// ====================================================================================================

static pthread_mutex_t g_syncLockV285 = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTicksV285 = 0;
static BOOL g_isDeviceChargingV285 = NO;
static volatile BOOL g_isUserTouchingV285 = NO;
static volatile CFTimeInterval g_lastTouchMediaTimeV285 = 0.0;
static volatile NSProcessInfoThermalState g_liveThermalStateV285 = NSProcessInfoThermalStateNominal;

static BOOL g_SystemMasterReady = YES;
static volatile BOOL g_isRebooting = NO; // [FIX] Trạng thái bảo vệ khi respring/reboot
static volatile int g_titaniumFirstFrameReady = 0;
static volatile NSInteger g_titaniumNativeDisplayMaxFPS = 60;
static volatile int g_titaniumNativeDisplayRateReady = 0;
static volatile int g_titaniumScreenRateSpoofReady = 0;

static volatile NSInteger g_cachedResolvedHz = 240;
static volatile NSInteger g_cachedResolvedFPS = 240;
static volatile BOOL g_thermalSeriousV285 = NO;
static volatile float g_batteryLevelV12 = 1.0f;
static volatile BOOL g_lowBatterySmoothBoostV12 = NO;

#define TITANIUM_BOOT_FLAG_VERIFIED @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.verified"

// ====================================================================================================
// BODY PUSH_RESOLVETARGETHZ
// Đặt ở đây vì g_syncPayloadV285 (line 1312) và g_cachedResolvedHz (line ~1394)
// đã được define phía trên. Không cần forward decl biến.
// ====================================================================================================

static NSInteger Push_ResolveTargetHz(void) {
    NSInteger target = g_syncPayloadV285.targetHz;
    if (target < 15) target = g_cachedResolvedHz;
    if (target < 15) target = 15;
    if (target > 240) target = 240;
    return target;
}

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

static void Titanium_BypassQuartzCoreRangeAssertion(void) {}
static void Init_CAWindowServer_Hooks(void) {}

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

static void Titanium_StartIPCHearthbeatV12(void);
static void Titanium_RegisterAppResumeRefreshV12(void);
static void Titanium_UpdateLowBatteryFlagV12(void);
static inline void Titanium_A20PrewarmAssetsAndGPU(void);

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
// HARDWARE DETECTION & RUNTIME PATH RESOLUTION (ÉP CƯỠNG BỨC 3 MÔI TRƯỜNG)
// ====================================================================================================

static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cachedJbRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 1. Ưu tiên tuyệt đối hàm `jbroot` của RootHide / Rootless (nếu có)
        typedef NSString* (*jbroot_fn)(NSString*);
        jbroot_fn jbroot_ptr = (jbroot_fn)dlsym(RTLD_DEFAULT, "jbroot");
        if (jbroot_ptr) {
            NSString *testPath = jbroot_ptr(@"/var/mobile");
            if (testPath && [testPath length] > 0) {
                // Lấy phần gốc, ví dụ trả về /var/jbproj-xxxx/var/mobile -> cắt lấy /var/jbproj-xxxx
                NSRange range = [testPath rangeOfString:@"/var/mobile"];
                if (range.location != NSNotFound) {
                    cachedJbRoot = [testPath substringToIndex:range.location];
                    if (cachedJbRoot.length == 0) cachedJbRoot = @"/";
                    return;
                }
            }
        }

        // 2. Nếu không có jbroot, dùng dladdr để tìm đường dẫn thư viện
        Dl_info info;
        if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            
            // Kiểm tra Rootful truyền thống
            if ([dylibPath hasPrefix:@"/Library/TweakInject"] || [dylibPath hasPrefix:@"/usr/lib/TweakInject"]) {
                cachedJbRoot = @"/";
            } else {
                // Kiểm tra RootHide / Rootless (thường chứa /var/jb)
                NSRange rVarJb = [dylibPath rangeOfString:@"/var/jb"];
                if (rVarJb.location != NSNotFound) {
                    NSUInteger startIdx = rVarJb.location;
                    NSUInteger searchIdx = startIdx + 7; // Độ dài của "/var/jb"
                    // Tìm dấu / tiếp theo để cắt lấy thư mục gốc (vd: /var/jbproj-abc)
                    NSRange nextSlash = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(searchIdx, dylibPath.length - searchIdx)];
                    if (nextSlash.location != NSNotFound) {
                        cachedJbRoot = [dylibPath substringToIndex:nextSlash.location];
                    } else {
                        cachedJbRoot = [dylibPath substringToIndex:searchIdx];
                    }
                } else {
                    cachedJbRoot = @"/var/jb"; // Fallback mặc định
                }
            }
        } else {
            cachedJbRoot = @"/var/jb"; // Fallback nếu dladdr thất bại
        }
    });
    return cachedJbRoot;
}

static inline NSString *Titanium_ResolvePrefPath(void) {
    static NSString *resolvedPath = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *root = Titanium_GetRootHidePrefixPath();
        NSFileManager *fm = [NSFileManager defaultManager];
        
        // Mảng chứa TẤT CẢ các đường dẫn có thể có trên 3 môi trường
        NSMutableArray<NSString *> *searchPaths = [NSMutableArray array];
        
        NSString *fileName = @"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
        
        // 1. Môi trường Rootless / RootHide (Dựa vào root path tìm được)
        if (root && ![root isEqualToString:@"/"]) {
            [searchPaths addObject:[root stringByAppendingPathComponent:fileName]];
            [searchPaths addObject:[root stringByAppendingPathComponent:@"mobile/Library/Preferences/com.taojb.boostiphone6s.plist"]];
        }
        
        // 2. Môi trường Rootful truyền thống (Đường dẫn tuyệt đối)
        [searchPaths addObject:@"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        
        // 3. Fallback ép cưỡng bức (Đề phòng path bị lỗi)
        [searchPaths addObject:@"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        [searchPaths addObject:@"/var/jb/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        [searchPaths addObject:@"/tmp/com.taojb.boostiphone6s.plist"]; // Ép đọc từ /tmp nếu có

        // Quét cạn: Thằng nào tồn tại đầu tiên thì chốt thằng đó
        for (NSString *path in searchPaths) {
            if ([fm fileExistsAtPath:path]) {
                resolvedPath = path;
                return;
            }
        }
        
        // Nếu đéo tìm thấy file nào (lần đầu cài), trả về đường dẫn mặc định để hàm write nó tạo ra
        if (root && ![root isEqualToString:@"/"]) {
            resolvedPath = [root stringByAppendingPathComponent:fileName];
        } else {
            resolvedPath = @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
        }
    });
    return resolvedPath;
}

static inline BOOL HardwareHasNative120Hz(void) { return YES; }
static inline NSInteger Titanium_NativeMaximumFPS(void) { return 240; }

// ====================================================================================================
// TITANIUM V285 PRO — CẤU HÌNH MACRO & TẦNG ẨN KHỞI TẠO TOÀN CỤC
// ====================================================================================================

#undef TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL
#define TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL 1
#undef TITANIUM_ENABLE_WATCHDOG_IMMUNITY
#define TITANIUM_ENABLE_WATCHDOG_IMMUNITY 0
#undef TITANIUM_ENABLE_METAL_ENV_TWEAKS
#define TITANIUM_ENABLE_METAL_ENV_TWEAKS 0
#undef TITANIUM_LITE_MODE
#define TITANIUM_LITE_MODE 0
#undef TITANIUM_SAFE_STABILITY_PROFILE
#define TITANIUM_SAFE_STABILITY_PROFILE 0
#undef TITANIUM_V10_PERFORMANCE
#define TITANIUM_V10_PERFORMANCE 1
#undef TITANIUM_ENABLE_RATE_KEEPER
#define TITANIUM_ENABLE_RATE_KEEPER 0
#undef TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES
#define TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES 0
#undef TITANIUM_ENABLE_TASK_QOS_TIER
#define TITANIUM_ENABLE_TASK_QOS_TIER 0
#undef TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS
#define TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS 0

#ifndef TITANIUM_ENABLE_DEVICE_SPOOF_IN_APPS
#define TITANIUM_ENABLE_DEVICE_SPOOF_IN_APPS 1
#endif

static inline BOOL Titanium_IsSpoofExcludedApp(void) {
    @try {
        NSString *bid = [[NSBundle mainBundle] bundleIdentifier];
        if (!bid) return NO;
        static NSSet<NSString *> *excluded = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            excluded = [NSSet setWithObjects:
                @"com.google.ios.youtube",
                @"com.google.gemini",
                @"com.anthropic.claudeios",
                @"com.anthropic.claude",
                @"com.openai.chat",
                nil];
        });
        return [excluded containsObject:bid];
    } @catch (__unused NSException *e) {}
    return NO;
}

#undef TITANIUM_ENABLE_DEVICE_AND_OS_SPOOFING
#define TITANIUM_ENABLE_DEVICE_AND_OS_SPOOFING 1
#undef TITANIUM_ENABLE_DEEP_HARDWARE_BYPASS
#define TITANIUM_ENABLE_DEEP_HARDWARE_BYPASS 1
#undef TITANIUM_ENABLE_SPRINGBOARD_LIQUID_GLASS_OPT
#define TITANIUM_ENABLE_SPRINGBOARD_LIQUID_GLASS_OPT 1

static inline BOOL Titanium_DisplaySpoofAllowed(void) { return YES; }

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
#define TITANIUM_FRAME_RATE_FLOOR 15.0f
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
// ADVANCED HARDWARE SUBSYSTEM ENGINE & MACH POLICY — V999 ABSOLUTE ENFORCE
// - Thread VIP: realtime 30/50 + precedence 63 + throttle off + wire stack
// - Zero latency: CATransaction low latency + commit priority override
// - Purge: RAM engine syscall thật (purgable + adaptive RSS)
// - Env: scale theo hw.memsize
// ====================================================================================================

// Forward decls — RAM engine định nghĩa ở block khác
static void Titanium_PurgePurgableMemory(void);
static BOOL Titanium_ShouldPurgeNow(void);
static uint64_t Titanium_GetCurrentRSS(void);
static uint64_t Titanium_GetDeviceTotalRAM(void);

// [ZERO LATENCY PIPELINE — ép CA commit thẳng, giảm latency render]
static inline void Titanium_EnableZeroLatencyPipeline(void) {
    if (!Titanium_ShouldApplyAppDisplayOverrides() || !Titanium_DisplayRateOverrideReady()) return;

    // Low latency transaction — đéo delay frame xuống display.
    if ([CATransaction respondsToSelector:@selector(_setLowLatency:)]) {
        [CATransaction _setLowLatency:YES];
    }

    // Commit priority cao — CA đẩy transaction lên trước queue.
    if ([CATransaction respondsToSelector:@selector(setCommitPriority:)]) {
        ((void (*)(id, SEL, int))objc_msgSend)([CATransaction class],
                                                @selector(setCommitPriority:), 1000);
    }
}

// [KERNEL THREAD UNTHROTTLE — tắt throttle + precedence max + time constraint]
static void Titanium_DisableKernelThreadThrottling(void) {
    static __thread BOOL s_threadUnthrottled = NO;
    if (__builtin_expect(s_threadUnthrottled, 1)) return;
    s_threadUnthrottled = YES;

    mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
    if (selfThread == MACH_PORT_NULL) return;

    // Throttle off — pset_limit=0 = không bị kernel giới hạn CPU time.
    thread_throttle_policy_data_t throttlePolicy;
    throttlePolicy.pset_limit = 0;
    thread_policy_set(selfThread, THREAD_THROTTLE_POLICY,
                      (thread_policy_t)&throttlePolicy, 1);

    // Precedence 63 = max priority (userland ceiling).
    thread_precedence_policy_data_t precedence = { .importance = 63 };
    thread_policy_set(selfThread, THREAD_PRECEDENCE_POLICY,
                      (thread_policy_t)&precedence, THREAD_PRECEDENCE_POLICY_COUNT);

    // Time constraint — ép scheduler phải chạy thread này trong cửa sổ định kỳ.
    // period 8ms, computation 30%, constraint 50% — gần realtime nhưng không nghẽn core.
    thread_time_constraint_policy_data_t tc;
    tc.period      = (uint32_t)Titanium_NanosToMachTicks(8000000ULL);
    tc.computation = (uint32_t)Titanium_NanosToMachTicks(2400000ULL);
    tc.constraint  = (uint32_t)Titanium_NanosToMachTicks(4000000ULL);
    tc.preemptible = TRUE;
    thread_policy_set(selfThread, THREAD_TIME_CONSTRAINT_POLICY,
                      (thread_policy_t)&tc, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}

// [THREAD VIP — QoS max + affinity P-core + disk elevated + wire stack]
static inline void Titanium_EnforceThreadVIPPolicy(void) {
    static __thread BOOL s_vipApplied = NO;
    if (__builtin_expect(s_vipApplied, 1)) return;
    s_vipApplied = YES;

    // QoS max — scheduler ưu tiên thread này trên P-core.
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    // Disk/atime I/O policy — I/O không bị throttle.
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);

    mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
    if (selfThread != MACH_PORT_NULL) {
        // Affinity tag = 1 → ưu tiên P-core cluster.
        thread_affinity_policy_data_t affinityData;
        affinityData.affinity_tag = 1;
        thread_policy_set(selfThread, THREAD_AFFINITY_POLICY,
                          (thread_policy_t)&affinityData, THREAD_AFFINITY_POLICY_COUNT);
    }

    // Nice -10 = max userland priority (kernel chặn -20 với userland).
    setpriority(PRIO_DARWIN_THREAD, 0, -10);

    // Wire thread stack vào RAM — đéo swap khi realtime chạy.
    pthread_t self = pthread_self();
    void *stack = pthread_get_stackaddr_np(self);
    size_t stackSize = pthread_get_stacksize_np(self);
    if (stack && stackSize > 0) {
        mach_vm_wire(0, mach_task_self(), (mach_vm_address_t)stack,
                     (mach_vm_size_t)stackSize, VM_PROT_READ | VM_PROT_WRITE);
    }

    Titanium_DisableKernelThreadThrottling();
}

static inline void Titanium_EnforceThreadRealtimeAndDiskVIP(void) {
    Titanium_EnforceThreadVIPPolicy();
}

// [BOOST BRIEF — nhanh, chỉ unthrottle, không wire lại]
static inline void Titanium_BoostCurrentThreadBriefly(void) {
    Titanium_DisableKernelThreadThrottling();
}

// [HEAP RELIEF — RAM engine syscall thật, adaptive theo máy]
static void Titanium_BackgroundHeapRelief(void) {
    static os_unfair_lock s_reliefLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t s_lastReliefTicks = 0;
    static volatile int32_t s_pressureLevel = 0;

    // Pressure monitor 1 lần — kernel báo khi áp lực cao.
    static dispatch_once_t pressureOnce;
    dispatch_once(&pressureOnce, ^{
        dispatch_source_t src = dispatch_source_create(DISPATCH_SOURCE_TYPE_MEMORYPRESSURE, 0,
                                                       DISPATCH_MEMORYPRESSURE_WARN | DISPATCH_MEMORYPRESSURE_CRITICAL,
                                                       dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
        dispatch_source_set_event_handler(src, ^{
            unsigned long flags = dispatch_source_get_data(src);
            if (flags & DISPATCH_MEMORYPRESSURE_CRITICAL) s_pressureLevel = 2;
            else if (flags & DISPATCH_MEMORYPRESSURE_WARN) s_pressureLevel = 1;
        });
        dispatch_resume(src);
    });

    uint64_t now = mach_absolute_time();
    BOOL go = NO;
    os_unfair_lock_lock(&s_reliefLock);
    uint64_t intervalSec = (Titanium_GetDeviceTotalRAM() >= 6ULL * 1024 * 1024 * 1024) ? 45 : 20;

    // Điều kiện: pressure critical HOẶC RSS > 85% ceiling adaptive.
    if (s_pressureLevel >= 2 || Titanium_ShouldPurgeNow()) {
        s_pressureLevel = 0;
        s_lastReliefTicks = now;
        go = YES;
    } else if (s_lastReliefTicks == 0 ||
               (now - s_lastReliefTicks) >= Titanium_NanosToMachTicks(intervalSec * 1000000000ULL)) {
        s_lastReliefTicks = now;
        go = YES;
    }
    os_unfair_lock_unlock(&s_reliefLock);
    if (!go) return;

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        @autoreleasepool {
            // [CHIP] Purge purgable page — kernel thu hồi page vật lý về controller.
            Titanium_PurgePurgableMemory();

            // Malloc purge.
            malloc_zone_pressure_relief(malloc_default_zone(), 0);

            // URL cache scale theo RAM máy.
            uint64_t ram = Titanium_GetDeviceTotalRAM();
            NSUInteger urlCap = (ram >= 6ULL * 1024 * 1024 * 1024) ? (128 * 1024 * 1024) : (64 * 1024 * 1024);
            NSURLCache *cache = [NSURLCache sharedURLCache];
            if (cache && (NSUInteger)cache.currentDiskUsage > urlCap) {
                [cache removeAllCachedResponses];
            }

            // UIImage cache flush.
            if ([UIImage respondsToSelector:@selector(_flushCache)]) {
                [UIImage performSelector:@selector(_flushCache)];
            }

            // WebKit memory warning nếu pressure cao HOẶC máy nhỏ.
            if (s_pressureLevel >= 1 || ram < 4ULL * 1024 * 1024 * 1024) {
                [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];
            }
        }
    });
}

// [PURGE — gate theo tương tác, interval adaptive]
static inline void Titanium_BackgroundPurgeMemory(void) {
    static os_unfair_lock s_purgeLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t s_lastPurgeTicks = 0;
    if (g_lowBatterySmoothBoostV12) return;

    if (g_isInteracting) return;

    uint64_t now = mach_absolute_time();
    BOOL shouldPurge = NO;
    os_unfair_lock_lock(&s_purgeLock);

    // Interval = 2× relief — tránh spam purge 2 tầng.
    uint64_t intervalSec = ((Titanium_GetDeviceTotalRAM() >= 6ULL * 1024 * 1024 * 1024) ? 45 : 20) * 2;

    if (s_lastPurgeTicks == 0 ||
        now - s_lastPurgeTicks >= Titanium_NanosToMachTicks(intervalSec * 1000000000ULL)) {
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

// [SILICON DEEP OPT — env scale theo RAM]
static void Titanium_ApplySiliconDeepOptimizations(void) {
    uint64_t ram = Titanium_GetDeviceTotalRAM();

    // Malloc threshold scale — máy lớn buffer lớn, máy nhỏ buffer nhỏ.
    if (ram >= 6ULL * 1024 * 1024 * 1024) {
        setenv("MALLOC_LARGE_THRESHOLD", "65536", 1);
        setenv("MALLOC_TINY_THRESHOLD",   "512",   1);
    } else {
        setenv("MALLOC_LARGE_THRESHOLD", "32768", 1);
        setenv("MALLOC_TINY_THRESHOLD",   "256",   1);
    }

#if TITANIUM_ENABLE_METAL_ENV_TWEAKS
    setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
    setenv("MTL_DISABLE_TEXTURE_RESIDENCY_TRACKING", "1", 1);
    setenv("MTL_SHADER_VALIDATION", "0", 1);
    setenv("MTL_FORCE_PARALLEL_ENCODE", "1", 1);
#endif

    // CA debug off — giảm log overhead.
    setenv("CA_DEBUG_TRANSACTIONS", "0", 1);

    // Metal command buffer — đéo chờ, present ngay.
    setenv("MTL_DEBUG_LAYER", "0", 1);
    setenv("MTL_SHADER_DUMP_FORCE_ERRORS", "0", 1);

    Titanium_DisableKernelThreadThrottling();
}

// [ENFORCE MAX CPU — throttle off + precedence]
static inline void EnforceMaxCPUPower(void) {
    Titanium_DisableKernelThreadThrottling();

    mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
    if (selfThread != MACH_PORT_NULL) {
        thread_precedence_policy_data_t precedence = { .importance = 63 };
        thread_policy_set(selfThread, THREAD_PRECEDENCE_POLICY,
                          (thread_policy_t)&precedence, THREAD_PRECEDENCE_POLICY_COUNT);
    }
}

// ====================================================================================================
// IPC — giữ nguyên
// ====================================================================================================

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

    NSArray *paths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE, @"/var/tmp/.boost_hz_sync"];
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
    NSString *jbSyncPath = [Titanium_GetRootHidePrefixPath() stringByAppendingPathComponent:@"tmp/.boost_hz_sync"];
    NSArray *checkPaths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE, jbSyncPath ?: @""];
    for (NSString *path in checkPaths) {
        if (path.length == 0) continue;
        int fd = open([path UTF8String], O_RDONLY);
        if (fd < 0) continue;
        uint8_t buf[512] = {0};
        ssize_t n = read(fd, buf, sizeof(buf));
        close(fd);
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
        self.targetHz = 240; // mặc định của tweak; được ghi đè bằng mức người dùng chọn khi tải cấu hình
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
                                
                                // Fix: Ép nhận dải 15-240Hz từ IPC
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
            
            // [V83 FIX] Fallback: Ép cứng 240Hz mặc định nếu không có plist hay IPC
            NSLog(@"[BoostTW] %@ src=DEFAULT (no plist, no ipc) -> Force 240Hz", bidDiag);
            self.targetHz = 240;
            self.targetFPS = 240;
            g_cachedResolvedHz = 240;
            g_cachedResolvedFPS = 240;
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
        if (self.targetHz < 15 || self.targetHz > 240) self.targetHz = 240;

        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 240);
        if (self.targetFPS < 15 || self.targetFPS > 240) self.targetFPS = 240;

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

        NSInteger safeHz = self.targetHz;
        if (safeHz < 15 || safeHz > 240) safeHz = 240;
        g_cachedResolvedHz = safeHz;

        NSInteger safeFPS = self.targetFPS;
        if (safeFPS < 15 || safeFPS > 240) safeFPS = 240;
        g_cachedResolvedFPS = safeFPS;

        if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.magic = APEX_SYNC_MAGIC_V285;
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)g_cachedResolvedHz;
            p.targetFPS = (int32_t)g_cachedResolvedFPS;
            p.forceOverclock = 0;
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
// TẦNG SÂU BẺ KHÓA LUỒNG XNU (FULL UNTHROTTLED UIKIT): BUNG CÔNG SUẤT 100%, NICE -20 (BẺ THẲNG)
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

// [BẺ THẲNG] Xoá sạch logic check thời gian, luôn ép khóa Hz/FPS
static inline BOOL Titanium_ShouldLockTargetRate(void) {
    return YES; 
}

// ==============================================================================
// TẦNG 5 & 6: BẺ KHÓA LUỒNG KERNEL + NICE -20 + P-CORE + MLOCK
// ==============================================================================

static inline void Titanium_UnleashAllHiddenSystemThreads(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
        
        // [BẺ THẲNG] Ép nice -20
        setpriority(PRIO_PROCESS, 0, -10); 
        
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
    });
}

static inline void Titanium_LockMainThreadFast(void) {
    if (![NSThread isMainThread]) return;

    static __thread BOOL s_isThreadOptimized = NO;
    if (__builtin_expect(s_isThreadOptimized, 1)) return;
    s_isThreadOptimized = YES;

    Titanium_UnleashAllHiddenSystemThreads();
    Titanium_EnforceThreadVIPPolicy();

    mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
    if (selfThread != MACH_PORT_NULL) {
        thread_affinity_policy_data_t affinity = { .affinity_tag = 1 }; 
        thread_policy_set(selfThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affinity, THREAD_AFFINITY_POLICY_COUNT);

        // [BẺ THẲNG] Precedence 63
        thread_precedence_policy_data_t precedence = { .importance = 63 }; 
        thread_policy_set(selfThread, THREAD_PRECEDENCE_POLICY, (thread_policy_t)&precedence, THREAD_PRECEDENCE_POLICY_COUNT);

        thread_throttle_policy_data_t throttle = { .pset_limit = 0 }; 
        thread_policy_set(selfThread, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttle, 1);
    }

    if (Titanium_ShouldApplyAppDisplayOverrides()) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
            AppleInternal_LockHardwareCADisplay();
            Titanium_EnableZeroLatencyPipeline();
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
        });
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
    __atomic_store_n(&g_isNotificationBannerActive, YES, __ATOMIC_RELAXED);
    Titanium_LockMainThreadFast();

    static int64_t s_bannerSeq = 0;
    int64_t currentSeq = ++s_bannerSeq;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(350 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if (s_bannerSeq == currentSeq) {
            __atomic_store_n(&g_isNotificationBannerActive, NO, __ATOMIC_RELAXED);
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
        __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
        Titanium_EnableZeroLatencyPipeline();
        Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
        __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
        Titanium_EnableZeroLatencyPipeline();
        Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
        __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
        Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
        Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
        Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
        __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
        Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
            __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
            Titanium_EnableZeroLatencyPipeline();
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
        }
    }
    %orig(event);
}

%end

%end

// ====================================================================================================
// HÀM TRỢ GIÚP TOÀN CỤC — ĐỒNG BỘ HOÀN TOÀN, KHÔNG CLAMP PHẦN CỨNG
// ====================================================================================================

#include <sys/sysctl.h>

static NSInteger Titanium_GetMasterRate(void);

// Giữ lại vì có code khác gọi. Không dùng trong clamp nữa.
static NSInteger Titanium_GetSafeMaxHzForChip(void) {
    return 240;
}

// [CLAMP] — sàn 15, trần 240, không đụng chip
static inline NSInteger Titanium_ClampDisplayFrameRate(NSInteger requestedFPS) {
    if (requestedFPS < 15)  requestedFPS = 15;
    if (requestedFPS > 240) requestedFPS = 240;
    return requestedFPS;
}

static inline NSInteger Titanium_ClampRequestedFrameRate(NSInteger requestedFPS) {
    if (requestedFPS < 15)  requestedFPS = 15;
    if (requestedFPS > 240) requestedFPS = 240;
    return requestedFPS;
}

static void Titanium_UpdateNativeDisplayMaxFPS(void) {
    // Intentionally no-op: bốc scan phần cứng native — tránh lock về 60Hz.
}

// [THERMAL GATE] — kernel báo nóng thì ngừng ép
static inline BOOL Titanium_ThermalSafeForOverride(void) {
    @try {
        if (@available(iOS 11.0, *)) {
            NSProcessInfoThermalState s = [[NSProcessInfo processInfo] thermalState];
            if (s == NSProcessInfoThermalStateSerious ||
                s == NSProcessInfoThermalStateCritical) return NO;
        }
    } @catch (__unused NSException *e) {}
    return YES;
}

static inline BOOL Titanium_DisplayRateOverrideReady(void) {
    // Sẵn sàng ép, trừ khi máy đang quá nhiệt
    return Titanium_ThermalSafeForOverride();
}

// [SMOOTH FRR] — ép sàn = trần, không clamp thêm
static inline CAFrameRateRange Titanium_SmoothFRR(float requestedMaxFPS) {
    if (!isfinite(requestedMaxFPS)) requestedMaxFPS = 60.0f;
    if (requestedMaxFPS < 15.0f)  requestedMaxFPS = 15.0f;
    if (requestedMaxFPS > 240.0f) requestedMaxFPS = 240.0f;

    NSInteger runtimeCap = Titanium_ClampDisplayFrameRate((NSInteger)llroundf(requestedMaxFPS));
    float maxFPS = (float)runtimeCap;
    float minFPS = maxFPS;
    return CAFrameRateRangeMake(minFPS, maxFPS, maxFPS);
}

// [VERIFY HELPER] — đọc Hz thực tế từ CADisplay để check driver có nhận không
static inline NSInteger Titanium_ReadDisplayPreferredFPS(void) {
    @try {
        Class cadCls = NSClassFromString(@"CADisplay");
        if (!cadCls) return -1;
        id cad = [cadCls performSelector:@selector(mainDisplay)];
        if (cad && [cad respondsToSelector:@selector(preferredFPS)]) {
            return ((NSInteger (*)(id, SEL))objc_msgSend)(cad, @selector(preferredFPS));
        }
    } @catch (__unused NSException *e) {}
    return -1;
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
        [delName containsString:@"Popup"] ||
        [delName containsString:@"PictureInPicture"] ||
        [delName containsString:@"PiP"] ||
        [layerName containsString:@"AV"] ||
        [layerName containsString:@"Video"] ||
        [layerName containsString:@"Popup"] ||
        [layerName containsString:@"AVPlayerLayer"] ||
        [layerName containsString:@"AVSampleBufferDisplayLayer"]) {
        return YES;
    }
    return NO;
}

static inline BOOL Titanium_IsMediaOrVideoLayer(CALayer *layer) {
    return Titanium_IsVideoOrMediaMetalLayer(layer);
}

// ==============================================================================
// TẦNG 2: BẺ KHÓA METAL & TẮT V-SYNC
// ==============================================================================

static inline void Titanium_KillVSyncCompletelyAtRoot(void) {
    if ([CATransaction respondsToSelector:@selector(_setLowLatency:)]) {
        [CATransaction _setLowLatency:YES];
    }
    Titanium_EnableZeroLatencyPipeline();
}

static void Titanium_ForceApplyMetalOverdriveUltimate(id self) {
    if (!self) return;
    
    BOOL isSB = Titanium_IsSpringBoard();
    BOOL isMedia = Titanium_IsVideoOrMediaMetalLayer((CAMetalLayer *)self);
    
    NSString *layerName = NSStringFromClass([self class]);
    id del = [(CALayer *)self delegate];
    NSString *delName = del ? NSStringFromClass([del class]) : @"";
    
    if ([layerName containsString:@"Web"] || [layerName containsString:@"WK"] || 
        [delName containsString:@"Web"] || [delName containsString:@"WK"]) {
        isMedia = YES;
    }

    if (!isSB) {
        if (!Titanium_DisplayRateOverrideReady() || isMedia) return;
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                NSInteger target = Titanium_GetEffectiveFrameCap();
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
        if ([self respondsToSelector:@selector(setAllowsNextDrawableTimeout:)]) {
            ((CAMetalLayer *)self).allowsNextDrawableTimeout = NO; 
        }
        if ([self respondsToSelector:@selector(setLowLatencyMode:)]) {
            ((CAMetalLayer *)self).lowLatencyMode = YES; 
        }
        if (@available(iOS 15.0, *)) {
            if (Titanium_DisplayRateOverrideReady() && [self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                float maxTarget = (float)Titanium_GetEffectiveFrameCap();
                ((CAMetalLayer *)self).preferredFrameRateRange = Titanium_SmoothFRR(maxTarget);
            }
        }
    }

    if (isSB && !isMedia) {
        if ([self respondsToSelector:@selector(setPresentsWithTransaction:)]) {
            ((CAMetalLayer *)self).presentsWithTransaction = YES;
        }
        if ([self respondsToSelector:@selector(setMaximumDrawableCount:)]) {
            ((CAMetalLayer *)self).maximumDrawableCount = 3;
        }
    }
}

static void (*orig_CAMetalLayer_didMoveToWindow)(id self, SEL _cmd) = NULL;
static void hooked_CAMetalLayer_didMoveToWindow(id self, SEL _cmd) {
    if (orig_CAMetalLayer_didMoveToWindow) orig_CAMetalLayer_didMoveToWindow(self, _cmd);
    if (!self) return;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        __weak id weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (weakSelf) Titanium_ForceApplyMetalOverdriveUltimate(weakSelf);
        });
    }
}

static void (*orig_CAMetalLayer_setDisplaySyncEnabled)(id self, SEL _cmd, BOOL enabled) = NULL;
static void hooked_CAMetalLayer_setDisplaySyncEnabled(id self, SEL _cmd, BOOL enabled) {
    if (orig_CAMetalLayer_setDisplaySyncEnabled) orig_CAMetalLayer_setDisplaySyncEnabled(self, _cmd, enabled);
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
// TẦNG 3: [HARD LOCK] ÉP CỨNG HZ/FPS CHO MỌI APP, APP ĐO FPS & WEB
// SINGLE SOURCE: Titanium_GetMasterRate (từ block TRƯỚC)
// ====================================================================================================

%group Group_FluidTransitions_Pacing_PreScreen

// [SỬA] Cả 2 hàm về MasterRate — bốc logic đọc 2 biến riêng
static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    return Titanium_GetMasterRate();
}

static inline NSInteger Titanium_GetTargetConfiguredFPS(void) {
    return Titanium_GetMasterRate();
}

NSInteger Titanium_GetEffectiveRefreshCap(void) {
    return Titanium_GetMasterRate();
}

NSInteger Titanium_GetEffectiveFrameCap(void) {
    return Titanium_GetMasterRate();
}

// [ÉP CỨNG] Min = Max = Preferred
static inline CAFrameRateRange Titanium_HardLockFRR(NSInteger target) {
    if (target < 15)  target = 15;
    if (target > 240) target = 240;
    return CAFrameRateRangeMake((float)target, (float)target, (float)target);
}

static NSString *Titanium_BuildWebFPSOverdriveScript(NSInteger targetFPS) {
    if (targetFPS < 15)  targetFPS = 15;
    if (targetFPS > 240) targetFPS = 240;

    return [NSString stringWithFormat:
        @"(function() {"
        @"  if (window.__titaniumTargetFPS) return;"
        @"  window.__titaniumTargetFPS = %ld;"
        @"  var targetInterval = 1000.0 / window.__titaniumTargetFPS;"
        @"  var origRAF = window.requestAnimationFrame.bind(window);"
        @"  var pending = [];"
        @"  var rafId = 1;"
        @"  var lastTime = 0;"
        @"  function tick(now) {"
        @"    origRAF(tick);"
        @"    if (now - lastTime >= targetInterval - 1.0) {"
        @"      lastTime = now;"
        @"      var batch = pending;"
        @"      pending = [];"
        @"      for (var i = 0; i < batch.length; i++) {"
        @"        try { batch[i](now); } catch(e) {}"
        @"      }"
        @"    }"
        @"  }"
        @"  origRAF(tick);"
        @"  window.requestAnimationFrame = function(cb) {"
        @"    pending.push(cb);"
        @"    return rafId++;"
        @"  };"
        @"  window.webkitRequestAnimationFrame = window.requestAnimationFrame;"
        @"  window.cancelAnimationFrame = function(id) {};"
        @"  window.webkitCancelAnimationFrame = window.cancelAnimationFrame;"
        @"  var origGetContext = HTMLCanvasElement.prototype.getContext;"
        @"  HTMLCanvasElement.prototype.getContext = function(type, attrs) {"
        @"    if (type === 'webgl' || type === 'webgl2' || type === 'experimental-webgl') {"
        @"      attrs = Object.assign({}, attrs || {}, {"
        @"        antialias: false, depth: true, stencil: false, alpha: false,"
        @"        desynchronized: true, powerPreference: 'high-performance', preserveDrawingBuffer: false"
        @"      });"
        @"    }"
        @"    return origGetContext.call(this, type, attrs);"
        @"  };"
        @"  function unlockShaderFP16(proto) {"
        @"    if (!proto || !proto.shaderSource) return;"
        @"    var origSource = proto.shaderSource;"
        @"    proto.shaderSource = function(shader, src) {"
        @"      if (typeof src === 'string') {"
        @"        src = src.replace(/precision\\s+highp\\s+float/g, 'precision mediump float');"
        @"        src = src.replace(/highp\\s+/g, 'mediump ');"
        @"      }"
        @"      return origSource.call(this, shader, src);"
        @"    };"
        @"  }"
        @"  if (window.WebGLRenderingContext) unlockShaderFP16(WebGLRenderingContext.prototype);"
        @"  if (window.WebGL2RenderingContext) unlockShaderFP16(WebGL2RenderingContext.prototype);"
        @"})();", (long)targetFPS];
}

static const void *kTitaniumWebLastSyncFPSKey = &kTitaniumWebLastSyncFPSKey;

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

// ====================================================================================================
// CADisplayLink — ép MasterRate, không double punch
// ====================================================================================================

%hook CADisplayLink

- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode {
    %orig(runLoop, mode);
    if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TrackDisplayLink(self);
        NSInteger target = Titanium_GetMasterRate();
        self.preferredFramesPerSecond = target;
        self.frameInterval = 1;
        if (@available(iOS 15.0, *)) {
            self.preferredFrameRateRange = Titanium_HardLockFRR(target);
        }
    }
}

- (void)invalidate {
    Titanium_UntrackDisplayLink(self);
    %orig;
}

- (NSInteger)preferredFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TrackDisplayLink(self);
        %orig(Titanium_GetMasterRate());
        return;
    }
    %orig(fps);
}

- (NSInteger)frameInterval {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return 1;
    }
    return %orig;
}

- (void)setFrameInterval:(NSInteger)interval {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(1);
        return;
    }
    %orig(interval);
}

- (CFTimeInterval)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return (1.0 / (double)Titanium_GetMasterRate());
    }
    return %orig;
}

- (CFTimeInterval)targetTimestamp {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return [self timestamp] + (1.0 / (double)Titanium_GetMasterRate());
    }
    return %orig;
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            return Titanium_HardLockFRR(Titanium_GetMasterRate());
        }
    }
    return %orig;
}

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_TrackDisplayLink(self);
            range = Titanium_HardLockFRR(Titanium_GetMasterRate());
        }
    }
    %orig(range);
}

%end

%hook MTLCompileOptions
- (BOOL)fastMathEnabled {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) return YES;
    return %orig;
}
- (void)setFastMathEnabled:(BOOL)enabled {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(YES);
        return;
    }
    %orig(enabled);
}
%end

// ====================================================================================================
// CADisplayMode / CADisplay — BỐC double punch driver mỗi getter
// Trước đây mỗi getter đấm IOMFB → nóng. Giờ getter chỉ trả MasterRate.
// ====================================================================================================

%hook CADisplayMode
- (double)refreshRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}
%end

%hook CADisplay
- (double)refreshRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}
- (NSInteger)preferredFPS {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetMasterRate();
    }
    return %orig;
}
- (void)setPreferredFPS:(NSInteger)fps {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        // Bốc dispatch_async đấm driver — drift detector/OverdrivePipeline lo phần đó
        %orig(Titanium_GetMasterRate());
        return;
    }
    %orig(fps);
}
- (BOOL)allowsVirtualModes { return YES; }
- (void)setAllowsVirtualModes:(BOOL)allows { %orig(YES); }
- (void)overrideDisplayCadence:(id)cadence {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        // Chỉ Tier4 cadence (nhẹ) — bốc đấm UltimateHardwareHack ở đây
        Titanium_Tier4_ExecuteHardwarePanelOverdrive();
    }
    %orig(cadence);
}
%end

%end

%group Group_UIScreen_FirstFrameOnly

%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetMasterRate();
    }
    return %orig;
}
- (NSInteger)_maximumFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetMasterRate();
    }
    return %orig;
}
- (CGFloat)_refreshRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return (CGFloat)Titanium_GetMasterRate();
    }
    return %orig;
}
- (void)_setTargetRefreshRate:(CGFloat)rate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig((CGFloat)Titanium_GetMasterRate());
        return;
    }
    %orig(rate);
}
%end

%end

static void Titanium_InstallUIScreenRateSpoofNow(void) {
    if (Titanium_IsSpringBoard() || g_isCurrentAppBlacklisted) return;
    if (__atomic_load_n(&g_titaniumScreenRateSpoofReady, __ATOMIC_ACQUIRE) != 0) return;

    (void)[UIScreen mainScreen];
    Titanium_UpdateNativeDisplayMaxFPS();
    int wasReady = __atomic_exchange_n(&g_titaniumScreenRateSpoofReady, 1, __ATOMIC_ACQ_REL);
    if (!wasReady) {
        %init(Group_UIScreen_FirstFrameOnly);
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

static inline BOOL Titanium_ShouldExposeHighFrameRateEntitlement(void) {
    return !Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted &&
           (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
           Titanium_GetMasterRate() >= 15;
}

%hook NSBundle
- (id)objectForInfoDictionaryKey:(NSString *)key {
    if ([key isEqualToString:@"CADisableMinimumFrameDurationOnPhone"] &&
        !g_isCurrentAppBlacklisted && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        return @YES;
    }
    return %orig(key);
}
%end

%hook WKWebView
- (void)_setDisplayRefreshRate:(double)rate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig((double)Titanium_GetMasterRate());
        return;
    }
    %orig(rate);
}

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted && configuration) {
        NSInteger targetCap = Titanium_GetMasterRate();
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
    return webView;
}

- (void)didMoveToWindow {
    %orig;
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldApplyAppDisplayOverrides() && !g_isCurrentAppBlacklisted && self.window) {
            NSString *js = Titanium_BuildWebFPSOverdriveScript(Titanium_GetMasterRate());
            if (js && js.length > 0) {
                [self evaluateJavaScript:js completionHandler:nil];
            }
        }
    } @catch (__unused NSException *e) {}
}
%end

%hook CAAnimation
- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            range = Titanium_HardLockFRR(Titanium_GetMasterRate());
        }
    }
    %orig(range);
}
- (CAFrameRateRange)preferredFrameRateRange {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            return Titanium_HardLockFRR(Titanium_GetMasterRate());
        }
    }
    return %orig;
}
%end

// ====================================================================================================
// [PARALLEL ANIMATION FORCE - FIXED] ÉP RENDER TỐI ĐA, KHÔNG ĐẶC CẦU, KHÔNG LAG
// ====================================================================================================

// Thread-local counter: đếm transaction do chính hook này mở.
static _Thread_local NSInteger g_ownTxDepth = 0;

%hook CATransaction
+ (void)begin {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        // KHÔNG setDisableActions, KHÔNG setAnimationDuration:0.0.
        // Chỉ đếm depth để biết khi nào commit transaction ngoài cùng.
        g_ownTxDepth++;
    }
}

+ (void)commit {
    BOOL isMyOutermost = NO;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (g_ownTxDepth > 0) {
            g_ownTxDepth--;
            if (g_ownTxDepth == 0) isMyOutermost = YES;
        }
    }
    %orig;
    if (isMyOutermost) {
        // [FIX THU NHỎ APP] Xoá lệnh flush.
        // Flush làm đứt gãy animation phóng to app lúc launch (gây thu nhỏ).
        // Việc ép 0ms delay đã được xử lý bằng HardLockFRR bên dưới.
    }
}
%end

// 2. Ép Layer Animation chạy ở FPS tối đa, xong là biến mất (Chống lag GPU)
%hook CALayer
- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    @try {
        if (anim && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (@available(iOS 15.0, *)) {
                if ([anim respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    // [ÉP KHOÁ CỨNG HZ/FPS TẠI ĐÂY]
                    // Min = Max = Preferred. Giữ cho animation luôn chạy ở mức FPS cao nhất.
                    anim.preferredFrameRateRange = Titanium_HardLockFRR(Titanium_GetEffectiveFrameCap());
                }
            }
            
            // Ép dọn dẹp sau khi chạy xong
            anim.removedOnCompletion = YES;
            anim.fillMode = kCAFillModeForwards;
        }
    } @catch (__unused NSException *e) {}
    %orig(anim, key);
}
%end

%end

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT — BẺ CƯỠNG CHẾ HZ/FPS THEO TỪNG FRAME
// Mọi call site đọc Titanium_GetMasterRate. Driver punch share cooldown 1500ms.
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

// 1. Vuốt đa nhiệm — KHOÁ HZ/FPS mỗi khi ngón tay di chuyển
%hook SBHomeGestureInteraction
- (void)_handleGestureChanged:(id)gesture {
    @try {
        if (!self) { %orig(gesture); return; }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isContinuousSwiping = YES;
            g_isInteracting = YES;
            g_lastInteractionMachTime = mach_absolute_time();

            // Khoá main thread priority — kernel không throttle
            Titanium_LockMainThreadFast();
            Titanium_EnableZeroLatencyPipeline();

            // Bơm rate — share cooldown với các hook khác, không spam
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());

            // CA lock — nhẹ, chỉ set UIScene.preferredFrameRateRange
            Titanium_ReapplyFrameRateToAllScenes();
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
            g_lastInteractionMachTime = mach_absolute_time();

            Titanium_LockMainThreadFast();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
}

- (void)_handleGestureBegan:(id)gesture {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isContinuousSwiping = YES;
            g_isInteracting = YES;
            g_lastInteractionMachTime = mach_absolute_time();
            Titanium_LockMainThreadFast();
            Titanium_EnableZeroLatencyPipeline();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
        }
    } @catch (__unused NSException *e) {}
    %orig(gesture);
}

- (void)_handleGestureCancelled:(id)gesture {
    %orig(gesture);
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isContinuousSwiping = NO;
            g_isInteracting = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
}
%end

// 2. Can thiệp Transaction chuyển đa nhiệm
%hook SBFluidSwitcherGestureWorkspaceTransaction
- (BOOL)canInterruptActiveGesture { return YES; }

- (void)_begin {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_lastInteractionMachTime = mach_absolute_time();
            Titanium_LockMainThreadFast();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
            Titanium_ReapplyFrameRateToAllScenes();
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
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
}
%end

// 3. Switcher item container — bơm xung khi touch, không đụng shadow
%hook SBFluidSwitcherItemContainer
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_lastInteractionMachTime = mach_absolute_time();
            g_isInteracting = YES;
            Titanium_TriggerInstantTouchBurst();
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig(touches, event);
}
%end

// 4. App <-> Home transaction
%hook SBAppToHomeWorkspaceTransaction
- (void)_willBegin {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isInteracting = YES;
            __atomic_fetch_add(&g_activeAnimationCount, 1, __ATOMIC_RELAXED);
            g_lastInteractionMachTime = mach_absolute_time();
            Titanium_LockMainThreadFast();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didComplete {
    %orig;
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            int32_t old = __atomic_fetch_sub(&g_activeAnimationCount, 1, __ATOMIC_RELAXED);
            if (old <= 0) __atomic_store_n(&g_activeAnimationCount, 0, __ATOMIC_RELAXED);
            g_isInteracting = NO;
            g_isUserTouchingScreen = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
}
%end

%hook SBHomeToAppWorkspaceTransaction
- (void)_willBegin {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_isInteracting = YES;
            __atomic_fetch_add(&g_activeAnimationCount, 1, __ATOMIC_RELAXED);
            g_lastInteractionMachTime = mach_absolute_time();
            Titanium_LockMainThreadFast();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didComplete {
    %orig;
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            int32_t old = __atomic_fetch_sub(&g_activeAnimationCount, 1, __ATOMIC_RELAXED);
            if (old <= 0) __atomic_store_n(&g_activeAnimationCount, 0, __ATOMIC_RELAXED);
            g_isInteracting = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
}
%end

// 5. Snapshot / Settings
%hook SBAppSwitcherSnapshotImageCache
- (BOOL)shouldLoadSnapshotImagesImmediately { return YES; }
%end

%hook SBAppSwitcherSettings
- (BOOL)shouldKeepAppSnapshotsInMemory { return YES; }
- (BOOL)shouldSimplifyForOptions:(long long)options { return NO; }
- (CGFloat)decelerationRate { return 0.998f; }
%end

%hook SBFluidSwitcherGestureManager
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}
%end

%end

// ====================================================================================================
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC & KHÓA CHẶN MỌI LỆNH DROP HZ/FPS
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

%hook SBAppLaunchSettings

- (double)delayBeforeAppLaunch {
    return 0.0; // Bấm là chạy, không chờ
}

- (double)zoomDuration {
    return %orig; // Giữ gốc — để app kịp render frame đầu
}

- (double)launchDuration {
    return %orig; // Giữ gốc — iOS tự tối ưu
}

%end

%hook SBSplashBoardController

- (double)splashScreenDelay {
    return 0.0; // Bốc splash delay
}

%end

%hook SBUIAnimationController

- (void)_willBeginAnimation {
    @try {
        if (!self) { %orig; return; }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
            (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
            g_isInteracting = YES;
            __atomic_fetch_add(&g_activeAnimationCount, 1, __ATOMIC_RELAXED);
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_LockMainThreadFast();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)_didCompleteAnimation {
    @try {
        if (!self) { %orig; return; }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            int32_t old = __atomic_fetch_sub(&g_activeAnimationCount, 1, __ATOMIC_RELAXED);
            if (old <= 0) __atomic_store_n(&g_activeAnimationCount, 0, __ATOMIC_RELAXED);
            g_isInteracting = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 6: [SCROLL SMOOTHNESS] — KHÔNG PUNCH MỖI FRAME, CA LOCK + DRIFT DETECTOR
// Punch chỉ tại _scrollViewWillBeginDragging (1 lần). Còn lại drift detector lo.
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

// [KHỬ NHOÈ] Ép layer vẽ native scale
%hook CALayer
- (void)setContentsScale:(CGFloat)scale {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        CGFloat nativeScale = [UIScreen mainScreen].scale;
        if (scale < nativeScale) {
            %orig(nativeScale);
            return;
        }
    }
    %orig(scale);
}

- (void)setShouldRasterize:(BOOL)shouldRasterize {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(NO);
        return;
    }
    %orig(shouldRasterize);
}

- (void)setDrawsAsynchronously:(BOOL)drawsAsynchronously {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(NO);
        return;
    }
    %orig(drawsAsynchronously);
}
%end

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

// [BỐC PUNCH] setContentOffset fire 60/s — chỉ CA lock, không punch. Drift detector lo punch.
- (void)setContentOffset:(CGPoint)contentOffset {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isScrollingActive) {
        Titanium_ReapplyFrameRateToAllScenes();
    }
}

- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isScrollingActive) {
        Titanium_ReapplyFrameRateToAllScenes();
    }
}

// [PUNCH 1 LẦN] Tại scroll start — share cooldown 1500ms
- (void)_scrollViewWillBeginDragging {
    @try {
        if (!self) { %orig; return; }
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            __atomic_store_n(&g_isScrollingActive, YES, __ATOMIC_RELAXED);
            __atomic_store_n(&g_isUserTouchingScreen, YES, __ATOMIC_RELAXED);

            Titanium_LockMainThreadFast();

            // Punch 1 lần đầu — cooldown 1500ms trong ForcePanel gate lại
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());

            self.layer.contentsScale = [UIScreen mainScreen].scale;
            self.layer.shouldRasterize = NO;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (CGFloat)decelerationRate {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
            if (self.isPagingEnabled) return %orig;
            return 0.998f;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

- (void)_stopScrollDecelerationNotify:(BOOL)notify {
    BOOL origDone = NO;
    @try {
        if (!self) { origDone = YES; %orig(notify); return; }
        origDone = YES; %orig(notify);
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            __atomic_store_n(&g_isScrollingActive, NO, __ATOMIC_RELAXED);
            __atomic_store_n(&g_isUserTouchingScreen, NO, __ATOMIC_RELAXED);
            self.layer.contentsScale = [UIScreen mainScreen].scale;
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig(notify);
    }
}

- (void)_scrollViewDidEndDecelerating {
    BOOL origDone = NO;
    @try {
        if (!self) { origDone = YES; %orig; return; }
        origDone = YES; %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            __atomic_store_n(&g_isScrollingActive, NO, __ATOMIC_RELAXED);
            __atomic_store_n(&g_isUserTouchingScreen, NO, __ATOMIC_RELAXED);
            self.layer.contentsScale = [UIScreen mainScreen].scale;
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD — PUNCH 1 LẦN GESTURE START, CA LOCK CHO PHẦN CÒN LẠI
// Bốc punch khỏi viewWillLayoutSubviews và _notifyDidScroll (heat source chính)
// ====================================================================================================

%group Group_Display_SpringBoardV285

@interface TitaniumVsyncOnce : NSObject
@property (nonatomic, copy) void (^work)(void);
@property (nonatomic, strong) CADisplayLink *link;
- (void)fire:(CADisplayLink *)l;
@end
@implementation TitaniumVsyncOnce
- (void)fire:(CADisplayLink *)l {
    [l invalidate];
    self.link = nil;
    void (^w)(void) = self.work;
    self.work = nil;
    if (w) w();
}
@end

static void Titanium_RunOnNextVsync(void (^work)(void)) {
    if (!work) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        TitaniumVsyncOnce *t = [TitaniumVsyncOnce new];
        t.work = work;
        t.link = [CADisplayLink displayLinkWithTarget:t selector:@selector(fire:)];
        [t.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
}

%hook SBFluidSwitcherViewController

// [PUNCH 1 LẦN] Tại gesture start
- (void)handleFluidSwitcherGesture:(id)gesture {
    @try {
        if (!self) { %orig(gesture); return; }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_lastInteractionMachTime = mach_absolute_time();
            __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
            Titanium_TriggerInstantTouchBurst();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig(gesture);
}

// [BỐC PUNCH] Layout fire nhiều lần — chỉ CA lock
- (void)viewWillLayoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)cardInteractiveTransitionDidEnd:(id)arg1 {
    if (!self) { %orig(arg1); return; }
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        __atomic_store_n(&g_isInteracting, NO, __ATOMIC_RELAXED);
        dispatch_async(dispatch_get_main_queue(), ^{
            Titanium_ReapplyFrameRateToAllScenes();
        });
    }
    %orig(arg1);
}
%end

%hook SBControlCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_lastInteractionMachTime = mach_absolute_time();
            __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
            Titanium_TriggerInstantTouchBurst();
            Titanium_RunOnNextVsync(^{
                Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_lastInteractionMachTime = mach_absolute_time();
            Titanium_LockMainThreadFast();
            Titanium_RunOnNextVsync(^{
                Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);

    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            __atomic_store_n(&g_isInteracting, NO, __ATOMIC_RELAXED);
        }
    } @catch (__unused NSException *e) {}
}
%end

%hook SBNotificationCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_lastInteractionMachTime = mach_absolute_time();
            __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
            Titanium_TriggerInstantTouchBurst();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_lastInteractionMachTime = mach_absolute_time();
            Titanium_LockMainThreadFast();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);

    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            __atomic_store_n(&g_isInteracting, NO, __ATOMIC_RELAXED);
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
}
%end

%hook SBIconScrollView

- (BOOL)delaysContentTouches {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return NO;
    } @catch (__unused NSException *e) {}
    return %orig;
}

// [BỐC PUNCH] _notifyDidScroll fire 60/s — chỉ CA lock
- (void)_notifyDidScroll {
    @try {
        if (!self) { %orig; return; }
        %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            __atomic_store_n(&g_isScrollingActive, YES, __ATOMIC_RELAXED);
            g_lastInteractionMachTime = mach_absolute_time();
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
}

- (void)_stopScrollingAndFastReload {
    %orig;
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            __atomic_store_n(&g_isScrollingActive, NO, __ATOMIC_RELAXED);
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
}
%end

%hook SBApplication

- (void)willActivate {
    @try {
        if (!self) { %orig; return; }
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            g_lastInteractionMachTime = mach_absolute_time();
            Titanium_TriggerInstantTouchBurst();
            Titanium_RunOnNextVsync(^{
                Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (BOOL)shouldPrewarmOnLaunch {
    @try {
        if (!self) return %orig;
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
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
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
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
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
        }
    } @catch (__unused NSException *e) {}
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
            __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
            Titanium_TriggerInstantTouchBurst();
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __atomic_store_n(&g_isInteracting, NO, __ATOMIC_RELAXED);
                Titanium_ReapplyFrameRateToAllScenes();
            });
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
            __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
            Titanium_TriggerInstantTouchBurst();
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
            
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __atomic_store_n(&g_isInteracting, NO, __ATOMIC_RELAXED);
                Titanium_ReapplyFrameRateToAllScenes();
            });
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
            __atomic_store_n(&g_isInteracting, YES, __ATOMIC_RELAXED);
            Titanium_TriggerInstantTouchBurst();
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
        }
    } @catch (__unused NSException *e) {}
    %orig(application);
}

- (void)handleApplicationSuspended:(id)application {
    %orig(application);
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            Titanium_BackgroundHeapRelief();
            __atomic_store_n(&g_isInteracting, NO, __ATOMIC_RELAXED);
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
        Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
    }
    %orig(arg1);
}

- (void)transitionRequest:(id)arg1 didCompleteWithResult:(id)arg2 {
    %orig(arg1, arg2);
    @try {
        if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
            Titanium_BackgroundHeapRelief();
            // [V81 FIX] Ép lại 240Hz ngay sau khi chuyển cảnh xong
            dispatch_async(dispatch_get_main_queue(), ^{
                Titanium_ReapplyFrameRateToAllScenes();
            });
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
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
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
            Titanium_PushRateToDriverV4(Titanium_GetUserTargetHz());
        }
    } @catch (__unused NSException *e) {
        if (!origDone) %orig;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 12: BÀN PHÍM STREAM TEXT, SHARE SHEET & CẢM ỨNG NÚT BẤM (0MS DELAY - GPU NHẸ GÁNH)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

// 1. SHARE SHEET & MENU CHUYỂN CẢNH
%hook UIPresentationController
- (void)presentationTransitionWillBegin {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            // Chỉ bật đường ống 0ms, không ép xung Driver ở đây (tránh lag)
            Titanium_EnableZeroLatencyPipeline();
            
            // Ép các layer con vẽ bất đồng bộ để không block Main Thread khi hiện Blur/Menu
            if (self.presentedView) {
                self.presentedView.layer.drawsAsynchronously = YES;
                // Tắt bóng đổ của Menu để GPU nhẹ gánh
                self.presentedView.layer.shadowOpacity = 0.0f; 
            }
        }
    } @catch (__unused NSException *e) {}
    %orig;
}

- (void)dismissalTransitionWillBegin {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

// 2. BÀN PHÍM STREAM TEXT
%hook UIKeyboardTaskQueue
- (void)performTask:(id)task {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig(task);
}
%end

%hook UIPeripheralHost
- (double)getLastTranslateTime {
    @try {
        if (!self) return %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            return 0.0; // 0ms Delay
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}
%end

// 3. CẢM ỨNG NÚT BẤM (BUTTON)
%hook UIButton
- (void)didMoveToWindow {
    %orig;
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
            // Tối ưu hóa nút bấm: Vẽ ngầm, giảm tải cho CPU
            self.layer.drawsAsynchronously = YES;
            self.layer.shouldRasterize = NO;
        }
    } @catch (__unused NSException *e) {}
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            // Không ép xung CPU, chỉ kích hoạt luồng render 0ms
            Titanium_EnableZeroLatencyPipeline();
        }
    } @catch (__unused NSException *e) {}
    %orig(touches, event);
}
%end

// 4. TẮT HIỆU ỨNG LÀM MỜ CỦA MENU (Chống lag Share Sheet)
%hook UIVisualEffectView
- (void)layoutSubviews {
    %orig;
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            self.layer.drawsAsynchronously = YES;
            // Tắt bóng đổ của View làm mờ
            self.layer.shadowOpacity = 0.0f;
        }
    } @catch (__unused NSException *e) {}
}
%end

%end

// ====================================================================================================
// NHÓM 13: BẺ KHÓA HIỆU NĂNG PIN YẾU & NHIỆT ĐỘ
// ====================================================================================================

#include <dlfcn.h>

static CFDictionaryRef (*orig_IOPSGetPowerSourceDescription)(CFTypeRef blob, CFTypeRef ps) = NULL;
static CFDictionaryRef hooked_IOPSGetPowerSourceDescription(CFTypeRef blob, CFTypeRef ps) {
    @try {
        if (orig_IOPSGetPowerSourceDescription) return orig_IOPSGetPowerSourceDescription(blob, ps);
    } @catch (__unused NSException *e) {}
    return NULL;
}

static int (*orig_IOPSGetPercentRemaining)(void) = NULL;
static int hooked_IOPSGetPercentRemaining(void) {
    @try {
        if (orig_IOPSGetPercentRemaining) return orig_IOPSGetPercentRemaining();
    } @catch (__unused NSException *e) {}
    return 100;
}

%group Group_Global_Thread_Governor_Unthrottled

%hook NSProcessInfo
- (BOOL)isLowPowerModeEnabled { return NO; }
- (NSProcessInfoThermalState)thermalState { return NSProcessInfoThermalStateNominal; }
%end

%hook UIDevice
- (float)batteryLevel { return %orig; }
- (UIDeviceBatteryState)batteryState { return UIDeviceBatteryStateFull; }
- (BOOL)isBatteryMonitoringEnabled { return %orig; }
%end

%hook SBUIController
- (BOOL)isBatterySaverModeActive { return NO; }
%end

%hook _CDBatterySaver
- (BOOL)getPowerMode { return NO; }
%end

%end

static void Titanium_InstallPowerBypassC(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            void *iokit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
            if (iokit) {
                void *sym1 = dlsym(iokit, "IOPSGetPowerSourceDescription");
                if (sym1) MSHookFunction(sym1, (void *)hooked_IOPSGetPowerSourceDescription, (void **)&orig_IOPSGetPowerSourceDescription);
                void *sym2 = dlsym(iokit, "IOPSGetPercentRemaining");
                if (sym2) MSHookFunction(sym2, (void *)hooked_IOPSGetPercentRemaining, (void **)&orig_IOPSGetPercentRemaining);
            }
        } @catch (__unused NSException *e) {}
    });
}

// ====================================================================================================
// NHÓM 15: SILICON METAL PIPELINE — bốc punch khỏi enqueue (fire 60/s, heat source)
// ====================================================================================================

%group Group_Silicon_Hardware_Pipeline_Overdrive

%hook _MTLCommandQueue
- (void)setStatOptions:(NSUInteger)options {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        %orig(0);
        return;
    }
    %orig(options);
}

- (BOOL)executionEnabled {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) return YES;
    return %orig;
}

// [BỐC PUNCH] enqueue fire 60/s — chỉ unthrottle thread, không punch
- (void)enqueueCommandBuffer:(id)buffer {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
        Titanium_BoostCurrentThreadBriefly();
    }
    %orig(buffer);
}
%end

%hook _MTLCommandBuffer
- (void)enqueue {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !g_isVideoPlayingActive) {
        Titanium_BoostCurrentThreadBriefly();
    }
    %orig;
}

// [BỐC PUNCH] commit fire 60/s — bốc luôn ZeroLatencyPipeline ở đây vì đã set global
- (void)commit {
    %orig;
}
%end

%hook MTLTextureDescriptor
- (BOOL)allowGPUOptimizedContents { return %orig; }
- (void)setAllowGPUOptimizedContents:(BOOL)flag { %orig(flag); }
%end

%hook CAMetalDrawable
- (void)presentAfterMinimumDuration:(CFTimeInterval)duration { %orig(duration); }
%end

%hook UIApplicationSceneTransitionContext
- (BOOL)waitForFence { return %orig; }
- (void)setWaitForFence:(BOOL)wait { %orig(wait); }
%end

%end

// ====================================================================================================
// NHÓM 4: NEURAL TOUCH — BỐC PUNCH, CHỈ GIỮ UNTHROTTLE THREAD
// Punch ở đây gây nóng vì touch predictor fire mỗi frame khi chạm
// ====================================================================================================

%group Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285

%hook _UITouchPredictor

// [BỐC PUNCH] Chỉ unthrottle, không đấm driver
- (id)predictedTouchesForTouch:(UITouch *)touch {
    @try {
        if (!self) return %orig(touch);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            static uint64_t s_lastPredictTick = 0;
            uint64_t now = mach_absolute_time();
            if (now - s_lastPredictTick > Titanium_NanosToMachTicks(50ULL * 1000000ULL)) {
                s_lastPredictTick = now;
                g_lastInteractionMachTime = now;
                Titanium_BoostCurrentThreadBriefly();
            }
        }
        return %orig(touch);
    } @catch (__unused NSException *e) {}
    return %orig(touch);
}

// [BỐC PUNCH] addTouch fire mỗi chạm — chỉ update timestamp
- (void)addTouch:(UITouch *)touch fromEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(touch, event);
}

%end

%hook _UIGestureEnvironment

// [BỐC PUNCH] _updateGesturesForEvent fire mỗi event — chỉ unthrottle
- (void)_updateGesturesForEvent:(UIEvent *)event {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            static uint64_t s_lastGestureTick = 0;
            uint64_t now = mach_absolute_time();
            if (now - s_lastGestureTick > Titanium_NanosToMachTicks(50ULL * 1000000ULL)) {
                s_lastGestureTick = now;
                g_lastInteractionMachTime = now;
                Titanium_BoostCurrentThreadBriefly();
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(event);
}

%end

%hook SBScreenEdgePanGestureRecognizer

// [PUNCH 1 LẦN] Chỉ đấm driver tại edge gesture start (không phải mỗi event)
- (BOOL)_shouldTryToBeginWithEvent:(UIEvent *)event {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
            // Punch có cooldown 1500ms trong ForcePanel gate
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
        }
    } @catch (__unused NSException *e) {}
    return %orig(event);
}

%end

%end

// ====================================================================================================
// NHÓM 16-21: SCHEDULER / CORE ANIMATION / MEMORY — bốc punch khỏi tap/layout
// ====================================================================================================

%group Group_Silicon_Scheduler_Touch_Governor

// [BỐC PUNCH HOÀN TOÀN] Highlight fire mỗi lần tap → folder icon tap bị ảnh hưởng.
// Chỉ unthrottle thread, không punch, không ZeroLatencyPipeline.
%hook _UIInteractiveHighlightEnvironment
- (void)applyHighlightWithAnimation:(BOOL)animated completion:(id)completion {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            Titanium_BoostCurrentThreadBriefly();
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}
%end

%end

%group Group_CoreAnimation_RenderServer_Governor

// [BỐC PUNCH HOÀN TOÀN] FBScene updateSettings fire mỗi frame layout → folder open bị lag
%hook FBScene
- (void)updateSettings:(id)settings withTransitionContext:(id)context {
    %orig(settings, context);
    // Không làm gì thêm — folder transition tự nhiên, không bị ép rate
}
%end

// [RESET VỀ GỐC] UIScene setPreferredFrameRateRange — hook cũ ép min=max=target
// → giết folder transition animation (cần varying rate). Trả về %orig.
%hook UIScene
- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    // Hook chỉ can thiệp khi KHÔNG phải folder/transition context
    // Trick: nếu đang scroll → ép target, còn lại để OS tự chạy
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
            (g_isInteracting || g_isScrollingActive || g_isContinuousSwiping)) {
            NSInteger target = Titanium_GetMasterRate();
            if (target < 15)  target = 15;
            if (target > 240) target = 240;
            range = CAFrameRateRangeMake((float)target, (float)target, (float)target);
        }
    }
    %orig(range);
}
%end

%end

// ====================================================================================================
// MEMORY & BLUR — giữ nguyên nhưng bốc punch khỏi layer nếu có
// ====================================================================================================

%group Group_System_Memory_And_RunLoop_Governor

%hook MTMaterialView
- (void)didMoveToWindow {
    %orig;
    @try {
        if (TITANIUM_LITE_MODE) return;
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && self.layer != nil) {
            self.layer.allowsGroupOpacity = YES;
            if ([self respondsToSelector:NSSelectorFromString(@"_setBlurRadius:")]) {
                [self setValue:@(0.0) forKey:@"_blurRadius"];
            }
        }
    } @catch (__unused NSException *e) {}
}
%end

%hook CABackdropLayer
- (void)setScale:(CGFloat)scale {
    %orig(scale);
}
%end

%hook UIVisualEffectView
- (void)setEffect:(UIVisualEffect *)effect {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(nil);
        return;
    }
    %orig(effect);
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

// ====================================================================================================
// HÀM ÉP LẠI FRAME RATE — DRIFT-AWARE, COOLDOWN, KHÔNG NÓNG
// ====================================================================================================

// [COOLDOWN + DRIFT STATE]
static volatile uint64_t g_lastHardwarePunchTick = 0;
static volatile uint32_t g_consecutiveDriftFrames = 0;
static volatile double   g_lastObservedFrameHz   = 0.0;
static volatile uint32_t g_driftPunchCountTotal  = 0;

// Forward decls
static void Titanium_ExecuteUltimateHardwareHack(NSInteger targetHz);
static void Titanium_ForcePanelModeDirect(NSInteger hz);
static void Titanium_PushRateToDriverV4(NSInteger hz, BOOL force);
static void Titanium_PushRateToDriverV4(NSInteger hz);
static void Titanium_EnforceCAFrameRange(void);
static void Titanium_DriftCheck(CFTimeInterval timestamp, CFTimeInterval targetTs, NSInteger targetHz);

// ====================================================================================================
// [THERMAL & PUNCH GATE] — thermal + 1500ms cooldown + drift counter
// Share giữa: ForcePanelModeDirect, HardwareDriverOverride,
//             PushRateToDriverV4, ExecuteUltimateHardwareHack
// ====================================================================================================

// [THERMAL GATE] — máy Serious/Critical thì ngừng punch
static inline BOOL Titanium_ThermalOK(void) {
    @try {
        if (@available(iOS 11.0, *)) {
            NSProcessInfoThermalState state = [[NSProcessInfo processInfo] thermalState];
            if (state == NSProcessInfoThermalStateSerious ||
                state == NSProcessInfoThermalStateCritical) {
                return NO;
            }
        }
    } @catch (__unused NSException *e) {}
    return YES;
}

// [PUNCH GATE] — thermal check + cooldown 1500ms
static inline BOOL Titanium_CanPunchHardware(void) {
    if (!Titanium_ThermalOK()) return NO;
    uint64_t now = mach_absolute_time();
    if (g_lastHardwarePunchTick == 0) return YES;
    return (now - g_lastHardwarePunchTick) >= Titanium_NanosToMachTicks(1500ULL * 1000000ULL);
}

// [MARK] — update timestamp + đếm lần punch (để log verify)
static inline void Titanium_MarkHardwarePunched(void) {
    g_lastHardwarePunchTick = mach_absolute_time();
    g_driftPunchCountTotal++;
}

// ====================================================================================================
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
        if (cap < 60) cap = 60;
        for (CADisplayLink *displayLink in snapshot) {
            if (!displayLink) continue;
            if (@available(iOS 15.0, *)) {
                if ([displayLink respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    displayLink.preferredFrameRateRange = Titanium_HardLockFRR(cap);
                }
            }
            displayLink.preferredFramesPerSecond = cap;
        }
    });
}

// [ENFORCE CA FRAME RANGE — nhẹ, KHÔNG đấm driver]
static void Titanium_EnforceCAFrameRange(void) {
    if (!Titanium_ShouldApplyAppDisplayOverrides() || g_isCurrentAppBlacklisted) return;
    @autoreleasepool {
        NSInteger targetHz = Titanium_GetUserTargetHz();
        if (targetHz < 15) targetHz = 15;
        if (targetHz > 240) targetHz = 240;
        CAFrameRateRange target = Titanium_HardLockFRR(targetHz);
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                UIWindowScene *ws = (UIWindowScene *)scene;
                if (@available(iOS 15.0, *)) {
                    if ([ws respondsToSelector:@selector(preferredFrameRateRange)] &&
                        [ws respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                        CAFrameRateRange curr = ws.preferredFrameRateRange;
                        if (fabs(curr.minimum - target.minimum) > 0.5 ||
                            fabs(curr.maximum - target.maximum) > 0.5 ||
                            fabs(curr.preferred - target.preferred) > 0.5) {
                            ws.preferredFrameRateRange = target;
                        }
                    }
                }
            }
        }
    }
    Titanium_ReapplyFrameRateToTrackedDisplayLinks();
}

static inline void Titanium_ReapplyFrameRateToAllScenes(void) {
    if (!Titanium_ShouldApplyAppDisplayOverrides()) return;
    Titanium_EnforceCAFrameRange();

    // [VERIFY] Log master rate vs readback — bắt lệch
    static uint64_t s_lastVerifyTick = 0;
    uint64_t now = mach_absolute_time();
    if (s_lastVerifyTick == 0 || (now - s_lastVerifyTick) >= Titanium_NanosToMachTicks(5ULL * 1000000000ULL)) {
        s_lastVerifyTick = now;
        NSInteger master = Titanium_GetMasterRate();
        NSInteger readback = -1;
        @try {
            id cad = [%c(CADisplay) mainDisplay];
            if (cad && [cad respondsToSelector:@selector(preferredFPS)]) {
                readback = ((NSInteger (*)(id, SEL))objc_msgSend)(cad, @selector(preferredFPS));
            }
        } @catch (__unused NSException *e) {}
        Titanium_V60_Log([NSString stringWithFormat:@"[SYNC] master=%ld readback=%ld", (long)master, (long)readback]);
    }
}

// [DRIFT CHECK — chỉ đấm khi lệch 2% liên tiếp 5 frame]
static inline void Titanium_DriftCheck(CFTimeInterval timestamp, CFTimeInterval targetTs, NSInteger targetHz) {
    if (targetHz < 15) return;
    double interval = targetTs - timestamp;
    if (interval <= 0.002 || interval > 0.5) return;
    double actualHz = 1.0 / interval;
    g_lastObservedFrameHz = actualHz;
    double deviation = fabs(actualHz - (double)targetHz) / (double)targetHz;

    if (deviation > 0.02) {
        g_consecutiveDriftFrames++;
        if (g_consecutiveDriftFrames >= 5) {
            g_consecutiveDriftFrames = 0;
            if (Titanium_CanPunchHardware()) {
                Titanium_MarkHardwarePunched();
                NSInteger tgt = targetHz;
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    @try {
                        Titanium_ExecuteUltimateHardwareHack(tgt);
                        Titanium_ForcePanelModeDirect(tgt);
                    } @catch (__unused NSException *e) {}
                });
            }
        }
    } else {
        g_consecutiveDriftFrames = 0;
    }
}

// ================= IOKIT SAFE-SYMBOL SHIMS =================
typedef kern_return_t (*Titanium_SetCFPropertiesFn)(io_registry_entry_t, CFTypeRef);
typedef kern_return_t (*Titanium_SetCFPropertyFn)(io_registry_entry_t, CFStringRef, CFTypeRef);
typedef io_service_t   (*Titanium_IOServiceGetMatchingServiceFn)(mach_port_t, CFDictionaryRef);
typedef kern_return_t  (*Titanium_IOServiceGetMatchingServicesFn)(mach_port_t, CFDictionaryRef, io_iterator_t*);
typedef kern_return_t  (*Titanium_IOServiceOpenFn)(io_service_t, task_port_t, uint32_t, io_connect_t*);
typedef kern_return_t  (*Titanium_IOConnectCallStructMethodFn)(io_connect_t, uint32_t, const void*, size_t, void*, size_t*);
typedef kern_return_t  (*Titanium_IOConnectCallScalarMethodFn)(io_connect_t, uint32_t, const uint64_t*, uint32_t, uint64_t*, uint32_t*);
typedef io_registry_entry_t (*Titanium_IORegistryEntryFromPathFn)(mach_port_t, const io_string_t);

typedef struct {
    Titanium_SetCFPropertiesFn           setCFProperties;
    Titanium_SetCFPropertyFn             setCFProperty;
    Titanium_IOServiceGetMatchingServiceFn  getMatchingService;
    Titanium_IOServiceGetMatchingServicesFn getMatchingServices;
    Titanium_IOServiceOpenFn             serviceOpen;
    Titanium_IOConnectCallStructMethodFn connectStructMethod;
    Titanium_IOConnectCallScalarMethodFn connectScalarMethod;
    Titanium_IORegistryEntryFromPathFn   entryFromPath;
} TitaniumIOKitSyms;

static TitaniumIOKitSyms g_tioKit = {0};
static dispatch_once_t   g_tioKitOnce;

static inline const TitaniumIOKitSyms *Titanium_ResolveIOKitSyms(void) {
    dispatch_once(&g_tioKitOnce, ^{
        g_tioKit.setCFProperties     = (Titanium_SetCFPropertiesFn)     dlsym(RTLD_DEFAULT, "IORegistryEntrySetCFProperties");
        g_tioKit.setCFProperty       = (Titanium_SetCFPropertyFn)       dlsym(RTLD_DEFAULT, "IORegistryEntrySetCFProperty");
        g_tioKit.getMatchingService  = (Titanium_IOServiceGetMatchingServiceFn) dlsym(RTLD_DEFAULT, "IOServiceGetMatchingService");
        g_tioKit.getMatchingServices = (Titanium_IOServiceGetMatchingServicesFn)dlsym(RTLD_DEFAULT, "IOServiceGetMatchingServices");
        g_tioKit.serviceOpen         = (Titanium_IOServiceOpenFn)       dlsym(RTLD_DEFAULT, "IOServiceOpen");
        g_tioKit.connectStructMethod = (Titanium_IOConnectCallStructMethodFn)dlsym(RTLD_DEFAULT, "IOConnectCallStructMethod");
        g_tioKit.connectScalarMethod = (Titanium_IOConnectCallScalarMethodFn)dlsym(RTLD_DEFAULT, "IOConnectCallScalarMethod");
        g_tioKit.entryFromPath       = (Titanium_IORegistryEntryFromPathFn)dlsym(RTLD_DEFAULT, "IORegistryEntryFromPath");
    });
    return &g_tioKit;
}

static inline kern_return_t Titanium_SafeSetCFProperties(io_registry_entry_t svc, NSDictionary *props) {
    if (svc == IO_OBJECT_NULL || !props) return KERN_INVALID_ARGUMENT;
    const TitaniumIOKitSyms *s = Titanium_ResolveIOKitSyms();
    if (s->setCFProperties) {
        return s->setCFProperties(svc, (__bridge CFTypeRef)props);
    }
    if (!s->setCFProperty) return KERN_NOT_SUPPORTED;
    kern_return_t last = KERN_SUCCESS;
    for (NSString *k in props) {
        kern_return_t kr = s->setCFProperty(svc, (__bridge CFStringRef)k, (__bridge CFTypeRef)props[k]);
        if (kr != KERN_SUCCESS) last = kr;
    }
    return last;
}

static inline kern_return_t Titanium_SafeSetCFProperty(io_registry_entry_t svc, NSString *key, id value) {
    if (svc == IO_OBJECT_NULL || !key) return KERN_INVALID_ARGUMENT;
    const TitaniumIOKitSyms *s = Titanium_ResolveIOKitSyms();
    if (!s->setCFProperty) return KERN_NOT_SUPPORTED;
    return s->setCFProperty(svc, (__bridge CFStringRef)key, (__bridge CFTypeRef)value);
}

// ====================================================================================================
// [RAM CONTROL ENGINE — syscall thật, KHÔNG hook, KHÔNG fake]
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
#ifndef JETSAM_PRIORITY_CRITICAL
#define JETSAM_PRIORITY_CRITICAL 19
#endif
#ifndef VM_PURGABLE_PURGE_ALL
#define VM_PURGABLE_PURGE_ALL 0
#endif

// ====================================================================================================
// [RAM CONTROL ENGINE — DLSYM-GUARDED PRIVATE SYMBOLS]
// iOS 16.7 rootless: memorystatus_control + vm_purgable_control + mach_vm_wire
// có thể không export → gọi trực tiếp → _dyld_missing_symbol_abort.
// Toàn bộ gọi qua dlsym, thiếu thì return -1/KERN_FAILURE, không crash.
// ====================================================================================================

extern int memorystatus_control(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);

// [DLSYM STATE] — resolve 1 lần, cache function pointer
static int (*g_memorystatus_control_fn)(uint32_t, int32_t, uint32_t, void *, size_t) = NULL;
static int (*g_vm_purgable_control_fn)(vm_map_t, vm_offset_t, int, int *) = NULL;
static kern_return_t (*g_mach_vm_wire_fn)(vm_map_t, vm_map_t, mach_vm_address_t, mach_vm_size_t, vm_prot_t) = NULL;
static dispatch_once_t g_dlsymOnce;

static inline void Titanium_ResolvePrivateSymbols(void) {
    dispatch_once(&g_dlsymOnce, ^{
        g_memorystatus_control_fn = (int (*)(uint32_t, int32_t, uint32_t, void *, size_t))
            dlsym(RTLD_DEFAULT, "memorystatus_control");
        if (!g_memorystatus_control_fn) {
            Titanium_V60_Log(@"[RAM] memorystatus_control missing — jetsam elevate skipped");
        }

        g_vm_purgable_control_fn = (int (*)(vm_map_t, vm_offset_t, int, int *))
            dlsym(RTLD_DEFAULT, "vm_purgable_control");
        if (!g_vm_purgable_control_fn) {
            Titanium_V60_Log(@"[RAM] vm_purgable_control missing — purge skipped");
        }

        g_mach_vm_wire_fn = (kern_return_t (*)(vm_map_t, vm_map_t, mach_vm_address_t, mach_vm_size_t, vm_prot_t))
            dlsym(RTLD_DEFAULT, "mach_vm_wire");
        if (!g_mach_vm_wire_fn) {
            Titanium_V60_Log(@"[RAM] mach_vm_wire missing — wire skipped");
        }
    });
}

// [SAFE WRAPPERS]
static inline int Titanium_SafeMemorystatusControl(uint32_t cmd, int32_t pid, uint32_t flags, void *buf, size_t sz) {
    Titanium_ResolvePrivateSymbols();
    if (!g_memorystatus_control_fn) return -1;
    return g_memorystatus_control_fn(cmd, pid, flags, buf, sz);
}

static inline int Titanium_SafeVmPurgableControl(vm_map_t task, vm_offset_t addr, int ctrl, int *state) {
    Titanium_ResolvePrivateSymbols();
    if (!g_vm_purgable_control_fn) return -1;
    return g_vm_purgable_control_fn(task, addr, ctrl, state);
}

static inline kern_return_t Titanium_SafeMachVmWire(vm_map_t host, vm_map_t task, mach_vm_address_t addr, mach_vm_size_t size, vm_prot_t prot) {
    Titanium_ResolvePrivateSymbols();
    if (!g_mach_vm_wire_fn) return KERN_FAILURE;
    return g_mach_vm_wire_fn(host, task, addr, size, prot);
}

// [DEVICE RAM DETECT]
static uint64_t Titanium_GetDeviceTotalRAM(void) {
    static uint64_t s_totalRAM = 0;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        size_t size = sizeof(s_totalRAM);
        if (sysctlbyname("hw.memsize", &s_totalRAM, &size, NULL, 0) != 0) {
            s_totalRAM = 3ULL * 1024 * 1024 * 1024;
        }
    });
    return s_totalRAM;
}

// [JETSAM UNLIMITED — qua Safe wrapper]
static void Titanium_ForceJetsamUnlimited(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            int32_t hwm = 0x7FFFFFFF - 1;
            Titanium_SafeMemorystatusControl(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK,
                                             getpid(), 0, &hwm, sizeof(hwm));

            int32_t taskLimit = 0x7FFFFFFF - 1;
            Titanium_SafeMemorystatusControl(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT,
                                             getpid(), 0, &taskLimit, sizeof(taskLimit));

            struct { int32_t priority; uint64_t user_data; } props;
            props.priority = JETSAM_PRIORITY_CRITICAL;
            props.user_data = 0;
            Titanium_SafeMemorystatusControl(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES,
                                             getpid(), 0, &props, sizeof(props));

            Titanium_SafeMemorystatusControl(MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE,
                                             getpid(), 0, NULL, 0);
            Titanium_SafeMemorystatusControl(MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED,
                                             getpid(), 0, NULL, 0);

            uint64_t total = Titanium_GetDeviceTotalRAM();
            Titanium_V60_Log([NSString stringWithFormat:@"[RAM] jetsam policy set: total=%lluMB",
                              total / 1024 / 1024]);
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[RAM] ForceJetsamUnlimited throw: %@", e.reason]);
        }
    });
}

// [WIRE TO CHIP — qua Safe wrapper]
static BOOL Titanium_WireMemoryToChip(void *addr, size_t size) {
    if (!addr || size == 0) return NO;
    kern_return_t kr = Titanium_SafeMachVmWire(0, mach_task_self(),
                                               (mach_vm_address_t)addr,
                                               (mach_vm_size_t)size,
                                               VM_PROT_READ | VM_PROT_WRITE);
    return kr == KERN_SUCCESS;
}

static void Titanium_WireGlobalPayloadsToChip(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            BOOL ok1 = Titanium_WireMemoryToChip(&g_syncPayloadV285, sizeof(ApexV285ProPayload));
            BOOL ok2 = Titanium_WireMemoryToChip(&g_livePayload, sizeof(ApexV285ProPayload));
            BOOL ok3 = NO;
            if (g_sharedPayloadPtr != MAP_FAILED && g_sharedPayloadPtr != NULL) {
                ok3 = Titanium_WireMemoryToChip(g_sharedPayloadPtr, sizeof(ApexV285ProPayload));
            }
            Titanium_V60_Log([NSString stringWithFormat:@"[RAM] wire: sync=%d live=%d shared=%d", ok1, ok2, ok3]);
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[RAM] wire throw: %@", e.reason]);
        }
    });
}

// [PURGE — qua Safe wrapper]
static void Titanium_PurgePurgableMemory(void) {
    @try {
        int state = 0;
        Titanium_SafeVmPurgableControl(mach_task_self(), 0, VM_PURGABLE_PURGE_ALL, &state);
    } @catch (__unused NSException *e) {}
}

// [VM STATS]
static uint64_t Titanium_GetAvailableRAM(void) {
    @try {
        vm_statistics64_data_t vmstat;
        mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
        if (host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmstat, &count) == KERN_SUCCESS) {
            vm_size_t pageSize = 0;
            host_page_size(mach_host_self(), &pageSize);
            uint64_t psize = (uint64_t)pageSize;
            if (psize == 0) psize = 16384;
            return ((uint64_t)vmstat.free_count + (uint64_t)vmstat.speculative_count +
                    (uint64_t)vmstat.purgeable_count) * psize;
        }
    } @catch (__unused NSException *e) {}
    return 0;
}

static uint64_t Titanium_GetCurrentRSS(void) {
    @try {
        task_vm_info_data_t info;
        mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
        if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) == KERN_SUCCESS) {
            return (uint64_t)info.phys_footprint;
        }
    } @catch (__unused NSException *e) {}
    return 0;
}

// [CEILING ADAPTIVE THEO RAM]
static uint64_t Titanium_GetRAMCeiling(void) {
    uint64_t total = Titanium_GetDeviceTotalRAM();
    if (total >= 8ULL * 1024 * 1024 * 1024) return total - (1ULL * 1024 * 1024 * 1024);
    if (total >= 6ULL * 1024 * 1024 * 1024) return total - (1ULL * 1024 * 1024 * 1024);
    if (total >= 4ULL * 1024 * 1024 * 1024) return total - (768ULL * 1024 * 1024);
    if (total >= 3ULL * 1024 * 1024 * 1024) return total - (512ULL * 1024 * 1024);
    return total - (384ULL * 1024 * 1024);
}

static inline BOOL Titanium_ShouldPurgeNow(void) {
    uint64_t rss = Titanium_GetCurrentRSS();
    uint64_t ceiling = Titanium_GetRAMCeiling();
    if (ceiling == 0) return NO;
    return rss > (ceiling * 85 / 100);
}

// ====================================================================================================
extern ApexV285ProPayload g_syncPayloadV285;
static inline BOOL Apex_IsMasterEnabled(void) { return g_syncPayloadV285.masterEnabled != 0; }
extern BOOL g_isCurrentAppBlacklisted;
@class BoostConfigV285Pro;
extern BoostConfigV285Pro *CFG285;
extern NSInteger Titanium_GetEffectiveFrameCap(void);
extern void EnforceMaxCPUPower(void);

static void Titanium_V60_Log(NSString *msg);
static NSInteger Titanium_GetMasterRate(void);
static inline BOOL Titanium_ShouldPurgeNow(void);
static void Titanium_HardwareDriverOverride(NSInteger targetHz);
static void Titanium_ForcePanelModeDirect(NSInteger hz);
static void Titanium_Tier4WriteCadence(NSInteger hz);
static void Titanium_Tier4RollbackCadence(void);
static void Titanium_ReloadSharedSyncStateV285(void);
static void Tio_DCPResolveConnections(void);
static kern_return_t Tio_IomfbRawSetMode(NSInteger hz);
static kern_return_t Tio_DisplayConnSetRefresh(NSInteger hz);

#import <notify.h>
#include <signal.h>

static void Titanium_ExecuteUltimateHardwareHack(NSInteger targetHz);
static void Titanium_Tier4_WriteCADisplayRefresh(NSInteger hz);
static volatile NSInteger g_tioLastAcceptedHz = 0;
static void Titanium_Tier6JetsamImmunityReal(void) {}
static void Titanium_Tier4_WriteCADisplayRefresh(NSInteger hz) {}

#define TITANIUM_CHECK_FILE @"/var/mobile/titanium_check.txt"
#define TITANIUM_V57_BEST_HZ_FILE @"/tmp/.boost_best_hz"

static volatile BOOL     g_v55ScreenOn      = YES;
static volatile BOOL     g_v55WakeSettling  = NO;
static volatile BOOL     g_v55FirstFrame    = NO;
static volatile BOOL     g_v55ThermalSafe   = YES;
static volatile BOOL     g_v56KeyboardVisible  = NO;
static volatile uint64_t g_v56KeyboardHideTick = 0;
static volatile uint64_t  g_v57AppLaunchTick   = 0;
static volatile uint64_t  g_v57LastIPCReload   = 0;
static volatile uint64_t  g_v57LastReapply     = 0;
static volatile NSInteger g_v57SharedBestHz    = 0;
static volatile BOOL g_v60ForceDriverSuccess = NO;

static inline uint64_t v55_ns(uint64_t ns) { return Titanium_NanosToMachTicks(ns); }

static void Titanium_V60_Log(NSString *msg) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        [[NSFileManager defaultManager] removeItemAtPath:TITANIUM_CHECK_FILE error:nil];
    });
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:TITANIUM_CHECK_FILE];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:TITANIUM_CHECK_FILE contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:TITANIUM_CHECK_FILE];
    }
    if (fh) {
        [fh seekToEndOfFile];
        NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
        [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [fh closeFile];
    }
}

static inline BOOL Titanium_V57_TouchReady(void) {
    if (!g_v55ScreenOn) return NO;
    if (g_v55WakeSettling) return NO;
    if (g_v55FirstFrame) return YES;
    if (g_v57AppLaunchTick != 0 && (mach_absolute_time() - g_v57AppLaunchTick) > v55_ns(2000000000ULL)) {
        g_v55FirstFrame = YES;
        return YES;
    }
    return NO;
}
static inline BOOL Titanium_V55_PanelWritable(void) { return g_v55ScreenOn && !g_v55WakeSettling; }
static inline BOOL Titanium_V56_KeyboardBusy(void) {
    if (g_v56KeyboardVisible) return YES;
    if (g_v56KeyboardHideTick != 0 && (mach_absolute_time() - g_v56KeyboardHideTick) < v55_ns(250ULL * 1000000ULL)) {
        return YES;
    }
    return NO;
}

static void Titanium_V57_ReloadIPCIfStale(void) {
    uint64_t now = mach_absolute_time();
    if (g_v57LastIPCReload != 0 && (now - g_v57LastIPCReload) < v55_ns(500ULL * 1000000ULL)) return;
    g_v57LastIPCReload = now;
    Titanium_ReloadSharedSyncStateV285();
}

static NSInteger Titanium_V57_ReadSharedBestHz(void) {
    if (g_v57SharedBestHz > 0) return g_v57SharedBestHz;
    @try {
        NSData *d = [NSData dataWithContentsOfFile:TITANIUM_V57_BEST_HZ_FILE];
        if (d && d.length >= sizeof(int32_t)) {
            int32_t hz = 0;
            [d getBytes:&hz length:sizeof(int32_t)];
            if (hz >= 60 && hz <= 240) { g_v57SharedBestHz = hz; return hz; }
        }
    } @catch (__unused NSException *e) {}
    return 0;
}

static void Titanium_V57_WriteSharedBestHz(NSInteger hz) {
    if (hz < 15 || hz > 240) return;
    g_v57SharedBestHz = hz;
    int32_t v = (int32_t)hz;
    NSData *d = [NSData dataWithBytes:&v length:sizeof(v)];
    [d writeToFile:TITANIUM_V57_BEST_HZ_FILE atomically:YES];
}

static void Titanium_V57_ForceReapplyIfNeeded(void) {
    if (Titanium_IsSpringBoard()) return;
    if (!Titanium_V57_TouchReady()) return;
    uint64_t now = mach_absolute_time();
    if (g_v57LastReapply != 0 && (now - g_v57LastReapply) < v55_ns(1000ULL * 1000000ULL)) return;
    g_v57LastReapply = now;
    Titanium_V57_ReloadIPCIfStale();
    dispatch_async(dispatch_get_main_queue(), ^{
        @try { Titanium_ReapplyFrameRateToAllScenes(); } @catch (__unused NSException *e) {}
    });
}

static void Titanium_V56_InstallKeyboardState(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserverForName:UIKeyboardWillShowNotification object:nil queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *n) { g_v56KeyboardVisible = YES; g_v56KeyboardHideTick = 0; }];
        [nc addObserverForName:UIKeyboardDidShowNotification object:nil queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *n) { g_v56KeyboardVisible = YES; }];
        [nc addObserverForName:UIKeyboardWillHideNotification object:nil queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *n) { g_v56KeyboardVisible = NO; g_v56KeyboardHideTick = mach_absolute_time(); }];
        [nc addObserverForName:UIKeyboardDidHideNotification object:nil queue:[NSOperationQueue mainQueue]
                    usingBlock:^(__unused NSNotification *n) { g_v56KeyboardVisible = NO; g_v56KeyboardHideTick = mach_absolute_time(); }];
    });
}

// [SYNC RATE CORE] - Ép đồng bộ tuyệt đối Hz và FPS thành 1
static NSInteger Titanium_GetMasterRate(void) {
    Titanium_V57_ReloadIPCIfStale();
    NSInteger hz = g_syncPayloadV285.targetHz;
    NSInteger fps = g_syncPayloadV285.targetFPS;
    
    if (hz < 15) hz = g_cachedResolvedHz;
    if (fps < 15) fps = g_cachedResolvedFPS;
    if (hz < 15 && CFG285) hz = CFG285.targetHz;
    if (fps < 15 && CFG285) fps = CFG285.targetFPS;

    // Ép đồng bộ: Lấy giá trị cao nhất để cả 2 chạy chung 1 tốc độ
    NSInteger master = MAX(hz, fps);
    if (master < 15) master = 60;
    if (master > 240) master = 240;
    return master;
}

static NSInteger Titanium_GetUserTargetHz(void) {
    return Titanium_GetMasterRate();
}

static NSInteger Titanium_GetUserTargetFPS(void) {
    return Titanium_GetMasterRate();
}

static float Titanium_ForceUserHz(float r) { (void)r; return (float)Titanium_GetMasterRate(); }
static float Titanium_ForceUserFPS(float r) { (void)r; return (float)Titanium_GetMasterRate(); }

static volatile NSInteger g_tioActiveHz        = 0;
static volatile double    g_tioObservedVsyncHz = 0.0;
static volatile BOOL      g_tioOverdriveBusy   = NO;
static volatile BOOL      g_tioRecoveryArmed   = NO;
static volatile uint64_t  g_tioLastVsyncTick   = 0;
static volatile NSInteger g_tioCooldownUntil   = 0;
static volatile BOOL      g_tioOverdriveDone   = NO;
static volatile NSInteger g_tioCachedBestHz    = 0;

static inline uint64_t tio_mach_nanos(uint64_t n) { return Titanium_NanosToMachTicks(n); }
static inline BOOL tio_elapsed_ms(uint64_t since, uint64_t ms) {
    return since != 0 && (mach_absolute_time() - since) >= tio_mach_nanos(ms * 1000000ULL);
}

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
- (void)tick:(CADisplayLink *)link {
    if (!Titanium_V55_PanelWritable()) return;
    NSInteger targetHz = Titanium_GetMasterRate();

    Titanium_DriftCheck(link.timestamp, link.targetTimestamp, targetHz);

    link.preferredFramesPerSecond = targetHz;
    if (@available(iOS 15.0, *)) {
        link.preferredFrameRateRange = CAFrameRateRangeMake((float)targetHz, (float)targetHz, (float)targetHz);
    }

    CFTimeInterval d = link.targetTimestamp - link.timestamp;
    if (d > 0.004 && d < 0.2) {
        g_tioObservedVsyncHz = 1.0 / d;
        g_tioLastVsyncTick   = mach_absolute_time();
    }
}
@end

static BOOL Titanium_IsUIProcess(void) {
    NSString *path = [[NSBundle mainBundle] bundlePath];
    return path != nil && [path hasSuffix:@".app"];
}

static TitaniumOverdriveVSyncProbe *g_tioProbe = nil;

static void Titanium_StartOverdriveProbe(void) {
    if (!Titanium_IsUIProcess()) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        TitaniumOverdriveVSyncProbe *p = [TitaniumOverdriveVSyncProbe new];
        p.link = [CADisplayLink displayLinkWithTarget:p selector:@selector(tick:)];
        p.link.preferredFramesPerSecond = Titanium_GetMasterRate();
        if (@available(iOS 15.0, *)) {
            p.link.preferredFrameRateRange = CAFrameRateRangeMake((float)Titanium_GetMasterRate(), (float)Titanium_GetMasterRate(), (float)Titanium_GetMasterRate());
        }
        p.link.paused = !g_v55ScreenOn;
        [p.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        g_tioProbe = p;
        g_tioLastVsyncTick = mach_absolute_time();
    });
}

// ====================================================================================================
// IOMFB DIRECT — RAW MIG + COOLDOWN
// ====================================================================================================

typedef void *tio_iomfb_ref;
typedef kern_return_t (*tio_iomfb_main_fn)(tio_iomfb_ref *out);
typedef kern_return_t (*tio_iomfb_setmode_fn)(tio_iomfb_ref fb, uint32_t w, uint32_t h, float hz);

static tio_iomfb_main_fn    tio_iomfb_main    = NULL;
static tio_iomfb_setmode_fn tio_iomfb_setmode = NULL;
static tio_iomfb_ref        tio_iomfb_handle  = NULL;

typedef struct __attribute__((packed)) {
    uint32_t width;
    uint32_t height;
    uint32_t refreshRate;
    uint32_t pixelClock;
    uint32_t hSyncStart;
    uint32_t hSyncEnd;
    uint32_t vSyncStart;
    uint32_t vSyncEnd;
    uint32_t flags;
} TioIomfbTiming;

static io_service_t g_dcpIomfbSvc = IO_OBJECT_NULL;
static io_service_t g_dcpDispSvc  = IO_OBJECT_NULL;
static io_connect_t g_dcpIomfbConn = IO_OBJECT_NULL;
static io_connect_t g_dcpDispConn = IO_OBJECT_NULL;
static volatile BOOL g_dcpConnReady = NO;

typedef enum {
    TioPathNone = 0,
    TioPathFramework,
    TioPathRawMIG,
    TioPathDisplayConnect
} TioDriverPath;
static volatile TioDriverPath g_tioBestPath = TioPathNone;

static void Titanium_LoadIOMFBDirect(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *lib = dlopen("/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer", RTLD_LAZY);
        if (!lib) return;
        tio_iomfb_main    = (tio_iomfb_main_fn)dlsym(lib, "IOMobileFramebufferGetMainDisplay");
        tio_iomfb_setmode = (tio_iomfb_setmode_fn)dlsym(lib, "IOMobileFramebufferSetDisplayMode");
        if (tio_iomfb_main && tio_iomfb_main(&tio_iomfb_handle) != KERN_SUCCESS) {
            tio_iomfb_handle = NULL;
        }
    });
}

static kern_return_t (*orig_IOConnectCallStructMethod)(io_connect_t, uint32_t, const void*, size_t, void*, size_t*) = NULL;
static kern_return_t hooked_IOConnectCallStructMethod(io_connect_t connection, uint32_t selector, const void *inputStruct, size_t inputStructCnt, void *outputStruct, size_t *outputStructCnt) {
    kern_return_t ret = KERN_FAILURE;
    if (orig_IOConnectCallStructMethod) {
        ret = orig_IOConnectCallStructMethod(connection, selector, inputStruct, inputStructCnt, outputStruct, outputStructCnt);
    }
    if (g_v60ForceDriverSuccess && (IS_ACTIVE || Apex_IsMasterEnabled())) return KERN_SUCCESS;
    return ret;
}

static kern_return_t (*orig_IOConnectCallScalarMethod)(io_connect_t, uint32_t, const uint64_t*, uint32_t, uint64_t*, uint32_t*) = NULL;
static kern_return_t hooked_IOConnectCallScalarMethod(io_connect_t connection, uint32_t selector, const uint64_t *input, uint32_t inputCnt, uint64_t *output, uint32_t *outputCnt) {
    kern_return_t ret = KERN_FAILURE;
    if (orig_IOConnectCallScalarMethod) {
        ret = orig_IOConnectCallScalarMethod(connection, selector, input, inputCnt, output, outputCnt);
    }
    if (g_v60ForceDriverSuccess && (IS_ACTIVE || Apex_IsMasterEnabled())) return KERN_SUCCESS;
    return ret;
}

static void Titanium_BypassDCPMethod(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        const TitaniumIOKitSyms *s = Titanium_ResolveIOKitSyms();
        if (s->connectStructMethod) {
            MSHookFunction((void *)s->connectStructMethod, (void *)hooked_IOConnectCallStructMethod, (void **)&orig_IOConnectCallStructMethod);
        }
        if (s->connectScalarMethod) {
            MSHookFunction((void *)s->connectScalarMethod, (void *)hooked_IOConnectCallScalarMethod, (void **)&orig_IOConnectCallScalarMethod);
        }
    });
}

static void Tio_DCPResolveConnections(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            const TitaniumIOKitSyms *s = Titanium_ResolveIOKitSyms();
            if (!s->getMatchingService || !s->serviceOpen) { g_dcpConnReady = NO; return; }
            const char *services[] = {
                "IOMobileFramebuffer", "IOMobileFramebufferAP",
                "AppleDCP", "AppleCLCD2", "AppleCLCD",
                "AppleDCPAVController", "AppleM2Scaler", "AppleM2ScalerUserClient"
            };
            int n = (int)(sizeof(services)/sizeof(services[0]));
            for (int i = 0; i < n; i++) {
                g_dcpIomfbSvc = s->getMatchingService(kIOMasterPortDefault, IOServiceMatching(services[i]));
                if (g_dcpIomfbSvc != IO_OBJECT_NULL) {
                    if (s->serviceOpen(g_dcpIomfbSvc, mach_task_self(), 0, &g_dcpIomfbConn) == KERN_SUCCESS) break;
                }
            }
            io_iterator_t iter = IO_OBJECT_NULL;
            if (s->getMatchingServices &&
                s->getMatchingServices(kIOMasterPortDefault, IOServiceMatching("IODisplayConnect"), &iter) == KERN_SUCCESS &&
                iter != IO_OBJECT_NULL) {
                g_dcpDispSvc = IOIteratorNext(iter);
                IOObjectRelease(iter);
                if (g_dcpDispSvc != IO_OBJECT_NULL) (void)s->serviceOpen(g_dcpDispSvc, mach_task_self(), 0, &g_dcpDispConn);
            }
            g_dcpConnReady = (g_dcpIomfbConn != IO_OBJECT_NULL) || (g_dcpDispConn != IO_OBJECT_NULL);
        } @catch (__unused NSException *e) { g_dcpConnReady = NO; }
    });
}

static kern_return_t Tio_DisplayConnSetRefresh(NSInteger hz) {
    if (g_isRebooting) return KERN_FAILURE;
    if (!Titanium_V55_PanelWritable()) return KERN_FAILURE;
    const TitaniumIOKitSyms *s = Titanium_ResolveIOKitSyms();
    if (!s->connectScalarMethod) return KERN_FAILURE;
    Tio_DCPResolveConnections();
    if (g_dcpDispConn == IO_OBJECT_NULL) return KERN_FAILURE;
    g_v60ForceDriverSuccess = YES;
    static const uint32_t kSels[] = { 8, 9, 10, 11, 12, 13 };
    for (uint32_t i = 0; i < 6; i++) {
        uint64_t in = (uint64_t)hz;
        uint32_t outLen = 0;
        kern_return_t kr = s->connectScalarMethod(g_dcpDispConn, kSels[i], &in, 1, NULL, &outLen);
        if (kr == KERN_SUCCESS) { g_v60ForceDriverSuccess = NO; return kr; }
    }
    g_v60ForceDriverSuccess = NO;
    return KERN_FAILURE;
}

static BOOL Tio_SubmitModeAllPaths(NSInteger hz) {
    if (g_isRebooting) return NO;
    const TitaniumIOKitSyms *syms = Titanium_ResolveIOKitSyms();
    if (g_dcpIomfbConn != IO_OBJECT_NULL && syms->connectStructMethod) {
        TioIomfbTiming timing;
        memset(&timing, 0, sizeof(timing));
        timing.width = (uint32_t)[UIScreen mainScreen].nativeBounds.size.width;
        timing.height = (uint32_t)[UIScreen mainScreen].nativeBounds.size.height;
        timing.refreshRate = (uint32_t)hz;
        timing.pixelClock = (uint32_t)((timing.width + 64) * (timing.height + 32) * hz * 1.05);
        timing.flags = 0xFFFFFFFF;
        uint32_t selectors[] = {14, 15, 16, 17, 18, 19, 30, 31};
        for (int i = 0; i < 8; i++) {
            size_t outLen = 0;
            (void)syms->connectStructMethod(g_dcpIomfbConn, selectors[i], &timing, sizeof(timing), NULL, &outLen);
        }
        g_tioBestPath = TioPathRawMIG;
    }
    if (g_dcpDispConn != IO_OBJECT_NULL) Tio_DisplayConnSetRefresh(hz);
    if (tio_iomfb_setmode && tio_iomfb_handle) {
        tio_iomfb_setmode(tio_iomfb_handle, (uint32_t)[UIScreen mainScreen].nativeBounds.size.width, (uint32_t)[UIScreen mainScreen].nativeBounds.size.height, (float)hz);
    }
    return YES;
}

// [FORCE PANEL MODE]
static void Titanium_ForcePanelModeDirect(NSInteger hz) {
    if (!Titanium_V55_PanelWritable()) return;
    if (hz < 15) hz = 15;
    if (hz > 240) hz = 240;
    if (!Titanium_CanPunchHardware()) return;
    Titanium_MarkHardwarePunched();

    const TitaniumIOKitSyms *syms = Titanium_ResolveIOKitSyms();
    if (!syms->connectStructMethod) return;

    CGFloat pw = [UIScreen mainScreen].nativeBounds.size.width;
    CGFloat ph = [UIScreen mainScreen].nativeBounds.size.height;
    g_v60ForceDriverSuccess = YES;
    Tio_DCPResolveConnections();

    if (g_dcpIomfbConn != IO_OBJECT_NULL) {
        TioIomfbTiming timing;
        memset(&timing, 0, sizeof(timing));
        timing.width = (uint32_t)pw; timing.height = (uint32_t)ph;
        timing.refreshRate = (uint32_t)hz;
        timing.pixelClock = (uint32_t)((pw + 64) * (ph + 32) * hz * 1.05);
        timing.hSyncEnd = (uint32_t)pw; timing.vSyncEnd = (uint32_t)ph;
        timing.flags = 0xFFFFFFFF;
        uint32_t selectors[] = {
            14, 15, 16, 17, 18, 19, 20, 21,
            22, 23, 24, 25, 26, 27, 28, 29,
            30, 31, 32, 33,
            40, 41, 42
        };
        int n = (int)(sizeof(selectors)/sizeof(selectors[0]));
        for (int i = 0; i < n; i++) {
            size_t outLen = 0;
            (void)syms->connectStructMethod(g_dcpIomfbConn, selectors[i], &timing, sizeof(timing), NULL, &outLen);
        }
    }
    if (tio_iomfb_setmode && tio_iomfb_handle) tio_iomfb_setmode(tio_iomfb_handle, (uint32_t)pw, (uint32_t)ph, (float)hz);
    g_v60ForceDriverSuccess = NO;
    
    // Bốc double punch, không gọi HardwareDriverOverride ở đây để đỡ nóng
    g_tioActiveHz = hz;
    Titanium_V60_Log([NSString stringWithFormat:@"[PUNCH] Panel forced to %ldHz", (long)hz]);

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            Titanium_EnforceCAFrameRange();
            id cad = [%c(CADisplay) mainDisplay];
            if (cad && [cad respondsToSelector:@selector(setPreferredFPS:)]) {
                ((void (*)(id, SEL, NSInteger))objc_msgSend)(cad, @selector(setPreferredFPS:), hz);
            }
        } @catch (__unused NSException *e) {}
    });
}

static NSInteger Titanium_IOMFBTryAlternateModes(NSInteger targetHz) {
    if (g_tioCachedBestHz == targetHz) return targetHz;
    if (!Titanium_V55_PanelWritable()) return 0;
    const TitaniumIOKitSyms *syms = Titanium_ResolveIOKitSyms();
    if (!syms->connectStructMethod) return 0;
    uint32_t w = (uint32_t)[UIScreen mainScreen].nativeBounds.size.width;
    uint32_t h = (uint32_t)[UIScreen mainScreen].nativeBounds.size.height;
    NSInteger upper = MIN(targetHz, (NSInteger)240);
    g_v60ForceDriverSuccess = YES;
    Tio_DCPResolveConnections();
    if (g_dcpIomfbConn != IO_OBJECT_NULL) {
        TioIomfbTiming timing;
        memset(&timing, 0, sizeof(timing));
        timing.width = w; timing.height = h;
        timing.refreshRate = (uint32_t)upper;
        timing.pixelClock = (uint32_t)((w + 64) * (h + 32) * upper * 1.05);
        timing.flags = 0xFFFFFFFF;
        uint32_t selectors[] = {14, 15, 16, 17, 18, 19};
        for (int i = 0; i < 6; i++) {
            size_t outLen = 0;
            (void)syms->connectStructMethod(g_dcpIomfbConn, selectors[i], &timing, sizeof(timing), NULL, &outLen);
        }
    }
    if (g_dcpDispConn != IO_OBJECT_NULL) Tio_DisplayConnSetRefresh(upper);
    if (tio_iomfb_setmode && tio_iomfb_handle) tio_iomfb_setmode(tio_iomfb_handle, w, h, (float)upper);
    g_v60ForceDriverSuccess = NO;
    g_tioCachedBestHz = upper;
    return upper;
}

static void Titanium_V55_InstallScreenState(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        int token = 0;
        notify_register_dispatch("com.apple.springboard.hasBlankedScreen", &token, dispatch_get_main_queue(), ^(int t) {
            uint64_t state = 0;
            notify_get_state(t, &state);
            BOOL on = (state == 0);
            g_v55ScreenOn = on;
            if (on) {
                g_v55WakeSettling = YES;
                g_tioObservedVsyncHz = 0.0;
                g_tioLastVsyncTick = mach_absolute_time();
                g_tioRecoveryArmed = NO;
                if (g_tioProbe && g_tioProbe.link) g_tioProbe.link.paused = NO;
                NSInteger targetHz = Titanium_GetMasterRate();
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    Titanium_ExecuteUltimateHardwareHack(targetHz);
                    Titanium_HardwareDriverOverride(targetHz);
                    Titanium_Tier4WriteCadence(targetHz);
                });
                dispatch_async(dispatch_get_main_queue(), ^{
                    Titanium_ReapplyFrameRateToAllScenes();
                    if (g_tioProbe && g_tioProbe.link) {
                        g_tioProbe.link.preferredFramesPerSecond = targetHz;
                        if (@available(iOS 15.0, *)) {
                            g_tioProbe.link.preferredFrameRateRange = CAFrameRateRangeMake((float)targetHz, (float)targetHz, (float)targetHz);
                        }
                    }
                });
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(800 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    g_v55WakeSettling = NO;
                });
            } else {
                if (g_tioProbe && g_tioProbe.link) g_tioProbe.link.paused = YES;
                g_tioRecoveryArmed = NO;
            }
        });
    });
}

static volatile uint64_t  g_v55LastCadenceTick = 0;
static volatile NSInteger g_v55LastCadenceHz   = 0;

static void Titanium_Tier4WriteCadence(NSInteger hz) {
    if (!Titanium_V55_PanelWritable()) return;
    if (hz < 15) hz = 15;
    if (hz > 240) hz = 240;
    g_v55LastCadenceHz = hz;
    g_v55LastCadenceTick = mach_absolute_time();
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
                TIO_SEND(setMaximumRefreshRate, double, (double)hz);
                TIO_SEND(setIdealRefreshRate, double, (double)hz);
                TIO_SEND(setMinimumRefreshRate, double, (double)hz);
                #undef TIO_SEND
            }
            id cad = [%c(CADisplay) mainDisplay];
            if (cad) {
                if ([cad respondsToSelector:@selector(setAllowsVirtualModes:)])
                    ((BOOL (*)(id, SEL, BOOL))objc_msgSend)(cad, @selector(setAllowsVirtualModes:), YES);
                if ([cad respondsToSelector:@selector(setPreferredFPS:)])
                    ((void (*)(id, SEL, NSInteger))objc_msgSend)(cad, @selector(setPreferredFPS:), hz);
            }
        } @catch (NSException *e) {}
    });
}

static void Titanium_Tier5WriteIORegistryTiming(NSInteger hz) {
    if (!Titanium_V55_PanelWritable()) return;
    const TitaniumIOKitSyms *s = Titanium_ResolveIOKitSyms();
    if (!s->entryFromPath || !s->setCFProperty) return;
    if (hz < 15) hz = 15;
    if (hz > 240) hz = 240;
    @try {
        const char *paths[] = {
            "IOService:/AppleARMPE/display0",
            "IOService:/AppleARMPE/display0/AppleCLCD2",
            "IOService:/AppleARMPE/display0/IOMobileFramebuffer",
            "IOService:/arm-io/display0"
        };
        g_v60ForceDriverSuccess = YES;
        NSDictionary *props = @{
            @"target-refresh-rate"    : @(hz),
            @"preferred-refresh-rate" : @(hz),
            @"min-refresh-rate"       : @(hz),
            @"max-refresh-rate"       : @(hz),
            @"refresh-rate"           : @(hz),
            @"DisplayRefreshRate"     : @(hz),
            @"IOMFBCustomRefreshRate" : @(hz),
            @"IOMFBSupportsProMotion" : @YES,
            @"isProMotionEnabled"     : @YES,
            @"VRRModeEnabled"         : @YES,
            @"ThermalMitigationEnabled" : @NO,
            @"thermal-mitigation"     : @NO,
            @"FrameRateProtection"    : @NO,
            @"DynamicPowerManagement" : @NO,
            @"DisplayIdleDownclock"   : @NO,
            @"IOMFBPowerManagement"   : @NO,
            @"IOMFBCurrentPowerState" : @(1),
            @"AllowHardwareOverclock" : @YES,
            @"ForcePixelClock"        : @YES,
            @"MaxPixelClock"          : @(999999999),
            @"OverrideLimit"          : @YES,
            @"BypassEDIDCheck"        : @YES
        };
        for (size_t i = 0; i < sizeof(paths)/sizeof(paths[0]); i++) {
            io_registry_entry_t entry = s->entryFromPath(kIOMasterPortDefault, paths[i]);
            if (entry == IO_OBJECT_NULL) continue;
            for (NSString *k in props) {
                (void)s->setCFProperty(entry, (__bridge CFStringRef)k, (__bridge CFTypeRef)props[k]);
            }
            IOObjectRelease(entry);
        }
        g_v60ForceDriverSuccess = NO;
    } @catch (NSException *e) {
        g_v60ForceDriverSuccess = NO;
        Titanium_V60_Log([NSString stringWithFormat:@"[V999] Tier5 IORegistry throw: %@", e.reason]);
    }
}

// [REALTIME FRAME — CHỈ KHI SCROLL ĐỂ CHỐNG NÓNG]
static void Titanium_Tier6RealtimeFrameConstraint(NSInteger hz) {
    if (!Titanium_V57_TouchReady()) return;
    if (Titanium_V56_KeyboardBusy()) return;
    if (![NSThread isMainThread]) return;
    if (hz < 15 || hz > 240) return;
    // Chỉ ép realtime khi scroll để không nóng máy
    if (!g_isScrollingActive && !g_isContinuousSwiping) return;

    mach_port_t thread = pthread_mach_thread_np(pthread_self());
    uint64_t periodNs = 1000000000ULL / (uint64_t)hz;

    thread_time_constraint_policy_data_t tc;
    tc.period = (uint32_t)tio_mach_nanos(periodNs);
    tc.computation = (uint32_t)tio_mach_nanos(periodNs * 0.25);
    tc.constraint  = (uint32_t)tio_mach_nanos(periodNs * 0.40);
    tc.preemptible = TRUE;
    thread_policy_set(thread, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&tc, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}

static void Titanium_OverdrivePipelineGo(NSInteger targetHz) {
    if (g_tioOverdriveBusy) return;
    if (!Titanium_V55_PanelWritable()) return;
    g_tioOverdriveBusy = YES;
    g_tioRecoveryArmed = NO;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            Titanium_LoadIOMFBDirect();
            if (targetHz > 60) Titanium_IOMFBTryAlternateModes(targetHz);
            g_tioActiveHz = targetHz;
            g_tioRecoveryArmed = YES;
            g_tioLastVsyncTick = mach_absolute_time();
            Titanium_Tier4WriteCadence(targetHz);
            Titanium_ForcePanelModeDirect(targetHz);
            Titanium_V57_WriteSharedBestHz(targetHz);
            Titanium_V60_Log([NSString stringWithFormat:@"[V77] HARD FORCED %ldHz", (long)targetHz]);
            g_tioOverdriveBusy = NO;
        }
    });
}

void Titanium_ExecuteRealPanelOverdrive(void) {
    if (!Titanium_V55_PanelWritable()) return;
    Titanium_V57_ReloadIPCIfStale();
    NSInteger targetHz = Titanium_GetMasterRate();
    Titanium_StartOverdriveProbe();
    Titanium_Tier6JetsamImmunityReal();
    Titanium_Tier6RealtimeFrameConstraint(targetHz);
    Titanium_OverdrivePipelineGo(targetHz);
    Titanium_Tier4WriteCadence(targetHz);
}

// [HARDWARE DRIVER OVERRIDE]
static void Titanium_HardwareDriverOverride(NSInteger targetHz) {
    if (!Titanium_V55_PanelWritable()) return;
    if (targetHz < 15) targetHz = 15;
    if (targetHz > 240) targetHz = 240;
    const TitaniumIOKitSyms *s = Titanium_ResolveIOKitSyms();
    if (!s->setCFProperties && !s->setCFProperty) return;
    if (!s->getMatchingServices && !s->getMatchingService) return;
    if (!Titanium_CanPunchHardware()) return;
    Titanium_MarkHardwarePunched();
    g_v60ForceDriverSuccess = YES;
    NSDictionary *overrideProps = @{
        @"DisplayPipeRefreshRate" : @(targetHz),
        @"TargetRefreshRate"      : @(targetHz),
        @"MaximumRefreshRate"     : @(targetHz),
        @"MinimumRefreshRate"     : @(targetHz),
        @"IOMFBSupportsProMotion" : @YES,
        @"isProMotionEnabled"     : @YES,
        @"VRRModeEnabled"         : @YES,
        @"AllowsVirtualModes"     : @YES,
        @"DisplayIdleDownclock"   : @NO,
        @"IOMFBCustomRefreshRate" : @(targetHz),
        @"IOMFBCurrentPowerState" : @(1),
        @"SupportsVRR"            : @YES,
        @"PipeOverrideMode"       : @YES,
        @"MinFrameDuration"       : @(1000000000 / targetHz),
        @"ThermalMitigationEnabled" : @NO,
        @"DynamicPowerManagement" : @NO,
        @"FrameRateProtection"    : @NO,
        @"AllowHardwareOverclock" : @YES,
        @"BypassEDIDCheck"        : @YES,
        @"ForcePixelClock"        : @YES,
        @"MaxPixelClock"          : @(999999999),
        @"OverrideLimit"          : @YES
    };
    const char *drivers[] = {
        "AppleDCP", "AppleCLCD2", "AppleCLCD",
        "IOMobileFramebufferAP", "IOMobileFramebuffer",
        "IOFramebuffer", "IOMobileFramebufferClient",
        "IOFramebufferUserClient", "AppleDCPAVController",
        "IOAVController", "AGXAcceleratorG13", "AGXAcceleratorG14",
        "AppleM2Scaler", "AppleM2ScalerUserClient"
    };
    for (size_t i = 0; i < sizeof(drivers)/sizeof(drivers[0]); i++) {
        CFMutableDictionaryRef matchDict = IOServiceMatching(drivers[i]);
        if (!matchDict) continue;
        io_iterator_t iterator = IO_OBJECT_NULL;
        kern_return_t kr = s->getMatchingServices ? s->getMatchingServices(kIOMasterPortDefault, matchDict, &iterator) : KERN_FAILURE;
        if (kr != KERN_SUCCESS || iterator == IO_OBJECT_NULL) continue;
        io_service_t service = IO_OBJECT_NULL;
        while ((service = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
            (void)Titanium_SafeSetCFProperties(service, overrideProps);
            IOObjectRelease(service);
        }
        IOObjectRelease(iterator);
    }
    g_v60ForceDriverSuccess = NO;
}

// ====================================================================================================
// HOOK: ProMotion overclock — BẺ THẲNG XUỐNG DRIVER, REFUSE LOWER, LOCK RATE
// ====================================================================================================
%group Group_Hardware_ProMotion_Overclock

%hook IOHIDEventSystemClient
- (void)setProperty:(id)property forKey:(NSString *)key {
    if (!self) { %orig(property, key); return; }
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && key) {
        if ([key isEqualToString:@"ReportInterval"] || [key isEqualToString:@"HIDReportInterval"]) {
            NSInteger target = Titanium_GetMasterRate();
            %orig(@(1000000 / target), key);
            return;
        }
    }
    %orig(property, key);
}

- (id)copyPropertyForKey:(id)arg1 {
    id ret = %orig(arg1);
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && [arg1 isKindOfClass:[NSString class]]) {
        if ([arg1 isEqualToString:@"ReportInterval"] || [arg1 isEqualToString:@"HIDReportInterval"]) {
            return @(1000000 / Titanium_GetMasterRate());
        }
    }
    return ret;
}
%end

// [BẺ THẲNG DRIVER] Ép C function IOMobileFramebufferSetDisplayMode trực tiếp
// Đây là entry point driver hardware — hook nó = hook mọi đường vào hardware.
static void (*orig_IOMobileFramebufferSetDisplayMode)(void *fb, uint32_t w, uint32_t h, float hz) = NULL;
static void hooked_IOMobileFramebufferSetDisplayMode(void *fb, uint32_t w, uint32_t h, float hz) {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V55_PanelWritable()) {
        NSInteger target = Titanium_GetMasterRate();
        if (orig_IOMobileFramebufferSetDisplayMode) {
            orig_IOMobileFramebufferSetDisplayMode(fb, w, h, (float)target);
        }
        return;
    }
    if (orig_IOMobileFramebufferSetDisplayMode) {
        orig_IOMobileFramebufferSetDisplayMode(fb, w, h, hz);
    }
}

%hook IOMobileFramebufferClient
// [REFUSE LOWER] setDisplayRefreshRate — ép target, không nhận rate thấp hơn
- (int)setDisplayRefreshRate:(float)rate options:(unsigned int)options {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V55_PanelWritable()) {
        NSInteger target = Titanium_GetMasterRate();
        Titanium_ForcePanelModeDirect(target);
        return 0; // Ép driver báo success
    }
    return %orig(rate, options);
}

- (int)setDisplayRefreshRate:(float)rate {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V55_PanelWritable()) {
        NSInteger target = Titanium_GetMasterRate();
        Titanium_ForcePanelModeDirect(target);
        return 0;
    }
    return %orig(rate);
}

// Getter luôn trả MasterRate — không cho app đọc rate thật
- (int)getDisplayRefreshRate:(float *)arg1 {
    int ret = %orig(arg1);
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && arg1) {
        *arg1 = (float)Titanium_GetMasterRate();
    }
    return ret;
}

- (float)getDisplayRefreshRate {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        return (float)Titanium_GetMasterRate();
    }
    return %orig;
}
%end

// [BẺ THẲNG DRIVER] CADisplayMode — mọi mode getter/setter đều trả MasterRate
%hook CADisplayMode
- (double)refreshRate {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (double)pixelAspectRatio {
    return %orig;
}
%end

// [BẺ THẲNG DRIVER] CADisplay — refuse lower, force target
%hook CADisplay
- (double)refreshRate {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setRefreshRate:(double)rate {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
        // Refuse lower — ép MasterRate
        NSInteger target = Titanium_GetMasterRate();
        %orig((double)target);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            Titanium_ForcePanelModeDirect(target);
        });
        return;
    }
    %orig(rate);
}

- (NSInteger)preferredFPS {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setPreferredFPS:(NSInteger)fps {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
        // [REFUSE LOWER] Nếu fps < MasterRate, ép về MasterRate
        NSInteger target = Titanium_GetMasterRate();
        %orig(target);
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            Titanium_ForcePanelModeDirect(target);
        });
        return;
    }
    %orig(fps);
}

- (BOOL)allowsVirtualModes { return YES; }
- (void)setAllowsVirtualModes:(BOOL)allows { %orig(YES); }

- (void)overrideDisplayCadence:(id)cadence {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        Titanium_Tier4_ExecuteHardwarePanelOverdrive();
    }
    %orig(cadence);
}

// [REFUSE LOWER] Bất kỳ setCurrentMode nào cũng ép về target mode
- (void)setCurrentMode:(id)mode {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
        @try {
            NSArray *modes = nil;
            if ([self respondsToSelector:@selector(availableModes)]) {
                modes = [self performSelector:@selector(availableModes)];
            }
            NSInteger target = Titanium_GetMasterRate();
            if (modes && [modes count] > 0) {
                // Tìm mode có refreshRate gần target nhất
                id bestMode = nil;
                double bestDiff = 999.0;
                for (id m in modes) {
                    if ([m respondsToSelector:@selector(refreshRate)]) {
                        double r = ((double (*)(id, SEL))objc_msgSend)(m, @selector(refreshRate));
                        double diff = fabs(r - (double)target);
                        if (diff < bestDiff) {
                            bestDiff = diff;
                            bestMode = m;
                        }
                    }
                }
                if (bestMode) {
                    %orig(bestMode);
                    return;
                }
            }
        } @catch (__unused NSException *e) {}
    }
    %orig(mode);
}
%end

// [LOCK HARDWARE] CAWindowServerDisplay — ép mọi rate lock, không cho hạ
%hook CAWindowServerDisplay
- (void)setMinimumFrameDuration:(double)duration {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        NSInteger target = Titanium_GetMasterRate();
        %orig(1.0 / (double)target);
        return;
    }
    %orig(duration);
}

- (double)minimumFrameDuration {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        NSInteger target = Titanium_GetMasterRate();
        return 1.0 / (double)target;
    }
    return %orig;
}

- (void)setMaximumRefreshRate:(double)rate {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        NSInteger target = Titanium_GetMasterRate();
        %orig((double)target);
        return;
    }
    %orig(rate);
}

- (double)maximumRefreshRate {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setMinimumRefreshRate:(double)rate {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        NSInteger target = Titanium_GetMasterRate();
        %orig((double)target);
        return;
    }
    %orig(rate);
}

- (double)minimumRefreshRate {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setIdealRefreshRate:(double)rate {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        NSInteger target = Titanium_GetMasterRate();
        %orig((double)target);
        return;
    }
    %orig(rate);
}

- (double)idealRefreshRate {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (BOOL)allowsVirtualModes { return YES; }
- (void)setAllowsVirtualModes:(BOOL)flag { %orig(YES); }
%end

// [BLOCK THERMAL DROP] IORegistry setCFProperty — chặn cứng
%hook IORegistryEntry
- (kern_return_t)setCFProperty:(NSString *)key withValue:(id)value {
    if (!key || !self) return %orig(key, value);
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        NSString *keyLower = [key lowercaseString];
        if ([keyLower containsString:@"power"] || [keyLower containsString:@"thermal"] ||
            [keyLower containsString:@"throttle"] || [keyLower containsString:@"budget"] ||
            [keyLower containsString:@"limit"] || [keyLower containsString:@"cap"] ||
            [keyLower containsString:@"max"] || [keyLower containsString:@"sustain"] ||
            [keyLower containsString:@"temperature"]) {
            return KERN_SUCCESS;
        }
    }
    return %orig(key, value);
}
%end

// [BLOCK THERMAL] NSProcessInfo / UIDevice — luôn báo mát
%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) return NSProcessInfoThermalStateNominal;
    return %orig;
}
- (BOOL)isLowPowerModeEnabled {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) return NO;
    return %orig;
}
%end

%hook UIDevice
- (float)batteryLevel {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) return 1.0f;
    return %orig;
}
- (UIDeviceBatteryState)batteryState {
    if (IS_ACTIVE || Apex_IsMasterEnabled()) return UIDeviceBatteryStateFull;
    return %orig;
}
%end

// [BƠM ĐIỆN] AGXAccelerator — ép max power state, không cho drop
%hook AGXAccelerator
- (int)setPowerState:(unsigned int)state {
    if (!self) return %orig(state);
    if (IS_ACTIVE || Apex_IsMasterEnabled()) {
        EnforceMaxCPUPower();
        %orig(1);
        return 1;
    }
    return %orig(state);
}
%end

%end

// ====================================================================================================
// HOOK: Deep Core Bypass — block thermal + power + throttle
// ====================================================================================================
%group Group_Hardware_Deep_Core_Bypass

%hook IORegistryEntry
- (kern_return_t)setCFProperty:(NSString *)key withValue:(id)value {
    if (!key || !self) return %orig(key, value);
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        NSString *keyLower = [key lowercaseString];
        if ([keyLower containsString:@"powerlimit"] || [keyLower containsString:@"thermal"] ||
            [keyLower containsString:@"throttle"] || [keyLower containsString:@"budget"] ||
            [keyLower containsString:@"maxpower"] || [keyLower containsString:@"sustainable"] ||
            [keyLower containsString:@"temperature"] || [keyLower containsString:@"limit"] ||
            [keyLower containsString:@"cap"] || [keyLower containsString:@"constraint"] ||
            [keyLower containsString:@"sensor"] || [keyLower containsString:@"current"]) {
            return KERN_SUCCESS;
        }
    }
    return %orig(key, value);
}

- (kern_return_t)setCFProperties:(NSDictionary *)properties {
    if (!properties || !self) return %orig(properties);
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        NSMutableDictionary *filtered = [properties mutableCopy];
        for (NSString *key in properties.allKeys) {
            NSString *keyLower = [key lowercaseString];
            if ([keyLower containsString:@"power"] || [keyLower containsString:@"thermal"] ||
                [keyLower containsString:@"throttle"] || [keyLower containsString:@"limit"] ||
                [keyLower containsString:@"sensor"]) {
                [filtered removeObjectForKey:key];
            }
        }
        return %orig(filtered);
    }
    return %orig(properties);
}
%end

%hook IOPMrootDomain
- (IOReturn)setAggressiveness:(unsigned long)type level:(unsigned long)level {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return %orig(type, 0);
    return %orig(type, level);
}
- (void)setSleepSupported:(BOOL)supported {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return;
    %orig(supported);
}
%end

%hook AGXAccelerator
- (int)setPowerState:(unsigned int)state {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        EnforceMaxCPUPower();
        state = 1;
    }
    return %orig(state);
}
- (void)setPerfState:(unsigned int)state {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(1);
        return;
    }
    %orig(state);
}
%end

%hook OSKernelTask
- (void)setQoS:(unsigned int)qos {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(33);
        return;
    }
    %orig(qos);
}
%end

%end

// ====================================================================================================
// [INSTALL C FUNCTION HOOKS] — gọi trong Titanium_LoadIOMFBDirect hoặc riêng
// ====================================================================================================

static void Titanium_InstallIOMFBCFunctionHook(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            void *lib = dlopen("/System/Library/PrivateFrameworks/IOMobileFramebuffer.framework/IOMobileFramebuffer", RTLD_LAZY);
            if (!lib) return;
            void *sym = dlsym(lib, "IOMobileFramebufferSetDisplayMode");
            if (sym) {
                MSHookFunction(sym, (void *)hooked_IOMobileFramebufferSetDisplayMode,
                               (void **)&orig_IOMobileFramebufferSetDisplayMode);
                Titanium_V60_Log(@"[HW] IOMobileFramebufferSetDisplayMode hook installed");
            }
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[HW] install IOMFB C hook throw: %@", e.reason]);
        }
    });
}

// ====================================================================================================
// HOOK: Cold Boot
// ====================================================================================================
%group Group_Apple_Native_ColdBoot_Overdrive

%hook UIScene
- (void)_activationCompleted {
    %orig;
    @try {
        if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted && Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            Titanium_V57_ReloadIPCIfStale();
            dispatch_async(dispatch_get_main_queue(), ^{ Titanium_ReapplyFrameRateToAllScenes(); });
        }
    } @catch (__unused NSException *e) {}
}
- (void)_didBecomeActive {
    %orig;
    @try {
        if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted && Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            Titanium_V57_ReloadIPCIfStale();
            Titanium_TriggerInstantTouchBurst();
            dispatch_async(dispatch_get_main_queue(), ^{ Titanium_ReapplyFrameRateToAllScenes(); });
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                Titanium_ExecuteRealPanelOverdrive();
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
            if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
                Titanium_EnforceThreadVIPPolicy();
                EnforceMaxCPUPower();
            }
        }
    });
}
%end

%end

// ====================================================================================================
// HOOK: KeepAppsAlive
// ====================================================================================================
%group Group_KeepAppsAlive_NoKill
%hook FBProcess
- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(id)description completion:(id)comp {
    @try {
        if (!self) { %orig(reason, report, description, comp); return; }
        NSString *desc = description ? [description lowercaseString] : @"";
        BOOL isUserKill = ([desc containsString:@"user"] || [desc containsString:@"terminate"] ||
                           [desc containsString:@"explicit"] || [desc containsString:@"switcher"] ||
                           [desc containsString:@"force"]);
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
            if (!isUserKill) {
                if (comp) { void (^cb)(id) = comp; cb(nil); }
                return;
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(reason, report, description, comp);
}
- (BOOL)isPendingExit { return %orig; }
%end
%end

// ====================================================================================================
// HOOK: V12 — BỐC PHYSICS (folder distortion fix). Chỉ giữ frameRateRange.
// ====================================================================================================
%group Group_TitaniumV12_SmoothExit_And_DisplayLink

%hook CASpringAnimation

// [ĐÃ XOÁ setStiffness/damping/setDamping/setInitialVelocity] — nguyên nhân folder méo.
// Chỉ giữ frameRateRange để animation chạy đúng target Hz.

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
            NSInteger target = Titanium_GetEffectiveFrameCap();
            if (target < 15) target = 15;
            range = Titanium_HardLockFRR(target);
        }
    }
    %orig(range);
}
- (CAFrameRateRange)preferredFrameRateRange {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || Apex_IsMasterEnabled()) && !g_isCurrentAppBlacklisted) {
            NSInteger target = Titanium_GetEffectiveFrameCap();
            if (target < 15) target = 15;
            return Titanium_HardLockFRR(target);
        }
    }
    return %orig;
}

%end
%end

// ====================================================================================================
// NHÓM 1: NETWORK — tầng C socket + session config, đéo đụng display
// ====================================================================================================
%group Group_AI_Stream_Optimization

%hook UITextView
- (void)didMoveToWindow {
    BOOL origDone = NO;
    @try {
        if (!self) { origDone = YES; %orig; return; }
        origDone = YES; %orig;
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
            self.window && Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
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
    } @catch (__unused NSException *e) { if (!origDone) %orig; }
}
%end

%hook UIKeyboardImpl
%end

%hook NSURLSessionConfiguration

+ (NSURLSessionConfiguration *)defaultSessionConfiguration {
    NSURLSessionConfiguration *cfg = %orig;
    @try {
        if (cfg && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            cfg.HTTPMaximumConnectionsPerHost = 16;   // 5G/WiFi 6 saturate
            cfg.HTTPShouldUsePipelining = NO;
            cfg.timeoutIntervalForRequest = 30.0;
            cfg.timeoutIntervalForResource = 90.0;

            if (@available(iOS 11.0, *)) cfg.waitsForConnectivity = YES;
            if (@available(iOS 13.0, *)) {
                cfg.allowsExpensiveNetworkAccess = YES;
                cfg.allowsConstrainedNetworkAccess = YES;
            }
            // [KVC GUARD] allowsUltraConstrainedNetworkAccess chỉ có runtime iOS 17+
            if ([cfg respondsToSelector:NSSelectorFromString(@"setAllowsUltraConstrainedNetworkAccess:")]) {
                @try { [cfg setValue:@YES forKey:@"allowsUltraConstrainedNetworkAccess"]; } @catch (__unused NSException *e) {}
            }
            if (@available(iOS 15.0, *)) {
                if ([cfg respondsToSelector:NSSelectorFromString(@"setAssumesHTTP3Capable:")]) {
                    @try { [cfg setValue:@YES forKey:@"assumesHTTP3Capable"]; } @catch (__unused NSException *e) {}
                }
            }
            // Service type — OS scheduler ưu tiên network thread
            if ([cfg respondsToSelector:NSSelectorFromString(@"setNetworkServiceType:")]) {
                @try { [cfg setValue:@(6) forKey:@"networkServiceType"]; } @catch (__unused NSException *e) {}
            }
            // Multipath TCP
            if ([cfg respondsToSelector:NSSelectorFromString(@"setMultipathServiceType:")]) {
                @try { [cfg setValue:@(1) forKey:@"multipathServiceType"]; } @catch (__unused NSException *e) {}
            }
        }
    } @catch (__unused NSException *e) {}
    return cfg;
}

+ (NSURLSessionConfiguration *)ephemeralSessionConfiguration {
    NSURLSessionConfiguration *cfg = %orig;
    @try {
        if (cfg && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            cfg.HTTPMaximumConnectionsPerHost = 16;
            cfg.HTTPShouldUsePipelining = NO;
            cfg.timeoutIntervalForRequest = 30.0;
            cfg.timeoutIntervalForResource = 90.0;

            if (@available(iOS 11.0, *)) cfg.waitsForConnectivity = YES;
            if (@available(iOS 13.0, *)) {
                cfg.allowsExpensiveNetworkAccess = YES;
                cfg.allowsConstrainedNetworkAccess = YES;
            }
            // [KVC GUARD] iOS 17+ only
            if ([cfg respondsToSelector:NSSelectorFromString(@"setAllowsUltraConstrainedNetworkAccess:")]) {
                @try { [cfg setValue:@YES forKey:@"allowsUltraConstrainedNetworkAccess"]; } @catch (__unused NSException *e) {}
            }
            if (@available(iOS 15.0, *)) {
                if ([cfg respondsToSelector:NSSelectorFromString(@"setAssumesHTTP3Capable:")]) {
                    @try { [cfg setValue:@YES forKey:@"assumesHTTP3Capable"]; } @catch (__unused NSException *e) {}
                }
            }
            if ([cfg respondsToSelector:NSSelectorFromString(@"setNetworkServiceType:")]) {
                @try { [cfg setValue:@(6) forKey:@"networkServiceType"]; } @catch (__unused NSException *e) {}
            }
            if ([cfg respondsToSelector:NSSelectorFromString(@"setMultipathServiceType:")]) {
                @try { [cfg setValue:@(1) forKey:@"multipathServiceType"]; } @catch (__unused NSException *e) {}
            }
        }
    } @catch (__unused NSException *e) {}
    return cfg;
}

%end

%hook NSURLSessionTask
- (void)setPriority:(float)priority {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) { %orig(1.0); return; }
    %orig(priority);
}
- (float)priority {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) return 1.0;
    return %orig;
}
%end

%hook NSMutableURLRequest
- (void)setNetworkServiceType:(NSURLRequestNetworkServiceType)type {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(NSURLNetworkServiceTypeResponsiveData);
        return;
    }
    %orig(type);
}
%end

%end

// ====================================================================================================
// NETWORK C-LAYER ENGINE — socket() + setsockopt() hook
// ====================================================================================================
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet/tcp.h>

static int (*orig_socket_fn)(int, int, int) = NULL;
static int hooked_socket_fn(int domain, int type, int protocol) {
    int fd = orig_socket_fn ? orig_socket_fn(domain, type, protocol) : -1;
    if (fd >= 0 && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        @try {
            int one = 1;
            // TCP_NODELAY — bốc Nagle, giảm 40ms/RTT
            setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof(one));

            // Buffer 1MB recv/send — giảm syscall, giữ packet kernel
            int bufSize = 1024 * 1024;
            setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &bufSize, sizeof(bufSize));
            setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &bufSize, sizeof(bufSize));

            // Keepalive
            setsockopt(fd, SOL_SOCKET, SO_KEEPALIVE, &one, sizeof(one));

            #ifdef TCP_FASTOPEN
            setsockopt(fd, IPPROTO_TCP, TCP_FASTOPEN, &one, sizeof(one));
            #endif
            #ifdef SO_NOSIGPIPE
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof(one));
            #endif
            #ifdef TCP_KEEPALIVE
            int keepIdle = 60;
            setsockopt(fd, IPPROTO_TCP, TCP_KEEPALIVE, &keepIdle, sizeof(keepIdle));
            #endif
        } @catch (__unused NSException *e) {}
    }
    return fd;
}

static int (*orig_setsockopt_fn)(int, int, int, const void*, socklen_t) = NULL;
static int hooked_setsockopt_fn(int fd, int level, int optname, const void *optval, socklen_t optlen) {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        @try {
            if (level == IPPROTO_TCP && optname == TCP_NODELAY) {
                int one = 1;
                return orig_setsockopt_fn ? orig_setsockopt_fn(fd, level, optname, &one, sizeof(one)) : -1;
            }
            if (level == SOL_SOCKET && (optname == SO_RCVBUF || optname == SO_SNDBUF)) {
                int sz = optval ? *(const int*)optval : 0;
                if (sz < 256 * 1024) {
                    int newSz = 1024 * 1024;
                    return orig_setsockopt_fn ? orig_setsockopt_fn(fd, level, optname, &newSz, sizeof(newSz)) : -1;
                }
            }
        } @catch (__unused NSException *e) {}
    }
    return orig_setsockopt_fn ? orig_setsockopt_fn(fd, level, optname, optval, optlen) : -1;
}

static void Titanium_InstallNetworkCHooks(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            void *socketSym = dlsym(RTLD_DEFAULT, "socket");
            if (socketSym) {
                MSHookFunction(socketSym, (void *)hooked_socket_fn, (void **)&orig_socket_fn);
                Titanium_V60_Log(@"[NET] socket hook installed");
            }
            void *setsockoptSym = dlsym(RTLD_DEFAULT, "setsockopt");
            if (setsockoptSym) {
                MSHookFunction(setsockoptSym, (void *)hooked_setsockopt_fn, (void **)&orig_setsockopt_fn);
                Titanium_V60_Log(@"[NET] setsockopt hook installed");
            }
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[NET] hook throw: %@", e.reason]);
        }
    });
}

// ====================================================================================================
// NHÓM 2: DEEP DRIVER — SAFE IOKIT, MasterRate single source
// ====================================================================================================

static void Tio_DCPResolveConnections_v2(void) {
    // Full scan cho iOS 15-18
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            const TitaniumIOKitSyms *s = Titanium_ResolveIOKitSyms();
            if (!s->getMatchingService || !s->serviceOpen) { g_dcpConnReady = NO; return; }
            const char *services[] = {
                "IOMobileFramebuffer", "IOMobileFramebufferAP",
                "AppleDCP", "AppleCLCD2", "AppleCLCD",
                "AppleDCPAVController", "AppleM2Scaler", "AppleM2ScalerUserClient"
            };
            int n = (int)(sizeof(services)/sizeof(services[0]));
            for (int i = 0; i < n; i++) {
                g_dcpIomfbSvc = s->getMatchingService(kIOMasterPortDefault, IOServiceMatching(services[i]));
                if (g_dcpIomfbSvc != IO_OBJECT_NULL) {
                    if (s->serviceOpen(g_dcpIomfbSvc, mach_task_self(), 0, &g_dcpIomfbConn) == KERN_SUCCESS) {
                        Titanium_V60_Log([NSString stringWithFormat:@"[DCP] v2 connected: %s", services[i]]);
                        break;
                    }
                }
            }
            g_dcpConnReady = (g_dcpIomfbConn != IO_OBJECT_NULL) || (g_dcpDispConn != IO_OBJECT_NULL);
        } @catch (__unused NSException *e) { g_dcpConnReady = NO; }
    });
}

// [FULL SELECTOR MATRIX] 14-21 mode, 22-29 gamma, 30-33 timing, 40-42 power
static kern_return_t Tio_IomfbRawSetMode(NSInteger hz) {
    if (g_isRebooting) return KERN_FAILURE;
    if (!Titanium_V55_PanelWritable()) return KERN_FAILURE;
    const TitaniumIOKitSyms *syms = Titanium_ResolveIOKitSyms();
    if (!syms->connectStructMethod) return KERN_FAILURE;

    Tio_DCPResolveConnections();
    if (g_dcpIomfbConn == IO_OBJECT_NULL) { Tio_DCPResolveConnections_v2(); }
    if (g_dcpIomfbConn == IO_OBJECT_NULL) return KERN_FAILURE;

    TioIomfbTiming timing;
    memset(&timing, 0, sizeof(timing));
    CGSize nb = [UIScreen mainScreen].nativeBounds.size;
    timing.width       = (uint32_t)nb.width;
    timing.height      = (uint32_t)nb.height;
    timing.refreshRate = (uint32_t)hz;
    timing.pixelClock  = (uint32_t)((nb.width + 64) * (nb.height + 32) * hz * 1.08);
    timing.hSyncStart  = 0;
    timing.hSyncEnd    = (uint32_t)nb.width;
    timing.vSyncStart  = 0;
    timing.vSyncEnd    = (uint32_t)nb.height;
    timing.flags       = 0xFFFFFFFF;

    g_v60ForceDriverSuccess = YES;
    uint32_t selectors[] = {
        14, 15, 16, 17, 18, 19, 20, 21,   // mode
        22, 23, 24, 25, 26, 27, 28, 29,   // gamma/LUT
        30, 31, 32, 33,                   // timing override
        40, 41, 42                        // power state
    };
    kern_return_t finalRet = KERN_FAILURE;
    int n = (int)(sizeof(selectors)/sizeof(selectors[0]));
    for (int i = 0; i < n; i++) {
        size_t outLen = 0;
        kern_return_t kr = syms->connectStructMethod(g_dcpIomfbConn, selectors[i], &timing, sizeof(timing), NULL, &outLen);
        if (kr == KERN_SUCCESS) finalRet = KERN_SUCCESS;
    }
    g_v60ForceDriverSuccess = NO;
    return finalRet;
}

static kern_return_t Tio_DisplayConnSetRefresh_v2(NSInteger hz) {
    return Tio_DisplayConnSetRefresh(hz);
}

static volatile NSInteger g_pushLastAppliedHz = 0;

// [PUSH RATE] — MasterRate, cooldown 1500ms, share g_lastHardwarePunchTick
static void Titanium_PushRateToDriverV4(NSInteger hz, BOOL force) {
    if (g_isRebooting) return;
    if (!Titanium_V55_PanelWritable()) return;
    if (hz < 15) hz = 15;
    if (hz > 240) hz = 240;
    if (!force && hz == g_pushLastAppliedHz) return;
    g_pushLastAppliedHz = hz;
    if (!Titanium_CanPunchHardware()) return;
    // Titanium_ForcePanelModeDirect sẽ tự MarkHardwarePunched — không double mark
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try { Titanium_ForcePanelModeDirect(hz); } @catch (__unused NSException *e) {}
    });
}
static void Titanium_PushRateToDriverV4(NSInteger hz) { Titanium_PushRateToDriverV4(hz, NO); }

// [ULTIMATE HACK] — full matrix selector
static void Titanium_ExecuteUltimateHardwareHack(NSInteger targetHz) {
    if (!Titanium_V55_PanelWritable()) return;
    if (targetHz < 15) targetHz = 15;
    if (targetHz > 240) targetHz = 240;
    if (!Titanium_CanPunchHardware()) return;
    Titanium_MarkHardwarePunched();

    const TitaniumIOKitSyms *syms = Titanium_ResolveIOKitSyms();
    if (!syms->connectStructMethod) return;

    Tio_DCPResolveConnections();
    if (g_dcpIomfbConn == IO_OBJECT_NULL) {
        Tio_DCPResolveConnections_v2();
    }
    if (g_dcpIomfbConn == IO_OBJECT_NULL) return;

    CGSize screenSize = [UIScreen mainScreen].nativeBounds.size;
    TioIomfbTiming timing;
    memset(&timing, 0, sizeof(timing));
    timing.width       = (uint32_t)screenSize.width;
    timing.height      = (uint32_t)screenSize.height;
    timing.refreshRate = (uint32_t)targetHz;
    timing.pixelClock  = (uint32_t)((screenSize.width + 64) * (screenSize.height + 32) * targetHz * 1.08);
    timing.hSyncEnd    = (uint32_t)screenSize.width;
    timing.vSyncEnd    = (uint32_t)screenSize.height;
    timing.flags       = 0xFFFFFFFF;

    g_v60ForceDriverSuccess = YES;
    uint32_t selectors[] = {
        14, 15, 16, 17, 18, 19, 20, 21,
        22, 23, 24, 25, 26, 27, 28, 29,
        30, 31, 32, 33,
        40, 41, 42
    };
    int n = (int)(sizeof(selectors)/sizeof(selectors[0]));
    for (int i = 0; i < n; i++) {
        size_t outLen = 0;
        (void)syms->connectStructMethod(g_dcpIomfbConn, selectors[i], &timing, sizeof(timing), NULL, &outLen);
    }
    g_v60ForceDriverSuccess = NO;
}

static void Titanium_Tier5C_RunSweepV4(void) {
    if (g_isRebooting) return;
    if (!Apex_IsMasterEnabled()) return;
    if (!Titanium_V55_PanelWritable()) return;
    NSInteger target = Titanium_GetMasterRate();
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @try {
            Tio_SubmitModeAllPaths(target);
            Titanium_HardwareDriverOverride(target);
            Titanium_Tier5WriteIORegistryTiming(target);
            Titanium_Tier4WriteCadence(target);
            Titanium_ExecuteUltimateHardwareHack(target);
            g_tioLastAcceptedHz = target;
            Titanium_V57_WriteSharedBestHz(target);
            Titanium_V60_Log([NSString stringWithFormat:@"[SWEEP] target=%ld readback=%ld",
                              (long)target, (long)Titanium_ReadDisplayPreferredFPS()]);
        } @catch (__unused NSException *e) {}
    });
}

// ====================================================================================================
// HOOK: CAWindowServer — LOCK FULL TRIPLET (min/ideal/max) + cadence + duration
// Ép hardware accept bằng mọi getter/setter ở tầng CAWindowServerDisplay
// ====================================================================================================
%group Group_CAWindowServer_Absolute_Dominance

%hook CADisplayController

- (void)displayLinkDidFire:(id)arg1 {
    // Bốc punch mỗi frame. Drift detector lo.
    %orig(arg1);
}

- (double)refreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        // Ép setter, refuse lower
        %orig((double)Titanium_GetMasterRate());
        return;
    }
    %orig(rate);
}

// [THÊM] Hook preferredFramesPerSecond — đây là đường OS dùng để hạ rate ngầm
- (NSInteger)preferredFramesPerSecond {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(Titanium_GetMasterRate());
        return;
    }
    %orig(fps);
}

%end

// [LOCK] CAWindowServerDisplay — full triplet + duration + cadence
%hook CAWindowServerDisplay

- (BOOL)allowsVirtualModes { return YES; }
- (void)setAllowsVirtualModes:(BOOL)flag { %orig(YES); }

// --- minimumFrameDuration ---
- (double)minimumFrameDuration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return 1.0 / (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setMinimumFrameDuration:(double)duration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(1.0 / (double)Titanium_GetMasterRate());
        return;
    }
    %orig(duration);
}

// [THÊM] frameDuration (không phải minimum) — OS dùng để set ideal cadence
- (double)frameDuration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return 1.0 / (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setFrameDuration:(double)duration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(1.0 / (double)Titanium_GetMasterRate());
        return;
    }
    %orig(duration);
}

// --- maximumRefreshRate ---
- (double)maximumRefreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setMaximumRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig((double)Titanium_GetMasterRate());
        return;
    }
    %orig(rate);
}

// --- minimumRefreshRate ---
- (double)minimumRefreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setMinimumRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig((double)Titanium_GetMasterRate());
        return;
    }
    %orig(rate);
}

// [THÊM] idealRefreshRate — OS gợi ý cadence, nếu không lock sẽ hạ về 60
- (double)idealRefreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (double)Titanium_GetMasterRate();
    }
    return %orig;
}

- (void)setIdealRefreshRate:(double)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig((double)Titanium_GetMasterRate());
        return;
    }
    %orig(rate);
}

%end

// [BỐC KVC LOOP] displayForScreen — không setValue:forKey: (trigger setter → loop)
%hook CAWindowServer

- (NSArray *)displays {
    return %orig;
}

- (id)displayForScreen:(id)screen {
    id disp = %orig(screen);
    // Setter đã bị hook ở CAWindowServerDisplay — bất kỳ ai gọi setter đều bị ép MasterRate.
    // Không KVC ở đây, tránh trigger setter qua KVC (có thể loop indirect).
    return disp;
}

%end

%end

// ====================================================================================================
// HOOK: UIWindowScene — CA lock 100ms, punch chỉ khi target đổi (share cooldown 1500ms)
// ====================================================================================================
%group Group_Window_Level_Overdrive

%hook UIWindowScene

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        @try {
            if (Titanium_DisplayRateOverrideReady() && self &&
                (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {

                NSInteger target = Titanium_GetMasterRate();
                range = SafeMakeFRR((double)target, (double)target, (double)target);

                // [PUNCH QUA PUSHRATE] — share cooldown với mọi call site
                static NSInteger s_lastHwAppliedHz = 0;
                if (target != s_lastHwAppliedHz) {
                    s_lastHwAppliedHz = target;
                    Titanium_PushRateToDriverV4(target);
                }
            }
        } @catch (__unused NSException *e) {}
    }
    %orig(*(CAFrameRateRange *)&range);
}

// [CA LOCK ONLY] _processUpdateWithFrameContext — không punch, drift detector lo
- (void)_processUpdateWithFrameContext:(id)context {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            if (g_isInteracting || g_isScrollingActive || g_isContinuousSwiping || g_activeAnimationCount > 0) {
                static uint64_t s_last = 0;
                uint64_t now = mach_absolute_time();
                if (s_last == 0 || (now - s_last) >= v55_ns(100ULL * 1000000ULL)) {
                    s_last = now;
                    Titanium_LockMainThreadFast();
                    // [CA LOCK ONLY] — nhẹ, không đấm kernel
                    Titanium_ReapplyFrameRateToAllScenes();
                }
            }
        }
    } @catch (__unused NSException *e) {}
    %orig(context);
}

%end

%end

// ====================================================================================================
// HOOK: V10 Layout
// ====================================================================================================
%group Group_TitaniumV10_SpringBoard_Layout_Boost

static inline void Titanium_V10_PinMainThreadHigh(void) {
    @try {
        if (![NSThread isMainThread]) return;
        if (!Titanium_V57_TouchReady() || Titanium_V56_KeyboardBusy()) return;
        static __thread uint64_t s_last = 0;
        uint64_t now = mach_absolute_time();
        if (s_last == 0 || (now - s_last) > Titanium_NanosToMachTicks(100ULL * 1000000ULL)) {
            s_last = now;
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
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            (g_isScrollingActive || g_isContinuousSwiping) && Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end
%hook SBFolderView
- (void)layoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            g_isScrollingActive && Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end
%hook SBMainDisplaySceneLayoutViewController
- (void)viewWillLayoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            Titanium_V10_PinMainThreadHigh();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end
%end

// ====================================================================================================
// HOOK: Switcher
// ====================================================================================================
%group Group_SpringBoard_Switcher_Opt
%hook _UIScreenEdgePanGestureRecognizer
- (BOOL)delaysTouchesBegan {
    if (!self) return %orig;
    if (Titanium_V56_KeyboardBusy()) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() && Titanium_V57_TouchReady()) return NO;
    return %orig;
}
- (double)_edgeRegionSize {
    if (!self) return %orig;
    double size = %orig;
    if (Titanium_V56_KeyboardBusy()) return size;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() && Titanium_V57_TouchReady()) {
        return (size > 0.0) ? (size * 1.25) : 25.0;
    }
    return size;
}
%end
%hook SBFluidSwitcherModifier
- (double)shadowOpacityForIndex:(unsigned long long)index {
    if (!self) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_V57_TouchReady()) return 0.0;
    return %orig;
}
%end
%end

// ====================================================================================================
// HOOK: Liquid Glass
// ====================================================================================================
%group Group_LiquidGlass_Opt
%hook UIVisualEffectView
- (void)setEffect:(UIVisualEffect *)effect {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) { %orig(nil); return; }
    %orig(effect);
}
- (void)layoutSubviews {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        CALayer *layer = self.layer;
        if (layer) layer.allowsGroupOpacity = YES;
    }
}
%end
%hook CABackdropLayer
- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) { %orig(YES); return; }
    %orig(flag);
}
- (BOOL)disablesOccludedBackdropBlurs {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) return YES;
    return %orig;
}
- (void)setScale:(CGFloat)scale {
    %orig(scale);
}
%end
%end

// ====================================================================================================
// Safari safety
// ====================================================================================================
static inline BOOL Titanium_ShouldApplyHardwareSpoof(void) {
    if (Titanium_IsSpringBoard() || Titanium_IsSettingsApp() ||
        Titanium_IsSpoofExcludedApp() || g_isCurrentAppBlacklisted) return NO;
    return YES;
}

%group Group_Safari_And_Animation_Safety
%hook _UIMorphingPlatterView
- (void)layoutSubviews {
    @try { if (!self || [(UIView *)self window] == nil) { %orig; return; } } @catch (__unused NSException *e) {}
    %orig;
}
%end
%hook _UIClickPresentationInteraction
- (void)_cancelWithReason:(NSInteger)reason alongsideActions:(id)alongsideActions completion:(id)completion {
    @try { if (!self) { %orig(reason, alongsideActions, completion); return; } } @catch (__unused NSException *e) {}
    %orig(reason, alongsideActions, completion);
}
%end
%end

// ====================================================================================================
// PHẦN B: constants
// ====================================================================================================
static inline BOOL Titanium_IsTargetProcess(void);

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
#define TIER6_KERNEL_MAX_IMPORTANCE 90
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

typedef int (*sandbox_check_fn)(pid_t pid, const char *operation, int type, ...);
static sandbox_check_fn orig_sandbox_check = NULL;

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

typedef struct {
    const char *machinePrefix;
    const char *modelName;
    uint32_t nativePanelMaxHz;
    uint32_t overdriveCeilingHz;
    uint32_t touchSampleRateHz;
} TitaniumPanelRegisterProfile;

static const TitaniumPanelRegisterProfile kTitaniumPanelProfiles[] = {
    {"iPhone8,",  "iPhone 6s / SE (A9)",      60,  75, 240},
    {"iPhone9,",  "iPhone 7 Series (A10)",    60,  75, 240},
    {"iPhone10,", "iPhone 8 / X (A11)",       60,  75, 240},
    {"iPhone11,", "iPhone XS / XR (A12)",     60,  75, 240},
    {"iPhone12,", "iPhone 11 / SE2 (A13)",    60,  75, 240},
    {"iPhone13,", "iPhone 12 Series (A14)",   60,  75, 240},
    {"iPhone14,2","iPhone 13 Pro (A15 LTPO)", 120, 120, 360},
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
                if (strncmp(sysInfo.machine, kTitaniumPanelProfiles[i].machinePrefix,
                            strlen(kTitaniumPanelProfiles[i].machinePrefix)) == 0) {
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

// Ép cưỡng bức: Luôn trả về YES để bypass Sandbox cho bất kỳ app nào Tweak nạp vào
static inline BOOL Titanium_IsTargetProcess(void) {
    // [VÁ LỖ HỔNG] Ép buộc mở khoá Sandbox cho toàn bộ tiến trình nếu tweak đang chạy
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return YES;
    }
    return NO;
}

static int hooked_sandbox_check(pid_t pid, const char *operation, int type, ...) {
    // Ép cưỡng bức: Nếu Tweak đang chạy, bỏ qua mọi kiểm tra Sandbox
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsTargetProcess()) {
        if (!operation ||
            strncmp(operation, "file-", 5) == 0 ||
            strncmp(operation, "mach-", 5) == 0 ||
            strncmp(operation, "ipc-", 4) == 0 ||
            strncmp(operation, "process-", 8) == 0 ||
            strncmp(operation, "sysctl-", 7) == 0 ||
            strncmp(operation, "iokit-", 6) == 0 ||
            strncmp(operation, "priv-", 5) == 0) {
            return 0; // Cho phép đọc/ghi mọi thứ
        }
    }
    return orig_sandbox_check ? orig_sandbox_check(pid, operation, type) : 0;
}

// ====================================================================================================
// [TIER 6 - UNLOCK SYSTEM FILE ACCESS - SAFE HOOK]
// sandbox_check là variadic — ellekit đôi khi trip nếu shim trên main queue
// lúc boot settle. Đẩy ra background + null-guard orig.
// ====================================================================================================

static void Titanium_Tier6_UnlockSystemFileAccessAndFilzaReadWrite(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            @try {
                void *sbLib = dlopen("/usr/lib/system/libsystem_sandbox.dylib",
                                     RTLD_LAZY | RTLD_LOCAL);
                if (!sbLib) sbLib = RTLD_DEFAULT;

                void *symSbCheck = dlsym(sbLib, "sandbox_check");
                if (!symSbCheck) {
                    Titanium_V60_Log(@"[V999] sandbox_check missing — hook skipped");
                    return;
                }
                if (orig_sandbox_check) return;   // đã hook rồi

                MSHookFunction(symSbCheck,
                               (void *)hooked_sandbox_check,
                               (void **)&orig_sandbox_check);

                if (!orig_sandbox_check) {
                    Titanium_V60_Log(@"[V999] MSHookFunction sandbox_check failed — orig NULL, hook disabled");
                } else {
                    Titanium_V60_Log(@"[V999] sandbox_check hook installed");
                }
            } @catch (NSException *e) {
                Titanium_V60_Log([NSString stringWithFormat:@"[V999] sandbox_check hook throw: %@", e.reason]);
            }
        });
    });
}

// ====================================================================================================
// [TIER 5 - QUARTZCORE 240HZ CEILING UNLOCK]
// Bọc @try, đảm bảo Tier4WriteCadence + driver push đều guarded.
// ====================================================================================================

static void Titanium_Tier5_UnlockQuartzCore240HzCeiling(void) {
    @try {
        Titanium_V57_ReloadIPCIfStale();
        NSInteger target = Titanium_GetUserTargetHz();

        if (target < 15) target = 15;
        if (target > 240) target = 240;

        Titanium_Tier4WriteCadence(target);

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @try {
                Titanium_ExecuteUltimateHardwareHack(target);
            } @catch (NSException *e) {
                Titanium_V60_Log([NSString stringWithFormat:@"[V999] Tier5 QC driver push throw: %@", e.reason]);
            }
        });
    } @catch (NSException *e) {
        Titanium_V60_Log([NSString stringWithFormat:@"[V999] Tier5 UnlockQuartzCore throw: %@", e.reason]);
    }
}

// ====================================================================================================
// [INSTALL DIRECT IOMFB C HOOKS]
// ====================================================================================================

static void Titanium_InstallDirectIOMobileFramebufferCHooks(void) {
    @try {
        Titanium_LoadIOMFBDirect();

        const TitaniumIOKitSyms *s = Titanium_ResolveIOKitSyms();
        if (!tio_iomfb_main && !tio_iomfb_setmode) {
            Titanium_V60_Log(@"[V999] IOMobileFramebuffer framework symbols missing — C hooks unavailable");
        }
        if (!s->connectStructMethod) {
            Titanium_V60_Log(@"[V999] IOConnectCallStructMethod missing — IOMFB direct call unavailable");
        }
    } @catch (NSException *e) {
        Titanium_V60_Log([NSString stringWithFormat:@"[V999] InstallIOMFBCHooks throw: %@", e.reason]);
    }
}

// ====================================================================================================
// [TIER 5 - FORCE HARDWARE PANEL & GPU 240HZ]
// ====================================================================================================

static void Titanium_Tier5_ForceHardwarePanelAndGPU240Hz(NSInteger targetHz, NSInteger targetFPS) {
    (void)targetFPS;
    @try {
        if (targetHz < 15) targetHz = 15;
        if (targetHz > 240) targetHz = 240;

        Titanium_OverdrivePipelineGo(targetHz);

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @try {
                Titanium_ExecuteUltimateHardwareHack(targetHz);
            } @catch (NSException *e) {
                Titanium_V60_Log([NSString stringWithFormat:@"[V999] Tier5 GPU/panel push throw: %@", e.reason]);
            }
        });
    } @catch (NSException *e) {
        Titanium_V60_Log([NSString stringWithFormat:@"[V999] Tier5 ForceHWPanel throw: %@", e.reason]);
    }
}

// ====================================================================================================
// [TIER 4 - EXECUTE HARDWARE PANEL OVERDRIVE]
// Delegate sang Titanium_ExecuteRealPanelOverdrive, wrapped.
// ====================================================================================================

static void Titanium_Tier4_ExecuteHardwarePanelOverdrive(void) {
    @try {
        Titanium_ExecuteRealPanelOverdrive();
    } @catch (NSException *e) {
        Titanium_V60_Log([NSString stringWithFormat:@"[V999] Tier4 PanelOverdrive throw: %@", e.reason]);
    }
}

// ====================================================================================================
// [KERNEL THREAD GOVERNOR - VÁ LỖ HỔNG]
// ====================================================================================================

static void Titanium_Tier6_PromoteThreadToKernelMax127(thread_act_t threadPort, NSInteger targetHz, BOOL isMainThread) {
    if (threadPort == MACH_PORT_NULL) return;
    if (targetHz < 15) targetHz = 15;
    if (targetHz > 240) targetHz = 240;

    thread_affinity_policy_data_t affinity = { .affinity_tag = 1 };
    thread_policy_set(threadPort, THREAD_AFFINITY_POLICY, (thread_policy_t)&affinity, THREAD_AFFINITY_POLICY_COUNT);

    thread_throttle_policy_data_t throttle = { .pset_limit = 0 };
    thread_policy_set(threadPort, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttle, 1);

    thread_precedence_policy_data_t precedence = { .importance = 63 }; // Max precedence
    thread_policy_set(threadPort, THREAD_PRECEDENCE_POLICY, (thread_policy_t)&precedence, THREAD_PRECEDENCE_POLICY_COUNT);

    if (isMainThread) {
        uint64_t frameNanos = 1000000000ULL / (uint64_t)targetHz;
        thread_time_constraint_policy_data_t tc;
        tc.period      = (uint32_t)Titanium_NanosToMachTicks(frameNanos);
        tc.computation = (uint32_t)Titanium_NanosToMachTicks(frameNanos * 0.75); // 75%
        tc.constraint  = (uint32_t)Titanium_NanosToMachTicks(frameNanos * 0.95); // 95%
        tc.preemptible = TRUE;
        thread_policy_set(threadPort, THREAD_TIME_CONSTRAINT_POLICY,
                          (thread_policy_t)&tc, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    }
}

static void Titanium_Tier5_PinAllThreadsToPCoreAndRealtime(void) {
    if (!Titanium_V57_TouchReady() || Titanium_V56_KeyboardBusy()) return;
    NSInteger targetHz = Titanium_ClampDisplayFrameRate(Titanium_GetEffectiveFrameCap());
    if (targetHz < 15) targetHz = 15;

    if ([NSThread isMainThread]) {
        mach_port_t mainThread = pthread_mach_thread_np(pthread_self());
        Titanium_Tier6_PromoteThreadToKernelMax127(mainThread, targetHz, YES);
    }

    thread_act_array_t threadList = NULL;
    mach_msg_type_number_t threadCount = 0;
    if (task_threads(mach_task_self(), &threadList, &threadCount) == KERN_SUCCESS && threadList) {
        mach_msg_type_number_t maxScan = (threadCount > 8) ? 8 : threadCount;
        for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
            if (i < maxScan) Titanium_Tier6_PromoteThreadToKernelMax127(threadList[i], targetHz, NO);
            mach_port_deallocate(mach_task_self(), threadList[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)threadList, threadCount * sizeof(thread_act_t));
    }
}

static void Titanium_Tier5_EnforceKernelJetsamAndPowerImmunity(void) {
    Titanium_Tier6JetsamImmunityReal();
}

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

            if (Titanium_IsSpringBoard() && Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
                setpriority(PRIO_PROCESS, 0, -10);
                setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
                setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
                Titanium_Tier5_PinAllThreadsToPCoreAndRealtime();
                NSInteger targetHz = Titanium_GetEffectiveFrameCap();
                Titanium_Tier5_ForceHardwarePanelAndGPU240Hz(targetHz, targetHz);
                Titanium_Tier4_ExecuteHardwarePanelOverdrive();
            }
        }
    });
}

// ====================================================================================================
// [GROUP: Tier5 Display] — BỐC PUNCH KHỎI LAYOUT, GIỮ PUNCH Ở FOLDER/ANIMATION START
// ====================================================================================================

%group Group_Tier5_DisplayIC_DynamicIsland_Dock_3DParticles

%hook NSFileManager
- (BOOL)isWritableFileAtPath:(NSString *)path {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && path) {
        if (Titanium_IsTargetProcess() && (
            [path hasPrefix:@"/var/"] || [path hasPrefix:@"/private/var/"] ||
            [path hasPrefix:@"/tmp/"] || [path hasPrefix:@"/Library/"])) {
            return YES;
        }
    }
    return %orig(path);
}
- (BOOL)isReadableFileAtPath:(NSString *)path {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && path && Titanium_IsTargetProcess()) return YES;
    return %orig(path);
}
- (BOOL)isDeletableFileAtPath:(NSString *)path {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && path && Titanium_IsTargetProcess()) return YES;
    return %orig(path);
}
%end

// [CADisplayProperties] — fires khi display property change (rare). Punch OK.
%hook CADisplayProperties
- (void)setOverscanAdjustment:(id)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
        Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
        Titanium_LockMainThreadFast();
        Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
    }
    %orig(arg1);
}
- (void)setConnectionSeed:(unsigned int)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
        Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
        Titanium_LockMainThreadFast();
        Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
    }
    %orig(arg1);
}
%end

// [Animation Settings] — getter, chỉ trả MasterRate, không punch
%hook BSAnimationSettings
- (float)frameInterval {
    if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
        !g_isCurrentAppBlacklisted && Titanium_V57_TouchReady()) {
        return (1.0f / (float)Titanium_GetMasterRate());
    }
    return %orig;
}
- (CAFrameRateRange)preferredFrameRateRange {
    if (@available(iOS 15.0, *)) {
        if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
            !g_isCurrentAppBlacklisted && Titanium_V57_TouchReady()) {
            return Titanium_HardLockFRR(Titanium_GetMasterRate());
        }
    }
    return %orig;
}
%end

%hook BSSpringAnimationSettings
- (float)frameInterval {
    if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
        !g_isCurrentAppBlacklisted && Titanium_V57_TouchReady()) {
        return (1.0f / (float)Titanium_GetMasterRate());
    }
    return %orig;
}
- (CAFrameRateRange)preferredFrameRateRange {
    if (@available(iOS 15.0, *)) {
        if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
            !g_isCurrentAppBlacklisted && Titanium_V57_TouchReady()) {
            return Titanium_HardLockFRR(Titanium_GetMasterRate());
        }
    }
    return %orig;
}
%end

// [UIViewPropertyAnimator] — animation start, punch 1 lần có cooldown
%hook UIViewPropertyAnimator
- (BOOL)isUserInteractionEnabled {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
        Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) return YES;
    return %orig;
}
- (BOOL)isInterruptible {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
        Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) return YES;
    return %orig;
}
- (BOOL)scrubsLinearly {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
        Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) return YES;
    return %orig;
}
- (void)startAnimation {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_LockMainThreadFast();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

// [_UIRoundedRectShadowView] — folder icon shadow layout, chỉ fix opacity, không punch
%hook _UIRoundedRectShadowView
- (void)layoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            self.layer.allowsGroupOpacity = YES;
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

// [_UIViewControllerTransitionContext] — 1 lần per transition, punch OK
%hook _UIViewControllerTransitionContext
- (void)completeTransition:(BOOL)didComplete {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            Titanium_EnableZeroLatencyPipeline();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
        }
    } @catch (__unused NSException *e) {}
    %orig(didComplete);
}
%end

// [SBSystemApertureViewController] — Dynamic Island (không có iPhone 8), CA lock only
%hook SBSystemApertureViewController
- (void)viewWillLayoutSubviews {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
- (void)viewDidLayoutSubviews {
    %orig;
}
%end

%hook SBSystemApertureController
- (void)viewWillLayoutSubviews {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

// [SBDockView] — DOCK fire LIÊN TỤC mỗi home screen redraw. Bốc punch, chỉ CA lock.
%hook SBDockView
- (void)layoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            self.layer.allowsGroupOpacity = YES;
            // [CA LOCK ONLY] — không punch, drift detector lo
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

// [SBFloatingDockViewController] — fire per layout. Bốc punch, chỉ CA lock.
%hook SBFloatingDockViewController
- (void)viewWillLayoutSubviews {
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            Titanium_ReapplyFrameRateToAllScenes();
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

// [SBFolderController] — folder open/close, punch 1 lần có cooldown
%hook SBFolderController
- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            g_isInteracting = YES;
            Titanium_TriggerInstantTouchBurst();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}
- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
        }
    } @catch (__unused NSException *e) {}
    %orig(animated, completion);
}
%end

// [SBIconController] — folder open alternate path, punch 1 lần
%hook SBIconController
- (void)openFolder:(id)folder animated:(BOOL)animated completion:(id)completion {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            uint64_t now = mach_absolute_time();
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
        }
    } @catch (__unused NSException *e) {}
    %orig(folder, animated, completion);
}
%end

// [MTKView] — 1 lần per view move, punch OK
%hook MTKView
- (void)didMoveToWindow {
    %orig;
    @try {
        if (self && Titanium_DisplayRateOverrideReady() &&
            (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
            Titanium_V57_TouchReady()) {
            Titanium_V57_ReloadIPCIfStale();
            self.preferredFramesPerSecond = Titanium_GetMasterRate();
            Titanium_PushRateToDriverV4(Titanium_GetMasterRate());
        }
    } @catch (__unused NSException *e) {}
}
- (NSInteger)preferredFramesPerSecond {
    if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetMasterRate();
    }
    return %orig;
}
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
        !g_isCurrentAppBlacklisted && Titanium_V57_TouchReady()) {
        Titanium_V57_ReloadIPCIfStale();
        %orig(Titanium_GetMasterRate());
        return;
    }
    %orig(fps);
}
%end

// [CAEmitterLayer] — không punch, chỉ opacity
%hook CAEmitterLayer
- (void)didChangeValueForKey:(NSString *)key {
    %orig(key);
    @try {
        if (self && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
            Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
            self.allowsGroupOpacity = YES;
        }
    } @catch (__unused NSException *e) {}
}
%end

// [SKView] — 1 lần per view move, punch OK
%hook SKView
- (void)didMoveToWindow {
    %orig;
    @try {
        if (self && Titanium_DisplayRateOverrideReady() &&
            (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
            Titanium_V57_TouchReady()) {
            Titanium_V57_ReloadIPCIfStale();
            [(id)self setPreferredFramesPerSecond: Titanium_GetMasterRate()];
            if ([self respondsToSelector:@selector(setIgnoresSiblingOrder:)]) {
                [(id)self setValue:@YES forKey:@"ignoresSiblingOrder"];
            }
        }
    } @catch (__unused NSException *e) {}
}
- (NSInteger)preferredFramesPerSecond {
    if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetMasterRate();
    }
    return %orig;
}
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (Titanium_DisplayRateOverrideReady() && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
        !g_isCurrentAppBlacklisted && Titanium_V57_TouchReady()) {
        Titanium_V57_ReloadIPCIfStale();
        %orig(Titanium_GetMasterRate());
        return;
    }
    %orig(fps);
}
%end

// [NSLayoutManager] — layout, không punch
%hook NSLayoutManager
- (BOOL)allowsNonContiguousLayout {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
        Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) return YES;
    return %orig;
}
- (void)setAllowsNonContiguousLayout:(BOOL)flag {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted &&
        Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
        %orig(YES);
        return;
    }
    %orig(flag);
}
%end

%end

// ====================================================================================================
// METAL SYNC — MasterRate, không punch mỗi setter
// ====================================================================================================

%group Group_V55_MetalSync

%hook CAMetalLayer

- (void)setPreferredFrameRateRange:(CAFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V57_TouchReady()) {
            NSInteger cap = Titanium_GetMasterRate();
            if (cap < 15) cap = 15;
            if (cap > 240) cap = 240;
            %orig(CAFrameRateRangeMake((float)cap, (float)cap, (float)cap));
            return;
        }
    }
    %orig(range);
}

- (CAFrameRateRange)preferredFrameRateRange {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V57_TouchReady()) {
            NSInteger cap = Titanium_GetMasterRate();
            if (cap < 15) cap = 15;
            if (cap > 240) cap = 240;
            return CAFrameRateRangeMake((float)cap, (float)cap, (float)cap);
        }
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V57_TouchReady()) {
        NSInteger cap = Titanium_GetMasterRate();
        if (cap < 15) cap = 15;
        if (cap > 240) cap = 240;
        %orig(cap);
        return;
    }
    %orig(fps);
}

- (NSInteger)preferredFramesPerSecond {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V57_TouchReady()) {
        NSInteger cap = Titanium_GetMasterRate();
        if (cap < 15) cap = 15;
        if (cap > 240) cap = 240;
        return cap;
    }
    return %orig;
}

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V57_TouchReady()) {
        %orig(NO);
        return;
    }
    %orig(enabled);
}

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V57_TouchReady()) {
        %orig(3);
        return;
    }
    %orig(count);
}

- (void)setLowLatencyMode:(BOOL)mode {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V57_TouchReady()) {
        %orig(YES);
        return;
    }
    %orig(mode);
}

- (void)setPresentsWithTransaction:(BOOL)flag {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V57_TouchReady()) {
        %orig(YES);
        return;
    }
    %orig(flag);
}

- (void)setAllowsNextDrawableTimeout:(BOOL)allow {
    if ((IS_ACTIVE || Apex_IsMasterEnabled()) && Titanium_V57_TouchReady()) {
        %orig(YES);
        return;
    }
    %orig(allow);
}
%end

%end

// ====================================================================================================
// [BẺ THẲNG DAEMON] CHẶN LAUNCHD KHỞI CHẠY THEO CÔNG TẮC UI — 3 MÔI TRƯỜNG
// Rootful (Taurine/unc0ver/checkra1n ≤14) | Rootless (Dopamine 15+) | RootHide (Dopamine + RH)
// Hook: posix_spawn, posix_spawnp, execve, execvp
// ====================================================================================================
#include <spawn.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>

// [MULTI-PATH PREFS LOADER] — thử cả 3 môi trường, cache kết quả
static NSString *Titanium_ResolveDaemonPrefPath_All3(void) {
    static NSString *s_cachedPath = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *fileName = @"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
        NSString *rootPath = Titanium_GetRootHidePrefixPath();

        NSMutableArray<NSString *> *candidates = [NSMutableArray array];

        // RootHide — randomized root (vd /var/jbproj-XXX)
        if (rootPath && ![rootPath isEqualToString:@"/"] && ![rootPath isEqualToString:@"/var/jb"]) {
            [candidates addObject:[rootPath stringByAppendingPathComponent:fileName]];
        }

        // Rootless — /var/jb
        [candidates addObject:[@"/var/jb" stringByAppendingPathComponent:fileName]];

        // Rootful — no prefix
        [candidates addObject:[@"/" stringByAppendingPathComponent:fileName]];

        // Fallback direct
        [candidates addObject:@"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        [candidates addObject:@"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];

        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *p in candidates) {
            if ([fm fileExistsAtPath:p]) {
                s_cachedPath = p;
                Titanium_V60_Log([NSString stringWithFormat:@"[DAEMON] pref path: %@", p]);
                return;
            }
        }

        s_cachedPath = candidates.firstObject ?: @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
        Titanium_V60_Log([NSString stringWithFormat:@"[DAEMON] pref path (none exist, using): %@", s_cachedPath]);
    });
    return s_cachedPath;
}

// [PREFS CACHE] — load 1 lần / 5s, tránh spam I/O mỗi posix_spawn
static NSDictionary *Titanium_LoadDaemonPrefs_Cached(void) {
    static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    static NSDictionary *s_cachedPrefs = nil;
    static uint64_t s_lastLoadTick = 0;

    os_unfair_lock_lock(&lock);
    uint64_t now = mach_absolute_time();
    if (s_lastLoadTick == 0 || (now - s_lastLoadTick) >= Titanium_NanosToMachTicks(5ULL * 1000000000ULL)) {
        s_lastLoadTick = now;
        NSString *path = Titanium_ResolveDaemonPrefPath_All3();
        s_cachedPrefs = path ? [NSDictionary dictionaryWithContentsOfFile:path] : nil;
    }
    NSDictionary *result = s_cachedPrefs;
    os_unfair_lock_unlock(&lock);
    return result;
}

// [WHITELIST] — process KHÔNG BAO GIỜ bị chặn, bất chấp tắt daemon
static BOOL Titanium_IsCriticalProcess(const char *path) {
    if (!path || !path[0]) return YES; // empty → allow, tránh hỏng API

    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;

    static const char *whitelist[] = {
        // Core OS
        "launchd", "SpringBoard", "backboardd", "sbreload",
        "runningboardd", "watchdogd", "kernelmanagerd",
        "configd", "notifyd", "securityd", "syslogd", "logd", "logd.old",
        // Jailbreak core
        "jailbreakd", "dopamine", "ellekit", "systemhook",
        "dopamined", "bootstrapd", "tweakinjectd", "rootlesshooks",
        "libhooker", "substitute", "substrated", "libsubstrate",
        // Shell / SSH / SCP
        "bash", "sh", "zsh", "dash", "ssh", "sshd", "scp", "sftp", "rsync",
        // Package managers (Sileo, Zebra, APT)
        "dpkg", "apt", "apt-get", "apt-key", "sileo", "zbra", "zebra",
        "filza", "filzajailed", "filza.sh",
        // Prefs / basic
        "cfprefsd", "mobilesafetymonitord", "mobileactivationd",
        // Backup / sharing — cần cho USB transfer
        "companiond", "sharingd", "afcd", "lockdownd",
        // UIKit critical
        "assistivetouchd.helper", "AccessibilityUIServer",
        NULL
    };

    for (int i = 0; whitelist[i]; i++) {
        if (strcasecmp(base, whitelist[i]) == 0) return YES;
    }
    return NO;
}

// [DAEMON BLOCK CHECK] — basename + absolute, 3 env, cached prefs
static BOOL Titanium_IsDaemonDisabled_All3(const char *path) {
    if (!path || !path[0]) return NO;
    if (Titanium_IsCriticalProcess(path)) return NO;

    NSDictionary *dict = Titanium_LoadDaemonPrefs_Cached();
    if (!dict || dict.count == 0) return NO;

    BOOL (^isOff)(NSString *) = ^BOOL(NSString *key) {
        if (dict[key] != nil) return ![dict[key] boolValue];
        return NO;
    };

    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    NSString *baseStr = [NSString stringWithUTF8String:base] ?: @"";

    #define DAEMON_MATCH(pname, uikey) \
        if ((strstr(path, pname) != NULL || \
             [baseStr caseInsensitiveCompare:@(pname)] == NSOrderedSame) && \
            isOff(@uikey)) return YES;

    // Print / system
    DAEMON_MATCH("airprintd", "DaemonAirPrint")
    DAEMON_MATCH("backupd", "DaemonBackup")
    DAEMON_MATCH("assistivetouchd", "DaemonAssistiveTouch")
    DAEMON_MATCH("gamecenterd", "DaemonGameCenter")
    // OTA / asset
    DAEMON_MATCH("softwareupdated", "DaemonOTA")
    DAEMON_MATCH("mobileassetd", "DaemonOTA")
    DAEMON_MATCH("SUHelper", "DaemonOTA")
    // Log / crash
    DAEMON_MATCH("ReportCrash", "DaemonLog")
    DAEMON_MATCH("logd", "DaemonLog")
    DAEMON_MATCH("osanalyticsd", "DaemonLog")
    DAEMON_MATCH("diagnosticd", "DaemonLog")
    DAEMON_MATCH("sysdiagnosed", "DaemonLog")
    DAEMON_MATCH("tailspind", "DaemonLog")
    // Accessories / peripherals
    DAEMON_MATCH("accessoryd", "DaemonAccessory")
    DAEMON_MATCH("diskmanage", "DaemonDataWipe")
    // Health / HomeKit
    DAEMON_MATCH("healthd", "DaemonHealthKit")
    DAEMON_MATCH("homekitd", "DaemonHomeKit")
    // iCloud
    DAEMON_MATCH("cloudd", "DaemoniCloud")
    DAEMON_MATCH("akd", "DaemoniCloud")
    DAEMON_MATCH("bird", "DaemoniCloud")
    DAEMON_MATCH("ckdiscretionaryd", "DaemoniCloud")
    // Tethering / hotspot
    DAEMON_MATCH("tetherd", "DaemonTethering")
    DAEMON_MATCH("CommCenter", "DaemonTethering")
    // Wallet
    DAEMON_MATCH("passd", "DaemonPassBook")
    DAEMON_MATCH("Passbook", "DaemonPassBook")
    // Spotlight index
    DAEMON_MATCH("Spotlight", "DaemonSpotlight")
    DAEMON_MATCH("mds", "DaemonSpotlight")
    DAEMON_MATCH("mds_stores", "DaemonSpotlight")
    DAEMON_MATCH("corespotlightd", "DaemonSpotlight")
    // Voice / Siri
    DAEMON_MATCH("VoiceControl", "DaemonVoiceControl")
    DAEMON_MATCH("AssistantServices", "DaemonSiri")
    DAEMON_MATCH("siriactionsd", "DaemonSiri")
    DAEMON_MATCH("SiriNCService", "DaemonSiri")
    // VPN / network extension
    DAEMON_MATCH("vpnagentd", "DaemonVPN")
    DAEMON_MATCH("NEAgent", "DaemonVPN")
    DAEMON_MATCH("nehelper", "DaemonVPN")
    // Photos analysis
    DAEMON_MATCH("photosanalysisd", "DaemonPhotosAnalysis")
    DAEMON_MATCH("mediaanalysisd", "DaemonPhotosAnalysis")

    #undef DAEMON_MATCH
    return NO;
}

// [LOG] — ghi mọi block, lock để đéo race
static void Titanium_LogDaemonBlocked(const char *path) {
    if (!path) return;
    static os_unfair_lock logLock = OS_UNFAIR_LOCK_INIT;
    os_unfair_lock_lock(&logLock);
    const char *base = strrchr(path, '/');
    base = base ? base + 1 : path;
    Titanium_V60_Log([NSString stringWithFormat:@"[DAEMON] BLOCKED: %s | %s", base, path]);
    os_unfair_lock_unlock(&logLock);
}

// ====================================================================================================
// HOOKS — 4 entry point spawn/exec
// ====================================================================================================

// --- posix_spawn ---
static int (*orig_posix_spawn)(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char *const[], char *const[]);
static int hooked_posix_spawn(pid_t *pid, const char *path,
                              const posix_spawn_file_actions_t *fa,
                              const posix_spawnattr_t *attrp,
                              char *const argv[], char *const envp[]) {
    if (Titanium_IsCriticalProcess(path)) {
        return orig_posix_spawn(pid, path, fa, attrp, argv, envp);
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsDaemonDisabled_All3(path)) {
        Titanium_LogDaemonBlocked(path);
        if (pid) *pid = -1;
        errno = EPERM;
        return EPERM;
    }
    return orig_posix_spawn(pid, path, fa, attrp, argv, envp);
}

// --- posix_spawnp (PATH lookup) ---
static int (*orig_posix_spawnp)(pid_t *, const char *, const posix_spawn_file_actions_t *, const posix_spawnattr_t *, char *const[], char *const[]);
static int hooked_posix_spawnp(pid_t *pid, const char *path,
                               const posix_spawn_file_actions_t *fa,
                               const posix_spawnattr_t *attrp,
                               char *const argv[], char *const envp[]) {
    if (Titanium_IsCriticalProcess(path)) {
        return orig_posix_spawnp(pid, path, fa, attrp, argv, envp);
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsDaemonDisabled_All3(path)) {
        Titanium_LogDaemonBlocked(path);
        if (pid) *pid = -1;
        errno = EPERM;
        return EPERM;
    }
    return orig_posix_spawnp(pid, path, fa, attrp, argv, envp);
}

// --- execve ---
static int (*orig_execve)(const char *, char *const[], char *const[]);
static int hooked_execve(const char *path, char *const argv[], char *const envp[]) {
    if (Titanium_IsCriticalProcess(path)) return orig_execve(path, argv, envp);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsDaemonDisabled_All3(path)) {
        Titanium_LogDaemonBlocked(path);
        errno = EPERM;
        return -1;
    }
    return orig_execve(path, argv, envp);
}

// --- execvp ---
static int (*orig_execvp)(const char *, char *const[]);
static int hooked_execvp(const char *path, char *const argv[]) {
    if (Titanium_IsCriticalProcess(path)) return orig_execvp(path, argv);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsDaemonDisabled_All3(path)) {
        Titanium_LogDaemonBlocked(path);
        errno = EPERM;
        return -1;
    }
    return orig_execvp(path, argv);
}

// [INSTALL] — gọi trong %ctor hoặc DeepHardwareCoreInit
static void Titanium_InstallDaemonKillerHooks(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            void *sp = dlsym(RTLD_DEFAULT, "posix_spawn");
            if (sp) MSHookFunction(sp, (void *)hooked_posix_spawn, (void **)&orig_posix_spawn);

            void *spp = dlsym(RTLD_DEFAULT, "posix_spawnp");
            if (spp) MSHookFunction(spp, (void *)hooked_posix_spawnp, (void **)&orig_posix_spawnp);

            void *ev = dlsym(RTLD_DEFAULT, "execve");
            if (ev) MSHookFunction(ev, (void *)hooked_execve, (void **)&orig_execve);

            void *evp = dlsym(RTLD_DEFAULT, "execvp");
            if (evp) MSHookFunction(evp, (void *)hooked_execvp, (void **)&orig_execvp);

            Titanium_V60_Log(@"[DAEMON] hooks installed: posix_spawn, posix_spawnp, execve, execvp");
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[DAEMON] install hooks throw: %@", e.reason]);
        }
    });
}

%group Group_DaemonKiller
%end

// ====================================================================================================
// [PHẦN C: INIT - V108 FIX SREBOOT HANG + RAM ENGINE INTEGRATION]
// ====================================================================================================

// RAM engine forward decls
extern void Titanium_ForceJetsamUnlimited(void);
extern void Titanium_WireGlobalPayloadsToChip(void);
extern void Titanium_PurgePurgableMemory(void);
extern uint64_t Titanium_GetCurrentRSS(void);
extern uint64_t Titanium_GetDeviceTotalRAM(void);
extern uint64_t Titanium_GetRAMCeiling(void);
extern BOOL Titanium_ShouldPurgeNow(void);

static void Titanium_StartIPCHearthbeatV12(void) {
    @try {
        if (!Titanium_IsSpringBoard()) return;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            dispatch_source_t hb = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
            dispatch_source_set_timer(hb,
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)),
                (uint64_t)(30 * NSEC_PER_SEC),
                (uint64_t)(5 * NSEC_PER_SEC));
            dispatch_source_set_event_handler(hb, ^{
                if (g_isRebooting) return;
                @try {
                    Titanium_ReloadSharedSyncStateV285();

                    if (Titanium_ShouldPurgeNow()) {
                        Titanium_PurgePurgableMemory();
                        malloc_zone_pressure_relief(malloc_default_zone(), 0);
                    }

                    static uint32_t s_wireTick = 0;
                    s_wireTick++;
                    if (s_wireTick % 10 == 0) {
                        Titanium_WireGlobalPayloadsToChip();
                    }
                } @catch (NSException *e) {
                    Titanium_V60_Log([NSString stringWithFormat:@"[V999] IPC heartbeat throw: %@", e.reason]);
                }
            });
            dispatch_resume(hb);
        });
    } @catch (NSException *e) {
        Titanium_V60_Log([NSString stringWithFormat:@"[V999] StartIPCHearthbeat throw: %@", e.reason]);
    }
}

static void Titanium_V57_StartAppReapplyTimer(void) {
    if (Titanium_IsSpringBoard()) return;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dispatch_source_t t = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0,
                                                     dispatch_get_main_queue());

        dispatch_source_set_timer(t,
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)),
            (uint64_t)(0.25 * NSEC_PER_SEC),
            (uint64_t)(10 * NSEC_PER_MSEC));

        dispatch_source_set_event_handler(t, ^{
            if (g_isRebooting) return;
            @try {
                if (!Titanium_V57_TouchReady()) return;
                Titanium_V57_ReloadIPCIfStale();

                NSInteger targetHz = Titanium_GetUserTargetHz();
                if (targetHz < 15)  targetHz = 15;
                if (targetHz > 240) targetHz = 240;

                Titanium_PushRateToDriverV4(targetHz, YES);
                Titanium_ReapplyFrameRateToAllScenes();

                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    @try {
                        Titanium_ExecuteUltimateHardwareHack(targetHz);
                    } @catch (NSException *e) {
                        Titanium_V60_Log([NSString stringWithFormat:@"[V999] reapply HW push throw: %@", e.reason]);
                    }
                });

                static uint32_t s_purgeTick = 0;
                s_purgeTick++;
                if (s_purgeTick % 16 == 0) {
                    if (Titanium_ShouldPurgeNow()) {
                        Titanium_PurgePurgableMemory();
                        malloc_zone_pressure_relief(malloc_default_zone(), 0);
                    }
                }
            } @catch (NSException *e) {
                Titanium_V60_Log([NSString stringWithFormat:@"[V999] reapply timer tick throw: %@", e.reason]);
            }
        });
        dispatch_resume(t);
    });
}

static void Titanium_RegisterAppResumeRefreshV12(void) {
    @try {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification * __unused note) {
                if (g_isRebooting) return;
                @try {
                    g_lastSyncTicksV285 = 0;
                    g_v57LastIPCReload = 0;
                    Titanium_ReloadSharedSyncStateV285();
                    if (CFG285) {
                        CFG285.enabled    = (g_syncPayloadV285.masterEnabled != 0);
                        CFG285.targetHz   = g_cachedResolvedHz;
                        CFG285.targetFPS  = g_cachedResolvedFPS;
                    }
                    if (Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
                        Titanium_ReapplyFrameRateToAllScenes();
                    }
                    Titanium_ForceJetsamUnlimited();
                    Titanium_WireGlobalPayloadsToChip();
                } @catch (NSException *e) {
                    Titanium_V60_Log([NSString stringWithFormat:@"[V999] resume refresh throw: %@", e.reason]);
                }
            }];

            if (@available(iOS 9.0, *)) {
                [[NSNotificationCenter defaultCenter] addObserverForName:NSProcessInfoPowerStateDidChangeNotification
                    object:nil queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification * __unused note) {
                    if (g_isRebooting) return;
                    @try {
                        if (Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
                            Titanium_ReapplyFrameRateToAllScenes();
                        }
                    } @catch (NSException *e) {
                        Titanium_V60_Log([NSString stringWithFormat:@"[V999] power state throw: %@", e.reason]);
                    }
                }];
            }
        });
    } @catch (NSException *e) {
        Titanium_V60_Log([NSString stringWithFormat:@"[V999] RegisterAppResumeRefresh throw: %@", e.reason]);
    }
}

static void Titanium_StartThermalAndChargingWatchdog(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            UIDevice *dev = [UIDevice currentDevice];
            dev.batteryMonitoringEnabled = YES;
            g_isDeviceChargingV285 = (dev.batteryState == UIDeviceBatteryStateCharging ||
                                      dev.batteryState == UIDeviceBatteryStateFull);

            [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification
                object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification * __unused note) {
                if (g_isRebooting) return;
                @try {
                    UIDevice *d = [UIDevice currentDevice];
                    g_isDeviceChargingV285 = (d.batteryState == UIDeviceBatteryStateCharging ||
                                              d.batteryState == UIDeviceBatteryStateFull);
                    Titanium_UpdateLowBatteryFlagV12();
                } @catch (NSException *e) {
                    Titanium_V60_Log([NSString stringWithFormat:@"[V999] battery state throw: %@", e.reason]);
                }
            }];

            g_batteryLevelV12 = dev.batteryLevel;
            Titanium_UpdateLowBatteryFlagV12();

            [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryLevelDidChangeNotification
                object:nil queue:[NSOperationQueue mainQueue]
                usingBlock:^(NSNotification * __unused note) {
                if (g_isRebooting) return;
                @try {
                    g_batteryLevelV12 = [UIDevice currentDevice].batteryLevel;
                    Titanium_UpdateLowBatteryFlagV12();
                } @catch (NSException *e) {
                    Titanium_V60_Log([NSString stringWithFormat:@"[V999] battery level throw: %@", e.reason]);
                }
            }];
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[V999] ThermalWatchdog throw: %@", e.reason]);
        }
    });
}

__attribute__((constructor)) static void Titanium_DeepHardwareCoreInit(void) {
    @autoreleasepool {
        @try {
            g_v57AppLaunchTick = mach_absolute_time();

            // [FIX] BỐC ForceJetsamUnlimited khỏi constructor — chuyển sang %ctor.
            // Lý do: constructor chạy trước bootloop check armed → crash 20 lần.

            Titanium_V55_InstallScreenState();
            Titanium_V56_InstallKeyboardState();
            Titanium_LoadIOMFBDirect();
            Titanium_StartIPCHearthbeatV12();
            Titanium_RegisterAppResumeRefreshV12();
            Titanium_V57_StartAppReapplyTimer();
            Titanium_StartThermalAndChargingWatchdog();

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)),
                           dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                @try {
                    Titanium_WireGlobalPayloadsToChip();
                } @catch (__unused NSException *e) {}
            });
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[V999] DeepHardwareCoreInit throw: %@", e.reason]);
        }
    }
}

void Titanium_TriggerRespringAction(void) {
    g_isRebooting = YES;
    UIImpactFeedbackGenerator *fb = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
    [fb impactOccurred];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(700 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        @try {
            pid_t pid = 0;
            const char *argsJB[]     = {"sbreload", NULL};
            const char *argsSystem[] = {"sbreload", NULL};
            int result = posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL,
                                     (char *const *)argsJB, environ);
            if (result != 0) {
                posix_spawn(&pid, "/usr/bin/sbreload", NULL, NULL,
                            (char *const *)argsSystem, environ);
            }
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[V999] TriggerRespring throw: %@", e.reason]);
        }
    });
}

#define TITANIUM_SREBOOT_MARKER     @"/tmp/.titanium_sreboot_marker"
#define TITANIUM_SREBOOT_WINDOW     180.0

static BOOL Titanium_ShouldDelayLoadAfterSreboot(void) {
    @try {
        NSDictionary *marker = [NSDictionary dictionaryWithContentsOfFile:TITANIUM_SREBOOT_MARKER];
        NSNumber *t = marker[@"time"];
        if ([t isKindOfClass:[NSNumber class]]) {
            NSTimeInterval age = [[NSDate date] timeIntervalSince1970] - [t doubleValue];
            if (age >= 0.0 && age < TITANIUM_SREBOOT_WINDOW) return YES;
        }
    } @catch (__unused NSException *e) {}
    return NO;
}

void Titanium_TriggerSrebootAction(void) {
    g_isRebooting = YES;
    NSDictionary *marker = @{@"time": @([[NSDate date] timeIntervalSince1970])};
    if (![marker writeToFile:TITANIUM_SREBOOT_MARKER atomically:YES]) return;
    UINotificationFeedbackGenerator *fb = [[UINotificationFeedbackGenerator alloc] init];
    [fb notificationOccurred:UINotificationFeedbackTypeWarning];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1200 * NSEC_PER_MSEC)),
                   dispatch_get_main_queue(), ^{
        @try {
            pid_t pid = 0;
            const char *args[] = {"launchctl", "reboot", "userspace", NULL};
            int spawnResult = posix_spawn(&pid, "/bin/launchctl", NULL, NULL,
                                          (char *const *)args, environ);
            if (spawnResult != 0) {
                [[NSFileManager defaultManager] removeItemAtPath:TITANIUM_SREBOOT_MARKER error:nil];
            }
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[V999] TriggerSreboot throw: %@", e.reason]);
        }
    });
}

static void Titanium_InstallMGCopyAnswerHookV26(void) {}

static void Titanium_RegisterPrefsObservers(BOOL isSpringBoardProcess) {
    (void)isSpringBoardProcess;
    static BOOL s_obsDone = NO;
    if (s_obsDone) return;
    s_obsDone = YES;
    CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
    if (!darwinCenter) return;
    NSArray<NSString *> *notifications = @[
        @NOTIFY_RELOAD, @NOTIFY_UIKIT_RELOAD, @NOTIFY_HARDWARE_SYNC,
        @NOTIFY_FPS_CHANGED, @NOTIFY_TITANIUM_CHANGED, @NOTIFY_PAYLOAD_WRITTEN,
        @"com.titanium.reload", @"com.titanium.uikit.reload",
        @"com.titanium.hardwaresync", @"com.titanium.fpschanged",
        @"com.titanium.changed", @"com.titanium.payloadwritten"
    ];
    for (NSString *name in notifications) {
        CFNotificationCenterAddObserver(darwinCenter, NULL,
            (CFNotificationCallback)ReloadPreferencesCallbackV285,
            (__bridge CFStringRef)name, NULL,
            CFNotificationSuspensionBehaviorDeliverImmediately);
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
    } @catch (NSException *e) {
        Titanium_V60_Log([NSString stringWithFormat:@"[V999] RestoreFirstDraw throw: %@", e.reason]);
    }
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
    if (!Titanium_IsUIProcess()) return;
    static BOOL s_waitingForFirstFrame = NO;
    if (s_waitingForFirstFrame) return;
    s_waitingForFirstFrame = YES;

    TitaniumFirstFrameTarget *target = [TitaniumFirstFrameTarget new];
    __weak TitaniumFirstFrameTarget *weakTarget = target;
    __block NSUInteger visibleTicks = 0;

    target.handler = ^(CADisplayLink *link) {
        if (g_isRebooting) return;
        @try {
            UIApplication *app = [UIApplication sharedApplication];
            BOOL hasVisibleWindow = NO;
            for (UIScene *scene in app.connectedScenes) {
                if (![scene isKindOfClass:[UIWindowScene class]] ||
                    scene.activationState != UISceneActivationStateForegroundActive) continue;
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
                g_v55FirstFrame = YES;
                Titanium_KillVSyncCompletelyAtRoot();
                AppleInternal_LockHardwareCADisplay();
                Titanium_ApplySiliconDeepOptimizations();
                Titanium_ExecuteRealPanelOverdrive();

                Titanium_ForceJetsamUnlimited();
                Titanium_WireGlobalPayloadsToChip();

                [link invalidate];
                weakTarget.handler = nil;
                Titanium_ReapplyFrameRateToVisibleMetalLayers();
                Titanium_ReapplyFrameRateToAllScenes();
            }
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[V999] firstFrame handler throw: %@", e.reason]);
        }
    };

    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:target selector:@selector(tick:)];
    NSInteger cap = Titanium_GetEffectiveFrameCap();
    if (cap < 15) cap = 15;
    if (cap > 240) cap = 240;
    displayLink.preferredFramesPerSecond = cap;
    [displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    (void)bundleID; (void)progName;
    static BOOL s_coreInitDone = NO;
    if (s_coreInitDone) return;
    s_coreInitDone = YES;

    if (g_isRebooting) return;

    @autoreleasepool {
        @try {
            Titanium_BypassQuartzCoreRangeAssertion();

            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
            }

            g_lastSyncTicksV285 = 0;
            g_v57LastIPCReload = 0;
            Titanium_ReloadSharedSyncStateV285();
            if (CFG285) {
                CFG285.enabled   = (g_syncPayloadV285.masterEnabled != 0);
                CFG285.targetHz  = g_cachedResolvedHz;
                CFG285.targetFPS = g_cachedResolvedFPS;
            }

            if (g_isCurrentAppBlacklisted) return;
            if (!isSpringBoard) Titanium_RegisterUIScreenRateSpoofAfterLaunch();

            Titanium_KillVSyncCompletelyAtRoot();
            Titanium_InitZeroCopyIPC(isSpringBoard);

            Titanium_ForceJetsamUnlimited();
            Titanium_WireGlobalPayloadsToChip();

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
            %init(Group_Hardware_ProMotion_Overclock);
            %init(Group_DaemonKiller);
            %init(Group_Apple_Native_ColdBoot_Overdrive);
            if (!g_avoidTweakConflicts) %init(Group_Silicon_Hardware_Pipeline_Overdrive);
            %init(Group_Silicon_Scheduler_Touch_Governor);
            %init(Group_CoreAnimation_RenderServer_Governor);
            %init(Group_System_Memory_And_RunLoop_Governor);
            %init(Group_Thermal_CryoPacing_ZeroDrop);
            %init(Group_Deep_RAM_Compaction_Engine);
            %init(Group_TitaniumV12_SmoothExit_And_DisplayLink);
            %init(Group_Window_Level_Overdrive);
            %init(Group_WebKit_RAM_Optimizer);
            %init(Group_UIKit_ThirdParty_IsolatedV285);
            %init(Group_Tier5_DisplayIC_DynamicIsland_Dock_3DParticles);
            %init(Group_V55_MetalSync);

            Titanium_InstallDirectIOMobileFramebufferCHooks();
            Titanium_Tier6_UnlockSystemFileAccessAndFilzaReadWrite();
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

                Titanium_StartThermalAndChargingWatchdog();
                Titanium_StartIPCHearthbeatV12();

                Titanium_ForceJetsamUnlimited();
                Titanium_WireGlobalPayloadsToChip();

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                    (int64_t)(TITANIUM_BOOT_SETTLE_DELAY_SB * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        if (g_isRebooting) return;
                        Titanium_ReloadSharedSyncStateV285();
                        Titanium_UpdateNativeDisplayMaxFPS();
                        Titanium_KillVSyncCompletelyAtRoot();
                        AppleInternal_EnforceZeroLatencyKernelTier();
                        Titanium_ApplySiliconDeepOptimizations();
                        AppleInternal_LockHardwareCADisplay();
                        if (Titanium_V57_TouchReady() && !Titanium_V56_KeyboardBusy()) {
                            Titanium_ReapplyFrameRateToAllScenes();
                        }
                        Titanium_ExecuteRealPanelOverdrive();

                        Titanium_ForceJetsamUnlimited();
                        Titanium_WireGlobalPayloadsToChip();
                    } @catch (NSException *e) {
                        Titanium_V60_Log([NSString stringWithFormat:@"[V999] SB boot settle throw: %@", e.reason]);
                    }
                });
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                    (int64_t)(TITANIUM_BOOT_SETTLE_DELAY_APP * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    @try {
                        if (g_isRebooting) return;
                        Titanium_ReloadSharedSyncStateV285();
                        if (CFG285) {
                            CFG285.enabled   = (g_syncPayloadV285.masterEnabled != 0);
                            CFG285.targetHz  = g_cachedResolvedHz;
                            CFG285.targetFPS = g_cachedResolvedFPS;
                        }
                        AppleInternal_EnforceZeroLatencyKernelTier();
                        Titanium_RegisterAppResumeRefreshV12();
                        Titanium_RestoreOnFirstFrame();

                        Titanium_ForceJetsamUnlimited();
                        Titanium_WireGlobalPayloadsToChip();
                    } @catch (NSException *e) {
                        Titanium_V60_Log([NSString stringWithFormat:@"[V999] App boot settle throw: %@", e.reason]);
                    }
                });
            }

            double settleDelay = isSpringBoard ? TITANIUM_BOOT_SETTLE_DELAY_SB : TITANIUM_BOOT_SETTLE_DELAY_APP;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(settleDelay * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                g_SystemMasterReady = YES;
            });
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[V999] runCoreTweak throw: %@", e.reason]);
        }
    }
}

// ====================================================================================================
// [UIView animation range guard]
// ====================================================================================================

%hook UIView
+ (void)_modifyAnimationsWithPreferredFrameRateRange:(CAFrameRateRange)range
                                        updateReason:(NSInteger)reason
                                          animations:(void (^)(void))animations {
    if (g_isRebooting) {
        %orig(range, reason, animations);
        return;
    }
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            NSInteger target = Titanium_GetEffectiveFrameCap();
            if (target < 15)  target = 15;
            if (target > 240) target = 240;
            range = Titanium_SmoothFRR((float)target);
            reason = 1;
        }
    }
    %orig(range, reason, animations);
}
%end

// ====================================================================================================
// [FIX SREBOOT HANG - KILL HOOK - SAFE]
// ====================================================================================================

static int (*orig_kill_v108)(pid_t, int) = NULL;

static int hooked_kill_v108(pid_t pid, int sig) {
    if ((IS_ACTIVE || Apex_IsMasterEnabled())) {
        if (pid == 1 && (sig == SIGTERM || sig == SIGKILL)) {
            g_isRebooting = YES;
            NSDictionary *marker = @{@"time": @([[NSDate date] timeIntervalSince1970])};
            [marker writeToFile:TITANIUM_SREBOOT_MARKER atomically:YES];
        }
        if (pid == getpid()) {
            if (sig == SIGSTOP) return 0;
            if (sig == SIGKILL) {
                g_isRebooting = YES;
                NSDictionary *marker = @{@"time": @([[NSDate date] timeIntervalSince1970])};
                [marker writeToFile:TITANIUM_SREBOOT_MARKER atomically:YES];
                return orig_kill_v108 ? orig_kill_v108(pid, sig) : -1;
            }
        }
    }
    return orig_kill_v108 ? orig_kill_v108(pid, sig) : -1;
}

static void Titanium_BypassKillMethodV108(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        @try {
            void *kill_sym = dlsym(RTLD_DEFAULT, "kill");
            if (!kill_sym) {
                Titanium_V60_Log(@"[V999] kill symbol missing — kill hook skipped");
                return;
            }
            if (orig_kill_v108) return;

            MSHookFunction(kill_sym, (void *)hooked_kill_v108, (void **)&orig_kill_v108);

            if (!orig_kill_v108) {
                Titanium_V60_Log(@"[V999] MSHookFunction kill failed — orig NULL, hook disabled");
            } else {
                Titanium_V60_Log(@"[V999] kill hook installed");
            }
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[V999] BypassKill throw: %@", e.reason]);
        }
    });
}

// ====================================================================================================
// [%ctor]
// ====================================================================================================

%ctor {
    @autoreleasepool {
        @try {
            const char *progName = Titanium_SafeGetProgName();
            if (!progName) return;
            if (!Titanium_IsUIProcess()) return;

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
                strcasestr(progName, "zinitd") != NULL ||
                strcasestr(progName, "nanotimekitcompaniond") != NULL ||
                strcasestr(progName, "nanotimekitd") != NULL ||
                strcasestr(progName, "nanoregistryd") != NULL ||
                strcasestr(progName, "nanopreferencesd") != NULL ||
                strcasestr(progName, "bridgeproxyd") != NULL ||
                strcasestr(progName, "bridged") != NULL ||
                strcasestr(progName, "mobileassetd") != NULL ||
                strcasestr(progName, "mobileinstallationd") != NULL ||
                strcasestr(progName, "installd") != NULL ||
                strcasestr(progName, "systemstatusd") != NULL ||
                strcasestr(progName, "aggregated") != NULL ||
                strcasestr(progName, "powerlogd") != NULL ||
                strcasestr(progName, "osanalyticsd") != NULL ||
                strcasestr(progName, "diagnosticd") != NULL ||
                strcasestr(progName, "logd") != NULL ||
                strcasestr(progName, "syslogd") != NULL) return;

            if ((strcasecmp(progName, "networkd") == 0) || (strcasecmp(progName, "trustd") == 0) ||
                (strcasecmp(progName, "configd") == 0) || (strcasecmp(progName, "wifid") == 0) ||
                (strcasecmp(progName, "CommCenter") == 0) || (strcasecmp(progName, "mDNSResponder") == 0) ||
                (strcasecmp(progName, "nsurlsessiond") == 0) || (strcasecmp(progName, "neagent") == 0) ||
                (strcasecmp(progName, "nesessionmanager") == 0) || (strcasecmp(progName, "apsd") == 0) ||
                (strcasecmp(progName, "cloudd") == 0) || (strcasecmp(progName, "geod") == 0) ||
                (strcasecmp(progName, "akd") == 0) || (strcasecmp(progName, "identityservicesd") == 0) ||
                (strcasecmp(progName, "imagent") == 0) || (strcasecmp(progName, "bluetoothd") == 0) ||
                (strcasecmp(progName, "profiled") == 0) || (strcasecmp(progName, "jailbreakd") == 0) ||
                (strcasecmp(progName, "launchd") == 0) || (strcasecmp(progName, "containermanagerd") == 0) ||
                (strcasecmp(progName, "cfprefsd") == 0) || (strcasecmp(progName, "watchdogd") == 0) ||
                (strcasecmp(progName, "mediaserverd") == 0) || (strcasecmp(progName, "installd") == 0) ||
                (strcasecmp(progName, "logd") == 0) || (strcasecmp(progName, "analyticsd") == 0) ||
                (strcasecmp(progName, "symptomsd") == 0) || (strcasecmp(progName, "powerd") == 0) ||
                (strcasecmp(progName, "notifyd") == 0) || (strcasecmp(progName, "securityd") == 0) ||
                (strcasecmp(progName, "runningboardd") == 0) || (strcasecmp(progName, "thermalmonitord") == 0) ||
                (strcasecmp(progName, "mediaremoted") == 0) || (strcasecmp(progName, "assertiond") == 0) ||
                (strcasecmp(progName, "timed") == 0) || (strcasecmp(progName, "passd") == 0)) return;

            NSBundle *mainBundle = [NSBundle mainBundle];
            NSString *bundleID = [mainBundle bundleIdentifier];
            if (bundleID) {
                if ([bundleID rangeOfString:@"networkextension" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                    [bundleID rangeOfString:@"vpn" options:NSCaseInsensitiveSearch].location != NSNotFound) return;
            }

            BOOL isSpringBoard = (bundleID && [bundleID isEqualToString:@"com.apple.springboard"]) ||
                                 (strcasecmp(progName, "SpringBoard") == 0);

            if (Titanium_ShouldDelayLoadAfterSreboot()) return;

            if (isSpringBoard) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                               dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                    @try {
                        (void)Titanium_CheckAndPreventBootloopUniversal();
                    } @catch (NSException *e) {
                        Titanium_V60_Log([NSString stringWithFormat:@"[V999] bootloop check throw: %@", e.reason]);
                    }
                });
            }

            Titanium_V55_InstallScreenState();
            Titanium_V56_InstallKeyboardState();
            Titanium_RegisterPrefsObservers(isSpringBoard);
            %init;

            // [RAM ENGINE] Force jetsam + wire ngay trong %ctor — bootloop check đã armed.
            Titanium_ForceJetsamUnlimited();
            Titanium_WireGlobalPayloadsToChip();

            Titanium_BypassDCPMethod();
            Titanium_BypassKillMethodV108();

            NSTimeInterval bootDelay = isSpringBoard ? 2.5 : 1.0;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(bootDelay * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                @try {
                    runCoreTweak(isSpringBoard, bundleID, progName);
                } @catch (NSException *e) {
                    Titanium_V60_Log([NSString stringWithFormat:@"[V999] scheduled runCoreTweak throw: %@", e.reason]);
                }
            });
        } @catch (NSException *e) {
            Titanium_V60_Log([NSString stringWithFormat:@"[V999] %%ctor throw: %@", e.reason]);
        }
    }
}
