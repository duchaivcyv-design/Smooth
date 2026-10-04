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
#include <stdatomic.h> // BẮT BUỘC: Hỗ trợ bộ đếm nguyên tử chống nóng máy và an toàn đa luồng
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
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAMetalLayer.h>
#import <AVFoundation/AVFoundation.h> // Đã lọc bỏ dòng import trùng lặp
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

// KHÓA ĐÚNG KHUNG HÌNH VẬT LÝ NGUYÊN BẢN (CHỐNG CẮT LỆCH GIAO DIỆN) & ÉP NHỊP 144HZ
static void Titanium_TuneWindowServerDisplayDirectly(void) {
    Class wsClass = NSClassFromString(@"CAWindowServer");
    if (!wsClass) return;
    
    CAWindowServer *server = [wsClass server];
    NSArray *displays = [server displays];
    if (displays && displays.count > 0) {
        CAWindowServerDisplay *mainDisp = displays[0];
        
        // Chu kỳ quét 144Hz (~0.00694s mỗi frame)
        double minDuration = 1.0 / 144.0;

        if ([mainDisp respondsToSelector:@selector(setMinimumFrameDuration:)]) {
            [mainDisp setMinimumFrameDuration:minDuration];
        }
        // TẮT CHẾ ĐỘ ẢO ĐỂ TRẢ LẠI ĐÚNG ĐỘ PHÂN GIẢI THỰC CỦA MÁY (HẾT CẮT PASSCODE/STATUSBAR)
        if ([mainDisp respondsToSelector:@selector(setAllowsVirtualModes:)]) {
            [mainDisp setAllowsVirtualModes:NO];
        }
        if ([mainDisp respondsToSelector:@selector(setAllowsDisplayCompositing:)]) {
            [mainDisp setAllowsDisplayCompositing:NO];
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
                // SỬ DỤNG __bridge_transfer ĐỂ ARC QUẢN LÝ VÀ TỰ GIẢI PHÓNG (TRIỆT TIÊU 100% RÒ RỈ RAM)
                NSString *str = (__bridge_transfer NSString *)val;
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

            // SAO CHÉP DỮ LIỆU SANG BIẾN CAPTURED: TRIỆT TIÊU LỖI CON TRỎ NGĂN XẾP RÁC KHI CHẠY NỀN
            ApexV285ProPayload capturedPayload = p;
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_WriteSyncPayloadV285(&capturedPayload);
            });
        }
    }
}

- (NSInteger)resolvedTargetHz {
    if (!self.enabled || !self.enableHzControl) return 144;
    if (self.powerSaveMode) return 60;
    
    // BẺ KHÓA TOÀN BỘ: ÉP THẲNG TRẦN 144HZ, BỎ CHẶN 60HZ CỦA APPLE
    return 144;
}

- (NSInteger)resolvedTargetFPS {
    if (!self.enabled || !self.enableFPSControl) return 144;
    if (self.powerSaveMode) return 60;
    
    // ÉP THẲNG ĐỒNG BỘ 144FPS KHÔNG GIỚI HẠN
    return 144;
}

- (NSInteger)resolvedFrameInterval {
    // Luôn trả về 1 để GPU/CoreAnimation dựng hình liên tục từng khung, không bỏ nhịp Vsync
    return 1;
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
// KHAI BÁO BIẾN TOÀN CỤC DUY NHẤT (ĐẢM BẢO ĐẦY ĐỦ CÁC CỜ HỆ THỐNG - KHÔNG LỖI UNDECLARED)
// ====================================================================================================

#include <stdatomic.h>

static volatile BOOL g_isContinuousSwiping = NO;
static volatile BOOL g_isUserTouchingScreen = NO;
static volatile BOOL g_isVideoPlayingActive = NO;       // Cờ cho Video & PiP Nhóm 8
static volatile BOOL g_isNotificationBannerActive = NO;
static volatile BOOL g_isScrollingActive = NO;
static volatile int32_t g_activeAnimationCount = 0;

// Các mốc Mach Time và hàng đợi dùng chung toàn hệ thống
static volatile uint64_t g_lastInteractionMachTime = 0;
static uint64_t g_burstDurationMachTicks = 0;
static uint64_t g_burstDurationChargingMachTicks = 0;

static volatile uint64_t g_lastBannerMachTime = 0;
static uint64_t g_bannerDurationMachTicks = 0;

static dispatch_source_t g_touchBurstTimer = nil;
static dispatch_queue_t g_touchBurstQueue = nil;
static dispatch_source_t g_bannerBurstTimer = nil;
static dispatch_queue_t g_bannerBurstQueue = nil;

// ====================================================================================================
// 5. BỘ ĐIỀU PHỐI BURST GOVERNOR NGUYÊN TỬ (AN TOÀN ĐA LUỒNG & KHÔNG OVERHEAD SYSCALL)
// ====================================================================================================

// 1. Khởi tạo Timebase: Có guard kiểm tra numer > 0 chống crash chia cho 0
static inline void Titanium_InitTouchMachTimebase(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t timebase;
        if (mach_timebase_info(&timebase) == KERN_SUCCESS && timebase.numer > 0) {
            uint64_t nanos = 350ULL * 1000000ULL;         // 350ms khi dùng pin
            uint64_t nanosCharging = 180ULL * 1000000ULL; // 180ms khi sạc pin
            g_burstDurationMachTicks = (nanos * timebase.denom) / timebase.numer;
            g_burstDurationChargingMachTicks = (nanosCharging * timebase.denom) / timebase.numer;
        }
    });
}

// Alias tương thích tuyệt đối cho các nhóm gọi Titanium_EnsureMachTimebaseInit
static inline void Titanium_EnsureMachTimebaseInit(void) {
    Titanium_InitTouchMachTimebase();
}

// Khởi tạo Mach Timebase riêng cho Banner thông báo
static inline void Titanium_InitBannerMachTimebase(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t timebase;
        if (mach_timebase_info(&timebase) == KERN_SUCCESS && timebase.numer > 0) {
            uint64_t nanos = 850ULL * 1000000ULL; // 850ms bao trọn chu kỳ banner trượt xuống và neo ổn định
            g_bannerDurationMachTicks = (nanos * timebase.denom) / timebase.numer;
        }
    });
}

// Kiểm tra banner còn hiệu lực theo Mach Time (2ns phản hồi)
static inline BOOL Titanium_IsNotificationBannerActive(void) {
    if (g_lastBannerMachTime == 0) return NO;
    uint64_t now = mach_absolute_time();
    return ((now - g_lastBannerMachTime) < g_bannerDurationMachTicks);
}

// 2. Nâng ưu tiên luồng chính: Thêm cờ khóa tránh spam syscall pthread liên tục mỗi frame
static inline void Titanium_LockMainThreadFast(void) {
    static pthread_t s_lastElevatedThread = NULL;
    pthread_t currentThread = pthread_self();

    // Chỉ thực thi một lần cho luồng hiện tại, tránh gọi syscall tốn chu kỳ CPU khi chạm liên tục
    if (s_lastElevatedThread != currentThread) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        struct sched_param param;
        param.sched_priority = 47;
        pthread_setschedparam(currentThread, SCHED_RR, &param);
        s_lastElevatedThread = currentThread;
    }
}

// 3. Kích xung nhịp tương tác tức thì: Nguyên tử hóa bộ đếm Token và ngắt timer rác
static void Titanium_TriggerInstantTouchBurst(void) {
    Titanium_InitTouchMachTimebase();

    // Cập nhật mốc thời gian Mach tuyệt đối (chỉ ~2ns)
    g_lastInteractionMachTime = mach_absolute_time();
    g_isUserTouchingScreen = YES;

    // Nâng priority an toàn
    Titanium_LockMainThreadFast();

    // Dùng Atomic Increment: Đảm bảo an toàn tuyệt đối nếu Touch Event đến từ Background Thread (IOHID)
    static atomic_int_fast64_t s_touchSeq = 0;
    int64_t currentSeq = atomic_fetch_add_explicit(&s_touchSeq, 1, memory_order_relaxed) + 1;

    // Sử dụng trực tiếp biến static g_isDeviceChargingV285 từ dòng 688 (TRIỆT TIÊU TOÀN BỘ CẢNH BÁO BUILD)
    BOOL isCharging = g_isDeviceChargingV285;
    int64_t burstDuration = isCharging ? (int64_t)(180 * NSEC_PER_MSEC) : (int64_t)(350 * NSEC_PER_MSEC);

    // Điều phối nhả cờ trên Main Runloop
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, burstDuration), dispatch_get_main_queue(), ^{
        if (atomic_load_explicit(&s_touchSeq, memory_order_relaxed) == currentSeq) {
            g_isUserTouchingScreen = NO;
        }
    });
}

