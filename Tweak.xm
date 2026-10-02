// ==================== MACH KERNEL ====================
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
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>
#import <IOKit/IOKitLib.h>

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
- (void)textChanged:(id)1;
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
@end

@interface SBUIAnimationController : NSObject
@end

@interface UIInputViewAnimationStyle : NSObject
@property (nonatomic, assign) double duration;
@property (nonatomic, assign) BOOL animated;
@end

@interface SBAppToHomeWorkspaceTransaction : NSObject
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
    NSArray *displays = [server displays];
    if (displays && displays.count > 0) {
        CAWindowServerDisplay *mainDisp = displays[0];
        
        NSInteger currentHz = CFG285 ? [CFG285 resolvedTargetHz] : 60;
        if (currentHz <= 0) currentHz = 60;
        double minDuration = 1.0 / (double)currentHz;

        if ([mainDisp respondsToSelector:@selector(setMinimumFrameDuration:)]) {
            [mainDisp setMinimumFrameDuration:minDuration];
        }
        if ([mainDisp respondsToSelector:@selector(setAllowsVirtualModes:)]) {
            [mainDisp setAllowsVirtualModes:YES];
        }
        if ([mainDisp respondsToSelector:@selector(setAllowsDisplayCompositing:)]) {
            [mainDisp setAllowsDisplayCompositing:YES];
        }
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
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    struct sched_param param;
    param.sched_priority = 47;
    pthread_setschedparam(pthread_self(), SCHED_RR, &param);
}

static void Titanium_TriggerInstantTouchBurst(void) {
    g_isUserTouchingScreen = YES;
    Titanium_LockMainThreadFast();

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

// ====================================================================================================
// NHÓM 1: CẢM ỨNG 0MS & CHỐNG RUNG CHỮ KHI MỞ APP (ĐÃ TỐI ƯU TOÀN DIỆN)
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

// 1. TRIỆT TIÊU ĐỘ TRỄ NHẬN DIỆN CỬ CHỈ GESTURE
%hook UIGestureRecognizer
- (BOOL)delaysTouchesBegan {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return NO;
    return %orig;
}

- (BOOL)delaysTouchesEnded {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return NO;
    return %orig;
}

- (void)setDelaysTouchesBegan:(BOOL)flag {
    BOOL actualFlag = (IS_ACTIVE && CFG285.touchResponseBoost) ? NO : flag;
    %orig(actualFlag);
}

- (void)setDelaysTouchesEnded:(BOOL)flag {
    BOOL actualFlag = (IS_ACTIVE && CFG285.touchResponseBoost) ? NO : flag;
    %orig(actualFlag);
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
    if (IS_ACTIVE) {
        // Chỉ làm tròn nếu toạ độ bị lẻ thập phân, tránh tính toán thừa trong feed dài
        if (frame.origin.x != floorf(frame.origin.x) || frame.origin.y != floorf(frame.origin.y)) {
            frame = CGRectIntegral(frame);
        }
    }
    %orig(frame);
}

- (void)setBounds:(CGRect)bounds {
    if (IS_ACTIVE) {
        if (bounds.origin.x != floorf(bounds.origin.x) || bounds.origin.y != floorf(bounds.origin.y)) {
            bounds = CGRectIntegral(bounds);
        }
    }
    %orig(bounds);
}
%end

// 4. ĐÓN ĐẦU CHẠM TOÀN MÀN HÌNH TẠI CỬA SỔ GỐC (0MS BURST)
%hook UIWindow
- (BOOL)_shouldDelayTouchForCancelEvents {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return NO;
    return %orig;
}

- (void)sendEvent:(UIEvent *)event {
    // 0 = UIEventTypeTouches: Đón đầu ngay khi ngón tay vừa chạm vào kính cảm ứng
    if (IS_ACTIVE && CFG285.touchResponseBoost && event.type == 0) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(event);
}
%end

%end

// ====================================================================================================
// NHÓM 2: METAL GRAPHICS, TRIPLE BUFFERING & KHÓA CHỐNG RUNG LAYER
// ====================================================================================================

%group Group_Metal_ZeroTearing_Pacing

%hook CAMetalLayer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if (IS_ACTIVE && CFG285.metalHexBuffering) {
        count = 3;
    }
    %orig(count);
}

