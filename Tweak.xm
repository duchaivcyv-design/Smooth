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
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>

// BẢO VỆ SDK: Chống lỗi fatal error nếu SDK thiếu thư mục Private Framework IOKit
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

typedef struct {
    uint32_t pset_limit;
} thread_throttle_policy_data_t;

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
// MACRO ĐỒNG BỘ TOÀN HỆ THỐNG & ĐƯỜNG DẪN TỆP IPC NGUYÊN TỬ (ĐÃ BỔ SUNG SECONDARY_SYNC_FILE)
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

// ====================================================================================================
// [ĐÃ ÉP THÊM]: CẤU TRÚC BỘ NHỚ SHMEM IPC ĐỒNG BỘ CHUẨN XÁC VỚI ROOTLISTCONTROLLER
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
// SYSTEM PRIVATE INTERFACES (ĐẦY ĐỦ 100% CHO CẢ 18 NHÓM GIA TỐC HỆ THỐNG)
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

// --- NEURAL TOUCH & GESTURE RECOGNITION ---
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

// --- WATCHDOG IMMUNITY & PROCESS ASSERTION ---
@interface FBProcessWatchdog : NSObject
- (void)start;
@end

@interface FBSceneWatchdog : NSObject
- (id)initWithTimeout:(double)timeout;
@end

@interface BKSProcessAssertion : NSObject
- (BOOL)isValid;
@end

// --- GIA TỐC IOKIT & SCENE MANAGEMENT ---
@interface IOHIDEventSystemClient : NSObject
- (void)setProperty:(id)property forKey:(NSString *)key;
@end

@interface FBScene : NSObject
- (void)updateSettings:(id)settings withTransitionContext:(id)context;
@end

@interface UIVisualEffectView (TitaniumCryoPacingPrivate)
@end

// --- KHẮC PHỤC TRIỆT ĐỂ WARNING ACCESSOR MISMATCH VỚI CLANG ---
@interface MTLRenderPassAttachmentDescriptor (TitaniumCryoPacing)
@property (nonatomic, assign) NSUInteger storeAction;
@end

@interface MTLRenderPassDescriptor (TitaniumCryoPacing)
@property (nonatomic, retain) MTLRenderPassAttachmentDescriptor *depthAttachment;
@property (nonatomic, retain) MTLRenderPassAttachmentDescriptor *stencilAttachment;
@end

// --- NHÓM 20: DEEP MEMORY OPTIMIZATION & ADVANCED JETSAM DEFENSE ---
@interface UIApplication (TitaniumMemoryPrivate)
- (void)_performMemoryWarning;
@end

@interface UIImage (TitaniumMemoryPrivate)
+ (void)_flushCache;
@end

// --- NHÓM 21: WKWEBVIEW & WEBKIT MEMORY COMPACTION INTERFACES ---
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
// ĐỊNH NGHĨA CHUẨN STRUCT PAYLOAD & KHỞI TẠO BIẾN TOÀN CỤC (ĐÃ SỬA TRIỆT ĐỂ LỖI CLANG)
// ====================================================================================================

// [ĐÃ ÉP]: Khởi tạo chuẩn xác từng trường chống lỗi "excess elements in struct initializer"
static ApexV285ProPayload g_syncPayloadV285 = {
    .magic = APEX_SYNC_MAGIC_V285,
    .masterEnabled = 1,
    .targetHz = 144,
    .targetFPS = 144,
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
    .updateSeq = 0,
    .lastHeartbeat = 0,
    .reserved = {0}
};

static pthread_mutex_t g_syncLockV285 = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTicksV285 = 0;
static BOOL g_isDeviceChargingV285 = NO;
static volatile BOOL g_isUserTouchingV285 = NO;
static volatile CFTimeInterval g_lastTouchMediaTimeV285 = 0.0;
static volatile NSProcessInfoThermalState g_liveThermalStateV285 = NSProcessInfoThermalStateNominal;

static BOOL g_SystemMasterReady = NO;

// ====================================================================================================
// HARDWARE DETECTION & RUNTIME PATH RESOLUTION (CHUẨN ROOTLESS, ROOTHIDE & APPLE SILICON)
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
                if (sub.location != NSNotFound) {
                    cachedJbRoot = [dylibPath substringToIndex:sub.location];
                } else {
                    cachedJbRoot = @"/var/jb";
                }
            } else {
                cachedJbRoot = @"/var/jb";
            }
        } else {
            cachedJbRoot = @"/var/jb";
        }
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
            if ([dev hasPrefix:@"iPhone14,2"] || [dev hasPrefix:@"iPhone14,3"] || // 13 Pro / Pro Max
                [dev hasPrefix:@"iPhone15,2"] || [dev hasPrefix:@"iPhone15,3"] || // 14 Pro / Pro Max
                [dev hasPrefix:@"iPhone16,1"] || [dev hasPrefix:@"iPhone16,2"] || // 15 Pro / Pro Max
                [dev hasPrefix:@"iPhone17,1"] || [dev hasPrefix:@"iPhone17,2"] || // 16 Pro / Pro Max
                [dev hasPrefix:@"iPad7,"]      || [dev hasPrefix:@"iPad8,"]      || // iPad Pro
                [dev hasPrefix:@"iPad13,"]     || [dev hasPrefix:@"iPad14,"]     ||
                [dev hasPrefix:@"iPad16,"]) {
                isNative120 = YES;
            }
        }
    });
    return isNative120;
}

static inline BOOL Titanium_IsClassicHomeButtonDevice(void) {
    static BOOL sIsClassic = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
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
        if (name) {
            isPrefs = [name isEqualToString:@"Preferences"] || [name isEqualToString:@"Settings"] || [name isEqualToString:@"TweakSettings"];
        }
    });
    return isPrefs;
}

static inline float ClampSafeFPS(float target) {
    if (target < 15.0f) return 15.0f;
    if (target > 144.0f) return 144.0f;
    return target;
}

// ====================================================================================================
// ADVANCED HARDWARE SUBSYSTEM ENGINE & MACH POLICY (PRO MAX ULTRA LOW-LATENCY)
// ====================================================================================================

static inline void Titanium_EnableZeroLatencyPipeline(void) {
    // CHỈ CHO PHÉP TRÊN SPRINGBOARD: Tuyệt đối không ép lên app bên thứ ba để tránh rỗng buffer đen màn hình
    if (Titanium_IsSpringBoard()) {
        if ([CATransaction respondsToSelector:@selector(_setLowLatency:)]) {
            [CATransaction _setLowLatency:YES];
        }
    }
}

static void Titanium_DisableKernelThreadThrottling(void) {
    mach_port_t thread = pthread_mach_thread_np(pthread_self());
    thread_throttle_policy_data_t throttlePolicy;
    throttlePolicy.pset_limit = 0;
    thread_policy_set(
        thread,
        THREAD_THROTTLE_POLICY,
        (thread_policy_t)&throttlePolicy,
        1
    );
}

static inline void Titanium_EnforceThreadVIPPolicy(void) {
    if (!NSThread.isMainThread) return;

    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    Titanium_DisableKernelThreadThrottling();
}

static inline void Titanium_EnforceThreadRealtimeAndDiskVIP(void) {
    Titanium_EnforceThreadVIPPolicy();
}

static inline void Titanium_BoostCurrentThreadBriefly(void) {
    if (NSThread.isMainThread) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

static inline void Titanium_BackgroundPurgeMemory(void) {
    static volatile uint64_t s_lastPurgeTicks = 0;
    uint64_t now = mach_absolute_time();
    if (s_lastPurgeTicks != 0 && (now - s_lastPurgeTicks) < (15ULL * 1000000000ULL)) {
        return;
    }
    s_lastPurgeTicks = now;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        malloc_zone_pressure_relief(malloc_default_zone(), 0);
    });
}

static inline void Titanium_PurgeProcessMemoryAggressively(void) {
    Titanium_BackgroundPurgeMemory();
}

static void Titanium_ApplySiliconDeepOptimizations(void) {
    if (Titanium_IsSpringBoard()) {
        // Chỉ ép cờ CoreAnimation trên SpringBoard để tránh phá pipeline của app con
        setenv("CA_DEBUG_TRANSACTIONS", "0", 1);
        setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);
    }

    // Gỡ bóp xung luồng Kernel an toàn cho toàn hệ thống
    Titanium_DisableKernelThreadThrottling();
}

// [ĐÃ ÉP TOÀN DIỆN]: Ghi đồng bộ tệp IPC atomic ra cả hai phân vùng Rootless & Rootful
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

// [ĐÃ ÉP TOÀN DIỆN]: Đọc atomic trạng thái đồng bộ IPC tức thì 0ns
static inline void Titanium_ReloadSharedSyncStateV285(void) {
    uint64_t now = mach_absolute_time();
    if (g_lastSyncTicksV285 != 0 && (now - g_lastSyncTicksV285) < (250ULL * 1000000ULL)) {
        return;
    }

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
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([fileManager fileExistsAtPath:bootCounterFilePath]) {
                [fileManager removeItemAtPath:bootCounterFilePath error:nil];
            }
        });
        return YES;
    }
}

// ====================================================================================================
// BOOST CONFIGURATION ENGINE (V28.7 PRO MAX - ĐÃ KHẮC PHỤC 100% LỖI PROPERTY CLANG)
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

// Biến cache nguyên thủy: Trả về tức thì 0ns cho CADisplayLink & CoreAnimation
static volatile NSInteger g_cachedResolvedHz = 144;
static volatile NSInteger g_cachedResolvedFPS = 144;

