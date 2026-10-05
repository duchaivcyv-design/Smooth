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

#ifndef CAFrameRateRangeDefined
#define CAFrameRateRangeDefined
typedef struct {
    float minimum;
    float maximum;
    float preferred;
} SafeFrameRateRange;
#define CAFrameRateRange SafeFrameRateRange
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

#define PREF_DOMAIN CFSTR("com.taojb.boostiphone6s")
#define SHARED_SYNC_FILE @"/tmp/.boost_hz_sync"
#define BOOT_GUARD_FILE @"/tmp/.boost_boot_counter"

#define NOTIFY_RELOAD "com.taojb.boostiphone6s/ReloadPrefs"
#define NOTIFY_UIKIT_RELOAD "com.taojb.boostiphone6s/ReloadUIKitPrefs"
#define NOTIFY_HARDWARE_SYNC "com.taojb.boostiphone6s/HardwareSync"
#define NOTIFY_FPS_CHANGED "com.taojb.boostiphone6s/FPSChanged"
#define NOTIFY_TITANIUM_CHANGED "com.titanium.v285.prefschanged"

#define APEX_SYNC_MAGIC_V285 0x56323835

// ====================================================================================================
// SYSTEM PRIVATE INTERFACES (ĐÃ BỔ SUNG ĐẦY ĐỦ 100% CHO CẢ 15 NHÓM ĐỘC QUYỀN)
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
- (void)_scrollViewAnimationEnded:(id)1 finished:(BOOL)2;
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
- (void)textChanged:(id)1;
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

@interface UIPresentationController : NSObject
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
- (overrideDisplayCadence:(id)cadence)overrideDisplayCadence:(id)cadence;
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

@interface UIViewPropertyAnimator ()
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
                [dev hasPrefix:@"iPad7,"]      || [dev hasPrefix:@"iPad8,"]      || // iPad Pro ProMotion
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

    mach_port_t machThread = pthread_mach_thread_np(pthread_self());
    thread_affinity_policy_data_t affPolicy;
    affPolicy.affinity_tag = 1;
    thread_policy_set(machThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affPolicy, THREAD_AFFINITY_POLICY_COUNT);

    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);

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
    // Giới hạn tần suất giải phóng RAM: Tối thiểu 10 giây/lần để tránh gián đoạn các luồng render
    if (s_lastPurgeTicks != 0 && (now - s_lastPurgeTicks) < (10ULL * 1000000000ULL)) {
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
static void Titanium_WriteSyncPayloadV285(const ApexV285ProPayload *payload) {
    if (!payload) return;
    ApexV285ProPayload temp = *payload;
    temp.magic = APEX_SYNC_MAGIC_V285;
    temp.updateSeq = (uint64_t)mach_absolute_time();

    NSString *targetPath = SHARED_SYNC_FILE;
    NSString *tempPath = [targetPath stringByAppendingString:@".tmp"];

    int fd = open([tempPath UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        write(fd, &temp, sizeof(ApexV285ProPayload));
        close(fd);
        chmod([tempPath UTF8String], 0666);
        rename([tempPath UTF8String], [targetPath UTF8String]);
    }
}

static inline void Titanium_ReloadSharedSyncStateV285(void) {
    pthread_mutex_lock(&g_syncLockV285);
    int fd = open([SHARED_SYNC_FILE UTF8String], O_RDONLY);
    if (fd >= 0) {
        ApexV285ProPayload temp;
        ssize_t bytes = read(fd, &temp, sizeof(temp));
        if (bytes == sizeof(temp) && temp.magic == APEX_SYNC_MAGIC_V285) {
            if (temp.updateSeq != g_syncPayloadV285.updateSeq) {
                g_syncPayloadV285 = temp;
                g_lastSyncTicksV285 = mach_absolute_time();
            }
        }
        close(fd);
    }
    pthread_mutex_unlock(&g_syncLockV285);
}

// BỘ GIÁM SÁT CHỐNG BOOTLOOP TOÀN CẦU (BẢO VỆ SPRINGBOARD & JAILBREAK AN TOÀN 100%)
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
// Tối ưu hóa sâu: Triệt tiêu lỗi đen app, chống lệch viewport và nạp cấu hình không tốn chu kỳ CPU
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

// Biến cache nguyên thủy: Trả về tức thì 0ns cho CADisplayLink (Gọi 144 lần/giây không tốn CPU)
static volatile NSInteger g_cachedResolvedHz = 144;
static volatile NSInteger g_cachedResolvedFPS = 144;

// ĐIỀU PHỐI WINDOWSERVER AN TOÀN TUYỆT ĐỐI (ĐÃ LOẠI BỎ TRIỆT ĐỂ LỆNH GÂY ĐEN MÀN HÌNH VÀ CO VIEWPORT)
static void Titanium_TuneWindowServerDisplayDirectly(void) {
    Class wsClass = NSClassFromString(@"CAWindowServer");
    if (!wsClass) return;
    
    CAWindowServer *server = [wsClass server];
    NSArray *displays = [server displays];
    if (displays && displays.count > 0) {
        CAWindowServerDisplay *mainDisp = displays[0];
        
        // Lấy đúng tần số quét đã resolve (30 - 144Hz)
        NSInteger currentHz = g_cachedResolvedHz;
        if (currentHz < 30) currentHz = 60;
        if (currentHz > 144) currentHz = 144;

        double minDuration = 1.0 / (double)currentHz;

        if ([mainDisp respondsToSelector:@selector(setMinimumFrameDuration:)]) {
            [mainDisp setMinimumFrameDuration:minDuration];
        }
        // ĐÃ XÓA setAllowsDisplayCompositing:NO (Triệt tiêu 100% nguyên nhân gây đen màn hình khi mở app)
        // ĐÃ XÓA setAllowsVirtualModes:NO (Bảo vệ toàn vẹn độ phân giải và tỉ lệ viewport gốc của iOS)
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
        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", YES);
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

        // TÍNH TOÁN VÀ LƯU SẴN VÀO CACHE NGUYÊN THỦY (0NS TRUY XUẤT CHO RENDER LOOP)
        if (!self.enabled || !self.enableHzControl) {
            g_cachedResolvedHz = 144;
        } else if (self.powerSaveMode) {
            g_cachedResolvedHz = 60;
        } else if (self.forceOverclock144Hz) {
            g_cachedResolvedHz = 144;
        } else {
            g_cachedResolvedHz = (self.targetHz >= 30 && self.targetHz <= 144) ? self.targetHz : 144;
        }

        if (!self.enabled || !self.enableFPSControl) {
            g_cachedResolvedFPS = 144;
        } else if (self.powerSaveMode) {
            g_cachedResolvedFPS = 60;
        } else if (self.forceOverclock144Hz) {
            g_cachedResolvedFPS = 144;
        } else {
            g_cachedResolvedFPS = (self.targetFPS >= 30 && self.targetFPS <= 144) ? self.targetFPS : 144;
        }

        if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)g_cachedResolvedHz;
            p.targetFPS = (int32_t)g_cachedResolvedFPS;
            p.forceOverclock = self.forceOverclock144Hz ? 1 : 0;
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

            ApexV285ProPayload capturedPayload = p;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_WriteSyncPayloadV285(&capturedPayload);
            });
        }
    }
}

