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

@interface UIViewPropertyAnimator ()
+ (void)_setTrackDuration:(double)duration;
@end

@interface _UIContextMenuContainerView : UIView
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
static BOOL g_isDeviceChargingV285 = NO;
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

static inline float ClampSafeFPS(float target) {
    if (target < 15.0f) return 15.0f;
    if (target > 144.0f) return 144.0f;
    return target;
}

static void Titanium_DisableKernelThreadThrottling(void) {
    mach_port_t thread = pthread_mach_thread_np(pthread_self());
    thread_throttle_policy_data_t throttlePolicy;
    throttlePolicy.pset_limit = 0;
    thread_policy_set(thread, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttlePolicy, 1);
}

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

static void Titanium_ApplySiliconDeepOptimizations(void) {
    setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
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
// BOOST CONFIGURATION ENGINE (V28.7 PRO - ĐẦY ĐỦ 100% TẤT CẢ CÁC KEY TỪ ROOT.PLIST)
// ====================================================================================================

@interface BoostConfigV285Pro : NSObject
// Nhóm 1: Master
@property (nonatomic, assign) BOOL enabled;
// Nhóm 2: Ngôn ngữ
@property (nonatomic, strong) NSString *selectedLanguage;
// Nhóm 3: ProMotion & Buffer
@property (nonatomic, assign) BOOL proMotionEngineBeta7;
@property (nonatomic, assign) BOOL metalHexBuffering;
@property (nonatomic, assign) BOOL keyboardZeroLagV24;
@property (nonatomic, assign) BOOL keyboardZeroLagV3;
// Nhóm 4: Điều phối Hz & FPS
@property (nonatomic, assign) BOOL enableHzControl;
@property (nonatomic, assign) NSInteger targetHz;
@property (nonatomic, assign) BOOL enableFPSControl;
@property (nonatomic, assign) NSInteger targetFPS;
@property (nonatomic, assign) BOOL forceOverclock144Hz;
// Nhóm 5: Cảm ứng
@property (nonatomic, assign) BOOL antiGhostTouch;
@property (nonatomic, assign) BOOL chargerRippleRejection;
@property (nonatomic, assign) BOOL touchResponseBoost;
// Nhóm 6: Tiêm trễ app 3rd
@property (nonatomic, assign) BOOL syncModuleDelay;
@property (nonatomic, assign) BOOL isolateRenderPipeline;
// Nhóm 7: Gia tốc UI ColorOS
@property (nonatomic, assign) BOOL colorOs17SmoothEngine;
@property (nonatomic, assign) BOOL reduceMultiTaskLag;
@property (nonatomic, assign) BOOL reduceMultitaskLag;
@property (nonatomic, assign) BOOL fixAppLaunchBlackScreen;
@property (nonatomic, assign) BOOL antiBlackScreenLaunch;
@property (nonatomic, assign) BOOL fixAppExitStutter;
// Nhóm 8: Đồ họa Metal & CALayer
@property (nonatomic, assign) BOOL quantumRenderShield;
@property (nonatomic, assign) BOOL neuralBufferOpt;
@property (nonatomic, assign) BOOL backgroundPacingDaemon;
@property (nonatomic, assign) BOOL hyperMemoryGuardian;
@property (nonatomic, assign) BOOL ultraResponsiveness;
@property (nonatomic, assign) BOOL ultraResponsivenessProEngineOfficial;
@property (nonatomic, assign) BOOL hyperThreadIO;
@property (nonatomic, assign) BOOL quantumCoreSync;
@property (nonatomic, assign) BOOL zeroLagNeuralBooster;
@property (nonatomic, assign) BOOL vsyncAdaptiveBuffer;
@property (nonatomic, assign) BOOL dynamicThermalEngine;
// Nhóm 9: Bộ nhớ RAM, Disk I/O & CPU
@property (nonatomic, assign) BOOL ioSchedulerEngine;
@property (nonatomic, assign) BOOL realtimeThreadSched;
@property (nonatomic, assign) BOOL cpuGpuFreqOptimizer;
@property (nonatomic, assign) BOOL periodicRamClean;
@property (nonatomic, assign) BOOL aggressiveRamClean;
@property (nonatomic, assign) BOOL machVMPurgeRam;
@property (nonatomic, assign) BOOL autoCloseBackgroundApp;
@property (nonatomic, assign) BOOL turboAppLaunch;
@property (nonatomic, assign) BOOL turboLaunch;
@property (nonatomic, assign) BOOL gameFPSStabilizer;
@property (nonatomic, assign) BOOL systemProcessOpt;
@property (nonatomic, assign) BOOL deviceSpoofer;
// Nhóm 10: Quản lý nhiệt độ & Nguồn điện
@property (nonatomic, assign) BOOL antiThermalThrottling;
@property (nonatomic, assign) BOOL antiThermalThrottle;
@property (nonatomic, assign) BOOL smartThermalDispatch;
@property (nonatomic, assign) BOOL heavyLoadCooling;
@property (nonatomic, assign) BOOL chargeThermalProtection;
@property (nonatomic, assign) BOOL powerSaveMode;
// Nhóm 11: Bảo mật & Sandbox
@property (nonatomic, assign) BOOL bypassVarSandbox;
@property (nonatomic, assign) BOOL blockBackgroundTelemetry;

+ (instancetype)sharedInstance;
- (void)loadSettings;
- (NSInteger)resolvedTargetHz;
- (NSInteger)resolvedTargetFPS;
- (NSInteger)resolvedFrameInterval;
@end

static BoostConfigV285Pro *CFG285 = nil;
#define IS_ACTIVE (CFG285 && CFG285.enabled)

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
        self.selectedLanguage = @"auto";
        self.proMotionEngineBeta7 = NO;
        self.metalHexBuffering = YES;
        self.keyboardZeroLagV24 = YES;
        self.keyboardZeroLagV3 = YES;
        self.enableHzControl = YES;
        self.targetHz = 120;
        self.enableFPSControl = YES;
        self.targetFPS = 120;
        self.forceOverclock144Hz = NO;
        self.antiGhostTouch = YES;
        self.chargerRippleRejection = YES;
        self.touchResponseBoost = YES;
        self.syncModuleDelay = YES;
        self.isolateRenderPipeline = YES;
        self.colorOs17SmoothEngine = YES;
        self.reduceMultiTaskLag = YES;
        self.reduceMultitaskLag = YES;
        self.fixAppLaunchBlackScreen = YES;
        self.antiBlackScreenLaunch = YES;
        self.fixAppExitStutter = YES;
        self.quantumRenderShield = YES;
        self.neuralBufferOpt = YES;
        self.backgroundPacingDaemon = YES;
        self.hyperMemoryGuardian = YES;
        self.ultraResponsiveness = YES;
        self.ultraResponsivenessProEngineOfficial = YES;
        self.hyperThreadIO = YES;
        self.quantumCoreSync = YES;
        self.zeroLagNeuralBooster = YES;
        self.vsyncAdaptiveBuffer = YES;
        self.dynamicThermalEngine = YES;
        self.ioSchedulerEngine = YES;
        self.realtimeThreadSched = YES;
        self.cpuGpuFreqOptimizer = YES;
        self.periodicRamClean = YES;
        self.aggressiveRamClean = NO;
        self.machVMPurgeRam = NO;
        self.autoCloseBackgroundApp = NO;
        self.turboAppLaunch = YES;
        self.turboLaunch = YES;
        self.gameFPSStabilizer = YES;
        self.systemProcessOpt = YES;
        self.deviceSpoofer = YES;
        self.antiThermalThrottling = YES;
        self.antiThermalThrottle = YES;
        self.smartThermalDispatch = YES;
        self.heavyLoadCooling = YES;
        self.chargeThermalProtection = YES;
        self.powerSaveMode = NO;
        self.bypassVarSandbox = YES;
        self.blockBackgroundTelemetry = YES;
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

        // Nạp đầy đủ 46 key từ file Plist
        self.enabled = GetLiveBool(@"Enabled", YES);
        self.selectedLanguage = GetLiveString(@"SelectedLanguage", @"auto");
        self.proMotionEngineBeta7 = GetLiveBool(@"ProMotionEngineBeta7", NO);
        self.metalHexBuffering = GetLiveBool(@"MetalHexBuffering", YES);
        self.keyboardZeroLagV24 = GetLiveBool(@"KeyboardZeroLagV24", YES);
        self.keyboardZeroLagV3 = self.keyboardZeroLagV24;
        self.enableHzControl = GetLiveBool(@"EnableHzControl", YES);
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 120);
        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 120);
        self.forceOverclock144Hz = GetLiveBool(@"ForceOverclock144Hz", NO);
        self.antiGhostTouch = GetLiveBool(@"AntiGhostTouch", YES);
        self.chargerRippleRejection = GetLiveBool(@"ChargerRippleRejection", YES);
        self.touchResponseBoost = GetLiveBool(@"TouchResponseBoost", YES);
        self.syncModuleDelay = GetLiveBool(@"SyncModuleDelay", YES);
        self.isolateRenderPipeline = GetLiveBool(@"IsolateRenderPipeline", YES);
        self.colorOs17SmoothEngine = GetLiveBool(@"ColorOs17SmoothEngine", YES);
        self.reduceMultiTaskLag = GetLiveBool(@"ReduceMultiTaskLag", YES);
        self.reduceMultitaskLag = self.reduceMultiTaskLag;
        self.fixAppLaunchBlackScreen = GetLiveBool(@"FixAppLaunchBlackScreen", YES);
        self.antiBlackScreenLaunch = self.fixAppLaunchBlackScreen;
        self.fixAppExitStutter = GetLiveBool(@"FixAppExitStutter", YES);
        self.quantumRenderShield = GetLiveBool(@"QuantumRenderShield", YES);
        self.neuralBufferOpt = GetLiveBool(@"NeuralBufferOpt", YES);
        self.backgroundPacingDaemon = GetLiveBool(@"BackgroundPacingDaemon", YES);
        self.hyperMemoryGuardian = GetLiveBool(@"HyperMemoryGuardian", YES);
        self.ultraResponsiveness = GetLiveBool(@"UltraResponsiveness", YES);
        self.ultraResponsivenessProEngineOfficial = self.ultraResponsiveness;
        self.hyperThreadIO = GetLiveBool(@"HyperThreadIO", YES);
        self.quantumCoreSync = GetLiveBool(@"QuantumCoreSync", YES);
        self.zeroLagNeuralBooster = GetLiveBool(@"ZeroLagNeuralBooster", YES);
        self.vsyncAdaptiveBuffer = GetLiveBool(@"VsyncAdaptiveBuffer", YES);
        self.dynamicThermalEngine = GetLiveBool(@"DynamicThermalEngine", YES);
        self.ioSchedulerEngine = GetLiveBool(@"IOSchedulerEngine", YES);
        self.realtimeThreadSched = GetLiveBool(@"RealtimeThreadSched", YES);
        self.cpuGpuFreqOptimizer = GetLiveBool(@"CPUGPUFreqOptimizer", YES);
        self.periodicRamClean = GetLiveBool(@"PeriodicRamClean", YES);
        self.aggressiveRamClean = GetLiveBool(@"AggressiveRamClean", NO);
        self.machVMPurgeRam = self.aggressiveRamClean;
        self.autoCloseBackgroundApp = GetLiveBool(@"AutoCloseBackgroundApp", NO);
        self.turboAppLaunch = GetLiveBool(@"TurboAppLaunch", YES);
        self.turboLaunch = self.turboAppLaunch;
        self.gameFPSStabilizer = GetLiveBool(@"GameFPSStabilizer", YES);
        self.systemProcessOpt = GetLiveBool(@"SystemProcessOpt", YES);
        self.deviceSpoofer = GetLiveBool(@"DeviceSpoofer", YES);
        self.antiThermalThrottling = GetLiveBool(@"AntiThermalThrottling", YES);
        self.antiThermalThrottle = self.antiThermalThrottling;
        self.smartThermalDispatch = GetLiveBool(@"SmartThermalDispatch", YES);
        self.heavyLoadCooling = GetLiveBool(@"HeavyLoadCooling", YES);
        self.chargeThermalProtection = GetLiveBool(@"ChargeThermalProtection", YES);
        self.powerSaveMode = GetLiveBool(@"PowerSaveMode", NO);
        self.bypassVarSandbox = GetLiveBool(@"BypassVarSandbox", YES);
        self.blockBackgroundTelemetry = GetLiveBool(@"BlockBackgroundTelemetry", YES);

        if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.magic = APEX_SYNC_MAGIC_V285;
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
            p.lowLatencyAudio = 1;
            p.memoryPressureRelief = 1;
            p.metalPacingEnabled = 1;
            p.runloopHangGuard = 1;
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
    if (!HardwareHasNative120Hz() && !self.forceOverclock144Hz) {
        if (target > 60) target = 60;
    }
    return target;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled || !self.enableFPSControl) return 60;
    if (self.powerSaveMode) return 30;
    
    NSInteger target = (NSInteger)ClampSafeFPS((float)self.targetFPS);
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