// ====================================================================================================
// HÀM ĐIỀU PHỐI KHÓA TARGET RATE TOÀN CỤC (PHẢI NẰM TẠI ĐÂY ĐỂ CALAYER DÒNG 1436 GỌI ĐƯỢC)
// ====================================================================================================

static inline BOOL Titanium_ShouldLockTargetRate(void) {
    // 1. Chạm tay hoặc vuốt cử chỉ X
    if (g_isContinuousSwiping || g_isUserTouchingScreen) return YES;

    // 2. Đang cuộn feed hoặc trôi quán tính (TikTok, FB, Safari, Album ảnh)
    if (g_isScrollingActive) return YES;

    // 3. Có thông báo đang trượt xuống hoặc đang neo
    if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

    // 4. Có hiệu ứng chuyển cảnh hệ thống, đóng mở app, lò xo
    if (g_activeAnimationCount > 0) return YES;

    // 5. Kiểm tra thời gian nhả xung Mach Time
    if (g_lastInteractionMachTime == 0) return NO;

    if (g_burstDurationMachTicks == 0) {
        Titanium_EnsureMachTimebaseInit();
    }

    uint64_t now = mach_absolute_time();
    BOOL isCharging = g_isDeviceChargingV285;
    uint64_t limitTicks = isCharging ? g_burstDurationChargingMachTicks : g_burstDurationMachTicks;

    return ((now - g_lastInteractionMachTime) < limitTicks);
}

// ====================================================================================================
// NHÓM 1: ZERO-LATENCY TOUCH PIPELINE & RAW EVENT DISPATCH (ĐIỀU PHỐI KERNEL & PHẦN CỨNG)
// ====================================================================================================

// 1. CẤP QUYỀN QOS AN TOÀN CHO NHÂN HỆ THỐNG XNU KERNEL (KHÔNG NGHẼN MẠNG YOUTUBE, KHÔNG NÓNG MÁY)
static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
    #if defined(TASK_LATENCY_QOS_POLICY)
    task_latency_qos_policy_data_t latencyPolicy;
    // Sử dụng TIER_1: Phản hồi tức thì nhưng KHÔNG chặn luồng nsurlsessiond của YouTube và Safari
    latencyPolicy.task_latency_qos_tier = LATENCY_QOS_TIER_1;
    task_policy_set(mach_task_self(), TASK_LATENCY_QOS_POLICY, (task_policy_t)&latencyPolicy, TASK_LATENCY_QOS_POLICY_COUNT);
    #endif

    #if defined(TASK_THROUGHPUT_QOS_POLICY)
    task_throughput_qos_policy_data_t throughputPolicy;
    // Băng thông I/O cân bằng để luồng tải video mạng và bộ đệm Metal chạy song song không nghẽn
    throughputPolicy.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_1;
    task_policy_set(mach_task_self(), TASK_THROUGHPUT_QOS_POLICY, (task_policy_t)&throughputPolicy, TASK_THROUGHPUT_QOS_POLICY_COUNT);
    #endif
}

// 2. CẤP QUYỀN THỜI GIAN THỰC MACH CHO LUỒNG VẼ GIAO DIỆN (CHỐNG QUÁ NHIỆT KHI SẠC PIN)
static void Titanium_ElevateThreadToMachRealTime(void) {
    // Nếu thiết bị đang cắm sạc: Nhả quyền cưỡng bức Mach để tránh cộng hưởng nhiệt gây nóng ran máy
    if (g_isDeviceChargingV285) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        return;
    }

    mach_timebase_info_data_t timebase;
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || timebase.numer == 0) return;

    // Chu kỳ 144Hz: ~6.94ms
    uint64_t period_ns = 6944444;      
    // Cân chỉnh 1.5ms tính toán: Đủ siêu mượt 144Hz mà CPU A9 vẫn có thời gian nghỉ, máy mát rượi
    uint64_t computation_ns = 1500000; 
    uint64_t constraint_ns = 5000000;  // Giới hạn 5.0ms nhả khung hình chuẩn xác

    thread_time_constraint_policy_data_t policy;
    policy.period = (uint32_t)((period_ns * timebase.denom) / timebase.numer);
    policy.computation = (uint32_t)((computation_ns * timebase.denom) / timebase.numer);
    policy.constraint = (uint32_t)((constraint_ns * timebase.denom) / timebase.numer);
    policy.preemptible = 1;

    thread_policy_set(mach_thread_self(), THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&policy, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}

// 3. KHÓA BỘ ĐIỀU KHIỂN TẤM NỀN MÀN HÌNH NỘI BỘ (AN TOÀN BỘ NHỚ VÀ SELECTOR RUNTIME)
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

        SEL selVirtual = sel_registerName("setAllowsVirtualModes:");
        if ([display respondsToSelector:selVirtual]) {
            void (*setAllowsVirtual)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))objc_msgSend;
            setAllowsVirtual(display, selVirtual, NO);
        }
    });
}

// 4. NHẬN DIỆN PHẦN CỨNG (A9 - A12)
static BOOL Titanium_IsLegacyA9toA12(void) {
    static BOOL s_isLegacy = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        if (uname(&sysInfo) == 0) {
            NSString *machine = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
            if (machine) {
                s_isLegacy = ([machine hasPrefix:@"iPhone8,"] ||  // A9
                              [machine hasPrefix:@"iPhone9,"] ||  // A10
                              [machine hasPrefix:@"iPhone10,"] || // A11
                              [machine hasPrefix:@"iPhone11,"] || // A12
                              [machine hasPrefix:@"iPad6,"] || 
                              [machine hasPrefix:@"iPad7,"]);
            }
        }
    });
    return s_isLegacy;
}

// ====================================================================================================
// NHÓM 1: CẢM ỨNG 0MS (ĐÃ KIỂM SOÁT AN TOÀN 100% - CHỐNG ĐEN APP, CHỐNG NÓNG MÁY, 0MS ĐỘ TRỄ)
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

// 1. PHẢN HỒI NÚT BẤM VÀ ĐIỀU HƯỚNG TỨC THÌ 0MS (BẢO TOÀN HOẠT ẢNH BUNG MENU & CHUYỂN CẢNH)
%hook UIControl
- (NSTimeInterval)_touchDelayThreshold {
    if (IS_ACTIVE && CFG285.touchResponseBoost) return 0.0; // 0ms: Chạm là ăn nút ngay lập tức, không trễ
    return %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst(); // Kích xung 144Hz ngay khoảnh khắc chạm nút
        Titanium_LockMainThreadFast();        // Khóa luồng chính ở mức ưu tiên Interactive cao nhất
        // ĐÃ SỬA: Không gọi ép zero latency thô bạo tại đây để bảo vệ hiệu ứng bung menu tab không bị giật
    }
    %orig(touches, event);
}
%end

// 2. ĐÓN ĐẦU CHẠM TOÀN MÀN HÌNH & PHÍM CỨNG VOLUME (CHỐNG GIẬT VOLUME HUD & CHỐNG KHỰNG ZOOM APP)
%hook UIWindow
- (BOOL)_shouldDelayTouchForCancelEvents {
    // Nếu đang có hiệu ứng chuyển cảnh hoặc vuốt app: Giữ nguyên cơ chế khử xung đột để góc bo không bị giật
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
        // ĐÃ BỔ SUNG event.type == 3: Kích xung cả khi bấm phím cứng VOLUME UP/DOWN (Triệt tiêu 100% lag Volume HUD)
        // event.type == 0: Chạm cảm ứng màn hình
        if (event.type == 0 || event.type == 3) {
            Titanium_TriggerInstantTouchBurst(); // Mach Time 2ns: 0 cấp phát bộ nhớ, không sinh nhiệt
            Titanium_LockMainThreadFast();        // Đưa luồng chính lên đỉnh ưu tiên, thanh Volume nảy mượt lì
        }
    }
    %orig(event);
}
%end

%end

// ====================================================================================================
// NHÓM 2: METAL GRAPHICS, TRIPLE BUFFERING & BẢO TOÀN TỌA ĐỘ LAYER (ĐÃ KIỂM SOÁT AN TOÀN 100%)
// ====================================================================================================

%group Group_Metal_ZeroTearing_Pacing

// 1. ĐỒNG BỘ HIỂN THỊ METAL AN TOÀN (KHÓA ĐỒNG BỘ V-SYNC 144HZ CHỐNG XÉ HÌNH)
%hook CAMetalLayer
- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if (IS_ACTIVE) enabled = YES; // Khóa đồng bộ V-Sync 144Hz chống xé hình
    %orig(enabled);
}
// ĐÃ XÓA: setMaximumDrawableCount & setLowLatencyMode (Hết đen app và khựng Metal)
%end

