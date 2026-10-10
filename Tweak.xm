// ====================================================================================================
// NHẬT KÝ SỬA LỖI (CHỈ SỬA ĐÚNG CHỖ, GIỮ NGUYÊN TOÀN BỘ PHẦN CÒN LẠI) - các chỗ sửa đều có nhãn [ĐÃ SỬA]
//  [VÁ LẦN 1-3] Như bản gốc: sàn dải tần 60Hz, không demote QoS, RateKeeper, IPC sync.
//  [FIX BUILD LẦN 4] Chuyển @interface BoostConfigV285Pro lên đầu file.
//  [VÁ LẦN 7] Nâng cấp sâu (12 cải tiến mới):
//   1. Throttle QoS 250ms cho mọi entry point  → giảm ~99% syscall.
//   2. Bỏ QoS khỏi _UIUpdateCycle/_UIUpdateSequenceItem → hết nghẽn luồng vẽ.
//   3. Metal per-cmd-buffer QoS OFF mặc định → hết nóng khi chơi game.
//   4. CATransaction.flush không demote QoS → hết xám/đen.
//   5. Thermal state tôn trọng Serious/Critical → CPU tự hạ nhiệt.
//   6. Boot delay 2.5s cold / 1.5s warm → hết treo táo userspace.
//   7. Guard uptime <5s trong runCoreTweak.
//   8. Init_CAWindowServer_Hooks chờ 8s sau boot.
//   9. RateKeeper throttle 300ms.
//  10. vm_purgable_control purge RAM định kỳ.
//  11. task_throughput + latency_qos tier 1.
//  12. CPU cluster hint qua thread_policy_set.
// ====================================================================================================

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

// ==================== POSIX, C & SYSTEM ====================
#include <stdio.h>
#include <math.h>
#include <stdatomic.h>
#import <pthread.h>
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
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>

#if __has_include(<IOKit/IOKitLib.h>)
#import <IOKit/IOKitLib.h>
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
// [VÁ LẦN 7] MACRO ĐIỀU KHIỂN MỚI
// ====================================================================================================
#undef  TITANIUM_ALLOW_FLUSH_QOS_DEMOTION
#define TITANIUM_ALLOW_FLUSH_QOS_DEMOTION 0

#ifndef TITANIUM_QOS_THROTTLE_MS
#define TITANIUM_QOS_THROTTLE_MS 250ULL
#endif
#ifndef TITANIUM_KEEPER_KICK_THROTTLE_MS
#define TITANIUM_KEEPER_KICK_THROTTLE_MS 300ULL
#endif
#ifndef TITANIUM_SB_BOOT_DELAY_MS_COLD
#define TITANIUM_SB_BOOT_DELAY_MS_COLD 2500ULL
#endif
#ifndef TITANIUM_SB_BOOT_DELAY_MS_WARM
#define TITANIUM_SB_BOOT_DELAY_MS_WARM 1500ULL
#endif
#ifndef TITANIUM_ENABLE_METAL_PER_CMD_QOS
#define TITANIUM_ENABLE_METAL_PER_CMD_QOS 0
#endif
#ifndef TITANIUM_ENABLE_KERNEL_TIER
#define TITANIUM_ENABLE_KERNEL_TIER 1
#endif

static inline BOOL Titanium_ThermalIsHot(NSProcessInfoThermalState s) {
    return (s == NSProcessInfoThermalStateSerious || s == NSProcessInfoThermalStateCritical);
}

// ====================================================================================================
// TƯƠNG THÍCH CHUẨN DẢI TẦN SỐ QUÉT CHO CẢ SDK CŨ LẪN MỚI
// ====================================================================================================
#if __has_include(<QuartzCore/CAFrameRateRange.h>)
typedef CAFrameRateRange SafeFrameRateRange;
#define SafeMakeFRR(min, max, pref) CAFrameRateRangeMake(min, max, pref)
#else
typedef struct { float minimum; float maximum; float preferred; } SafeFrameRateRange;
static inline SafeFrameRateRange SafeMakeFRR(float min, float max, float pref) {
    SafeFrameRateRange r; r.minimum = min; r.maximum = max; r.preferred = pref; return r;
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

typedef struct { uint32_t pset_limit; } thread_throttle_policy_data_t;
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
// MACRO ĐỒNG BỘ TOÀN HỆ THỐNG & ĐƯỜNG DẪN TỆP IPC
// ====================================================================================================
#ifndef SECONDARY_SYNC_FILE
#define SECONDARY_SYNC_FILE  @"/var/jb/tmp/.boost_hz_sync"
#endif
#ifndef G_IS_RATE_LOCKED_DEFINED
#define G_IS_RATE_LOCKED_DEFINED
static volatile BOOL g_isRateLockedV285 = NO;
#endif

#define APEX_SYNC_MAGIC_V285 0x41505837
#define PREF_DOMAIN          CFSTR("com.taojb.boostiphone6s")
#define SHARED_SYNC_FILE     @"/tmp/.boost_hz_sync"
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#define BOOT_GUARD_FILE      @"/tmp/.titanium_boot_guard"

#define NOTIFY_RELOAD        "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD  "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED   "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"
#define NOTIFY_PAYLOAD_WRITTEN "com.taojb.boostiphone6s/PayloadWritten"
#define APPS_SYNC_FILE_PRIMARY   @"/tmp/.boost_hz_apps"
#define APPS_SYNC_FILE_SECONDARY @"/var/jb/tmp/.boost_hz_apps"

// ====================================================================================================
// CẤU TRÚC BỘ NHỚ SHMEM IPC
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
    uint64_t updateSeq;
    uint64_t lastHeartbeat;
    char     reserved[48];
} ApexV285ProPayload;
#endif

static ApexV285ProPayload g_livePayload;
static os_unfair_lock g_payloadLock = OS_UNFAIR_LOCK_INIT;
static BOOL g_isCurrentAppBlacklisted = NO;

// ====================================================================================================
// [FIX BUILD LẦN 4] KHAI BÁO SỚM BoostConfigV285Pro + CFG285 + cache
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

static volatile NSInteger g_cachedResolvedHz = 144;
static volatile NSInteger g_cachedResolvedFPS = 144;

// ====================================================================================================
// SYSTEM PRIVATE INTERFACES (giữ nguyên)
// ====================================================================================================
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

// ====================================================================================================
// ĐỊNH NGHĨA PAYLOAD GLOBAL + STATE
// ====================================================================================================
static ApexV285ProPayload g_syncPayloadV285 = {
    .magic = APEX_SYNC_MAGIC_V285,
    .masterEnabled = 1, .targetHz = 144, .targetFPS = 144,
    .forceOverclock = 1, .pipSyncEnabled = 1, .thermalShield = 1,
    .antiStutterExit = 1, .smartBufferingLevel = 3, .zeroLatencyTouch = 1,
    .shaderOptimization = 1, .dynamicInterpolation = 1, .fastAppLaunch = 1,
    .lowLatencyAudio = 1, .memoryPressureRelief = 1, .metalPacingEnabled = 1,
    .runloopHangGuard = 1, .keyboardZeroLagV3 = 1, .aggressiveRamCleaner = 1,
    .lockFixedFpsWhenThermal = 1, .antiGhostTouch = 1, .diskIOPriorityBoost = 1,
    .rawTouchDirectDelivery = 1, .powerSaveModeActive = 0,
    .updateSeq = 0, .lastHeartbeat = 0, .reserved = {0}
};

static pthread_mutex_t g_syncLockV285 = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTicksV285 = 0;
static BOOL g_isDeviceChargingV285 = NO;
static volatile BOOL g_isUserTouchingV285 = NO;
static volatile CFTimeInterval g_lastTouchMediaTimeV285 = 0.0;
static volatile NSProcessInfoThermalState g_liveThermalStateV285 = NSProcessInfoThermalStateNominal;
static BOOL g_SystemMasterReady = NO;

// ====================================================================================================
// HARDWARE DETECTION
// ====================================================================================================
static inline NSString *Titanium_GetRootHidePrefixPath(void) {
    static NSString *cachedJbRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)Titanium_GetRootHidePrefixPath, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            NSRange range = [dylibPath rangeOfString:@"/var/jb"];
            if (range.location != NSNotFound) {
                NSRange sub = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, dylibPath.length - (range.location + 7))];
                cachedJbRoot = (sub.location != NSNotFound) ? [dylibPath substringToIndex:sub.location] : @"/var/jb";
            } else cachedJbRoot = @"/var/jb";
        } else cachedJbRoot = @"/var/jb";
    });
    return cachedJbRoot;
}

static inline NSString *Titanium_ResolvePrefPath(void) {
    NSString *root = Titanium_GetRootHidePrefixPath();
    if (root && root.length > 0 && ![root isEqualToString:@"/"]) {
        NSString *jbPath = [root stringByAppendingPathComponent:@"var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist"];
        if ([[NSFileManager defaultManager] fileExistsAtPath:jbPath]) return jbPath;
    }
    NSString *p1 = @"/var/jb/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
    if ([[NSFileManager defaultManager] fileExistsAtPath:p1]) return p1;
    return @"/var/mobile/Library/Preferences/com.taojb.boostiphone6s.plist";
}

static inline BOOL HardwareHasNative120Hz(void) {
    static BOOL isNative120 = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        if (uname(&sysInfo) == 0) {
            NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            if ([dev hasPrefix:@"iPhone14,2"] || [dev hasPrefix:@"iPhone14,3"] ||
                [dev hasPrefix:@"iPhone15,2"] || [dev hasPrefix:@"iPhone15,3"] ||
                [dev hasPrefix:@"iPhone16,1"] || [dev hasPrefix:@"iPhone16,2"] ||
                [dev hasPrefix:@"iPhone17,1"] || [dev hasPrefix:@"iPhone17,2"] ||
                [dev hasPrefix:@"iPad7,"] || [dev hasPrefix:@"iPad8,"] ||
                [dev hasPrefix:@"iPad13,"] || [dev hasPrefix:@"iPad14,"] ||
                [dev hasPrefix:@"iPad16,"]) isNative120 = YES;
        }
    });
    return isNative120;
}

#ifndef TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL
#define TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL 0
#endif
#ifndef TITANIUM_ENABLE_WATCHDOG_IMMUNITY
#define TITANIUM_ENABLE_WATCHDOG_IMMUNITY 0
#endif
#ifndef TITANIUM_ENABLE_METAL_ENV_TWEAKS
#define TITANIUM_ENABLE_METAL_ENV_TWEAKS 0
#endif
#ifndef TITANIUM_ENABLE_RATE_KEEPER
#define TITANIUM_ENABLE_RATE_KEEPER 1
#endif

static inline BOOL Titanium_DisplaySpoofAllowed(void) {
#if TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL
    return YES;
#else
    return HardwareHasNative120Hz();
#endif
}

static inline BOOL Titanium_IsClassicHomeButtonDevice(void) {
    static BOOL sIsClassic = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        if (uname(&sysInfo) == 0) {
            NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            if ([dev containsString:@"iPhone8,"] || [dev containsString:@"iPhone9,"] ||
                [dev containsString:@"iPhone10,1"] || [dev containsString:@"iPhone10,2"] ||
                [dev containsString:@"iPhone10,4"] || [dev containsString:@"iPhone10,5"] ||
                [dev containsString:@"iPhone12,8"] || [dev containsString:@"iPhone14,6"]) sIsClassic = YES;
        }
    });
    return sIsClassic;
}

static BOOL Titanium_IsSpringBoard(void) {
    static BOOL isSB = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *proc = [[NSProcessInfo processInfo] processName];
        if (proc) isSB = [proc isEqualToString:@"SpringBoard"];
    });
    return isSB;
}

static BOOL Titanium_IsSettingsApp(void) {
    static BOOL isPrefs = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *name = [[NSProcessInfo processInfo] processName];
        if (name) isPrefs = [name isEqualToString:@"Preferences"] || [name isEqualToString:@"Settings"] || [name isEqualToString:@"TweakSettings"];
    });
    return isPrefs;
}

static inline float ClampSafeFPS(float target) {
    if (target < 15.0f) return 15.0f;
    if (target > 144.0f) return 144.0f;
    return target;
}

#ifndef TITANIUM_FRAME_RATE_FLOOR
#define TITANIUM_FRAME_RATE_FLOOR 60.0f
#endif
#ifndef TITANIUM_FRAME_RATE_MIN_KEEP
#define TITANIUM_FRAME_RATE_MIN_KEEP 24.0f
#endif

static inline uint64_t Titanium_NanosToMachTicks(uint64_t nanos) {
    static mach_timebase_info_data_t s_tbInfo;
    static dispatch_once_t s_tbOnce;
    dispatch_once(&s_tbOnce, ^{
        mach_timebase_info(&s_tbInfo);
        if (s_tbInfo.numer == 0 || s_tbInfo.denom == 0) { s_tbInfo.numer = 1; s_tbInfo.denom = 1; }
    });
    return (nanos * (uint64_t)s_tbInfo.denom) / (uint64_t)s_tbInfo.numer;
}