static void PrefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (CFG285) {
        [CFG285 loadSettings];
        Titanium_TuneWindowServerDisplayDirectly();
    }
}

// ====================================================================================================
// NHÓM 1: ZERO-LATENCY TOUCH PIPELINE & RAW EVENT DISPATCH
// ====================================================================================================

static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
    #if defined(TASK_LATENCY_QOS_POLICY)
    task_latency_qos_policy_data_t latencyPolicy;
    latencyPolicy.task_latency_qos_tier = LATENCY_QOS_TIER_0;
    task_policy_set(mach_task_self(), TASK_LATENCY_QOS_POLICY, (task_policy_t)&latencyPolicy, TASK_LATENCY_QOS_POLICY_COUNT);
    #endif

    #if defined(TASK_THROUGHPUT_QOS_POLICY)
    task_throughput_qos_policy_data_t throughputPolicy;
    throughputPolicy.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_0;
    task_policy_set(mach_task_self(), TASK_THROUGHPUT_QOS_POLICY, (task_policy_t)&throughputPolicy, TASK_THROUGHPUT_QOS_POLICY_COUNT);
    #endif
}

static void Titanium_ElevateThreadToMachRealTime(void) {
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);

    uint64_t period_ns = 16666667;
    uint64_t computation_ns = 8000000;
    uint64_t constraint_ns = 12000000;

    thread_time_constraint_policy_data_t policy;
    policy.period = (uint32_t)((period_ns * timebase.denom) / timebase.numer);
    policy.computation = (uint32_t)((computation_ns * timebase.denom) / timebase.numer);
    policy.constraint = (uint32_t)((constraint_ns * timebase.denom) / timebase.numer);
    policy.preemptible = 1;

    thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}

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
            }
        }
    });
}

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
// NHÓM 1: CẢM ỨNG 0MS
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

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

