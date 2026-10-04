// ==================== MACH & XNU KERNEL ====================
#import <mach/mach.h>
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

// ==================== SYS HEADERS ====================
#import <sys/sysctl.h>
#import <sys/resource.h>
#import <sys/utsname.h>
#import <sys/wait.h>
#import <sys/mman.h>
#import <sys/stat.h>
#import <sys/types.h>

// ==================== OBJC & SECURITY ====================
#import <objc/runtime.h>
#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>
#import <substrate.h>

// ==================== APPLE FRAMEWORKS ====================
#import <CoreFoundation/CoreFoundation.h>
#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAMetalLayer.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>
#import <IOKit/IOKitLib.h>

static void Titanium_StealthKernelHijack(void);
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
// SYSTEM PRIVATE INTERFACES
// ====================================================================================================

@interface UIEvent (TitaniumApexPrivate)
- (int)type;
@end

@interface UITouch (TitaniumApexPrivate)
- (float)_pathMajorRadius;
@end

@interface UIControl (TitaniumApexPrivate)
- (NSTimeInterval)_touchDelayThreshold;
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
@end

@interface UIViewController (TitaniumApexPrivate)
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewWillDisappear:(BOOL)animated;
- (void)viewDidDisappear:(BOOL)animated;
- (void)viewDidLoad;
- (void)didReceiveMemoryWarning;
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
@end

@interface UITableView (TitaniumApexPrivate)
@end

@interface UICollectionView (TitaniumApexPrivate)
@end

@interface UITextView (TitaniumApexPrivate)
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
@end

@interface UITextInputController : NSObject
- (void)_insertText:(id)text;
- (void)deleteBackward;
- (void)replaceRange:(id)range withText:(id)text;
- (void)setMarkedText:(id)markedText selectedRange:(NSRange)selectedRange;
- (void)unmarkText;
@end

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
@end

@interface CAMetalLayer (TitaniumApexPrivate)
- (void)setLowLatencyMode:(BOOL)flag;
- (void)setMaximumDrawableCount:(NSUInteger)count;
- (NSUInteger)maximumDrawableCount;
- (void)setDisplaySyncEnabled:(BOOL)enabled;
- (void)setAllowsNextDrawableTimeout:(BOOL)allow;
- (void)setPresentsWithTransaction:(BOOL)flag;
- (void)setServerPresentsWithTransaction:(BOOL)flag;
- (void)setFramebufferOnly:(BOOL)fb;
- (BOOL)framebufferOnly;
- (id)nextDrawable;
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
- (void)setAllowsDisplayCompositing:(BOOL)flag;
@end

@interface CAWindowServer : NSObject
+ (instancetype)server;
- (NSArray *)displays;
@end

// ĐÃ GỘP CHUẨN: SBApplication chỉ khai báo 1 lần duy nhất chứa đủ method willActivate
@interface SBApplication : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)displayName;
- (id)processState;
- (BOOL)isRunning;
- (BOOL)isClassic;
- (void)didExitWithContext:(id)context;
- (void)willActivate;
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
@end

@interface RBSProcessIdentity : NSObject
- (id)embeddedApplicationIdentifier;
@end

@interface RBSProcessHandle : NSObject
+ (instancetype)currentProcess;
- (RBSProcessIdentity *)identity;
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
- (void)presentAnimated:(BOOL)animated;
- (void)dismissAnimated:(BOOL)animated;
@end

@interface SBNotificationCenterController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isVisible;
- (void)presentAnimated:(BOOL)animated;
- (void)dismissAnimated:(BOOL)animated;
@end

@interface SBWallpaperController : NSObject
+ (instancetype)sharedInstance;
- (void)beginRequiringWithReason:(id)reason;
- (void)endRequiringWithReason:(id)reason;
- (void)suspendWallpaperAnimationForReason:(id)reason;
- (void)resumeWallpaperAnimationForReason:(id)reason;
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
@end

@interface SBIconListView : UIView
- (void)layoutIconsNow;
- (void)layoutSubviews;
- (void)setAlphaForAllIcons:(double)alpha;
- (void)fadeInIcon:(id)icon;
@end

@interface SBIconView : UIView
- (void)setIconImageInfo:(id)info;
- (void)setHighlighted:(BOOL)highlighted;
- (void)setTouchDownInIcon:(BOOL)touchDown;
- (void)setAllowsCloseBox:(BOOL)allows;
- (void)prepareForReuse;
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
- (BOOL)shouldAsyncRenderAppLayouts;
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
@end

@interface SBUIAnimationController : NSObject
@end

@interface UIInputViewAnimationStyle : NSObject
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) BOOL animated;
@end

@interface SBAppToHomeWorkspaceTransaction : NSObject
@end

@interface UIViewPropertyAnimator ()
+ (void)_setTrackDuration:(double)duration;
@end

@interface _UIContextMenuContainerView : UIView
@end

@interface SBDockView : UIView
- (void)setBackgroundAlpha:(CGFloat)alpha;
@end

@interface SBAppToHomeAnimationSettings : NSObject
@property (nonatomic, assign) double mass;
@property (nonatomic, assign) double stiffness;
@property (nonatomic, assign) double damping;
@end

@interface SBFluidSwitcherAnimationSettings : NSObject
@property (nonatomic, assign) double mass;
@property (nonatomic, assign) double stiffness;
@property (nonatomic, assign) double damping;
@end

// ====================================================================================================
// PRIVATE APPLE INTERNAL INTERFACES (NHÓM 14)
// ====================================================================================================

@interface BKSHIDEventDeliveryManager : NSObject
+ (instancetype)sharedInstance;
- (void)selectDispatches:(id)arg1;
@end

@interface CARenderServer : NSObject
+ (void)beginFrame;
+ (void)endFrame;
@end

@interface SBPrototypeController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)isPrototypingEnabled;
@end

// ====================================================================================================
// CORE IPC STRUCT & RUNTIME PAYLOAD ENGINE
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
    APEX_SYNC_MAGIC_V285, 1, 60, 60, 0, 1, 1, 1, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, {0}
};

static pthread_mutex_t g_syncLockV285 = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTicksV285 = 0;
static BOOL g_isDeviceChargingV285 = NO;
static volatile BOOL g_isUserTouchingV285 = NO;
static volatile CFTimeInterval g_lastTouchMediaTimeV285 = 0.0;
static volatile NSProcessInfoThermalState g_liveThermalStateV285 = NSProcessInfoThermalStateNominal;

static BOOL g_SystemMasterReady = NO;

// KHAI BÁO BIẾN TOÀN CỤC LÊN ĐẦU ĐỂ KHÔNG BỊ LỖI UNDECLARED IDENTIFIER
static volatile BOOL g_isInstantMotion = NO;
static volatile BOOL g_isScrollingActive = NO;
static volatile BOOL g_isContinuousSwiping = NO;
static volatile BOOL g_isAppToHomeAnimating = NO;
static volatile BOOL g_isAppOpeningAnimating = NO;
static volatile BOOL g_isSwitcherActive = NO; // Cờ giữ cứng 120Hz/60Hz khi đang ở màn hình đa nhiệm


// ====================================================================================================
// HARDWARE DETECTION & RUNTIME PATH RESOLUTION
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
        uname(&sysInfo);
        NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        if ([dev hasPrefix:@"iPhone14,2"] || [dev hasPrefix:@"iPhone14,3"] ||
            [dev hasPrefix:@"iPhone15,2"] || [dev hasPrefix:@"iPhone15,3"] ||
            [dev hasPrefix:@"iPhone16,"] || [dev hasPrefix:@"iPhone17,"]) {
            isNative120 = YES;
        }
    });
    return isNative120;
}

static inline BOOL Titanium_IsClassicHomeButtonDevice(void) {
    static BOOL sIsClassic = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        uname(&sysInfo);
        NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        if ([dev containsString:@"iPhone8,"] || 
            [dev containsString:@"iPhone9,"] || 
            [dev containsString:@"iPhone10,1"] || [dev containsString:@"iPhone10,2"] || 
            [dev containsString:@"iPhone10,4"] || [dev containsString:@"iPhone10,5"] || 
            [dev containsString:@"iPhone12,8"] || [dev containsString:@"iPhone14,6"]) {
            sIsClassic = YES;
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
// ADVANCED HARDWARE SUBSYSTEM ENGINE & MACH POLICY (NO OVERCLOCK, ZERO LATENCY)
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

// ĐÃ SỬA: Bỏ ép QOS_CLASS_USER_INTERACTIVE liên tục trên luồng chính để hạ nhiệt CPU/GPU
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

static inline void Titanium_BackgroundPurgeMemory(void) {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        malloc_zone_pressure_relief(malloc_default_zone(), 0);
    });
}

static inline void Titanium_PurgeProcessMemoryAggressively(void) {
    Titanium_BackgroundPurgeMemory();
}

static void Titanium_ApplySiliconDeepOptimizations(void) {
    setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
    setenv("MTL_DISABLE_TEXTURE_RESIDENCY_TRACKING", "1", 1);
    setenv("MTL_SHADER_VALIDATION", "0", 1);
    setenv("MTL_FORCE_PARALLEL_ENCODE", "1", 1);
    setenv("CA_DEBUG_TRANSACTIONS", "0", 1);
    setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);

    Titanium_DisableKernelThreadThrottling();
}