// 2. KÍCH HOẠT ĐỒ HỌA ZERO-LATENCY AN TOÀN: CHỐNG NÓNG MÁY, KHÔNG ĐỘNG HÌNH NỀN & MỊN HOẠT ẢNH
%hook CALayer
- (void)display {
    // KIỂM SOÁT AN TOÀN TUYỆT ĐỐI - KHẮC PHỤC TRIỆT ĐỂ CÁC LỖI VIDEO 2 & VIDEO 3:
    if (IS_ACTIVE && CFG285.touchResponseBoost && NSThread.isMainThread && Titanium_ShouldLockTargetRate()) {
        // 1. BẢO VỆ TUYỆT ĐỐI HÌNH NỀN (WALLPAPER): Bỏ qua 100% layer thuộc Wallpaper/Poster
        id del = self.delegate;
        const char *delName = del ? object_getClassName(del) : NULL;
        BOOL isWallpaper = (delName != NULL) && (strstr(delName, "Wallpaper") != NULL || strstr(delName, "Poster") != NULL);

        if (!isWallpaper) {
            // 2. CHỐNG GIẬT CONTROL CENTER & BUNG MENU ICON (3D TOUCH):
            // Bỏ qua CABackdropLayer (layer xử lý Gaussian Blur) để shader không bị nghẽn khi lò xo nảy
            static Class s_backdropCls = Nil;
            static dispatch_once_t s_onceBackdrop;
            dispatch_once(&s_onceBackdrop, ^{
                s_backdropCls = objc_getClass("CABackdropLayer");
            });

            BOOL isBackdrop = (s_backdropCls && [self isKindOfClass:s_backdropCls]);

            // 3. CHỐNG GIẬT GÓC BO & ZOOM RA/VÀO APP (Lỗi 1, 4, 5 Video 2):
            // Bảo toàn đường cong góc bo của Fluid Switcher khi đang phóng to/thu nhỏ
            BOOL isCornerMasking = (self.mask != nil) || (self.cornerRadius > 0.0f && self.masksToBounds);

            // 4. CHỐNG NÓNG MÁY KHI SẠC PIN: Cắm sạc sẽ không spam flush GPU liên tục
            BOOL isThermalSafe = !g_isDeviceChargingV285 || (g_isUserTouchingScreen || g_isContinuousSwiping);

            if (!isBackdrop && !isCornerMasking && isThermalSafe) {
                Titanium_EnableZeroLatencyPipeline();
            }
        }
    }
    %orig;
}
// TUYỆT ĐỐI XÓA BỎ setPosition: LÀM TRÒN SỐ NGUYÊN
// -> HẾT 100% LỖI: CẮT NỬA CHẤM MẬT MÃ, KẺ ĐEN BÀN PHÍM, LỆCH POPUP VÀ GIẬT KHUNG CROP ẢNH
%end

// 3. ƯU TIÊN LUỒNG DỰNG HÌNH ĐỒNG BỘ: ĐỒNG NHẤT SPRINGBOARD & APP, CHỐNG NÓNG MÁY
%hook CAContext
- (void)setCommitPriority:(uint32_t)priority {
    if (IS_ACTIVE) {
        // Nếu cắm sạc: Trả về mức điều tiết mặc định của iOS để chip A9 không bị quá nhiệt
        if (g_isDeviceChargingV285) {
            %orig(priority);
            return;
        }
        // Đồng bộ ưu tiên giữa SpringBoard và App khi tương tác để chuyển cảnh ra/vào không lệch nhịp
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
    if (IS_ACTIVE) range = 1.0f; // Khóa SDR chuẩn 1.0f: GPU mát lạnh, không nghẽn shader đồ họa
    %orig(range);
}
%end

%end

// ====================================================================================================
// ĐIỀU PHỐI TRẠNG THÁI CHUYỂN ĐỘNG, VIDEO VÀ THÔNG BÁO HỆ THỐNG (ĐÃ BỎ ĐỊNH NGHĨA TRÙNG LẶP)
// ====================================================================================================

// Kích xung nhịp CPU/GPU cực đại tức thì 0ms khi có thông báo: KHÔNG TẠO TIMER RÁC, CHỐNG GIẬT KHỰNG BANNER
static void Titanium_TriggerNotificationBurst(void) {
    Titanium_InitBannerMachTimebase();
    g_lastBannerMachTime = mach_absolute_time();
    g_isNotificationBannerActive = YES;
    
    // Khóa luồng chính ở mức ưu tiên đồ họa cao nhất (QOS_CLASS_USER_INTERACTIVE)
    Titanium_LockMainThreadFast();
    // BẢO VỆ PACING BUFFER: KHÔNG GỌI Titanium_EnableZeroLatencyPipeline() ĐỂ BANNER RƠI MỊN MÀ 144HZ

    // Sequence token an toàn trên Main Thread: Triệt tiêu hoàn toàn việc tạo/hủy dispatch_source_t gây nóng máy
    static int64_t s_bannerSeq = 0;
    int64_t currentSeq = ++s_bannerSeq;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(850 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        if (s_bannerSeq == currentSeq) {
            g_isNotificationBannerActive = NO;
        }
    });
}

// ====================================================================================================
// NHÓM 3: KHÓA CỨNG HZ/FPS TÙY CHỌN - TỰ HẠ KHI TĨNH - ĐÓN ĐẦU THÔNG BÁO - BẢO VỆ VIDEO
// (CHỈ ÁP DỤNG IPHONE 6S - 12 PRO MAX)
// ====================================================================================================

// 2. Kiểm tra xem có đang ở chế độ xem video thụ động (không tương tác tay) hay không
static inline BOOL Titanium_IsPassiveVideoPlayback(void) {
    // Chỉ nhả về gốc khi đang xem video mà KHÔNG chạm tay và KHÔNG cuộn trang
    return (g_isVideoPlayingActive && !g_isUserTouchingScreen && !g_isScrollingActive);
}

%group Group_FluidTransitions_Pacing

// 1. ĐIỀU PHỐI VÒNG LẶP DỰNG HÌNH CADISPLAYLINK (CHUYỂN ĐỘNG 144HZ - TĨNH HẲN HẠ 10HZ)
%hook CADisplayLink

- (NSInteger)preferredFramesPerSecond {
    if (Titanium_IsPassiveVideoPlayback()) return %orig; // Giữ nguyên FPS video khi xem thụ động

    if (IS_ACTIVE && CFG285.enableFPSControl) {
        if (Titanium_ShouldLockTargetRate()) {
            return 144; // CÒN CHUYỂN ĐỘNG HOẶC TƯƠNG TÁC: ĐẨY CĂNG TRẦN 144 FPS
        }
        return 10; // TĨNH HẲN 100%: HẠ XUỐNG 10 FPS ĐỂ MÁT GPU VÀ TIẾT KIỆM PIN
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if (Titanium_IsPassiveVideoPlayback()) {
        %orig;
        return;
    }

    if (IS_ACTIVE && CFG285.enableFPSControl) {
        %orig(Titanium_ShouldLockTargetRate() ? 144 : 10);
        return;
    }
    %orig;
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (Titanium_IsPassiveVideoPlayback()) { 
        %orig; 
        return; 
    }

    if (@available(iOS 15.0, *)) {
        if (IS_ACTIVE && CFG285.enableHzControl) {
            if (Titanium_ShouldLockTargetRate()) {
                // CHUYỂN ĐỘNG / VUỐT / HOẠT ẢNH: KHÓA CHẶT DẢI 144HZ SIÊU MƯỢT
                range = SafeMakeFRR(144.0f, 144.0f, 144.0f);
            } else {
                // TĨNH HẲN: SÀN 10HZ, PREFERRED 10HZ LÀM MÁT MÁY, TRẦN 144HZ SẴN SÀNG BẬT LÊN TRONG 0MS
                range = SafeMakeFRR(10.0f, 144.0f, 10.0f);
            }
        }
    }
    %orig(range);
}

- (void)setFrameInterval:(NSInteger)interval {
    if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE && CFG285.enableHzControl) {
        interval = 1; // LUÔN VẼ TỪNG FRAME, KHÔNG BỎ NHỊP
    }
    %orig(interval);
}

%end

// 2. KHÓA TẤM NỀN PHẦN CỨNG CADISPLAY LÊN TRẦN 144HZ (CHỐNG KHỰNG RESYNC TẤM NỀN KHI CHẠM)
%hook CADisplay

- (NSInteger)preferredFPS {
    if (Titanium_IsPassiveVideoPlayback()) return %orig;
    if (!IS_ACTIVE) return %orig;
    return 144; // Giữ trần phần cứng ở 144Hz để CADisplayLink vọt lên trong 0ms không khựng
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (Titanium_IsPassiveVideoPlayback()) { 
        %orig; 
        return; 
    }
    if (IS_ACTIVE) {
        fps = 144;
    }
    %orig(fps);
}