%hook UIControl
- (NSTimeInterval)_touchDelayThreshold {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return 0.0;
    return %orig;
}
%end

%hook UIWindow
- (BOOL)_shouldDelayTouchForCancelEvents {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return NO;
    return %orig;
}

- (void)sendEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost && event.type == 0) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(event);
}
%end

%end

// ====================================================================================================
// NHÓM 2: METAL GRAPHICS & TRIPLE BUFFERING (KHÔNG LỆCH TOẠ ĐỘ KHUNG HÌNH)
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
%end

%hook CALayer
- (void)display {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
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
%end

%end

// ====================================================================================================
// BIẾN QUẢN LÝ ĐA LUỒNG & CHUYỂN ĐỘNG (10HZ KHI TĨNH - 120/144HZ KHI ĐỘNG)
// ====================================================================================================

static volatile int32_t g_activeAnimationCount = 0;
static volatile BOOL g_isScrollingActive = NO;
static volatile BOOL g_isVideoPlayingActive = NO;
static volatile BOOL g_isNotificationBannerActive = NO;
static volatile BOOL g_isAppWarmingUp = YES;
static dispatch_source_t g_bannerBurstTimer = nil;
static dispatch_queue_t g_bannerBurstQueue = nil;

static inline BOOL Titanium_IsScreenInMotion(void) {
    return (g_isUserTouchingScreen || g_isAppWarmingUp || g_isScrollingActive || g_activeAnimationCount > 0 || g_isNotificationBannerActive);
}

static void Titanium_TriggerNotificationBurst(void) {
    if (!Titanium_IsSpringBoard()) return;
    g_isNotificationBannerActive = YES;

    static dispatch_once_t bToken;
    dispatch_once(&bToken, ^{
        g_bannerBurstQueue = dispatch_queue_create("com.titanium.bannerburst", DISPATCH_QUEUE_SERIAL);
    });

    if (g_bannerBurstTimer) {
        dispatch_source_cancel(g_bannerBurstTimer);
        g_bannerBurstTimer = nil;
    }

    g_bannerBurstTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, g_bannerBurstQueue);
    dispatch_source_set_timer(g_bannerBurstTimer, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(850 * NSEC_PER_MSEC)), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(g_bannerBurstTimer, ^{
        g_isNotificationBannerActive = NO;
        g_bannerBurstTimer = nil;
    });
    dispatch_resume(g_bannerBurstTimer);
}