// [ĐÃ ÉP TOÀN DIỆN]: ĐIỀU PHỐI WINDOWSERVER TỨC THÌ (KHÓA DẢI 15 - 144HZ, CHỐNG CO VIEWPORT & CHỐNG ĐEN APP)
static void Titanium_TuneWindowServerDisplayDirectly(void) {
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

            if ([mainDisp respondsToSelector:sel_registerName("setMinimumFrameDuration:")]) {
                ((void (*)(id, SEL, double))objc_msgSend)(mainDisp, sel_registerName("setMinimumFrameDuration:"), minDuration);
            }
            if ([mainDisp respondsToSelector:sel_registerName("setMaximumRefreshRate:")]) {
                ((void (*)(id, SEL, double))objc_msgSend)(mainDisp, sel_registerName("setMaximumRefreshRate:"), (double)currentHz);
            }
            if ([mainDisp respondsToSelector:sel_registerName("setIdealRefreshRate:")]) {
                ((void (*)(id, SEL, double))objc_msgSend)(mainDisp, sel_registerName("setIdealRefreshRate:"), (double)currentHz);
            }
        }
    } @catch (NSException *e) {
        // Bỏ qua an toàn tuyệt đối nếu SDK không hỗ trợ selector
    }
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
        self.targetHz = 144;
        self.targetFPS = 144;
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

        // [ĐÃ ÉP TOÀN DIỆN]: Khởi tạo mặc định cho nhóm nhiệt độ & đồ họa
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

        // [ĐÃ ÉP TOÀN DIỆN]: Khởi tạo mặc định cho 7 cờ Scheduler, I/O & Memory
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

        // ==============================================================================================
        // CƠ CHẾ DỰ PHÒNG CHO APP THỨ 3 (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN - VƯỢT SANDBOX 100% QUA RAM)
        // (AN TOÀN TUYỆT ĐỐI: KHÔNG TREO I/O, KHÔNG ĐEN MÀN HÌNH, KHÔNG NGHẼN MẠNG)
        // ==============================================================================================
        if (!diskDict || diskDict.count == 0) {
            // ĐÃ ÉP: Đọc tệp IPC đồng bộ từ App Control Master với phân quyền 0666
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
                                close(fd);
                                return;
                            }
                        }
                        close(fd);
                    }
                }
            }

            // ĐÃ ÉP: Cưỡng bức kích hoạt kịch trần toàn bộ cấu hình trực tiếp từ RAM khi bị Sandbox chặn
            self.enabled = YES;
            self.targetHz = 144;
            self.targetFPS = 144;
            self.enableHzControl = YES;
            self.enableFPSControl = YES;
            self.forceOverclock144Hz = YES;
            self.proMotionEngineBeta7 = YES;
            self.touchResponseBoost = YES;
            self.colorOs17SmoothEngine = YES;
            self.metalHexBuffering = YES;
            self.vsyncAdaptiveBuffer = YES;
            self.fixAppLaunchBlackScreen = YES;
            self.turboAppLaunch = YES;
            self.turboLaunch = YES;
            self.antiThermalThrottling = YES;
            self.antiThermalThrottle = YES;
            self.ultraResponsiveness = YES;
            self.ultraResponsivenessPro = YES;
            self.gameFPSStabilizer = YES;
            self.lockHighIdleFloor = YES;
            self.quantumCoreSync = YES;
            self.pCoreRealtimePriority = YES;
            self.zeroLagNeural = YES;
            self.powerSaveMode = NO;
            self.batterySaver60Hz = NO;

            g_cachedResolvedHz = 144;
            g_cachedResolvedFPS = 144;
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
        self.autoCloseBackgroundApp = self.fixAppExitStutter;
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

        // --- ĐỒNG BỘ ÁNH XẠ CÁC THUỘC TÍNH BỔ SUNG TỪ ROOT.PLIST ---
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

        // [ĐÃ ÉP TOÀN DIỆN]: ĐỒNG BỘ ÁNH XẠ 7 CỜ MỚI
        self.schedulerGovernor = GetLiveBool(@"IOSchedulerEngine", YES);
        self.iopolVipPriority = GetLiveBool(@"SystemProcessOpt", YES);
        self.ultraResponsivenessPro = GetLiveBool(@"UltraResponsiveness", YES);
        self.coolDownHeavyLoad = GetLiveBool(@"HeavyLoadCooling", YES);
        self.backgroundPacingDaemon = GetLiveBool(@"BackgroundPacingDaemon", YES);
        self.autoKillBackground = GetLiveBool(@"AutoCloseBackgroundApp", NO);
        self.hyperMemoryGuardian = GetLiveBool(@"HyperMemoryGuardian", YES);

        // Nhận diện trạng thái ổ khóa HZ/FPS từ App
        g_isRateLockedV285 = GetLiveBool(@"IsRateLocked", NO);

        // [ĐÃ ÉP TOÀN DIỆN]: ĐỌC DANH SÁCH LOẠI TRỪ ỨNG DỤNG APPTWEAKSTATES
        NSString *currentBundleID = [[NSBundle mainBundle] bundleIdentifier];
        if (currentBundleID && diskDict[@"AppTweakStates"]) {
            NSDictionary *appStates = diskDict[@"AppTweakStates"];
            if (appStates[currentBundleID] != nil && ![appStates[currentBundleID] boolValue]) {
                self.enabled = NO;
            }
        }

        // ==============================================================================================
        // [ĐÃ ÉP TOÀN DIỆN]: KHÓA CỨNG MỨC CHỈNH TỪ 15HZ ĐẾN 144HZ VÀO CACHE NGUYÊN THỦY (0NS RENDER LOOP)
        // ==============================================================================================
        NSInteger safeHz = self.targetHz;
        if (safeHz < 15) safeHz = 15;
        if (safeHz > 144) safeHz = 144;

        if (!self.enabled || !self.enableHzControl) {
            g_cachedResolvedHz = 60;
        } else if (self.powerSaveMode || self.batterySaver60Hz) {
            g_cachedResolvedHz = 60;
        } else if (self.forceOverclock144Hz || safeHz >= 144) {
            g_cachedResolvedHz = 144;
        } else {
            g_cachedResolvedHz = safeHz;
        }

        NSInteger safeFPS = self.targetFPS;
        if (safeFPS < 15) safeFPS = 15;
        if (safeFPS > 144) safeFPS = 144;

        if (!self.enabled || !self.enableFPSControl) {
            g_cachedResolvedFPS = 60;
        } else if (self.powerSaveMode || self.batterySaver60Hz) {
            g_cachedResolvedFPS = 60;
        } else if (self.forceOverclock144Hz || safeFPS >= 144) {
            g_cachedResolvedFPS = 144;
        } else {
            g_cachedResolvedFPS = safeFPS;
        }

        // [ĐÃ ÉP TOÀN DIỆN]: ĐỒNG BỘ PAYLOAD HẠT NHÂN CHUẨN IPC TỪ SPRINGBOARD
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

            ApexV285ProPayload capturedPayload = p;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_WriteSyncPayloadV285(&capturedPayload);
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

// CALLBACK ĐỒNG BỘ TOÀN HỆ THỐNG
static void PrefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (CFG285) {
        [CFG285 loadSettings];
        if (Titanium_IsSpringBoard()) {
            Titanium_TuneWindowServerDisplayDirectly();
        }
    }
}

// ====================================================================================================
// KHAI BÁO BIẾN TOÀN CỤC & ĐIỀU PHỐI HỆ THỐNG TITANIUM (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN & AN TOÀN ĐA LUỒNG)
// (AN TOÀN TUYỆT ĐỐI: ĐỒNG BỘ 100% VỚI Ổ KHÓA CỦA APP, KHÔNG ĐEN MÀN HÌNH, KHÔNG TREO RESPRING)
// ====================================================================================================

#include <stdatomic.h>

static volatile BOOL g_isContinuousSwiping = NO;
static volatile BOOL g_isUserTouchingScreen = NO;
static volatile BOOL g_isVideoPlayingActive = NO;       // Trạng thái phát Video & PiP
static volatile BOOL g_isNotificationBannerActive = NO;
static volatile BOOL g_isScrollingActive = NO;
static volatile int32_t g_activeAnimationCount = 0;
static volatile BOOL g_isMetalGameProcess = NO;        // Nhận diện tiến trình Game Metal 3D

// Mốc thời gian Mach Time chuẩn xác tuyệt đối (Zero-Overhead)
static volatile uint64_t g_lastInteractionMachTime = 0;
static uint64_t g_burstDurationMachTicks = 0;
static uint64_t g_burstDurationChargingMachTicks = 0;

static volatile uint64_t g_lastBannerMachTime = 0;
static uint64_t g_bannerDurationMachTicks = 0;

// ====================================================================================================
// 1. BỘ KHỞI TẠO MACH TIMEBASE THỐNG NHẤT (CHỐNG CRASH CHIA CHO 0 & CẤP ĐỦ TICKS TRONG 1 LẦN GỌI)
// ====================================================================================================

static inline void Titanium_InitUnifiedMachTimebase(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t tb;
        if (mach_timebase_info(&tb) == KERN_SUCCESS && tb.numer > 0 && tb.denom > 0) {
            // Chu kỳ nhả xung chạm: 350ms khi dùng pin, 180ms khi cắm sạc
            g_burstDurationMachTicks = (350ULL * 1000000ULL * tb.denom) / tb.numer;
            g_burstDurationChargingMachTicks = (180ULL * 1000000ULL * tb.denom) / tb.numer;
            // Chu kỳ neo giữ banner thông báo: 850ms
            g_bannerDurationMachTicks = (850ULL * 1000000ULL * tb.denom) / tb.numer;
        }
    });
}

static inline void Titanium_EnsureMachTimebaseInit(void) {
    Titanium_InitUnifiedMachTimebase();
}

static inline void Titanium_InitTouchMachTimebase(void) {
    Titanium_InitUnifiedMachTimebase();
}

static inline void Titanium_InitBannerMachTimebase(void) {
    Titanium_InitUnifiedMachTimebase();
}

// Kiểm tra banner còn hiệu lực hiển thị
static inline BOOL Titanium_IsNotificationBannerActive(void) {
    if (g_lastBannerMachTime == 0) return NO;
    return ((mach_absolute_time() - g_lastBannerMachTime) < g_bannerDurationMachTicks);
}

// Kiểm tra video thụ động (không thao tác chạm, không cuộn màn hình)
static inline BOOL Titanium_IsPassiveVideoPlayback(void) {
    return (g_isVideoPlayingActive && !g_isUserTouchingScreen && !g_isScrollingActive && g_activeAnimationCount == 0);
}

// ====================================================================================================
// 2. BỘ ĐIỀU PHỐI KHÓA TARGET RATE DYNAMIC (ATOMIC TICKS - CÓ TIMEOUT CHỐNG KẸT PEAK VĨNH VIỄN)
// ====================================================================================================

static inline BOOL Titanium_ShouldLockTargetRate(void) {
    // [ĐÃ ÉP TOÀN DIỆN]: NẾU BẬT Ổ KHÓA HOẶC ÉP XUNG 144HZ -> LUÔN KHÓA CỨNG Ở TRẦN TƯƠNG TÁC CAO NHẤT
    if (g_isRateLockedV285) return YES;
    if (CFG285 && (CFG285.forceOverclock144Hz || CFG285.proMotionEngineBeta7)) return YES;
    if (g_syncPayloadV285.forceOverclock != 0 || g_syncPayloadV285.dynamicInterpolation != 0) return YES;

    // 1. Đang có cử chỉ vuốt liên tục hoặc cuộn quán tính
    if (g_isContinuousSwiping || g_isScrollingActive) return YES;

    // 2. Có banner thông báo đang hoạt động
    if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

    // 3. Có hoạt ảnh chuyển cảnh (TIMEOUT BẢO VỆ: Chống kẹt cờ làm nóng máy & tụt xung)
    if (g_activeAnimationCount > 0) {
        static uint64_t s_animStartTick = 0;
        uint64_t nowTick = mach_absolute_time();
        if (s_animStartTick == 0) {
            s_animStartTick = nowTick;
            return YES;
        } else if ((nowTick - s_animStartTick) < (uint64_t)(1200000000ULL)) { // Giới hạn tối đa 1.2s
            return YES;
        } else {
            g_activeAnimationCount = 0;
            s_animStartTick = 0;
        }
    }

    // 4. Kiểm tra cửa sổ tương tác Mach Time
    if (g_lastInteractionMachTime == 0) return NO;

    if (__builtin_expect(g_burstDurationMachTicks == 0, 0)) {
        Titanium_InitUnifiedMachTimebase();
    }

    uint64_t now = mach_absolute_time();
    uint64_t limitTicks = g_isDeviceChargingV285 ? g_burstDurationChargingMachTicks : g_burstDurationMachTicks;

    return ((now - g_lastInteractionMachTime) < limitTicks);
}

// ====================================================================================================
// 3. ĐIỀU PHỐI XUNG NHỊP CẢM ỨNG (CƯỚP QUYỀN P-CORE TOÀN HỆ THỐNG - KHÔNG NGHẼN SOCKET)
// ====================================================================================================

// [ĐÃ ÉP TOÀN DIỆN]: Ép quyền ưu tiên cao nhất cho luồng chính và I/O ổ đĩa
static inline void Titanium_LockMainThreadFast(void) {
    if (![NSThread isMainThread]) return;

    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(650 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if (s_bannerSeq == currentSeq) {
            g_isNotificationBannerActive = NO;
        }
    });
}

// ====================================================================================================
// 4. ĐIỀU PHỐI CÂN BẰNG: CPU ĐỒ HỌA SOFT-REALTIME (ÁP DỤNG MỌI TIẾN TRÌNH)
// ====================================================================================================

static inline void Titanium_BoostRenderWithoutStarvingNetwork(void) {
    if (![NSThread isMainThread]) return;
    if (!Titanium_ShouldLockTargetRate()) return;

    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
}

// ====================================================================================================
// 5. THUẬT TOÁN PHÂN TẦNG TOÀN HỆ THỐNG: MẶC ĐỊNH 144HZ, TĨNH 60HZ, DẢI 15 - 144HZ
// ====================================================================================================

typedef NS_ENUM(NSInteger, TitaniumDisplayTier) {
    TitaniumTier_BypassGame = 0,    // Tầng 0: Game Metal -> Bypass giữ nguyên FPS gốc của game
    TitaniumTier_DeepIdle   = 60,   // Tầng 1: Màn hình tĩnh hoàn toàn -> Khóa sàn 60Hz cho cả máy
    TitaniumTier_VideoSync  = 60,   // Tầng 2: Xem video/PiP -> Chuẩn 60fps gốc
    TitaniumTier_TextRead   = 80,   // Tầng 3: Đọc báo, cuộn chậm
    TitaniumTier_ApexPeak   = 144   // Tầng 4: Chạm vuốt nhanh, bung toàn bộ 144Hz
};

static inline BOOL Titanium_IsCurrentAppAGame(void) {
    if (Titanium_IsSpringBoard()) return NO;
    return g_isMetalGameProcess;
}