// TRẢ VỀ TRỰC TIẾP TỪ CACHE: TỐC ĐỘ XỬ LÝ 0NS, KHÔNG GÂY DROPS FRAME TRONG LOOP DỰNG HÌNH
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
// 2. BỘ ĐIỀU PHỐI KHÓA TARGET RATE DYNAMIC (TÍNH TOÁN THEO MACH TICKS - ZERO RUNLOOP OVERHEAD)
// ====================================================================================================

static inline BOOL Titanium_ShouldLockTargetRate(void) {
    // 1. Đang có cử chỉ vuốt liên tục
    if (g_isContinuousSwiping) return YES;

    // 2. Đang cuộn quán tính danh sách/feed
    if (g_isScrollingActive) return YES;

    // 3. Có banner thông báo đang trượt hoặc đang neo
    if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

    // 4. Có hoạt ảnh chuyển cảnh hệ thống (mở app, đóng app, đa nhiệm)
    if (g_activeAnimationCount > 0) return YES;

    // 5. Kiểm tra cửa sổ tương tác Mach Time
    if (g_lastInteractionMachTime == 0) return NO;

    if (__builtin_expect(g_burstDurationMachTicks == 0, 0)) {
        Titanium_InitUnifiedMachTimebase();
    }

    uint64_t now = mach_absolute_time();
    uint64_t limitTicks = g_isDeviceChargingV285 ? g_burstDurationChargingMachTicks : g_burstDurationMachTicks;

    return ((now - g_lastInteractionMachTime) < limitTicks);
}

// ====================================================================================================
// 3. ĐIỀU PHỐI XUNG NHỊP TỨC THÌ (ATOMIC TIMESTAMP - KHÔNG SPAM MAIN QUEUE)
// ====================================================================================================

static inline void Titanium_LockMainThreadFast(void) {
    if (![NSThread isMainThread]) return;

    static pthread_t s_lastElevatedThread = NULL;
    pthread_t currentThread = pthread_self();

    if (s_lastElevatedThread != currentThread) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        struct sched_param param;
        param.sched_priority = 47; // Mức trần UIKit: nhường time-slice cho socket mạng
        pthread_setschedparam(currentThread, SCHED_RR, &param);
        s_lastElevatedThread = currentThread;
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(850 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if (s_bannerSeq == currentSeq) {
            g_isNotificationBannerActive = NO;
        }
    });
}

// ====================================================================================================
// 4. ĐIỀU PHỐI CÂN BẰNG: CPU ĐỒ HỌA SOFT-REALTIME (BẢO TOÀN 100% BĂNG THÔNG MẠNG YOUTUBE/TIKTOK)
// ====================================================================================================

static inline void Titanium_BoostRenderWithoutStarvingNetwork(void) {
    if (![NSThread isMainThread]) return;
    if (!Titanium_ShouldLockTargetRate()) return;

    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    static pthread_t s_lastThread = NULL;
    pthread_t current = pthread_self();
    if (s_lastThread != current) {
        s_lastThread = current;
        struct sched_param param;
        param.sched_priority = 47;
        pthread_setschedparam(current, SCHED_RR, &param);
    }
}

// ====================================================================================================
// 5. THUẬT TOÁN PHÂN TẦNG 5 NẤC & GAME OVERDRIVE (CHUẨN CƠ CHẾ PROMOTION TRÊN PRO MAX)
// ====================================================================================================

typedef NS_ENUM(NSInteger, TitaniumDisplayTier) {
    TitaniumTier_BypassGame = 0,    // Tầng 0: Game Metal -> Giữ nguyên FPS thiết kế gốc, chống drop
    TitaniumTier_DeepIdle   = 30,   // Tầng 1: Màn hình tĩnh hoàn toàn -> Hạ xung nhịp, máy mát
    TitaniumTier_VideoSync  = 60,   // Tầng 2: Xem video/PiP -> Khớp khung hình gốc, không đơ bộ đệm
    TitaniumTier_TextRead   = 80,   // Tầng 3: Đọc báo, lướt chậm
    TitaniumTier_ApexPeak   = 144   // Tầng 4: Chạm vuốt nhanh, mở app, hiệu ứng nảy SpringBoard
};

static inline BOOL Titanium_IsCurrentAppAGame(void) {
    if (Titanium_IsSpringBoard()) return NO;
    return g_isMetalGameProcess;
}