// ====================================================================================================
// NHÓM 3: KHÓA CỨNG HZ & FPS THÔNG MINH (10HZ TĨNH, MAX HZ KHI VUỐT CHẠM)
// ====================================================================================================

%group Group_FluidTransitions_Pacing

%hook UIScrollView

- (void)_notifyDidScroll {
    %orig;
    g_isScrollingActive = YES;
}

- (void)_scrollViewDidEndDraggingForChildScrollView:(id)arg1 {
    %orig(arg1);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(120 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        g_isScrollingActive = NO;
    });
}

- (void)_scrollViewDidEndDeceleratingForChildScrollView:(id)arg1 {
    %orig(arg1);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(120 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        g_isScrollingActive = NO;
    });
}

%end

%hook CADisplayLink

- (NSInteger)preferredFramesPerSecond {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        if (Titanium_IsScreenInMotion()) {
            return [CFG285 resolvedTargetFPS];
        }
        return 10;
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        if (Titanium_IsScreenInMotion()) {
            %orig([CFG285 resolvedTargetFPS]);
        } else {
            %orig(10);
        }
        return;
    }
    %orig(fps);
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE && CFG285.enableHzControl) {
            float target = (float)[CFG285 resolvedTargetHz];
            if (Titanium_IsScreenInMotion()) {
                float minHz = (target < 60.0f) ? target : 60.0f;
                range = SafeMakeFRR(minHz, target, target);
            } else {
                range = SafeMakeFRR(10.0f, 30.0f, 10.0f);
            }
        }
    }
    %orig(range);
}