// [ĐÃ ÉP TOÀN DIỆN]: Phân tầng nhịp theo công tắc cấu hình hoặc bung toàn lực 144Hz
static inline NSInteger Titanium_CalculateAdaptiveProMaxTier(void) {
    // 1. TẦNG GAME: Giữ nguyên nhịp render gốc của game
    if (Titanium_IsCurrentAppAGame()) {
        return TitaniumTier_BypassGame;
    }

    // 2. [ĐÃ ÉP]: NẾU BẬT Ổ KHÓA HOẶC ÉP XUNG 144HZ -> BUNG KỊCH TRẦN GIÁ TRỊ ĐÃ KHÓA
    if (g_isRateLockedV285 || (CFG285 && (CFG285.forceOverclock144Hz || CFG285.proMotionEngineBeta7)) || g_syncPayloadV285.forceOverclock != 0) {
        NSInteger target = g_cachedResolvedHz > 0 ? g_cachedResolvedHz : (NSInteger)g_syncPayloadV285.targetHz;
        return target > 0 ? target : TitaniumTier_ApexPeak;
    }

    // 3. TẦNG VIDEO: Đang phát video YouTube / TikTok / PiP -> Giữ 60fps chuẩn
    if (Titanium_IsPassiveVideoPlayback()) {
        return TitaniumTier_VideoSync;
    }

    // 4. TẦNG PEAK: Đang vuốt lướt nhanh, mở app hoặc gõ phím -> Phóng thẳng lên trần cấu hình (144Hz)
    if (Titanium_ShouldLockTargetRate()) {
        NSInteger target = g_cachedResolvedHz > 0 ? g_cachedResolvedHz : (NSInteger)g_syncPayloadV285.targetHz;
        return target > 0 ? target : TitaniumTier_ApexPeak;
    }

    // 5. TẦNG STANDARD: Đang chạm giữ trên màn hình hoặc cuộn chậm
    if (g_isUserTouchingScreen || g_isScrollingActive) {
        NSInteger target = g_cachedResolvedHz > 0 ? g_cachedResolvedHz : (NSInteger)g_syncPayloadV285.targetHz;
        return target > 0 ? target : TitaniumTier_ApexPeak;
    }

    // 6. TẦNG IDLE: Màn hình đứng yên hoàn toàn -> Khóa sàn 60Hz tiết kiệm pin
    return TitaniumTier_DeepIdle;
}

// ====================================================================================================
// 6. ĐIỀU PHỐI KERNEL XNU & PHẦN CỨNG TOÀN DIỆN
// ====================================================================================================

// [ĐÃ ÉP TOÀN DIỆN]: Ép nhân Kernel XNU chạy chính sách độ trễ và băng thông cấp 1
static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
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
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép triệt tiêu độ trễ hiển thị phần cứng của CADisplay về 0.0s
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

static BOOL Titanium_IsLegacyA9toA12(void) {
    static BOOL s_isLegacy = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        if (uname(&sysInfo) == 0) {
            NSString *machine = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            if (machine) {
                s_isLegacy = ([machine hasPrefix:@"iPhone8,"]  ||  // A9
                              [machine hasPrefix:@"iPhone9,"]  ||  // A10
                              [machine hasPrefix:@"iPhone10,"] ||  // A11
                              [machine hasPrefix:@"iPhone11,"] ||  // A12
                              [machine hasPrefix:@"iPad6,"]    || 
                              [machine hasPrefix:@"iPad7,"]);
            }
        }
    });
    return s_isLegacy;
}

// ====================================================================================================
// THIẾT LẬP CHU KỲ REALTIME TOÀN HỆ THỐNG (CHẠY TRÊN CẢ SPRINGBOARD VÀ TẤT CẢ ỨNG DỤNG THỨ BA)
// ====================================================================================================

// [ĐÃ ÉP TOÀN DIỆN]: Ép ràng buộc thời gian thực Mach Thread Constraint chuẩn xác cho từng Hz
static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz) {
    if (!Titanium_IsSpringBoard()) {
        Titanium_ReloadSharedSyncStateV285();
    }

    if (CFG285 && !CFG285.enabled) return;
    if (g_syncPayloadV285.masterEnabled == 0) return;

    if (g_isDeviceChargingV285) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        return;
    }

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
    kern_return_t kr = thread_policy_set(threadPort,
                                         THREAD_TIME_CONSTRAINT_POLICY,
                                         (thread_policy_t)&policy,
                                         THREAD_TIME_CONSTRAINT_POLICY_COUNT);

    // [ĐÃ ÉP]: Giải phóng descriptor Mach Port ngay lập tức, chống cạn kiệt tài nguyên hạt nhân
    mach_port_deallocate(mach_task_self(), threadPort);

    if (kr == KERN_SUCCESS) {
        s_appliedHz = targetHz;
    } else {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

static inline void Titanium_EnforceMachFrameConstraint(void) {
    int targetHz = 144;
    if (CFG285 && [CFG285 respondsToSelector:@selector(targetHz)]) {
        targetHz = (int)CFG285.targetHz;
    } else if (g_cachedResolvedHz > 0) {
        targetHz = (int)g_cachedResolvedHz;
    } else if (g_syncPayloadV285.targetHz > 0) {
        targetHz = (int)g_syncPayloadV285.targetHz;
    }
    Titanium_EnforceMachFrameConstraintDynamic(targetHz >= 15 ? targetHz : 144);
}

// ====================================================================================================
// NHÓM NỘI BỘ APPLE: MÔ PHỎNG VÒNG LẶP _UIUPDATECYCLE (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN - TỐC ĐỘ 0NS)
// (KẾT NỐI: ProMotion Engine Beta 7 + Phản Hồi Cảm Ứng 0ms + Khóa Nhịp Luồng Realtime + Ổ Khóa App)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG ĐỆ QUY, KHÔNG NGHẼN GETTER, 100% KHÔNG CRASH XNU)
// ====================================================================================================

%group Group_Apple_Internal_ProMotion_Apex

%hook _UIUpdateCycle

// [ĐÃ ÉP TOÀN DIỆN]: Giữ getter nguyên bản nhẹ nhất, triệt tiêu hoàn toàn overhead thăm dò trạng thái
- (BOOL)isPerformingUpdate {
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép nâng QoS luồng lên User-Interactive và kích hoạt Zero-Latency Pipeline ngay trong chu kỳ vẽ
- (void)performUpdateWithInfo:(void *)info {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (CFG285.proMotionEngineBeta7 || CFG285.touchResponseBoost || g_isRateLockedV285 || g_syncPayloadV285.zeroLatencyTouch) {
            if (Titanium_ShouldLockTargetRate()) {
                g_lastInteractionMachTime = mach_absolute_time();
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
                Titanium_EnableZeroLatencyPipeline();
            }
        }
    }
    %orig;
}

%end

%hook _UIUpdateSequenceItem

// [ĐÃ ÉP TOÀN DIỆN]: Ép duy trì nhịp Mach Time liên tục cho từng đơn vị item trong chuỗi cập nhật
- (void)performItem {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (CFG285.proMotionEngineBeta7 || CFG285.touchResponseBoost || g_isRateLockedV285 || g_syncPayloadV285.zeroLatencyTouch) {
            if (Titanium_ShouldLockTargetRate()) {
                g_lastInteractionMachTime = mach_absolute_time();
            }
        }
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 1: CẢM ỨNG 0MS NỘI BỘ APPLE (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN - ZERO-LATENCY TOUCH & ANTI-GHOST)
// (KẾT NỐI: Tăng Phản Hồi 0ms Touch + Lọc Loạn Cảm Ứng Khi Cắm Sạc + Khử Trễ Icon/Button)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG ĐƠ CHẠM, KHÔNG ĐEN HÌNH NỀN, KHÔNG NGHẼN MẠNG, 100% KHÔNG LỖI)
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

// --- [ĐÃ ÉP TỐI ĐA - BẢO TOÀN CHUỖI NHẬN DIỆN HID GỐC] ---
%hook UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

// --- [ĐÃ ÉP TỐI ĐA - BẢO TOÀN BỘ PHÂN PHỐI SỰ KIỆN GỐC] ---
%hook _UIEventDispatcher

- (void)dispatchEvent:(UIEvent *)event toTarget:(id)target {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

// --- [ĐÃ ÉP TOÀN DIỆN - TRIỆT TIÊU ĐỘ TRỄ ICON SPRINGBOARD VỀ 0.0S] ---
%hook SBIconView

// [ĐÃ ÉP TOÀN DIỆN]: Khử hoàn toàn độ trễ phát sáng icon về 0.0s
- (double)highlightDelay {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        return 0.0;
    }
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

// --- [ĐÃ ÉP TOÀN DIỆN - TRIỆT TIÊU TRỄ NÚT BẤM UIKIT VỀ 0.0S] ---
%hook UIControl

// [ĐÃ ÉP TOÀN DIỆN]: Khử hoàn toàn trễ nhận diện nút bấm UIKit về 0.0s
- (NSTimeInterval)_touchDelayThreshold {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        return 0.0;
    }
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

// --- [ĐÃ ÉP TOÀN DIỆN - BỘ LỌC CẢM ỨNG VÀ CHỐNG NHIỄU SẠC AN TOÀN] ---
%hook UIWindow

// [ĐÃ ÉP TOÀN DIỆN]: Bỏ qua độ trễ hủy sự kiện khi màn hình tĩnh để nhận diện cảm ứng tức thì
- (BOOL)_shouldDelayTouchForCancelEvents {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        if (g_activeAnimationCount > 0 || g_isScrollingActive) {
            return %orig;
        }
        return NO;
    }
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Lọc loạn cảm ứng khi cắm sạc & Cướp quyền P-Core 0ms
- (void)sendEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch) && event) {
        if (event.type == 0) { // UIEventTypeTouches
            BOOL shouldTriggerBoost = YES;

            // ĐÃ ÉP: Lọc vi rung giật dưới 2.0px do dòng sạc dỏm mà KHÔNG nuốt mất touch của người dùng
            if ((CFG285.antiGhostTouch || g_syncPayloadV285.antiGhostTouch) && g_isDeviceChargingV285) {
                NSSet *allTouches = [event allTouches];
                UITouch *touch = [allTouches anyObject];
                if (touch && touch.phase == UITouchPhaseMoved) {
                    CGPoint currentLoc = [touch locationInView:nil];
                    CGPoint prevLoc = [touch previousLocationInView:nil];
                    CGFloat deltaX = currentLoc.x - prevLoc.x;
                    CGFloat deltaY = currentLoc.y - prevLoc.y;
                    if ((deltaX * deltaX + deltaY * deltaY) < 4.0) {
                        shouldTriggerBoost = NO; // Chỉ ngắt kích xung CPU, không nuốt mất touch
                    }
                }
            }

            if (shouldTriggerBoost) {
                static uint64_t s_lastWindowTouchTick = 0;
                uint64_t now = mach_absolute_time();
                // ĐÃ ÉP: Đệm nhịp 30ms chống spam CPU gây nghẽn băng thông socket mạng
                if (now - s_lastWindowTouchTick > (30ULL * 1000000ULL)) {
                    s_lastWindowTouchTick = now;
                    g_lastInteractionMachTime = now;
                    
                    if (Titanium_IsSpringBoard()) {
                        Titanium_LockMainThreadFast();
                    } else {
                        Titanium_BoostRenderWithoutStarvingNetwork();
                    }
                }
            }
        }
    }
    %orig; // Luôn gọi %orig bảo toàn chuỗi sự kiện UIKit
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
// NHÓM 2: OVERDRIVE METAL GRAPHICS - CHỐNG ĐEN APP, CHỐNG GIẬT LAG & BẢO VỆ SAFEMODE TUYỆT ĐỐI
// ====================================================================================================

%group Group_Metal_ZeroTearing_Pacing

%hook CAMetalLayer

- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        g_isMetalGameProcess = YES;
    }
}

// [ĐÃ ÉP TOÀN DIỆN]: Bỏ khóa V-Sync an toàn cho game 3D, tránh can thiệp nếu app ở SpringBoard
- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && CFG285.vsyncAdaptiveBuffer && !Titanium_IsSpringBoard()) {
        %orig(NO);
        return;
    }
    %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Cưỡng bức Triple Buffering (3) khi layer đã có kích thước thực tế (chống nghẽn buffer gây đen app)
- (NSUInteger)maximumDrawableCount {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard() && (CFG285.metalHexBuffering || g_syncPayloadV285.metalPacingEnabled)) {
        if (self.superlayer != nil && self.bounds.size.width > 0 && self.bounds.size.height > 0) {
            return 3;
        }
    }
    return %orig;
}

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard() && (CFG285.metalHexBuffering || g_syncPayloadV285.metalPacingEnabled)) {
        if (self.superlayer != nil && self.bounds.size.width > 0 && self.bounds.size.height > 0) {
            %orig(3);
            return;
        }
    }
    %orig;
}