- (NSUInteger)maximumDrawableCount {
    if (IS_ACTIVE && CFG285.metalHexBuffering) return 3;
    return %orig;
}

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if (IS_ACTIVE) enabled = YES;
    %orig(enabled);
}

- (void)setLowLatencyMode:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
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

// Khóa vị trí layer thành số nguyên để chống rung khi phóng to/thu nhỏ icon
- (void)setPosition:(CGPoint)position {
    if (IS_ACTIVE) {
        position.x = round(position.x);
        position.y = round(position.y);
    }
    %orig(position);
}
%end

%hook CAContext
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

// ====================================================================================================
// MODULE ĐIỀU TẦN PROMOTION 120HZ THÔNG MINH (15HZ TĨNH <---> 120HZ CHUYỂN ĐỘNG / VIDEO / CUỘN FEED)
// ====================================================================================================

#import <AVFoundation/AVFoundation.h>

// Quản lý biến an toàn đa luồng cho hoạt ảnh, video, cuộn trang và thông báo
static volatile int32_t g_activeAnimationCount = 0;
static volatile BOOL g_isScrollingActive = NO; // Cờ giữ trần 120Hz/60Hz khi đang cuộn hoặc trôi quán tính
static volatile BOOL g_isVideoPlayingActive = NO;
static volatile BOOL g_isNotificationBannerActive = NO;
static dispatch_source_t g_bannerBurstTimer = nil;
static dispatch_queue_t g_bannerBurstQueue = nil;

// Kích xung nhịp CPU/GPU cực đại 120Hz tức thì 0ms khi có thông báo xuất hiện
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

    // Giữ trần 120FPS trong 650ms để banner trượt xuống mượt mà không khựng 1 khung hình
    g_bannerBurstTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, g_bannerBurstQueue);
    dispatch_source_set_timer(g_bannerBurstTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(650 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(g_bannerBurstTimer, ^{
        g_isNotificationBannerActive = NO;
        g_bannerBurstTimer = nil;
    });
    dispatch_resume(g_bannerBurstTimer);
}

// Bộ lọc điều kiện: Nhận diện chính xác trạng thái hoạt động thực tế
static inline BOOL Titanium_ShouldKeepMax120FPS(NSInteger requestedFPS) {
    if (g_isUserTouchingScreen) return YES;         // 1. Chạm tay vuốt màn hình
    if (g_isScrollingActive) return YES;            // 2. Đang cuộn feed hoặc trôi quán tính (TikTok, FB, Safari)
    if (g_isNotificationBannerActive) return YES;   // 3. Banner thông báo đang bay ra
    if (g_isVideoPlayingActive) return YES;         // 4. Đang phát video hoặc PiP
    if (g_activeAnimationCount > 0) return YES;     // 5. Có hoạt ảnh chuyển động trên màn hình
    // Sửa lỗi: 0 là giá trị mặc định của Apple CADisplayLink yêu cầu max rate, >= 30 là app yêu cầu fps cao
    if (requestedFPS >= 30 || requestedFPS == 0) return YES; 
    return NO; // Màn hình tĩnh 100% -> Tự động hạ sâu về 15Hz để máy mát lạnh
}

// ====================================================================================================
// NHÓM 3: DISPLAY REFRESH CADENCE & PROMOTION PACING (15HZ - 120HZ)
// ====================================================================================================

%group Group_FluidTransitions_Pacing

// 1. TỰ ĐỘNG ĐIỀU TẦN QUÉT MÀN HÌNH (15HZ TĨNH <---> 120HZ CHUYỂN ĐỘNG)
%hook CADisplayLink

- (NSInteger)preferredFramesPerSecond {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        if (Titanium_ShouldKeepMax120FPS(%orig)) {
            return 120; // Đẩy thẳng 120 FPS mượt mà
        }
        return 15; // Màn hình tĩnh 100%: Hạ về 15 FPS triệt tiêu nhiệt độ
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        if (Titanium_ShouldKeepMax120FPS(fps)) {
            %orig(120);
            return;
        }
        %orig(15);
        return;
    }
    %orig(fps);
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE && CFG285.enableHzControl) {
            if (Titanium_ShouldKeepMax120FPS(30)) {
                // Min 60Hz, Target 120Hz, Max 120Hz chuẩn ProMotion
                range = SafeMakeFRR(60.0f, 120.0f, 120.0f);
            } else {
                // Màn hình tĩnh: Sàn 15Hz, Trần sẵn sàng vọt lên 120Hz trong 0ms
                range = SafeMakeFRR(15.0f, 15.0f, 120.0f);
            }
            Titanium_EnableZeroLatencyPipeline();
        }
    }
    %orig(range);
}