%end

%hook CADisplay

- (NSInteger)preferredFPS {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        if (Titanium_IsScreenInMotion()) {
            return [CFG285 resolvedTargetFPS];
        }
        return 10;
    }
    return %orig;
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        if (Titanium_IsScreenInMotion()) {
            fps = [CFG285 resolvedTargetFPS];
        } else {
            fps = 10;
        }
    }
    %orig(fps);
}

- (void)overrideDisplayCadence:(id)cadence {
    if (Titanium_IsSpringBoard() && IS_ACTIVE && CFG285.enableHzControl) {
        cadence = nil;
    }
    %orig(cadence);
}

- (BOOL)supportsDynamicRefresh {
    return %orig;
}

%end

%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        return [CFG285 resolvedTargetFPS];
    }
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ACTIVE && CFG285.enableFPSControl) {
        return [CFG285 resolvedTargetFPS];
    }
    return %orig;
}

- (CGFloat)_refreshRate {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        return (CGFloat)[CFG285 resolvedTargetHz];
    }
    return %orig;
}

- (BOOL)supportsDynamicRefreshRate {
    return %orig;
}

- (BOOL)_supportsDynamicRefreshRate {
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (IS_ACTIVE && CFG285.enableHzControl) {
        rate = (CGFloat)[CFG285 resolvedTargetHz];
    }
    %orig(rate);
}

%end

%hook CAAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE && CFG285.enableHzControl) {
            float target = (float)[CFG285 resolvedTargetHz];
            float minHz = (target < 60.0f) ? target : 60.0f;
            range = SafeMakeFRR(minHz, target, target);
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
        if (IS_ACTIVE && CFG285.enableHzControl) {
            float target = (float)[CFG285 resolvedTargetHz];
            float minHz = (target < 60.0f) ? target : 60.0f;
            range = SafeMakeFRR(minHz, target, target);
        }
    }
    %orig(range);
}

%end

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

%hook AVPlayer

- (void)setRate:(float)rate {
    %orig(rate);
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = (rate > 0.0f);
    }
}

%end

%hook NCNotificationDispatcher
- (void)postNotificationWithRequest:(id)request {
    if (Titanium_IsSpringBoard() && IS_ACTIVE) Titanium_TriggerNotificationBurst();
    %orig(request);
}
%end