static void Titanium_WriteSyncPayloadV285(const ApexV285ProPayload *payload) {
    if (!payload) return;
    ApexV285ProPayload temp = *payload;
    temp.magic = APEX_SYNC_MAGIC_V285;
    temp.updateSeq = (uint64_t)mach_absolute_time();
    int fd = open([SHARED_SYNC_FILE UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        write(fd, &temp, sizeof(ApexV285ProPayload));
        close(fd);
        chmod([SHARED_SYNC_FILE UTF8String], 0666);
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

static BOOL Titanium_CheckAndPreventBootloopUniversal(void) {
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
    if (currentUnixTime - previousRestartTime < 15.0) {
        restartCount++;
    } else {
        restartCount = 1;
    }
    NSDictionary *updatedCounterDict = @{@"count": @(restartCount), @"time": @(currentUnixTime)};
    [updatedCounterDict writeToFile:bootCounterFilePath atomically:YES];
    if (restartCount >= 4) {
        return NO;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([fileManager fileExistsAtPath:bootCounterFilePath]) {
            [fileManager removeItemAtPath:bootCounterFilePath error:nil];
        }
    });
    return YES;
}

// ====================================================================================================
// BOOST CONFIGURATION ENGINE (V28.7 PRO)
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

// SỬA CHUẨN ĐỒNG BỘ: Đặt sau khi class BoostConfigV285Pro đã được khai báo
static void Titanium_TuneWindowServerDisplayDirectly(void) {
    Class wsClass = NSClassFromString(@"CAWindowServer");
    if (!wsClass) return;
    
    CAWindowServer *server = [wsClass server];
    if (!server) return;

    NSArray *displays = [server displays];
    // Kiểm tra displays tồn tại và có ít nhất 1 màn hình trước khi can thiệp
    if (!displays || displays.count == 0) return;

    CAWindowServerDisplay *mainDisp = displays[0];
    if (!mainDisp) return;
    
    NSInteger currentHz = CFG285 ? [CFG285 resolvedTargetHz] : 60;
    if (currentHz <= 0) currentHz = 60;
    double minDuration = 1.0 / (double)currentHz;

    if ([mainDisp respondsToSelector:@selector(setMinimumFrameDuration:)]) {
        [mainDisp setMinimumFrameDuration:minDuration];
    }
     if ([mainDisp respondsToSelector:@selector(setAllowsVirtualModes:)]) {
        [mainDisp setAllowsVirtualModes:NO]; // Khóa cứng chạy chế độ Native toàn màn hình
    }
    if ([mainDisp respondsToSelector:@selector(setAllowsDisplayCompositing:)]) {
        [mainDisp setAllowsDisplayCompositing:YES];
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
        self.targetHz = 60;
        self.targetFPS = 60;
        self.enableHzControl = YES;
        self.enableFPSControl = YES;
        self.proMotionEngineBeta7 = YES;
        self.touchResponseBoost = YES;
        self.colorOs17SmoothEngine = YES;
        self.keyboardZeroLagV24 = YES;
        self.metalHexBuffering = YES;
        self.fixAppExitStutter = YES;
        self.fixAppLaunchBlackScreen = YES;
        self.turboAppLaunch = YES;
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
                NSString *str = (__bridge NSString *)val;
                return str;
            }
            return d;
        };

        self.enabled = GetLiveBool(@"Enabled", YES);
        self.selectedLanguage = GetLiveString(@"SelectedLanguage", @"auto");
        self.enableHzControl = GetLiveBool(@"EnableHzControl", YES);
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 60);
        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 60);
        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", NO);
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

        if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)[self resolvedTargetHz];
            p.targetFPS = (int32_t)[self resolvedTargetFPS];
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

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_WriteSyncPayloadV285(&p);
            });
        }
    }
}

- (NSInteger)resolvedTargetHz {
    if (!self.enabled || !self.enableHzControl) return 60;
    if (self.powerSaveMode) return 30;
    
    NSInteger target = (NSInteger)ClampSafeFPS((float)self.targetHz);
    // Khóa trần phần cứng 60Hz cho iPhone 6s - 12 Pro Max
    if (!HardwareHasNative120Hz() && !self.forceOverclock144Hz) {
        if (target > 60) target = 60;
    }
    return target;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled || !self.enableFPSControl) return 60;
    if (self.powerSaveMode) return 30;
    
    NSInteger target = (NSInteger)ClampSafeFPS((float)self.targetFPS);
    // Khóa trần phần cứng 60FPS cho màn hình 60Hz vật lý
    if (!HardwareHasNative120Hz() && !self.forceOverclock144Hz) {
        if (target > 60) target = 60;
    }
    return target;
}

- (NSInteger)resolvedFrameInterval {
    NSInteger fps = [self resolvedTargetFPS];
    NSInteger baseHz = HardwareHasNative120Hz() ? 120 : 60;
    if (fps <= 0) return 1;
    NSInteger interval = baseHz / fps;
    return (interval >= 1) ? interval : 1;
}

@end

// CALLBACK ĐỒNG BỘ TOÀN HỆ THỐNG
static void PrefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (CFG285) {
        [CFG285 loadSettings];
        Titanium_TuneWindowServerDisplayDirectly();
    }
}

// ====================================================================================================
// NHÓM 1: ZERO-LATENCY TOUCH PIPELINE & RAW EVENT DISPATCH (0.0s RESPONSE)
// ===================================================================================================
static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
    #if defined(TASK_LATENCY_QOS_POLICY)
    task_latency_qos_policy_data_t latencyPolicy;
    latencyPolicy.task_latency_qos_tier = LATENCY_QOS_TIER_0; // 0ms trễ đánh thức CPU
    task_policy_set(mach_task_self(), TASK_LATENCY_QOS_POLICY, (task_policy_t)&latencyPolicy, TASK_LATENCY_QOS_POLICY_COUNT);
    #endif

    #if defined(TASK_THROUGHPUT_QOS_POLICY)
    task_throughput_qos_policy_data_t throughputPolicy;
    throughputPolicy.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_0; // Băng thông I/O tối đa
    task_policy_set(mach_task_self(), TASK_THROUGHPUT_QOS_POLICY, (task_policy_t)&throughputPolicy, TASK_THROUGHPUT_QOS_POLICY_COUNT);
    #endif
}

// 2. CẤP QUYỀN THỜI GIAN THỰC MACH CHO LUỒNG VẼ GIAO DIỆN
static void Titanium_ElevateThreadToMachRealTime(void) {
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);

    uint64_t period_ns = 16666667;     // Chu kỳ 60 FPS (16.6ms)
    uint64_t computation_ns = 8000000; // Đảm bảo 8ms tính toán liên tục
    uint64_t constraint_ns = 12000000;

    thread_time_constraint_policy_data_t policy;
    policy.period = (uint32_t)((period_ns * timebase.denom) / timebase.numer);
    policy.computation = (uint32_t)((computation_ns * timebase.denom) / timebase.numer);
    policy.constraint = (uint32_t)((constraint_ns * timebase.denom) / timebase.numer);
    policy.preemptible = 1;

    thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}

// 3. KHÓA BỘ ĐIỀU KHIỂN TẤM NỀN MÀN HÌNH NỘI BỘ (RUNTIME CALL AN TOÀN, KHÔNG BỊ DUPLICATE INTERFACE)
static void AppleInternal_LockHardwareCADisplay(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class caDisplayClass = objc_getClass("CADisplay");
        if (caDisplayClass && [caDisplayClass respondsToSelector:sel_registerName("mainDisplay")]) {
            id display = ((id (*)(id, SEL))objc_msgSend)(caDisplayClass, sel_registerName("mainDisplay"));
            if (display) {
                SEL selLatency = sel_registerName("setLatency:");
                if ([display respondsToSelector:selLatency]) {
                    ((void (*)(id, SEL, double))objc_msgSend)(display, selLatency, 0.0);
                }
                SEL selVirtual = sel_registerName("setAllowsVirtualModes:");
                if ([display respondsToSelector:selVirtual]) {
                    ((void (*)(id, SEL, BOOL))objc_msgSend)(display, selVirtual, NO);
                }
            }
        }
    });
}

// 4. PHÂN TÁCH PHẦN CỨNG TỰ ĐỘNG (CHỈ ÉP MAX CHO CHIP A9 - A12)
static BOOL Titanium_IsLegacyA9toA12(void) {
    static BOOL s_isLegacy = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        uname(&sysInfo);
        NSString *machine = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        if ([machine hasPrefix:@"iPhone8,"] || [machine hasPrefix:@"iPhone9,"] || 
            [machine hasPrefix:@"iPhone10,"] || [machine hasPrefix:@"iPhone11,"] ||
            [machine hasPrefix:@"iPad6,"] || [machine hasPrefix:@"iPad7,"]) {
            s_isLegacy = YES;
        } else {
            s_isLegacy = NO;
        }
    });
    return s_isLegacy;
}

// 5. BỘ ĐIỀU PHỐI BURST GOVERNOR (CHẠM 0S BƠM 60FPS, BUÔNG TAY HẠ 25HZ MÁT MÁY KHI SẠC)
static volatile BOOL g_isUserTouchingScreen = NO;
static dispatch_source_t g_touchBurstTimer = nil;
static dispatch_queue_t g_touchBurstQueue = nil;

static inline void Titanium_LockMainThreadFast(void) {
    // Chỉ nâng mức QoS ưu tiên tương tác mượt mà, không ép SCHED_RR 47 để tránh nghẽn CPU sau respring
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
}

// ====================================================================================================
// BỘ ĐIỀU PHỐI BURST CẢM ỨNG & CƯỚP QUYỀN TẦNG NHÂN MACH (KHÔNG ĐEN APP, 0MS JITTER)
// ====================================================================================================

