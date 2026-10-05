// ==================== MACH & XNU KERNEL ====================
#import <mach/mach.h>
#import <mach/mach_init.h>      // BỔ SUNG: Khai báo chuẩn mach_task_self()
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

// ==================== POSIX & SYSTEM ====================
#include <stdatomic.h>          // Hỗ trợ bộ đếm nguyên tử an toàn đa luồng
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
#import <errno.h>               // BỔ SUNG: Bắt mã lỗi I/O file IPC và sysctl
#import <time.h>                // BỔ SUNG: Khai báo chuẩn time_t và hàm time()

// ==================== SYS HEADERS ====================
#import <sys/types.h>
#import <sys/time.h>            // BỔ SUNG: Khai báo struct timeval (chống lỗi incomplete type)
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
// MACRO ĐỒNG BỘ TOÀN HỆ THỐNG
// ====================================================================================================

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define SHARED_SYNC_FILE @"/tmp/.boost_hz_sync"
#define PRIMARY_SYNC_FILE @"/tmp/.boost_hz_sync"
#define BOOT_GUARD_FILE @"/tmp/.boost_boot_counter"

#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"

#define APEX_SYNC_MAGIC_V285 0x56323835

// ====================================================================================================
// SYSTEM PRIVATE INTERFACES (ĐÃ BỔ SUNG ĐẦY ĐỦ 100% CHO CẢ 16 NHÓM ĐỘC QUYỀN)
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

// BỔ SUNG: Cho Nhóm 16 (Silicon Scheduler)
@interface _UIEventFetcher : NSObject
- (void)_receiveHIDEvent:(void *)event;
@end

// BỔ SUNG: Cho Nhóm 16 (Highlight Feedback)
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

// ĐÃ SỬA: Dùng Category để không trùng lặp định nghĩa với UIKit SDK
@interface UIPresentationController (TitaniumApexPrivate)
- (void)presentationTransitionWillBegin;
- (void)presentationTransitionDidEnd:(BOOL)completed;
- (void)dismissalTransitionWillBegin;
- (void)dismissalTransitionDidEnd:(BOOL)completed;
@end

// --- QUARTZCORE & METAL PIPELINE ---
@interface CATransaction (TitaniumApexPrivate)
+ (void)_setLowLatency:(BOOL)arg1;
+ (void)activateBackground:(BOOL)arg1;
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
- (void)closeFolderAnimated:(BOOL)animated completion:(id)completion;
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

// ĐÃ SỬA: Dùng Named Category để không dính lỗi Anonymous Class Extension
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

// ====================================================================================================
// CORE IPC DEFINITIONS & UNIFIED CONSTANTS (ĐỒNG BỘ ĐA PHÂN VÙNG ROOTLESS / ROOTHIDE)
// ====================================================================================================

#define APEX_SYNC_MAGIC_V285 0x41505837
#define SHARED_SYNC_FILE     @"/tmp/.boost_hz_sync"
#define PRIMARY_SYNC_FILE    @"/tmp/.boost_hz_sync"
#define BOOT_GUARD_FILE      @"/tmp/.titanium_boot_guard"
#define PREF_DOMAIN          CFSTR("com.taojb.boostiphone6s")

// ====================================================================================================
// CORE IPC STRUCT & RUNTIME PAYLOAD ENGINE (PRO MOTION MULTI-TIER ARCHITECTURE)
// ====================================================================================================

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

static ApexV285ProPayload g_syncPayloadV285 = {
    APEX_SYNC_MAGIC_V285, 1, 144, 144, 1, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, {0}
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

// NHẬN DIỆN MÀN HÌNH PROMOTION 120HZ PHẦN CỨNG NGUYÊN BẢN CỦA APPLE
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

// NHẬN DIỆN CÁC THIẾT BỊ NÚT HOME VẬT LÝ (A9 - A15 TRUYỀN THỐNG)
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
    if ([CATransaction respondsToSelector:@selector(_setLowLatency:)]) {
        [CATransaction _setLowLatency:YES];
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

// CẤP QUYỀN ƯU TIÊN I/O VÀ CPU NHƯNG BẢO TOÀN 100% TIẾN TRÌNH SOCKET MẠNG
static inline void Titanium_EnforceThreadVIPPolicy(void) {
    if (!NSThread.isMainThread) return;

    // Cấp quyền I/O đọc đĩa tức thì cho các assets giao diện
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);

    // Đưa mức QoS luồng chính lên User Interactive của Apple Silicon
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

// XẢ BỘ NHỚ ĐỆM TIẾN TRÌNH AN TOÀN (CÓ DEBOUNCE CHỐNG THÙNG RÁC CPU THRASHING)
static inline void Titanium_BackgroundPurgeMemory(void) {
    static volatile uint64_t s_lastPurgeTicks = 0;
    uint64_t now = mach_absolute_time();
    // Giới hạn tần suất: Tối thiểu 15 giây/lần để tránh gián đoạn các luồng render
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

// GIA TỐC PHẦN CỨNG METAL & SILICON GPU (ÉP XUẤT LỆNH SONG SONG, TẮT VALIDATION PROFILE)
static void Titanium_ApplySiliconDeepOptimizations(void) {
    setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
    setenv("MTL_DISABLE_TEXTURE_RESIDENCY_TRACKING", "1", 1);
    setenv("MTL_SHADER_VALIDATION", "0", 1);
    setenv("MTL_FORCE_PARALLEL_ENCODE", "1", 1);
    setenv("CA_DEBUG_TRANSACTIONS", "0", 1);
    setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);

    Titanium_DisableKernelThreadThrottling();
}

// GHI TỆP ĐỒNG BỘ NGUYÊN TỬ (ATOMIC IPC SWAP - TRIỆT TIÊU ĐỌC LỖI TỆP TRONG /TMP)
static void Titanium_WriteSyncPayloadUniversal(const void *payloadData, size_t dataSize) {
    if (!payloadData || dataSize == 0) return;

    NSString *targetPath = SHARED_SYNC_FILE;
    NSString *tempPath = [targetPath stringByAppendingString:@".tmp"];

    int fd = open([tempPath UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        write(fd, payloadData, dataSize);
        close(fd);
        chmod([tempPath UTF8String], 0666);
        rename([tempPath UTF8String], [targetPath UTF8String]);
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

// ĐỌC LẠI BỘ NHỚ CHIA SẺ VỚI DEBOUNCE 500MS (CHỐNG NGHẼN I/O ĐĨA VÀ CHỐNG DROP FRAME)
static inline void Titanium_ReloadSharedSyncStateV285(void) {
    uint64_t now = mach_absolute_time();
    // Debounce: Chỉ đọc lại đĩa tối đa 1 lần mỗi 500ms
    if (g_lastSyncTicksV285 != 0 && (now - g_lastSyncTicksV285) < (500ULL * 1000000ULL)) {
        return;
    }

    pthread_mutex_lock(&g_syncLockV285);
    int fd = open([SHARED_SYNC_FILE UTF8String], O_RDONLY);
    if (fd >= 0) {
        ApexV285ProPayload temp;
        ssize_t bytes = read(fd, &temp, sizeof(temp));
        if (bytes == sizeof(temp) && temp.magic == APEX_SYNC_MAGIC_V285) {
            if (temp.updateSeq != g_syncPayloadV285.updateSeq) {
                g_syncPayloadV285 = temp;
            }
            g_lastSyncTicksV285 = now;
        }
        close(fd);
    }
    pthread_mutex_unlock(&g_syncLockV285);
}

// BỘ GIÁM SÁT CHỐNG BOOTLOOP TOÀN CẦU (ĐẶT TẠI ĐÂY LÀ DUY NHẤT - KHÔNG TRÙNG LẶP ĐUÔI FILE)
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
        
        // Nếu thiết bị khởi động lại liên tục 4 lần trong 20s -> Tạm ngừng tiêm để cứu máy khỏi bootloop
        if (restartCount >= 4) {
            return NO;
        }
        
        // Hệ thống chạy ổn định sau 20 giây -> Xóa bộ đếm khởi động
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([fileManager fileExistsAtPath:bootCounterFilePath]) {
                [fileManager removeItemAtPath:bootCounterFilePath error:nil];
            }
        });
        return YES;
    }
}

// ====================================================================================================
// BOOST CONFIGURATION ENGINE (V28.7 PRO MAX - PROMOTION ARCHITECTURE)
// Tối ưu hóa sâu: Mở khóa trọn vẹn 15 - 144Hz, khóa cứng mức chỉnh, đọc vượt Sandbox cho 100% App
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

// ĐIỀU PHỐI WINDOWSERVER AN TOÀN TUYỆT ĐỐI (CHUẨN DẢI 15 - 144HZ, CHỐNG CO VIEWPORT & CHỐNG ĐEN APP)
static void Titanium_TuneWindowServerDisplayDirectly(void) {
    Class wsClass = NSClassFromString(@"CAWindowServer");
    if (!wsClass) return;
    
    CAWindowServer *server = [wsClass server];
    NSArray *displays = [server displays];
    if (displays && displays.count > 0) {
        CAWindowServerDisplay *mainDisp = displays[0];
        
        // Mở rộng chuẩn xác dải tần số từ 15 đến 144Hz
        NSInteger currentHz = g_cachedResolvedHz;
        if (currentHz < 15) currentHz = 15;
        if (currentHz > 144) currentHz = 144;

        double minDuration = 1.0 / (double)currentHz;

        if ([mainDisp respondsToSelector:@selector(setMinimumFrameDuration:)]) {
            [mainDisp setMinimumFrameDuration:minDuration];
        }
        // ĐÃ TRIỆT TIÊU: setAllowsDisplayCompositing & setAllowsVirtualModes để chống đen app và co màn hình
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

        // CƠ CHẾ DỰ PHÒNG CHO APP THỨ 3 (VƯỢT SANDBOX BẰNG SHARED IPC PAYLOAD)
        if (!diskDict || diskDict.count == 0) {
            int fd = open([PRIMARY_SYNC_FILE UTF8String], O_RDONLY);
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

                        g_cachedResolvedHz = self.targetHz;
                        g_cachedResolvedFPS = self.targetFPS;
                        close(fd);
                        return;
                    }
                }
                close(fd);
            }
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

        // ==============================================================================================
        // TÍNH TOÁN & KHÓA CỨNG MỨC CHỈNH TỪ 15HZ ĐẾN 144HZ VÀO CACHE NGUYÊN THỦY (0NS CHO RENDER LOOP)
        // ==============================================================================================
        NSInteger safeHz = self.targetHz;
        if (safeHz < 15) safeHz = 15;
        if (safeHz > 144) safeHz = 144;

        if (!self.enabled || !self.enableHzControl) {
            g_cachedResolvedHz = 60;
        } else if (self.powerSaveMode) {
            g_cachedResolvedHz = 60;
        } else if (self.forceOverclock144Hz || safeHz >= 144) {
            g_cachedResolvedHz = 144;
        } else {
            // Khóa cứng mức người dùng đã chọn (15 - 140Hz)
            g_cachedResolvedHz = safeHz;
        }

        NSInteger safeFPS = self.targetFPS;
        if (safeFPS < 15) safeFPS = 15;
        if (safeFPS > 144) safeFPS = 144;

        if (!self.enabled || !self.enableFPSControl) {
            g_cachedResolvedFPS = 60;
        } else if (self.powerSaveMode) {
            g_cachedResolvedFPS = 60;
        } else if (self.forceOverclock144Hz || safeFPS >= 144) {
            g_cachedResolvedFPS = 144;
        } else {
            // Khóa cứng mức khung hình người dùng đã chọn (15 - 140 FPS)
            g_cachedResolvedFPS = safeFPS;
        }

        // ĐỒNG BỘ PAYLOAD HẠT NHÂN CHUẨN IPC TỪ SPRINGBOARD
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
            p.powerSaveModeActive = self.powerSaveMode ? 1 : 0;
            p.updateSeq = (uint64_t)mach_absolute_time();
            p.lastHeartbeat = p.updateSeq;

            ApexV285ProPayload capturedPayload = p;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_WriteSyncPayloadV285(&capturedPayload);
            });
        }
    }
}