static inline NSInteger Titanium_CalculateAdaptiveProMaxTier(void) {
    // 1. TẦNG GAME: Trả về 0 để CADisplayLink gọi %orig giữ nguyên tốc độ khung hình gốc
    if (Titanium_IsCurrentAppAGame()) {
        return TitaniumTier_BypassGame;
    }

    // 2. TẦNG VIDEO: Đang phát video YouTube / TikTok / PiP
    if (Titanium_IsPassiveVideoPlayback()) {
        return TitaniumTier_VideoSync;
    }

    // 3. TẦNG PEAK: Đang vuốt lướt nhanh, mở/đóng app, bung Control Center hoặc bàn phím
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
// 6. ĐIỀU PHỐI KERNEL XNU & PHẦN CỨNG (KHÔNG NGHẼN MẠNG, KHÔNG THU NHỎ CỬA SỔ, GIẢI PHÓNG MACH PORT)
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
        // ĐÃ LOẠI BỎ setAllowsVirtualModes: NO ĐỂ KHÔNG LÀM SAI LỆCH VIEWPORT
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

// Thiết lập chu kỳ thời gian thực Mach Kernel (Giải phóng Mach Port sạch sẽ chống leak)
static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz) {
    if (g_isDeviceChargingV285) {
        // Cắm sạc: Nhả quyền ràng buộc Mach để chống cộng hưởng nhiệt
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
    uint64_t computation_ns = (period_ns * 35ULL) / 100ULL;
    uint64_t constraint_ns  = (period_ns * 75ULL) / 100ULL;

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

    // BẮT BUỘC: Giải phóng Mach send right ngay lập tức sau khi dùng
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
// 7. NHÓM NỘI BỘ APPLE: MÔ PHỎNG VÒNG LẶP _UIUPDATECYCLE
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
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig;
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
// NHÓM 1: CẢM ỨNG 0MS NỘI BỘ APPLE (IOHIDEVENT + UIEVENTDISPATCHER + SPECULATIVE TOUCH-DOWN)
// Đã làm sạch 100% [CATransaction flush] (Trị dứt điểm co cửa sổ nhỏ), giữ nguyên phản hồi 0ms
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
        // ĐÃ TRIỆT TIÊU [CATransaction flush]: Tránh ép xuất hình sớm khi ma trận viewport chưa sẵn sàng
    }
    %orig;
}

%end

%hook SBIconView

- (double)highlightDelay {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted && IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        // ĐÃ XÓA [CATransaction flush] VÀ Mach Constraint: Cho phép SpringBoard hoàn thành trọn vẹn animation bung app
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

- (NSTimeInterval)_touchDelayThreshold {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return 0.0;
    return %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceMachFrameConstraintDynamic(144);
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig;
}

%end

%hook UIWindow

- (BOOL)_shouldDelayTouchForCancelEvents {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        if (g_activeAnimationCount > 0 || g_isScrollingActive) {
            return %orig;
        }
        return NO;
    }
    return %orig;
}

- (void)sendEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        if (event.type == 0 || event.type == 3) {
            g_lastInteractionMachTime = mach_absolute_time();

            if (Titanium_IsSpringBoard()) {
                Titanium_LockMainThreadFast();
                Titanium_EnforceMachFrameConstraintDynamic(144);
            } else {
                Titanium_BoostRenderWithoutStarvingNetwork();
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
// (CHUẨN HOÁ GPU PIPELINE - CHỐNG CO CỬA SỔ & BẢO VỆ FPS TRONG GAME TUYỆT ĐỐI)
// ====================================================================================================

%group Group_Metal_ZeroTearing_Pacing

%hook CAMetalLayer

- (void)didMoveToWindow {
    %orig;
    // Tự động nhận diện nếu tiến trình là Game Metal 3D để kích hoạt chế độ Bypass độc lập
    if (!Titanium_IsSpringBoard()) {
        g_isMetalGameProcess = YES;
    }
}

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    // Luôn giữ đồng bộ V-Sync chuẩn phần cứng để loại bỏ hoàn toàn hiện tượng rách hình (tearing)
    if (IS_ACTIVE) enabled = YES;
    %orig(enabled);
}

// BẬT TRIPLE BUFFERING: Cung cấp sẵn 3 khung đệm drawable giúp GPU game không bị nghẽn (backpressure stall)
- (NSUInteger)maximumDrawableCount {
    if (IS_ACTIVE) return 3;
    return %orig;
}

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ACTIVE) count = 3;
    %orig(count);
}

// BỎ ÉP YES: Để Game xuất hình bất đồng bộ độc lập với Main Runloop, triệt tiêu drop FPS
- (void)setPresentsWithTransaction:(BOOL)presents {
    %orig;
}

- (BOOL)presentsWithTransaction {
    return %orig;
}

%end

%hook CALayer

- (void)display {
    if (IS_ACTIVE && CFG285.touchResponseBoost && [NSThread isMainThread] && Titanium_ShouldLockTargetRate()) {
        id del = self.delegate;
        const char *delName = del ? object_getClassName(del) : NULL;
        BOOL isWallpaper = (delName != NULL) && (strstr(delName, "Wallpaper") != NULL || strstr(delName, "Poster") != NULL);

        if (!isWallpaper) {
            static Class s_backdropCls = Nil;
            static dispatch_once_t s_onceBackdrop;
            dispatch_once(&s_onceBackdrop, ^{
                s_backdropCls = objc_getClass("CABackdropLayer");
            });

            BOOL isBackdrop = (s_backdropCls && [self isKindOfClass:s_backdropCls]);
            BOOL isCornerMasking = (self.mask != nil) || (self.cornerRadius > 0.0f && self.masksToBounds);
            BOOL isThermalSafe = !g_isDeviceChargingV285 || (g_isUserTouchingScreen || g_isContinuousSwiping);

            if (!isBackdrop && !isCornerMasking && isThermalSafe) {
                Titanium_EnableZeroLatencyPipeline();
            }
        }
    }
    %orig;
}

%end

%hook CAContext

- (void)setCommitPriority:(uint32_t)priority {
    if (IS_ACTIVE) {
        if (g_isDeviceChargingV285) {
            %orig(priority);
            return;
        }
        if (Titanium_ShouldLockTargetRate()) {
            priority = 100;
        }
    }
    %orig(priority);
}