static void Titanium_TriggerInstantTouchBurst(void) {
    g_isUserTouchingScreen = YES;
    Titanium_LockMainThreadFast();
    Titanium_StealthKernelHijack(); // 👈 Gọi cướp quyền tức thì ngay khi ngón tay vừa chạm kính!

    static dispatch_once_t qToken;
    dispatch_once(&qToken, ^{
        g_touchBurstQueue = dispatch_queue_create("com.titanium.burstqueue", DISPATCH_QUEUE_SERIAL);
    });

    if (g_touchBurstTimer) {
        dispatch_source_cancel(g_touchBurstTimer);
        g_touchBurstTimer = nil;
    }

    // Nếu đang sạc pin: Giữ burst ngắn 180ms để chống nóng bo mạch tuyệt đối
    int64_t burstDuration = g_isDeviceChargingV285 ? (int64_t)(180 * NSEC_PER_MSEC) : (int64_t)(350 * NSEC_PER_MSEC);

    g_touchBurstTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, g_touchBurstQueue);
    dispatch_source_set_timer(g_touchBurstTimer, dispatch_time(DISPATCH_TIME_NOW, burstDuration), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(g_touchBurstTimer, ^{
        g_isUserTouchingScreen = NO;
        g_touchBurstTimer = nil;
    });
    dispatch_resume(g_touchBurstTimer);
}

static inline void Titanium_StealthKernelHijack(void) {
    if (!NSThread.isMainThread) return;

    // 1. CÁCH LY TUYỆT ĐỐI SÓNG SIM, MẠNG VÀ WEB
    const char *prog = getprogname();
    if (prog) {
        if (strstr(prog, "WebKit") || strstr(prog, "WebContent") || 
            strstr(prog, "GPUProcess") || strstr(prog, "Networking") ||
            strstr(prog, "CommCenter") || strstr(prog, "telephony") ||
            strstr(prog, "wifid") || strstr(prog, "wirelessproxd") ||
            strcmp(prog, "nsurlsessiond") == 0 || strcmp(prog, "mDNSResponder") == 0) {
            return;
        }
    }

    mach_port_t machThread = pthread_mach_thread_np(pthread_self());

    // 2. Tính toán chu kỳ thời gian thực theo Target Hz
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);

    double currentHz = (CFG285 && CFG285.targetHz > 0) ? (double)[CFG285 resolvedTargetHz] : 60.0;
    if (currentHz <= 0.0) currentHz = 60.0;

        // KHÓA CỨNG MACH REAL-TIME: ÉP NHÂN DARWIN CẤP 85% NĂNG LỰC P-CORE CHO LUỒNG ĐỒ HỌA
    uint64_t period_ns      = (uint64_t)(1000000000.0 / currentHz); 
    uint64_t computation_ns = (uint64_t)(period_ns * 0.85); // Ép giữ 85% chu kỳ cho tác vụ vẽ
    uint64_t constraint_ns  = period_ns;                    // Không cho phép nới lỏng deadline

    thread_time_constraint_policy_data_t timePolicy;
    timePolicy.period      = (uint32_t)((period_ns * timebase.denom) / timebase.numer);
    timePolicy.computation = (uint32_t)((computation_ns * timebase.denom) / timebase.numer);
    timePolicy.constraint  = (uint32_t)((constraint_ns * timebase.denom) / timebase.numer);
    timePolicy.preemptible = 1; // 👈 BẮT BUỘC = 1: Cho phép ngắt mạng phần cứng hoạt động xuyên suốt

    thread_policy_set(machThread, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&timePolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);

    thread_policy_set(machThread, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&timePolicy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);

    // 3. Giữ timeshare = 1 để nhân Darwin vẫn điều phối được đa nhiệm, không làm chết socket mạng ngầm
    thread_extended_policy_data_t extPolicy;
    extPolicy.timeshare = 1; 
    thread_policy_set(machThread, THREAD_EXTENDED_POLICY, (thread_policy_t)&extPolicy, THREAD_EXTENDED_POLICY_COUNT);

    // 4. Ưu tiên P-Core cho luồng đồ họa
    thread_affinity_policy_data_t affPolicy;
    affPolicy.affinity_tag = 1;
    thread_policy_set(machThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affPolicy, THREAD_AFFINITY_POLICY_COUNT);

    // 5. Tối ưu I/O và nâng mức QoS tương tác người dùng chuẩn Apple
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
}

// ====================================================================================================
// NHÓM 1: CẢM ỨNG 0MS & CHỐNG RUNG CHỮ KHI MỞ APP (ĐÃ TỐI ƯU TOÀN DIỆN)
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

%hook UIGestureRecognizer
- (BOOL)delaysTouchesBegan { 
    return %orig; 
}

- (BOOL)delaysTouchesEnded { 
    return %orig; 
}

- (void)setDelaysTouchesBegan:(BOOL)flag { 
    %orig; 
}

- (void)setDelaysTouchesEnded:(BOOL)flag { 
    %orig; 
}
%end

// 2. PHẢN HỒI NÚT BẤM VÀ ĐIỀU HƯỚNG TỨC THÌ
%hook UIControl
- (NSTimeInterval)_touchDelayThreshold {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return 0.0;
    return %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(touches, event);
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
}
%end

// 3. KHÓA TỌA ĐỘ NGUYÊN PIXEL CHỐNG RUNG CHỮ (CHỈ LÀM TRÒN KHI BỊ LỆCH SUB-PIXEL)
%hook UILabel
- (void)setFrame:(CGRect)frame {
    %orig(frame);
}

- (void)setBounds:(CGRect)bounds {
    %orig(bounds);
}
%end

%hook UIWindow
- (BOOL)_shouldDelayTouchForCancelEvents {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return NO;
    return %orig;
}

- (void)sendEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost && event.type == 0) {
        for (UITouch *touch in [event allTouches]) {
            if (touch.phase == UITouchPhaseBegan || touch.phase == UITouchPhaseMoved) {
                g_isInstantMotion = YES;
                Titanium_TriggerInstantTouchBurst();
                break;
            } else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) {
                if (!g_isScrollingActive && !g_isContinuousSwiping && !g_isAppToHomeAnimating) {
                    g_isInstantMotion = NO;
                }
            }
        }
    }
    %orig(event);
}
%end

%end // KẾT THÚC %group Group_ZeroLatency_Touch_Opt

// ====================================================================================================
// NHÓM 2: METAL GRAPHICS, TRIPLE BUFFERING & KHÓA CHỐNG RUNG LAYER
// ====================================================================================================
%group Group_Metal_ZeroTearing_Pacing

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ACTIVE && CFG285.metalHexBuffering) {
        count = 3; // Triple Buffering: Luôn sẵn 1 frame gối đầu
    }
    %orig(count);
}

- (NSUInteger)maximumDrawableCount {
    if (IS_ACTIVE && CFG285.metalHexBuffering) return 3;
    return %orig;
}

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if (IS_ACTIVE) enabled = YES; // Đồng bộ VSync 100% chống xé hình
    %orig(enabled);
}

// CẤM GPU TIMEOUT: Không cho phép GPU hủy khung hình đang dựng dở khi tải nặng
- (void)setAllowsNextDrawableTimeout:(BOOL)allow {
    if (IS_ACTIVE) allow = NO;
    %orig(allow);
}

// Cho phép nạp lệnh song song nhưng không ép LowLatencyMode (tránh đen app)
- (void)setPresentsWithTransaction:(BOOL)flag {
    if (IS_ACTIVE) flag = NO; // Xuất ngay lên màn hình khi render xong, không đợi giao dịch gộp
    %orig(flag);
}
%end

%hook CALayer
- (void)display {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (void)setPosition:(CGPoint)position {
    %orig(position);
}

// Giảm tải GPU: Cho phép các layer phức tạp vẽ nền bất đồng bộ
- (void)setDrawsAsynchronously:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
    %orig(flag);
}
%end

// GỘP HOÀN CHỈNH: TỐI ƯU HÓA RENDER SERVER & XẾP LỚP LAYER (KHÔNG TEO NHỎ APP)
%hook CAContext
- (void)orderAbove:(uint32_t)contextId {
    if (IS_ACTIVE && Titanium_IsSpringBoard()) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(contextId);
}

- (void)setCommitPriority:(uint32_t)priority {
    if (!Titanium_IsSpringBoard() && IS_ACTIVE) {
        priority = 100;
    }
    %orig(priority);
}

- (uint32_t)commitPriority {
    if (Titanium_IsSpringBoard()) return %orig;
    if (IS_ACTIVE) return 100;
    return %orig;
}

- (void)setDesiredDynamicRange:(float)range {
    if (IS_ACTIVE) range = 1.0f;
    %orig(range);
}
%end

%end

// ====================================================================================================
// BIẾN QUẢN LÝ TRẠNG THÁI CHUYỂN ĐỘNG, VIDEO VÀ THÔNG BÁO HỆ THỐNG
// ====================================================================================================

// Quản lý biến an toàn đa luồng cho hoạt ảnh, video, cuộn trang và thông báo
static volatile int32_t g_activeAnimationCount = 0;
static volatile BOOL g_isVideoPlayingActive = NO;
static volatile BOOL g_isNotificationBannerActive = NO;
static dispatch_source_t g_bannerBurstTimer = nil;
static dispatch_queue_t g_bannerBurstQueue = nil;