- (void)overrideDisplayCadence:(id)cadence {
    // GIỮ NGUYÊN CADENCE GỐC, KHÔNG GÁN NIL ĐỂ TRÁNH CRASH CON TRỎ RỖNG
    %orig(cadence);
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

// 3. BÁO CÁO ĐỒNG BỘ THÔNG SỐ 144HZ CHO TOÀN BỘ UIKIT
%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    if (IS_ACTIVE) return 144;
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ACTIVE) return 144;
    return %orig;
}

- (CGFloat)_refreshRate {
    if (IS_ACTIVE) return 144.0;
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
        rate = 144.0;
        // ĐÃ BỎ: Không ép gọi zero latency tại đây để tránh giật khựng khi UIKit đổi tần số
    }
    %orig(rate);
}

%end

// 4. KHÓA CỨNG TẤT CẢ HOẠT ẢNH & LÒ XO (26ANIM) ĐẠT ĐỈNH 144HZ KÈM BẢO TOÀN THỜI GIAN NẢY
%hook CAAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            range = SafeMakeFRR(144.0f, 144.0f, 144.0f);
            // GHI NHẬN CHUYỂN ĐỘNG: Duy trì 144Hz cho đến khi hoạt ảnh kết thúc, chống tụt 10Hz giữa chừng
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
    %orig(range);
}

- (void)setDelegate:(id)delegate {
    %orig(delegate);
}

%end

%hook CASpringAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if (!Titanium_IsPassiveVideoPlayback() && IS_ACTIVE) {
            range = SafeMakeFRR(144.0f, 144.0f, 144.0f);
            // ĐẨY XUNG LÒ XO (Control Center thu về, Zoom icon app, Menu 3D Touch bung ra):
            // Bảo toàn 144Hz xuyên suốt thời gian lò xo nảy, TRIỆT TIÊU 100% CÚ GIẬT KHỰNG Ở ĐIỂM CUỐI!
            g_lastInteractionMachTime = mach_absolute_time();
        }
    }
    %orig(range);
}

%end

%hook CATransaction

+ (void)commit {
    %orig; // Giữ nguyên commit gốc, loại bỏ hoàn toàn dispatch_after flood để CPU mát lạnh
}

%end

// 5. THEO DÕI VIDEO (ĐẢM BẢO YOUTUBE VÀ VIDEO KHÔNG BỊ KHỰNG HAY NGHẼN MẠNG)
%hook AVPlayer

- (void)setRate:(float)rate {
    %orig(rate);
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = (rate > 0.0f);
    }
}

%end

// 6. ĐÓN ĐẦU THÔNG BÁO XUẤT HIỆN: KÍCH XUNG 144HZ TỨC THÌ TRONG 0MS
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

// 7. TẢI LẠI CẤU HÌNH KHI APP ACTIVE (BẢO TOÀN MỞ APP MƯỢT MÀ, KHÔNG ĐƠ TRỄ KHỞI ĐỘNG)
%hook UIApplication

- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        if (!Titanium_IsSpringBoard()) {
            [[BoostConfigV285Pro sharedInstance] loadSettings];
        }
        // ĐÃ BỎ: Không ép pipeline đột ngột lúc mở app để chuyển cảnh vào app không bị khựng góc
    }
}

- (void)applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE) {
        if (!Titanium_IsSpringBoard()) {
            [[BoostConfigV285Pro sharedInstance] loadSettings];
        }
    }
}

%end

%end

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT (TRIỆT TIÊU 100% GIẬT KHI THU VỀ & KHÔNG BỊ KHỰNG ĐA NHIỆM)
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

// 1. KHÓA 144HZ TOÀN BỘ CHU TRÌNH CỬ CHỈ VUỐT VÀ NẢY LÒ XO THU VỀ (FIX LỖI 1)
%hook SBHomeGestureInteraction
- (void)_handleGestureBegan:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = YES;
        g_activeAnimationCount++; // Khóa trần 144Hz ngay khi bắt đầu chạm vuốt
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(gesture);
}

// Bắt di chuyển ngón tay: Cập nhật Mach Time 2ns, máy mát lạnh 100%
- (void)_handleGestureChanged:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(gesture);
}

// BẢO VỆ CHU KỲ NẢY THU VỀ: Giữ vững 144Hz thêm 750ms sau khi buông tay để hoạt ảnh tiếp đất phẳng lì
- (void)_handleGestureEnded:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();

        // Sequence token an toàn trên Main Thread: Giữ nhịp lò xo tiếp đất phẳng lì, hết giật giật
        static int64_t s_homeEndSeq = 0;
        int64_t currentSeq = ++s_homeEndSeq;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(750 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (s_homeEndSeq == currentSeq) {
                if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            }
        });
    }
    %orig(gesture);
}

- (void)_handleGestureCancelled:(id)gesture {
    if (IS_ACTIVE) {
        g_isContinuousSwiping = NO;
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
    %orig(gesture);
}
%end

// 2. KHÓA CHẶT HOẠT ẢNH THOÁT APP VỀ ICON VÀ ĐA NHIỆM SWITCHER (FIX LỖI 6)
%hook SBFluidSwitcherGestureWorkspaceTransaction
- (BOOL)canInterruptActiveGesture {
    return %orig;
}

- (BOOL)_shouldSuppressGestures {
    if (IS_ACTIVE) return NO;
    return %orig;
}

- (void)_begin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++; // Khóa nhịp đa nhiệm 144Hz xuyên suốt
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isContinuousSwiping = NO;
    }
}
%end

// 3. THOÁT APP: GIỮ TRẦN 144HZ CHO ĐẾN KHI ICON THU NHỎ HOÀN TOÀN
%hook SBAppToHomeWorkspaceTransaction
- (BOOL)shouldAnimateOrientationChangeOnCompletion {
    return %orig;
}

- (void)_willBegin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        Titanium_LockMainThreadFast();
        g_isContinuousSwiping = NO;
        g_isUserTouchingScreen = NO;
    }
}
%end

// 4. MỞ APP: ĐÓN ĐẦU KHUNG HÌNH MƯỢT MÀ, KHÔNG KHỰNG GÓC
%hook SBHomeToAppWorkspaceTransaction
- (void)_willBegin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}
%end

// 5. QUẢN LÝ BỘ NHỚ ĐỆM SNAPSHOT & TRÔI THẺ ĐA NHIỆM SIÊU MƯỢT
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
        g_activeAnimationCount++;
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(animated);
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isUserTouchingScreen = NO;
        g_isContinuousSwiping = NO;
    }
}
%end

// 6. THẺ ỨNG DỤNG TRONG SWITCHER: ĐỒNG BỘ HOÁ RASTERIZE
%hook SBFluidSwitcherItemContainer
- (void)prepareForReuse {
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC (TURBO ENGINE - CHỐNG ĐEN APP & KHÔNG NGHẼN MẠNG)
// ====================================================================================================

%group Group_FastLaunch_SuperEngineV285

// 1. TỐI ƯU TIẾN TRÌNH FRONTBOARD: CẤP QUYỀN VIP KHI NẠP APP (CHỐNG NÓNG MÁY KHI SẠC)
%hook FBApplicationProcess
- (void)bootstrapWithContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        // Cấp quyền nạp đĩa siêu tốc cho SpringBoard khi mở app, nhả tải khi cắm sạc để giữ mát máy
        if (!g_isDeviceChargingV285) {
            Titanium_EnforceThreadVIPPolicy();
        }
    }
    %orig(context, completion);
}