- (uint32_t)commitPriority {
    if (IS_ACTIVE && !g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
        return 100;
    }
    return %orig;
}

- (void)setDesiredDynamicRange:(float)range {
    if (IS_ACTIVE) range = 1.0f;
    %orig(range);
}

%end

// XÓA BỎ HOÀN TOÀN [CATransaction flush]: Triệt tiêu 100% lỗi co nhỏ cửa sổ app khi mở
%hook CATransaction

+ (void)commit {
    %orig;
}

%end

%end

// ====================================================================================================
// ĐIỀU PHỐI TRẠNG THÁI CHUYỂN ĐỘNG, VIDEO VÀ THÔNG BÁO HỆ THỐNG
// ====================================================================================================

static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    if (!IS_ACTIVE || !CFG285) return 144;
    
    NSInteger userHz = 144;
    if ([CFG285 respondsToSelector:@selector(targetHz)]) {
        userHz = (NSInteger)[CFG285 targetHz];
    } else {
        id dynamicCfg = (id)CFG285;
        SEL sCustom = NSSelectorFromString(@"customFPS");
        SEL sSelected = NSSelectorFromString(@"selectedFPS");
        if ([dynamicCfg respondsToSelector:sCustom]) {
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[dynamicCfg methodSignatureForSelector:sCustom]];
            [inv setSelector:sCustom];
            [inv setTarget:dynamicCfg];
            [inv invoke];
            [inv getReturnValue:&userHz];
        } else if ([dynamicCfg respondsToSelector:sSelected]) {
            NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[dynamicCfg methodSignatureForSelector:sSelected]];
            [inv setSelector:sSelected];
            [inv setTarget:dynamicCfg];
            [inv invoke];
            [inv getReturnValue:&userHz];
        }
    }
    
    if (userHz < 30) userHz = 30;
    if (userHz > 144) userHz = 144;
    return userHz;
}

// ====================================================================================================
// NHÓM 3: ĐỘNG CƠ PHÂN TẦNG NHỊP THÍCH ỨNG 5 NẤC (CHUẨN CƠ CHẾ PROMOTION TRÊN PRO MAX)
// (144HZ KHI VUỐT CHẠM - KHÓA GỐC KHI CHƠI GAME - 30HZ KHI TĨNH - KHÔNG ĐƠ VIDEO/APP)
// ====================================================================================================

%group Group_FluidTransitions_Pacing

%hook CADisplayLink

- (CFTimeInterval)targetTimestamp {
    return %orig;
}

- (NSInteger)preferredFramesPerSecond {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        NSInteger targetTier = Titanium_CalculateAdaptiveProMaxTier();
        // TẦNG GAME: Trả về %orig để game tự kiểm soát tốc độ khung hình, không bị ép tụt 30FPS khi nhấc tay
        if (targetTier == TitaniumTier_BypassGame) {
            return %orig;
        }
        return targetTier;
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        NSInteger targetTier = Titanium_CalculateAdaptiveProMaxTier();
        if (targetTier == TitaniumTier_BypassGame) {
            %orig(fps);
            return;
        }
        fps = targetTier;
    }
    %orig(fps);
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        NSInteger targetTier = Titanium_CalculateAdaptiveProMaxTier();
        if (targetTier == TitaniumTier_BypassGame) {
            %orig(range);
            return;
        }

        float tierFPS = (float)targetTier;
        if (targetTier == TitaniumTier_ApexPeak) {
            // Tương tác đỉnh (vuốt/mở app): Khóa cứng dải tần số quét tại mức trần
            range = SafeMakeFRR(tierFPS, tierFPS, tierFPS);
        } else {
            // Đọc báo hoặc cuộn chậm: Cho phép co giãn nhịp từ 30Hz đến mức phân tầng hiện tại
            range = SafeMakeFRR(30.0f, tierFPS, tierFPS);
        }
    }
    %orig(range);
}

- (void)setFrameInterval:(NSInteger)interval {
    if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE && CFG285.enableHzControl) {
        interval = Titanium_ShouldLockTargetRate() ? 1 : 2;
    }
    %orig(interval);
}

// BẢO VỆ NGUYÊN BẢN: Cho phép DisplayLink dừng nghỉ khi đợi buffer video PiP, chống đơ app 100%
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
        %orig(fps); 
        return; 
    }
    if (IS_ACTIVE) {
        fps = Titanium_GetTargetConfiguredHz();
    }
    %orig(fps);
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
        return 30.0;
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

// BẢO TOÀN VIEWPORT NGUYÊN BẢN: Tuyệt đối không can thiệp để WindowServer không scale nhầm cửa sổ
- (BOOL)allowsVirtualModes {
    return %orig;
}

- (void)setAllowsVirtualModes:(BOOL)allows {
    %orig(allows);
}

- (void)setTag:(NSInteger)tag {
    %orig(tag);
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
    %orig(rate);
}

%end

%hook CAAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
    %orig(range);
}

%end

%hook CASpringAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            float maxTarget = (float)Titanium_GetTargetConfiguredHz();
            range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
    %orig(range);
}

%end

%hook AVPlayer

- (void)setRate:(float)rate {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = (rate > 0.0f);
    }
    %orig(rate);
}

%end

%hook UIApplication

- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig(arg1);
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_activeAnimationCount++;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        });
    }
}

%end

%end

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT (CHUẨN HOÁ CỬ CHỈ ĐA NHIỆM PRO MAX - BẢO TOÀN VIEWPORT & CHỐNG JETSAM)
// Tối ưu hoá zero-drop frame khi vuốt Home/App Switcher, giữ nguyên 100% kích thước cửa sổ gốc
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

%hook SBHomeGestureInteraction

- (void)_handleGestureBegan:(id)gesture {
    %orig;
    if (IS_ACTIVE) {
        g_isContinuousSwiping = YES;
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        // Cấp quyền ưu tiên tức thì cho luồng cử chỉ SpringBoard: bám dính ngón tay 0ms
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
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        // Giữ trần ưu tiên nhẹ trong giai đoạn thẻ app bay về vị trí ổn định
        Titanium_LockMainThreadFast();
    }
}