// Kích xung nhịp CPU/GPU cực đại tức thì 0ms khi có thông báo xuất hiện
static void Titanium_TriggerNotificationBurst(void) {
    g_isNotificationBannerActive = YES;
    Titanium_LockMainThreadFast();
    Titanium_EnableZeroLatencyPipeline();

    static dispatch_once_t bToken;
    dispatch_once(&bToken, ^{
        g_bannerBurstQueue = dispatch_queue_create("com.titanium.bannerburst", DISPATCH_QUEUE_SERIAL);
    });

    if (g_bannerBurstTimer) {
        dispatch_source_cancel(g_bannerBurstTimer);
        g_bannerBurstTimer = nil;
    }

    // Giữ trần FPS trong 850ms để bao trọn thời lượng banner rơi xuống và neo mượt mà
    g_bannerBurstTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, g_bannerBurstQueue);
    dispatch_source_set_timer(g_bannerBurstTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(850 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(g_bannerBurstTimer, ^{
        g_isNotificationBannerActive = NO;
        g_bannerBurstTimer = nil;
    });
    dispatch_resume(g_bannerBurstTimer);
}

// ====================================================================================================
// NHÓM 3: KHÓA CỨNG HZ/FPS TÙY CHỌN - TỰ HẠ KHI TĨNH - ĐÓN ĐẦU THÔNG BÁO - BẢO VỆ VIDEO
// (CHỈ ÁP DỤNG IPHONE 6S - 12 PRO MAX)
// ====================================================================================================

static inline BOOL Titanium_ShouldLockTargetRate(void) {
    if (g_isSwitcherActive) return YES;         // 👈 Đang mở đa nhiệm: Giữ trần 120Hz, cấm rụng 15Hz khi buông tay
    if (g_isAppOpeningAnimating) return YES;
    if (g_isAppToHomeAnimating) return YES;
    if (g_isInstantMotion) return YES; 
    if (g_isContinuousSwiping) return YES; 
    if (g_isUserTouchingScreen) return YES; 
    if (g_isScrollingActive) return YES; 
    if (g_isNotificationBannerActive) return YES; 
    if (g_activeAnimationCount > 0) return YES; 
    return NO; 
}

// 2. Kiểm tra xem có đang ở chế độ xem video thụ động (không tương tác tay) hay không
static inline BOOL Titanium_IsPassiveVideoPlayback(void) {
    // Chỉ nhả về gốc khi đang xem video mà KHÔNG chạm tay và KHÔNG cuộn trang
    return (g_isVideoPlayingActive && !g_isUserTouchingScreen && !g_isScrollingActive);
}

%group Group_FluidTransitions_Pacing

// ====================================================================================================
// 1. ĐIỀU PHỐI DẢI TẦN SỐ QUÉT ĐỘNG CAFrameRateRange TRÊN iOS 16+
// ====================================================================================================
%hook CADisplayLink

- (NSInteger)preferredFramesPerSecond {
    if (Titanium_IsPassiveVideoPlayback()) return %orig;

    if (IS_ACTIVE && CFG285.enableFPSControl) {
        return Titanium_ShouldLockTargetRate() ? 120 : 15;
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (Titanium_IsPassiveVideoPlayback()) {
        %orig;
        return;
    }

    if (IS_ACTIVE && CFG285.enableFPSControl) {
        if (Titanium_ShouldLockTargetRate()) {
            Titanium_StealthKernelHijack();
            Titanium_EnableZeroLatencyPipeline();
            %orig(120); // Có chuyển động: Đẩy kịch trần 120 FPS
            return;
        }
        %orig(15);      // Màn hình tĩnh: Hạ thẳng 15 FPS
        return;
    }
    %orig;
}

// CƯỚP QUYỀN DẢI TẦN DYNAMIC TRÊN iOS 16+:
// Khi tương tác: Khóa cứng 120-120-120
// Khi đứng yên: Khóa cứng 15-15-15 để làm mát bo mạch tuyệt đối
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (Titanium_IsPassiveVideoPlayback()) { 
        %orig; 
        return; 
    }

    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE && CFG285.enableHzControl) {
            if (Titanium_ShouldLockTargetRate()) {
                range = SafeMakeFRR(120.0f, 120.0f, 120.0f);
                Titanium_StealthKernelHijack();
                Titanium_EnableZeroLatencyPipeline();
            } else {
                range = SafeMakeFRR(15.0f, 15.0f, 15.0f); // 👈 Hạ trần max về đúng 15Hz
            }
        }
    }
    %orig(range);
}

- (void)setFrameInterval:(NSInteger)interval {
    if (!HardwareHasNative120Hz() && !Titanium_IsPassiveVideoPlayback() && IS_ACTIVE && CFG285.enableHzControl) {
        interval = 1;
    }
    %orig(interval);
}

%end

// ====================================================================================================
// 2. KHÓA TẤM NỀN PHẦN CỨNG CADISPLAY (BẢO VỆ VSYNC KHÔNG ĐEN MÀN)
// ====================================================================================================
%hook CADisplay

- (NSInteger)preferredFPS {
    if (HardwareHasNative120Hz() || Titanium_IsPassiveVideoPlayback()) return %orig;
    if (!IS_ACTIVE) return %orig;
    
    NSInteger target = [CFG285 resolvedTargetFPS];
    return Titanium_ShouldLockTargetRate() ? target : 15;
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (HardwareHasNative120Hz() || Titanium_IsPassiveVideoPlayback()) { 
        %orig; 
        return; 
    }
    
    if (IS_ACTIVE) {
        NSInteger target = [CFG285 resolvedTargetFPS];
        fps = Titanium_ShouldLockTargetRate() ? target : 15;
    }
    %orig(fps);
}

// KHÓA CỨNG CADENCE PHẦN CỨNG: CẤM WINDOWSERVER TỰ Ý DÃN CHU KỲ VSYNC
- (void)overrideDisplayCadence:(id)cadence {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        // Cưỡng bức khóa cadence về mode 0 (mode xuất frame cao nhất của phần cứng)
        %orig(nil);
        return;
    }
    %orig(cadence);
}

- (BOOL)supportsDynamicRefresh {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (void)setAllowsVirtualModes:(BOOL)allows {
    // Khóa phần cứng chạy trực tiếp ở chế độ Native, cấm chế độ ảo giả lập làm trễ VSync
    if (IS_ACTIVE) allows = NO;
    %orig(allows);
}

- (BOOL)hasDynamicDisplayMode {
    if (HardwareHasNative120Hz()) return %orig;
    if (!IS_ACTIVE) return YES;
    return %orig;
}

%end

// ====================================================================================================
// 3. MỞ KHÓA PROMOTION CHO CÁC APP TRÊN iOS 16+
// ====================================================================================================
%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (HardwareHasNative120Hz()) return %orig;
    if (IS_ACTIVE) return [CFG285 resolvedTargetFPS];
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (HardwareHasNative120Hz()) return %orig;
    if (IS_ACTIVE) return [CFG285 resolvedTargetFPS];
    return %orig;
}

- (CGFloat)_refreshRate {
    if (HardwareHasNative120Hz()) return %orig;
    if (IS_ACTIVE) return (CGFloat)[CFG285 resolvedTargetHz];
    return %orig;
}

// Cho WebKit và App biết máy có hỗ trợ Dynamic Refresh Rate
- (BOOL)supportsDynamicRefreshRate {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)_supportsDynamicRefreshRate {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (HardwareHasNative120Hz()) { 
        %orig; 
        return; 
    }
    if (IS_ACTIVE) {
        rate = (CGFloat)[CFG285 resolvedTargetHz];
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(rate);
}

%end

// ====================================================================================================
// 4. KHÓA TỐC ĐỘ DỰNG HOẠT ẢNH VÀ LÒ XO (ANIMATION & SPRING)
// ====================================================================================================
%hook CAAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!HardwareHasNative120Hz() && !Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            float target = (float)[CFG285 resolvedTargetHz];
            range = SafeMakeFRR(target, target, target);
        }
    }
    %orig(range);
}

- (void)setDelegate:(id)delegate {
    %orig;
    if (IS_ACTIVE) {
        __sync_fetch_and_add(&g_activeAnimationCount, 1);
    }
}

%end

%hook CASpringAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!HardwareHasNative120Hz() && !Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            float target = (float)[CFG285 resolvedTargetHz];
            range = SafeMakeFRR(target, target, target);
        }
    }
    %orig(range);
}

%end

%hook CATransaction

+ (void)commit {
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
    if (IS_ACTIVE && g_activeAnimationCount > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (g_activeAnimationCount > 0) {
                __sync_fetch_and_sub(&g_activeAnimationCount, 1);
            }
        });
    }
}

%end

// 5. THEO DÕI VIDEO
%hook AVPlayer

- (void)setRate:(float)rate {
    %orig(rate);
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = (rate > 0.0f);
    }
}

%end

// 6. ĐÓN ĐẦU THÔNG BÁO XUẤT HIỆN: KÍCH XUNG LÊN TRẦN HZ/FPS ĐÃ KHÓA TRƯỚC 0MS
%hook NCNotificationDispatcher

- (void)postNotificationWithRequest:(id)request {
    if (IS_ACTIVE) {
        Titanium_TriggerNotificationBurst();
    }
    %orig(request);
}

%end

%hook NCNotificationViewController

- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerNotificationBurst();
    }
    %orig(animated);
}

%end

%hook SBNotificationBannerDestination

- (void)postNotificationRequest:(id)request {
    if (IS_ACTIVE) {
        Titanium_TriggerNotificationBurst();
    }
    %orig(request);
}