- (void)setFrameInterval:(NSInteger)interval {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        interval = 1; // Khóa chu kỳ dựng khung hình dày nhất
    }
    %orig(interval);
}

%end

// 2. KHÓA TẤM NỀN CADISPLAY VÀ BÁO CÁO CÔNG NGHỆ PROMOTION
%hook CADisplay

- (NSInteger)preferredFPS {
    if (!IS_ACTIVE) return %orig;
    return Titanium_ShouldKeepMax120FPS(0) ? 120 : 15;
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (IS_ACTIVE) {
        fps = Titanium_ShouldKeepMax120FPS(fps) ? 120 : 15;
    }
    %orig(fps);
}

- (void)overrideDisplayCadence:(id)cadence {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        cadence = nil;
    }
    %orig(cadence);
}

- (BOOL)supportsDynamicRefresh {
    if (!IS_ACTIVE) return %orig;
    return YES;
}

- (BOOL)hasDynamicDisplayMode {
    if (!IS_ACTIVE) return YES;
    return %orig;
}

%end

// 3. ĐÁNH LỪA UIKIT & CÁC APP ĐO FPS RẰNG MÀN HÌNH LÀ 120HZ PROMOTION
%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (IS_ACTIVE) return 120;
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ACTIVE) return 120;
    return %orig;
}

- (CGFloat)_refreshRate {
    if (IS_ACTIVE) return 120.0;
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
        rate = 120.0;
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(rate);
}

%end

// 4. THEO DÕI HOẠT ẢNH TRÊN MÀN HÌNH (ANIMATION TRACKER AN TOÀN ĐA LUỒNG)
%hook CAAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE) {
            range = SafeMakeFRR(60.0f, 120.0f, 120.0f);
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

// Lò xo quán tính 26Anim luôn được ưu tiên tần số quét 120Hz
%hook CASpringAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE) {
            range = SafeMakeFRR(60.0f, 120.0f, 120.0f);
        }
    }
    %orig(range);
}

%end

// Giảm bộ đếm an toàn khi animation kết thúc (chống âm biến)
%hook CATransaction

+ (void)commit {
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

// 5. TỰ ĐỘNG BẢO TOÀN TRẦN 120HZ XUYÊN SUỐT QUÁ TRÌNH CUỘN TRÔI QUÁN TÍNH
%hook UIScrollView

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE) return YES;
    return %orig(view);
}

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

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        Titanium_LockMainThreadFast();
    }
    %orig(timestamp);
}

- (void)_stopScrollDecelerationNotify:(BOOL)notify {
    %orig(notify);
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
    %orig(view);
    if (IS_ACTIVE && !self.isDecelerating) {
        g_isScrollingActive = NO;
    }
}

%end

// 6. BẢO VỆ NỘI DUNG VIDEO (KHÔNG BAO GIỜ BỊ HẠ VỀ 15HZ)
%hook AVPlayer

- (void)setRate:(float)rate {
    %orig(rate);
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = (rate > 0.0f);
        if (g_isVideoPlayingActive) {
            Titanium_EnableZeroLatencyPipeline();
        }
    }
}

%end

// Khóa trần cho video PiP cửa sổ nổi
%hook PGPictureInPictureRemoteObject

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
    }
    %orig(animated);
}

%end

// 7. TỰ ĐỘNG PHÁT HIỆN THÔNG BÁO XUẤT HIỆN -> ĐẨY 120HZ + MAX CPU TRƯỚC 0MS
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