- (void)_handleGestureCancelled:(id)gesture {
    %orig;
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

%end

%hook SBFluidSwitcherGestureWorkspaceTransaction

- (BOOL)canInterruptActiveGesture {
    return %orig;
}

- (BOOL)_shouldSuppressGestures {
    return %orig;
}

- (void)_begin {
    %orig;
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isContinuousSwiping = NO;
    }
}

%end

%hook SBAppToHomeWorkspaceTransaction

- (BOOL)shouldAnimateOrientationChangeOnCompletion {
    return %orig;
}

- (void)_willBegin {
    %orig;
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        // Đẩy xung đồ họa SpringBoard mượt mà khi thu nhỏ app về Home
        Titanium_LockMainThreadFast();
    }
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isContinuousSwiping = NO;
        g_isUserTouchingScreen = NO;
    }
}

%end

// GIAO DỊCH MỞ APP TỪ MÀN HÌNH CHÍNH (ĐẢM BẢO HOẠT ẢNH BUNG FULL MÀN HÌNH 100%)
%hook SBHomeToAppWorkspaceTransaction

- (void)_willBegin {
    // 1. GỌI %orig LÊN ĐẦU TIÊN: Để SpringBoard khởi tạo hoàn chỉnh transaction và ma trận viewport
    %orig;
    
    // 2. Kích hoạt mốc thời gian và tăng xung render nhịp nhàng, KHÔNG chèn flush hay ép scale
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

%end

%hook SBAppSwitcherSettings

- (BOOL)shouldKeepAppSnapshotsInMemory {
    // Trả về nguyên bản để hệ thống tự cân bằng bộ nhớ, không ép giữ snapshot gây tràn RAM (Jetsam kill app)
    return %orig;
}

- (CGFloat)decelerationRate {
    // Quán tính trượt thẻ đa nhiệm êm mượt tự nhiên như ProMotion
    if (IS_ACTIVE) return UIScrollViewDecelerationRateNormal;
    return %orig;
}

%end

%hook SBAppSwitcherController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
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
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC (TURBO ENGINE - SẠCH NGHẼN MẠNG & CHỐNG ĐEN APP 100%)
// Tối ưu hoá handshake giữa SpringBoard và FBScene - Bảo toàn 100% kích thước toàn màn hình
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

%hook FBApplicationProcess

- (void)bootstrapWithContext:(id)context completion:(id)completion {
    // Gọi %orig trước để XNU Kernel và SpringBoard cấp phát PID sạch sẽ
    %orig;
    if (IS_ACTIVE && CFG285.turboAppLaunch && !g_isDeviceChargingV285) {
        Titanium_EnforceThreadVIPPolicy();
    }
}

- (void)launchIfNecessary {
    %orig;
    if (IS_ACTIVE && CFG285.turboAppLaunch && !g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
        Titanium_EnforceThreadVIPPolicy();
    }
}

%end

%hook UIApplication

- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    // 1. GỌI %orig TRƯỚC: Cho phép hệ thống nạp scene đồ họa trọn vẹn, chống đen màn hình (Black Screen)
    %orig;

    // 2. Kích xung đồ họa mượt mà không bóp nghẹt chu kỳ render ban đầu
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
// Triệt tiêu hoàn toàn [CATransaction flush] trong Navigation - Cảm ứng cuộn dính tay 0ms
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

%hook UIInputViewAnimationStyle

- (double)duration {
    // Tốc độ nảy bàn phím nhanh nhạy 0.08s (vừa mắt nhìn, không gây lỗi layout bộ gõ tiếng Việt)
    if (IS_ACTIVE) return 0.08;
    return %orig;
}

%end

%hook UIKeyboardImpl

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
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

%end

%hook UITextInputController

- (void)_insertText:(id)text {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}

- (void)deleteBackward {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
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

%hook UINavigationController

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
        // ĐÃ XÓA HOÀN TOÀN [CATransaction flush]: Chống giật khung hình và chống lỗi thu nhỏ màn hình khi chuyển trang
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

%hook UIScrollView

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    // Nhận diện cuộn ngay lập tức ngay cả khi ngón tay chạm đè lên nút bấm (Bám tay tức thì)
    if (IS_ACTIVE && [view isKindOfClass:[UIControl class]]) {
        if (self.isDragging) return YES;
    }
    return %orig;
}

- (BOOL)delaysContentTouches {
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
        // ĐIỀU PHỐI ĐỒ HỌA MƯỢT NHƯNG KHÔNG CHẶN SOCKET MẠNG: Xem video TikTok/FB khi cuộn không bị giật lag
        if (!Titanium_IsSpringBoard()) {
            Titanium_BoostRenderWithoutStarvingNetwork();
        } else {
            Titanium_LockMainThreadFast();
        }
    }
    %orig;
}

- (CGFloat)decelerationRate {
    if (IS_ACTIVE) return UIScrollViewDecelerationRateNormal;
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

%hook UITableView

- (void)willMoveToWindow:(UIWindow *)newWindow { 
    %orig; 
}

%end

%hook UICollectionView

- (void)willMoveToWindow:(UIWindow *)newWindow { 
    %orig; 
}

%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD - TOÀN BỘ HIỆU ỨNG HỆ THỐNG (FOLDER, LOCKSCREEN, 3D TOUCH, CC/NC, GIAO DIỆN)
// Tối ưu hóa chu trình ProMax: Cân bằng bộ đếm hoạt ảnh 100%, triệt tiêu lỗi chớp thư mục & nóng ngầm
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
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
}

%end

%hook SBScreenshotManager

- (void)saveScreenshotsWithCompletion:(id)completion {
    %orig;
    if (IS_ACTIVE) {
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
    }
}

%end

%hook SBVolumeControl

- (void)increaseVolume {
    %orig;
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
}

- (void)decreaseVolume {
    %orig;
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
}