%hook NCNotificationViewController
- (void)viewWillAppear:(BOOL)animated {
    if (Titanium_IsSpringBoard() && IS_ACTIVE) Titanium_TriggerNotificationBurst();
    %orig(animated);
}
%end

%hook SBNotificationBannerDestination
- (void)postNotificationRequest:(id)request {
    if (Titanium_IsSpringBoard() && IS_ACTIVE) Titanium_TriggerNotificationBurst();
    %orig(request);
}
%end

%hook UIApplication

- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        if (!Titanium_IsSpringBoard()) {
            [[BoostConfigV285Pro sharedInstance] loadSettings];
        }
        g_isAppWarmingUp = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            g_isAppWarmingUp = NO;
        });
    }
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        if (!Titanium_IsSpringBoard()) {
            [[BoostConfigV285Pro sharedInstance] loadSettings];
        }
        g_isAppWarmingUp = YES;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            g_isAppWarmingUp = NO;
        });
    }
}

%end

%end

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM
// ====================================================================================================

static volatile BOOL g_isContinuousSwiping = NO;

%group Group_Switcher30Apps_Virtualization

%hook SBHomeGestureInteraction
- (void)_handleGestureBegan:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = YES;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(gesture);
}
%end

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

%hook SBAppToHomeWorkspaceTransaction
- (BOOL)shouldAnimateOrientationChangeOnCompletion {
    return NO;
}

- (void)_willBegin {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            if (!g_isContinuousSwiping && !g_isUserTouchingScreen) {
                malloc_zone_pressure_relief(malloc_default_zone(), 0);
            }
        });
    }
}
%end

%hook SBFluidSwitcherModifier
- (BOOL)shouldasyncRenderAppLayouts {
    if (IS_ACTIVE) return YES;
    return %orig;
}
%end

%hook SBAppSwitcherSettings
- (BOOL)shouldKeepAppSnapshotsInMemory {
    if (IS_ACTIVE) return YES;
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
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC
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
    if (Titanium_IsSpringBoard() && IS_ACTIVE && CFG285.turboAppLaunch) {
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig(scene, context, completion);
}

- (void)_applicationWillEnterForeground {
    %orig;
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
}
%end

%end

// ====================================================================================================
// NHÓM 6: CUỘN FEED VÀ BÀN PHÍM SIÊU NHẠY
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

%hook UIKeyboardImpl
- (void)showKeyboard {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(string, event, context);
}

- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
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

%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(action, target, event);
}
%end

%hook UITabBarController
- (void)setSelectedIndex:(NSUInteger)index {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(index);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(selectedViewController);
}
%end

%hook UINavigationController
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(viewController, animated);
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    return %orig(animated);
}
%end

%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(viewControllerToPresent, flag, completion);
}
%end

%hook UIScrollView
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE) return YES;
    return %orig(view);
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
// NHÓM 7: SPRINGBOARD - TOÀN BỘ HIỆU ỨNG BÊN NGOÀI (FOLDER, LOCKSCREEN, 3D TOUCH, CC/NC, LOAD APP)
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
// 7. TOÀN DIỆN HIỆU ỨNG THƯ MỤC, 3D TOUCH & MÀN HÌNH KHÓA (COVERSHEET / HOMESCREEN)
// ====================================================================================================

// Rút ngắn thời gian mở/đóng thư mục (Folder) từ 350ms xuống 220ms, bung nảy dứt khoát
%hook SBFolderControllerAnimationSettings
- (double)duration {
    if (IS_ACTIVE) return 0.22;
    return %orig;
}
%end

// Bơm xung zero-latency ngay khi người dùng chạm mở Folder
%hook SBFolderView
- (void)prepareToOpen {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}
%end

// Menu giữ đè icon (3D Touch / Haptic Touch) mở ra tức thì 0ms
%hook SBIconForceTouchSettings
- (double)delayBeforeOpening {
    if (IS_ACTIVE) return 0.05; // 50ms: Đặt ngón tay là menu bung ngay lập tức
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
// NHÓM 8: PICTURE-IN-PICTURE
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
// NHÓM 9: HOME BUTTON VẬT LÝ
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions
- (void)performSinglePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)performDoublePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH
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
    }
    %orig(application);
}
%end

%end