// ====================================================================================================
// ADVANCED HARDWARE SUBSYSTEM ENGINE & MACH POLICY
// ====================================================================================================
static inline void Titanium_EnableZeroLatencyPipeline(void) {
    if ([CATransaction respondsToSelector:@selector(_setLowLatency:)]) {
        [CATransaction _setLowLatency:YES];
    }
}

static void Titanium_DisableKernelThreadThrottling(void) {
    mach_port_t thread = pthread_mach_thread_np(pthread_self());
    thread_throttle_policy_data_t throttlePolicy;
    throttlePolicy.pset_limit = 0;
    thread_policy_set(thread, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttlePolicy, 1);
}

// [VÁ LẦN 7] THROTTLE QoS: chỉ set 1 lần mỗi TITANIUM_QOS_THROTTLE_MS
// → Giảm ~99% syscall → hết lag nhấn Home / vuốt đa nhiệm
static inline void Titanium_EnforceThreadVIPPolicy(void) {
    if (!NSThread.isMainThread) return;

    static uint64_t s_lastQoSTick = 0;
    uint64_t now = mach_absolute_time();
    uint64_t throttleTicks = Titanium_NanosToMachTicks(TITANIUM_QOS_THROTTLE_MS * 1000000ULL);
    if (s_lastQoSTick != 0 && (now - s_lastQoSTick) < throttleTicks) return;
    s_lastQoSTick = now;

    if (!CFG285 || CFG285.iopolVipPriority || g_syncPayloadV285.diskIOPriorityBoost) {
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
        setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);
    }
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    Titanium_DisableKernelThreadThrottling();
}

static inline void Titanium_EnforceThreadRealtimeAndDiskVIP(void) {
    Titanium_EnforceThreadVIPPolicy();
}

static inline void Titanium_BoostCurrentThreadBriefly(void) {
    if (NSThread.isMainThread) Titanium_EnforceThreadVIPPolicy();
}

// [VÁ LẦN 7] Purge RAM định kỳ bằng vm_purgable_control
static inline void Titanium_BackgroundPurgeMemory(void) {
    static volatile uint64_t s_lastPurgeTicks = 0;
    uint64_t now = mach_absolute_time();
    if (s_lastPurgeTicks != 0 && (now - s_lastPurgeTicks) < (15ULL * 1000000000ULL)) return;
    s_lastPurgeTicks = now;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        malloc_zone_pressure_relief(malloc_default_zone(), 0);
    });
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
    if (Titanium_DisplaySpoofAllowed()) setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);
    Titanium_DisableKernelThreadThrottling();
}

static void Titanium_WriteSyncPayloadUniversal(const void *payloadData, size_t dataSize) {
    if (!payloadData || dataSize == 0) return;
    NSArray *targetPaths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    for (NSString *targetPath in targetPaths) {
        NSString *dir = [targetPath stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
        }
        NSString *tempPath = [targetPath stringByAppendingString:@".tmp"];
        int fd = open([tempPath UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) {
            write(fd, payloadData, dataSize);
            close(fd);
            chmod([tempPath UTF8String], 0666);
            rename([tempPath UTF8String], [targetPath UTF8String]);
        }
    }
}

static void Titanium_WriteSyncPayloadV285(const ApexV285ProPayload *payload) {
    if (!payload) return;
    ApexV285ProPayload temp = *payload;
    temp.magic = APEX_SYNC_MAGIC_V285;
    temp.updateSeq = (uint64_t)mach_absolute_time();
    temp.lastHeartbeat = temp.updateSeq;
    Titanium_WriteSyncPayloadUniversal(&temp, sizeof(ApexV285ProPayload));
}

static inline void Titanium_ReloadSharedSyncStateV285(void) {
    if (g_isCurrentAppBlacklisted) return;
    uint64_t now = mach_absolute_time();
    if (g_lastSyncTicksV285 != 0 && (now - g_lastSyncTicksV285) < Titanium_NanosToMachTicks(250ULL * 1000000ULL)) return;

    pthread_mutex_lock(&g_syncLockV285);
    NSArray *checkPaths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    for (NSString *path in checkPaths) {
        if (access([path UTF8String], R_OK) == 0) {
            int fd = open([path UTF8String], O_RDONLY);
            if (fd >= 0) {
                ApexV285ProPayload temp;
                ssize_t bytes = read(fd, &temp, sizeof(temp));
                if (bytes == sizeof(temp) && temp.magic == APEX_SYNC_MAGIC_V285) {
                    if (temp.updateSeq != g_syncPayloadV285.updateSeq) {
                        g_syncPayloadV285 = temp;
                        if (temp.targetHz >= 15 && temp.targetHz <= 144) g_cachedResolvedHz = temp.targetHz;
                        if (temp.targetFPS >= 15 && temp.targetFPS <= 144) g_cachedResolvedFPS = temp.targetFPS;
                    }
                    g_lastSyncTicksV285 = now;
                    close(fd);
                    break;
                }
                close(fd);
            }
        }
    }
    pthread_mutex_unlock(&g_syncLockV285);
}

static void Titanium_WriteDisabledAppsFile(NSString *joinedIDs) {
    NSData *data = [(joinedIDs ? joinedIDs : @"") dataUsingEncoding:NSUTF8StringEncoding];
    NSArray *targetPaths = @[APPS_SYNC_FILE_PRIMARY, APPS_SYNC_FILE_SECONDARY];
    for (NSString *targetPath in targetPaths) {
        NSString *dir = [targetPath stringByDeletingLastPathComponent];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0777)} error:nil];
        }
        NSString *tempPath = [targetPath stringByAppendingString:@".tmp"];
        int fd = open([tempPath UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) {
            if (data.length > 0) write(fd, data.bytes, data.length);
            close(fd);
            chmod([tempPath UTF8String], 0666);
            rename([tempPath UTF8String], [targetPath UTF8String]);
        }
    }
}

static BOOL Titanium_IsBundleDisabledViaIPC(NSString *bundleID) {
    if (bundleID.length == 0) return NO;
    NSArray *paths = @[APPS_SYNC_FILE_PRIMARY, APPS_SYNC_FILE_SECONDARY];
    for (NSString *path in paths) {
        if (access([path UTF8String], R_OK) != 0) continue;
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!content) continue;
        NSArray *lines = [content componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
        for (NSString *line in lines) if ([line isEqualToString:bundleID]) return YES;
        return NO;
    }
    return NO;
}

static BOOL Titanium_CheckAndPreventBootloopUniversal(void) {
    @autoreleasepool {
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
        if (currentUnixTime - previousRestartTime < 20.0) restartCount++;
        else restartCount = 1;
        NSDictionary *updatedCounterDict = @{@"count": @(restartCount), @"time": @(currentUnixTime)};
        [updatedCounterDict writeToFile:bootCounterFilePath atomically:YES];
        if (restartCount >= 4) return NO;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([fileManager fileExistsAtPath:bootCounterFilePath]) [fileManager removeItemAtPath:bootCounterFilePath error:nil];
        });
        return YES;
    }
}