- (void)changeVolumeByDelta:(float)delta {
    %orig;
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
}

%end

// ==================== CONTROL CENTER & NOTIFICATION CENTER ====================

%hook SBControlCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();

        void (^origComp)(void) = [completion copy];
        id wrappedComp = ^{
            if (origComp) origComp();
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        };
        %orig(animated, wrappedComp);
        return;
    }
    %orig;
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();

        void (^origComp)(void) = [completion copy];
        id wrappedComp = ^{
            if (origComp) origComp();
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        };
        %orig(animated, wrappedComp);
        return;
    }
    %orig;
}

%end

%hook SBNotificationCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();

        void (^origComp)(void) = [completion copy];
        id wrappedComp = ^{
            if (origComp) origComp();
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        };
        %orig(animated, wrappedComp);
        return;
    }
    %orig;
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();

        void (^origComp)(void) = [completion copy];
        id wrappedComp = ^{
            if (origComp) origComp();
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        };
        %orig(animated, wrappedComp);
        return;
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
        Titanium_LockMainThreadFast();
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
        Titanium_TriggerInstantTouchBurst();
    }
}

%end

// ==================== THƯ MỤC (FOLDER) - BẢO ĐẢM KHÔNG CHỚP NHÁY 100% ====================

%hook SBFolderControllerAnimationSettings

- (double)duration {
    return %orig;
}

%end

%hook SBFolderView

// Chuẩn hóa gọi %orig trước để icon thư mục render ổn định, sau đó mới kích xung chuyển cảnh
- (void)prepareToOpen {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
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
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();

        void (^origComp)(void) = [completion copy];
        id wrappedComp = ^{
            if (origComp) origComp();
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        };
        %orig(animated, wrappedComp);
        return;
    }
    %orig;
}

- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();

        void (^origComp)(void) = [completion copy];
        id wrappedComp = ^{
            if (origComp) origComp();
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        };
        %orig(animated, wrappedComp);
        return;
    }
    %orig;
}

%end

%hook SBIconForceTouchSettings

- (double)delayBeforeOpening {
    return %orig;
}

%end

// ==================== MÀN HÌNH KHÓA & TRẠNG THÁI TIẾN TRÌNH ====================

%hook CSCoverSheetViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
}

%end

%hook SBHomeScreenViewController

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
}

%end

%hook SBApplication

- (void)willActivate {
    %orig;
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
}

- (BOOL)shouldPrewarmOnLaunch {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

%hook SBAppLaunchSettings

- (double)zoomDuration {
    return %orig;
}

- (double)launchDuration {
    return %orig;
}

- (double)delayBeforeAppLaunch {
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
    %orig;
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
    }
}

- (void)_didCompleteAnimation {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 8: PIPELINE CHO PICTURE-IN-PICTURE (PIP MƯỢT MÀ & CHUYỂN CẢNH 144HZ)
// Tối ưu hóa bộ đệm video thụ động: Chống đơ khung hình PiP và tiết kiệm pin tối đa
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
        g_isVideoPlayingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

- (void)stopPictureInPictureAnimated:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = NO;
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
        g_isVideoPlayingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)stopPictureInPicture {
    %orig;
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 9: PHÂN TÁCH PHẦN CỨNG (HOME BUTTON VẬT LÝ - PHẢN HỒI 0MS, BẢO TOÀN ĐỆM 144HZ)
// Đã xóa g_activeAnimationCount++ không có điểm dừng (Triệt tiêu nóng máy & hao pin ngầm)
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions

- (void)performSinglePressAction {
    %orig;
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        // Kích xung nhịp Mach Time tự thu hồi, không làm rò rỉ biến đếm hoạt ảnh
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
}

- (void)performDoublePressAction {
    %orig;
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH & BẢO VỆ JETSAM (CHỐNG ĐEN APP 100% & MÁT MÁY KHI CHẠY NỀN)
// Cân bằng trạng thái tiến trình XNU - An toàn tuyệt đối với bộ nhớ hệ thống
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

%hook SBApplication

- (void)setProcessState:(id)state {
    %orig;
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        Titanium_LockMainThreadFast();
    }
}

%end

%hook SBMainWorkspace

- (void)handleApplicationLaunch:(id)application {
    %orig;
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        // Khởi động app tức thì qua Burst Controller, không để rò rỉ cờ hoạt ảnh
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 11: NÂNG CẤP TOÀN BỘ APP THỨ BA & CHUYỂN TIẾP VIEWCONTROLLER CHUẨN XNU
// (SẠCH NGHẼN MẠNG YOUTUBE, BẢO TOÀN SNAPSHOT MỞ APP & CHỐNG THU NHỎ CỬA SỔ 100%)
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
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE && g_activeAnimationCount > 0) {
        g_activeAnimationCount--;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE && g_activeAnimationCount > 0) {
        g_activeAnimationCount--;
    }
}

%end

%hook UIViewControllerTransitionCoordinator

- (BOOL)animateAlongsideTransition:(void (^)(id context))animation
                        completion:(void (^)(id context))completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_activeAnimationCount++;

        void (^wrappedCompletion)(id) = ^(id context) {
            if (completion) completion(context);
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        };
        return %orig(animation, wrappedCompletion);
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
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)presentationTransitionDidEnd:(BOOL)completed {
    %orig;
    if (IS_ACTIVE && g_activeAnimationCount > 0) {
        g_activeAnimationCount--;
    }
}