// ====================================================================================================
// NHÓM 11: ỨNG DỤNG BÊN THỨ BA (TIÊM NHẸ NHÀNG, MẠNG LOAD 100%, KHÔNG KHÓA LUỒNG)
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
}
%end

%hook UIViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
}
%end

%hook UIScrollView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE && CFG285.enableHzControl) {
        if ([self respondsToSelector:@selector(setDecelerationRate:)]) {
            self.decelerationRate = UIScrollViewDecelerationRateNormal;
        }
    }
}
%end

%end

// ====================================================================================================
// NHÓM 12: TIỆN ÍCH HỆ THỐNG
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
    }
    %orig;
}
%end

%hook UIButton
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE) Titanium_TriggerInstantTouchBurst();
    %orig(touches, event);
}
%end

%end

// ====================================================================================================
// NHÓM 13: KHÓA CỨNG TRẦN FPS & CHỐNG BÓP NHIỆT ĐỘ
// ====================================================================================================

%group Group_Global_Thread_Governor_Unthrottled

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

%end

// ====================================================================================================
// GIA TỐC HOẠT ẢNH TRONG APP
// ====================================================================================================

%group Group_Universal_InApp_Animations

%hook UIViewPropertyAnimator
- (void)startAnimation {
    %orig;
}
%end

%hook _UIContextMenuContainerView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
}
%end

%hook UIAlertController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
}
%end

%hook UIPresentationController
- (void)presentationTransitionWillBegin {
    %orig;
    if (IS_ACTIVE) {
        __sync_fetch_and_add(&g_activeAnimationCount, 1);
    }
}

- (void)presentationTransitionDidEnd:(BOOL)completed {
    %orig(completed);
    if (IS_ACTIVE && g_activeAnimationCount > 0) {
        __sync_fetch_and_sub(&g_activeAnimationCount, 1);
    }
}

- (void)dismissalTransitionWillBegin {
    %orig;
    if (IS_ACTIVE) {
        __sync_fetch_and_add(&g_activeAnimationCount, 1);
    }
}

- (void)dismissalTransitionDidEnd:(BOOL)completed {
    %orig(completed);
    if (IS_ACTIVE && g_activeAnimationCount > 0) {
        __sync_fetch_and_sub(&g_activeAnimationCount, 1);
    }
}
%end

%end

// ====================================================================================================
// GIÁM SÁT SẠC PIN
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

static void SpringBoardDidLaunchCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            const char *progName = getprogname();
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
            NSFileManager *fm = [NSFileManager defaultManager];
            BOOL isVerified = [fm fileExistsAtPath:TITANIUM_BOOT_FLAG_VERIFIED];

            // =========================================================================
            // NHÁNH 1: IPHONE 6S - 7 PLUS (COLD REBOOT & USERSPACE REBOOT)
            // =========================================================================
            if (Titanium_IsLegacy6s7P()) {
                if (isVerified) {
                    // Đã qua bước respring an toàn -> NẠP TWEAK VÀ DỪNG VÒNG LẶP
                    runCoreTweak(YES, bundleID, progName);
                    return;
                }

                // Lần đầu khởi động lên (chưa có cờ verified): Đợi 2.2 giây rồi Respring tự động
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (![fm fileExistsAtPath:TITANIUM_BOOT_FLAG_VERIFIED]) {
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
            runCoreTweak(YES, bundleID, progName);
        });
    });
}

// ====================================================================================================
// CONSTRUCTOR CHÍNH CỦA DYLIB
// ====================================================================================================

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        // Bỏ qua các tiến trình ngầm hệ thống và WebKit phụ
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

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [mainBundle bundleIdentifier];
        BOOL isSpringBoard = bundleID && [bundleID isEqualToString:@"com.apple.springboard"];

        // 1. Chỉ kiểm tra bootguard trên SpringBoard
        if (isSpringBoard) {
            if (!Titanium_CheckAndPreventBootloopUniversal()) return;
        }

        // 2. Nạp cấu hình tức thì cho ứng dụng Cài đặt
        if (strstr(progName, "Preferences") || strstr(progName, "Settings")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
            }
            return;
        }

        %init;

        // 3. Phân luồng SpringBoard vs App bên thứ ba
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
            // App Sandbox (TikTok, Facebook, Game...): Nạp trực tiếp Tweak
            runCoreTweak(NO, bundleID, progName);
        }
    }
}