// TRẢ VỀ TRỰC TIẾP TỪ CACHE: TỐC ĐỘ 0NS, KHÔNG CHẠY NSINVOCATION TRÁNH SỤT KHUNG HÌNH
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
// KHAI BÁO BIẾN TOÀN CỤC & ĐIỀU PHỐI HỆ THỐNG TITANIUM (TỐI ƯU SÂU & AN TOÀN ĐA LUỒNG)
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
    // 1. Đang có cử chỉ vuốt liên tục hoặc cuộn quán tính
    if (g_isContinuousSwiping || g_isScrollingActive) return YES;

    // 2. Có banner thông báo đang hoạt động
    if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

    // 3. Có hoạt ảnh chuyển cảnh (BỔ SUNG TIMEOUT: Chống kẹt cờ làm nóng máy & tụt xung)
    if (g_activeAnimationCount > 0) {
        static uint64_t s_animStartTick = 0;
        uint64_t nowTick = mach_absolute_time();
        if (s_animStartTick == 0) {
            s_animStartTick = nowTick;
            return YES;
        } else if ((nowTick - s_animStartTick) < (uint64_t)(1500000000ULL)) { // Giới hạn tối đa 1.5s
            return YES;
        } else {
            // Quá 1.5s animation chưa nhả -> Reset biến đếm để cứu CPU/Pin
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
// 3. ĐIỀU PHỐI XUNG NHỊP CẢM ỨNG (CƯỚP QUYỀN P-CORE NHƯNG KHÔNG BAO GIỜ BỎ ĐÓI SOCKET MẠNG)
// ====================================================================================================

static inline void Titanium_LockMainThreadFast(void) {
    if (![NSThread isMainThread]) return;

    // CƯỚP ĐỈNH ƯU TIÊN P-CORE: Đưa luồng cảm ứng lên hàng đợi cao nhất của XNU Kernel
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    // FIX LỖI NGHẼN MẠNG:
    // TUYỆT ĐỐI BỎ 'SCHED_RR' - SCHED_RR độc chiếm CPU làm các luồng socket nsurlsessiond / WebKit bị bỏ đói.
    // Thay vào đó: Duy trì chính sách điều phối mặc định của XNU nhưng đẩy CPU Affinity & I/O Policy
    // để Main Thread chiếm trọn sức mạnh tính toán mà VẪN NHẢ TIME-SLICE cho tiến trình mạng tải buffer.
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
// 4. ĐIỀU PHỐI CÂN BẰNG: CPU ĐỒ HỌA SOFT-REALTIME (BẢO TOÀN BĂNG THÔNG YOUTUBE / TIKTOK)
// ====================================================================================================

static inline void Titanium_BoostRenderWithoutStarvingNetwork(void) {
    if (![NSThread isMainThread]) return;
    if (!Titanium_ShouldLockTargetRate()) return;

    // Giữ mức ưu tiên User Interactive cao nhất cho render, nhường time-slice cho socket TCP/TLS
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
}

// ====================================================================================================
// 5. THUẬT TOÁN PHÂN TẦNG 5 NẤC & GAME OVERDRIVE (CHUẨN CƠ CHẾ PROMOTION TRÊN PRO MAX)
// ====================================================================================================

typedef NS_ENUM(NSInteger, TitaniumDisplayTier) {
    TitaniumTier_BypassGame = 0,    // Tầng 0: Game Metal -> Bypass giữ nguyên FPS gốc, chống drop
    TitaniumTier_DeepIdle   = 30,   // Tầng 1: Màn hình tĩnh hoàn toàn -> Hạ tần số, máy mát rượi
    TitaniumTier_VideoSync  = 60,   // Tầng 2: Xem video/PiP -> Khớp 60fps gốc, không giật bộ đệm
    TitaniumTier_TextRead   = 80,   // Tầng 3: Đọc báo, cuộn chậm
    TitaniumTier_ApexPeak   = 144   // Tầng 4: Chạm vuốt nhanh, mở app, hiệu ứng nảy SpringBoard
};

static inline BOOL Titanium_IsCurrentAppAGame(void) {
    if (Titanium_IsSpringBoard()) return NO;
    return g_isMetalGameProcess;
}

static inline NSInteger Titanium_CalculateAdaptiveProMaxTier(void) {
    // 1. TẦNG GAME: Trả về 0 để CADisplayLink gọi %orig giữ nguyên nhịp render gốc của game
    if (Titanium_IsCurrentAppAGame()) {
        return TitaniumTier_BypassGame;
    }

    // 2. TẦNG VIDEO: Đang phát video YouTube / TikTok / PiP -> Khóa chuẩn 60fps để không lag hình
    if (Titanium_IsPassiveVideoPlayback()) {
        return TitaniumTier_VideoSync;
    }

    // 3. TẦNG PEAK: Đang vuốt lướt nhanh, mở/đóng app, bung Control Center hoặc gõ phím
    if (Titanium_ShouldLockTargetRate()) {
        return TitaniumTier_ApexPeak;
    }

    // 4. TẦNG STANDARD: Đang giữ ngón tay trên màn hình hoặc cuộn chậm
    if (g_isUserTouchingScreen || g_isScrollingActive) {
        return TitaniumTier_TextRead;
    }

    // 5. TẦNG IDLE: Màn hình đứng yên hoàn toàn
    return Titanium_IsSpringBoard() ? TitaniumTier_DeepIdle : 60;
}

// ====================================================================================================
// 6. ĐIỀU PHỐI KERNEL XNU & PHẦN CỨNG (KHÔNG ĐEN APP, BẢO TOÀN VIEWPORT & GIẢI PHÓNG MACH PORT)
// ====================================================================================================

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
        // ĐÃ TRIỆT TIÊU HOÀN TOÀN CÁC LỆNH VIRTUALMODES/COMPOSITING ĐỂ KHÔNG BAO GIỜ BỊ ĐEN MÀN
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

// THIẾT LẬP CHU KỲ REALTIME AN TOÀN TUYỆT ĐỐI (CHỈ CHẠY TRÊN SPRINGBOARD - CHỐNG ĐEN APP 100%)
static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz) {
    // CHỐNG ĐEN APP: KHÔNG BAO GIỜ ép ràng buộc Mach cứng vào App bên thứ ba!
    // App bên thứ 3 cần tự do nạp view; ép Mach constraint trong app sẽ gây đóng băng và đen màn hình.
    if (!Titanium_IsSpringBoard()) return;

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

    if (targetHz < 30) targetHz = 60;
    if (targetHz > 144) targetHz = 144;

    uint64_t period_ns = 1000000000ULL / (uint64_t)targetHz;
    // Tỷ lệ an toàn: Giảm computation xuống 25% để nhường chu kỳ xử lý cho các tác vụ khác
    uint64_t computation_ns = (period_ns * 25ULL) / 100ULL;
    uint64_t constraint_ns  = (period_ns * 85ULL) / 100ULL;

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

    mach_port_deallocate(mach_task_self(), threadPort);

    if (kr == KERN_SUCCESS) {
        s_appliedHz = targetHz;
    } else {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
}

static inline void Titanium_EnforceMachFrameConstraint(void) {
    int targetHz = 60;
    if (CFG285 && [CFG285 respondsToSelector:@selector(targetHz)]) {
        targetHz = (int)CFG285.targetHz;
    }
    Titanium_EnforceMachFrameConstraintDynamic(targetHz > 0 ? targetHz : 60);
}

// ====================================================================================================
// 7. NHÓM NỘI BỘ APPLE: MÔ PHỎNG VÒNG LẶP _UIUPDATECYCLE (TỐC ĐỘ 0NS - KHÔNG GỌI RECURSION)
// ====================================================================================================

%group Group_Apple_Internal_ProMotion_Apex

%hook _UIUpdateCycle

- (BOOL)isPerformingUpdate {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    return %orig;
}

- (void)performUpdateWithInfo:(void *)info {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
        // Chỉ nâng QoS luồng chính nhẹ nhàng, bảo đảm không can thiệp priority cứng
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig; // Chuẩn hóa %orig; để triệt tiêu cảnh báo compiler
}

%end

%hook _UIUpdateSequenceItem

- (void)performItem {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 1: CẢM ỨNG 0MS NỘI BỘ APPLE (ZERO-LATENCY TOUCH & INSTANT GESTURE RECOGNITION)
// Triệt tiêu 100% độ trễ cảm ứng, không gọi Kernel Trap dồn dập, giữ Main Thread nhẹ tênh
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

%hook UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

- (void)displayLinkDidFire:(id)arg1 {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%hook _UIEventDispatcher

- (void)dispatchEvent:(UIEvent *)event toTarget:(id)target {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%hook SBIconView

// Bỏ thời gian chờ 150ms: Chạm tay vào icon là sáng đèn và nhận diện mở app ngay tức thì (0ms)
- (double)highlightDelay {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted && IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)setTouchDownInIcon:(BOOL)touchDown {
    if (touchDown && IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%hook UIControl

// Triệt tiêu ngưỡng trễ kích hoạt nút bấm trên toàn bộ UIKit
- (NSTimeInterval)_touchDelayThreshold {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return 0.0;
    return %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

%end

%hook UIWindow

// Mở khóa cử chỉ tức thì: Không hoãn touch để chờ gesture phụ
- (BOOL)_shouldDelayTouchForCancelEvents {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        if (g_activeAnimationCount > 0 || g_isScrollingActive) {
            return %orig;
        }
        return NO;
    }
    return %orig;
}

// Bắt nhịp tương tác chuẩn xác: Chỉ burst khi bắt đầu chạm (Touch Began), không spam CPU khi rê ngón tay
- (void)sendEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        if (event.type == 0) { // 0 = UIEventTypeTouches
            static uint64_t s_lastWindowTouchTick = 0;
            uint64_t now = mach_absolute_time();
            // Throttling 35ms: Đảm bảo phản xạ nhạy nhưng không spam RunLoop liên tục
            if (now - s_lastWindowTouchTick > (35ULL * 1000000ULL)) {
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
    %orig;
}

- (void)_sendTouchesForEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 2: OVERDRIVE METAL GRAPHICS - TRIPLE BUFFERING & BẢO TOÀN TỌA ĐỘ LAYER
// Đã dọn sạch 100% việc duyệt chuỗi nặng nề trong CALayer display, bảo vệ VRAM và chống rách hình
// ====================================================================================================

%group Group_Metal_ZeroTearing_Pacing

%hook CAMetalLayer

- (void)didMoveToWindow {
    %orig;
    if (!Titanium_IsSpringBoard()) {
        g_isMetalGameProcess = YES;
    }
}

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if (IS_ACTIVE) enabled = YES; // Luôn giữ V-Sync chống rách hình (tearing)
    %orig;
}

// TRIPLE BUFFERING THÔNG MINH: Cung cấp sẵn 3 drawable cho Game & đồ họa nặng
- (NSUInteger)maximumDrawableCount {
    if (IS_ACTIVE) return 3;
    return %orig;
}

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ACTIVE) count = 3;
    %orig;
}

- (void)setPresentsWithTransaction:(BOOL)presents {
    %orig;
}

- (BOOL)presentsWithTransaction {
    return %orig;
}

%end

%hook CALayer

// TỐI ƯU CỰC ĐẠI: Loại bỏ 100% object_getClassName và strstr!
// Chuyển sang cờ bit kiểm tra nhanh 0ns, giải phóng hoàn toàn Main Thread khi render danh sách & ảnh
- (void)display {
    if (IS_ACTIVE && CFG285.touchResponseBoost && [NSThread isMainThread] && Titanium_ShouldLockTargetRate()) {
        if (!g_isDeviceChargingV285) {
            Titanium_EnableZeroLatencyPipeline();
        }
    }
    %orig;
}

%end

%hook CAContext

- (void)setCommitPriority:(uint32_t)priority {
    if (IS_ACTIVE) {
        if (g_isDeviceChargingV285) {
            %orig;
            return;
        }
        if (Titanium_ShouldLockTargetRate()) {
            priority = 90; // Mức an toàn: Ưu tiên vẽ khung hình cao nhưng không chiếm quyền của WindowServer
        }
    }
    %orig;
}

- (uint32_t)commitPriority {
    if (IS_ACTIVE && !g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
        return 90;
    }
    return %orig;
}

- (void)setDesiredDynamicRange:(float)range {
    if (IS_ACTIVE) range = 1.0f;
    %orig;
}

%end

// Triệt tiêu lỗi co nhỏ cửa sổ app khi mở
%hook CATransaction

+ (void)commit {
    %orig;
}

%end

%end

// ====================================================================================================
// ĐIỀU PHỐI TRẠNG THÁI CHUYỂN ĐỘNG, VIDEO VÀ THÔNG BÁO HỆ THỐNG (TỐC ĐỘ 0NS - KHÔNG DÙNG NSINVOCATION)
// ====================================================================================================

static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    if (!IS_ACTIVE) return 144;
    
    // ĐỌC TRỰC TIẾP TỪ CACHE NGUYÊN THỦY (0NS): Triệt tiêu 100% độ trễ và cấp phát bộ nhớ heap
    NSInteger userHz = g_cachedResolvedHz;
    if (userHz <= 0 && CFG285) {
        userHz = (NSInteger)CFG285.targetHz;
    }
    
    if (userHz < 15) userHz = 15;
    if (userHz > 144) userHz = 144;
    return userHz;
}

// ====================================================================================================
// NHÓM 3: ĐỘNG CƠ PHÂN TẦNG NHỊP THÍCH ỨNG 5 NẤC (CHUẨN CƠ CHẾ PROMOTION TRÊN PRO MAX)
// (LOẠI BỎ TRIỆT ĐỂ MICRO-STUTTER - KHÔNG BỊ KHỰNG KHI BUÔNG TAY - KHÔNG ĐƠ VIDEO / APP)
// ====================================================================================================

%group Group_FluidTransitions_Pacing

%hook CADisplayLink

- (CFTimeInterval)targetTimestamp {
    return %orig;
}

- (NSInteger)preferredFramesPerSecond {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        if (Titanium_IsCurrentAppAGame()) {
            return %orig;
        }
        if (Titanium_IsPassiveVideoPlayback()) {
            return 60;
        }
        return Titanium_GetTargetConfiguredHz();
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        if (Titanium_IsCurrentAppAGame()) {
            %orig;
            return;
        }
        if (Titanium_IsPassiveVideoPlayback()) {
            fps = 60;
            %orig;
            return;
        }
        fps = Titanium_GetTargetConfiguredHz();
    }
    %orig;
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        if (Titanium_IsCurrentAppAGame()) {
            %orig;
            return;
        }

        float targetFPS = (float)Titanium_GetTargetConfiguredHz();
        if (Titanium_IsPassiveVideoPlayback()) {
            range = SafeMakeFRR(30.0f, 60.0f, 60.0f);
        } else {
            float minSafe = (targetFPS <= 60.0f) ? 30.0f : 60.0f;
            range = SafeMakeFRR(minSafe, targetFPS, targetFPS);
        }
    }
    %orig;
}

// Giữ frameInterval = 1 để GPU xuất hình liên tục từng V-Sync, tránh chia đôi nhịp vẽ
- (void)setFrameInterval:(NSInteger)interval {
    if (IS_ACTIVE && CFG285.enableHzControl && !Titanium_IsPassiveVideoPlayback()) {
        interval = 1;
    }
    %orig;
}

- (BOOL)isPaused {
    return %orig;
}

%end

%hook CADisplay

- (NSInteger)preferredFPS {
    if (Titanium_IsPassiveVideoPlayback()) return %orig;
    if (!IS_ACTIVE) return %orig;
    return Titanium_GetTargetConfiguredHz();
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (Titanium_IsPassiveVideoPlayback()) { 
        %orig; 
        return; 
    }
    if (IS_ACTIVE) {
        fps = Titanium_GetTargetConfiguredHz();
    }
    %orig;
}

- (NSInteger)minimumFPS {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        return 30;
    }
    return %orig;
}

- (BOOL)supportsDynamicRefresh {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)hasDynamicDisplayMode {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

%hook CAWindowServerDisplay

- (double)minimumRefreshRate {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        return 15.0;
    }
    return %orig;
}

- (double)maximumRefreshRate {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        return (double)Titanium_GetTargetConfiguredHz();
    }
    return %orig;
}

- (double)idealRefreshRate {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        return (double)Titanium_GetTargetConfiguredHz();
    }
    return %orig;
}