%end

// 7. TẢI LẠI CẤU HÌNH KHI APP ACTIVE
%hook UIApplication

- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        if (!Titanium_IsSpringBoard()) {
            [[BoostConfigV285Pro sharedInstance] loadSettings];
        }
        Titanium_EnableZeroLatencyPipeline();
    }
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        if (!Titanium_IsSpringBoard()) {
            [[BoostConfigV285Pro sharedInstance] loadSettings];
        }
        Titanium_EnableZeroLatencyPipeline();
    }
}
%end

// Ép dải tần số quét tối đa cho toàn bộ UIView Animation trên iOS 16+
%hook UIView

+ (void)_setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!HardwareHasNative120Hz() && !Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            float target = (float)[CFG285 resolvedTargetHz];
            range = SafeMakeFRR(target, target, target);
        }
    }
    %orig(range);
}
%end

%end

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT (DỨT ĐIỂM MÀN HÌNH ĐEN KHI MỞ APP)
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

// 1. BẮT ĐẦU CỬ CHỈ VUỐT: Bắt từ bộ nhận diện cử chỉ (0ms) để không bị trễ frame đầu
%hook SBHomeGestureInteraction
- (void)_handleGestureRecognizer:(UIGestureRecognizer *)gesture {
    if (IS_ACTIVE) {
        if (gesture.state == UIGestureRecognizerStateBegan || gesture.state == UIGestureRecognizerStatePossible) {
            g_isContinuousSwiping = YES;
            g_isInstantMotion = YES;
            Titanium_TriggerInstantTouchBurst();
            Titanium_StealthKernelHijack();
            Titanium_LockMainThreadFast();
        }
    }
    %orig(gesture);
}
%end

// 2. ÉP RENDER BẤT ĐỒNG BỘ CARD ĐA NHIỆM (ĐÃ SỬA CHỮ 'A' VIẾT HOA CHUẨN XÁC)
%hook SBFluidSwitcherModifier
- (BOOL)shouldAsyncRenderAppLayouts {
    if (IS_ACTIVE) return YES; // Chuẩn selector của Apple: Vẽ ngầm trước tránh khựng
    return %orig;
}
%end

// ====================================================================================================
// 3. THOÁT APP (APP-TO-HOME): ÉP TRIỆT TIÊU 100% ĐỘ KHỰNG & KHÓA CỨNG 120Hz SUỐT ĐƯỜNG BAY
// ====================================================================================================

// GIỮ QUÁN TÍNH TỰ NHIÊN CỦA APPLE - CHỈ KIỂM SOÁT ĐỘ ÊM, KHÔNG ÉP BẬT NHANH
%hook SBAppToHomeAnimationSettings
- (void)setDefaultValues {
    %orig;
    if (IS_ACTIVE) {
        // Giữ mass và stiffness tự nhiên của Apple, chỉ tăng nhẹ damping để khi về đích không bị nảy giật
        self.damping = 42.0; 
    }
}
%end

// 2. Chống nghẽn GPU khi hình nền Homescreen nét trở lại lúc thoát app
%hook SBHomeScreenBackdropView
- (void)beginRequiringLiveBackdropViewForReason:(id)reason {
    if (IS_ACTIVE) {
        Titanium_StealthKernelHijack();
    }
    %orig(reason);
}
%end

%hook SBAppToHomeWorkspaceTransaction
- (BOOL)shouldAnimateOrientationChangeOnCompletion {
    return NO;
}

- (void)_willBegin {
    if (IS_ACTIVE) {
        g_isAppToHomeAnimating = YES; // Khóa cờ giữ 120Hz
        g_isInstantMotion = YES;
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (void)_beginAnimation {
    if (IS_ACTIVE) {
        g_isAppToHomeAnimating = YES;
        g_isInstantMotion = YES;
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
    }
    %orig;
    if (IS_ACTIVE) {
        Titanium_LockMainThreadFast();
    }
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;

        // Giữ trần 120Hz thêm 300ms để đợi Dock và các Icon Homescreen hoàn tất dao động nảy tự nhiên
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (!g_isContinuousSwiping && !g_isUserTouchingScreen) {
                g_isAppToHomeAnimating = NO;
                g_isInstantMotion = NO;
            }
        });

        dispatch_async(dispatch_get_main_queue(), ^{
            Titanium_EnableZeroLatencyPipeline();
        });

        // Chỉ thu hồi RAM nếu sau 2.0 giây người dùng KHÔNG chạm, KHÔNG vuốt và KHÔNG có hoạt cảnh thoát app
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            if (!g_isContinuousSwiping && !g_isUserTouchingScreen && !g_isAppToHomeAnimating) {
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            }
        });
    }
}
%end


// ====================================================================================================
// 4. QUẢN LÝ BỘ NHỚ ĐỆM SNAPSHOT & ĐÀ LƯỚT CHUYỂN APP DỨT KHOÁT
// ====================================================================================================

%hook SBAppSwitcherSettings
// KHÔNG GIỮ TOÀN BỘ SNAPSHOT TRONG RAM: Cho phép dọn bớt thẻ ở xa để không nghẽn GPU khi lướt ngang
- (BOOL)shouldKeepAppSnapshotsInMemory {
    return %orig;
}

- (CGFloat)decelerationRate {
    return %orig; // Trả về quán tính mượt tự nhiên của Apple
}
%end

%hook SBAppSwitcherController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        g_isSwitcherActive = YES; // Bật cờ giữ 120Hz ngay khi bước vào đa nhiệm
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        g_isSwitcherActive = NO; // Rời khỏi đa nhiệm: Nhả cờ an toàn
    }
}

// TRIỆT TIÊU GIẬT KHI VUỐT BỎ TAB (KILL APP):
// Giữ trần 120Hz để thẻ bay vút lên và các thẻ xung quanh dồn vào nhau mượt mà
- (void)switcherContentController:(id)contentController deletedItem:(id)deletedItem {
    if (IS_ACTIVE) {
        g_isSwitcherActive = YES;
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(450 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            // Sau khi các thẻ dồn vào xong vẫn duy trì theo trạng thái switcher
        });
    }
    %orig(contentController, deletedItem);
}
%end

// TRẢ VỀ RENDER ĐỒNG BỘ: Không dùng drawsAsynchronously để thẻ không bị chớp hay trễ frame
%hook SBFluidSwitcherItemContainer
- (void)prepareForReuse {
    %orig;
}
%end

// Xóa giật bóng mờ khi thẻ app tiếp đất thành icon trên màn hình chính
%hook SBIconView
- (void)setAllowsGroupOpacity:(BOOL)allows {
    if (IS_ACTIVE && (g_isAppToHomeAnimating || g_isContinuousSwiping)) {
        %orig(NO);
        return;
    }
    %orig(allows);
}
%end

%end

// ====================================================================================================
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC (TURBO ENGINE)
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

%hook FBApplicationProcess
- (void)bootstrapWithContext:(id)context completion:(id)completion {
    // Chỉ cướp quyền I/O và CPU sau khi SpringBoard đã sẵn sàng, tránh nghẽn lúc boot
    if (IS_ACTIVE && CFG285.turboAppLaunch && [[UIApplication sharedApplication] keyWindow] != nil) {
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
        Titanium_StealthKernelHijack();
    }
    %orig(context, completion);
}

- (void)launchIfNecessary {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        Titanium_StealthKernelHijack();
    }
    %orig;
}
%end

%hook UIApplication
- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        // Bơm xung P-Core tính toán layout giao diện đầu tiên
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(scene, context, completion);
}

- (void)_applicationWillEnterForeground {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 6: CUỘN FEED TIKTOK / BÀN PHÍM SIÊU NHẠY (BẢO TOÀN NỀN SAFARI VÀ ICON EMOJI)
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

// 1. ÉP BÀN PHÍM BẬT RA NHANH GẤP ĐÔI (TỪ 0.25S RÚT XUỐNG 0.12S) & SIÊU NHẠY GÕ PHÍM
%hook UIInputViewAnimationStyle
- (double)duration {
    if (IS_ACTIVE) return 0.09; 
    return %orig;
}
%end

%hook UIKeyboardImpl
- (void)showKeyboard {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack(); // 👈 Cướp quyền CPU vẽ bàn phím trong 0ms
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(string, event, context);
}

- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(string, flags, context);
}
%end

%hook UITextInputController
- (void)_insertText:(id)text {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(text);
}

- (void)deleteBackward {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}
%end

// 3. TĂNG TỐC CHUYỂN QUA LẠI CÁC TAB (UITABBARCONTROLLER) TỨC THÌ
%hook UITabBarController
- (void)setSelectedIndex:(NSUInteger)index {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack(); // 👈 Thay LockMainThread bằng Stealth Hijack để không nghẽn luồng tải tab
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(index);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(selectedViewController);
}
%end

// 4. TĂNG TỐC ĐẨY/RÚT TRANG NAVIGATION (PUSH/POP/PRESENT MENU)
%hook UINavigationController
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack(); // 👈 Cướp quyền render view mới
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(viewController, animated);
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    return %orig(animated);
}
%end

%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(viewControllerToPresent, flag, completion);
}
%end

// 5. CUỘN FEED TIKTOK / FACEBOOK / SAFARI TRÔI MƯỢT QUÁN TÍNH%hook UIScrollView
%hook UIScrollView
- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        Titanium_StealthKernelHijack(); // Bơm xung Mach giữ trần FPS suốt đà trôi
        Titanium_LockMainThreadFast();
    }
    %orig(timestamp);
}