// 8. TẢI LẠI CẤU HÌNH KHI APP ACTIVE
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

%end

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT (DỨT ĐIỂM MÀN HÌNH ĐEN KHI MỞ APP)
// ====================================================================================================

// Khai báo cờ chống xung đột dọn RAM khi vuốt liên hoàn
static volatile BOOL g_isContinuousSwiping = NO;

%group Group_Switcher30Apps_Virtualization

// ====================================================================================================
// 1. ĐÓN ĐẦU CỬ CHỈ & CHO PHÉP VUỐT LIÊN HOÀN (BẢO TOÀN ĐỘ ĐÀN HỒI LÒ XO 26ANIM)
// ====================================================================================================

// Chạm mép đáy là kích xung 60FPS/120FPS trước 0ms
%hook SBHomeGestureInteraction
- (void)_handleGestureBegan:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = YES;
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(gesture);
}
%end

// Cho phép cử chỉ mới cướp quyền ngay lập tức, vuốt nhanh liên tục không phải chờ cử chỉ cũ
%hook SBFluidSwitcherGestureWorkspaceTransaction
- (BOOL)canInterruptActiveGesture {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)_shouldSuppressGestures {
    if (IS_ACTIVE) return NO;
    return %orig;
}
%end

// ====================================================================================================
// 2. THOÁT APP: CHỈ DỌN RAM KHI ĐÃ DỪNG TAY HẲN (TRIỆT TIÊU GIẬT KHỰNG DO MALLOC PURGE)
// ====================================================================================================

%hook SBAppToHomeWorkspaceTransaction
- (BOOL)shouldAnimateOrientationChangeOnCompletion {
    return NO;
}

- (void)_willBegin {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        dispatch_async(dispatch_get_main_queue(), ^{
            Titanium_EnableZeroLatencyPipeline();
        });

        // Chỉ thu hồi RAM nếu sau 2.0 giây người dùng KHÔNG chạm hoặc vuốt tiếp
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            if (!g_isContinuousSwiping && !g_isUserTouchingScreen) {
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            }
        });
    }
}
%end

// ====================================================================================================
// 3. RENDER LAYOUT BẤT ĐỒNG BỘ (BẢO TOÀN 100% BÓNG ĐỔ VÀ NỀN MỜ CỦA 26ANIM)
// ====================================================================================================

%hook SBFluidSwitcherModifier
// Render layout bất đồng bộ: Mở app tức thì, không bị màn hình đen
- (BOOL)shouldasyncRenderAppLayouts {
    if (IS_ACTIVE) return YES;
    return %orig;
}

// ĐÃ GỠ BỎ: shouldSimplifyForOptions, shadowOpacity, wallpaperOverlayAlpha
// để 26Anim tự do xử lý độ nảy lò xo, bo góc và bóng đổ 3D.
%end

// ====================================================================================================
// 4. QUẢN LÝ BỘ NHỚ ĐỆM SNAPSHOT & VẼ CARD BẤT ĐỒNG BỘ
// ====================================================================================================

%hook SBAppSwitcherSettings
- (BOOL)shouldKeepAppSnapshotsInMemory {
    if (IS_ACTIVE) return YES; // Giữ ảnh chụp tạm thời trong RAM, vuốt nhiều tab không bị nghẽn ổ flash
    return %orig;
}

- (CGFloat)decelerationRate {
    if (IS_ACTIVE) return UIScrollViewDecelerationRateNormal;
    return %orig;
}
%end

%hook SBAppSwitcherController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(animated);
}
%end

%hook SBFluidSwitcherItemContainer
- (void)prepareForReuse {
    %orig;
    if (IS_ACTIVE) {
        UIView *v = (UIView *)self;
        v.layer.drawsAsynchronously = YES;
    }
}
%end

%end

// ====================================================================================================
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC (TURBO ENGINE)
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

%hook FBApplicationProcess
- (void)bootstrapWithContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG285.turboAppLaunch) Titanium_EnforceThreadVIPPolicy();
    %orig(context, completion);
}
- (void)launchIfNecessary {
    if (IS_ACTIVE && CFG285.turboAppLaunch) Titanium_EnforceThreadVIPPolicy();
    %orig;
}
%end