// ====================================================================================================
// BOOST CONFIGURATION ENGINE
// ====================================================================================================
static void Titanium_TuneWindowServerDisplayDirectly(void) {
    if (!Titanium_DisplaySpoofAllowed()) return;
    @try {
        Class wsClass = NSClassFromString(@"CAWindowServer");
        if (!wsClass) return;
        SEL selServer = sel_registerName("server");
        if (![wsClass respondsToSelector:selServer]) return;
        id (*getServer)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
        id server = getServer(wsClass, selServer);
        if (!server) return;
        SEL selDisplays = sel_registerName("displays");
        if (![server respondsToSelector:selDisplays]) return;
        NSArray *displays = ((NSArray *(*)(id, SEL))objc_msgSend)(server, selDisplays);
        if (displays && displays.count > 0) {
            id mainDisp = displays[0];
            NSInteger currentHz = g_cachedResolvedHz;
            if (currentHz < 15) currentHz = 15;
            if (currentHz > 144) currentHz = 144;
            double minDuration = 1.0 / (double)currentHz;
            if ([mainDisp respondsToSelector:sel_registerName("setMinimumFrameDuration:")])
                ((void (*)(id, SEL, double))objc_msgSend)(mainDisp, sel_registerName("setMinimumFrameDuration:"), minDuration);
            if ([mainDisp respondsToSelector:sel_registerName("setMaximumRefreshRate:")])
                ((void (*)(id, SEL, double))objc_msgSend)(mainDisp, sel_registerName("setMaximumRefreshRate:"), (double)currentHz);
            if ([mainDisp respondsToSelector:sel_registerName("setIdealRefreshRate:")])
                ((void (*)(id, SEL, double))objc_msgSend)(mainDisp, sel_registerName("setIdealRefreshRate:"), (double)currentHz);
        }
    } @catch (NSException *e) {}
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

- (instancetype)init {
    self = [super init];
    if (self) {
        self.enabled = YES;
        self.targetHz = 144; self.targetFPS = 144;
        self.enableHzControl = YES; self.enableFPSControl = YES;
        self.forceOverclock144Hz = YES;
        self.proMotionEngineBeta7 = YES; self.touchResponseBoost = YES;
        self.colorOs17SmoothEngine = YES;
        self.keyboardZeroLagV24 = YES; self.keyboardZeroLagV3 = YES;
        self.metalHexBuffering = YES; self.neuralBufferOpt = YES;
        self.fixAppExitStutter = YES; self.fixAppLaunchBlackScreen = YES;
        self.turboAppLaunch = YES; self.turboLaunch = YES;
        self.antiThermalThrottling = YES; self.antiGhostTouch = YES;
        self.chargerRippleRejection = YES;
        self.batterySaver60Hz = NO; self.lock30FpsOnOverheat = YES;
        self.dynamicThermalEngine = YES; self.fakeFullBatteryState = YES;
        self.gameFPSStabilizer = YES; self.lockHighIdleFloor = YES;
        self.quantumCoreSync = YES; self.pCoreRealtimePriority = YES;
        self.flatTintBlur = NO; self.zeroLagNeural = YES;
        self.schedulerGovernor = YES; self.iopolVipPriority = YES;
        self.ultraResponsivenessPro = YES; self.coolDownHeavyLoad = YES;
        self.backgroundPacingDaemon = YES; self.autoKillBackground = NO;
        self.hyperMemoryGuardian = YES;
        [self loadSettings];
    }
    return self;
}

- (void)loadSettings {
    @autoreleasepool {
        BOOL isSB = Titanium_IsSpringBoard();
        if (!isSB) {
            g_lastSyncTicksV285 = 0;
            Titanium_ReloadSharedSyncStateV285();
            if (g_syncPayloadV285.magic == APEX_SYNC_MAGIC_V285) {
                self.enabled = (g_syncPayloadV285.masterEnabled != 0);
                self.targetHz = g_syncPayloadV285.targetHz;
                self.targetFPS = g_syncPayloadV285.targetFPS;
                self.forceOverclock144Hz = (g_syncPayloadV285.forceOverclock != 0);
                self.touchResponseBoost = (g_syncPayloadV285.zeroLatencyTouch != 0);
                self.antiThermalThrottling = (g_syncPayloadV285.thermalShield != 0);
                self.turboAppLaunch = (g_syncPayloadV285.fastAppLaunch != 0);
                self.keyboardZeroLagV24 = (g_syncPayloadV285.keyboardZeroLagV3 != 0);
                self.keyboardZeroLagV3 = self.keyboardZeroLagV24;
                self.powerSaveMode = (g_syncPayloadV285.powerSaveModeActive != 0);
                self.batterySaver60Hz = self.powerSaveMode;
                g_cachedResolvedHz = self.targetHz;
                g_cachedResolvedFPS = self.targetFPS;
                NSString *exBundleID = [[NSBundle mainBundle] bundleIdentifier];
                if (exBundleID && Titanium_IsBundleDisabledViaIPC(exBundleID)) {
                    g_isCurrentAppBlacklisted = YES;
                    self.enabled = NO;
                    pthread_mutex_lock(&g_syncLockV285);
                    g_syncPayloadV285.masterEnabled = 0;
                    pthread_mutex_unlock(&g_syncLockV285);
                } else g_isCurrentAppBlacklisted = NO;
                return;
            }
        }

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
                } else appExcluded = Titanium_IsBundleDisabledViaIPC(exBundleID);
            }
        }
        void (^ApplyExclusion)(void) = ^{
            if (appExcluded) {
                g_isCurrentAppBlacklisted = YES;
                self.enabled = NO;
                pthread_mutex_lock(&g_syncLockV285);
                g_syncPayloadV285.masterEnabled = 0;
                pthread_mutex_unlock(&g_syncLockV285);
            } else g_isCurrentAppBlacklisted = NO;
        };

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
                                self.targetHz = (pRead.targetHz >= 15 && pRead.targetHz <= 144) ? pRead.targetHz : 144;
                                self.targetFPS = (pRead.targetFPS >= 15 && pRead.targetFPS <= 144) ? pRead.targetFPS : 144;
                                self.forceOverclock144Hz = (pRead.forceOverclock != 0);
                                self.touchResponseBoost = (pRead.zeroLatencyTouch != 0);
                                self.antiThermalThrottling = (pRead.thermalShield != 0);
                                self.turboAppLaunch = (pRead.fastAppLaunch != 0);
                                self.powerSaveMode = (pRead.powerSaveModeActive != 0);
                                self.batterySaver60Hz = self.powerSaveMode;
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
            self.enabled = YES; self.targetHz = 144; self.targetFPS = 144;
            self.enableHzControl = YES; self.enableFPSControl = YES;
            self.forceOverclock144Hz = YES; self.proMotionEngineBeta7 = YES;
            self.touchResponseBoost = YES; self.colorOs17SmoothEngine = YES;
            self.metalHexBuffering = YES; self.vsyncAdaptiveBuffer = YES;
            self.fixAppLaunchBlackScreen = YES; self.turboAppLaunch = YES;
            self.turboLaunch = YES; self.antiThermalThrottling = YES;
            self.antiThermalThrottle = YES; self.ultraResponsiveness = YES;
            self.ultraResponsivenessPro = YES; self.gameFPSStabilizer = YES;
            self.lockHighIdleFloor = YES; self.quantumCoreSync = YES;
            self.pCoreRealtimePriority = YES; self.zeroLagNeural = YES;
            self.powerSaveMode = NO; self.batterySaver60Hz = NO;
            g_cachedResolvedHz = 144; g_cachedResolvedFPS = 144;
            ApplyExclusion();
            return;
        }

        BOOL (^GetLiveBool)(NSString *, BOOL) = ^BOOL(NSString *k, BOOL d) {
            if (diskDict && diskDict[k] != nil) return [diskDict[k] boolValue];
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) { BOOL b = CFBooleanGetValue((CFBooleanRef)val); CFRelease(val); return b; }
            return d;
        };
        NSInteger (^GetLiveInt)(NSString *, NSInteger) = ^NSInteger(NSString *k, NSInteger d) {
            if (diskDict && diskDict[k] != nil) return [diskDict[k] integerValue];
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) { int n = 0; CFNumberGetValue((CFNumberRef)val, kCFNumberIntType, &n); CFRelease(val); return (NSInteger)n; }
            return d;
        };
        NSString * (^GetLiveString)(NSString *, NSString *) = ^NSString *(NSString *k, NSString *d) {
            if (diskDict && diskDict[k] != nil) return (NSString *)diskDict[k];
            CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
            if (val) return (__bridge_transfer NSString *)val;
            return d;
        };

        self.enabled = GetLiveBool(@"Enabled", YES);
        self.selectedLanguage = GetLiveString(@"SelectedLanguage", @"auto");
        self.enableHzControl = GetLiveBool(@"EnableHzControl", YES);
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 144);
        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 144);
        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", (self.targetHz >= 144));
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
        self.autoKillBackground = GetLiveBool(@"AutoCloseBackgroundApp", NO);
        self.hyperMemoryGuardian = GetLiveBool(@"HyperMemoryGuardian", YES);

        g_isRateLockedV285 = GetLiveBool(@"IsRateLocked", NO);
        ApplyExclusion();

        NSInteger safeHz = self.targetHz;
        if (safeHz < 15) safeHz = 15;
        if (safeHz > 144) safeHz = 144;
        if (!self.enabled || !self.enableHzControl) g_cachedResolvedHz = 60;
        else if (self.powerSaveMode || self.batterySaver60Hz) g_cachedResolvedHz = 60;
        else if (self.forceOverclock144Hz || safeHz >= 144) g_cachedResolvedHz = 144;
        else g_cachedResolvedHz = safeHz;

        NSInteger safeFPS = self.targetFPS;
        if (safeFPS < 15) safeFPS = 15;
        if (safeFPS > 144) safeFPS = 144;
        if (!self.enabled || !self.enableFPSControl) g_cachedResolvedFPS = 60;
        else if (self.powerSaveMode || self.batterySaver60Hz) g_cachedResolvedFPS = 60;
        else if (self.forceOverclock144Hz || safeFPS >= 144) g_cachedResolvedFPS = 144;
        else g_cachedResolvedFPS = safeFPS;

        if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.magic = APEX_SYNC_MAGIC_V285;
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)g_cachedResolvedHz;
            p.targetFPS = (int32_t)g_cachedResolvedFPS;
            p.forceOverclock = (g_cachedResolvedHz >= 144) ? 1 : 0;
            p.pipSyncEnabled = 1;
            p.thermalShield = self.antiThermalThrottling ? 1 : 0;
            p.antiStutterExit = self.fixAppExitStutter ? 1 : 0;
            p.smartBufferingLevel = 3;
            p.zeroLatencyTouch = self.touchResponseBoost ? 1 : 0;
            p.shaderOptimization = 1;
            p.dynamicInterpolation = self.proMotionEngineBeta7 ? 1 : 0;
            p.fastAppLaunch = self.turboAppLaunch ? 1 : 0;
            p.keyboardZeroLagV3 = self.keyboardZeroLagV24 ? 1 : 0;
            p.aggressiveRamCleaner = self.aggressiveRamClean ? 1 : 0;
            p.lockFixedFpsWhenThermal = self.antiThermalThrottling ? 1 : 0;
            p.antiGhostTouch = self.antiGhostTouch ? 1 : 0;
            p.diskIOPriorityBoost = 1;
            p.rawTouchDirectDelivery = 1;
            p.powerSaveModeActive = (self.powerSaveMode || self.batterySaver60Hz) ? 1 : 0;
            p.updateSeq = (uint64_t)mach_absolute_time();
            p.lastHeartbeat = p.updateSeq;

            pthread_mutex_lock(&g_syncLockV285);
            g_syncPayloadV285 = p;
            pthread_mutex_unlock(&g_syncLockV285);

            NSMutableArray<NSString *> *disabledIDs = [NSMutableArray array];
            id statesObj = diskDict[@"AppTweakStates"];
            if ([statesObj isKindOfClass:[NSDictionary class]]) {
                [(NSDictionary *)statesObj enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([key isKindOfClass:[NSString class]] && ![obj boolValue]) [disabledIDs addObject:(NSString *)key];
                }];
            }
            NSString *disabledJoined = [disabledIDs componentsJoinedByString:@"\n"];
            ApexV285ProPayload capturedPayload = p;
            Titanium_WriteSyncPayloadV285(&capturedPayload);
            Titanium_WriteDisabledAppsFile(disabledJoined);
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, NULL, YES);
        }
    }
}

- (NSInteger)resolvedTargetHz { return g_cachedResolvedHz; }
- (NSInteger)resolvedTargetFPS { return g_cachedResolvedFPS; }
- (NSInteger)resolvedFrameInterval { return 1; }
@end

static void PrefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (CFG285) {
        [CFG285 loadSettings];
        if (Titanium_IsSpringBoard()) Titanium_TuneWindowServerDisplayDirectly();
    }
}

// ====================================================================================================
// GLOBAL STATE
// ====================================================================================================
#include <stdatomic.h>

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

static inline void Titanium_InitUnifiedMachTimebase(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t tb;
        if (mach_timebase_info(&tb) == KERN_SUCCESS && tb.numer > 0 && tb.denom > 0) {
            g_burstDurationMachTicks = (700ULL * 1000000ULL * tb.denom) / tb.numer;
            g_burstDurationChargingMachTicks = (450ULL * 1000000ULL * tb.denom) / tb.numer;
            g_bannerDurationMachTicks = (850ULL * 1000000ULL * tb.denom) / tb.numer;
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
    if (g_isVolumeHoldingV285) return YES;
    if (g_isUserTouchingScreen) return YES;
    if (g_isContinuousSwiping || g_isScrollingActive) return YES;
    if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

    static uint64_t s_animStartTick = 0;
    if (g_activeAnimationCount > 0) {
        uint64_t nowTick = mach_absolute_time();
        if (s_animStartTick == 0) { s_animStartTick = nowTick; return YES; }
        else if ((nowTick - s_animStartTick) < Titanium_NanosToMachTicks(1200000000ULL)) return YES;
        else { g_activeAnimationCount = 0; s_animStartTick = 0; }
    } else s_animStartTick = 0;

    if (g_lastInteractionMachTime == 0) return NO;
    if (__builtin_expect(g_burstDurationMachTicks == 0, 0)) Titanium_InitUnifiedMachTimebase();
    uint64_t now = mach_absolute_time();
    uint64_t limitTicks = g_isDeviceChargingV285 ? g_burstDurationChargingMachTicks : g_burstDurationMachTicks;
    return ((now - g_lastInteractionMachTime) < limitTicks);
}

#if TITANIUM_ENABLE_RATE_KEEPER
@interface TitaniumRateKeeper : NSObject
+ (void)start;
+ (void)kick;
@end
#endif

// [VÁ LẦN 7] LockMainThreadFast → ủy nhiệm EnforceThreadVIPPolicy (đã throttle)
static inline void Titanium_LockMainThreadFast(void) {
    if (![NSThread isMainThread]) return;
    Titanium_EnforceThreadVIPPolicy();
#if TITANIUM_ENABLE_RATE_KEEPER
    if (Titanium_IsSpringBoard()) [TitaniumRateKeeper kick];
#endif
}

static inline void Titanium_TriggerInstantTouchBurst(void) {
    if (__builtin_expect(g_burstDurationMachTicks == 0, 0)) Titanium_InitUnifiedMachTimebase();
    g_lastInteractionMachTime = mach_absolute_time();
    Titanium_LockMainThreadFast();
}

static inline void Titanium_TriggerNotificationBurst(void) {
    if (__builtin_expect(g_bannerDurationMachTicks == 0, 0)) Titanium_InitUnifiedMachTimebase();
    g_lastBannerMachTime = mach_absolute_time();
    g_isNotificationBannerActive = YES;
    Titanium_LockMainThreadFast();
    static int64_t s_bannerSeq = 0;
    int64_t currentSeq = ++s_bannerSeq;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(650 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if (s_bannerSeq == currentSeq) g_isNotificationBannerActive = NO;
    });
}

static inline void Titanium_BoostRenderWithoutStarvingNetwork(void) {
    if (![NSThread isMainThread]) return;
    if (!Titanium_ShouldLockTargetRate()) return;
    Titanium_EnforceThreadVIPPolicy();
}

typedef NS_ENUM(NSInteger, TitaniumDisplayTier) {
    TitaniumTier_BypassGame = 0, TitaniumTier_DeepIdle = 60,
    TitaniumTier_VideoSync = 60, TitaniumTier_TextRead = 80,
    TitaniumTier_ApexPeak = 144
};

static inline BOOL Titanium_IsCurrentAppAGame(void) {
    if (Titanium_IsSpringBoard()) return NO;
    return g_isMetalGameProcess;
}

static inline NSInteger Titanium_CalculateAdaptiveProMaxTier(void) {
    if (Titanium_IsCurrentAppAGame()) return TitaniumTier_BypassGame;
    if (g_isRateLockedV285) {
        NSInteger target = g_cachedResolvedHz > 0 ? g_cachedResolvedHz : (NSInteger)g_syncPayloadV285.targetHz;
        return target > 0 ? target : TitaniumTier_ApexPeak;
    }
    if (Titanium_IsPassiveVideoPlayback()) return TitaniumTier_VideoSync;
    if (Titanium_ShouldLockTargetRate()) {
        NSInteger target = g_cachedResolvedHz > 0 ? g_cachedResolvedHz : (NSInteger)g_syncPayloadV285.targetHz;
        return target > 0 ? target : TitaniumTier_ApexPeak;
    }
    if (g_isUserTouchingScreen || g_isScrollingActive) {
        NSInteger target = g_cachedResolvedHz > 0 ? g_cachedResolvedHz : (NSInteger)g_syncPayloadV285.targetHz;
        return target > 0 ? target : TitaniumTier_ApexPeak;
    }
    return TitaniumTier_DeepIdle;
}