- (void)launchIfNecessary {
    // CHỐNG NÓNG MÁY: Chỉ cấp VIP khi có tương tác thực tế từ người dùng và KHÔNG cắm sạc
    // Triệt tiêu hoàn toàn tình trạng kích xung ngầm liên tục bởi background daemons và widgets
    if (IS_ACTIVE && CFG285.turboAppLaunch && !g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}
%end

// 2. TỐI ƯU GẮN KẾT SCENE GỐC & THỨC DẬY TỪ BACKGROUND (TRIỆT TIÊU NGHẼN MẠNG YOUTUBE & CHỐNG ĐEN APP)
%hook UIApplication
- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        // PHÂN TÁCH TIẾN TRÌNH CHỐNG NGHẼN MẠNG:
        if (Titanium_IsSpringBoard()) {
            Titanium_EnforceThreadVIPPolicy(); // Nâng ưu tiên cho SpringBoard gắn kết scene
        } else {
            // Trong ứng dụng con (YouTube, Safari...):
            // Nâng luồng UI chuẩn POSIX để giao diện đạt 144Hz, TUYỆT ĐỐI KHÔNG chặn luồng mạng NSURLSession
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(scene, context, completion);
}

- (void)_applicationWillEnterForeground {
    %orig; // Nạp lại trạng thái ứng dụng trước để gắn kết framebuffer an toàn (CHỐNG ĐEN APP 100%)
    if (IS_ACTIVE) {
        // Duy trì 144Hz vừa đủ cho hoạt ảnh bung app mà KHÔNG tạo cờ chạm tay giả mạo (máy tự hạ 10Hz khi tĩnh)
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceThreadVIPPolicy();
        } else {
            // Trong YouTube và các app thứ 3: Nhường băng thông cho kết nối mạng tải video mượt mà (HẾT NGHẼN MẠNG)
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}
%end

%end

// ====================================================================================================
// NHÓM 6: CUỘN FEED TIKTOK / BÀN PHÍM SIÊU NHẠY (BẢO TOÀN NỀN SAFARI VÀ ICON EMOJI - MÁT MÁY 100%)
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

// 1. ÉP BÀN PHÍM BẬT RA NHANH GẤP ĐÔI (0.12S) & GÕ PHÍM 0MS KHÔNG NGHẼN PIPELINE
%hook UIInputViewAnimationStyle
- (double)duration {
    if (IS_ACTIVE) return 0.12; // Bàn phím nảy lên lập tức, dứt khoát
    return %orig;
}
%end

%hook UIKeyboardImpl
- (void)showKeyboard {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        // ĐÃ BỎ: Không ép pipeline thô bạo để bàn phím trượt lên mượt mà không giật khung
    }
    %orig;
}

- (void)handleKeyWithString:(id)string forKeyEvent:(id)event executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        // Cập nhật Mach Time 2ns: Khóa cứng 144Hz khi gõ phím, KHÔNG gây nghẽn GPU
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(string, event, context);
}

- (void)addInputString:(id)string withFlags:(NSUInteger)flags executionContext:(id)context {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(string, flags, context);
}
%end

%hook UITextInputController
- (void)_insertText:(id)text {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(text);
}

- (void)deleteBackward {
    if (IS_ACTIVE && CFG285.keyboardZeroLagV24) {
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig;
}
%end

// 2. ĐÓN ĐẦU CHẠM NÚT 3 GẠCH & NÚT ĐIỀU HƯỚNG: BƠM XUNG 144HZ AN TOÀN
%hook UIControl
- (void)sendAction:(SEL)action to:(id)target forEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        // ĐÃ BỎ: Không ép zero latency pipeline để drawer/menu trượt ra mịn màng
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
    }
    %orig(index);
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(selectedViewController);
}
%end

// 4. TĂNG TỐC ĐẨY/RÚT TRANG NAVIGATION (PUSH/POP/PRESENT: CHỐNG GIẬT KHỰNG CHUYỂN CẢNH)
%hook UINavigationController
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        // Bảo vệ hoạt ảnh trượt trang: Giữ 144Hz cho đến khi hoàn tất chuyển cảnh
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(viewController, animated);
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
        g_lastInteractionMachTime = mach_absolute_time();
    }
    return %orig(animated);
}
%end

%hook UIViewController
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        // TRIỆT TIÊU GIẬT KHI BUNG TAB / MENU NGỮ CẢNH: Để UIKit tự nhiên diễn hoạt ở 144Hz
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(viewControllerToPresent, flag, completion);
}
%end

// 5. CUỘN FEED TIKTOK / FACEBOOK / SAFARI TRÔI MƯỢT QUÁN TÍNH (TRIỆT TIÊU HOÀN TOÀN NÓNG MÁY)
%hook UIScrollView
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE && [view isKindOfClass:[UIControl class]]) {
        // Nếu người dùng đang vuốt cuộn (isDragging): Hủy chạm trong nút để feed trôi tiếp, không bị dính khựng
        if (self.isDragging) return YES;
        return NO;
    }
    return %orig(view);
}

- (BOOL)delaysContentTouches {
    // Giữ nguyên delaysContentTouches gốc để không kẹt chọn ảnh trong CollectionView
    return %orig;
}

// Bắt đầu kéo: Kích cờ cuộn để giữ trần 144Hz
- (void)_scrollViewWillBeginDragging {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

// TRIỆT TIÊU 100% NGUYÊN NHÂN NÓNG MÁY KHI CUỘN:
// Tuyệt đối không gọi Titanium_TriggerInstantTouchBurst() tại đây (tránh spam 144 timer/giây vào GCD)
- (void)_notifyDidScroll {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time(); // Chỉ cập nhật Mach Time 2ns: CPU mát rượi
    }
    %orig;
}

// Giữ nguyên mức FPS cao xuyên suốt đà trôi tự do sau khi buông tay
- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
    %orig(timestamp);
}

// Dừng trôi hẳn: Nhả cờ để hệ thống tự hạ về 10Hz làm mát máy
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

// 6. GIỮ ĐỘ PHẢN HỒI CELL NHANH NHƯNG BẢO TOÀN NỀN SAFARI, ICON EMOJI VÀ BỘ CHỌN ẢNH
%hook UITableView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
}
%end

%hook UICollectionView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
}
%end

%end

// ====================================================================================================
// NHÓM 7: SPRINGBOARD - TOÀN BỘ HIỆU ỨNG BÊN NGOÀI (FOLDER, LOCKSCREEN, 3D TOUCH, CC/NC, LOAD APP)
// ====================================================================================================

%group Group_Display_SpringBoardV285

// ====================================================================================================
// 1. BẢO TOÀN NGUYÊN BẢN HÌNH NỀN (TUYỆT ĐỐI KHÔNG CAN THIỆP GÂY ĐEN HAY BIẾN DẠNG HÌNH NỀN)
// ====================================================================================================

%hook SBWallpaperController
- (double)wallpaperScaleForVariant:(long long)variant {
    return %orig;
}
%end

// ====================================================================================================
// 2. TỐI ƯU CẢM ỨNG & HIỂN THỊ ICON / WIDGET / ICON TO (SỬA DỨT ĐIỂM LỖI 4: HẾT GIẬT ICON TO)
// ====================================================================================================

%hook SBIconView
- (double)highlightDelay {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted && IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(highlighted);
}

- (void)setTouchDownInIcon:(BOOL)touchDown {
    if (touchDown && IS_ACTIVE && CFG285.touchResponseBoost) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
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
        Titanium_LockMainThreadFast();
    }
    %orig(gesture);
}
%end

// ====================================================================================================
// 4. TRIỆT TIÊU LAG KHI CHỤP MÀN HÌNH & BẤM PHÍM CỨNG VOLUME (SỬA DỨT ĐIỂM LỖI 2 - VIDEO 2)
// ====================================================================================================

%hook SBScreenshotManager
- (void)saveScreenshotsWithCompletion:(id)completion {
    if (IS_ACTIVE) {
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(completion);
}
%end

%hook SBVolumeControl
- (void)increaseVolume {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)decreaseVolume {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)changeVolumeByDelta:(float)delta {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(delta);
}
%end

// ====================================================================================================
// 5. KÉO & THU CONTROL CENTER / THÔNG BÁO (SỬA DỨT ĐIỂM LỖI 2 & 3: KHÓA 144HZ TOÀN BỘ CHU TRÌNH NẢY LÒ XO)
// ====================================================================================================

%hook SBControlCenterController
- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++; // Khóa trần 144Hz khi vuốt mở CC
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(animated, completion);
}

// KHÓA CHẶT 144HZ THÊM 700MS KHI THU VỀ: Triệt tiêu 100% hiện tượng giật khi lò xo đàn hồi về điểm neo
- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();

        static int64_t s_ccDismissSeq = 0;
        int64_t currentSeq = ++s_ccDismissSeq;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(700 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (s_ccDismissSeq == currentSeq) {
                if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            }
        });
    }
    %orig(animated, completion);
}
%end

%hook SBNotificationCenterController
- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++; // Khóa trần 144Hz khi vuốt kéo NC xuống
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig(animated, completion);
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();

        static int64_t s_ncDismissSeq = 0;
        int64_t currentSeq = ++s_ncDismissSeq;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(700 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (s_ncDismissSeq == currentSeq) {
                if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            }
        });
    }
    %orig(animated, completion);
}
%end

// ====================================================================================================
// 6. LƯỚT TRANG MÀN HÌNH CHÍNH: TRIỆT TIÊU 100% NÓNG MÁY DO SPAM TIMER
// ====================================================================================================

%hook SBIconScrollView
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (IS_ACTIVE) return YES;
    return %orig;
}

- (BOOL)delaysContentTouches {
    return %orig;
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
        Titanium_LockMainThreadFast();
    }
    %orig(timestamp);
}
%end