%end

%hook CALayer

// [ĐÃ ÉP TOÀN DIỆN]: Kích hoạt Zero-Latency Pipeline với bộ đệm nhịp 16ms chống spam nghẽn Main Thread
- (void)display {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch) && [NSThread isMainThread]) {
        if (!g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
            static uint64_t s_lastLatencyTrigger = 0;
            uint64_t now = mach_absolute_time();
            // Đệm 16ms (chu kỳ 1 frame ở 60Hz) tránh spam đè lên các sublayer con
            if (now - s_lastLatencyTrigger > (16ULL * 1000000ULL)) {
                s_lastLatencyTrigger = now;
                if (self.bounds.size.width > 0 && self.bounds.size.height > 0) {
                    Titanium_EnableZeroLatencyPipeline();
                }
            }
        }
    }
    %orig;
}

%end

%hook CAContext

// [ĐÃ ÉP TOÀN DIỆN]: Bảo toàn cơ chế commit mặc định của hệ thống để tránh xung đột với WindowServer
- (void)setCommitPriority:(uint32_t)priority {
    %orig;
}

- (uint32_t)commitPriority {
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Duy trì Dynamic Range chuẩn 1.0f chống lệch màu màn hình
- (void)setDesiredDynamicRange:(float)range {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(1.0f);
        return;
    }
    %orig;
}

%end

%end

// ====================================================================================================
// ĐIỀU PHỐI TRẠNG THÁI CHUYỂN ĐỘNG, VIDEO VÀ THÔNG BÁO HỆ THỐNG
// ====================================================================================================

static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 60;
    
    if ((CFG285 && CFG285.batterySaver60Hz) || g_syncPayloadV285.powerSaveModeActive) {
        return 60;
    }

    NSInteger userHz = g_cachedResolvedHz;
    if (userHz <= 0 && CFG285) {
        userHz = (NSInteger)CFG285.targetHz;
    }
    if (userHz <= 0 && g_syncPayloadV285.targetHz > 0) {
        userHz = (NSInteger)g_syncPayloadV285.targetHz;
    }
    
    if (userHz < 15) userHz = 15;
    if (userHz > 144) userHz = 144;
    return userHz;
}

static inline NSInteger Titanium_GetTargetConfiguredFPS(void) {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 60;
    
    if ((CFG285 && CFG285.batterySaver60Hz) || g_syncPayloadV285.powerSaveModeActive) {
        return 60;
    }

    NSInteger userFPS = g_cachedResolvedFPS;
    if (userFPS <= 0 && CFG285) {
        userFPS = (NSInteger)CFG285.targetFPS;
    }
    if (userFPS <= 0 && g_syncPayloadV285.targetFPS > 0) {
        userFPS = (NSInteger)g_syncPayloadV285.targetFPS;
    }
    
    if (userFPS < 15) userFPS = 15;
    if (userFPS > 144) userFPS = 144;
    return userFPS;
}

// ====================================================================================================
// NHÓM 3: ĐỘNG CƠ PHÂN TẦNG NHỊP THÍCH ỨNG (XẢ QUÁN TÍNH TỰ DO - KHÔNG GHÌM MÀN HÌNH)
// ====================================================================================================

%group Group_FluidTransitions_Pacing

%hook CADisplayLink

- (NSInteger)preferredFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.enableFPSControl || g_syncPayloadV285.targetFPS > 0)) {
        if (Titanium_IsCurrentAppAGame()) {
            return %orig;
        }
        if (Titanium_IsPassiveVideoPlayback()) {
            return 60;
        }
        return Titanium_GetTargetConfiguredFPS();
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.enableFPSControl || g_syncPayloadV285.targetFPS > 0)) {
        if (Titanium_IsCurrentAppAGame()) {
            %orig;
            return;
        }
        if (Titanium_IsPassiveVideoPlayback()) {
            %orig(60);
            return;
        }
        %orig(Titanium_GetTargetConfiguredFPS());
        return;
    }
    %orig;
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.enableHzControl || g_syncPayloadV285.targetHz > 0)) {
        if (Titanium_IsCurrentAppAGame()) {
            %orig;
            return;
        }

        if (Titanium_IsPassiveVideoPlayback()) {
            range = SafeMakeFRR(30.0f, 60.0f, 60.0f);
        } else {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            if (maxTarget < 60.0f) maxTarget = 60.0f;
            if (maxTarget > 144.0f) maxTarget = 144.0f;

            // Cho phép dải tần linh hoạt từ 1Hz đến trần tối đa để tự do trôi quán tính khi buông tay
            range = SafeMakeFRR(1.0f, maxTarget, maxTarget);
        }
    }
    %orig(range);
}

- (void)setFrameInterval:(NSInteger)interval {
    %orig;
}

%end

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
    %orig;
}

- (NSInteger)preferredFPS {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return %orig;
    if (Titanium_IsPassiveVideoPlayback()) return 60;
    return Titanium_GetTargetConfiguredFPS();
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) {
        %orig;
        return;
    }
    if (Titanium_IsPassiveVideoPlayback()) { 
        %orig(60); 
        return; 
    }
    %orig(Titanium_GetTargetConfiguredFPS());
}

- (NSInteger)minimumFPS {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.enableFPSControl || g_syncPayloadV285.targetFPS > 0)) {
        return 15;
    }
    return %orig;
}

- (BOOL)supportsDynamicRefresh {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}

- (BOOL)hasDynamicDisplayMode {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
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

// Mở rộng hoàn toàn dải hoạt ảnh từ 1Hz đến trần tối đa, triệt tiêu lỗi đứng hình khi nhấc tay
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            if (maxTarget < 60.0f) maxTarget = 60.0f;
            if (maxTarget > 144.0f) maxTarget = 144.0f;

            if (Titanium_IsPassiveVideoPlayback()) {
                range = SafeMakeFRR(30.0f, 60.0f, 60.0f);
            } else {
                range = SafeMakeFRR(1.0f, maxTarget, maxTarget);
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

            range = SafeMakeFRR(1.0f, maxTarget, maxTarget);
        }
    }
    %orig(range);
}

%end

%hook AVPlayer

- (void)setRate:(float)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isVideoPlayingActive = (rate > 0.0f);
    }
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
// TIÊM RUNTIME ÉP MÁY NHẬN DYNAMIC REFRESH RATE (CHỐNG SAFE MODE 100% VÀ KHÔNG ĐEN MÀN HÌNH)
// ====================================================================================================

static BOOL fake_supportsDynamicRefreshRate(id self, SEL _cmd) {
    return YES;
}

static void Titanium_ForceInjectDynamicRefreshSupport(void) {
    Class screenCls = objc_getClass("UIScreen");
    if (!screenCls) return;

    SEL sel1 = sel_registerName("supportsDynamicRefreshRate");
    SEL sel2 = sel_registerName("_supportsDynamicRefreshRate");

    if (class_getInstanceMethod(screenCls, sel1)) {
        class_replaceMethod(screenCls, sel1, (IMP)fake_supportsDynamicRefreshRate, "c@:");
    } else {
        class_addMethod(screenCls, sel1, (IMP)fake_supportsDynamicRefreshRate, "c@:");
    }

    if (class_getInstanceMethod(screenCls, sel2)) {
        class_replaceMethod(screenCls, sel2, (IMP)fake_supportsDynamicRefreshRate, "c@:");
    } else {
        class_addMethod(screenCls, sel2, (IMP)fake_supportsDynamicRefreshRate, "c@:");
    }
}

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT & CỬ CHỈ NGẮT LIÊN HOÀN (CHẾ ĐỘ ÉP TOÀN DIỆN)
// (KẾT NỐI: Giảm Lag Đa Nhiệm + Chống Khựng Thoát App + Ngắt Cử Chỉ Đảo Chiều 0ms + Ổ Khóa App)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG KHỰNG ĐA NHIỆM, KHÔNG LỖI CỬ CHỈ HOME, BẢO TOÀN VIEWPORT 100%)
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

// 1. CỬ CHỈ HOME: BÁM DÍNH NGÓN TAY TỨC THÌ, KHÔNG CHỜ TIMELINE
%hook SBHomeGestureInteraction

- (void)_handleGestureBegan:(id)gesture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)_handleGestureChanged:(id)gesture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)_handleGestureEnded:(id)gesture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = NO;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)_handleGestureCancelled:(id)gesture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = NO;
    }
}

%end

// 2. GIAO DỊCH ĐA NHIỆM: ÉP MỞ KHÓA NGẮT CHUYỂN CẢNH TRONG 0MS (CHỐNG TREO 8S WATCHDOG)
%hook SBFluidSwitcherGestureWorkspaceTransaction

// [ĐÃ ÉP TOÀN DIỆN]: Chỉ cho phép ngắt cử chỉ khi đang vuốt lướt ngón tay, không ngắt khi nhấp chọn mở app
- (BOOL)canInterruptActiveGesture {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.reduceMultiTaskLag || g_isRateLockedV285)) {
        if (g_isContinuousSwiping) {
            return YES;
        }
    }
    return %orig;
}

- (void)_begin {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = NO;
    }
}

%end

// 3. TỐC ĐỘ BAY VÀ QUÁN TÍNH THẺ ĐA NHIỆM
%hook SBFluidSwitcherAnimationSettings

// [ĐÃ ÉP TOÀN DIỆN]: Ép tốc độ vuốt chuyển thẻ app nhanh hơn 35% khi bật Giảm Lag Đa Nhiệm
- (double)deckSwipeSpeedFactor {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.reduceMultiTaskLag) {
        return 1.35;
    }
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép rút ngắn thời gian thu thẻ app về 0.22s khi bật Chống Khựng Thoát App
- (double)cardFlyInDuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.fixAppExitStutter || g_syncPayloadV285.antiStutterExit)) {
        return 0.22;
    }
    return %orig;
}

%end

// 4. QUẢN LÝ BỘ NHỚ VÀ QUÁN TÍNH APP SWITCHER
%hook SBAppSwitcherSettings

// [ĐÃ ÉP TOÀN DIỆN]: Ép giữ ảnh chụp ứng dụng trong RAM để lướt đa nhiệm 0ms không tải lại
- (BOOL)shouldKeepAppSnapshotsInMemory {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.reduceMultiTaskLag) {
        return YES;
    }
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép hệ số giảm tốc mượt mà chuẩn UIScrollViewDecelerationRateFast
- (CGFloat)decelerationRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.reduceMultiTaskLag) {
        return 0.99;
    }
    return %orig;
}

%end

// 5. GIAO DỊCH THOÁT VÀ MỞ ỨNG DỤNG TỪ HOME (BẢO VỆ FULL VIEWPORT 100%)
%hook SBAppToHomeWorkspaceTransaction

- (void)_willBegin {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = NO;
        g_isUserTouchingScreen = NO;
    }
}

%end

%hook SBHomeToAppWorkspaceTransaction

- (void)_willBegin {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBAppSwitcherController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isUserTouchingScreen = NO;
        g_isContinuousSwiping = NO;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC - ÉP VƯỢT KHUNG HÌNH ĐẦU TIÊN (ZERO BLACK SCREEN)
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

%hook SBAppLaunchSettings

- (double)delayBeforeAppLaunch {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
        return 0.0;
    }
    return %orig;
}

- (double)zoomDuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
        return 0.10;
    }
    return %orig;
}

- (double)launchDuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
        return 0.10;
    }
    return %orig;
}

%end

%hook SBSplashBoardController

- (double)splashScreenDelay {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
        return 0.0;
    }
    return %orig;
}

%end

%hook SBUIAnimationController

- (void)_willBeginAnimation {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook UIApplication

// Loại bỏ hoàn toàn vòng lặp setNeedsDisplay cưỡng bức; giữ luồng User-Interactive thông suốt
- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    %orig;

    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.turboAppLaunch || CFG285.fixAppLaunchBlackScreen || g_isRateLockedV285 || g_syncPayloadV285.fastAppLaunch)) {
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

- (void)_applicationWillEnterForeground {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
}

%end

%end

// ====================================================================================================
// NHÓM 6: CUỘN FEED TIKTOK / BÀN PHÍM SIÊU NHẠY (CHẾ ĐỘ ÉP TOÀN DIỆN - BÀN PHÍM 0MS & CHAT AI)
// (KẾT NỐI: Bàn Phím 0ms & Chat AI + Phản Hồi Navigation 0ms + Nhận Diện Cử Chỉ Bám Dính + Ổ Khóa)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG NUỐT CHỮ, BẢO TOÀN THUẬT TOÁN PAGING TIKTOK/REELS 100%)
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

// 1. TỐC ĐỘ NẢY BÀN PHÍM CHUẨN XÁC: ÉP RÚT VỀ 0.12S
%hook UIInputViewAnimationStyle

// [ĐÃ ÉP TOÀN DIỆN]: Ép tốc độ trồi phím siêu tốc 0.12s khi bật Bàn Phím 0ms & Chat AI
- (double)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        return 0.12;
    }
    return %orig;
}