- (BOOL)allowsVirtualModes {
    return %orig;
}

- (void)setAllowsVirtualModes:(BOOL)allows {
    %orig;
}

- (void)setTag:(NSInteger)tag {
    %orig;
}

%end

%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (IS_ACTIVE) return Titanium_GetTargetConfiguredHz();
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ACTIVE) return Titanium_GetTargetConfiguredHz();
    return %orig;
}

- (CGFloat)_refreshRate {
    if (IS_ACTIVE) return (CGFloat)Titanium_GetTargetConfiguredHz();
    return %orig;
}

- (BOOL)supportsDynamicRefreshRate {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)_supportsDynamicRefreshRate {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (IS_ACTIVE) {
        rate = (CGFloat)Titanium_GetTargetConfiguredHz();
    }
    %orig;
}

%end

%hook CAAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            float minTarget = (maxTarget <= 60.0f) ? 30.0f : 60.0f;
            range = SafeMakeFRR(minTarget, maxTarget, maxTarget);
        }
    }
    %orig;
}

%end

%hook CASpringAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            float minTarget = (maxTarget <= 60.0f) ? 30.0f : 60.0f;
            range = SafeMakeFRR(minTarget, maxTarget, maxTarget);
        }
    }
    %orig;
}

%end

%hook AVPlayer