// Dừng trôi hẳn: Lập tức nhả cờ để ProMotion hạ tần số về 15 FPS làm mát máy
- (void)_stopScrollDecelerationNotify:(BOOL)notify {
    %orig(notify);
    if (IS_ACTIVE) {
        g_isScrollingActive = NO;
    }
}

// Bắt đầu kéo: Kích cờ cuộn để giữ trần 120Hz/60Hz
- (void)_scrollViewWillBeginDragging {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (void)_notifyDidScroll {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)_scrollViewDidEndDecelerating {
    %orig;
    if (IS_ACTIVE) {
        g_isScrollingActive = NO;
    }
}

- (void)_scrollViewDidEndDraggingForChildScrollView:(id)view {
    %orig(view);
    if (IS_ACTIVE && !self.isDecelerating) {
        g_isScrollingActive = NO;
    }
}

%end

// 6. GIỮ ĐỘ PHẢN HỒI CELL NHANH NHƯNG BẢO TOÀN NỀN SAFARI VÀ ICON EMOJI
%hook UITableView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.delaysContentTouches = NO;
        self.layer.drawsAsynchronously = YES; // Vẽ bất đồng bộ giảm tải CPU
    }
}
%end

%hook UICollectionView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.delaysContentTouches = NO;
        self.layer.drawsAsynchronously = YES;
    }
}
%end

// GIẢM TẢI TIKTOK/FACEBOOK: Đẩy việc vẽ cell sang luồng nền
%hook UITableViewCell
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.layer.drawsAsynchronously = YES;
    }
}
%end

%hook UICollectionViewCell
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        self.layer.drawsAsynchronously = YES;
    }
}
%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD - TOÀN BỘ HIỆU ỨNG BÊN NGOÀI (FOLDER, LOCKSCREEN, 3D TOUCH, CC/NC, LOAD APP)
// ====================================================================================================

%group Group_Display_SpringBoardV285

// ====================================================================================================
// 1. KHÓA CỨNG HÌNH NỀN TĨNH & ĐÓNG BĂNG MÔ HÌNH 3D (GIẢI PHÓNG 80% TẢI GPU)
// ====================================================================================================

%hook SBWallpaperController
- (double)wallpaperScaleForVariant:(long long)variant {
    return %orig;
}
%end

%hook PBFPosterExtensionDataStore
- (void)_updateSnapshot {
    if (IS_ACTIVE) return;
    %orig;
}
%end

// ====================================================================================================
// 2. KHỬ TRỄ BẤM ICON: NẢY TỨC THÌ 0MS NHƯNG KHÔNG GIẬT KHI LƯỚT NGANG
// ====================================================================================================

%hook SBIconView
- (double)highlightDelay {
    if (IS_ACTIVE) return 0.05; // 50ms: Ngăn kích hoạt highlight giả khi lướt ngang trang
    return %orig;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted && IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(highlighted);
}

- (void)setTouchDownInIcon:(BOOL)touchDown {
    if (touchDown && IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(touchDown);
}
%end

// ====================================================================================================
// 3. TỐI ƯU CỬ CHỈ ĐA NHIỆM SPRINGBOARD (GIỮ NGUYÊN HOẠT ẢNH 26ANIM)
// ====================================================================================================

%hook SBFluidSwitcherViewController
- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(gesture);
}
%end

// ====================================================================================================
// 4. TRIỆT TIÊU LAG KHI CHỤP MÀN HÌNH
// ====================================================================================================

%hook SBScreenshotManager
- (void)saveScreenshotsWithCompletion:(id)completion {
    if (IS_ACTIVE) Titanium_TriggerInstantTouchBurst();
    %orig(completion);
}
%end

// ====================================================================================================
// 5. KÉO CONTROL CENTER & TRUNG TÂM THÔNG BÁO TỨC THÌ (0MS DELAY)
// ====================================================================================================

%hook SBControlCenterController
- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(animated, completion);
}
%end

%hook SBNotificationCenterController
- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(animated, completion);
}
%end

// ====================================================================================================
// 6. SỬA DỨT ĐIỂM GIẬT/GỢN KHI LƯỚT TRANG MÀN HÌNH CHÍNH (SMOOTH HOMESCREEN PAGING)
// ====================================================================================================

%hook SBIconScrollView
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)delaysContentTouches {
    return YES;
}

- (void)_notifyDidScroll {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        Titanium_LockMainThreadFast();
    }
    %orig(timestamp);
}
%end

%hook SBIconListView
- (void)setAlpha:(CGFloat)alpha {
    %orig(alpha); // Không ép allowsGroupOpacity để tránh vẽ offscreen gây nháy widget
}
%end

%hook SBIconController
- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(index, animate);
}
%end

// ====================================================================================================
// 7. TOÀN DIỆN HIỆU ỨNG THƯ MỤC, 3D TOUCH & MÀN HÌNH KHÓA (COVERSHEET / HOMESCREEN)
// ====================================================================================================

// TRẢ VỀ CHU KỲ VẬT LÝ GỐC: XÓA BỎ HOÀN TOÀN HIỆN TƯỢNG NHẤP NHÁY THƯ MỤC
%hook SBFolderControllerAnimationSettings
- (double)duration {
    return %orig; // Đồng bộ thời gian với hiệu ứng làm mờ nền của iOS
}
%end

%hook SBFolderView
- (void)prepareToOpen {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst(); // Chỉ kích xung nhịp, không bật LowLatency trên lớp mờ
    }
    %orig;
}
%end

// Menu giữ đè icon (3D Touch / Haptic Touch) mở ra tức thì 0ms
%hook SBIconForceTouchSettings
- (double)delayBeforeOpening {
    if (IS_ACTIVE) return 0.01; // 50ms: Đặt ngón tay là menu bung ngay lập tức
    return %orig;
}
%end

// Vuốt mở Màn hình khóa (LockScreen / CoverSheet) siêu mượt
%hook CSCoverSheetViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(animated);
}
%end

// Kích xung ưu tiên khi quay trở lại Màn hình chính
%hook SBHomeScreenViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(animated);
}
%end

// ====================================================================================================
// 8. ÉP TỐC ĐỘ LOAD APP SIÊU TỐC & TRIỆT TIÊU ĐỘ TRỄ MỞ ỨNG DỤNG (ULTRA-FAST LAUNCH)
// ====================================================================================================

// TRẢ VỀ CHU KỲ NỘI SUY GỐC CỦA APPLE: ICON NỞ ĐỀU RA TOÀN MÀN HÌNH, KHÔNG BỊ MÉO TRÒN
%hook SBAppLaunchSettings
- (double)zoomDuration {
    return %orig; // Giữ nguyên để bán kính bo góc dãn khớp 100% với khung hình
}

- (double)launchDuration {
    return %orig; // Giữ nguyên để app có đủ thời gian vẽ frame đầu tiên
}

- (double)delayBeforeAppLaunch {
    if (IS_ACTIVE) return 0.0; // Chỉ xóa độ trễ nhận diện khi bấm chạm
    return %orig;
}
%end

// BUNG MÀN HÌNH CHỜ/LOADING TỨC THÌ NHƯNG LUÔN CÓ HÌNH BỌC LÓT (CHỐNG MÀN HÌNH ĐEN)
%hook SBSplashBoardController
- (double)splashScreenDelay {
    if (IS_ACTIVE) return 0.10; // 20ms: Bung ra ngay tức thì nhưng đảm bảo layer Loading đã nạp xong
    return %orig; 
}
%end

%hook SBUIAnimationController
- (void)_willBeginAnimation {
    if (IS_ACTIVE) {
        g_isAppOpeningAnimating = YES;
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (void)_cleanupAnimation {
    %orig;
    if (IS_ACTIVE) {
        // App đã bung xong toàn màn hình: Đợi 200ms để khung hình ổn định hoàn toàn rồi mới hạ xung
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            g_isAppOpeningAnimating = NO;
        });
    }
}
%end

%end

// ====================================================================================================
// NHÓM 8: PIPELINE CHO PICTURE-IN-PICTURE (PIP 60FPS MƯỢT MÀ)
// ====================================================================================================

%group Group_V285_FloatingWindow_PiP

%hook PGPictureInPictureRemoteObject
- (void)_updatePreferredContentSize {
    %orig;
    if (IS_ACTIVE) Titanium_LockMainThreadFast();
}

- (void)startPictureInPicture {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = YES;
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)stopPictureInPictureAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = NO;
        Titanium_LockMainThreadFast();
    }
    %orig(animated);
}
%end

%hook SBPIPController
- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    if (IS_ACTIVE) Titanium_LockMainThreadFast();
    %orig(pid, sceneId, animated, completion);
}
%end

%hook AVPictureInPictureController
- (void)startPictureInPicture {
    if (IS_ACTIVE) Titanium_LockMainThreadFast();
    %orig;
}