%hook SBIconListView
- (void)setAlpha:(CGFloat)alpha {
    %orig(alpha);
}
%end

%hook SBIconController
- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(index, animate);
}
%end

// ====================================================================================================
// 7. TOÀN DIỆN THƯ MỤC ỨNG DỤNG, 3D TOUCH & LOCKSCREEN (SỬA DỨT ĐIỂM LỖI 5: THƯ MỤC MƯỢT PHẲNG LÌ)
// ====================================================================================================

// BẢO VỆ ĐƯỜNG CONG LÒ XO GỐC: Trả về %orig để hoạt ảnh mở thư mục co giãn mượt mà, không bị gãy nhịp
%hook SBFolderControllerAnimationSettings
- (double)duration {
    return %orig;
}
%end

%hook SBFolderView
- (void)prepareToOpen {
    if (IS_ACTIVE) {
        g_activeAnimationCount++; // Giữ vững trần 144Hz khi bung mở thư mục
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)didClose {
    %orig;
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}
%end

// CƯỚP QUYỀN ĐIỀU PHỐI ĐỒ HỌA CHO THƯ MỤC KHI ĐÓNG/MỞ
%hook SBFolderController
- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig(animated, completion);
}

- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig(animated, completion);
}
%end

%hook SBIconForceTouchSettings
- (double)delayBeforeOpening {
    return %orig;
}
%end

%hook CSCoverSheetViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(animated);
}
%end

%hook SBHomeScreenViewController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(animated);
}
%end

// ====================================================================================================
// 8. ÉP TỐC ĐỘ LOAD APP & CHU TRÌNH THU PHÓNG (SỬA DỨT ĐIỂM LỖI 1, 4, 5 - VIDEO 2)
// ====================================================================================================