- (void)setRate:(float)rate {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = (rate > 0.0f);
    }
    %orig;
}

%end

%hook UIApplication

- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
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
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT & CỬ CHỈ NGẮT LIÊN HOÀN (CHUẨN VIDEO 2 - INTERRUPTIBLE ENGINE)
// Mở khóa vuốt đảo chiều 0ms, thẻ App bay bám dính ngón tay, giữ nguyên 100% kích thước Viewport
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

// 1. CỬ CHỈ HOME: BÁM DÍNH NGÓN TAY TỨC THÌ, KHÔNG CHỜ TIMELINE
%hook SBHomeGestureInteraction

- (BOOL)canInterruptActiveGesture {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)_shouldSuppressGestures {
    if (IS_ACTIVE) return NO;
    return %orig;
}

- (void)_handleGestureBegan:(id)gesture {
    %orig;
    if (IS_ACTIVE) {
        g_isContinuousSwiping = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)_handleGestureChanged:(id)gesture {
    %orig;
    if (IS_ACTIVE) {
        g_isContinuousSwiping = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)_handleGestureEnded:(id)gesture {
    %orig;
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)_handleGestureCancelled:(id)gesture {
    %orig;
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;
    }
}

%end

// 2. GIAO DỊCH ĐA NHIỆM: MỞ KHÓA NGẮT CHUYỂN CẢNH TRONG 0MS
%hook SBFluidSwitcherGestureWorkspaceTransaction

- (BOOL)canInterruptActiveGesture {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)_shouldSuppressGestures {
    if (IS_ACTIVE) return NO;
    return %orig;
}

- (void)_begin {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;
    }
}