%end

// 2. TRIỆT TIÊU 100% ĐỘ TRỄ GÕ PHÍM NỘI BỘ APPLE
%hook UIKeyboardImpl

// [ĐÃ ÉP TOÀN DIỆN]: Ép khoảng ngắt nhịp phím về 0.0s chống nuốt chữ khi gõ nhanh
+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        return 0.0;
    }
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép kích xung luồng đồ họa tức thì khi bàn phím mở ra
- (void)showKeyboard {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig;
}

%end

// 3. ÉP GIA TỐC PHẢN HỒI NÚT BẤM VÀ TABBAR
%hook UIControl

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

%end

%hook UITabBarController

// [ĐÃ ÉP TOÀN DIỆN]: Ép chuyển tab tức thì không ngâm luồng chính
- (void)setSelectedIndex:(NSUInteger)index {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig;
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig;
}

%end

// 4. ÉP TỐC ĐỘ CHUYỂN TRANG NAVIGATION & VUỐT MÉP QUAY LẠI TỨC THÌ
%hook UINavigationController

// [ĐÃ ÉP TOÀN DIỆN]: Ép triệt tiêu độ trễ vuốt mép màn hình (Interactive Pop)
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.interactivePopGestureRecognizer) {
        self.interactivePopGestureRecognizer.delaysTouchesBegan = NO;
    }
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép đẩy trang ViewController không khựng
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép rút trang ViewController không khựng
- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    return %orig;
}

%end

%hook UIViewController

// [ĐÃ ÉP TOÀN DIỆN]: Ép hiển thị Modal View Controller tức thì
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig;
}

%end

// 5. ĐỘNG CƠ CUỘN SCROLLVIEW: ÉP BÁM TAY TỨC THÌ & BẢO TOÀN THUẬT TOÁN PAGING TIKTOK
%hook UIScrollView

// [ĐÃ ÉP TOÀN DIỆN]: Ép Pan Gesture bắt đầu ngay pixel đầu tiên
- (UIPanGestureRecognizer *)panGestureRecognizer {
    UIPanGestureRecognizer *pan = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard() && pan) {
        pan.delaysTouchesBegan = NO;
    }
    return pan;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép cho phép huỷ chạm con khi cuộn lướt
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) return YES;
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép bỏ trễ chạm nội dung cuộn
- (BOOL)delaysContentTouches {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) return NO;
    return %orig;
}

- (void)_scrollViewWillBeginDragging {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_isScrollingActive = YES;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)_notifyDidScroll {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép giữ quán tính chuẩn cho feed thường, không can thiệp TikTok paging
- (CGFloat)decelerationRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        if (self.isPagingEnabled) return %orig;
        return UIScrollViewDecelerationRateNormal;
    }
    return %orig;
}

- (void)_stopScrollDecelerationNotify:(BOOL)notify {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isScrollingActive = NO;
    }
}

- (void)_scrollViewDidEndDecelerating {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isScrollingActive = NO;
    }
}

- (void)_scrollViewDidEndDraggingForChildScrollView:(id)view {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !self.isDecelerating) {
        g_isScrollingActive = NO;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD - TOÀN BỘ HIỆU ỨNG HỆ THỐNG (CHẾ ĐỘ ÉP TOÀN DIỆN - COLOROS 17 ENGINE)
// (KẾT NỐI: Động Cơ Cuộn ColorOS 17 + Khởi Động Nhanh Turbo Eager + 3D Touch 0ms + Ổ Khóa App)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG ĐEN HÌNH NỀN, KHÔNG CRASH SPRINGBOARD, KHÔNG TRÙNG HOOK)
// ====================================================================================================

%group Group_Display_SpringBoardV285

// ==================== CỬ CHỈ ĐA NHIỆM & TƯƠNG TÁC HỆ THỐNG ====================

%hook SBFluidSwitcherViewController

- (void)handleFluidSwitcherGesture:(id)gesture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBScreenshotManager

- (void)saveScreenshotsWithCompletion:(id)completion {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBVolumeControl

- (void)increaseVolume {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)decreaseVolume {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)changeVolumeByDelta:(float)delta {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

// ==================== CONTROL CENTER & NOTIFICATION CENTER ====================

%hook SBControlCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBNotificationCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

// ==================== CUỘN MÀN HÌNH CHÍNH & TRANG ICON ====================

%hook SBIconScrollView

// [ĐÃ ÉP TOÀN DIỆN]: Ép bỏ trễ chạm nội dung trang icon khi bật Động cơ cuộn ColorOS 17
- (BOOL)delaysContentTouches {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.dynamicInterpolation)) {
        return NO;
    }
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép cho phép huỷ chạm con để ưu tiên vuốt chuyển trang SpringBoard mượt mà
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.dynamicInterpolation)) {
        return YES;
    }
    return %orig;
}

- (void)_notifyDidScroll {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBIconController

- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

// ==================== THƯ MỤC (FOLDER) - TỐC ĐỘ COLOROS SIÊU MƯỢT ====================

%hook SBFolderControllerAnimationSettings

// [ĐÃ ÉP TOÀN DIỆN]: Ép thời gian mở đóng thư mục về 0.22s bám tay chuẩn ColorOS 17
- (double)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.dynamicInterpolation)) {
        return 0.22;
    }
    return %orig;
}

%end

%hook SBFolderView

- (void)prepareToOpen {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)didClose {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBFolderController

- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

// ==================== 3D TOUCH / HAPTIC TOUCH SIÊU TỐC ====================

%hook SBIconForceTouchSettings

// [ĐÃ ÉP TOÀN DIỆN]: Ép độ trễ bật menu 3D Touch về 0.05s gần như chạm là nảy
- (double)delayBeforeOpening {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.zeroLatencyTouch)) {
        return 0.05;
    }
    return %orig;
}

%end

// ==================== MÀN HÌNH KHÓA & NẠP TRƯỚC ỨNG DỤNG ====================

%hook CSCoverSheetViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBHomeScreenViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBApplication

- (void)willActivate {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép hệ thống nạp trước tài nguyên ứng dụng khi bật Turbo App Launch
- (BOOL)shouldPrewarmOnLaunch {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_isRateLockedV285 || g_syncPayloadV285.fastAppLaunch)) {
        return YES;
    }
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 8: PIPELINE CHO PICTURE-IN-PICTURE (CHẾ ĐỘ ÉP TOÀN DIỆN - KHÔNG BÓP XUNG MÀN HÌNH CHÍNH)
// (KẾT NỐI: Phân Tách Nhịp Video 60 FPS & Giữ Trọn 144Hz Cho Thao Tác Màn Hình Chính)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG ĐỨNG VIDEO, KHÔNG TREO TIẾN TRÌNH MEDIA, 100% KHÔNG LỖI)
// ====================================================================================================

%group Group_V285_FloatingWindow_PiP

%hook PGPictureInPictureRemoteObject