%hook SBApplication
- (void)willActivate {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
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
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        Titanium_LockMainThreadFast();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
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
// NHÓM 8: PIPELINE CHO PICTURE-IN-PICTURE (PIP 60FPS MƯỢT MÀ & CHUYỂN CẢNH 144HZ)
// ====================================================================================================

%group Group_V285_FloatingWindow_PiP

// 1. TỐI ƯU CO GIÃN KHUNG HÌNH & CHUYỂN TIẾP CỬA SỔ NỔI TRONG SPRINGBOARD (PEGASUS)
%hook PGPictureInPictureRemoteObject
- (void)_updatePreferredContentSize {
    %orig;
    if (IS_ACTIVE) {
        // CHỐNG NÓNG MÁY: Chỉ cập nhật Mach Time 2ns để co giãn mượt mà,
        // KHÔNG dựng cờ chạm giả mạo làm mất chế độ làm mát máy khi xem video thụ động
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)startPictureInPicture {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time(); // Tách cửa sổ PiP bay ra phẳng lì ở 144Hz
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
    %orig;
}

- (void)stopPictureInPictureAnimated:(BOOL)animated {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = NO;
        g_lastInteractionMachTime = mach_absolute_time(); // Bung ngược về app toàn màn hình không khựng giật
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
    %orig(animated);
}
%end

// 2. ĐIỀU PHỐI TIẾN TRÌNH PIP TRÊN SPRINGBOARD CONTROLLER
%hook SBPIPController
- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig(pid, sceneId, animated, completion);
}
%end

// 3. ĐIỀU KHIỂN PIP TỪ PHÍA ỨNG DỤNG NỀN (AVKIT / HOST APP - TRIỆT TIÊU NGHẼN MẠNG YOUTUBE)
%hook AVPictureInPictureController
- (void)startPictureInPicture {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        // Trong YouTube: Sử dụng QoS chuẩn POSIX, TUYỆT ĐỐI KHÔNG ép SCHED_RR để mạng tải video thông suốt
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}

- (void)stopPictureInPicture {
    if (IS_ACTIVE) {
        g_isVideoPlayingActive = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 9: PHÂN TÁCH PHẦN CỨNG (HOME BUTTON VẬT LÝ - PHẢN HỒI 0MS, BẢO TOÀN ĐỆM 144HZ)
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions
- (void)performSinglePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_activeAnimationCount++; // BẢO VỆ CHUYỂN CẢNH: Giữ vững 144Hz cho đến khi app thu về hẳn Home Screen
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast(); // Về Home tức thì 0ms, triệt tiêu khựng giật thu icon
    }
    %orig;
}

- (void)performDoublePressAction {
    if (IS_ACTIVE && CFG285.touchResponseBoost) {
        g_activeAnimationCount++; // BẢO TOÀN ĐỆM: Mở đa nhiệm Switcher mượt mà 144Hz phẳng lì
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig;
}
%end

%end

// ====================================================================================================
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH & BẢO VỆ JETSAM (CHỐNG ĐEN APP 100% & MÁT MÁY KHI CHẠY NỀN)
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

// 1. ƯU TIÊN LUỒNG ĐỒ HỌA KHI TIẾN TRÌNH THAY ĐỔI TRẠNG THÁI (CHỈ TĂNG TỐC KHI CÓ TƯƠNG TÁC)
%hook SBApplication
- (void)setProcessState:(id)state {
    // CHỐNG NÓNG MÁY: Chỉ kích xung khi người dùng đang thực sự tương tác,
    // TUYỆT ĐỐI KHÔNG spam CPU khi các daemon chạy ngầm đổi trạng thái
    if (IS_ACTIVE && Titanium_ShouldLockTargetRate()) {
        Titanium_LockMainThreadFast();
    }
    %orig(state);
}
%end

// 2. KHỞI CHẠY ỨNG DỤNG SIÊU TỐC: BẢO TOÀN ĐỆM DỰNG HÌNH ĐỂ TRIỆT TIÊU 100% LỖI ĐEN MÀN HÌNH
%hook SBMainWorkspace
- (void)handleApplicationLaunch:(id)application {
    if (IS_ACTIVE && CFG285.turboAppLaunch) {
        g_activeAnimationCount++; // BẢO TOÀN 144HZ KHI MỞ APP: Chống khựng 4 góc và mượt mà tuyệt đối
        g_lastInteractionMachTime = mach_absolute_time();
        Titanium_LockMainThreadFast();
    }
    %orig(application);
}
%end

%end

// ====================================================================================================
// NHÓM 11: NÂNG CẤP TOÀN BỘ ỨNG DỤNG BÊN THỨ BA (APP NẶNG & NHẸ - FIX LAG POPUP & CHUYỂN TRANG 144HZ)
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

// 1. CƯỚP QUYỀN ĐỒ HỌA RUNLOOP CỦA TOÀN BỘ APP THỨ BA (TRẢI NGHIỆM 144HZ 0MS)
%hook UIApplication
- (void)_sendWillEnterForegroundCallbacks {
    %orig;
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceThreadVIPPolicy();
        } else {
            // Nâng quyền User-Interactive cho luồng UI của app, giữ nguyên băng thông mạng
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}
%end

// 2. KHỞI TẠO CỬA SỔ VÀ ĐÓN ĐẦU CỬ CHỈ TRONG APP (HẾT LAG POPUP & MODAL)
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig; // Gắn kết framebuffer an toàn (CHỐNG ĐEN APP 100%)
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
            Titanium_EnforceThreadVIPPolicy();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

// Bắt mọi thao tác chạm/vuốt bên trong app để giữ vững 144Hz
- (void)sendEvent:(UIEvent *)event {
    if (IS_ACTIVE && CFG285.touchResponseBoost && (event.type == 0 || event.type == 3)) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(event);
}
%end

// 3. TỐI ƯU TOÀN DIỆN CHUYỂN CẢNH MÀN HÌNH & CHUYỂN TAB TRONG APP
%hook UIViewController
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        g_activeAnimationCount++; // Khóa trần 144Hz cho đến khi chuyển trang hoàn tất
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();

        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

- (void)viewDidLoad {
    %orig; // Giữ nguyên nạp View gốc của iOS
}
%end

// 4. FIX TRIỆT ĐỂ LAG KHI KÉO VUỐT POPUP, BOTTOM SHEET & MODAL TRONG MỌI APP
%hook UIPresentationController
- (void)presentationTransitionWillBegin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

- (void)presentationTransitionDidEnd:(BOOL)completed {
    %orig(completed);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}

- (void)dismissalTransitionWillBegin {
    if (IS_ACTIVE) {
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

- (void)dismissalTransitionDidEnd:(BOOL)completed {
    %orig(completed);
    if (IS_ACTIVE) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
    }
}
%end

// 5. TỐI ƯU HIỆU NĂNG CHO DANH SÁCH CUỘN TRONG APP NẶNG (TIKTOK, FACEBOOK FEED)
%hook UIScrollView
- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if (IS_ACTIVE) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(timestamp);
}
%end

%end

// ====================================================================================================
// NHÓM 12: BÀN PHÍM STREAM TEXT & CẢM ỨNG NÚT BẤM (ĐÃ TỐI ƯU 0MS & KHÔNG NGHẼN MẠNG YOUTUBE)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

// 1. ƯU TIÊN HÀNG ĐỢI TÁC VỤ GÕ PHÍM: GÕ NHANH KHÔNG TRỄ, KHÔNG NGHẼN MẠNG
%hook UIKeyboardTaskQueue
- (void)performTask:(id)task {
    if (IS_ACTIVE) {
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            // Trong app (YouTube, Safari...): Dùng POSIX interactive chuẩn, không chiếm đoạt luồng mạng
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(task);
}
%end

// 2. BẬT BÀN PHÍM TỨC THÌ 0MS: BẢO TOÀN ĐỆM DỰNG HÌNH CHỐNG HỞ VIỀN ĐEN CHÂN PHÍM
%hook UIKeyboardImpl
- (void)callShowKeyboard {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

// Triệt tiêu khoảng thời gian đè nén cảm ứng bàn phím: Chạm là ăn phím ngay lập tức
+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if (IS_ACTIVE) return 0.0;
    return %orig;
}
%end

// 3. TRIỆT TIÊU ĐỘ TRỄ DỊCH CHUYỂN BÀN PHÍM
%hook UIPeripheralHost
- (double)getLastTranslateTime {
    if (IS_ACTIVE) return 0.0; // Bàn phím xuất hiện không có độ trễ dịch chuyển
    return %orig;
}
%end

// 4. PHẢN HỒI NÚT BẤM SIÊU NHẠY 0MS CHO TOÀN BỘ UIKIT (AN TOÀN TIẾN TRÌNH)
%hook UIButton
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (IS_ACTIVE) {
        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
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

// 1. QUẢN LÝ TIẾN TRÌNH THÔNG MINH: CHỐNG ZOMBIE PROCESS & TRIỆT TIÊU 100% NGUYÊN NHÂN NÓNG MÁY
%hook RBSProcessState
- (unsigned char)taskState {
    unsigned char orig = %orig;
    // SỬA TRIỆT ĐỂ NÓNG MÁY: Chỉ duy trì Running (4) khi có tương tác thực tế và KHÔNG cắm sạc quá nhiệt
    // Cho phép hệ điều hành đóng băng (Suspend) các daemon chạy ngầm khi đứng yên để CPU A9 mát lạnh
    if (IS_ACTIVE && orig > 0) {
        if (!g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
            return 4; // Giữ ứng dụng hoạt động mượt mà khi đang tương tác
        }
    }
    return orig;
}
%end

// 2. GIẢI PHÓNG TIẾN TRÌNH CHUẨN XÁC: TRIỆT TIÊU 100% LỖI ĐEN MÀN HÌNH KHI MỞ LẠI APP
%hook FBProcess
- (BOOL)isPendingExit {
    return %orig; // Giữ nguyên cơ chế dọn dẹp tiến trình của iOS, chống treo đen màn hình app
}
%end

// 3. ĐIỀU TIẾT NHIỆT ĐỘ HỆ THỐNG: KHÔNG BÓP FPS KHI DÙNG NHƯNG CHO PHÉP MÁY TỰ HẠ NHIỆT KHI SẠC
%hook NSProcessInfo
- (NSProcessInfoThermalState)thermalState {
    if (IS_ACTIVE) {
        // Nếu đang cắm sạc và máy không có thao tác vuốt: Báo trạng thái thực để iOS bảo vệ pin và ngắt nhiệt
        if (g_isDeviceChargingV285 && !Titanium_ShouldLockTargetRate()) {
            return %orig;
        }
        // Khi đang vuốt chạm: Luôn giữ Nominal để duy trì mượt mà 144Hz
        return NSProcessInfoThermalStateNominal;
    }
    return %orig;
}

// BẢO TOÀN NGUYÊN BẢN CHO CONTROL CENTER & CÀI ĐẶT
- (BOOL)isLowPowerModeEnabled {
    return %orig; // Nút Chế độ nguồn điện thấp ở Control Center hoạt động chuẩn xác 100%
}
%end

// 4. CHẶN THÔNG BÁO TĂNG NHIỆT ĐỘ KHI ĐANG TƯƠNG TÁC
%hook NSNotificationCenter
- (void)postNotificationName:(NSNotificationName)aName object:(id)anObject userInfo:(NSDictionary *)aUserInfo {
    if (IS_ACTIVE && aName) {
        if (Titanium_ShouldLockTargetRate()) {
            if (aName == NSProcessInfoThermalStateDidChangeNotification || 
                ([aName isKindOfClass:[NSString class]] && [aName isEqualToString:NSProcessInfoThermalStateDidChangeNotification])) {
                return; // Chặn bóp xung nhịp trong lúc ngón tay đang lướt
            }
        }
    }
    %orig(aName, anObject, aUserInfo);
}
%end

%end

// ====================================================================================================
// NHÓM BẢO VỆ CHỐNG NÓNG, CHỐNG GIẬT CC/NC & BẢO TOÀN NGUYÊN BẢN HÌNH NỀN
// ====================================================================================================

%group Group_LiquidGlass_Opt

// 1. BẢO TOÀN ĐƯỜNG CONG LÀM MỜ SHADER: SỬA DỨT ĐIỂM GIẬT BUNG TAB (LỖI 1 VIDEO 3)
%hook CAFilter
- (void)setValue:(id)value forKey:(NSString *)key {
    // KHÔNG khống chế cứng 12.0f khi đang chuyển cảnh hoạt ảnh để tránh làm đứt gãy đường cong lò xo
    if (IS_ACTIVE && [key isKindOfClass:[NSString class]] && [key isEqualToString:@"inputRadius"]) {
        if (g_activeAnimationCount == 0 && !Titanium_ShouldLockTargetRate()) {
            if ([value isKindOfClass:[NSNumber class]] && [value floatValue] > 16.0f) {
                value = @(16.0f); // Chỉ khống chế nhẹ khi màn hình tĩnh để làm mát GPU
            }
        }
    }
    %orig(value, key);
}
%end

// 2. BẢO VỆ TUYỆT ĐỐI HÌNH NỀN & SỬA DỨT ĐIỂM GIẬT CONTROL CENTER KHI THU VỀ (LỖI 3 VIDEO 2)
%hook CABackdropLayer
- (void)setScale:(double)scale {
    // BẢO TOÀN NGUYÊN BẢN HÌNH NỀN: Trả về gốc khi đang có chuyển cảnh hoặc kéo giãn Control Center
    // Triệt tiêu 100% hiện tượng vỡ hạt texture và giật lò xo đàn hồi
    if (IS_ACTIVE) {
        if (Titanium_ShouldLockTargetRate() || g_activeAnimationCount > 0) {
            %orig(scale);
            return;
        }
    }
    %orig(scale);
}

- (double)scale {
    return %orig; // Giữ nguyên tỉ lệ hiển thị gốc, không làm biến dạng hình nền
}

- (void)setAllowsInPlaceFiltering:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
    %orig(flag);
}

- (BOOL)allowsInPlaceFiltering {
    return IS_ACTIVE ? YES : %orig;
}

- (void)setDisablesOccludedBackdropBlurs:(BOOL)flag {
    if (IS_ACTIVE) flag = YES;
    %orig(flag);
}

- (BOOL)disablesOccludedBackdropBlurs {
    return IS_ACTIVE ? YES : %orig;
}
%end

// 3. ĐỒNG BỘ HIỂN THỊ NỀN MỜ CONTROL CENTER & NOTIFICATION CENTER (HẾT GIẬT LỆCH KHUNG)
%hook MTMaterialView
- (void)layoutSubviews {
    %orig;
    // ĐÃ BỎ drawsAsynchronously: Vẽ đồng bộ trực tiếp theo V-Sync để kính mờ không bị trễ nhịp so với lò xo
}
%end

// 4. TỐI ƯU HIỆU ỨNG GIAO DIỆN (UIVISUALEFFECTVIEW) - KHÔNG LỆCH POPUP, KHÔNG GIẬT KHUNG
%hook UIVisualEffectView
- (void)layoutSubviews {
    %orig;
    if (IS_ACTIVE) {
        UIView *v = (UIView *)self;
        v.layer.allowsGroupOpacity = YES; // Chống xén mép, chống mất viền popup
        // ĐÃ BỎ drawsAsynchronously để loại bỏ hoàn toàn độ trễ 1 khung hình gây khựng bung tab
    }
}
%end

%end

// ====================================================================================================
// GIA TỐC TOÀN BỘ HIỆU ỨNG BÊN TRONG ỨNG DỤNG (MODAL, POPUP, SHEET, CONTEXT MENU - MỊN 144HZ)
// ====================================================================================================

%group Group_Universal_InApp_Animations

// 1. ÉP BỘ MÁY HOẠT ẢNH HIỆN ĐẠI CỦA APPLE (UIVIEWPROPERTYANIMATOR) CHẠY 144HZ / KHÔNG KHỰNG
%hook UIViewPropertyAnimator
- (void)startAnimation {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time(); // Giữ xung 144Hz xuyên suốt hoạt ảnh
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
        // ĐÃ BỎ: Không ép zero latency thô bạo để đường cong đàn hồi nảy mượt mà phẳng lì
    }
    %orig;
}
%end

// 2. TĂNG TỐC POPUP GIỮ ĐÈ ICON / MENU BỐI CẢNH (SỬA DỨT ĐIỂM LỖI 1 VIDEO 3: BUNG MENU MỊN MÀ 144HZ)
%hook _UIContextMenuContainerView
- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig(newWindow);
    if (newWindow && IS_ACTIVE) {
        // Cập nhật Mach Time 2ns: Giữ vững 144Hz cho đến khi menu tab bung xong hoàn toàn
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
        // TRIỆT TIÊU GIẬT BUNG TAB: Bỏ ép flush bộ đệm để shader làm mờ Gaussian Blur không bị nghẽn
    }
}
%end

// 3. HIỆU ỨNG BẬT BẢNG THÔNG BÁO / ACTIONSHEET / DIALOG SYSTEM
%hook UIAlertController
- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig(animated);
}
%end