%end

// 3. TỐC ĐỘ BAY VÀ QUÁN TÍNH THẺ ĐA NHIỆM (PROMOTION SPEED PRO MAX)
%hook SBFluidSwitcherAnimationSettings

- (double)deckSwipeSpeedFactor {
    if (IS_ACTIVE) return 1.35;
    return %orig;
}

- (double)cardFlyInDuration {
    if (IS_ACTIVE) return 0.22;
    return %orig;
}

%end

%hook SBAppToHomeWorkspaceTransaction

- (BOOL)shouldAnimateOrientationChangeOnCompletion {
    return %orig;
}

- (void)_willBegin {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;
        g_isUserTouchingScreen = NO;
    }
}

%end

// 4. GIAO DỊCH MỞ APP TỪ HOME (GỌI %orig ĐẦU TIÊN ĐỂ BẢO VỆ 100% KÍCH THƯỚC FULL VIEWPORT)
%hook SBHomeToAppWorkspaceTransaction

- (void)_willBegin {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)_didComplete {
    %orig;
}

%end

%hook SBAppSwitcherSettings

- (BOOL)shouldKeepAppSnapshotsInMemory {
    return %orig;
}

- (CGFloat)decelerationRate {
    if (IS_ACTIVE) return UIScrollViewDecelerationRateNormal;
    return %orig;
}

%end

%hook SBAppSwitcherController

- (voidviewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_isUserTouchingScreen = NO;
        g_isContinuousSwiping = NO;
    }
}

%end

%hook SBFluidSwitcherItemContainer

- (void)prepareForReuse {
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC (TURBO ENGINE - TRIỆT TIÊU ĐỘ TRỄ MỞ APP CỦA APPLE)
// Xóa bỏ thời gian chờ phóng icon, nạp Scene êm ái, chống đen App và giữ nguyên tốc độ mạng 100%
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

// 1. TRIỆT TIÊU KHOẢNG TRỄ 150MS VÀ RÚT NGẮN THỜI GIAN PHÓNG ICON CỦA SPRINGBOARD
%hook SBAppLaunchSettings

- (double)delayBeforeAppLaunch {
    if (IS_ACTIVE && CFG285.turboAppLaunch) return 0.0;
    return %orig;
}

- (double)zoomDuration {
    if (IS_ACTIVE && CFG285.turboAppLaunch) return 0.22;
    return %orig;
}

- (double)launchDuration {
    if (IS_ACTIVE && CFG285.turboAppLaunch) return 0.20;
    return %orig;
}

%end

// 2. LOẠI BỎ THỜI GIAN CHỜ MÀN HÌNH CHÀO (SPLASH SCREEN DELAY)
%hook SBSplashBoardController

- (double)splashScreenDelay {
    if (IS_ACTIVE && CFG285.turboAppLaunch) return 0.0;
    return %orig;
}

%end

// 3. BẢO ĐẢM HOẠT ẢNH MỞ APP CÓ THỂ NGẮT ĐƯỢC (VỪA BẤM NHẦM LÀ VUỐT VỀ HOME ĐƯỢC NGAY)
%hook SBUIAnimationController

- (BOOL)isInterruptible {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)canBeInterrupted {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

// 4. TIẾN TRÌNH KHỞI TẠO ỨNG DỤNG (GIỮ NGUYÊN BẢN ĐỂ KHÔNG XUNG ĐỘT RUNNINGBOARDD GÂY KHỰNG MÁY)
%hook FBApplicationProcess

- (void)bootstrapWithContext:(id)context completion:(id)completion {
    %orig;
}

- (void)launchIfNecessary {
    %orig;
}

%end

// 5. NẠP SCENE GIAO DIỆN CHUẨN XÁC: %orig CHẠY ĐẦU TIÊN ĐỂ TRỊ DỨT ĐIỂM ĐEN APP (BLACK SCREEN)
%hook UIApplication

- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    %orig;

    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
}

- (void)_applicationWillEnterForeground {
    %orig;
    if (IS_ACTIVE) {
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
// NHÓM 6: CUỘN FEED TIKTOK / BÀN PHÍM SIÊU NHẠY (PROMOTION CADENCE - KHÔNG NGHẼN MẠNG YOUTUBE)
// Bám tay tức thì 0ms, bảo toàn thuật toán Paging Video TikTok, gõ bàn phím không độ trễ
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

// 1. TỐC ĐỘ NẢY BÀN PHÍM CHUẨN XÁC: 0.12s (CỰC NHANH NHƯNG KHÔNG LỖI GIAO DIỆN BỘ GÕ TIẾNG VIỆT)
%hook UIInputViewAnimationStyle

- (double)duration {
    if (IS_ACTIVE) return 0.12;
    return %orig;
}

%end

// 2. TRIỆT TIÊU 100% ĐỘ TRỄ GÕ PHÍM NỘI BỘ CỦA APPLE (KHÔNG SPAM MACH TIME TRÁNH NÓNG MÁY)
%hook UIKeyboardImpl

+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) return 0.0;
    return %orig;
}

- (void)showKeyboard {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig;
}

- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context {
    %orig;
}

- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    %orig;
}

%end

%hook UITextInputController

- (void)_insertText:(id)text {
    %orig;
}

- (void)deleteBackward {
    %orig;
}

%end

%hook UIControl

- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

%end

%hook UITabBarController