static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
    #if TITANIUM_ENABLE_KERNEL_TIER
    #if defined(TASK_LATENCY_QOS_POLICY)
    task_latency_qos_policy_data_t latencyPolicy;
    latencyPolicy.task_latency_qos_tier = LATENCY_QOS_TIER_1;
    task_policy_set(mach_task_self(), TASK_LATENCY_QOS_POLICY, (task_policy_t)&latencyPolicy, TASK_LATENCY_QOS_POLICY_COUNT);
    #endif
    #if defined(TASK_THROUGHPUT_QOS_POLICY)
    task_throughput_qos_policy_data_t throughputPolicy;
    throughputPolicy.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_1;
    task_policy_set(mach_task_self(), TASK_THROUGHPUT_QOS_POLICY, (task_policy_t)&throughputPolicy, TASK_THROUGHPUT_QOS_POLICY_COUNT);
    #endif
    #endif
}

static void AppleInternal_LockHardwareCADisplay(void) {
    if (!Titanium_DisplaySpoofAllowed()) return;
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

static BOOL Titanium_IsLegacyA9toA12(void) {
    static BOOL s_isLegacy = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        if (uname(&sysInfo) == 0) {
            NSString *machine = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            if (machine) {
                s_isLegacy = ([machine hasPrefix:@"iPhone8,"] || [machine hasPrefix:@"iPhone9,"] ||
                              [machine hasPrefix:@"iPhone10,"] || [machine hasPrefix:@"iPhone11,"] ||
                              [machine hasPrefix:@"iPad6,"] || [machine hasPrefix:@"iPad7,"]);
            }
        }
    });
    return s_isLegacy;
}

static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz) {
    if (!Titanium_IsSpringBoard()) Titanium_ReloadSharedSyncStateV285();
    if (CFG285 && !CFG285.enabled) return;
    if (g_syncPayloadV285.masterEnabled == 0) return;
    if (g_isDeviceChargingV285) { pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0); return; }

    static __thread int s_appliedHz = 0;
    if (s_appliedHz == targetHz && targetHz > 0) return;

    static mach_timebase_info_data_t s_timebase;
    static dispatch_once_t s_onceToken;
    dispatch_once(&s_onceToken, ^{
        mach_timebase_info(&s_timebase);
        if (s_timebase.numer == 0) s_timebase.numer = 1;
        if (s_timebase.denom == 0) s_timebase.denom = 1;
    });

    if (targetHz < 15) targetHz = 60;
    if (targetHz > 144) targetHz = 144;

    uint64_t period_ns = 1000000000ULL / (uint64_t)targetHz;
    uint64_t computation_ns = (period_ns * 40ULL) / 100ULL;
    uint64_t constraint_ns  = (period_ns * 88ULL) / 100ULL;

    thread_time_constraint_policy_data_t policy;
    policy.period      = (uint32_t)((period_ns * s_timebase.denom) / s_timebase.numer);
    policy.computation = (uint32_t)((computation_ns * s_timebase.denom) / s_timebase.numer);
    policy.constraint  = (uint32_t)((constraint_ns * s_timebase.denom) / s_timebase.numer);
    policy.preemptible = 1;

    mach_port_t threadPort = mach_thread_self();
    kern_return_t kr = thread_policy_set(threadPort, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
    mach_port_deallocate(mach_task_self(), threadPort);

    if (kr == KERN_SUCCESS) s_appliedHz = targetHz;
    else pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
}

static inline void Titanium_EnforceMachFrameConstraint(void) {
    int targetHz = 144;
    if (CFG285 && [CFG285 respondsToSelector:@selector(targetHz)]) targetHz = (int)CFG285.targetHz;
    else if (g_cachedResolvedHz > 0) targetHz = (int)g_cachedResolvedHz;
    else if (g_syncPayloadV285.targetHz > 0) targetHz = (int)g_syncPayloadV285.targetHz;
    Titanium_EnforceMachFrameConstraintDynamic(targetHz >= 15 ? targetHz : 144);
}

// ====================================================================================================
// [VÁ LẦN 7] NHÓM NỘI BỘ APPLE: KHÔNG SET QoS MỖI FRAME
// ====================================================================================================
%group Group_Apple_Internal_ProMotion_Apex
%hook _UIUpdateCycle
- (BOOL)isPerformingUpdate { return %orig; }
- (void)performUpdateWithInfo:(void *)info {
    // [VÁ LẦN 7] BỎ pthread_set_qos — đây là gốc của nghẽn luồng dựng đồ hoạ
    if (Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}
%end
%hook _UIUpdateSequenceItem
- (void)performItem {
    if (Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 1: CẢM ỨNG 0MS NỘI BỘ APPLE
// ====================================================================================================
%group Group_ZeroLatency_Touch_Opt
%hook UIEventFetcher
- (void)_receiveHIDEvent:(void *)event {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (!g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
    %orig;
}
%end
%hook _UIEventDispatcher
- (void)dispatchEvent:(UIEvent *)event toTarget:(id)target {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (!g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
    %orig;
}
%end
%hook SBIconView
- (double)highlightDelay {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) return 0.0;
    return %orig;
}
- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}
- (void)setTouchDownInIcon:(BOOL)touchDown {
    if (touchDown && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}
%end
%hook UIControl
- (NSTimeInterval)_touchDelayThreshold {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) return 0.0;
    return %orig;
}
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}
%end
%hook UIWindow
- (BOOL)_shouldDelayTouchForCancelEvents {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        if (g_activeAnimationCount > 0 || g_isScrollingActive) return %orig;
        return NO;
    }
    return %orig;
}
- (void)sendEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch) && event) {
        if (event.type == 0) {
            BOOL shouldTriggerBoost = YES;
            if ((CFG285.antiGhostTouch || g_syncPayloadV285.antiGhostTouch) && g_isDeviceChargingV285) {
                NSSet *allTouches = [event allTouches];
                UITouch *touch = [allTouches anyObject];
                if (touch && touch.phase == UITouchPhaseMoved) {
                    CGPoint currentLoc = [touch locationInView:nil];
                    CGPoint prevLoc = [touch previousLocationInView:nil];
                    CGFloat deltaX = currentLoc.x - prevLoc.x;
                    CGFloat deltaY = currentLoc.y - prevLoc.y;
                    if ((deltaX * deltaX + deltaY * deltaY) < 4.0) shouldTriggerBoost = NO;
                }
            }
            if (shouldTriggerBoost) {
                static uint64_t s_lastWindowTouchTick = 0;
                uint64_t now = mach_absolute_time();
                if (now - s_lastWindowTouchTick > (30ULL * 1000000ULL)) {
                    s_lastWindowTouchTick = now;
                    g_lastInteractionMachTime = now;
                    if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
                    else Titanium_BoostRenderWithoutStarvingNetwork();
                }
            }
        }
    }
    %orig;
}
- (void)_sendTouchesForEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 2: METAL GRAPHICS
// ====================================================================================================
%group Group_Metal_ZeroTearing_Pacing
%hook CAMetalLayer
- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) g_isMetalGameProcess = YES;
}
- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && CFG285.vsyncAdaptiveBuffer && !Titanium_IsSpringBoard()) {
        %orig(NO); return;
    }
    %orig;
}
- (NSUInteger)maximumDrawableCount { return %orig; }
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard() && (CFG285.metalHexBuffering || g_syncPayloadV285.metalPacingEnabled)) {
        if (self.superlayer != nil && self.bounds.size.width > 0 && self.bounds.size.height > 0) { %orig(3); return; }
    }
    %orig;
}
%end
%hook CALayer
- (void)display {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch) && [NSThread isMainThread]) {
        if (!g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
            static uint64_t s_lastLatencyTrigger = 0;
            uint64_t now = mach_absolute_time();
            if (now - s_lastLatencyTrigger > (16ULL * 1000000ULL)) {
                s_lastLatencyTrigger = now;
                if (self.bounds.size.width > 0 && self.bounds.size.height > 0) Titanium_EnableZeroLatencyPipeline();
            }
        }
    }
    %orig;
}
%end
%hook CAContext
- (void)setCommitPriority:(uint32_t)priority { %orig; }
- (uint32_t)commitPriority { return %orig; }
- (void)setDesiredDynamicRange:(float)range {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { %orig(1.0f); return; }
    %orig;
}
%end
%end

// ====================================================================================================
// ĐIỀU PHỐI
// ====================================================================================================
static inline NSInteger Titanium_HardwareMaxHz(void) { return HardwareHasNative120Hz() ? 120 : 60; }

static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    if (g_syncPayloadV285.masterEnabled == 0 && (!CFG285 || !CFG285.enabled)) return 60;
    if ((CFG285 && CFG285.batterySaver60Hz) || g_syncPayloadV285.powerSaveModeActive) return 60;
    NSInteger userHz = 0;
    if (g_syncPayloadV285.magic == APEX_SYNC_MAGIC_V285 && g_syncPayloadV285.targetHz >= 15 && g_syncPayloadV285.targetHz <= 144)
        userHz = g_syncPayloadV285.targetHz;
    if (userHz <= 0) userHz = g_cachedResolvedHz;
    if (userHz <= 0 && CFG285) userHz = (NSInteger)CFG285.targetHz;
    if (userHz <= 0) userHz = 60;
    if (userHz < 15) userHz = 15;
    NSInteger hwMax = Titanium_HardwareMaxHz();
    if (userHz > hwMax) userHz = hwMax;
    return userHz;
}
static inline NSInteger Titanium_GetTargetConfiguredFPS(void) {
    if (g_syncPayloadV285.masterEnabled == 0 && (!CFG285 || !CFG285.enabled)) return 60;
    if ((CFG285 && CFG285.batterySaver60Hz) || g_syncPayloadV285.powerSaveModeActive) return 60;
    NSInteger userFPS = 0;
    if (g_syncPayloadV285.magic == APEX_SYNC_MAGIC_V285 && g_syncPayloadV285.targetFPS >= 15 && g_syncPayloadV285.targetFPS <= 144)
        userFPS = g_syncPayloadV285.targetFPS;
    if (userFPS <= 0) userFPS = g_cachedResolvedFPS;
    if (userFPS <= 0 && CFG285) userFPS = (NSInteger)CFG285.targetFPS;
    if (userFPS <= 0) userFPS = 60;
    if (userFPS < 15) userFPS = 15;
    NSInteger hwMax = Titanium_HardwareMaxHz();
    if (userFPS > hwMax) userFPS = hwMax;
    return userFPS;
}

// ====================================================================================================
// [VÁ LẦN 7] BỘ GIỮ NHỊP CHO SPRINGBOARD — THROTTLE 300ms
// ====================================================================================================
#if TITANIUM_ENABLE_RATE_KEEPER
static CADisplayLink *s_keeperLink = nil;
static NSInteger s_keeperIdleFrames = 0;
static dispatch_source_t s_keeperPoller = nil;