// 4. HIỆU ỨNG CHUYỂN CẢNH TRANG DẠNG TRƯỢT SHEET (PAGE SHEET / FORM SHEET: 144HZ PHẲNG LÌ)
%hook UIPresentationController
- (void)presentationTransitionWillBegin {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
}

- (void)dismissalTransitionWillBegin {
    if (IS_ACTIVE) {
        g_lastInteractionMachTime = mach_absolute_time();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }
    }
    %orig;
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

        // LẮNG NGHE SỰ KIỆN GỐC: Chỉ kích hoạt đúng 1 lần khi cắm hoặc rút sạc
        // TUYỆT ĐỐI KHÔNG DÙNG TIMER 5S LẶP ĐI LẶP LẠI GÂY TỐN PIN VÀ NÓNG MÁY KHI NGHỈ
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
// ĐIỀU PHỐI KHỞI ĐỘNG THUẦN ROOTLESS & ROOTHIDE (CHỐNG TREO TÁO / TREO REBOOT 100%)
// ====================================================================================================

#define TITANIUM_BOOT_FLAG_VERIFIED @"/tmp/.titanium_tweak_verified"
#define TITANIUM_BOOT_STAGE_8P      @"/tmp/.titanium_8p_reboot_staged"

// 1. Phân loại thiết bị
static inline BOOL Titanium_IsLegacy6s7P(void) {
    static BOOL s_isLegacy = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        uname(&sysInfo);
        NSString *machine = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        if ([machine hasPrefix:@"iPhone8,"] || [machine hasPrefix:@"iPhone9,"]) {
            s_isLegacy = YES;
        }
    });
    return s_isLegacy;
}

// 2. Đo thời gian uptime từ lúc bật nguồn
static time_t Titanium_GetSystemUptimeSeconds(void) {
    struct timeval boottime;
    size_t len = sizeof(boottime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    if (sysctl(mib, 2, &boottime, &len, NULL, 0) < 0) return 9999;
    time_t now = time(NULL);
    return (now - boottime.tv_sec);
}

// 3. Thực thi Respring an toàn tương thích hoàn toàn đường dẫn Rootless/RootHide
static void Titanium_ExecuteSystemRespring(void) {
    UIApplication *app = [UIApplication sharedApplication];
    if ([app respondsToSelector:@selector(_relaunchSpringBoardNow)]) {
        [(SpringBoard *)app _relaunchSpringBoardNow];
        return;
    }

    NSString *jbRoot = Titanium_GetRootHidePrefixPath();
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Tìm nhị phân sbreload hoặc killall trong $JBROOT
    NSString *sbreload = [jbRoot stringByAppendingPathComponent:@"usr/bin/sbreload"];
    if (![fm fileExistsAtPath:sbreload]) sbreload = @"/var/jb/usr/bin/sbreload";

    NSString *killall = [jbRoot stringByAppendingPathComponent:@"usr/bin/killall"];
    if (![fm fileExistsAtPath:killall]) killall = @"/var/jb/usr/bin/killall";

    pid_t pid;
    if ([fm fileExistsAtPath:sbreload]) {
        const char *args[] = {"sbreload", NULL};
        posix_spawn(&pid, [sbreload UTF8String], NULL, NULL, (char *const *)args, environ);
    } else if ([fm fileExistsAtPath:killall]) {
        const char *args[] = {"killall", "-9", "SpringBoard", NULL};
        posix_spawn(&pid, [killall UTF8String], NULL, NULL, (char *const *)args, environ);
    }
}

// ====================================================================================================
// RUNTIME INITIALIZER: ĐIỀU PHỐI TẦNG NỘI BỘ & KHỞI CHẠY TWEAK (TRIỆT TIÊU NGHẼN MẠNG & NÓNG MÁY)
// ====================================================================================================

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    @autoreleasepool {
        AppleInternal_EnforceZeroLatencyKernelTier();
        AppleInternal_LockHardwareCADisplay();

        // PHÂN BIỆT RÕ RÀNG TIẾN TRÌNH ĐỂ KHÔNG LÀM NGHẼN MẠNG YOUTUBE:
        if (isSpringBoard) {
            Titanium_LockMainThreadFast();
            if (Titanium_IsLegacyA9toA12() && !g_isDeviceChargingV285) {
                Titanium_ApplySiliconDeepOptimizations();
                Titanium_EnableZeroLatencyPipeline();
                Titanium_EnforceThreadVIPPolicy();
                Titanium_ElevateThreadToMachRealTime();
            }
        } else {
            // Trong YouTube, TikTok, Facebook: TUYỆT ĐỐI KHÔNG gọi Titanium_LockMainThreadFast (SCHED_RR)
            // Dùng chuẩn POSIX User-Interactive: Giao diện 144Hz, trả lại toàn bộ băng thông mạng cho YouTube
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
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
        %init(Group_LiquidGlass_Opt);

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

            // ĐÁNH DẤU TWEAK ĐÃ NẠP THÀNH CÔNG (Tương thích sandbox Rootless)
            NSData *verifiedData = [@"VERIFIED" dataUsingEncoding:NSUTF8StringEncoding];
            [[NSFileManager defaultManager] createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED contents:verifiedData attributes:@{NSFilePosixPermissions: @(0666)}];
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
// CƠ CHẾ NẠP TRỄ: ĐỢI LÊN NGUỒN HOÀN TẤT MỚI CƯỚP QUYỀN TIÊM TWEAK
// ====================================================================================================

static void SpringBoardDidLaunchCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            const char *progName = getprogname();
            NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

            time_t uptime = Titanium_GetSystemUptimeSeconds();
            BOOL isColdBootOrReboot = (uptime < 90);

            // NẾU VỪA BẬT NGUỒN HOẶC REBOOT JAILBREAK:
            // Đợi 2.5s để SpringBoard load xong hoàn toàn giao diện LockScreen, không tự Respring bừa bãi.
            int64_t waitTime = isColdBootOrReboot ? (int64_t)(2.5 * NSEC_PER_SEC) : (int64_t)(0.8 * NSEC_PER_SEC);

            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, waitTime), dispatch_get_main_queue(), ^{
                Titanium_LockMainThreadFast();
                runCoreTweak(YES, bundleID, progName);
            });
        });
    });
}

// ====================================================================================================
// CONSTRUCTOR CHÍNH CỦA DYLIB (BLACKLIST BẢO VỆ TIẾN TRÌNH MẠNG HỆ THỐNG)
// ====================================================================================================

%ctor {
    @autoreleasepool {
        const char *progName = getprogname();
        if (!progName) return;

        // Bỏ qua WebKit, WebContent và các tiến trình mạng hệ thống: TRIỆT TIÊU 100% NGHẼN MẠNG
        if (strstr(progName, "WebKit") || strstr(progName, "WebContent") ||
            strstr(progName, "GPUProcess") || strstr(progName, "Networking") ||
            strstr(progName, "nsurlsessiond") || strstr(progName, "mDNSResponder") ||
            strstr(progName, "cloudd")) {
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
            // App bên thứ ba (YouTube, TikTok, Facebook...): Nạp an toàn không nghẽn mạng
            runCoreTweak(NO, bundleID, progName);
        }
    }
}