%hook UIApplication
- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG285.turboAppLaunch) Titanium_EnforceThreadVIPPolicy();
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
    if (IS_ACTIVE) return 0.12; // Bàn phím nảy lên lập tức, cực kỳ dứt khoát
    return %orig;
}
%end

%hook UIKeyboardImpl
- (void)showKeyboard {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
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

// 2. ĐÓN ĐẦU CHẠM NÚT 3 GẠCH & NÚT ĐIỀU HƯỚNG (BƠM XUNG TRƯỚC KHI DRAWER TRƯỢT RA)
%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        // Chạm vào nút 3 gạch hoặc nút bấm bất kỳ: Kích 120Hz/60Hz ngay tại 0ms
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(action, target, event);
}
%end

// 3. TĂNG TỐC CHUYỂN QUA LẠI CÁC TAB (UITABBARCONTROLLER) TỨC THÌ
%hook UITabBarController
- (void)setSelectedIndex:(NSUInteger)index {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(index);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
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
        Titanium_LockMainThreadFast();
    }
    %orig(viewController, animated);
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
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

// 5. CUỘN FEED TIKTOK / FACEBOOK / SAFARI TRÔI MƯỢT QUÁN TÍNH
%hook UIScrollView
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE) return YES;
    return %orig(view);
}

- (BOOL)delaysContentTouches {
    if (IS_ACTIVE) return NO;
    return %orig;
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

// Giữ nguyên mức FPS cao xuyên suốt đà trôi tự do sau khi buông tay
- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        Titanium_LockMainThreadFast();
    }
    %orig(timestamp);
}

// Dừng trôi hẳn: Nhả cờ để hệ thống tự hạ về 15Hz làm mát máy
- (void)_stopScrollDecelerationNotify:(BOOL)notify {
    %orig(notify);
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
    if (newWindow && IS_ACTIVE) self.delaysContentTouches = NO;
}
%end

%hook UICollectionView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) self.delaysContentTouches = NO;
}
%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD (TỐI ƯU 26ANIM, ĐÓNG BĂNG 3D THIÊN VĂN, KÉO CC/NC 0MS)
// ====================================================================================================

%group Group_Display_SpringBoardV285

// ====================================================================================================
// 1. KHÓA CỨNG HÌNH NỀN TĨNH & ĐÓNG BĂNG MÔ HÌNH 3D (GIẢI PHÓNG 80% TẢI GPU)
// ====================================================================================================

%hook SBWallpaperController
- (double)wallpaperScaleForVariant:(long long)variant {
    if (IS_ACTIVE) return 1.0;
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

// Bấm chạm icon là nảy hiệu ứng và kích 120Hz/60Hz ngay tại 0ms
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
// 3. TỐI ƯU CỬ CHỈ ĐA NHIỆM SPRINGBOARD (ĐÃ XÓA CÁC HOOK TRÙNG VỚI GROUP SWITCHER VÀ GIỮ NGUYÊN 26ANIM)
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

// ĐÃ GỠ BỎ: SBHomeGestureSettings (homeGestureDelayDuration) để 26Anim tính vector gia tốc văng chuẩn xác!
// ĐÃ GỠ BỎ: SBFluidSwitcherGestureWorkspaceTransaction, SBHomeGestureInteraction, SBAppToHomeWorkspaceTransaction
// (Các hook này đã nằm trọn vẹn và an toàn trong Group_Switcher30Apps_Virtualization, tránh xung đột kép)

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
// Cho phép vuốt là trang trượt đi ngay lập tức
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE) return YES;
    return %orig;
}

// BẮT BUỘC ĐỂ YES: Không cho icon dưới ngón tay nhận lệnh chạm khi đang quẹt ngang
- (BOOL)delaysContentTouches {
    return YES;
}

// Duy trì xung nhịp phẳng lỳ xuyên suốt quá trình kéo trang
- (void)_notifyDidScroll {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

// Khóa ưu tiên luồng chính khi trang đang trong đà trôi tự động về vị trí dừng
- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        Titanium_LockMainThreadFast();
    }
    %orig(timestamp);
}
%end