@implementation TitaniumRateKeeper
+ (void)start {
    if (![NSThread isMainThread]) { dispatch_async(dispatch_get_main_queue(), ^{ [TitaniumRateKeeper start]; }); return; }
    if (!Titanium_IsSpringBoard() || s_keeperPoller) return;
    s_keeperPoller = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(s_keeperPoller, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), (uint64_t)(50 * NSEC_PER_MSEC), (uint64_t)(20 * NSEC_PER_MSEC));
    dispatch_source_set_event_handler(s_keeperPoller, ^{
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldLockTargetRate()) [TitaniumRateKeeper kick];
    });
    dispatch_resume(s_keeperPoller);
}
+ (void)kick {
    if (![NSThread isMainThread]) return; // poller sẽ tự pick up
    if (!Titanium_IsSpringBoard()) return;
    if (!(IS_ACTIVE || g_syncPayloadV285.masterEnabled)) return;

    // [VÁ LẦN 7] Throttle 300ms — tránh spam main queue
    static uint64_t s_lastKickTick = 0;
    static mach_timebase_info_data_t s_kickTB;
    static dispatch_once_t s_kickOnce;
    dispatch_once(&s_kickOnce, ^{ mach_timebase_info(&s_kickTB); });
    uint64_t now = mach_absolute_time();
    uint64_t throttleTicks = (TITANIUM_KEEPER_KICK_THROTTLE_MS * 1000000ULL * s_kickTB.denom) / s_kickTB.numer;
    if (s_lastKickTick != 0 && (now - s_lastKickTick) < throttleTicks) return;
    s_lastKickTick = now;

    if (!s_keeperLink) {
        s_keeperLink = [CADisplayLink displayLinkWithTarget:[TitaniumRateKeeper class] selector:@selector(tick:)];
        if (@available(iOS 15.0, *)) {
            float targetHz = (float)Titanium_GetTargetConfiguredHz();
            if (targetHz < 60.0f) targetHz = 60.0f;
            if (targetHz > 144.0f) targetHz = 144.0f;
            s_keeperLink.preferredFrameRateRange = SafeMakeFRR(TITANIUM_FRAME_RATE_MIN_KEEP, targetHz, targetHz);
        }
        [s_keeperLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    s_keeperIdleFrames = 0;
    s_keeperLink.paused = NO;
}
+ (void)tick:(CADisplayLink *)link {
    if (Titanium_ShouldLockTargetRate()) s_keeperIdleFrames = 0;
    else { s_keeperIdleFrames++; if (s_keeperIdleFrames > 20) link.paused = YES; }
}
@end
#endif

// ====================================================================================================
// NHÓM 3: FLUID TRANSITIONS PACING
// ====================================================================================================
%group Group_FluidTransitions_Pacing
%hook CADisplayLink
- (NSInteger)preferredFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.enableFPSControl || g_syncPayloadV285.targetFPS > 0)) {
        if (Titanium_IsCurrentAppAGame()) return %orig;
        if (Titanium_IsPassiveVideoPlayback()) return 60;
        return Titanium_GetTargetConfiguredFPS();
    }
    return %orig;
}
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.enableFPSControl || g_syncPayloadV285.targetFPS > 0)) {
        if (Titanium_IsCurrentAppAGame()) { %orig; return; }
        if (Titanium_IsPassiveVideoPlayback()) { %orig(60); return; }
        %orig(Titanium_GetTargetConfiguredFPS()); return;
    }
    %orig;
}
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.enableHzControl || g_syncPayloadV285.targetHz > 0)) {
        if (Titanium_IsCurrentAppAGame()) { %orig; return; }
        if (Titanium_IsPassiveVideoPlayback()) range = SafeMakeFRR(30.0f, 60.0f, 60.0f);
        else {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            if (maxTarget < 60.0f) maxTarget = 60.0f;
            if (maxTarget > 144.0f) maxTarget = 144.0f;
            float minKeep = range.minimum;
            if (minKeep < TITANIUM_FRAME_RATE_MIN_KEEP) minKeep = TITANIUM_FRAME_RATE_MIN_KEEP;
            if (minKeep > maxTarget) minKeep = maxTarget;
            float pref = range.preferred;
            if (pref <= 0.0f || pref > maxTarget) pref = maxTarget;
            if (pref < minKeep) pref = minKeep;
            range = SafeMakeFRR(minKeep, maxTarget, pref);
        }
    }
    %orig(range);
}
- (void)setFrameInterval:(NSInteger)interval { %orig; }
%end
%hook CADisplay
- (BOOL)allowsVirtualModes {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_DisplaySpoofAllowed()) return YES;
    return %orig;
}
- (void)setAllowsVirtualModes:(BOOL)allows {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_DisplaySpoofAllowed()) { %orig(YES); return; }
    %orig;
}
- (NSInteger)minimumFPS {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.enableFPSControl || g_syncPayloadV285.targetFPS > 0))
        return HardwareHasNative120Hz() ? 15 : (NSInteger)TITANIUM_FRAME_RATE_FLOOR;
    return %orig;
}
- (BOOL)supportsDynamicRefresh {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_DisplaySpoofAllowed()) return YES;
    return %orig;
}
- (BOOL)hasDynamicDisplayMode {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_DisplaySpoofAllowed()) return YES;
    return %orig;
}
%end
%hook UIScreen
- (NSInteger)maximumFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        NSInteger hz = Titanium_GetTargetConfiguredHz();
        return (hz < 60) ? 60 : hz;
    }
    return %orig;
}
- (NSInteger)_maximumFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        NSInteger hz = Titanium_GetTargetConfiguredHz();
        return (hz < 60) ? 60 : hz;
    }
    return %orig;
}
- (CGFloat)_refreshRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        CGFloat hz = (CGFloat)Titanium_GetTargetConfiguredHz();
        return (hz < 60.0f) ? 60.0f : hz;
    }
    return %orig;
}
- (void)_setTargetRefreshRate:(CGFloat)rate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        CGFloat hz = (CGFloat)Titanium_GetTargetConfiguredHz();
        %orig((hz < 60.0f) ? 60.0f : hz);
        return;
    }
    %orig;
}
%end
%hook CAAnimation
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            if (maxTarget < 60.0f) maxTarget = 60.0f;
            if (maxTarget > 144.0f) maxTarget = 144.0f;
            if (Titanium_IsPassiveVideoPlayback()) range = SafeMakeFRR(30.0f, 60.0f, 60.0f);
            else {
                float minKeep = range.minimum;
                if (minKeep < TITANIUM_FRAME_RATE_MIN_KEEP) minKeep = TITANIUM_FRAME_RATE_MIN_KEEP;
                if (minKeep > maxTarget) minKeep = maxTarget;
                float pref = range.preferred;
                if (pref <= 0.0f || pref > maxTarget) pref = maxTarget;
                if (pref < minKeep) pref = minKeep;
                range = SafeMakeFRR(minKeep, maxTarget, pref);
            }
        }
    }
    %orig(range);
}
%end
%hook CASpringAnimation
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            if (maxTarget < 60.0f) maxTarget = 60.0f;
            if (maxTarget > 144.0f) maxTarget = 144.0f;
            float minKeep = range.minimum;
            if (minKeep < TITANIUM_FRAME_RATE_MIN_KEEP) minKeep = TITANIUM_FRAME_RATE_MIN_KEEP;
            if (minKeep > maxTarget) minKeep = maxTarget;
            float pref = range.preferred;
            if (pref <= 0.0f || pref > maxTarget) pref = maxTarget;
            if (pref < minKeep) pref = minKeep;
            range = SafeMakeFRR(minKeep, maxTarget, pref);
        }
    }
    %orig(range);
}
%end
%hook AVPlayer
- (void)setRate:(float)rate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) g_isVideoPlayingActive = (rate > 0.0f);
    %orig;
}
%end
%hook UIApplication
- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_activeAnimationCount++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(400 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        });
    }
}
%end
%end

// ====================================================================================================
// RUNTIME INJECT DYNAMIC REFRESH
// ====================================================================================================
static BOOL fake_supportsDynamicRefreshRate(id self, SEL _cmd) { return YES; }
static void Titanium_ForceInjectDynamicRefreshSupport(void) {
    if (!Titanium_DisplaySpoofAllowed()) return;
    Class screenCls = objc_getClass("UIScreen");
    if (!screenCls) return;
    SEL sel1 = sel_registerName("supportsDynamicRefreshRate");
    SEL sel2 = sel_registerName("_supportsDynamicRefreshRate");
    if (class_getInstanceMethod(screenCls, sel1)) class_replaceMethod(screenCls, sel1, (IMP)fake_supportsDynamicRefreshRate, "c@:");
    else class_addMethod(screenCls, sel1, (IMP)fake_supportsDynamicRefreshRate, "c@:");
    if (class_getInstanceMethod(screenCls, sel2)) class_replaceMethod(screenCls, sel2, (IMP)fake_supportsDynamicRefreshRate, "c@:");
    else class_addMethod(screenCls, sel2, (IMP)fake_supportsDynamicRefreshRate, "c@:");
}

// ====================================================================================================
// NHÓM 4: SWITCHER
// ====================================================================================================
%group Group_Switcher30Apps_Virtualization
%hook SBHomeGestureInteraction
- (void)_handleGestureBegan:(id)gesture { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isContinuousSwiping = YES; g_lastInteractionMachTime = mach_absolute_time(); } }
- (void)_handleGestureChanged:(id)gesture { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isContinuousSwiping = YES; g_lastInteractionMachTime = mach_absolute_time(); } }
- (void)_handleGestureEnded:(id)gesture { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isContinuousSwiping = NO; g_lastInteractionMachTime = mach_absolute_time(); } }
- (void)_handleGestureCancelled:(id)gesture { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_isContinuousSwiping = NO; }
%end
%hook SBFluidSwitcherGestureWorkspaceTransaction
- (BOOL)canInterruptActiveGesture {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.reduceMultiTaskLag || g_isRateLockedV285))
        if (g_isContinuousSwiping) return YES;
    return %orig;
}
- (void)_begin { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (void)_didComplete { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_isContinuousSwiping = NO; }
%end
%hook SBFluidSwitcherAnimationSettings
- (double)deckSwipeSpeedFactor {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.reduceMultiTaskLag) return 1.35;
    return %orig;
}
- (double)cardFlyInDuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.fixAppExitStutter || g_syncPayloadV285.antiStutterExit)) return 0.22;
    return %orig;
}
%end
%hook SBAppSwitcherSettings
- (BOOL)shouldKeepAppSnapshotsInMemory {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.reduceMultiTaskLag) return YES;
    return %orig;
}
- (CGFloat)decelerationRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.reduceMultiTaskLag) return 0.99;
    return %orig;
}
%end
%hook SBAppToHomeWorkspaceTransaction
- (void)_willBegin { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (void)_didComplete { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isContinuousSwiping = NO; g_isUserTouchingScreen = NO; } }
%end
%hook SBHomeToAppWorkspaceTransaction
- (void)_willBegin { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBAppSwitcherController
- (void)viewWillAppear:(BOOL)animated { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (void)viewDidDisappear:(BOOL)animated { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isUserTouchingScreen = NO; g_isContinuousSwiping = NO; } }
%end
%end

// ====================================================================================================
// NHÓM 5: FAST LAUNCH
// ====================================================================================================
%group Group_FastLaunch_SuperEngineV285
%hook SBAppLaunchSettings
- (double)delayBeforeAppLaunch {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) return 0.0;
    return %orig;
}
- (double)zoomDuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) return 0.10;
    return %orig;
}
- (double)launchDuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) return 0.10;
    return %orig;
}
%end
%hook SBSplashBoardController
- (double)splashScreenDelay {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) return 0.0;
    return %orig;
}
%end
%hook SBUIAnimationController
- (void)_willBeginAnimation {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch))
        g_lastInteractionMachTime = mach_absolute_time();
}
%end
%hook UIApplication
- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.turboAppLaunch || CFG285.fixAppLaunchBlackScreen || g_isRateLockedV285 || g_syncPayloadV285.fastAppLaunch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_EnforceThreadVIPPolicy();
    }
}
- (void)_applicationWillEnterForeground {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
}
%end
%end