- (void)stopPictureInPicture {
    if (IS_ACTIVE) Titanium_LockMainThreadFast();
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 9: PHÂN TÁCH PHẦN CỨNG (HOME BUTTON VẬT LÝ)
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions
- (void)performSinglePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (void)performDoublePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH & BẢO VỆ JETSAM
// ====================================================================================================

// ====================================================================================================
// NHÓM KIỂM SOÁT ĐỘC QUYỀN SPRINGBOARD (120Hz CHẠM - 15Hz NGHỈ - ĐỒNG BỘ DOCK & ĐA NHIỆM)
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

// 1. QUẢN LÝ TIẾN TRÌNH & LAUNCH APP GỐC (ĐÃ GỘP CHUẨN ĐỦ 3 HÀM)
%hook SBApplication
- (void)setProcessState:(id)state {
    %orig(state);
}

- (void)willActivate {
    if (IS_ACTIVE) {
        g_isAppOpeningAnimating = YES;
        Titanium_TriggerInstantTouchBurst();
        // BỎ Titanium_LockMainThreadFast để CPU chia tài nguyên cho App con kịp vẽ khung hình
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (BOOL)shouldPrewarmOnLaunch {
    if (IS_ACTIVE) return YES;
    return %orig;
}
%end

%hook SBMainWorkspace
- (void)handleApplicationLaunch:(id)application {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(application);
}
%end

// 4. ÉP ĐỒNG BỘ DOCK: TRIỆT TIÊU GIẬT / LỆCH NHỊP KHI DOCK NẢY LÊN
%hook SBDockView
- (void)layoutSubviews {
    %orig;
    if (IS_ACTIVE) {
        self.layer.allowsGroupOpacity = NO;
    }
}

- (void)setBackgroundAlpha:(CGFloat)alpha {
    if (IS_ACTIVE && (g_isAppToHomeAnimating || g_isContinuousSwiping)) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(alpha);
}
%end

// CÂN BẰNG LÒ XO ĐA NHIỆM: LƯỚT NGANG BÁM TAY VÀ VUỐT BAY LÊN KHÔNG BỊ KHỰNG
%hook SBFluidSwitcherAnimationSettings
- (void)setDefaultValues {
    %orig;
    if (IS_ACTIVE) {
        self.mass = 1.0;        // Trọng lượng tự nhiên
        self.stiffness = 320.0; // Độ nảy vừa phải, không ghì giật thẻ
        self.damping = 34.0;    // Dập rung êm ru khi thẻ dừng lại
    }
}
%end

%end // KẾT THÚC %group Group_SpringBoard_ProcessManagerV285

// ====================================================================================================
// NHÓM 11: NÂNG CẤP TOÀN BỘ ỨNG DỤNG BÊN THỨ BA (TIKTOK, ZALO, TỆP, APP STORE)
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

%hook UIWindow
- (void)makeKeyAndVisible {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}
%end

%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_StealthKernelHijack(); // Dùng Stealth Hijack để luồng mạng tải data song song
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(animated);
}

- (void)viewDidLoad {
    if (IS_ACTIVE) {
        Titanium_StealthKernelHijack();
    }
    %orig;
}
%end

// 2. PHÁ VÒNG XOAY LOADING: VỪA XOAY LÀ CPU TẬP TRUNG XỬ LÝ XONG NGAY LẬP TỨC
%hook UIActivityIndicatorView
- (void)startAnimating {
    if (IS_ACTIVE) {
        Titanium_StealthKernelHijack(); // Bơm xung P-Core giải nén dữ liệu nhanh
    }
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 12: BÀN PHÍM STREAM TEXT & CẢM ỨNG NÚT BẤM (ĐÃ LỌC BỎ CÁC HOOK TRÙNG)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

%hook UIKeyboardTaskQueue
- (void)performTask:(id)task {
    if (IS_ACTIVE) Titanium_LockMainThreadFast();
    %orig(task);
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
        Titanium_StealthKernelHijack(); // 👈 Cướp quyền ngay khi ngón tay vừa áp vào nút bấm
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(touches, event);
}
%end

%end

// ====================================================================================================
// NHÓM 13: KHÓA CỨNG TRẦN 60.00 FPS & CHẶN BÓP XUNG NHIỆT ĐỘ APPLE
// ====================================================================================================

// TRẢ VỀ CƠ CHẾ ĐIỀU NHIỆT VÀ QUẢN LÝ TIẾN TRÌNH CỦA APPLE: HẠ NHIỆT MÁY VÀ GIẢI PHÓNG RAM
%group Group_Global_Thread_Governor_Unthrottled

%hook RBSProcessState
- (unsigned char)taskState {
    return %orig; // Cho phép hệ thống hạ ưu tiên các tiến trình chạy ngầm
}
%end

%hook FBProcess
- (BOOL)isPendingExit {
    return %orig; // Cho phép dọn dẹp các app không sử dụng để tránh cạn kiệt RAM
}
%end

%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    return %orig; // Bật lại cảm biến nhiệt để phần cứng tự điều tiết an toàn
}

- (BOOL)isLowPowerModeEnabled {
    return %orig;
}
%end

%hook NSNotificationCenter
- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo {
    %orig(aName, anObject, aUserInfo); // Không chặn thông báo cảnh báo nhiệt độ
}
%end

%end

// ====================================================================================================
// GIA TỐC TOÀN BỘ HIỆU ỨNG BÊN TRONG ỨNG DỤNG (MODAL, POPUP, SHEET, CONTEXT MENU)
// ====================================================================================================

%group Group_Universal_InApp_Animations

// 1. Ép bộ máy Animator hiện đại chạy mượt tuyệt đối không rơi khung hình
%hook UIViewPropertyAnimator
- (void)startAnimation {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}
%end

// 2. Menu 3 chấm / Giữ đè icon bung ra ngay lập tức
%hook _UIContextMenuContainerView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
}
%end

// 3. Bảng thông báo Dialog / Alert bung ra không trễ
%hook UIAlertController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(animated);
}
%end

// 4. Trang vuốt trượt từ dưới lên (Sheet / Modal) bung mượt như 120Hz
%hook UIPresentationController
- (void)presentationTransitionWillBegin {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (void)dismissalTransitionWillBegin {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 14: CAN THIỆP TẦNG SÂU NỘI BỘ APPLE (BACKBOARD HID, MACH WORKLOOP & IOKIT VOLTAGE BURST)
// ====================================================================================================

%group Group_Apple_DeepInternal_SubsystemV285

// 1. BACKBOARDSERVICES: BẮT SỰ KIỆN CẢM ỨNG TRƯỚC KHI TRUYỀN VÀO SPRINGBOARD (TRIỆT TIÊU 100% ĐỘ TRỄ HID)
%hook BKSHIDEventDeliveryManager
- (void)dispatchDiscreteEvents:(id)events {
    if (IS_ACTIVE) {
        // Kích xung Mach ngay tầng BackBoard trước khi truyền đến UIWindow
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(events);
}
%end

// 4. KÍCH HOẠT IOKIT POWER ASSERTION: ÉP PHẦN CỨNG GIỮ NGUYÊN ĐIỆN ÁP ĐỈNH KHI THAO TÁC
%hook SBBacklightController
- (void)animateBacklightToFactor:(float)factor duration:(double)duration source:(long long)source completion:(id)completion {
    if (IS_ACTIVE) {
        // Khi mở màn hình hoặc sáng đèn nền: Đẩy xung Mach tức thì để giao diện xuất hiện không một vết gợn
        Titanium_StealthKernelHijack();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(factor, duration, source, completion);
}
%end

%end // KẾT THÚC %group Group_Apple_DeepInternal_SubsystemV285

// ====================================================================================================
// GIÁM SÁT SẠC PIN (CHỐNG NÓNG MÁY KHI CẮM SẠC)
// ====================================================================================================

static void Titanium_StartThermalAndChargingWatchdog(void) {
    static dispatch_source_t s_batteryTimer = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_t bQueue = dispatch_queue_create("com.titanium.batterywatchdog", DISPATCH_QUEUE_SERIAL);
        s_batteryTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, bQueue);
        dispatch_source_set_timer(s_batteryTimer, dispatch_time(DISPATCH_TIME_NOW, 0), (int64_t)(5.0 * NSEC_PER_SEC), (int64_t)(1.0 * NSEC_PER_SEC));
        dispatch_source_set_event_handler(s_batteryTimer, ^{
            dispatch_async(dispatch_get_main_queue(), ^{
                UIDevice *dev = [UIDevice currentDevice];
                if (!dev.isBatteryMonitoringEnabled) dev.batteryMonitoringEnabled = YES;
                g_isDeviceChargingV285 = (dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull);
            });
        });
        dispatch_resume(s_batteryTimer);
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
// CƠ CHẾ ĐIỀU PHỐI KHỞI ĐỘNG THÔNG MINH
// 6S-7P: TỰ ĐỘNG RESPRING LIÊN TỤC CHO ĐẾN KHI NẠP ĐƯỢC TWEAK THÌ DỪNG NGAY
// 8P-15PRM: CHỈ KHI REBOOT NGUỒN, NẾU CHƯA NẠP TWEAK SẼ RESPRING ĐÚNG 1 LẦN
// ====================================================================================================

#define TITANIUM_BOOT_FLAG_VERIFIED @"/tmp/.titanium_tweak_verified"
#define TITANIUM_BOOT_STAGE_8P      @"/tmp/.titanium_8p_reboot_staged"

// 1. Phân loại chuẩn xác dòng 6s - 7 Plus (A9 - A10)
static inline BOOL Titanium_IsLegacy6s7P(void) {
    static BOOL s_isLegacy = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        uname(&sysInfo);
        NSString *machine = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        // iPhone 6s, 6s+, SE 1 (iPhone8,x), iPhone 7, 7+ (iPhone9,x)
        if ([machine hasPrefix:@"iPhone8,"] || [machine hasPrefix:@"iPhone9,"]) {
            s_isLegacy = YES;
        }
    });
    return s_isLegacy;
}

// 2. Đo thời gian hệ thống hoạt động từ lúc bật nguồn (Uptime)
static time_t Titanium_GetSystemUptimeSeconds(void) {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) < 0) return 9999;
    time_t now = time(NULL);
    return (now - boottime.tv_sec);
}