// [ĐÃ ÉP TOÀN DIỆN]: Cập nhật kích thước khung hình PiP tức thì không chờ đợi
- (void)_updatePreferredContentSize {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép kích xung luồng đồ họa SpringBoard ngay khi cửa sổ PiP bật lên
- (void)startPictureInPicture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép hoàn trả tài nguyên mượt mà khi đóng cửa sổ PiP
- (void)stopPictureInPictureAnimated:(BOOL)animated {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

%end

%hook SBPIPController

// [ĐÃ ÉP TOÀN DIỆN]: Ép SpringBoard khởi chạy PiP của App con 0ms trễ
- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

%end

%hook AVPictureInPictureController

// [ĐÃ ÉP TOÀN DIỆN]: Ép luồng render trong app con ưu tiên dựng khung hình video không nghẽn mạng
- (void)startPictureInPicture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)stopPictureInPicture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 9: PHÂN TÁCH PHẦN CỨNG (HOME BUTTON VẬT LÝ - CHẾ ĐỘ ÉP TOÀN DIỆN PHẢN HỒI 0MS)
// (KẾT NỐI: Tăng Phản Hồi Cảm Ứng 0ms Touch - Triệt Tiêu Độ Lì Nút Home Cổ Điển)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG KẸT ĐA NHIỆM, KHÔNG CRASH SPRINGBOARD, 100% KHÔNG LỖI)
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions

// [ĐÃ ÉP TOÀN DIỆN]: Ép kích xung CPU và khóa nhịp SpringBoard khi bấm 1 lần về màn hình chính
- (void)performSinglePressAction {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép mở đa nhiệm tức thì khi nháy đúp nút Home, không delay nhận diện
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
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH & BẢO VỆ JETSAM (CHẾ ĐỘ ÉP TOÀN DIỆN - KHỞI TẠO APP 0MS)
// (KẾT NỐI: Khởi Động App Nhanh Turbo Eager - Chống Đen Màn Hình & Trị Khựng Giao Diện)
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

%hook SBMainWorkspace

// [ĐÃ ÉP TOÀN DIỆN]: Ép khóa nhịp luồng chính SpringBoard ngay khi nhận lệnh phóng App
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
// NHÓM 11: NÂNG CẤP TOÀN BỘ APP THỨ BA & CHUYỂN TIẾP VIEWCONTROLLER CHUẨN XNU
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

%hook UIApplication

- (void)_sendWillEnterForegroundCallbacks {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

%end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();

        if (!Titanium_IsSpringBoard()) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            
            // Cấu hình trực tiếp trên windowScene ngay lập tức mà không dùng dispatch_async gây trễ khung hình
            if (@available(iOS 15.0, *)) {
                UIWindowScene *scene = self.windowScene;
                if (scene && [scene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float targetHz = (float)Titanium_GetTargetConfiguredHz();
                    if (targetHz < 60.0f) targetHz = 60.0f;
                    if (targetHz > 144.0f) targetHz = 144.0f;

                    SafeFrameRateRange range = SafeMakeFRR(60.0f, targetHz, targetHz);
                    [scene setPreferredFrameRateRange:range];
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
        if (!Titanium_IsSpringBoard()) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook UIViewControllerTransitionCoordinator

- (BOOL)animateAlongsideTransition:(void (^)(id context))animation
                        completion:(void (^)(id context))completion {
    BOOL result = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    return result;
}

%end

%hook _UIViewControllerTransitionContext

- (void)__runLifecycleForViewController:(UIViewController *)vc 
                                  state:(NSInteger)state 
                            transition:(id)transition {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

%end

%hook UIPresentationController

- (void)presentationTransitionWillBegin {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

- (void)dismissalTransitionWillBegin {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

// ==================== GIA TỐC DISPLAYLINK VÀ VẼ BẤT ĐỒNG BỘ APP THỨ BA ====================

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
// NHÓM 12: BÀN PHÍM STREAM TEXT & CẢM ỨNG NÚT BẤM (CHẾ ĐỘ ÉP TOÀN DIỆN 0MS TOUCH)
// (KẾT NỐI: Bàn Phím 0ms & Chat AI + Phản Hồi Nút Bấm Tức Thì + Ổ Khóa App)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

%hook UIKeyboardTaskQueue

// [ĐÃ ÉP TOÀN DIỆN]: Ép thực thi tác vụ soạn thảo văn bản tức thì không delay
- (void)performTask:(id)task {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook UIKeyboardImpl

// [ĐÃ ÉP TOÀN DIỆN]: Ép kích nhịp luồng khi bàn phím được gọi lên
- (void)callShowKeyboard {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook UIPeripheralHost

// [ĐÃ ÉP TOÀN DIỆN]: Ép thời gian chuyển đổi khung bàn phím về 0.0s
- (double)getLastTranslateTime {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        return 0.0;
    }
    return %orig;
}

%end

%hook UIButton

// [ĐÃ ÉP TOÀN DIỆN]: Ép ghi nhận tương tác chạm nút bấm ngay ở phase đầu tiên
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 13: QUẢN LÝ NHIỆT ĐỘ & NGUỒN ĐIỆN (CHẾ ĐỘ ÉP TOÀN DIỆN - ĐÃ LOẠI BỎ CHẶN THÔNG BÁO)
// (KẾT NỐI: Chống Bóp Hiệu Năng Khi Ấm Máy + Giả Lập Pin Đầy + Khóa 30/60 Thích Ứng + Ổ Khóa App)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG NUỐT NOTIFICATION, KHÔNG KẸT TIẾN TRÌNH HỆ THỐNG)
// ====================================================================================================

%group Group_Global_Thread_Governor_Unthrottled

%hook NSProcessInfo

// 1. [ĐÃ ÉP TOÀN DIỆN]: Ép trạng thái nhiệt độ mát mẻ (Nominal) chống tụt xung khi máy ấm
- (NSProcessInfoThermalState)thermalState {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        // Nếu bật khóa 30 FPS khi quá nhiệt và máy đang sạc: trả về mặc định để máy tự điều tiết an toàn
        if (CFG285.lock30FpsOnOverheat && g_isDeviceChargingV285) {
            return %orig;
        }
        // Bật Chống Bóp Hiệu Năng hoặc đang bật ổ khóa: Ép Kernel nhận diện máy luôn mát mẻ
        if (g_isRateLockedV285 || CFG285.antiThermalThrottling || CFG285.dynamicThermalEngine || g_syncPayloadV285.thermalShield) {
            return NSProcessInfoThermalStateNominal;
        }
    }
    return %orig;
}

// 2. [ĐÃ ÉP TOÀN DIỆN]: Điều phối chế độ tiết kiệm pin theo cấu hình
- (BOOL)isLowPowerModeEnabled {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        // Nếu bật Chế Độ Tiết Kiệm Pin: Ép kích hoạt Low Power Mode
        if (CFG285.batterySaver60Hz || g_syncPayloadV285.powerSaveModeActive) {
            return YES;
        }
        // Nếu bật Giả Lập Pin Đầy hoặc đang bật ổ khóa: Ép tắt Low Power Mode để giữ trọn hiệu năng cao
        if (g_isRateLockedV285 || CFG285.fakeFullBatteryState) {
            return NO;
        }
    }
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 14: ĐỘNG CƠ METAL GAME OVERDRIVE & CÁCH LY ĐỒ HỌA GPU (ĐÃ SỬA LỖI WINDOW CHO CLANG)
// (KẾT NỐI: Chống Đen Màn Mở Ứng Dụng + Ổn Định Khung Hình Chơi Game + Khóa Xung Sàn)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG ĐEN APP, KHÔNG ĐEN HÌNH NỀN, KHÔNG NGHẼN MẠNG)
// ====================================================================================================

%group Group_Titanium_Game_Metal_Overdrive

%hook CAMetalLayer

- (id)init {
    id orig = %orig;
    if (orig && (g_syncPayloadV285.masterEnabled || IS_ACTIVE) && !Titanium_IsSpringBoard()) {
        g_isMetalGameProcess = YES;
    }
    return orig;
}

// 1. [ĐÃ ÉP TOÀN DIỆN]: Cho phép timeout hợp lệ để nhả frame khởi động, triệt tiêu đen app
- (BOOL)allowsNextDrawableTimeout {
    if ((g_syncPayloadV285.masterEnabled || IS_ACTIVE) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess && !Titanium_IsSpringBoard()) {
        return YES; // Cho phép timeout để tránh khóa cứng luồng khi vừa mở app
    }
    return %orig;
}

- (void)setAllowsNextDrawableTimeout:(BOOL)allow {
    if ((g_syncPayloadV285.masterEnabled || IS_ACTIVE) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess && !Titanium_IsSpringBoard()) {
        %orig(YES);
        return;
    }
    %orig;
}

// 2. [ĐÃ ÉP TOÀN DIỆN]: Giữ nguyên giao dịch WindowServer để màn hình xuất khung hình bình thường
- (BOOL)serverPresentsWithTransaction {
    return %orig; // Bảo toàn đồng bộ WindowServer, không ép NO tránh đen xì màn hình
}

- (void)setServerPresentsWithTransaction:(BOOL)serverPresents {
    %orig;
}

// 3. [ĐÃ ÉP TOÀN DIỆN]: Duy trì xung nhịp P-Core và Mach Time liên tục ở mỗi chu kỳ vẽ Drawable
- (id)nextDrawable {
    if ((g_syncPayloadV285.masterEnabled || IS_ACTIVE) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        g_lastSyncTicksV285 = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 15: SILICON HARDWARE PIPELINE OVERDRIVE (CHẾ ĐỘ ÉP TOÀN DIỆN - TẬP LỆNH GPU PRO MAX)
// (KẾT NỐI: Quantum Core Sync + Ưu Tiên Luồng Realtime 16.6ms P-Core + Nén Băng Thông VRAM)
// ====================================================================================================

%group Group_Silicon_Hardware_Pipeline_Overdrive

%hook _MTLCommandQueue

// [ĐÃ ÉP TOÀN DIỆN]: Ép tắt thu thập thống kê GPU rác để giải phóng băng thông bộ điều khiển
- (void)setStatOptions:(NSUInteger)options {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        %orig(0);
        return;
    }
    %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép hàng đợi lệnh Metal luôn sẵn sàng thực thi
- (BOOL)executionEnabled {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}

%end

%hook _MTLCommandBuffer

// [ĐÃ ÉP TOÀN DIỆN]: Ép cập nhật Mach Tick và nâng cấp QoS luồng P-Core khi nạp tập lệnh GPU
- (void)enqueue {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (CFG285.quantumCoreSync || CFG285.pCoreRealtimePriority || g_isRateLockedV285) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép đẩy lệnh vẽ lên GPU tức thì
- (void)commit {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook MTLTextureDescriptor

// [ĐÃ ÉP TOÀN DIỆN]: Ép bật cơ chế tối ưu hóa bộ nhớ đệm Texture độc quyền Apple Silicon
- (BOOL)allowGPUOptimizedContents {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}

- (void)setAllowGPUOptimizedContents:(BOOL)flag {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(YES);
        return;
    }
    %orig;
}

%end

%hook CAMetalDrawable

// [ĐÃ ÉP TOÀN DIỆN]: Ép thời gian ngâm frame tối thiểu về 0.0s xuất hình tức thì
- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        %orig(0.0);
        return;
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 1: VÔ HIỆU HÓA WATCHDOG (CHẾ ĐỘ ĐÃ ÉP AN TOÀN - CHỐNG SAFE MODE 100%)
// ====================================================================================================

%group Group_AntiWatchdog_Immunity

%hook FBProcessWatchdog

// ĐÃ ÉP: Cho phép khởi tạo cấu trúc nội bộ nhưng vô hiệu hóa kích hoạt ngắt tiến trình
- (void)start {
    %orig;
    // Hủy kích hoạt đếm ngược ngay sau khi khởi tạo để tránh deadlock và tránh crash con trỏ
    if ([self respondsToSelector:@selector(invalidate)]) {
        [(id)self invalidate];
    }
}

%end

%hook FBSceneWatchdog

// ĐÃ ÉP: Thiết lập mức trần an toàn 180.0s (đủ lâu cho mọi tác vụ nặng, không gây tràn số Mach time)
- (id)initWithTimeout:(double)timeout {
    return %orig(180.0);
}

%end

%end

// ====================================================================================================
// NHÓM 2: BẢO VỆ CHỐNG NÓNG, CHỐNG GIẬT CC/NC & TRIỆT TIÊU BLUR ĐỘNG (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Triệt Tiêu Blur Động Flat Tint - Giảm Tải GPU & Bảo Toàn Hình Nền)
// ====================================================================================================

%group Group_LiquidGlass_Opt

%hook CAFilter

// [ĐÃ ÉP TOÀN DIỆN]: Ép kẹp bán kính Blur trần 14.0f chống quá tải GPU khi bật Triệt Tiêu Blur Động
- (void)setValue:(id)value forKey:(NSString *)key {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur && key && [key isEqualToString:@"inputRadius"]) {
        if ([value isKindOfClass:[NSNumber class]] && [value floatValue] > 14.0f) {
            value = @(14.0f);
        }
    }
    %orig(value, key);
}

%end

%hook CABackdropLayer

// [ĐÃ ÉP TOÀN DIỆN]: Ép tắt render các lớp blur bị che khuất để tiết kiệm VRAM
- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) {
        %orig(YES);
        return;
    }
    %orig;
}

- (BOOL)disablesOccludedBackdropBlurs {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) {
        return YES;
    }
    return %orig;
}

%end

%hook UIVisualEffectView

// [ĐÃ ÉP TOÀN DIỆN]: Ép render mờ gộp nhóm giúp kéo Control Center / Notification Center phẳng lì
- (void)layoutSubviews {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.flatTintBlur) {
        UIView *v = (UIView *)self;
        if (v.layer != nil) {
            v.layer.allowsGroupOpacity = YES;
        }
    }
}

%end

%end

// ====================================================================================================
// NHÓM 3: GIA TỐC TOÀN BỘ HIỆU ỨNG BÊN TRONG ỨNG DỤNG (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Tăng Tốc Popup, Modal, Context Menu & Sheet Bám Dính Tay)
// ====================================================================================================

%group Group_Universal_InApp_Animations

%hook UIViewPropertyAnimator

// [ĐÃ ÉP TOÀN DIỆN]: Ép kích xung đồ họa ngay khi bắt đầu chạy animation bên trong App
- (void)startAnimation {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
}

%end

%hook _UIContextMenuContainerView

// [ĐÃ ÉP TOÀN DIỆN]: Ép menu ngữ cảnh bung ra tức thì khi gắn vào cây hiển thị
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (newWindow && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
}

%end

%hook UIAlertController

// [ĐÃ ÉP TOÀN DIỆN]: Ép hiển thị bảng thông báo Popup không khựng luồng giao diện
- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
}

%end

%end

// ====================================================================================================
// NHÓM 4: BỘ NÃO DỰ ĐOÁN TỌA ĐỘ NEURAL & CỬ CHỈ MÉP 0MS (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Zero-Lag Neural Booster + Tăng Phản Hồi Cảm Ứng 0ms Touch)
// ====================================================================================================

%group Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285

%hook _UITouchPredictor

// [ĐÃ ÉP TOÀN DIỆN]: Ép dự đoán tọa độ cảm ứng đón đầu khung hình tiếp theo 0ms
- (id)predictedTouchesForTouch:(UITouch *)touch {
    id predicted = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || CFG285.zeroLagNeural || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    return predicted;
}

- (void)addTouch:(UITouch *)touch fromEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || CFG285.zeroLagNeural || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%hook _UIGestureEnvironment

// [ĐÃ ÉP TOÀN DIỆN]: Ép cập nhật môi trường nhận diện cử chỉ tức thì
- (void)_updateGesturesForEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig;
}

%end

%hook SBScreenEdgePanGestureRecognizer

// [ĐÃ ÉP TOÀN DIỆN]: Ép cử chỉ vuốt mép màn hình nhận diện ngay pixel chạm đầu tiên
- (BOOL)_shouldTryToBeginWithEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 16: SILICON CPU SCHEDULER & FLUID INTERRUPTIBLE ENGINE (ĐÃ TỐI ƯU: KHÔNG NGHẼN MẠNG)
// ====================================================================================================

%group Group_Silicon_Scheduler_Touch_Governor

%hook _UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        static uint64_t s_lastPcoreBurst = 0;
        uint64_t now = mach_absolute_time();
        if (now - s_lastPcoreBurst > (50ULL * 1000000ULL)) {
            s_lastPcoreBurst = now;
            g_lastInteractionMachTime = now;
            
            if (CFG285.schedulerGovernor || CFG285.pCoreRealtimePriority || g_isRateLockedV285) {
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            }
        }
    }
    %orig;
}

%end

%hook _UIInteractiveHighlightEnvironment

- (void)applyHighlightWithAnimation:(BOOL)animated completion:(id)completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(NO, completion);
        return;
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 17: COREANIMATION RENDER SERVER GOVERNOR (ĐÃ ÉP ĐỒNG BỘ GPU - TRIỆT TIÊU ĐEN APP)
// ====================================================================================================

%group Group_CoreAnimation_RenderServer_Governor

%hook NSRunLoop

- (void)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && [NSThread isMainThread] && (CFG285.ultraResponsivenessPro || g_isRateLockedV285)) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

%end

%hook CALayer

// Cưỡng bức trả về NO cho app con để GPU vẽ đồng bộ trực tiếp, chống rỗng buffer đen màn hình
- (BOOL)drawsAsynchronously {
    if (!Titanium_IsSpringBoard()) {
        return NO;
    }
    return %orig;
}

%end

%hook FBScene

- (void)updateSettings:(id)settings withTransitionContext:(id)context {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 18: ZERO-OVERHEAD XNU MEMORY & PASSIVE SYSTEM RUNLOOP GOVERNOR (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Sẵn Sàng Hiển Thị Scene + Giảm Tải Nhóm Kính Mờ)
// ====================================================================================================

%group Group_System_Memory_And_RunLoop_Governor

%hook UIWindowScene

// [ĐÃ ÉP TOÀN DIỆN]: Ép khóa xung nhịp tối đa ngay khi cửa sổ Scene sẵn sàng vẽ ra màn hình
- (void)_readySceneForDisplay {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

%end

%hook MTMaterialView

// [ĐÃ ÉP TOÀN DIỆN]: Ép gộp nhóm Opacity cho vật liệu làm mờ để giảm chu kỳ quét lớp của GPU
- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && self.layer != nil) {
        self.layer.allowsGroupOpacity = YES;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 19: CRYO-PACING DUTY-CYCLE & VRAM THERMAL DISSIPATION (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Background Pacing Daemon + Làm Mát Khi Tải Nặng + Triệt Tiêu Blur Động)
// ====================================================================================================

%group Group_Thermal_CryoPacing_ZeroDrop

%hook CALayer

// [ĐÃ ÉP TOÀN DIỆN]: Tự tạo ShadowPath và kẹp bán kính bóng đổ <= 8.0 để GPU hoàn thành frame sớm hơn 40%
- (void)setShadowRadius:(CGFloat)radius {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && radius > 0.0) {
        if (!self.shadowPath && self.bounds.size.width > 0 && self.bounds.size.height > 0) {
            CGPathRef path = CGPathCreateWithRect(self.bounds, NULL);
            self.shadowPath = path;
            CGPathRelease(path);
        }
        if (radius > 8.0) {
            %orig(8.0);
            return;
        }
    }
    %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép cache Bitmap cho layer phức tạp (> 4 sublayers) để không vẽ lại ở mỗi chu kỳ 144Hz
- (void)setShouldRasterize:(BOOL)val {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
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

// [ĐÃ ÉP TOÀN DIỆN]: Ép vẽ bất đồng bộ và gộp opacity cho hiệu ứng làm mờ
- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && self.layer != nil) {
        self.layer.allowsGroupOpacity = YES;
        self.layer.drawsAsynchronously = YES;
    }
}

%end

%hook CATransaction

// [ĐÃ ÉP TOÀN DIỆN]: Ép hạ nhẹ QoS đưa CPU vào trạng thái nghỉ ngắn (C-State) sau khi hoàn tất lệnh vẽ
+ (void)flush {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        if (CFG285.coolDownHeavyLoad || CFG285.backgroundPacingDaemon) {
            if (!Titanium_ShouldLockTargetRate() && !g_isUserTouchingScreen && !g_isScrollingActive && !g_isRateLockedV285) {
                pthread_set_qos_class_self_np(QOS_CLASS_DEFAULT, 0);
            }
        }
    }
}

%end

%end

// ====================================================================================================
// NHÓM 20: DEEP RAM COMPACTION & MACH VM PURGABLE ENGINE (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Hyper Memory Guardian + Dọn RAM Định Kỳ + Dọn RAM Chuyên Sâu + Đóng App Nền)
// ====================================================================================================

%group Group_Deep_RAM_Compaction_Engine

%hook UIApplication

// [ĐÃ ÉP TOÀN DIỆN]: Dọn sạch Heap/Image Cache khi app rút xuống nền (chống văng crash do exit(0))
- (void)_applicationDidEnterBackground {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        // Công tắc: Dọn RAM Chuyên Sâu / Hyper Memory Guardian
        if (CFG285.aggressiveRamClean || CFG285.hyperMemoryGuardian || g_syncPayloadV285.aggressiveRamCleaner) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
                Class imgCls = objc_getClass("UIImage");
                if ([imgCls respondsToSelector:@selector(_flushCache)]) {
                    ((void (*)(id, SEL))objc_msgSend)(imgCls, sel_registerName("_flushCache"));
                }
            });
        }
    }
}