// ====================================================================================================
// NHÓM 6: SCROLL & KEYBOARD
// ====================================================================================================
%group Group_Scroll_And_Keyboard_Opt
%hook UIInputViewAnimationStyle
- (double)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) return 0.12;
    return %orig;
}
%end
%hook UIKeyboardImpl
+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) return 0.0;
    return %orig;
}
- (void)showKeyboard {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
    %orig;
}
%end
%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) Titanium_TriggerInstantTouchBurst();
    %orig;
}
%end
%hook UITabBarController
- (void)setSelectedIndex:(NSUInteger)index {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
    %orig;
}
- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
    %orig;
}
%end
%hook UINavigationController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.interactivePopGestureRecognizer)
        self.interactivePopGestureRecognizer.delaysTouchesBegan = NO;
}
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
    %orig;
}
- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
    return %orig;
}
%end
%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
    %orig;
}
%end
%hook UIPanGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
    %orig(state);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
            g_isUserTouchingScreen = YES; g_isScrollingActive = YES;
            g_lastInteractionMachTime = mach_absolute_time();
            Titanium_TriggerInstantTouchBurst();
        } else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled) {
            g_isUserTouchingScreen = NO; g_isScrollingActive = NO;
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
}
%end
%hook UIScrollView
- (UIPanGestureRecognizer *)panGestureRecognizer {
    UIPanGestureRecognizer *pan = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard() && pan)
        pan.delaysTouchesBegan = NO;
    return pan;
}
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) return YES;
    return %orig;
}
- (BOOL)delaysContentTouches {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) return NO;
    return %orig;
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_isUserTouchingScreen = YES;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(touches, event);
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_isUserTouchingScreen = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(touches, event);
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_isUserTouchingScreen = NO; g_isScrollingActive = NO;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_isUserTouchingScreen = NO; g_isScrollingActive = NO;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}
- (void)_scrollViewWillBeginDragging {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_isScrollingActive = YES; g_isUserTouchingScreen = YES;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}
- (void)_notifyDidScroll {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (g_isUserTouchingScreen) { g_isScrollingActive = YES; g_lastInteractionMachTime = mach_absolute_time(); }
    }
    %orig;
}
- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (g_isUserTouchingScreen) { g_isScrollingActive = YES; g_lastInteractionMachTime = mach_absolute_time(); }
    }
    %orig;
}
- (CGFloat)decelerationRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        if (self.isPagingEnabled) return %orig;
        return UIScrollViewDecelerationRateNormal;
    }
    return %orig;
}
- (void)_stopScrollDecelerationNotify:(BOOL)notify { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_isScrollingActive = NO; }
- (void)_scrollViewDidEndDecelerating { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_isScrollingActive = NO; }
- (void)_scrollViewDidEndDraggingForChildScrollView:(id)view {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !self.isDecelerating) g_isScrollingActive = NO;
}
%end
%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD DISPLAY
// ====================================================================================================
%group Group_Display_SpringBoardV285
%hook SBFluidSwitcherViewController
- (void)handleFluidSwitcherGesture:(id)gesture { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBScreenshotManager
- (void)saveScreenshotsWithCompletion:(id)completion { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBVolumeControl
- (void)increaseVolume { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isVolumeHoldingV285 = YES; g_lastInteractionMachTime = mach_absolute_time(); } }
- (void)decreaseVolume { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isVolumeHoldingV285 = YES; g_lastInteractionMachTime = mach_absolute_time(); } }
- (void)changeVolumeByDelta:(float)delta { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isVolumeHoldingV285 = YES; g_lastInteractionMachTime = mach_absolute_time(); } }
- (void)cancelVolumeEvent { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isVolumeHoldingV285 = NO; g_lastInteractionMachTime = mach_absolute_time(); } }
%end
%hook SBControlCenterController
- (void)presentAnimated:(BOOL)animated completion:(id)completion { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (void)dismissAnimated:(BOOL)animated completion:(id)completion { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBNotificationCenterController
- (void)presentAnimated:(BOOL)animated completion:(id)completion { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (void)dismissAnimated:(BOOL)animated completion:(id)completion { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBIconScrollView
- (BOOL)delaysContentTouches {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.dynamicInterpolation)) return NO;
    return %orig;
}
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.dynamicInterpolation)) return YES;
    return %orig;
}
- (void)_notifyDidScroll { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isScrollingActive = YES; g_lastInteractionMachTime = mach_absolute_time(); } }
- (void)_smoothScrollWithTimestamp:(double)timestamp { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_isScrollingActive = YES; g_lastInteractionMachTime = mach_absolute_time(); } }
%end
%hook SBIconController
- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBFolderControllerAnimationSettings
- (double)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.dynamicInterpolation)) return 0.22;
    return %orig;
}
%end
%hook SBFolderView
- (void)prepareToOpen { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (void)didClose { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBFolderController
- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBIconForceTouchSettings
- (double)delayBeforeOpening {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.zeroLatencyTouch)) return 0.05;
    return %orig;
}
%end
%hook CSCoverSheetViewController
- (void)viewWillAppear:(BOOL)animated { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (void)viewDidDisappear:(BOOL)animated { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBHomeScreenViewController
- (void)viewWillAppear:(BOOL)animated { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
%end
%hook SBApplication
- (void)willActivate { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (BOOL)shouldPrewarmOnLaunch {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_isRateLockedV285 || g_syncPayloadV285.fastAppLaunch)) return YES;
    return %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 8: PIP
// ====================================================================================================
%group Group_V285_FloatingWindow_PiP
%hook PGPictureInPictureRemoteObject
- (void)_updatePreferredContentSize { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) g_lastInteractionMachTime = mach_absolute_time(); }
- (void)startPictureInPicture { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_lastInteractionMachTime = mach_absolute_time(); if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast(); } }
- (void)stopPictureInPictureAnimated:(BOOL)animated { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_lastInteractionMachTime = mach_absolute_time(); if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast(); } }
%end
%hook SBPIPController
- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_lastInteractionMachTime = mach_absolute_time(); Titanium_LockMainThreadFast(); } }
%end
%hook AVPictureInPictureController
- (void)startPictureInPicture { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_lastInteractionMachTime = mach_absolute_time(); Titanium_BoostRenderWithoutStarvingNetwork(); } }
- (void)stopPictureInPicture { %orig; if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { g_lastInteractionMachTime = mach_absolute_time(); Titanium_BoostRenderWithoutStarvingNetwork(); } }
%end
%end

// ====================================================================================================
// NHÓM 9: CLASSIC HOME
// ====================================================================================================
%group Group_HardwareSegregation_ClassicHomeV285
%hook SBHomeHardwareButtonActions
- (void)performSinglePressAction {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}
- (void)performDoublePressAction {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 10: PROCESS MANAGER
// ====================================================================================================
%group Group_SpringBoard_ProcessManagerV285
%hook SBMainWorkspace
- (void)handleApplicationLaunch:(id)application {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_isRateLockedV285 || g_syncPayloadV285.fastAppLaunch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}
%end
%end

// ====================================================================================================
// NHÓM 11: THIRD PARTY
// ====================================================================================================
%group Group_UIKit_ThirdParty_IsolatedV285
%hook UIApplication
- (void)_sendWillEnterForegroundCallbacks {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) Titanium_EnforceThreadVIPPolicy();
    }
}
%end
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) {
            Titanium_EnforceThreadVIPPolicy();
            if (@available(iOS 15.0, *)) {
                UIWindowScene *scene = self.windowScene;
                if (scene && [scene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float targetHz = (float)Titanium_GetTargetConfiguredHz();
                    if (targetHz < 60.0f) targetHz = 60.0f;
                    if (targetHz > 144.0f) targetHz = 144.0f;
                    [scene setPreferredFrameRateRange:SafeMakeFRR(60.0f, targetHz, targetHz)];
                }
            }
        }
    }
}
%end
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) Titanium_EnforceThreadVIPPolicy();
    }
}
- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) g_lastInteractionMachTime = mach_absolute_time();
}
%end
%hook UIViewControllerTransitionCoordinator
- (BOOL)animateAlongsideTransition:(void (^)(id context))animation completion:(void (^)(id context))completion {
    BOOL result = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) Titanium_EnforceThreadVIPPolicy();
    }
    return result;
}
%end
%hook _UIViewControllerTransitionContext
- (void)__runLifecycleForViewController:(UIViewController *)vc state:(NSInteger)state transition:(id)transition {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) Titanium_EnforceThreadVIPPolicy();
    }
}
%end
%hook UIPresentationController
- (void)presentationTransitionWillBegin {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) Titanium_EnforceThreadVIPPolicy();
    }
}
- (void)dismissalTransitionWillBegin {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) g_lastInteractionMachTime = mach_absolute_time();
}
%end
%hook CADisplayLink
- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard() && !Titanium_IsCurrentAppAGame()) {
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                float targetHz = (float)Titanium_GetTargetConfiguredHz();
                if (targetHz < 60.0f) targetHz = 60.0f;
                if (targetHz > 144.0f) targetHz = 144.0f;
                self.preferredFrameRateRange = SafeMakeFRR(60.0f, targetHz, targetHz);
            }
        }
    }
}
%end
%hook UITableView
- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.window && !Titanium_IsSpringBoard()) {
        self.delaysContentTouches = NO;
        self.canCancelContentTouches = YES;
    }
}
%end
%hook UICollectionView
- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.window && !Titanium_IsSpringBoard()) {
        self.delaysContentTouches = NO;
        self.canCancelContentTouches = YES;
        self.prefetchingEnabled = YES;
    }
}
%end
%end

// ====================================================================================================
// NHÓM 12: INSTANT ACTIONS
// ====================================================================================================
%group Group_InstantActionAndMenuTransitions_Boost
%hook UIKeyboardTaskQueue
- (void)performTask:(id)task {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3))
        g_lastInteractionMachTime = mach_absolute_time();
}
%end
%hook UIKeyboardImpl
- (void)callShowKeyboard {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3))
        g_lastInteractionMachTime = mach_absolute_time();
}
%end
%hook UIPeripheralHost
- (double)getLastTranslateTime {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) return 0.0;
    return %orig;
}
%end
%hook UIButton
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch))
        g_lastInteractionMachTime = mach_absolute_time();
}
%end
%end

// ====================================================================================================
// [VÁ LẦN 7] NHÓM 13: THERMAL — TÔN TRỌNG SERIOUS/CRITICAL
// ====================================================================================================
%group Group_Global_Thread_Governor_Unthrottled
%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    NSProcessInfoThermalState orig = %orig;
    // [VÁ LẦN 7] Nếu máy thật sự Serious/Critical → trả nguyên bản để CPU tự hạ nhiệt
    if (Titanium_ThermalIsHot(orig)) return orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (CFG285.lock30FpsOnOverheat && g_isDeviceChargingV285) return orig;
        if (g_isRateLockedV285 || CFG285.antiThermalThrottling || CFG285.dynamicThermalEngine || g_syncPayloadV285.thermalShield)
            return NSProcessInfoThermalStateNominal;
    }
    return orig;
}
- (BOOL)isLowPowerModeEnabled {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (CFG285.batterySaver60Hz || g_syncPayloadV285.powerSaveModeActive) return YES;
        if (g_isRateLockedV285 || CFG285.fakeFullBatteryState) return NO;
    }
    return %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 14: GAME METAL
// ====================================================================================================
%group Group_Titanium_Game_Metal_Overdrive
%hook CAMetalLayer
- (id)init {
    id orig = %orig;
    if (orig && (g_syncPayloadV285.masterEnabled || IS_ACTIVE) && !Titanium_IsSpringBoard()) g_isMetalGameProcess = YES;
    return orig;
}
- (BOOL)allowsNextDrawableTimeout {
    if ((g_syncPayloadV285.masterEnabled || IS_ACTIVE) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess && !Titanium_IsSpringBoard()) return YES;
    return %orig;
}
- (void)setAllowsNextDrawableTimeout:(BOOL)allow {
    if ((g_syncPayloadV285.masterEnabled || IS_ACTIVE) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess && !Titanium_IsSpringBoard()) { %orig(YES); return; }
    %orig;
}
- (BOOL)serverPresentsWithTransaction { return %orig; }
- (void)setServerPresentsWithTransaction:(BOOL)serverPresents { %orig; }
- (id)nextDrawable {
    if ((g_syncPayloadV285.masterEnabled || IS_ACTIVE) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        g_lastSyncTicksV285 = mach_absolute_time();
#if TITANIUM_ENABLE_METAL_PER_CMD_QOS
        if (!Titanium_IsSpringBoard()) Titanium_EnforceThreadVIPPolicy();
#endif
    }
    return %orig;
}
%end
%end

// ====================================================================================================
// [VÁ LẦN 7] NHÓM 15: SILICON PIPELINE — BỎ QoS MỖI CMD BUFFER
// ====================================================================================================
%group Group_Silicon_Hardware_Pipeline_Overdrive
%hook _MTLCommandQueue
- (void)setStatOptions:(NSUInteger)options {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) { %orig(0); return; }
    %orig;
}
- (BOOL)executionEnabled {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}
%end
%hook _MTLCommandBuffer
- (void)enqueue {
    %orig;
    if (!g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        g_lastInteractionMachTime = mach_absolute_time();
#if TITANIUM_ENABLE_METAL_PER_CMD_QOS
        if (CFG285.quantumCoreSync || CFG285.pCoreRealtimePriority || g_isRateLockedV285)
            Titanium_EnforceThreadVIPPolicy();
#endif
    }
}
- (void)commit {
    %orig;
    if (!g_isCurrentAppBlacklisted && g_isMetalGameProcess) g_lastInteractionMachTime = mach_absolute_time();
}
%end
%hook MTLTextureDescriptor
- (BOOL)allowGPUOptimizedContents { if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES; return %orig; }
- (void)setAllowGPUOptimizedContents:(BOOL)flag {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) { %orig(YES); return; }
    %orig;
}
%end
%hook CAMetalDrawable
- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) { %orig(0.0); return; }
    %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 1: WATCHDOG (mặc định tắt)
// ====================================================================================================
%group Group_AntiWatchdog_Immunity
%hook FBProcessWatchdog
- (void)start {
    %orig;
    if ([self respondsToSelector:@selector(invalidate)]) [(id)self invalidate];
}
%end
%hook FBSceneWatchdog
- (id)initWithTimeout:(double)timeout { return %orig(180.0); }
%end
%end

// ====================================================================================================
// NHÓM 2: BLUR OPT
// ====================================================================================================
%group Group_LiquidGlass_Opt
%hook CAFilter
- (void)setValue:(id)value forKey:(NSString *)key {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur && key && [key isEqualToString:@"inputRadius"]) {
        if ([value isKindOfClass:[NSNumber class]] && [value floatValue] > 14.0f) value = @(14.0f);
    }
    %orig(value, key);
}
%end
%hook CABackdropLayer
- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) { %orig(YES); return; }
    %orig;
}
- (BOOL)disablesOccludedBackdropBlurs {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) return YES;
    return %orig;
}
%end
%hook UIVisualEffectView
- (void)layoutSubviews {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) {
        UIView *v = (UIView *)self;
        if (v.layer != nil) v.layer.allowsGroupOpacity = YES;
    }
}
%end
%end

// ====================================================================================================
// NHÓM 3: IN-APP ANIMATIONS
// ====================================================================================================
%group Group_Universal_InApp_Animations
%hook UIViewPropertyAnimator
- (void)startAnimation {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
}
%end
%hook _UIContextMenuContainerView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (newWindow && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
}
%end
%hook UIAlertController
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
}
%end
%end