// 3. Thực hiện lệnh Respring hệ thống an toàn
static void Titanium_ExecuteSystemRespring(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(_relaunchSpringBoardNow)]) {
        [(SpringBoard *)app _relaunchSpringBoardNow];
        return;
    }

    pid_t pid;
    const char *args[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)args, environ);
}

// ====================================================================================================
// RUNTIME INITIALIZER: ĐIỀU PHỐI TẦNG NỘI BỘ & KHỞI CHẠY TWEAK
// ====================================================================================================

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    @autoreleasepool {
        AppleInternal_EnforceZeroLatencyKernelTier();
        AppleInternal_LockHardwareCADisplay();
        Titanium_LockMainThreadFast();

        if (Titanium_IsLegacyA9toA12()) {
            Titanium_ElevateThreadToMachRealTime();
            Titanium_ApplySiliconDeepOptimizations();
            Titanium_EnableZeroLatencyPipeline();
            Titanium_EnforceThreadVIPPolicy();
        }

        Class configClass = NSClassFromString(@"BoostConfigV285Pro");
        if (configClass) {
            CFG285 = [configClass sharedInstance];
            [CFG285 loadSettings];
        }

        %init(Group_ZeroLatency_Touch_Opt);
        %init(Group_Metal_ZeroTearing_Pacing);
        %init(Group_FluidTransitions_Pacing);
        %init(Group_FastLaunch_SuperEngineV285);
        %init(Group_Scroll_And_Keyboard_Opt);
        %init(Group_InstantActionAndMenuTransitions_Boost);
        %init(Group_Global_Thread_Governor_Unthrottled);

        // KÍCH HOẠT HIỆU ỨNG TRONG APP (POPUP, SHEET, CONTEXT MENU)
        %init(Group_Universal_InApp_Animations);

        if (Titanium_IsClassicHomeButtonDevice()) {
            %init(Group_HardwareSegregation_ClassicHomeV285);
        }

         if (isSpringBoard) {
            Titanium_TuneWindowServerDisplayDirectly();
            %init(Group_Switcher30Apps_Virtualization);
            %init(Group_Display_SpringBoardV285);
            %init(Group_V285_FloatingWindow_PiP); 
            %init(Group_SpringBoard_ProcessManagerV285);
            %init(Group_Apple_DeepInternal_SubsystemV285);

            Titanium_StartThermalAndChargingWatchdog();

            // ĐÁNH DẤU TWEAK ĐÃ NẠP THÀNH CÔNG HOÀN TOÀN
            [@"VERIFIED" writeToFile:TITANIUM_BOOT_FLAG_VERIFIED atomically:YES encoding:NSUTF8StringEncoding error:nil];
            chmod([TITANIUM_BOOT_FLAG_VERIFIED UTF8String], 0666);
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
}

// ====================================================================================================
// CALLBACK KÍCH HOẠT KHI SPRINGBOARD KHỞI CHẠY (BẢO VỆ CỜ BOOT & CƯỚP QUYỀN AN TOÀN)
// ====================================================================================================

static void SpringBoardDidLaunchCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            const char *progName = getprogname();
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSFileManager *fm = [NSFileManager defaultManager];
            BOOL isVerified = [fm fileExistsAtPath:TITANIUM_BOOT_FLAG_VERIFIED];

            // 1. Tinh chỉnh WindowServer và cướp quyền P-Core ngay khi SpringBoard sẵn sàng
            Titanium_TuneWindowServerDisplayDirectly();
            Titanium_StealthKernelHijack();
            Titanium_EnableZeroLatencyPipeline();

            // =========================================================================
            // NHÁNH 1: IPHONE 6S - 7 PLUS (COLD REBOOT & USERSPACE REBOOT)
            // =========================================================================
            if (Titanium_IsLegacy6s7P()) {
                if (isVerified) {
                    // Đã qua bước respring an toàn -> NẠP TWEAK VÀ DỪNG VÒNG LẶP
                    runCoreTweak(YES, bundleID ? bundleID : @"com.apple.springboard", progName);
                    return;
                }

                // Lần đầu khởi động lên (chưa có cờ verified): Đợi 2.2 giây rồi Respring tự động
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (![fm fileExistsAtPath:TITANIUM_BOOT_FLAG_VERIFIED]) {
                        [fm createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED contents:nil attributes:nil];
                        Titanium_ExecuteSystemRespring();
                    }
                });
                return;
            }

            // =========================================================================
            // NHÁNH 2: IPHONE 8 PLUS - 15 PRO MAX (CHỈ XỬ LÝ KHI REBOOT NGUỒN)
            // =========================================================================
            time_t uptime = Titanium_GetSystemUptimeSeconds();
            BOOL isColdBoot = (uptime < 60);

            if (isColdBoot) {
                BOOL alreadyStaged = [fm fileExistsAtPath:TITANIUM_BOOT_STAGE_8P];
                
                // Chưa từng respring trong đợt reboot này -> Chờ màn hình lên rồi Respring đúng 1 lần
                if (!alreadyStaged) {
                    [@"STAGED" writeToFile:TITANIUM_BOOT_STAGE_8P atomically:YES encoding:NSUTF8StringEncoding error:nil];
                    chmod([TITANIUM_BOOT_STAGE_8P UTF8String], 0666);

                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        Titanium_ExecuteSystemRespring();
                    });
                    return;
                }
            }

            // ĐÃ QUA RESPRING HOẶC HOẠT ĐỘNG BÌNH THƯỜNG: NẠP TWEAK (CHỈ GỌI 1 LẦN DUY NHẤT)
            runCoreTweak(YES, bundleID ? bundleID : @"com.apple.springboard", progName);
        });
    });
}

// ====================================================================================================
// CONSTRUCTOR KHỞI ĐỘNG TỐC ĐỘ CAO (CÁCH LY WEB/MẠNG TRIỆT ĐỂ, KHÔNG ĐEN APP, KHÔNG TREO TÁO)
// ====================================================================================================

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        // 1. CÁCH LY TUYỆT ĐỐI SÓNG SIM, VIỄN THÔNG, MẠNG & WEBKIT
                // CÁCH LY TUYỆT ĐỐI DAEMONS MẠNG, WI-FI, SÓNG SIM & WEBKIT
        if (strstr(progName, "WebKit") || 
            strstr(progName, "WebContent") || 
            strstr(progName, "GPUProcess") || 
            strstr(progName, "Networking") || 
            strstr(progName, "webpushd") || 
            strstr(progName, "CommCenter") || 
            strstr(progName, "telephony") || 
            strstr(progName, "wifid") || 
            strstr(progName, "wirelessproxd") || 
            strcmp(progName, "nsurlsessiond") == 0 || 
            strcmp(progName, "mDNSResponder") == 0 || 
            strcmp(progName, "networkd") == 0 || 
            strcmp(progName, "cfnetwork") == 0 ||
            strcmp(progName, "symptomsd") == 0) { 
            return; 
        }

        // 2. BỎ QUA CÁC TIẾN TRÌNH HỆ THỐNG NGẦM
        if (strstr(progName, "jailbreakd") || strstr(progName, "launchd") ||
            strstr(progName, "containermanagerd") || strstr(progName, "cfprefsd") ||
            strstr(progName, "watchdogd") || strstr(progName, "mediaserverd") ||
            strstr(progName, "installd") || strstr(progName, "logd") ||
            strstr(progName, "analyticsd") || strstr(progName, "symptomsd") ||
            strstr(progName, "powerd") || strstr(progName, "backboardd") ||
            strstr(progName, "notifyd") || strstr(progName, "securityd")) {
            return;
        }

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];

        if (bundleID && ([bundleID containsString:@"WebKit"] || 
                         [bundleID containsString:@"com.apple.WebKit"] ||
                         [bundleID containsString:@"com.apple.telephony"])) {
            return;
        }

        BOOL isSpringBoard = (bundleID && [bundleID isEqualToString:@"com.apple.springboard"]) || 
                             (strcmp(progName, "SpringBoard") == 0);

        // 3. CHỈ KIỂM TRA BOOTGUARD TRÊN TIẾN TRÌNH SPRINGBOARD
        if (isSpringBoard) {
            if (!Titanium_CheckAndPreventBootloopUniversal()) return;
            // CHỈ NÂNG QOS RIÊNG CHO SPRINGBOARD ĐỂ KHÔNG TRANH CHẤP VỚI SÓNG SIM HAY APP KHÁC
            setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
            setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }

        // 4. NẠP CẤU HÌNH CHO CÀI ĐẶT
        if (strstr(progName, "Preferences") || strstr(progName, "Settings")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
            }
            return;
        }

        // 5. TỐI ƯU HÓA I/O & NÂNG QOS CHO SPRINGBOARD / APP THƯỜNG
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

        %init;

        // 6. PHÂN LUỒNG SPRINGBOARD VS ỨNG DỤNG NGƯỜI DÙNG
        if (isSpringBoard) {
            // Đăng ký nhận thông báo SpringBoard qua Darwin Center chuẩn của iOS
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetDarwinNotifyCenter(),
                NULL,
                SpringBoardDidLaunchCallback,
                CFSTR("SBSpringBoardDidLaunchNotification"),
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
        } else {
            // App Sandbox bên thứ ba (TikTok, Facebook, Game...): Nạp core trực tiếp
            runCoreTweak(NO, bundleID, progName);
        }
    }
}