// Làm phẳng độ trong suốt của danh sách icon, giải phóng GPU khi chuyển trang
%hook SBIconListView
- (void)setAlpha:(CGFloat)alpha {
    %orig(alpha);
    if (IS_ACTIVE) {
        UIView *v = (UIView *)self;
        v.layer.allowsGroupOpacity = YES;
    }
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
// 7. CÁC TIỆN ÍCH KHÁC CỦA SPRINGBOARD
// ====================================================================================================

%hook SBFolderControllerAnimationSettings
- (double)duration {
    return %orig;
}
%end

%hook SBIconForceTouchSettings
- (double)delayBeforeOpening {
    if (IS_ACTIVE) return 0.10;
    return %orig;
}
%end

// ====================================================================================================
// 8. ÉP TỐC ĐỘ LOAD APP SIÊU TỐC & TRIỆT TIÊU ĐỘ TRỄ MỞ ỨNG DỤNG (ULTRA-FAST LAUNCH)
// ====================================================================================================

// Bơm xung CPU/GPU cực đại ngay khoảnh khắc chạm icon mở app
%hook SBApplication
- (void)willActivate {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

- (BOOL)shouldPrewarmOnLaunch {
    if (IS_ACTIVE) return YES;
    return %orig;
}
%end

// Rút ngắn thời gian phóng to icon từ 450ms xuống 180ms để app bật lên tức thì
%hook SBAppLaunchSettings
- (double)zoomDuration {
    if (IS_ACTIVE) return 0.18;
    return %orig;
}

- (double)launchDuration {
    if (IS_ACTIVE) return 0.20;
    return %orig;
}

- (double)delayBeforeAppLaunch {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}
%end

// Bỏ qua thời gian dừng chờ màn hình trắng/splash screen
%hook SBSplashBoardController
- (double)splashScreenDelay {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}
%end

// Ưu tiên luồng dựng hình ngay khi bắt đầu hoạt ảnh mở app
%hook SBUIAnimationController
- (void)_willBeginAnimation {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
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
    if (IS_ACTIVE) Titanium_LockMainThreadFast();
    %orig;
}
- (void)stopPictureInPictureAnimated:(BOOL)animated {
    if (IS_ACTIVE) Titanium_LockMainThreadFast();
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
// NHÓM 9: PHÂN TÁCH PHẦN CỨNG (HOME BUTTON VẬT LÝ & VUỐT HIỆN ĐẠI)
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

%group Group_HardwareSegregation_ModernGesturesV285

%hook SBFluidSwitcherViewController
- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(gesture);
}
%end

%end

// ====================================================================================================
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH & BẢO VỆ JETSAM
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

%hook SBApplication
- (void)setProcessState:(id)state {
    if (IS_ACTIVE) Titanium_LockMainThreadFast();
    %orig(state);
}
%end

%hook SBMainWorkspace
- (void)handleApplicationLaunch:(id)application {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(application);
}
%end

%end

// ====================================================================================================
// NHÓM 11: NÂNG CẤP TOÀN BỘ ỨNG DỤNG BÊN THỨ BA (TIKTOK, ZALO, TỆP, APP STORE)
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

// 1. KÍCH XUNG KHI CỬA SỔ CHÍNH ĐƯỢC KÍCH HOẠT
%hook UIWindow
- (void)makeKeyAndVisible {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

// ĐÃ GỠ BỎ sendEvent: để tránh kích xung kép (đã do Group_ZeroLatency_Touch_Opt đảm nhiệm)
%end

// 2. ƯU TIÊN LUỒNG CAO NHẤT KHI NẠP VIEW CONTROLLER CỦA APP BÊN THỨ BA
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_LockMainThreadFast();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(animated);
}

- (void)viewDidLoad {
    if (IS_ACTIVE) {
        Titanium_LockMainThreadFast();
    }
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 12: BÀN PHÍM STREAM TEXT & CẢM ỨNG NÚT BẤM
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

%hook UIKeyboardTaskQueue
- (void)performTask:(id)task {
    if (IS_ACTIVE) Titanium_LockMainThreadFast();
    %orig(task);
}
%end

%hook UIKeyboardImpl
- (void)callShowKeyboard {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
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
    if (IS_ACTIVE) Titanium_TriggerInstantTouchBurst();
    %orig(touches, event);
}
%end

%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (IS_ACTIVE) Titanium_TriggerInstantTouchBurst();
    %orig(action, target, event);
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

%hook UINavigationController
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(viewController, animated);
}
%end

%hook UITabBarController
- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(selectedViewController);
}
%end

%end

// ====================================================================================================
// NHÓM 13: KHÓA CỨNG TRẦN 60.00 FPS & CHẶN BÓP XUNG NHIỆT ĐỘ APPLE
// ====================================================================================================

%group Group_Global_Thread_Governor_Unthrottled

%hook RBSProcessState
- (unsigned char)taskState {
    if (IS_ACTIVE) return 4;
    return %orig;
}
%end

%hook FBProcess
- (BOOL)isPendingExit {
    return NO;
}
%end

%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ACTIVE) return NSProcessInfoThermalStateNominal;
    return %orig;
}