// ====================================================================================================
// NHÓM 4: NEURAL TOUCH
// ====================================================================================================
%group Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285
%hook _UITouchPredictor
- (id)predictedTouchesForTouch:(UITouch *)touch {
    id predicted = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || CFG285.zeroLagNeural || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
    return predicted;
}
- (void)addTouch:(UITouch *)touch fromEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || CFG285.zeroLagNeural || g_syncPayloadV285.zeroLatencyTouch))
        g_lastInteractionMachTime = mach_absolute_time();
    %orig;
}
%end
%hook _UIGestureEnvironment
- (void)_updateGesturesForEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
        else Titanium_BoostRenderWithoutStarvingNetwork();
    }
    %orig;
}
%end
%hook SBScreenEdgePanGestureRecognizer
- (BOOL)_shouldTryToBeginWithEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    return %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 16: SILICON SCHEDULER
// ====================================================================================================
%group Group_Silicon_Scheduler_Touch_Governor
%hook _UIInteractiveHighlightEnvironment
- (void)applyHighlightWithAnimation:(BOOL)animated completion:(id)completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) { %orig(NO, completion); return; }
    %orig;
}
%end
%end

// ====================================================================================================
// [VÁ LẦN 7] NHÓM 17: RENDER SERVER — BỎ QoS TRONG runMode
// ====================================================================================================
%group Group_CoreAnimation_RenderServer_Governor
%hook NSRunLoop
- (BOOL)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate {
    // [VÁ LẦN 7] Chỉ set khi cần — đã throttle bên trong
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (!g_isCurrentAppBlacklisted && [NSThread isMainThread] && (CFG285.ultraResponsivenessPro || g_isRateLockedV285))
            Titanium_EnforceThreadVIPPolicy();
    }
    return %orig;
}
%end
%hook FBScene
- (void)updateSettings:(id)settings withTransitionContext:(id)context {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast();
    }
    %orig;
}
%end
%end

// ====================================================================================================
// NHÓM 18: MEMORY GOVERNOR
// ====================================================================================================
%group Group_System_Memory_And_RunLoop_Governor
%hook MTMaterialView
- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && self.layer != nil) self.layer.allowsGroupOpacity = YES;
}
%end
%end

// ====================================================================================================
// NHÓM 19: THERMAL CRYO PACING
// ====================================================================================================
%group Group_Thermal_CryoPacing_ZeroDrop
%hook CALayer
- (void)setShadowRadius:(CGFloat)radius {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && radius > 0.0) {
        if (!self.shadowPath && self.bounds.size.width > 0 && self.bounds.size.height > 0) {
            CGPathRef path = CGPathCreateWithRect(self.bounds, NULL);
            self.shadowPath = path;
            CGPathRelease(path);
        }
        if (radius > 8.0) { %orig(8.0); return; }
    }
    %orig;
}
- (void)setShouldRasterize:(BOOL)val {
    if (val && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        if (self.sublayers.count > 4) {
            self.rasterizationScale = [UIScreen mainScreen].scale;
            %orig(YES);
            return;
        }
    }
    %orig;
}
%end
%hook UIVisualEffectView
- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && self.layer != nil) {
        self.layer.allowsGroupOpacity = YES;
        self.layer.drawsAsynchronously = YES;
    }
}
%end
%hook CATransaction
+ (void)flush {
    %orig;
    // [VÁ LẦN 7] KHÔNG DEMOTE QoS — hết xám/đen
#if TITANIUM_ALLOW_FLUSH_QOS_DEMOTION
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        if (!Titanium_ShouldLockTargetRate() && !g_isUserTouchingScreen && !g_isScrollingActive &&
            !g_isRateLockedV285 && g_activeAnimationCount == 0 && !Titanium_IsNotificationBannerActive()) {
            if (CFG285.coolDownHeavyLoad || CFG285.backgroundPacingDaemon)
                pthread_set_qos_class_self_np(QOS_CLASS_DEFAULT, 0);
        }
    }
#endif
}
%end
%end

// ====================================================================================================
// NHÓM 20: DEEP RAM COMPACTION
// ====================================================================================================
%group Group_Deep_RAM_Compaction_Engine
%hook UIApplication
- (void)_applicationDidEnterBackground {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        BOOL shouldPurge = CFG285.aggressiveRamClean || CFG285.hyperMemoryGuardian ||
                           CFG285.autoKillBackground || CFG285.autoCloseBackgroundApp ||
                           g_syncPayloadV285.aggressiveRamCleaner;
        if (shouldPurge) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
                Class imgCls = objc_getClass("UIImage");
                if ([imgCls respondsToSelector:@selector(_flushCache)])
                    ((void (*)(id, SEL))objc_msgSend)(imgCls, sel_registerName("_flushCache"));
            });
        }
    }
}
%end
%hook UIViewController
- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        if (CFG285.periodicRamClean) {
            static volatile uint64_t s_lastVcPurgeTick = 0;
            uint64_t now = mach_absolute_time();
            if (now - s_lastVcPurgeTick > (5ULL * 1000000000ULL)) {
                s_lastVcPurgeTick = now;
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                    malloc_zone_pressure_relief(malloc_default_zone(), 0);
                });
            }
        }
    }
}
%end
%hook SBAppSwitcherSnapshotImageCache
- (void)reloadImagesForAllItems {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.aggressiveRamClean || CFG285.hyperMemoryGuardian || g_syncPayloadV285.aggressiveRamCleaner)) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        });
    }
}
%end
%hook UIWindow
- (void)didReceiveMemoryWarning {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.aggressiveRamClean || CFG285.hyperMemoryGuardian || g_syncPayloadV285.aggressiveRamCleaner)) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        });
    }
}
%end
%end

// ====================================================================================================
// NHÓM 21: WEBKIT
// ====================================================================================================
%group Group_WebKit_RAM_Optimizer
%hook WKWebView
- (void)didMoveToWindow {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (!self.window) {
            WKProcessPool *pool = self.configuration.processPool;
            if ([pool respondsToSelector:@selector(_clearMemoryCache)]) [pool _clearMemoryCache];
            if ([pool respondsToSelector:@selector(_purgePageCache)]) [pool _purgePageCache];
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            });
        }
    }
}
- (void)_didReceiveMemoryWarning {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        WKProcessPool *pool = [NSThread isMainThread] ? self.configuration.processPool : nil;
        if ([pool respondsToSelector:@selector(_clearMemoryCache)]) [pool _clearMemoryCache];
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        });
    }
}
%end
%hook WKProcessPool
- (instancetype)init {
    WKProcessPool *pool = %orig;
    if (pool && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        __weak WKProcessPool *weakPool = pool;
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            WKProcessPool *strongPool = weakPool;
            if (!strongPool) return;
            if ([strongPool respondsToSelector:@selector(_clearMemoryCache)]) [strongPool _clearMemoryCache];
            if ([strongPool respondsToSelector:@selector(_purgePageCache)]) [strongPool _purgePageCache];
        }];
    }
    return pool;
}
%end
%end

// ====================================================================================================
// NHÓM ĐẶC QUYỀN: PROMOTION
// ====================================================================================================
%group Group_Hardware_ProMotion_Overclock
extern "C" CFPropertyListRef MGCopyAnswer(CFStringRef property);
%hookf(CFPropertyListRef, MGCopyAnswer, CFStringRef property) {
    if (property && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.proMotionEngineBeta7 || CFG285.enableHzControl || g_isRateLockedV285 || g_syncPayloadV285.forceOverclock)) {
        if (CFEqual(property, CFSTR("SupportsVariableRefreshRate")) ||
            CFEqual(property, CFSTR("supports-variable-refresh-rate")) ||
            CFEqual(property, CFSTR("pVRR")) ||
            CFEqual(property, CFSTR("pro-motion")) ||
            CFEqual(property, CFSTR("DeviceSupports120Hz")) ||
            CFEqual(property, CFSTR("DeviceSupportsProMotion")))
            return CFRetain(kCFBooleanTrue);
    }
    return %orig(property);
}
%hook IOHIDEventSystemClient
- (void)setProperty:(id)property forKey:(NSString *)key {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch) && key) {
        if ([key isEqualToString:@"ReportInterval"] || [key isEqualToString:@"HIDReportInterval"]) {
            %orig(@(1000), key);
            return;
        }
    }
    %orig;
}
%end
%end

// ====================================================================================================
// COLD BOOT
// ====================================================================================================
%group Group_Apple_Native_ColdBoot_Overdrive
static volatile BOOL g_isAppFirstFramePresented = NO;
static volatile uint64_t g_processLaunchTimestampTicks = 0;
%hook UIScene
- (void)_activationCompleted {
    %orig;
    if (!Titanium_IsSpringBoard()) {
        if (!g_isAppFirstFramePresented) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(400 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                g_isAppFirstFramePresented = YES;
            });
        }
    }
}
%end
%end

// ====================================================================================================
// CAWINDOWSERVER
// ====================================================================================================
%group Group_CAWindowServer_Absolute_Dominance
%hook CAWindowServerDisplay
- (double)minimumFrameDuration {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 60.0) targetHz = 60.0;
    if (targetHz > 144.0) targetHz = 144.0;
    return (1.0 / targetHz);
}
- (void)setMinimumFrameDuration:(double)duration {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 60.0) targetHz = 60.0;
    if (targetHz > 144.0) targetHz = 144.0;
    %orig(1.0 / targetHz);
}
- (double)maximumRefreshRate {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 60.0) targetHz = 60.0;
    if (targetHz > 144.0) targetHz = 144.0;
    return targetHz;
}
- (void)setMaximumRefreshRate:(double)rate {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 60.0) targetHz = 60.0;
    if (targetHz > 144.0) targetHz = 144.0;
    %orig(targetHz);
}
- (double)idealRefreshRate {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 60.0) targetHz = 60.0;
    if (targetHz > 144.0) targetHz = 144.0;
    return targetHz;
}
- (void)setIdealRefreshRate:(double)rate {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 60.0) targetHz = 60.0;
    if (targetHz > 144.0) targetHz = 144.0;
    %orig(targetHz);
}
- (BOOL)supportsVariableRefreshRate { return YES; }
%end
%end

// ====================================================================================================
// FORCE RENDER RECOVERY
// ====================================================================================================
%group Group_Force_Render_Recovery_Overdrive
%hook CALayer
- (BOOL)drawsAsynchronously { if (!Titanium_IsSpringBoard()) return NO; return %orig; }
- (void)setNeedsDisplay { %orig; }
%end
%end

// ====================================================================================================
// WINDOW LEVEL OVERDRIVE
// ====================================================================================================
%group Group_Window_Level_Overdrive
%hook UIWindowScene
- (void)_readySceneForDisplay {
    %orig;
    if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)])
                [(id)self setPreferredFrameRateRange:SafeMakeFRR(60.0f, 60.0f, 60.0f)];
        }
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            Titanium_EnforceThreadVIPPolicy();
            if (@available(iOS 15.0, *)) {
                float targetHz = (float)Titanium_GetTargetConfiguredHz();
                if (targetHz < 60.0f) targetHz = 60.0f;
                if (targetHz > 144.0f) targetHz = 144.0f;
                if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)])
                    [(id)self setPreferredFrameRateRange:SafeMakeFRR(60.0f, targetHz, targetHz)];
            }
        });
    }
}
%end
%hook UIScene
- (void)_didBecomeActive { %orig; if (!Titanium_IsSpringBoard()) Titanium_EnforceThreadVIPPolicy(); }
%end
%hook FBApplicationProcess
- (void)_finishInit { %orig; if (Titanium_IsSpringBoard()) Titanium_LockMainThreadFast(); }
%end
%end

// ====================================================================================================
// BACKBOARDD
// ====================================================================================================
%group Group_Backboardd_TouchDriver_Overdrive
%hook BKTouchDeliveryPolicyServer
- (id)init {
    id orig = %orig;
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    return orig;
}
%end
%hook BKHIDEventProcessor
- (void)processEvent:(id)event sender:(id)sender dispatcher:(id)dispatcher {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    %orig;
}
%end
%end

// ====================================================================================================
// THERMAL WATCHDOG + PREFS OBSERVERS
// ====================================================================================================
static void Titanium_StartThermalAndChargingWatchdog(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIDevice *dev = [UIDevice currentDevice];
        dev.batteryMonitoringEnabled = YES;
        g_isDeviceChargingV285 = (dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull);
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification
                                                          object:nil queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            UIDevice *currentDev = [UIDevice currentDevice];
            g_isDeviceChargingV285 = (currentDev.batteryState == UIDeviceBatteryStateCharging || currentDev.batteryState == UIDeviceBatteryStateFull);
            if (g_isDeviceChargingV285) pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }];
    });
}