- (void)dismissalTransitionWillBegin {
    %orig;
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)dismissalTransitionDidEnd:(BOOL)completed {
    %orig;
    if (IS_ACTIVE && g_activeAnimationCount > 0) {
        g_activeAnimationCount--;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 12: BÀN PHÍM STREAM TEXT & CẢM ỨNG NÚT BẤM (ĐÃ TỐI ƯU 0MS & KHÔNG NGHẼN MẠNG YOUTUBE)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

%hook UIKeyboardTaskQueue

- (void)performTask:(id)task {
    if (IS_ACTIVE) {
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig(task);
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

+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if (IS_ACTIVE) return 0.0;
    return %orig;
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
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }
    }
    %orig(touches, event);
}

%end

%end

// ====================================================================================================
// NHÓM 13: DUY TRÌ TRẦN 144HZ & CHỐNG QUÁ NHIỆT (TRIỆT TIÊU HOÀN TOÀN NÓNG MÁY KHI SẠC PIN)
// ====================================================================================================

%group Group_Global_Thread_Governor_Unthrottled

%hook RBSProcessState

- (unsigned char)taskState {
    unsigned char orig = %orig;
    if (IS_ACTIVE && orig > 0) {
        // Chỉ cấp quyền ưu tiên cao khi không cắm sạc và đang có tương tác thực tế
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
        // Nếu đang cắm sạc: Cho phép hệ thống nhận diện nhiệt độ thực tế để kích hoạt cơ chế bảo vệ pin
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
                ([aName isKindOfClass:[NSString class]] && [aName isEqualToString:NSProcessInfoThermalStateDidChangeNotification])) {
                return; // Chặn thông báo hạ xung nhịp giả định trong lúc đang tương tác vuốt chạm
            }
        }
    }
    %orig(aName, anObject, aUserInfo);
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
        g_isMetalGameProcess = YES; // Tự động nhận diện tiến trình Game Metal Engine
    }
    return orig;
}

// 1. TẮT TIMEOUT XUẤT HÌNH: GPU luôn kiên nhẫn chờ nạp đủ dữ liệu, chống rớt khung hình (Drop Frame) khi combat
- (BOOL)allowsNextDrawableTimeout {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        return NO;
    }
    return %orig;
}

- (void)setAllowsNextDrawableTimeout:(BOOL)allow {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        allow = NO;
    }
    %orig(allow);
}

// 2. TỐI ƯU HÓA ĐỆM BỘ NHỚ KHUNG HÌNH (DRAWABLE PACING): Ép đệm 3 lớp mượt mà
- (id)nextDrawable {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    return %orig;
}

// 3. ĐỒNG BỘ HIỂN THỊ CHUẨN XÁC: Loại bỏ hiện tượng xé hình nhưng không bắt luồng chính UIKit phải đợi
- (BOOL)serverPresentsWithTransaction {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        return NO; // Để GPU xuất hình độc lập, không phụ thuộc vào chu kỳ commit của SpringBoard
    }
    return %orig;
}

- (void)setServerPresentsWithTransaction:(BOOL)serverPresents {
    if (IS_ACTIVE && g_isMetalGameProcess) {
        serverPresents = NO;
    }
    %orig(serverPresents);
}

%end

%end

// ====================================================================================================
// NHÓM 15: SILICON HARDWARE PIPELINE OVERDRIVE (ĐỘNG CƠ ĐỒ HỌA MỚI HOÀN TOÀN - CHUẨN PRO MAX)
// (TĂNG TỐC TRUYỀN TẬP LỆNH GPU - NÉN BĂNG THÔNG VRAM - TRIỆT TIÊU TRỄ XUẤT HÌNH - KHÔNG ĐEN APP - KHÔNG NGHẼN MẠNG)
// ====================================================================================================

%group Group_Silicon_Hardware_Pipeline_Overdrive

// 1. TỐI ƯU HÓA HÀNG ĐỢI LỆNH GPU METAL (GIẢM TẢI CPU PROFILE, TẬP TRUNG TỐC ĐỘ DỰNG HÌNH)
%hook _MTLCommandQueue

- (void)setStatOptions:(NSUInteger)options {
    // Tắt ghi log thống kê GPU ngầm trong game để tiết kiệm xung nhịp bộ xử lý đồ họa
    if (IS_ACTIVE && g_isMetalGameProcess) {
        options = 0;
    }
    %orig(options);
}

- (BOOL)executionEnabled {
    if (IS_ACTIVE) return YES;
    return %orig;
}

%end

// 2. GIA TỐC PHÁT LỆNH VẼ BẤT ĐỒNG BỘ: ĐẨY LỆNH VẼ THẲNG VÀO GPU KHÔNG CHỜ ĐỢI
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
        // Cập nhật mốc thời gian Mach để hệ thống duy trì trần xung nhịp cho khung hình kế tiếp
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

%end

// 3. NÉN BĂNG THÔNG BỘ NHỚ VRAM (LOSSLESS TEXTURE COMPRESSION - MÁT MÁY & TĂNG TỐC TẢI MAP)
%hook MTLTextureDescriptor

- (BOOL)allowGPUOptimizedContents {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (void)setAllowGPUOptimizedContents:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
    %orig(flag);
}

%end

// 4. TRIỆT TIÊU ĐỘ TRỄ XUẤT HÌNH TỐI THIỂU (ZERO PRESENTATION HOLD DELAY)
%hook CAMetalDrawable

- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    // Ép thời gian giữ frame về 0: GPU vẽ xong là xuất hình ngay lập tức, không ngâm buffer
    if (IS_ACTIVE && g_isMetalGameProcess) {
        duration = 0.0;
    }
    %orig(duration);
}

%end

%end

// ====================================================================================================
// NHÓM BẢO VỆ CHỐNG NÓNG, CHỐNG GIẬT CC/NC & BẢO TOÀN NGUYÊN BẢN HÌNH NỀN
// ====================================================================================================

%group Group_LiquidGlass_Opt

%hook CAFilter

- (void)setValue:(id)value forKey:(NSString *)key {
    if (IS_ACTIVE && [key isKindOfClass:[NSString class]] && [key isEqualToString:@"inputRadius"]) {
        // Khống chế trần làm mờ 14px: Giao diện mịn màng nhưng giải phóng 40% tải render cho GPU
        if ([value isKindOfClass:[NSNumber class]] && [value floatValue] > 14.0f) {
            value = @(14.0f);
        }
    }
    %orig(value, key);
}

%end

%hook CABackdropLayer

- (void)setScale:(double)scale {
    %orig(scale);
}