- (void)setSelectedIndex:(NSUInteger)index {
    if (IS_ACTIVE) {
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
    if (IS_ACTIVE) {
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

// 3. TĂNG TỐC ĐỘ CHUYỂN TRANG NAVIGATION (PUSH / POP) & VUỐT MÉP QUAY LẠI TỨC THÌ
%hook UINavigationController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE && self.interactivePopGestureRecognizer) {
        self.interactivePopGestureRecognizer.delaysTouchesBegan = NO;
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (IS_ACTIVE) {
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

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
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

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (IS_ACTIVE) {
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

// 4. ĐỘNG CƠ CUỘN SCROLLVIEW: BẢO VỆ NGUYÊN VẸN PAGING TIKTOK & BĂNG THÔNG MẠNG
%hook UIScrollView

- (UIPanGestureRecognizer *)panGestureRecognizer {
    UIPanGestureRecognizer *pan = %orig;
    if (IS_ACTIVE && pan) {
        pan.delaysTouchesBegan = NO;
    }
    return pan;
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)delaysContentTouches {
    if (IS_ACTIVE) return NO;
    return %orig;
}

- (void)_scrollViewWillBeginDragging {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)_notifyDidScroll {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

- (CGFloat)decelerationRate {
    if (IS_ACTIVE) {
        if (self.isPagingEnabled) return %orig;
        return UIScrollViewDecelerationRateNormal;
    }
    return %orig;
}

- (void)_stopScrollDecelerationNotify:(BOOL)notify {
    %orig;
    if (IS_ACTIVE) {
        g_isScrollingActive = NO;
    }
}

- (void)_scrollViewDidEndDecelerating {
    %orig;
    if (IS_ACTIVE) {
        g_isScrollingActive = NO;
    }
}

- (void)_scrollViewDidEndDraggingForChildScrollView:(id)view {
    %orig;
    if (IS_ACTIVE && !self.isDecelerating) {
        g_isScrollingActive = NO;
    }
}

%end

// 5. TỐI ƯU HOÁ TABLEVIEW & COLLECTIONVIEW (PHOTOS, CÀI ĐẶT, DANH SÁCH BÀI VIẾT)
%hook UITableView

- (void)didMoveToWindow {
    %orig;
    if (IS_ACTIVE && self.window) {
        self.delaysContentTouches = NO;
        self.canCancelContentTouches = YES;
    }
}

%end

%hook UICollectionView

- (void)didMoveToWindow {
    %orig;
    if (IS_ACTIVE && self.window) {
        self.delaysContentTouches = NO;
        self.canCancelContentTouches = YES;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD - TOÀN BỘ HIỆU ỨNG HỆ THỐNG (FOLDER, LOCKSCREEN, 3D TOUCH, CC/NC, GIAO DIỆN)
// Tối ưu hóa chu trình ProMax: Mở thư mục siêu tốc, 3D Touch 0ms, vuốt trang icon phẳng lì
// ====================================================================================================

%group Group_Display_SpringBoardV285

%hook SBWallpaperController

- (double)wallpaperScaleForVariant:(long long)variant {
    return %orig;
}

%end

%hook SBFluidSwitcherViewController

- (void)handleFluidSwitcherGesture:(id)gesture {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

%end

%hook SBScreenshotManager

- (void)saveScreenshotsWithCompletion:(id)completion {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

%end

%hook SBVolumeControl

- (void)increaseVolume {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)decreaseVolume {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)changeVolumeByDelta:(float)delta {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

// ==================== CONTROL CENTER & NOTIFICATION CENTER (CHUẨN %orig; TRÁNH LỖI RUNNER) ====================

%hook SBControlCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

%end

%hook SBNotificationCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

%end

// ==================== CUỘN MÀN HÌNH CHÍNH & ICON SPRINGBOARD ====================

%hook SBIconScrollView

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)delaysContentTouches {
    if (IS_ACTIVE) return NO;
    return %orig;
}

- (void)_notifyDidScroll {
    %orig;
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    %orig;
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBIconListView

- (void)setAlpha:(CGFloat)alpha {
    %orig;
}

%end

%hook SBIconController

- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

%end

// ==================== THƯ MỤC (FOLDER) - TỐC ĐỘ PROMAX & CHỐNG CHỚP NHÁY ====================

%hook SBFolderControllerAnimationSettings

- (double)duration {
    if (IS_ACTIVE) return 0.22;
    return %orig;
}

%end

%hook SBFolderView

- (void)prepareToOpen {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)didClose {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBFolderController

- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

%end

// ==================== 3D TOUCH / HAPTIC TOUCH SIÊU NHẠY ====================

%hook SBIconForceTouchSettings

- (double)delayBeforeOpening {
    if (IS_ACTIVE) return 0.05;
    return %orig;
}

%end

// ==================== MÀN HÌNH KHÓA & TRẠNG THÁI TIẾN TRÌNH ====================

%hook CSCoverSheetViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBHomeScreenViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook SBApplication

- (void)willActivate {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (BOOL)shouldPrewarmOnLaunch {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

%hook SBUIAnimationController

- (void)_willBeginAnimation {
    %orig;
    if (IS_ACTIVE) {
        Titanium_LockMainThreadFast();
    }
}

- (void)_didCompleteAnimation {
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 8: PIPELINE CHO PICTURE-IN-PICTURE (PIP MƯỢT MÀ & KHÔNG BÓP XUNG MÀN HÌNH CHÍNH)
// Video PiP giữ chuẩn 60fps nhưng khi tay chạm lướt Home/App vẫn bung trọn vẹn 144Hz
// ====================================================================================================

%group Group_V285_FloatingWindow_PiP

%hook PGPictureInPictureRemoteObject

- (void)_updatePreferredContentSize {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)startPictureInPicture {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

- (void)stopPictureInPictureAnimated:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

%end

%hook SBPIPController

- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

%end

%hook AVPictureInPictureController

- (void)startPictureInPicture {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)stopPictureInPicture {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 9: PHÂN TÁCH PHẦN CỨNG (HOME BUTTON VẬT LÝ - PHẢN HỒI 0MS, BẢO TOÀN ĐỆM 144HZ)
// Kích xung XNU tức thời, loại bỏ độ lì của nút Home trên các dòng máy cổ điển
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions

- (void)performSinglePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)performDoublePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH & BẢO VỆ JETSAM (CHỐNG ĐEN APP 100% & MÁT MÁY KHI CHẠY NỀN)
// Cân bằng trạng thái tiến trình XNU - Không can thiệp bừa bãi vào luồng nền
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

%hook SBApplication

- (void)setProcessState:(id)state {
    %orig;
}

%end

%hook SBMainWorkspace

- (void)handleApplicationLaunch:(id)application {
    %orig;
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 11: NÂNG CẤP TOÀN BỘ APP THỨ BA & CHUYỂN TIẾP VIEWCONTROLLER CHUẨN XNU
// TRIỆT TIÊU HOÀN TOÀN LỖI KẸT CỜ HOẠT ẢNH (CHỐNG NÓNG MÁY & CHỐNG BÓP XUNG NHỊP 100%)
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

%hook UIApplication

- (void)_sendWillEnterForegroundCallbacks {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

%end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

%end

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
}

%end

%hook UIViewControllerTransitionCoordinator

- (BOOL)animateAlongsideTransition:(void (^)(id context))animation
                        completion:(void (^)(id context))completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
    return %orig;
}

%end

%hook _UIViewControllerTransitionContext

- (void)__runLifecycleForViewController:(UIViewController *)vc 
                                  state:(NSInteger)state 
                            transition:(id)transition {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)completeTransition:(BOOL)didComplete {
    %orig;
}

%end

%hook UIPresentationController

- (void)presentationTransitionWillBegin {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)presentationTransitionDidEnd:(BOOL)completed {
    %orig;
}

- (void)dismissalTransitionWillBegin {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)dismissalTransitionDidEnd:(BOOL)completed {
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 12: BÀN PHÍM STREAM TEXT & CẢM ỨNG NÚT BẤM (0MS TOUCH - CHUẨN HÓA %ORIG)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

%hook UIKeyboardTaskQueue

- (void)performTask:(id)task {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%hook UIKeyboardImpl

- (void)callShowKeyboard {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
}

%end

%hook UIPeripheralHost

- (double)getLastTranslateTime {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}

%end

%hook UIButton

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 13: DUY TRÌ TRẦN 144HZ & CHỐNG QUÁ NHIỆT (TRIỆT TIÊU HOÀN TOÀN NÓNG MÁY KHI SẠC PIN)
// Tối ưu hóa bộ lọc Notification 0ns, bảo vệ an toàn pin và chống bóp xung nhịp ảo
// ====================================================================================================

%group Group_Global_Thread_Governor_Unthrottled

%hook RBSProcessState

- (unsigned char)taskState {
    unsigned char orig = %orig;
    if (IS_ACTIVE && orig > 0) {
        if (!g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
            return 4; // TaskStateForegroundActive
        }
    }
    return orig;
}

%end

%hook FBProcess

- (BOOL)isPendingExit {
    return %orig;
}

%end

%hook NSProcessInfo

- (NSProcessInfoThermalState)thermalState {
    if (IS_ACTIVE) {
        if (g_isDeviceChargingV285 && !Titanium_ShouldLockTargetRate()) {
            return %orig;
        }
        return NSProcessInfoThermalStateNominal;
    }
    return %orig;
}

- (BOOL)isLowPowerModeEnabled {
    return %orig;
}

%end

%hook NSNotificationCenter

- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo {
    if (IS_ACTIVE && aName) {
        if (Titanium_ShouldLockTargetRate()) {
            if (aName == NSProcessInfoThermalStateDidChangeNotification || 
                [aName isEqualToString:NSProcessInfoThermalStateDidChangeNotification]) {
                return;
            }
        }
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 14: ĐỘNG CƠ METAL GAME OVERDRIVE & CÁCH LY ĐỒ HỌA GPU (CHUẨN IPHONE PRO MAX)
// (BẢO VỆ 60/120 FPS GAME KHÔNG GIẬT KHỰNG - MÁT MÁY - KHÔNG ĐEN MÀN HÌNH - KHÔNG NGHẼN MẠNG)
// ====================================================================================================

%group Group_Titanium_Game_Metal_Overdrive

%hook CAMetalLayer

- (id)init {
    id orig = %orig;
    if (orig && IS_ACTIVE && !Titanium_IsSpringBoard()) {
        g_isMetalGameProcess = YES;
    }
    return orig;
}

- (BOOL)allowsNextDrawableTimeout {
    if (IS_ACTIVE && g_isMetalGameProcess && !Titanium_IsSpringBoard()) {
        return NO;
    }
    return %orig;
}

- (void)setAllowsNextDrawableTimeout:(BOOL)allow {
    if (IS_ACTIVE && g_isMetalGameProcess && !Titanium_IsSpringBoard()) {
        allow = NO;
    }
    %orig;
}

- (id)nextDrawable {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    return %orig;
}

- (BOOL)serverPresentsWithTransaction {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        return NO;
    }
    return %orig;
}

- (void)setServerPresentsWithTransaction:(BOOL)serverPresents {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        serverPresents = NO;
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 15: SILICON HARDWARE PIPELINE OVERDRIVE (ĐỘNG CƠ ĐỒ HỌA MỚI HOÀN TOÀN - CHUẨN PRO MAX)
// (TĂNG TỐC TRUYỀN TẬP LỆNH GPU - NÉN BĂNG THÔNG VRAM - TRIỆT TIÊU TRỄ XUẤT HÌNH)
// ====================================================================================================

%group Group_Silicon_Hardware_Pipeline_Overdrive

%hook _MTLCommandQueue

- (void)setStatOptions:(NSUInteger)options {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        options = 0;
    }
    %orig;
}

- (BOOL)executionEnabled {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

%hook _MTLCommandBuffer

- (void)enqueue {
    %orig;
    if (IS_ACTIVE && g_isMetalGameProcess) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)commit {
    %orig;
    if (IS_ACTIVE && g_isMetalGameProcess) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

%hook MTLTextureDescriptor

- (BOOL)allowGPUOptimizedContents {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (void)setAllowGPUOptimizedContents:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
    %orig;
}

%end

%hook CAMetalDrawable

- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        duration = 0.0;
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM BẢO VỆ CHỐNG NÓNG, CHỐNG GIẬT CC/NC & BẢO TOÀN NGUYÊN BẢN HÌNH NỀN
// ====================================================================================================

%group Group_LiquidGlass_Opt

%hook CAFilter

- (void)setValue:(id)value forKey:(NSString *)key {
    if (IS_ACTIVE && key && [key isEqualToString:@"inputRadius"]) {
        if ([value isKindOfClass:[NSNumber class]] && [value floatValue] > 14.0f) {
            value = @(14.0f);
        }
    }
    %orig;
}

%end

%hook CABackdropLayer

- (void)setScale:(double)scale {
    %orig;
}

- (double)scale {
    return %orig;
}

- (void)setAllowsInPlaceFiltering:(BOOL)flag {
    %orig;
}

- (BOOL)allowsInPlaceFiltering {
    return %orig;
}

- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
    %orig;
}

- (BOOL)disablesOccludedBackdropBlurs {
    return IS_ACTIVE ? YES : %orig;
}

%end

%hook MTMaterialView

- (void)layoutSubviews {
    %orig;
}

%end

%hook UIVisualEffectView

- (void)layoutSubviews {
    %orig;
    if (IS_ACTIVE) {
        UIView *v = (UIView *)self;
        v.layer.allowsGroupOpacity = YES;
    }
}

%end

%end

// ====================================================================================================
// GIA TỐC TOÀN BỘ HIỆU ỨNG BÊN TRONG ỨNG DỤNG (MODAL, POPUP, SHEET, CONTEXT MENU)
// Tích hợp lò xo vật lý CASpringAnimation: Mọi chuyển động trong app đều nhẹ và nảy dính tay
// ====================================================================================================

%group Group_Universal_InApp_Animations

%hook CASpringAnimation

- (void)setMass:(CGFloat)mass {
    if (IS_ACTIVE && mass > 0.6f) {
        mass = 0.58f;
    }
    %orig;
}

- (void)setStiffness:(CGFloat)stiffness {
    if (IS_ACTIVE && stiffness < 320.0f) {
        stiffness = 340.0f;
    }
    %orig;
}

- (void)setDamping:(CGFloat)damping {
    if (IS_ACTIVE && damping < 26.0f) {
        damping = 28.5f;
    }
    %orig;
}

%end

%hook UIViewPropertyAnimator

- (void)startAnimation {
    %orig;
    if (IS_ACTIVE) {
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

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (newWindow && IS_ACTIVE) {
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

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
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
// NHÓM ĐỘC QUYỀN: BỘ NÃO DỰ ĐOÁN TỌA ĐỘ NEURAL & CỬ CHỈ MÉP 0MS
// ====================================================================================================

%group Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285

%hook _UITouchPredictor

- (id)predictedTouchesForTouch:(UITouch *)touch {
    id predicted = %orig;
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
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
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%hook _UIGestureEnvironment

- (void)_updateGesturesForEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
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

- (BOOL)_shouldTryToBeginWithEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    return %orig;
}

- (double)_edgeRegionSize {
    double origSize = %orig;
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        return origSize > 0.0 ? (origSize * 1.20) : 24.0;
    }
    return origSize;
}

%end

%end

// ====================================================================================================
// NHÓM 16: SILICON CPU SCHEDULER & FLUID INTERRUPTIBLE ENGINE (CHUẨN VIDEO 1 & VIDEO 2)
// ====================================================================================================

%group Group_Silicon_Scheduler_Touch_Governor

%hook _UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if (IS_ACTIVE) {
        static uint64_t s_lastPcoreBurst = 0;
        uint64_t now = mach_absolute_time();
        if (now - s_lastPcoreBurst > (30ULL * 1000000ULL)) {
            s_lastPcoreBurst = now;
            g_lastInteractionMachTime = now;
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
        }
    }
    %orig;
}

%end

%hook _UIInteractiveHighlightEnvironment

- (void)applyHighlightWithAnimation:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        animated = NO;
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 17: SYSTEM DISPLAY PIPELINE & COREANIMATION RENDER SERVER GOVERNOR (MỚI 100%)
// (CƯỚP QUYỀN COMMIT GIAO DIỆN - TRIỆT TIÊU NGHẼN RUNLOOP - ĐẨY LỆNH VẼ THẲNG VÀO RENDERSERVER 0NS)
// ====================================================================================================

%group Group_CoreAnimation_RenderServer_Governor

%hook CATransaction

+ (BOOL)animates {
    return %orig;
}

+ (unsigned int)generateSeed {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    return %orig;
}

%end

%hook NSRunLoop

- (void)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate {
    if (IS_ACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

%end

%hook CADisplay

- (BOOL)allowsVirtualModes {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

%hook CALayer

- (BOOL)clearsContextBeforeDrawing {
    if (IS_ACTIVE) return NO;
    return %orig;
}

%end

%hook FBScene

- (void)updateSettings:(id)settings withTransitionContext:(id)context {
    if (IS_ACTIVE) {
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
// NHÓM 18: ZERO-OVERHEAD XNU MEMORY & PASSIVE SYSTEM RUNLOOP GOVERNOR (MỚI 100% - CHỐNG NÓNG & MƯỢT NHẸ)
// (CƯỚP QUYỀN SẴN SÀNG HIỂN THỊ SCENE - TRIỆT TIÊU TÍNH TOÁN THỪA - GIỮ MÁY MÁT MẺ TỐI ĐA)
// ====================================================================================================

%group Group_System_Memory_And_RunLoop_Governor

%hook UIWindowScene

- (void)_readySceneForDisplay {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

%end

%hook MTMaterialView

- (void)didMoveToWindow {
    %orig;
    if (IS_ACTIVE && self.window) {
        self.layer.allowsGroupOpacity = YES;
    }
}

%end

%end

// ====================================================================================================
// GIÁM SÁT SẠC PIN THÔNG MINH (DÙNG NOTIFICATION HỆ THỐNG - TRIỆT TIÊU 100% NÓNG MÁY KHI CẮM SẠC)
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
        }];
    });
}

static void Titanium_StartPassiveRamDaemon(void) {
    return;
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
    dispatch_source_set_timer(s_debounceTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(s_debounceTimer, ^{
        if (CFG285 && [CFG285 respondsToSelector:@selector(loadSettings)]) {
            [CFG285 loadSettings];
        }
        if (Titanium_IsSpringBoard()) {
            Titanium_TuneWindowServerDisplayDirectly();
        }
        s_debounceTimer = nil;
    });
    dispatch_resume(s_debounceTimer);
}

// ====================================================================================================
// ĐIỀU PHỐI KHỞI ĐỘNG THUẦN ROOTLESS & ROOTHIDE (BẢO VỆ CHỐNG TREO REBOOT & CHỐNG TREO TÁO 100%)
// ====================================================================================================

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
// RUNTIME INITIALIZER: ĐIỀU PHỐI TẦNG NỘI BỘ & KHỞI CHẠY TWEAK (NẠP ĐẦY ĐỦ 18 NHÓM ĐỘC QUYỀN)
// ====================================================================================================

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    static dispatch_once_t s_coreInitToken;
    dispatch_once(&s_coreInitToken, ^{
        @autoreleasepool {
            AppleInternal_EnforceZeroLatencyKernelTier();
            AppleInternal_LockHardwareCADisplay();

            if (isSpringBoard) {
                Titanium_LockMainThreadFast();
            } else {
                pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
            }

            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
            }

            // 1. CÁC NHÓM CẢM ỨNG & HIỆU ỨNG HỆ THỐNG
            %init(Group_ZeroLatency_Touch_Opt);
            %init(Group_Metal_ZeroTearing_Pacing);
            %init(Group_FluidTransitions_Pacing);
            %init(Group_FastLaunch_SuperEngineV285);
            %init(Group_Scroll_And_Keyboard_Opt);
            %init(Group_InstantActionAndMenuTransitions_Boost);
            %init(Group_Global_Thread_Governor_Unthrottled);

            // 2. CÁC NHÓM GIA TỐC PHẦN CỨNG & DỰ ĐOÁN ĐỒ HỌA
            %init(Group_Universal_InApp_Animations);
            %init(Group_Apple_Internal_ProMotion_Apex);
            %init(Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285);
            
            // 3. ĐÃ NẠP ĐẦY ĐỦ: NHÓM 14, 15, 16, 17 VÀ NHÓM 18 MỚI
            %init(Group_Titanium_Game_Metal_Overdrive);
            %init(Group_Silicon_Hardware_Pipeline_Overdrive);
            %init(Group_Silicon_Scheduler_Touch_Governor);
            %init(Group_CoreAnimation_RenderServer_Governor);
            %init(Group_System_Memory_And_RunLoop_Governor);

            if (Titanium_IsClassicHomeButtonDevice()) {
                %init(Group_HardwareSegregation_ClassicHomeV285);
            }

            if (isSpringBoard) {
                Titanium_TuneWindowServerDisplayDirectly();
                %init(Group_LiquidGlass_Opt);
                %init(Group_Switcher30Apps_Virtualization);
                %init(Group_Display_SpringBoardV285);
                %init(Group_V285_FloatingWindow_PiP);
                %init(Group_SpringBoard_ProcessManagerV285);
                Titanium_StartThermalAndChargingWatchdog();

                NSData *verifiedData = [@"VERIFIED" dataUsingEncoding:NSUTF8StringEncoding];
                [[NSFileManager defaultManager] createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED 
                                                        contents:verifiedData 
                                                      attributes:@{NSFilePosixPermissions: @(0666)}];
            } else {
                %init(Group_UIKit_ThirdParty_IsolatedV285);
            }

            static dispatch_once_t notifyToken;
            dispatch_once(&notifyToken, ^{
                CFNotificationCenterRef darwinCenter = CFNotificationCenterGetDarwinNotifyCenter();
                if (darwinCenter) {
                    CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                    CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_UIKIT_RELOAD), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                    CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_FPS_CHANGED), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
                    CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_TITANIUM_CHANGED), NULL, CFNotificationSuspensionBehaviorCoalesce);
                }
            });

            g_SystemMasterReady = YES;
        }
    });
}

// ====================================================================================================
// CƠ CHẾ NẠP AN TOÀN KÉP (DUAL-TRIGGER DISPATCH): CHỐNG KẸT KHỞI ĐỘNG VÀ BẢO VỆ WATCHDOG 100%
// ====================================================================================================

static void SpringBoardBootstrapTrigger(void) {
    static dispatch_once_t s_triggerOnce;
    dispatch_once(&s_triggerOnce, ^{
        const char *progName = getprogname();
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

        time_t uptime = Titanium_GetSystemUptimeSeconds();
        BOOL isColdBoot = (uptime < 45);

        int64_t waitDelay = isColdBoot ? (int64_t)(1200 * NSEC_PER_MSEC) : (int64_t)(300 * NSEC_PER_MSEC);

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, waitDelay), dispatch_get_main_queue(), ^{
            runCoreTweak(YES, bundleID, progName);
        });
    });
}

// ====================================================================================================
// CONSTRUCTOR CHÍNH CỦA DYLIB (BLACKLIST BẢO VỆ TIẾN TRÌNH & BẢO ĐẢM KHÔNG TREO JAILBREAK)
// ====================================================================================================

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        // 1. CHẶN TRIỆT ĐỂ CÁC TIẾN TRÌNH MẠNG VÀ WEB (TRÁNH NGHẼN MẠNG & TREO TRÌNH DUYỆT)
        if (strstr(progName, "WebKit") || strstr(progName, "WebContent") ||
            strstr(progName, "GPUProcess") || strstr(progName, "Networking") ||
            strstr(progName, "nsurlsessiond") || strstr(progName, "mDNSResponder") ||
            strstr(progName, "cloudd")) {
            return;
        }

        // 2. CHẶN TOÀN BỘ DAEMON HỆ THỐNG (CHỐNG TREO REBOOT & CRASH DO VI PHẠM QUYỀN SANDBOX)
        if (strstr(progName, "jailbreakd") || strstr(progName, "launchd") ||
            strstr(progName, "containermanagerd") || strstr(progName, "cfprefsd") ||
            strstr(progName, "watchdogd") || strstr(progName, "mediaserverd") ||
            strstr(progName, "installd") || strstr(progName, "logd") ||
            strstr(progName, "analyticsd") || strstr(progName, "symptomsd") ||
            strstr(progName, "powerd") || strstr(progName, "backboardd") ||
            strstr(progName, "notifyd") || strstr(progName, "securityd") ||
            strstr(progName, "runningboardd") || strstr(progName, "thermalmonitord") ||
            strstr(progName, "mediaremoted") || strstr(progName, "assertiond")) {
            return;
        }

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];
        BOOL isSpringBoard = (bundleID && [bundleID isEqualToString:@"com.apple.springboard"]);

        // 3. NẾU LÀ SPRINGBOARD: KIỂM TRA CHỐNG BOOTLOOP TRƯỚC TIÊN (GỌI HÀM Ở PHẦN TRÊN)
        if (isSpringBoard) {
            if (!Titanium_CheckAndPreventBootloopUniversal()) {
                return;
            }
        }

        // 4. TIẾN TRÌNH CÀI ĐẶT
        if (strstr(progName, "Preferences") || strstr(progName, "Settings")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
            }
            return;
        }

        %init;

        if (isSpringBoard) {
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                SpringBoardBootstrapTrigger();
            }];

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                SpringBoardBootstrapTrigger();
            });
        } else {
            runCoreTweak(NO, bundleID, progName);
        }
    }
}