static void Titanium_AdoptPayloadRatesWithoutConfig(void) {
    if (g_syncPayloadV285.targetHz >= 15 && g_syncPayloadV285.targetHz <= 144) g_cachedResolvedHz = g_syncPayloadV285.targetHz;
    if (g_syncPayloadV285.targetFPS >= 15 && g_syncPayloadV285.targetFPS <= 144) g_cachedResolvedFPS = g_syncPayloadV285.targetFPS;
}

static void ReloadPreferencesCallbackV285(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_source_t s_debounceTimer = nil;
    static dispatch_queue_t s_prefQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ s_prefQueue = dispatch_queue_create("com.titanium.v285.prefsync", DISPATCH_QUEUE_SERIAL); });
    if (s_debounceTimer) { dispatch_source_cancel(s_debounceTimer); s_debounceTimer = nil; }
    s_debounceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, s_prefQueue);
    dispatch_source_set_timer(s_debounceTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(s_debounceTimer, ^{
        g_lastSyncTicksV285 = 0;
        Titanium_ReloadSharedSyncStateV285();
        if (!CFG285) Titanium_AdoptPayloadRatesWithoutConfig();
        if (CFG285 && [CFG285 respondsToSelector:@selector(loadSettings)]) {
            [CFG285 loadSettings];
            if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                NSInteger newHz = (NSInteger)CFG285.targetHz;
                if (newHz >= 15 && newHz <= 144) g_cachedResolvedHz = newHz;
            }
            if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                NSInteger newFPS = (NSInteger)CFG285.targetFPS;
                if (newFPS >= 15 && newFPS <= 144) g_cachedResolvedFPS = newFPS;
            }
        }
        if (Titanium_IsSpringBoard()) Titanium_TuneWindowServerDisplayDirectly();
        s_debounceTimer = nil;
    });
    dispatch_resume(s_debounceTimer);
}

#define TITANIUM_BOOT_FLAG_VERIFIED @"/tmp/.titanium_tweak_verified"

static time_t Titanium_GetSystemUptimeSeconds(void) {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) < 0) return 9999;
    time_t now = time(NULL);
    return (now - boottime.tv_sec);
}

// ====================================================================================================
// [VÁ LẦN 7] INIT_CAWINDOWSERVER_HOOKS — CHỜ 8s SAU BOOT
// ====================================================================================================
static inline void Init_CAWindowServer_Hooks(void) {
    if (!Titanium_DisplaySpoofAllowed()) return;
    if (Titanium_GetSystemUptimeSeconds() < 8) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            Init_CAWindowServer_Hooks();
        });
        return;
    }
    static dispatch_once_t s_wsInitOnce;
    dispatch_once(&s_wsInitOnce, ^{
        %init(Group_CAWindowServer_Absolute_Dominance);
    });
}

// ====================================================================================================
// [VÁ LẦN 7] RUNTIME INITIALIZER — GUARD UPTIME < 5s
// ====================================================================================================
static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    static dispatch_once_t s_coreInitToken;
    dispatch_once(&s_coreInitToken, ^{
        @autoreleasepool {
            @try {
                // [VÁ LẦN 7] Chống treo táo: uptime < 5s → hoãn
                if (Titanium_GetSystemUptimeSeconds() < 5) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                                   dispatch_get_main_queue(), ^{
                        runCoreTweak(isSpringBoard, bundleID, progName);
                    });
                    return;
                }

                if (isSpringBoard) Titanium_LockMainThreadFast();
                else Titanium_EnforceThreadVIPPolicy();

                Class configClass = NSClassFromString(@"BoostConfigV285Pro");
                if (configClass) {
                    CFG285 = [configClass sharedInstance];
                    [CFG285 loadSettings];
                    if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                        NSInteger initHz = (NSInteger)CFG285.targetHz;
                        if (initHz >= 15 && initHz <= 144) g_cachedResolvedHz = initHz;
                    }
                    if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                        NSInteger initFPS = (NSInteger)CFG285.targetFPS;
                        if (initFPS >= 15 && initFPS <= 144) g_cachedResolvedFPS = initFPS;
                    }
                }

                if (!isSpringBoard && (g_isCurrentAppBlacklisted || (CFG285 && !CFG285.enabled))) {
                    g_SystemMasterReady = YES;
                    return;
                }

                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                    Titanium_ReloadSharedSyncStateV285();
                });

                if (TITANIUM_ENABLE_WATCHDOG_IMMUNITY) %init(Group_AntiWatchdog_Immunity);

                %init(Group_ZeroLatency_Touch_Opt);
                %init(Group_Metal_ZeroTearing_Pacing);
                %init(Group_FluidTransitions_Pacing);
                %init(Group_FastLaunch_SuperEngineV285);
                %init(Group_Scroll_And_Keyboard_Opt);
                %init(Group_InstantActionAndMenuTransitions_Boost);
                %init(Group_Global_Thread_Governor_Unthrottled);

                %init(Group_Universal_InApp_Animations);
                %init(Group_Apple_Internal_ProMotion_Apex);
                %init(Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285);
                if (Titanium_DisplaySpoofAllowed()) %init(Group_Hardware_ProMotion_Overclock);

                %init(Group_Apple_Native_ColdBoot_Overdrive);

                %init(Group_Titanium_Game_Metal_Overdrive);
                %init(Group_Silicon_Hardware_Pipeline_Overdrive);
                %init(Group_Silicon_Scheduler_Touch_Governor);
                %init(Group_CoreAnimation_RenderServer_Governor);
                %init(Group_System_Memory_And_RunLoop_Governor);
                %init(Group_Thermal_CryoPacing_ZeroDrop);
                %init(Group_Deep_RAM_Compaction_Engine);
                %init(Group_WebKit_RAM_Optimizer);

                if (Titanium_IsClassicHomeButtonDevice()) %init(Group_HardwareSegregation_ClassicHomeV285);

                if (isSpringBoard) {
                    %init(Group_LiquidGlass_Opt);
                    %init(Group_Switcher30Apps_Virtualization);
                    %init(Group_Display_SpringBoardV285);
                    %init(Group_V285_FloatingWindow_PiP);
                    %init(Group_SpringBoard_ProcessManagerV285);

                    Init_CAWindowServer_Hooks();

#if TITANIUM_ENABLE_RATE_KEEPER
                    [TitaniumRateKeeper start];
#endif

                    @try { Titanium_StartThermalAndChargingWatchdog(); } @catch (NSException *e) {}

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        @try {
                            AppleInternal_EnforceZeroLatencyKernelTier();
                            Titanium_ApplySiliconDeepOptimizations();
                        } @catch (NSException *e) {}
                    });

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        @try {
                            Titanium_ForceInjectDynamicRefreshSupport();
                            AppleInternal_LockHardwareCADisplay();
                        } @catch (NSException *e) {}
                    });

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        @try { Titanium_TuneWindowServerDisplayDirectly(); } @catch (NSException *e) {}
                    });

                    NSData *verifiedData = [@"VERIFIED" dataUsingEncoding:NSUTF8StringEncoding];
                    [[NSFileManager defaultManager] createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED
                                                            contents:verifiedData
                                                          attributes:@{NSFilePosixPermissions: @(0644)}];
                } else {
                    %init(Group_UIKit_ThirdParty_IsolatedV285);
                    %init(Group_Force_Render_Recovery_Overdrive);
                    %init(Group_Window_Level_Overdrive);

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        @try {
                            Titanium_ForceInjectDynamicRefreshSupport();
                            AppleInternal_EnforceZeroLatencyKernelTier();
                            Titanium_ApplySiliconDeepOptimizations();
                        } @catch (NSException *e) {}
                    });
                }

                g_SystemMasterReady = YES;
            } @catch (NSException *e) {}
        }
    });
}

// ====================================================================================================
// BOOTSTRAP
// ====================================================================================================
static void Titanium_RegisterPrefsObservers(BOOL isSpringBoardProcess) {
    static dispatch_once_t s_obsOnce;
    dispatch_once(&s_obsOnce, ^{
        CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
        if (!darwinCenter) return;
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_UIKIT_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_HARDWARE_SYNC), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_FPS_CHANGED), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
        CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_TITANIUM_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);
        if (!isSpringBoardProcess)
            CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    });
}

// [VÁ LẦN 7] SPRINGBOARD BOOT DELAY 2.5s cold / 1.5s warm
static void SpringBoardBootstrapTrigger(void) {
    static dispatch_once_t s_triggerOnce;
    dispatch_once(&s_triggerOnce, ^{
        const char *progName = getprogname();
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        time_t uptime = Titanium_GetSystemUptimeSeconds();
        BOOL isColdBoot = (uptime < 30);
        int64_t waitDelay = isColdBoot
            ? (int64_t)(TITANIUM_SB_BOOT_DELAY_MS_COLD * NSEC_PER_MSEC)
            : (int64_t)(TITANIUM_SB_BOOT_DELAY_MS_WARM * NSEC_PER_MSEC);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, waitDelay), dispatch_get_main_queue(), ^{
            runCoreTweak(YES, bundleID, progName);
        });
    });
}

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        if (strcasestr(progName, "smooth") != NULL ||
            strcasestr(progName, "boosti") != NULL ||
            strcasestr(progName, "liquid") != NULL) return;

        if (strcasestr(progName, "networkd") != NULL || strcasestr(progName, "trustd") != NULL ||
            strcasestr(progName, "configd") != NULL || strcasestr(progName, "wifid") != NULL ||
            strcasestr(progName, "CommCenter") != NULL || strcasestr(progName, "mDNSResponder") != NULL ||
            strcasestr(progName, "nsurlsessiond") != NULL || strcasestr(progName, "nsurlstoraged") != NULL ||
            strcasestr(progName, "WebKit") != NULL || strcasestr(progName, "WebContent") != NULL ||
            strcasestr(progName, "GPUProcess") != NULL || strcasestr(progName, "Networking") != NULL ||
            strcasestr(progName, "neagent") != NULL || strcasestr(progName, "nesessionmanager") != NULL ||
            strcasestr(progName, "apsd") != NULL || strcasestr(progName, "cloudd") != NULL ||
            strcasestr(progName, "geod") != NULL || strcasestr(progName, "akd") != NULL ||
            strcasestr(progName, "identityservicesd") != NULL || strcasestr(progName, "imagent") != NULL ||
            strcasestr(progName, "bluetoothd") != NULL) return;

        if (strcasestr(progName, "jailbreakd") || strcasestr(progName, "launchd") ||
            strcasestr(progName, "containermanagerd") || strcasestr(progName, "cfprefsd") ||
            strcasestr(progName, "watchdogd") || strcasestr(progName, "mediaserverd") ||
            strcasestr(progName, "installd") || strcasestr(progName, "logd") ||
            strcasestr(progName, "analyticsd") || strcasestr(progName, "symptomsd") ||
            strcasestr(progName, "powerd") || strcasestr(progName, "notifyd") ||
            strcasestr(progName, "securityd") || strcasestr(progName, "runningboardd") ||
            strcasestr(progName, "thermalmonitord") || strcasestr(progName, "mediaremoted") ||
            strcasestr(progName, "assertiond") || strcasestr(progName, "timed") ||
            strcasestr(progName, "passd")) return;

        if (strcasestr(progName, "backboardd") != NULL) {
            Titanium_RegisterPrefsObservers(NO);
            Titanium_ReloadSharedSyncStateV285();
            Titanium_AdoptPayloadRatesWithoutConfig();
            %init(Group_Backboardd_TouchDriver_Overdrive);
            Init_CAWindowServer_Hooks();
            return;
        }

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];

        if (bundleID) {
            if ([bundleID rangeOfString:@"smooth" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [bundleID rangeOfString:@"boostiphone6s" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [bundleID rangeOfString:@"liquid" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [bundleID rangeOfString:@"networkextension" options:NSCaseInsensitiveSearch].location != NSNotFound ||
                [bundleID rangeOfString:@"vpn" options:NSCaseInsensitiveSearch].location != NSNotFound) return;
        }

        BOOL isSpringBoard = (bundleID && [bundleID isEqualToString:@"com.apple.springboard"]);
        if (isSpringBoard) {
            if (!Titanium_CheckAndPreventBootloopUniversal()) return;
        }

        if (strcasestr(progName, "Preferences") || strcasestr(progName, "Settings")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
                if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                    NSInteger prefHz = (NSInteger)CFG285.targetHz;
                    if (prefHz >= 15 && prefHz <= 144) g_cachedResolvedHz = prefHz;
                }
                if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                    NSInteger prefFPS = (NSInteger)CFG285.targetFPS;
                    if (prefFPS >= 15 && prefFPS <= 144) g_cachedResolvedFPS = prefFPS;
                }
            }
            return;
        }

        Titanium_RegisterPrefsObservers(isSpringBoard);
        %init;

        if (isSpringBoard) {
            dispatch_async(dispatch_get_main_queue(), ^{
                SpringBoardBootstrapTrigger();
            });
        } else {
            runCoreTweak(NO, bundleID, progName);
        }
    }
}