- (BOOL)isLowPowerModeEnabled {
    if (IS_ACTIVE) return NO;
    return %orig;
}
%end

%hook NSNotificationCenter
- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo {
    if (IS_ACTIVE && aName) {
        if ([aName isEqualToString:NSProcessInfoThermalStateDidChangeNotification]) {
            return;
        }
    }
    %orig(aName, anObject, aUserInfo);
}
%end

%hook UIGestureRecognizer
- (BOOL)delaysTouchesBegan {
    if (IS_ACTIVE) return NO;
    return %orig;
}

- (BOOL)delaysTouchesEnded {
    if (IS_ACTIVE) return NO;
    return %orig;
}
%end

%end

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

        if (Titanium_IsClassicHomeButtonDevice()) {
            %init(Group_HardwareSegregation_ClassicHomeV285);
        } else {
            %init(Group_HardwareSegregation_ModernGesturesV285);
        }

        if (isSpringBoard) {
            Titanium_TuneWindowServerDisplayDirectly();
            %init(Group_Switcher30Apps_Virtualization);
            %init(Group_Display_SpringBoardV285);
            %init(Group_V285_FloatingWindow_PiP);
            %init(Group_SpringBoard_ProcessManagerV285);
            Titanium_StartThermalAndChargingWatchdog();
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

static void SpringBoardDidLaunchCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            const char *progName = getprogname();
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            runCoreTweak(YES, bundleID, progName);
        });
    });
}

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        if (strstr(progName, "WebKit") || strstr(progName, "WebContent") ||
            strstr(progName, "GPUProcess") || strstr(progName, "Networking")) {
            return;
        }

        if (strstr(progName, "jailbreakd") || strstr(progName, "launchd") ||
            strstr(progName, "containermanagerd") || strstr(progName, "cfprefsd") ||
            strstr(progName, "watchdogd") || strstr(progName, "mediaserverd") ||
            strstr(progName, "installd") || strstr(progName, "logd") ||
            strstr(progName, "analyticsd") || strstr(progName, "symptomsd") ||
            strstr(progName, "powerd") || strstr(progName, "backboardd") ||
            strstr(progName, "notifyd") || strstr(progName, "securityd")) {
            return;
        }

        if (!Titanium_CheckAndPreventBootloopUniversal()) return;

        if (strstr(progName, "Preferences") || strstr(progName, "Settings")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
            }
            return;
        }

        %init;

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];
        BOOL isSpringBoard = bundleID && [bundleID isEqualToString:@"com.apple.springboard"];

        if (isSpringBoard) {
            CFNotificationCenterAddObserver(
                CFNotificationCenterGetLocalCenter(),
                NULL,
                SpringBoardDidLaunchCallback,
                (CFStringRef)UIApplicationDidFinishLaunchingNotification,
                NULL,
                CFNotificationSuspensionBehaviorDeliverImmediately
            );
        } else {
            runCoreTweak(NO, bundleID, progName);
        }
    }
}