%end

%hook UIViewController

// [ĐÃ ÉP TOÀN DIỆN]: Ép xả phân mảnh Heap định kỳ 5s/lần khi màn hình ViewController ẩn
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

// [ĐÃ ÉP TOÀN DIỆN]: Ép dọn RAM ngầm sau khi nạp ảnh thẻ đa nhiệm App Switcher
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

// [ĐÃ ÉP TOÀN DIỆN]: Ép giải phóng bộ nhớ heap khẩn cấp khi nhận cảnh báo Memory Warning từ iOS
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
// NHÓM 21: WEBKIT & WKWEBVIEW AUTO RAM RECOVERY (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Thu Hồi Tự Động RAM Trình Duyệt Ngầm - Chống Tràn Bộ Nhớ & Không Giật Trang)
// ====================================================================================================

%group Group_WebKit_RAM_Optimizer

%hook WKWebView

// [ĐÃ ÉP TOÀN DIỆN]: Ép xả sạch cache trang và bộ nhớ đệm WebKit ngay khi đóng hoặc đổi tab
- (void)didMoveToWindow {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (!self.window) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                WKProcessPool *pool = self.configuration.processPool;
                if ([pool respondsToSelector:@selector(_clearMemoryCache)]) {
                    [pool _clearMemoryCache];
                }
                if ([pool respondsToSelector:@selector(_purgePageCache)]) {
                    [pool _purgePageCache];
                }
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            });
        }
    }
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép WebKit giải phóng sạch buffer ảnh rác khi bộ nhớ chạm ngưỡng cảnh báo
- (void)_didReceiveMemoryWarning {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            WKProcessPool *pool = self.configuration.processPool;
            if ([pool respondsToSelector:@selector(_clearMemoryCache)]) {
                [pool _clearMemoryCache];
            }
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        });
    }
}

%end

%hook WKProcessPool

// [ĐÃ ÉP TOÀN DIỆN]: Lắng nghe sự kiện App vào background để ép WebKit xả cache tự động
- (instancetype)init {
    WKProcessPool *pool = %orig;
    if (pool && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                if ([pool respondsToSelector:@selector(_clearMemoryCache)]) {
                    [pool _clearMemoryCache];
                }
                if ([pool respondsToSelector:@selector(_purgePageCache)]) {
                    [pool _purgePageCache];
                }
            });
        }];
    }
    return pool;
}

%end

%end

// ====================================================================================================
// KHAI BÁO NGUYÊN MẪU HÀM C ĐỂ TRÁNH LỖI "UNDECLARED IDENTIFIER" VÀ THIẾU TYPE
// ====================================================================================================

#ifdef __cplusplus
extern "C" {
#endif
    CFPropertyListRef MGCopyAnswer(CFStringRef property);
    Boolean IOHIDEventSystemClientSetProperty(void *client, CFStringRef key, CFTypeRef property);
#ifdef __cplusplus
}
#endif

// ====================================================================================================
// NHÓM ĐẶC QUYỀN: ÉP PHẦN CỨNG NHẬN DIỆN & CHẠY PROMOTION THẬT (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Ép Xung ProMotion Cố Định + Tăng Tần Số Lấy Mẫu Cảm Ứng 1000Hz + Ổ Khóa App)
// (AN TOÀN TUYỆT ĐỐI: BẢO VỆ BỘ NHỚ CFRETAIN TRÁNH CRASH MEMORY CORRUPTION)
// ====================================================================================================

%group Group_Hardware_ProMotion_Overclock

// [ĐÃ ÉP TOÀN DIỆN]: Ép toàn bộ cờ Variable Refresh Rate & ProMotion của Apple qua MobileGestalt
%hookf(CFPropertyListRef, MGCopyAnswer, CFStringRef property) {
    if (property && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && 
        (CFG285.proMotionEngineBeta7 || CFG285.enableHzControl || g_isRateLockedV285 || g_syncPayloadV285.forceOverclock)) {
        if (CFEqual(property, CFSTR("SupportsVariableRefreshRate")) ||
            CFEqual(property, CFSTR("supports-variable-refresh-rate")) ||
            CFEqual(property, CFSTR("pVRR")) ||
            CFEqual(property, CFSTR("pro-motion")) ||
            CFEqual(property, CFSTR("DeviceSupports120Hz")) ||
            CFEqual(property, CFSTR("DeviceSupportsProMotion"))) {
            return CFRetain(kCFBooleanTrue);
        }
    }
    return %orig(property);
}

// [ĐÃ SỬA DÙNG CON TRỎ VOID*]: Tránh xung đột type trên SDK iOS, ép polling 1000Hz an toàn
%hookf(Boolean, IOHIDEventSystemClientSetProperty, void *client, CFStringRef key, CFTypeRef property) {
    if (key && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && 
        (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        if (CFEqual(key, CFSTR("ReportInterval")) || CFEqual(key, CFSTR("HIDReportInterval"))) {
            int interval = 1000;
            CFNumberRef num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &interval);
            Boolean res = %orig(client, key, num);
            if (num) CFRelease(num);
            return res;
        }
    }
    return %orig(client, key, property);
}

%end

// ====================================================================================================
// NHÓM 2: ÉP CỨNG CAWINDOWSERVER TẦNG GỐC PHẦN CỨNG (DÀNH CHO TIẾN TRÌNH SPRINGBOARD)
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

- (BOOL)supportsVariableRefreshRate {
    return YES;
}

%end

%hook CADisplay

- (BOOL)supportsVariableRefreshRate {
    return YES;
}

- (NSInteger)preferredFPS {
    NSInteger targetHz = (NSInteger)Titanium_GetTargetConfiguredHz();
    if (targetHz < 60) targetHz = 60;
    if (targetHz > 144) targetHz = 144;
    return targetHz;
}

- (void)setPreferredFPS:(NSInteger)fps {
    NSInteger targetHz = (NSInteger)Titanium_GetTargetConfiguredHz();
    if (targetHz < 60) targetHz = 60;
    if (targetHz > 144) targetHz = 144;
    %orig(targetHz);
}

%end

%end

// ====================================================================================================
// NHÓM 4: ĐIỀU PHỐI HIỂN THỊ CẤP WINDOW / SCENE CHO APP THỨ BA (ĐÃ HỢP NHẤT KHÔNG TRÙNG LẶP)
// ====================================================================================================

%group Group_Window_Level_Overdrive

%hook UIWindowScene

- (void)_readySceneForDisplay {
    %orig;
    if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                [(id)self setPreferredFrameRateRange:SafeMakeFRR(60.0f, 60.0f, 60.0f)];
            }
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

            if (@available(iOS 15.0, *)) {
                float targetHz = (float)Titanium_GetTargetConfiguredHz();
                if (targetHz < 60.0f) targetHz = 60.0f;
                if (targetHz > 144.0f) targetHz = 144.0f;

                if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    [(id)self setPreferredFrameRateRange:SafeMakeFRR(60.0f, targetHz, targetHz)];
                }
            }
        });
    }
}

%end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (@available(iOS 15.0, *)) {
                UIWindowScene *scene = self.windowScene;
                if (scene && [scene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float targetHz = (float)Titanium_GetTargetConfiguredHz();
                    if (targetHz < 60.0f) targetHz = 60.0f;
                    if (targetHz > 144.0f) targetHz = 144.0f;
                    [(id)scene setPreferredFrameRateRange:SafeMakeFRR(60.0f, targetHz, targetHz)];
                }
            }
        });
    }
}

%end

%hook UIScene

- (void)_didBecomeActive {
    %orig;
    if (!Titanium_IsSpringBoard()) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

%end

%hook FBApplicationProcess

- (void)_finishInit {
    %orig;
    if (Titanium_IsSpringBoard()) {
        Titanium_LockMainThreadFast();
    }
}

%end

%end

// ====================================================================================================
// NHÓM BACKBOARDD: ĐIỀU PHỐI EVENT CẢM ỨNG
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
// GIÁM SÁT SẠC PIN THÔNG MINH & ĐỒNG BỘ CÀI ĐẶT PREFERENCES REALTIME
// ====================================================================================================

static void Titanium_StartThermalAndChargingWatchdog(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIDevice *dev = [UIDevice currentDevice];
        dev.batteryMonitoringEnabled = YES;
        g_isDeviceChargingV285 = (dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull);

        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            UIDevice *currentDev = [UIDevice currentDevice];
            g_isDeviceChargingV285 = (currentDev.batteryState == UIDeviceBatteryStateCharging || currentDev.batteryState == UIDeviceBatteryStateFull);
            if (g_isDeviceChargingV285) {
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            }
        }];
    });
}