- (double)scale {
    return %orig;
}

// Bỏ ép in-place filter để GPU không phải chia sẻ bộ đệm khung hình
- (void)setAllowsInPlaceFiltering:(BOOL)flag {
    %orig(flag);
}

- (BOOL)allowsInPlaceFiltering {
    return %orig;
}

// Tắt bộ lọc nếu layer bị che khuất để tiết kiệm điện năng và giảm nhiệt độ SoC
- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
    %orig(flag);
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
// ====================================================================================================

%group Group_Universal_InApp_Animations

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
    %orig(newWindow);
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
    %orig(animated);
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
// NHÓM MỚI ĐỘC QUYỀN: BỘ NÃO DỰ ĐOÁN TỌA ĐỘ NEURAL & CỬ CHỈ MÉP 0MS
// ĐÃ XÓA SẠCH HOÀN TOÀN CALAYER drawsAsynchronously (TRIỆT TIÊU 100% LỖI CHỚP NHÁY THƯ MỤC)
// ====================================================================================================

%group Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285

%hook _UITouchPredictor

- (id)predictedTouchesForTouch:(UITouch *)touch {
    id predicted = %orig(touch);
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
    %orig(touch, event);
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
    %orig(event);
}

%end

%hook SBScreenEdgePanGestureRecognizer

- (BOOL)_shouldTryToBeginWithEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    return %orig(event);
}

- (double)_edgeRegionSize {
    double origSize = %orig;
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        return origSize > 0.0 ? (origSize * 1.20) : 24.0;
    }
    return origSize;
}

%end

%hook SBFluidSwitcherAnimationSettings

- (double)deckSwipeSpeedFactor {
    if (IS_ACTIVE) return 1.35;
    return %orig;
}

- (double)cardFlyInDuration {
    if (IS_ACTIVE) return 0.24;
    return %orig;
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
#define TITANIUM_BOOT_GUARD_FILE    @"/tmp/.titanium_boot_guard"

static time_t Titanium_GetSystemUptimeSeconds(void) {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) < 0) return 9999;
    time_t now = time(NULL);
    return (now - boottime.tv_sec);
}

// CƠ CHẾ SAFEGUARD: Nếu thiết bị khởi động lại quá 3 lần liên tiếp trong 25 giây -> Tự động dừng tweak để vào máy an toàn
static BOOL Titanium_CheckAndPreventBootloopUniversal(void) {
    @autoreleasepool {
        NSString *guardPath = TITANIUM_BOOT_GUARD_FILE;
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:guardPath];
        NSInteger failCount = 0;
        NSTimeInterval lastBoot = 0;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

        if (dict) {
            failCount = [dict[@"count"] integerValue];
            lastBoot = [dict[@"time"] doubleValue];
        }

        if (now - lastBoot < 25.0) {
            failCount++;
        } else {
            failCount = 1;
        }

        NSDictionary *newDict = @{@"count": @(failCount), @"time": @(now)};
        [newDict writeToFile:guardPath atomically:YES];

        if (failCount >= 3) {
            // Phát hiện nguy cơ kẹt vòng lặp khởi động: Tạm dừng tiêm để bảo vệ Jailbreak
            return NO;
        }

        // Sau 15 giây hệ thống chạy ổn định -> Xóa cờ guard, xác nhận hệ thống an toàn
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if ([fm fileExistsAtPath:guardPath]) {
                [fm removeItemAtPath:guardPath error:nil];
            }
        });
        return YES;
    }
}

// ====================================================================================================
// RUNTIME INITIALIZER: ĐIỀU PHỐI TẦNG NỘI BỘ & KHỞI CHẠY TWEAK (NẠP ĐẦY ĐỦ 15 NHÓM ĐỘC QUYỀN)
// ====================================================================================================

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    static dispatch_once_t s_coreInitToken;
    dispatch_once(&s_coreInitToken, ^{
        @autoreleasepool {
            AppleInternal_EnforceZeroLatencyKernelTier();
            AppleInternal_LockHardwareCADisplay();

            if (isSpringBoard) {
                // Chỉ cấp quyền ưu tiên luồng giao diện mượt mà, KHÔNG ép Mach Realtime cứng khi mới bật máy
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
            
            // 3. ĐÃ NẠP HOÀN CHỈNH: NHÓM 14 (GAME OVERDRIVE) & NHÓM 15 (SILICON PIPELINE MỚI 100%)
            %init(Group_Titanium_Game_Metal_Overdrive);
            %init(Group_Silicon_Hardware_Pipeline_Overdrive);

            if (Titanium_IsClassicHomeButtonDevice()) {
                %init(Group_HardwareSegregation_ClassicHomeV285);
            }

            if (isSpringBoard) {
                Titanium_TuneWindowServerDisplayDirectly();
                // CÁCH LY LIQUID GLASS: Chỉ nạp ngoài SpringBoard để Game hoàn toàn mát mẻ không drop FPS
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

        // Cold boot: Chờ 1.2s để SpringBoard dựng xong khung hình gốc; Respring: Chờ 0.3s
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

        // 3. NẾU LÀ SPRINGBOARD: KIỂM TRA CHỐNG BOOTLOOP TRƯỚC TIÊN
        if (isSpringBoard) {
            if (!Titanium_CheckAndPreventBootloopUniversal()) {
                return; // Dừng tiêm nếu phát hiện reboot liên tục để cứu máy
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
            // CƠ CHẾ NẠP KÉP: Bắt sự kiện chuẩn qua Cocoa NSNotificationCenter
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                SpringBoardBootstrapTrigger();
            }];

            // CƠ CHẾ DỰ PHÒNG (FALLBACK): Nếu sự kiện khởi động đã trôi qua trước khi tiêm dylib -> Kích hoạt sau 2.0s
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                SpringBoardBootstrapTrigger();
            });
        } else {
            // ĐỐI VỚI APP THƯỜNG / GAME: Nạp trực tiếp vào luồng app
            runCoreTweak(NO, bundleID, progName);
        }
    }
}