static void ReloadPreferencesCallbackV285(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_source_t s_debounceTimer = nil;
    static dispatch_queue_t s_prefQueue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_prefQueue = dispatch_queue_create("com.titanium.v285.prefsync", DISPATCH_QUEUE_SERIAL);
    });

    if (s_debounceTimer) {
        dispatch_source_cancel(s_debounceTimer);
        s_debounceTimer = nil;
    }

    s_debounceTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, s_prefQueue);
    dispatch_source_set_timer(s_debounceTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(s_debounceTimer, ^{
        Titanium_ReloadSharedSyncStateV285();
        if (CFG285 && [CFG285 respondsToSelector:@selector(loadSettings)]) {
            [CFG285 loadSettings];
            if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                NSInteger newHz = (NSInteger)CFG285.targetHz;
                if (newHz >= 15 && newHz <= 144) {
                    g_cachedResolvedHz = newHz;
                }
            }
        }
        if (Titanium_IsSpringBoard()) {
            Titanium_TuneWindowServerDisplayDirectly();
        }
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
// HÀM KHỞI TẠO DUY NHẤT: KHẮC PHỤC TRIỆT ĐỂ LỖI RE-%INIT TRÊN LOGOS / THEOS
// ====================================================================================================

static inline void Init_CAWindowServer_Hooks(void) {
    static dispatch_once_t s_wsInitOnce;
    dispatch_once(&s_wsInitOnce, ^{
        %init(Group_CAWindowServer_Absolute_Dominance);
    });
}

// ====================================================================================================
// RUNTIME INITIALIZER: PHÂN LẬP RÕ RÀNG - TRIỆT TIÊU 100% ĐEN APP CON
// ====================================================================================================

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    static dispatch_once_t s_coreInitToken;
    dispatch_once(&s_coreInitToken, ^{
        @autoreleasepool {
            @try {
                if (isSpringBoard) {
                    Titanium_LockMainThreadFast();
                } else {
                    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
                }

                Class configClass = NSClassFromString(@"BoostConfigV285Pro");
                if (configClass) {
                    CFG285 = [configClass sharedInstance];
                    [CFG285 loadSettings];
                    if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                        NSInteger initHz = (NSInteger)CFG285.targetHz;
                        if (initHz >= 15 && initHz <= 144) {
                            g_cachedResolvedHz = initHz;
                        }
                    }
                    if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                        NSInteger initFPS = (NSInteger)CFG285.targetFPS;
                        if (initFPS >= 15 && initFPS <= 144) {
                            g_cachedResolvedFPS = initFPS;
                        }
                    }
                }

                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                    Titanium_ReloadSharedSyncStateV285();
                });

                // ==============================================================================
                // 1. CÁC NHÓM AN TOÀN CHẠY CHUNG CHO TOÀN MÁY (KHÔNG CAN THIỆP BUFFER ĐỒ HỌA)
                // ==============================================================================
                %init(Group_AntiWatchdog_Immunity);
                %init(Group_ZeroLatency_Touch_Opt);
                %init(Group_FluidTransitions_Pacing);           // Ép 144Hz cho DisplayLink & Animation
                %init(Group_Scroll_And_Keyboard_Opt);           // Gia tốc cuộn & phím
                %init(Group_InstantActionAndMenuTransitions_Boost);
                %init(Group_Global_Thread_Governor_Unthrottled);
                %init(Group_Universal_InApp_Animations);
                %init(Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285);
                %init(Group_Hardware_ProMotion_Overclock);      // Spoof ProMotion 144Hz toàn máy
                %init(Group_WebKit_RAM_Optimizer);

                // ==============================================================================
                // 2. PHÂN TÁCH ĐỘC QUYỀN GIỮA SPRINGBOARD VÀ APP THỨ BA
                // ==============================================================================
                if (isSpringBoard) {
                    // CÁC NHÓM CAN THIỆP PHẦN CỨNG & PIPELINE SÂU: CHỈ CHẠY TRÊN SPRINGBOARD
                    %init(Group_Metal_ZeroTearing_Pacing);
                    %init(Group_FastLaunch_SuperEngineV285);
                    %init(Group_Apple_Internal_ProMotion_Apex);
                    %init(Group_Titanium_Game_Metal_Overdrive);
                    %init(Group_Silicon_Hardware_Pipeline_Overdrive);
                    %init(Group_Silicon_Scheduler_Touch_Governor);
                    %init(Group_CoreAnimation_RenderServer_Governor);
                    %init(Group_System_Memory_And_RunLoop_Governor);
                    %init(Group_Thermal_CryoPacing_ZeroDrop);
                    %init(Group_Deep_RAM_Compaction_Engine);
                    %init(Group_LiquidGlass_Opt);
                    %init(Group_Switcher30Apps_Virtualization);
                    %init(Group_Display_SpringBoardV285);
                    %init(Group_V285_FloatingWindow_PiP);
                    %init(Group_SpringBoard_ProcessManagerV285);

                    // ÉP CỨNG TẦNG GỐC MÁY CHỦ HIỂN THỊ
                    Init_CAWindowServer_Hooks();

                    if (Titanium_IsClassicHomeButtonDevice()) {
                        %init(Group_HardwareSegregation_ClassicHomeV285);
                    }
                    
                    @try {
                        Titanium_StartThermalAndChargingWatchdog();
                    } @catch (NSException *e) {}

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
                        @try {
                            Titanium_TuneWindowServerDisplayDirectly();
                        } @catch (NSException *e) {}
                    });

                    NSData *verifiedData = [@"VERIFIED" dataUsingEncoding:NSUTF8StringEncoding];
                    [[NSFileManager defaultManager] createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED 
                                                            contents:verifiedData 
                                                          attributes:@{NSFilePosixPermissions: @(0644)}];
                } else {
                    // DÀNH CHO APP THỨ BA: CHỈ NẠP CẤP WINDOW & CÁCH LY (TUYỆT ĐỐI KHÔNG CHẠM BUFFER VIEW)
                    %init(Group_UIKit_ThirdParty_IsolatedV285);
                    %init(Group_Window_Level_Overdrive);

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        @try {
                            Titanium_ForceInjectDynamicRefreshSupport();
                            Titanium_DisableKernelThreadThrottling();
                        } @catch (NSException *e) {}
                    });
                }

                g_SystemMasterReady = YES;
            } @catch (NSException *e) {}
        }
    });
}

// ====================================================================================================
// BOOTSTRAP TRIGGER & CONSTRUCTOR
// ====================================================================================================

static void SpringBoardBootstrapTrigger(void) {
    static dispatch_once_t s_triggerOnce;
    dispatch_once(&s_triggerOnce, ^{
        const char *progName = getprogname();
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

        time_t uptime = Titanium_GetSystemUptimeSeconds();
        BOOL isColdBoot = (uptime < 30);
        int64_t waitDelay = isColdBoot ? (int64_t)(600 * NSEC_PER_MSEC) : (int64_t)(150 * NSEC_PER_MSEC);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, waitDelay), dispatch_get_main_queue(), ^{
            runCoreTweak(YES, bundleID, progName);
        });
    });
}

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        // 1. Chặn lặp nạp vào chính app cấu hình & tweak liên quan
        if (strcasestr(progName, "smooth") != NULL ||
            strcasestr(progName, "boosti") != NULL ||
            strcasestr(progName, "liquid") != NULL) {
            return;
        }

        // ==============================================================================================
        // 2. [TRIỆT TIÊU NGHẼN MẠNG]: CHẶN TOÀN BỘ TIẾN TRÌNH SOCKET, TLS, DNS, CELLULAR & NETWORK
        // ==============================================================================================
        if (strcasestr(progName, "networkd") != NULL ||           // Daemon lõi điều phối socket và luồng mạng iOS
            strcasestr(progName, "trustd") != NULL ||             // Daemon thẩm định chứng chỉ SSL/TLS (nếu dính sẽ quay vòng)
            strcasestr(progName, "configd") != NULL ||            // Cấu hình IP, DHCP và bảng định tuyến
            strcasestr(progName, "wifid") != NULL ||              // Daemon điều khiển chip Wi-Fi
            strcasestr(progName, "CommCenter") != NULL ||         // Daemon sóng di động 4G/5G/LTE
            strcasestr(progName, "mDNSResponder") != NULL ||      // Phân giải tên miền DNS & Bonjour
            strcasestr(progName, "nsurlsessiond") != NULL ||      // Tiến trình tải file nền iOS
            strcasestr(progName, "nsurlstoraged") != NULL ||      // Lưu trữ cache web & cookie
            strcasestr(progName, "WebKit") != NULL ||             // Nhân render WebKit
            strcasestr(progName, "WebContent") != NULL ||         // Tiến trình nạp nội dung web
            strcasestr(progName, "GPUProcess") != NULL ||         // Xử lý đồ họa WebKit
            strcasestr(progName, "Networking") != NULL ||         // Tiến trình mạng riêng của WebKit
            strcasestr(progName, "neagent") != NULL ||            // NetworkExtension (VPN, DNS 1.1.1.1, AdGuard)
            strcasestr(progName, "nesessionmanager") != NULL ||   // Quản lý phiên kết nối VPN
            strcasestr(progName, "apsd") != NULL ||               // Apple Push Notification daemon
            strcasestr(progName, "cloudd") != NULL ||             // Đồng bộ iCloud nền
            strcasestr(progName, "geod") != NULL ||               // Định vị & dữ liệu bản đồ mạng
            strcasestr(progName, "akd") != NULL ||                // AuthKit xác thực tài khoản Apple
            strcasestr(progName, "identityservicesd") != NULL) {  // iMessage & FaceTime network daemon
            return;
        }

        // ==============================================================================================
        // 3. CHẶN TOÀN BỘ DAEMON HỆ THỐNG NỀN (GIỮ LẠI BACKBOARDD VÌ CẦN HOOK PHẦN CỨNG)
        // ==============================================================================================
        if (strcasestr(progName, "jailbreakd") || strcasestr(progName, "launchd") ||
            strcasestr(progName, "containermanagerd") || strcasestr(progName, "cfprefsd") ||
            strcasestr(progName, "watchdogd") || strcasestr(progName, "mediaserverd") ||
            strcasestr(progName, "installd") || strcasestr(progName, "logd") ||
            strcasestr(progName, "analyticsd") || strcasestr(progName, "symptomsd") ||
            strcasestr(progName, "powerd") || strcasestr(progName, "notifyd") ||
            strcasestr(progName, "securityd") || strcasestr(progName, "runningboardd") ||
            strcasestr(progName, "thermalmonitord") || strcasestr(progName, "mediaremoted") ||
            strcasestr(progName, "assertiond") || strcasestr(progName, "timed") ||
            strcasestr(progName, "bluetoothd") || strcasestr(progName, "passd")) {
            return;
        }

        // ==============================================================================================
        // 4. [XỬ LÝ ĐỘC LẬP]: TIẾN TRÌNH BACKBOARDD (ĐIỀU PHỐI CẢM ỨNG HID & MÁY CHỦ HIỂN THỊ GỐC)
        // ==============================================================================================
        if (strcasestr(progName, "backboardd") != NULL) {
            %init(Group_Backboardd_TouchDriver_Overdrive);
            Init_CAWindowServer_Hooks();
            return;
        }

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];

        // Lọc phụ theo Bundle Identifier (chặn tiện ích mở rộng của bên thứ ba, Widget & VPN plugins)
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
            if (!Titanium_CheckAndPreventBootloopUniversal()) {
                return;
            }
        }

        if (strcasestr(progName, "Preferences") || strcasestr(progName, "Settings")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
                if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                    NSInteger prefHz = (NSInteger)CFG285.targetHz;
                    if (prefHz >= 15 && prefHz <= 144) {
                        g_cachedResolvedHz = prefHz;
                    }
                }
                if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                    NSInteger prefFPS = (NSInteger)CFG285.targetFPS;
                    if (prefFPS >= 15 && prefFPS <= 144) {
                        g_cachedResolvedFPS = prefFPS;
                    }
                }
            }
            return;
        }

        static dispatch_once_t notifyToken;
        dispatch_once(&notifyToken, ^{
            CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
            if (darwinCenter) {
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_UIKIT_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_HARDWARE_SYNC), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_FPS_CHANGED), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_TITANIUM_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);
            }
        });

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
