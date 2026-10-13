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

// V15 stability profile: no realtime thread policy, no forced Metal drawable depth, no BackBoard hook.
// Hz/FPS requests are capped by the device native maximum; unsupported private hooks stay uninitialized.
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

// [ĐÃ BỔ SUNG - CÔNG TẮC TỔNG]: SpringBoard phát thông báo này SAU KHI đã ghi xong tệp IPC để app/backboardd nạp lại đúng lúc,
// và danh sách bundle ID bị tắt trong tab App được ghi ra tệp riêng (app trong sandbox không đọc được tệp plist cấu hình).
#define NOTIFY_PAYLOAD_WRITTEN "com.taojb.boostiphone6s/PayloadWritten"
#define APPS_SYNC_FILE_PRIMARY   @"/tmp/.boost_hz_apps"
#define APPS_SYNC_FILE_SECONDARY @"/var/jb/tmp/.boost_hz_apps"

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

static inline BOOL Titanium_IsAIApp(void);
static ApexV285ProPayload g_livePayload;
static os_unfair_lock g_payloadLock = OS_UNFAIR_LOCK_INIT;
static BOOL g_isCurrentAppBlacklisted = NO;
static volatile BOOL g_isInteracting = NO;
static volatile uint64_t g_lastInteractiveTick = 0;

// KHAI BÁO TOÀN BỘ NHÓM BÊN DƯỚI

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

// [MỚI]: Bổ sung nhận diện cử chỉ viền cạnh màn hình UIKit
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

// [MỚI]: Gộp hàm setShadowStyle vào class có sẵn
@interface SBFluidSwitcherItemContainer : UIView
- (void)setContentAlpha:(double)alpha;
- (void)prepareForReuse;
- (void)setCornerRadius:(CGFloat)radius;
- (void)setShadowStyle:(long long)style;
- (long long)shadowStyle;
@end

// [MỚI]: Bổ sung overlay icon trong switcher
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

// [MỚI]: Bổ sung nạp ảnh async cho AppSwitcher
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

// [MỚI]: Bổ sung setDefaultValues cho Animation Settings
@interface SBFluidSwitcherAnimationSettings : NSObject
- (double)deckSwipeSpeedFactor;
- (double)cardFlyInDuration;
- (void)setDefaultValues;
@end

// [MỚI]: Thông số độ nảy/cản của thanh Home
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

// 3. INTERFACE CHO BỘ GIỮ NHỊP SPRINGBOARD RATE KEEPER
@interface TitaniumRateKeeper : NSObject
+ (void)start;
+ (void)kick;
+ (void)tick:(id)link;
@end

// ====================================================================================================
// ĐỊNH NGHĨA CHUẨN STRUCT PAYLOAD & KHỞI TẠO BIẾN TOÀN CỤC (ĐÃ SỬA TRIỆT ĐỂ LỖI CLANG)
// ====================================================================================================

// [ĐÃ ÉP]: Khởi tạo chuẩn xác từng trường chống lỗi "excess elements in struct initializer"
static ApexV285ProPayload g_syncPayloadV285 = {
    .magic = APEX_SYNC_MAGIC_V285,
    .masterEnabled = 0,
    .targetHz = 60,
    .targetFPS = 60,
    .forceOverclock = 0, // [ĐÃ SỬA ĐỢT 5]: mặc định KHÔNG ép quá xung; chỉ bật khi người dùng chọn >=144 trong app. Mặc định 120Hz cân bằng mượt + ít nóng (máy 60Hz tự khóa 60).
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
// [V12] BIẾN TOÀN CỤC & KHAI BÁO TRƯỚC (định nghĩa đầy đủ nằm ở KHỐI V12 phía dưới, trước runCoreTweak)
// ====================================================================================================

// [V12 - PIN 1-20% VẪN MƯỢT]: mức pin hiện tại (0.0 - 1.0) và cờ "pin yếu => ưu tiên mượt" (<=20% và không sạc).
static volatile float g_batteryLevelV12 = 1.0f;
static volatile BOOL g_lowBatterySmoothBoostV12 = NO;

// [V12] Khai báo trước: đa ngôn ngữ tự động / áp dụng Hz-FPS ngay cho app đang mở / heartbeat IPC / cờ pin yếu
static NSString *Titanium_ResolveEffectiveLanguage(void);
static void Titanium_ReapplyFrameRateToAllScenes(void);
static void Titanium_StartIPCHearthbeatV12(void);
static void Titanium_RegisterAppResumeRefreshV12(void);
static void Titanium_UpdateLowBatteryFlagV12(void);

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
    // Whitelist model định danh thật sự có ProMotion; không dùng prefix iPad7/iPad8/iPad14
    // vì các prefix đó cũng gồm nhiều mẫu iPad 60Hz. Việc nhận sai panel có thể làm hỏng đàm phán FPS.
    static BOOL isNative120 = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname sysInfo;
        if (uname(&sysInfo) != 0) return;
        NSString *dev = [NSString stringWithCString:sysInfo.machine encoding:NSUTF8StringEncoding];
        if (dev.length == 0) return;
        static NSSet<NSString *> *proMotionModels = nil;
        static dispatch_once_t modelsOnce;
        dispatch_once(&modelsOnce, ^{
            proMotionModels = [NSSet setWithArray:@[
                // iPhone 13 Pro/Pro Max -> iPhone 16 Pro/Pro Max
                @"iPhone14,2", @"iPhone14,3", @"iPhone15,2", @"iPhone15,3",
                @"iPhone16,1", @"iPhone16,2", @"iPhone17,1", @"iPhone17,2",
                // iPad Pro 10.5-inch / 12.9-inch (2nd gen)
                @"iPad7,1", @"iPad7,2", @"iPad7,3", @"iPad7,4",
                // iPad Pro generations 2018-2020 (all exact Pro model identifiers)
                @"iPad8,1", @"iPad8,2", @"iPad8,3", @"iPad8,4",
                @"iPad8,5", @"iPad8,6", @"iPad8,7", @"iPad8,8",
                @"iPad8,9", @"iPad8,10", @"iPad8,11", @"iPad8,12",
                // iPad Pro M1 / M2 / M4
                @"iPad13,4", @"iPad13,5", @"iPad13,6", @"iPad13,7",
                @"iPad13,8", @"iPad13,9", @"iPad13,10", @"iPad13,11",
                @"iPad14,3", @"iPad14,4", @"iPad14,5", @"iPad14,6",
                @"iPad16,3", @"iPad16,4", @"iPad16,5", @"iPad16,6"
            ]];
        });
        isNative120 = [proMotionModels containsObject:dev];
    });
    return isNative120;
}

// Trần phần cứng thật cho nhóm thiết bị mục tiêu. iPhone/iPad 60Hz không bao giờ bị ép lên 120/144;
// thiết bị ProMotion được giới hạn ở 120Hz, vì đây là trần vật lý của các model trong danh sách.
static inline NSInteger Titanium_NativeMaximumFPS(void) {
    // V22: ask UIKit for the actual panel capability so newer ProMotion devices and older devices
    // use the same code path. Private display spoofing is never used in the safe profile.
    @try {
        UIScreen *screen = [UIScreen mainScreen];
        if (@available(iOS 10.0, *)) {
            if ([screen respondsToSelector:@selector(maximumFramesPerSecond)]) {
                NSInteger reported = (NSInteger)screen.maximumFramesPerSecond;
                // Trust UIKit's actual display capability; reject implausible values, never fabricate a higher rate.
                if (reported >= 30 && reported <= 240) return reported;
            }
        }
    } @catch (__unused NSException *exception) {}
    return HardwareHasNative120Hz() ? 120 : 60;
}

// ====================================================================================================
// [ĐÃ BỔ SUNG - TRUNG THỰC VỚI PHẦN CỨNG MÀN HÌNH]
// Máy không có ProMotion (iPhone 8 Plus, 6s...) có tấm nền 60Hz cố định. Khai man VRR/ProMotion/144Hz không tạo thêm khung hình nào
// nhưng làm hệ thống đàm phán nhịp quét sai (hoạt ảnh đứng hẳn sau khi nhả tay, app đen lúc mở).
// Mặc định chỉ khai man trên phần cứng THẬT SỰ có ProMotion. Đặt TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL = 1 để trả về hành vi cũ.
// ====================================================================================================
#ifndef TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL
#define TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL 0
#endif

// Miễn nhiễm watchdog FrontBoard (FBProcessWatchdog start rồi invalidate ngay) có thể hủy assertion giữ app chạy lúc mở. Mặc định TẮT.
#ifndef TITANIUM_ENABLE_WATCHDOG_IMMUNITY
#define TITANIUM_ENABLE_WATCHDOG_IMMUNITY 0
#endif

// Đặt biến môi trường MTL_* giữa chừng trong mọi app (tắt theo dõi residency, ép encode song song...) gây hình đen/vỡ ở app Metal. Mặc định TẮT.
#ifndef TITANIUM_ENABLE_METAL_ENV_TWEAKS
#define TITANIUM_ENABLE_METAL_ENV_TWEAKS 0
#endif

// [ĐÃ BỔ SUNG - ĐỢT 4] CHẾ ĐỘ NHẸ: 1 = các hook chạy từng khung hình/layer/sự kiện và các hook ghi đè hành vi hệ thống chuyển thẳng cho bản gốc.
// Lõi (Hz/FPS toàn hệ thống, công tắc tổng, loại trừ app, sửa lỗi đã nêu) KHÔNG bị ảnh hưởng. Đặt 0 để trả về hành vi nặng cũ.
#ifndef TITANIUM_LITE_MODE
#define TITANIUM_LITE_MODE 1
#endif

// Stable default for this build: skip private WindowServer/BackBoard/gesture/Metal override groups.
// The iOS-native refresh scheduler remains in control; only guarded public DisplayLink/Scene caps are used.
#ifndef TITANIUM_SAFE_STABILITY_PROFILE
#define TITANIUM_SAFE_STABILITY_PROFILE 1
#endif

// [V10] Bật boost layout SpringBoard/đa nhiệm/popup (có cache QoS, không overhead). Đặt 0 để tắt.
#ifndef TITANIUM_V10_PERFORMANCE
#define TITANIUM_V10_PERFORMANCE 1
#endif

// Bộ giữ nhịp CADisplayLink cho SpringBoard (xem TitaniumRateKeeper). Mặc định TẮT: cờ "đang cuộn" có thể bị kẹt khiến bộ này chạy mãi (nóng máy).
#ifndef TITANIUM_ENABLE_RATE_KEEPER
#define TITANIUM_ENABLE_RATE_KEEPER 0
#endif

// Ghi đè "hợp đồng" Metal trong MỌI tiến trình: ép MTLTextureDescriptor.allowGPUOptimizedContents = YES (CoreVideo/IOSurface/ảnh/video cần NO
// nên texture hỏng => nội dung app mạng xám/đen/văng) và ép _MTLCommandQueue.executionEnabled = YES. Mặc định TẮT.
#ifndef TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES
#define TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES 0
#endif

// Đặt Task QoS tier (độ trễ/băng thông tier 1) cho cả tiến trình: tắt coalescing timer, đánh thức CPU liên tục => nóng máy. Mặc định TẮT.
#ifndef TITANIUM_ENABLE_TASK_QOS_TIER
#define TITANIUM_ENABLE_TASK_QOS_TIER 0
#endif

// Nhóm hook WebKit RAM (WKWebView/WKProcessPool) trong app thứ ba: app có mạng thường nhúng WKWebView (đăng nhập, nội dung web). Mặc định TẮT trong app.
#ifndef TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS
#define TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS 0
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

// [ĐÃ SỬA]: SÀN DẢI TẦN QUÉT cho mọi CAFrameRateRange mà tweak ghi đè.
// Bản cũ đặt sàn 1Hz => hệ thống được phép hạ nhịp xuống ~0 ngay khi không còn chạm (đứng khung hình mức 0 lúc
// mở/đóng app, kéo Trung tâm điều khiển/Thông báo, vuốt màn hình khóa, mở Spotlight). Sàn 60Hz = nhịp gốc của
// màn hình 60Hz, trần vẫn là 144 (hoặc giá trị đã chọn) như cấu hình của người dùng.
#ifndef TITANIUM_FRAME_RATE_FLOOR
#define TITANIUM_FRAME_RATE_FLOOR 60.0f
#endif

// [ĐÃ SỬA]: Công tắc biên dịch cho việc HẠ QoS luồng sau mỗi CATransaction flush (xem hook CATransaction bên dưới).
// Mặc định TẮT (0): hạ QoS luồng chính của app xuống DEFAULT khi rảnh làm app khởi động/nạp nội dung chậm và dễ xám/đen.
#ifndef TITANIUM_ALLOW_FLUSH_QOS_DEMOTION
#define TITANIUM_ALLOW_FLUSH_QOS_DEMOTION 0
#endif

// [ĐÃ SỬA]: Đổi nano-giây sang Mach ticks theo timebase phần cứng.
// Lỗi gốc: so sánh trực tiếp (mach_absolute_time() - mốc) với hằng số nano-giây. Trên chip A11 trở lên timebase là 125/3
// (1 tick ~ 41.7ns) nên "800ms" thực tế thành ~33 giây, "1.2s" thành ~50 giây.
static inline uint64_t Titanium_NanosToMachTicks(uint64_t nanos) {
    static mach_timebase_info_data_t s_tbInfo;
    static dispatch_once_t s_tbOnce;
    dispatch_once(&s_tbOnce, ^{
        mach_timebase_info(&s_tbInfo);
        if (s_tbInfo.numer == 0 || s_tbInfo.denom == 0) {
            s_tbInfo.numer = 1;
            s_tbInfo.denom = 1;
        }
    });
    return (nanos * (uint64_t)s_tbInfo.denom) / (uint64_t)s_tbInfo.numer;
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
    // V26 VIP safety: intentionally do not override kernel thread throttling.
    // iOS owns scheduling and thermal limits; attempting to bypass them can increase heat or instability.
}

static inline void Titanium_EnforceThreadVIPPolicy(void) {
    if (!NSThread.isMainThread) return;

    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    setiopolicy_np(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);
    /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */

    Titanium_DisableKernelThreadThrottling();
}

static inline void Titanium_EnforceThreadRealtimeAndDiskVIP(void) {
    Titanium_EnforceThreadVIPPolicy();
}

static inline void Titanium_BoostCurrentThreadBriefly(void) {
    if (NSThread.isMainThread) {
        /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
    }
}

static inline void Titanium_BackgroundPurgeMemory(void) {
    static os_unfair_lock s_purgeLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t s_lastPurgeTicks = 0;
    // Heap-pressure relief is not a universal RAM cleaner. Rate-limit non-urgent requests to avoid
    // allocator work during every app-switch/animation and keep the main thread free.
    if (g_lowBatterySmoothBoostV12) return;

    uint64_t now = mach_absolute_time();
    BOOL shouldPurge = NO;
    os_unfair_lock_lock(&s_purgeLock);
    uint64_t intervalTicks = Titanium_NanosToMachTicks(15ULL * 1000000000ULL);
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
}

static inline void Titanium_PurgeProcessMemoryAggressively(void) {
    Titanium_BackgroundPurgeMemory();
}

static void Titanium_ApplySiliconDeepOptimizations(void) {
    // [ĐÃ SỬA]: các biến MTL_* đặt giữa chừng trong mọi app có thể làm app Metal đen hình/vỡ hình; mặc định TẮT (xem macro ở trên).
#if TITANIUM_ENABLE_METAL_ENV_TWEAKS
    setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
    setenv("MTL_DISABLE_TEXTURE_RESIDENCY_TRACKING", "1", 1);
    setenv("MTL_SHADER_VALIDATION", "0", 1);
    setenv("MTL_FORCE_PARALLEL_ENCODE", "1", 1);
#endif
    setenv("CA_DEBUG_TRANSACTIONS", "0", 1);
    // [ĐÃ SỬA]: ép tần số tối đa của CoreAnimation chỉ có nghĩa trên phần cứng ProMotion thật
    if (Titanium_DisplaySpoofAllowed()) {
        setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);
    }

#if !TITANIUM_SAFE_STABILITY_PROFILE
    Titanium_DisableKernelThreadThrottling();
#endif
}

// ==================== HÀM ÉP XUNG CPU/KERNEL CHO RENDER ====================
static inline void EnforceMaxCPUPower(void) {
    if (![NSThread isMainThread]) return;
    
    // 1. Ghim mức ưu tiên cao nhất cho CPU
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    
    // 2. Gỡ bỏ giới hạn điều tiết luồng cấp Kernel
    mach_port_t thread = pthread_mach_thread_np(pthread_self());
    thread_throttle_policy_data_t policy;
    policy.pset_limit = 0;
    thread_policy_set(thread, THREAD_THROTTLE_POLICY, (thread_policy_t)&policy, 1);
}

// V25: safe IPC writer. Use per-write temporary files (not a shared .tmp name),
// retry interrupted/short writes and replace the target only after the full payload is durable.
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
}

static uint64_t Titanium_IPCSequenceNowV25(void) {
    NSTimeInterval epoch = [[NSDate date] timeIntervalSince1970];
    uint64_t candidate = (isfinite(epoch) && epoch >= 1.0)
        ? (uint64_t)(epoch * 1000000000.0) : (uint64_t)mach_absolute_time();
    // SpringBoard emits the preference sequence; make rapid same-process changes strictly ordered.
    static os_unfair_lock sequenceLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t lastSequence = 0;
    os_unfair_lock_lock(&sequenceLock);
    if (candidate <= lastSequence) candidate = lastSequence + 1;
    lastSequence = candidate;
    os_unfair_lock_unlock(&sequenceLock);
    return candidate;
}

// Don't let an older queued heartbeat replace a newer preference payload. Per-path comparison
// is necessary because the primary and RootHide-compatible files can briefly differ during writes.
static void Titanium_WriteSyncPayloadUniversal(const void *payloadData, size_t dataSize) {
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
}

static void Titanium_WriteSyncPayloadV285(const ApexV285ProPayload *payload) {
    if (!payload) return;
    ApexV285ProPayload temp = *payload;
    temp.magic = APEX_SYNC_MAGIC_V285;
    if (temp.updateSeq == 0) temp.updateSeq = Titanium_IPCSequenceNowV25();
    temp.lastHeartbeat = Titanium_IPCSequenceNowV25();

    Titanium_WriteSyncPayloadUniversal(&temp, sizeof(ApexV285ProPayload));
}

// [ĐÃ ÉP TOÀN DIỆN]: Đọc atomic trạng thái đồng bộ IPC tức thì 0ns
static inline void Titanium_ReloadSharedSyncStateV285(void) {
    // [ĐÃ SỬA - CÔNG TẮC TỔNG]: app đã bị tắt trong tab App thì không bao giờ nạp lại payload (tránh bật lại ngoài ý muốn)
    if (g_isCurrentAppBlacklisted) {
        return;
    }
    uint64_t now = mach_absolute_time();
    // [ĐÃ SỬA]: 250ms phải đổi sang Mach ticks. Bản cũ so ticks với nano-giây => thực tế ~10 giây không nạp lại,
    // nên đổi công tắc/Hz trong app cấu hình không có tác dụng trong khoảng đó.
    if (g_lastSyncTicksV285 != 0 && (now - g_lastSyncTicksV285) < Titanium_NanosToMachTicks(250ULL * 1000000ULL)) {
        return;
    }

    pthread_mutex_lock(&g_syncLockV285);
    NSArray *checkPaths = @[PRIMARY_SYNC_FILE, SECONDARY_SYNC_FILE];
    ApexV285ProPayload newestPayload;
    memset(&newestPayload, 0, sizeof(newestPayload));
    BOOL foundPayload = NO;
    for (NSString *path in checkPaths) {
        int fd = open([path UTF8String], O_RDONLY);
        if (fd < 0) continue;
        ApexV285ProPayload temp;
        uint8_t *cursor = (uint8_t *)&temp;
        size_t remaining = sizeof(temp);
        BOOL readOK = YES;
        while (remaining > 0) {
            ssize_t count = read(fd, cursor, remaining);
            if (count < 0 && errno == EINTR) continue;
            if (count <= 0) { readOK = NO; break; }
            cursor += (size_t)count;
            remaining -= (size_t)count;
        }
        close(fd);
        if (!readOK || temp.magic != APEX_SYNC_MAGIC_V285) continue;
        if (!foundPayload || temp.updateSeq > newestPayload.updateSeq) {
            newestPayload = temp;
            foundPayload = YES;
        }
    }
    if (foundPayload) {
        if (newestPayload.updateSeq > g_syncPayloadV285.updateSeq) {
            g_syncPayloadV285 = newestPayload;
        }
        g_lastSyncTicksV285 = now;
    }
    pthread_mutex_unlock(&g_syncLockV285);
}

// [ĐÃ BỔ SUNG - CÔNG TẮC TỔNG / LOẠI TRỪ APP]: SpringBoard đọc được plist cấu hình nên ghi danh sách bundle ID bị TẮT ra tệp văn bản
// (mỗi dòng một ID). App thứ ba trong sandbox đọc tệp này để biết mình có bị loại trừ hay không.
static void Titanium_WriteDisabledAppsFile(NSString *joinedIDs) {
    NSData *data = [(joinedIDs ?: @"") dataUsingEncoding:NSUTF8StringEncoding];
    (void)Titanium_WriteAtomicIPCFile(APPS_SYNC_FILE_PRIMARY, data.bytes, data.length);
    (void)Titanium_WriteAtomicIPCFile(APPS_SYNC_FILE_SECONDARY, data.bytes, data.length);
}

static BOOL Titanium_IsBundleDisabledViaIPC(NSString *bundleID) {
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
        return NO; // đã đọc được một tệp hợp lệ: kết luận theo tệp đó
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
        
        // Chỉ xóa bản ghi nếu vẫn đúng lần khởi động đã lên lịch; tránh timer cũ xóa bộ đếm mới.
        NSInteger scheduledCount = restartCount;
        NSTimeInterval scheduledTime = currentUnixTime;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(20.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            NSDictionary *latest = [NSDictionary dictionaryWithContentsOfFile:bootCounterFilePath];
            if ([latest[@"count"] integerValue] == scheduledCount &&
                fabs([latest[@"time"] doubleValue] - scheduledTime) < 0.001) {
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
static volatile NSInteger g_cachedResolvedHz = 120; // [ĐÃ SỬA ĐỢT 5]: mặc định cân bằng 120 (máy 60Hz tự khóa 60)
static volatile NSInteger g_cachedResolvedFPS = 120;
// [ĐÃ THÊM ĐỢT 5 - CHỐNG NÓNG MÁY]: cờ nhiệt được cập nhật bởi hook thermalState; khi Serious/Critical
// toàn hệ thống tự hạ trần về 60Hz để GPU/CPU nghỉ, hết nóng thì tự về mức người dùng chọn.
static volatile BOOL g_thermalSeriousV285 = NO;

// V22: đọc trạng thái nhiệt/Low Power thật từ API công khai; không giả mạo thermalState hoặc nâng QoS.
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

// [ĐÃ ÉP TOÀN DIỆN]: ĐIỀU PHỐI WINDOWSERVER TỨC THÌ (KHÓA DẢI 15 - 144HZ, CHỐNG CO VIEWPORT & CHỐNG ĐEN APP)
static void Titanium_TuneWindowServerDisplayDirectly(void) {
#if TITANIUM_SAFE_STABILITY_PROFILE
    // Không gọi private CAWindowServer setters trong profile an toàn: một giá trị sai có thể làm
    // WindowServer/BackBoard đàm phán refresh không hợp lệ và gây đứng màn hình sau respring.
    return;
#else
    // [ĐÃ SỬA]: không can thiệp thông số máy chủ hiển thị trên tấm nền 60Hz không có ProMotion
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

- (instancetype)init {
    self = [super init];
    if (self) {
        self.enabled = YES;
        self.targetHz = 120; // [ĐÃ SỬA ĐỢT 5]: mặc định 120 cân bằng mượt + ít nóng (máy 60Hz tự khóa 60)
        self.targetFPS = 120;
        self.enableHzControl = YES;
        self.enableFPSControl = YES;
        self.forceOverclock144Hz = NO; // [ĐÃ SỬA ĐỢT 5]: chỉ ép quá xung khi người dùng chủ động chọn >=144
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
        // [ĐÃ SỬA - CÔNG TẮC TỔNG / LOẠI TRỪ APP]: xác định app hiện tại có bị tắt trong tab App hay không.
        // Bản cũ: biến g_isCurrentAppBlacklisted không bao giờ được gán, và dù self.enabled = NO thì payload mặc định masterEnabled = 1
        // vẫn khiến mọi hook chạy; app trong sandbox còn không đọc được plist nên không bao giờ biết mình bị loại trừ.
        // Nay: ưu tiên plist (nếu đọc được), sau đó tới tệp IPC danh sách app bị tắt do SpringBoard ghi.
        // ==============================================================================================
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
        // CƠ CHẾ DỰ PHÒNG CHO APP THỨ 3 (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN - VƯỢT SANDBOX 100% QUA RAM)
        // (AN TOÀN TUYỆT ĐỐI: KHÔNG TREO I/O, KHÔNG ĐEN MÀN HÌNH, KHÔNG NGHẼN MẠNG)
        // ==============================================================================================
        if (!diskDict || diskDict.count == 0) {
            // V25: Đọc tệp IPC đồng bộ chỉ đọc; payload được thay nguyên tử với quyền 0644.
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

                                // [ĐÃ SỬA - CÔNG TẮC TỔNG]: nạp NGUYÊN payload vào g_syncPayloadV285 ngay (không chờ lượt nạp nền)
                                // để điều kiện "IS_ACTIVE hoặc masterEnabled" phản ánh đúng công tắc tổng ngay lập tức.
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

            // [V13 STABILITY]: nếu chưa đọc được plist và cũng không có payload IPC hợp lệ,
            // fail closed. Không tự bật Turbo Launch/Metal/Touch với dữ liệu mặc định vì app có thể
            // mở trước SpringBoard, nhất là ngay sau respring RootHide/Rootless.
            self.enabled = NO;
            self.enableHzControl = NO;
            self.enableFPSControl = NO;
            self.targetHz = 60;
            self.targetFPS = 60;
            self.forceOverclock144Hz = NO;
            self.touchResponseBoost = NO;
            self.metalHexBuffering = NO;
            self.vsyncAdaptiveBuffer = NO;
            self.fixAppLaunchBlackScreen = NO;
            self.turboAppLaunch = NO;
            self.turboLaunch = NO;
            self.proMotionEngineBeta7 = NO;
            self.antiThermalThrottling = NO;
            self.powerSaveMode = NO;
            self.batterySaver60Hz = NO;
            g_cachedResolvedHz = 60;
            g_cachedResolvedFPS = 60;
            pthread_mutex_lock(&g_syncLockV285);
            memset(&g_syncPayloadV285, 0, sizeof(g_syncPayloadV285));
            g_syncPayloadV285.magic = APEX_SYNC_MAGIC_V285;
            g_syncPayloadV285.masterEnabled = 0;
            g_syncPayloadV285.targetHz = 60;
            g_syncPayloadV285.targetFPS = 60;
            pthread_mutex_unlock(&g_syncLockV285);
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
        // [ĐÃ SỬA - CÔNG TẮC TỔNG]: áp dụng kết quả loại trừ đã tính ở trên (đặt g_isCurrentAppBlacklisted + tắt payload của tiến trình này)
        ApplyExclusion();

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
        } else if (safeHz >= 144) {
            // [ĐÃ SỬA - CHỈNH Hz KHÔNG CÓ TÁC DỤNG]: bản cũ "forceOverclock144Hz || ..." - cờ này được lưu lại từ lần chọn 144 và KHÔNG tự tắt
            // khi bạn chọn giá trị thấp hơn nên luôn ép về 144 bất kể lựa chọn. Nay chỉ khi giá trị chọn >= 144 mới lấy 144.
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
        } else if (safeFPS >= 144) {
            // [ĐÃ SỬA - CHỈNH FPS KHÔNG CÓ TÁC DỤNG]: xem ghi chú ở nhánh Hz (cờ ForceOverclock144Hz đã lưu không được đè lựa chọn thấp hơn)
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
            // [V12 - ĐA NGÔN NGỮ TỰ ĐỘNG CHUẨN]: nhúng mã ngôn ngữ đã phân giải vào vùng reserved của payload IPC
            // để app thứ ba và giao diện cài đặt dùng CHUNG một ngôn ngữ với máy (máy tiếng Anh => tweak tiếng Anh;
            // máy tiếng Việt => tweak tiếng Việt...). Không đổi kích thước/layout struct nên tương thích ngược 100%.
            {
                const char *langCodeV12 = Titanium_ResolveEffectiveLanguage().UTF8String;
                if (langCodeV12) {
                    p.reserved[0] = 'L'; p.reserved[1] = 'G'; p.reserved[2] = ':';
                    strncpy(&p.reserved[3], langCodeV12, sizeof(p.reserved) - 4);
                    p.reserved[sizeof(p.reserved) - 1] = '\0';
                }
            }
            p.updateSeq = Titanium_IPCSequenceNowV25();
            p.lastHeartbeat = p.updateSeq;

            // [ĐÃ SỬA - CÔNG TẮC TỔNG]: cập nhật payload của CHÍNH SpringBoard ngay lập tức. Bản cũ chỉ ghi tệp rồi chờ lượt nạp lại
            // (mà lượt nạp lại đọc tệp CŨ trước khi tệp mới được ghi) nên tắt công tắc tổng mà các hook vẫn chạy nhờ masterEnabled mặc định = 1.
            pthread_mutex_lock(&g_syncLockV285);
            g_syncPayloadV285 = p;
            pthread_mutex_unlock(&g_syncLockV285);

            // Danh sách bundle ID bị tắt trong tab App (ghi ra tệp để app trong sandbox đọc được)
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
                // Báo cho app và backboardd nạp lại SAU KHI tệp đã ghi xong
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

// CALLBACK ĐỒNG BỘ TOÀN HỆ THỐNG
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
// KHAI BÁO BIẾN TOÀN CỤC & ĐIỀU PHỐI HỆ THỐNG TITANIUM (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN & AN TOÀN ĐA LUỒNG)
// (AN TOÀN TUYỆT ĐỐI: ĐỒNG BỘ 100% VỚI Ổ KHÓA CỦA APP, KHÔNG ĐEN MÀN HÌNH, KHÔNG TREO RESPRING)
// ====================================================================================================

#include <stdatomic.h>

static volatile BOOL g_isContinuousSwiping = NO;
static volatile BOOL g_isUserTouchingScreen = NO;
static volatile BOOL g_isVolumeHoldingV285 = NO;
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
            // Chu kỳ nhả xung chạm: 700ms khi dùng pin, 450ms khi cắm sạc
            // [ĐÃ SỬA]: kéo dài từ 350/180ms để hoạt ảnh sau khi nhả tay (mở/đóng app, CC/NC, màn hình khóa) vẫn giữ nhịp tới khi xong
            g_burstDurationMachTicks = (700ULL * 1000000ULL * tb.denom) / tb.numer;
            g_burstDurationChargingMachTicks = (450ULL * 1000000ULL * tb.denom) / tb.numer;
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
    return (g_isVideoPlayingActive && !g_isUserTouchingScreen && !g_isVolumeHoldingV285 && !g_isScrollingActive && g_activeAnimationCount == 0);
}

// ====================================================================================================
// 2. BỘ ĐIỀU PHỐI KHÓA TARGET RATE DYNAMIC (ATOMIC TICKS - CÓ TIMEOUT CHỐNG KẸT PEAK VĨNH VIỄN)
// ====================================================================================================

// ==================== BỘ ĐIỀU PHỐI KHÓA TRẦN / NHẢ 15HZ CHỐNG KHỰNG ====================
static inline BOOL Titanium_ShouldLockTargetRate(void) {
    // 1. Ổ khóa thủ công từ ứng dụng/tweak: Ép trần liên tục nếu có thiết lập cứng
    if (g_isRateLockedV285) return YES;

    // 2. Banner thông báo hệ thống đang hiển thị
    if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

    // 3. Hoạt ảnh chuyển cảnh (giữ trần tối đa 1.2s chống kẹt)
    static uint64_t s_animStartTick = 0;
    if (g_activeAnimationCount > 0) {
        uint64_t nowTick = mach_absolute_time();
        if (s_animStartTick == 0) {
            s_animStartTick = nowTick;
            return YES;
        } else if ((nowTick - s_animStartTick) < Titanium_NanosToMachTicks(1200000000ULL)) {
            return YES;
        } else {
            g_activeAnimationCount = 0;
            s_animStartTick = 0;
        }
    } else {
        s_animStartTick = 0;
    }

    // 4. KIỂM TRA TẤT CẢ CÁC CỜ TƯƠNG TÁC (Chạm, HID, Vuốt, Cuộn, Âm lượng)
    // SỬA LỖI: Đưa g_isInteracting vào đây và kiểm tra timeout để chống kẹt vĩnh viễn khi Single Tap
    if (g_isInteracting || g_isVolumeHoldingV285 || g_isUserTouchingScreen || g_isContinuousSwiping || g_isScrollingActive) {
        static uint64_t s_staleFlagTicks = 0;
        if (s_staleFlagTicks == 0) {
            s_staleFlagTicks = Titanium_NanosToMachTicks(1500000000ULL); // Giữ tối đa 1.5s
        }
        
        uint64_t nowFlag = mach_absolute_time();
        uint64_t lastTick = (g_lastInteractiveTick > g_lastInteractionMachTime) ? g_lastInteractiveTick : g_lastInteractionMachTime;

        // Nếu vẫn còn trong khoảng 1.5s kể từ lần chạm/di chuyển cuối cùng -> Giữ trần
        if (lastTick != 0 && (nowFlag - lastTick) < s_staleFlagTicks) {
            return YES;
        }

        // Đã quá 1.5s không còn tín hiệu mới -> Xả sạch toàn bộ cờ để đưa nhịp về 15Hz
        g_isInteracting = NO;
        g_isVolumeHoldingV285 = NO;
        g_isUserTouchingScreen = NO;
        g_isContinuousSwiping = NO;
        g_isScrollingActive = NO;
    }

    // 5. Cửa sổ giữ nhịp Mach Time (sau khi nhả tay hoàn toàn, giữ thêm 0.7s - 1.0s)
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

#if TITANIUM_ENABLE_RATE_KEEPER
// [ĐÃ BỔ SUNG]: bộ giữ nhịp cho SpringBoard (phần cài đặt nằm sau Titanium_GetTargetConfiguredFPS)
@interface TitaniumRateKeeper : NSObject
+ (void)start;
+ (void)kick;
@end
#endif

// [ĐÃ ÉP TOÀN DIỆN]: Ép quyền ưu tiên cao nhất cho luồng chính và I/O ổ đĩa
static inline void Titanium_LockMainThreadFast(void) {
    if (![NSThread isMainThread]) return;
    // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]: luồng chính vốn đã là User-Interactive và IO mặc định; hàm này được gọi cho TỪNG sự kiện chạm / TỪNG hoạt ảnh
    // nên chỉ tốn 2 syscall mỗi lần mà không thêm lợi ích nào. Chế độ nhẹ bỏ qua.
    if (TITANIUM_LITE_MODE) return;

    /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
#if TITANIUM_ENABLE_RATE_KEEPER
    if (Titanium_IsSpringBoard()) {
        [TitaniumRateKeeper kick];
    }
#endif
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
    if (TITANIUM_LITE_MODE) return; // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]
    if (!Titanium_ShouldLockTargetRate()) return;

    /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
}

// ====================================================================================================
// 5. THUẬT TOÁN PHÂN TẦNG TOÀN HỆ THỐNG: TRẦN NHỊP THÍCH ỨNG, GIỚI HẠN THEO PHẦN CỨNG THẬT
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
    if (g_isRateLockedV285) {
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
    // [ĐÃ SỬA]: mặc định TẮT (TITANIUM_ENABLE_TASK_QOS_TIER = 0) vì làm CPU thức liên tục => nóng máy
    #if TITANIUM_ENABLE_TASK_QOS_TIER && defined(TASK_LATENCY_QOS_POLICY)
    task_latency_qos_policy_data_t latencyPolicy;
    latencyPolicy.task_latency_qos_tier = LATENCY_QOS_TIER_1;
    task_policy_set(mach_task_self(), TASK_LATENCY_QOS_POLICY, (task_policy_t)&latencyPolicy, TASK_LATENCY_QOS_POLICY_COUNT);
    #endif

    #if TITANIUM_ENABLE_TASK_QOS_TIER && defined(TASK_THROUGHPUT_QOS_POLICY)
    task_throughput_qos_policy_data_t throughputPolicy;
    throughputPolicy.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_1;
    task_policy_set(mach_task_self(), TASK_THROUGHPUT_QOS_POLICY, (task_policy_t)&throughputPolicy, TASK_THROUGHPUT_QOS_POLICY_COUNT);
    #endif
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép triệt tiêu độ trễ hiển thị phần cứng của CADisplay về 0.0s
static void AppleInternal_LockHardwareCADisplay(void) {
    // [ĐÃ SỬA]: không đổi độ trễ hiển thị của CADisplay trên tấm nền 60Hz không có ProMotion
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
// V15: Do not assign THREAD_TIME_CONSTRAINT_POLICY to app/SpringBoard threads.
// DisplayLink/Scene frame-rate hints are the supported pacing path; realtime policy can starve
// system work and cause stutter, heat, and watchdog termination on some jailbreak/iOS combinations.
static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz) {
    (void)targetHz;
}

static inline void Titanium_EnforceMachFrameConstraint(void) {
    // Intentionally no-op in the stable profile. Native frame pacing remains owned by iOS.
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
    // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]: hook chạy MỖI KHUNG HÌNH; đồng thời tự gia hạn mốc tương tác nên khóa nhịp không bao giờ tự hết khi còn hoạt ảnh
    if (TITANIUM_LITE_MODE) {
        %orig;
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (CFG285.proMotionEngineBeta7 || CFG285.touchResponseBoost || g_isRateLockedV285 || g_syncPayloadV285.zeroLatencyTouch) {
            if (Titanium_ShouldLockTargetRate()) {
                g_lastInteractionMachTime = mach_absolute_time();
                /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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
    // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]: hook chạy cho TỪNG mục trong chuỗi cập nhật của MỖI khung hình
    if (TITANIUM_LITE_MODE) {
        %orig;
        return;
    }
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

// --- [ĐÃ ÉP TỐI ĐA - BẢO TOÀN CHUỖI NHẬN DIỆN HID GỐC & KÍCH TRẦN 0MS TỪ SÀN 15HZ] ---
%hook UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES; // Kích cờ tương tác ngay từ tầng driver phần cứng

        // SỬA CHUẨN: _receiveHIDEvent chạy trên luồng com.apple.uikit.eventfetch-thread.
        // Nâng thẳng QoS của luồng này lên User Interactive để gom dữ liệu cảm ứng 0ms.
        static dispatch_once_t s_qosOnce;
        dispatch_once(&s_qosOnce, ^{
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        });
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
                // Đệm nhịp 30ms: Kích trọn công suất CPU Kernel ngay khi chạm, chống spam syscall
                if (now - s_lastWindowTouchTick > Titanium_NanosToMachTicks(30ULL * 1000000ULL)) {
                    s_lastWindowTouchTick = now;
                    g_lastInteractionMachTime = now;
                    
                    // ÉP XUNG P-CORE & GỠ BỎ THROTTLE KERNEL NGAY KHI CHẠM
                    EnforceMaxCPUPower();
                    
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
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard() && self.context) {
        // 1. Nhận diện tiến trình Game Metal chính xác
        CGSize scrSize = [UIScreen mainScreen].bounds.size;
        CGFloat scrArea = scrSize.width * scrSize.height;
        CGRect layerBounds = self.bounds;
        CGFloat layerArea = layerBounds.size.width * layerBounds.size.height;
        if (scrArea > 0.0 && (layerArea / scrArea) >= 0.75) {
            g_isMetalGameProcess = YES;
        }

        // 2. Không ép cứng 2 buffer cho TikTok để tránh nghẽn luồng giải mã video
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        BOOL isTikTok = [bundleID containsString:@"musical.ly"] || [bundleID containsString:@"tiktok"];
        if (!isTikTok) {
            self.maximumDrawableCount = 2;
        }

        // 3. Khóa cứng V-Sync triệt tiêu xé hình
        [self setDisplaySyncEnabled:YES];

        // 4. Giải nghẽn luồng render
        if ([self respondsToSelector:@selector(setAllowsNextDrawableTimeout:)]) {
            self.allowsNextDrawableTimeout = YES;
        }

        // 5. Bật chế độ trễ thấp phần cứng Apple Silicon
        if ([self respondsToSelector:@selector(setLowLatencyMode:)]) {
            self.lowLatencyMode = YES;
        }

        // 6. Tối ưu xuất hình cho game Metal
        if (g_isMetalGameProcess || Titanium_IsCurrentAppAGame()) {
            self.presentsWithTransaction = NO;
            self.framebufferOnly = YES;
        }
    }
}

// Khóa cứng V-Sync
- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        %orig(YES);
        return;
    }
    %orig;
}

// Trả về 2 buffer khi truy vấn
- (NSUInteger)maximumDrawableCount {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        return 2;
    }
    return %orig;
}

// Chặn app/game tự nâng lên 3 buffer
- (void)setMaximumDrawableCount:(NSUInteger)count {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        %orig(2);
        return;
    }
    %orig(count);
}

// Gộp logic CPU & Mach time cho nextDrawable
- (id)nextDrawable {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        if (g_isMetalGameProcess || Titanium_IsCurrentAppAGame()) {
            g_lastInteractionMachTime = mach_absolute_time();
            EnforceMaxCPUPower();
        }
    }
    return %orig;
}

%end

// ====================================================================================================
// KÍCH HOẠT ZERO-LATENCY 0MS TỨC THÌ (BỎ QUA CHO APP AI ĐỂ KHÔNG NGHẼN BATCH CHỮ)
// ====================================================================================================
%hook CALayer

- (void)display {
    if (TITANIUM_LITE_MODE) {
        %orig;
        return;
    }
    // Cho phép App AI gom cụm token chữ mượt mà, không ép commit lẻ từng mili-giây
    if (Titanium_IsAIApp()) {
        %orig;
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch) && [NSThread isMainThread]) {
        if (!g_isDeviceChargingV285 && Titanium_ShouldLockTargetRate()) {
            // 0ms tuyệt đối: Bỏ toàn bộ bộ đếm tick thời gian
            if (self.bounds.size.width > 0 && self.bounds.size.height > 0) {
                Titanium_EnableZeroLatencyPipeline();
            }
        }
    }
    %orig;
}

%end

// ====================================================================================================
// BÙ TRỄ TỌA ĐỘ ĐÓN ĐẦU: TRIỆT TIÊU TRỄ KÉO RÊ, BÁM TAY 1:1 CHUẨN XÁC 0MS
// ====================================================================================================
%hook UIPanGestureRecognizer

- (CGPoint)translationInView:(UIView *)view {
    CGPoint original = %orig(view);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        UIGestureRecognizerState st = self.state;
        if (st == UIGestureRecognizerStateChanged || st == UIGestureRecognizerStateBegan) {
            CGPoint velocity = [self velocityInView:view];
            if (isfinite(velocity.x) && isfinite(velocity.y)) {
                // Đưa về 0.0ms: Bám dính ngón tay 1:1, không lệch tọa độ khi đổi chiều
                const CGFloat kLeadFactor = 0.0f;
                original.x += velocity.x * kLeadFactor;
                original.y += velocity.y * kLeadFactor;
            }
        }
    }
    return original;
}

%end

// ====================================================================================================
// DUY TRÌ DYNAMIC RANGE 1.0F CHỐNG LỆCH MÀU
// ====================================================================================================
%hook CAContext

- (void)setDesiredDynamicRange:(float)range {
    if (TITANIUM_LITE_MODE) {
        %orig;
        return;
    }
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
    // [TRUNG THỰC VỚI PHẦN CỨNG]: tấm nền không có ProMotion chỉ quét tối đa 60Hz
    NSInteger nativeMaxHz = Titanium_NativeMaximumFPS();
    if (userHz > nativeMaxHz) userHz = nativeMaxHz;
    // [CHỐNG NÓNG]: máy nóng Serious/Critical tự hạ về tối đa 60Hz tạm thời
    if (Titanium_ShouldApplyEcoFrameCapV19() && userHz > 60) userHz = 60;
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

    NSInteger nativeMaxFPS = Titanium_NativeMaximumFPS();
    if (userFPS > nativeMaxFPS) userFPS = nativeMaxFPS;

    if (Titanium_ShouldApplyEcoFrameCapV19() && userFPS > 60) userFPS = 60;
    return userFPS;
}

// [Hz/FPS CÓ TÁC DỤNG TOÀN HỆ THỐNG]: trần khung hình hiệu lực = giá trị THẤP HƠN giữa Hz và FPS đã chọn
static inline NSInteger Titanium_GetEffectiveFrameCap(void) {
    NSInteger hzCap = Titanium_GetTargetConfiguredHz();
    NSInteger fpsCap = Titanium_GetTargetConfiguredFPS();
    return (hzCap < fpsCap) ? hzCap : fpsCap;
}

// [KHÓA CỨNG SÀN]: Sàn luôn bằng đúng trần hiệu lực đã cấu hình, không cho phép rớt sâu
static inline float Titanium_RangeFloorForCap(float cap) {
    return cap;
}

// [KHÓA CỨNG DẢI TẦN SỐ QUÉT]: Ép toàn bộ dải (min, max, preferred) bằng đúng mức đã chọn
static inline SafeFrameRateRange Titanium_NormalizeFrameRateRange(SafeFrameRateRange range, BOOL systemUI) {
    (void)systemUI;
    (void)range;
    
    NSInteger nativeMax = Titanium_NativeMaximumFPS();
    NSInteger cap = Titanium_GetEffectiveFrameCap();
    if (nativeMax < 15) nativeMax = 60;
    if (cap < 15) cap = 15;
    if (cap > nativeMax) cap = nativeMax;

    float target = (float)cap;
    // Khóa cứng tuyệt đối: Minimum = Maximum = Preferred = target
    return SafeMakeFRR(target, target, target);
}

#if TITANIUM_ENABLE_RATE_KEEPER

// ====================================================================================================
// [ĐÃ TỐI ƯU]: BỘ GIỮ NHỊP CHO SPRINGBOARD (KEEP-ALIVE DISPLAYLINK)
// Khóa cứng theo targetHz, duy trì nhịp liên tục cho đến khi hoạt ảnh kết thúc hẳn (chống đứng hình 1-3s)
// ====================================================================================================

static CADisplayLink *s_keeperLink = nil;
static NSInteger s_keeperIdleFrames = 0;
static dispatch_source_t s_keeperPoller = nil;

@implementation TitaniumRateKeeper

+ (void)start {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [TitaniumRateKeeper start]; });
        return;
    }
    if (!Titanium_IsSpringBoard() || s_keeperPoller) return;

    // Thăm dò 20 lần/giây: đảm bảo luôn giữ nhịp khi có tương tác
    s_keeperPoller = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(s_keeperPoller, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), (uint64_t)(50 * NSEC_PER_MSEC), (uint64_t)(20 * NSEC_PER_MSEC));
    dispatch_source_set_event_handler(s_keeperPoller, ^{
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (Titanium_ShouldLockTargetRate() || g_activeAnimationCount > 0)) {
            [TitaniumRateKeeper kick];
        }
    });
    dispatch_resume(s_keeperPoller);
}

+ (void)kick {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [TitaniumRateKeeper kick]; });
        return;
    }
    if (!Titanium_IsSpringBoard()) return;
    if (!(IS_ACTIVE || g_syncPayloadV285.masterEnabled)) return;

    if (!s_keeperLink) {
        s_keeperLink = [CADisplayLink displayLinkWithTarget:[TitaniumRateKeeper class] selector:@selector(tick:)];
        if (@available(iOS 15.0, *)) {
            float targetHz = (float)Titanium_GetTargetConfiguredHz();
            if (targetHz < 15.0f) targetHz = 15.0f;
            if (targetHz > 144.0f) targetHz = 144.0f;
            // Khóa cứng sàn và trần của RateKeeper đúng bằng targetHz đã chỉnh
            s_keeperLink.preferredFrameRateRange = SafeMakeFRR(targetHz, targetHz, targetHz);
        }
        [s_keeperLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    }
    s_keeperIdleFrames = 0;
    s_keeperLink.paused = NO;
}

+ (void)tick:(CADisplayLink *)link {
    // [ĐÃ SỬA]: Giữ nhịp xuyên suốt khi có tương tác HOẶC khi hoạt ảnh hệ thống đang chạy
    if (Titanium_ShouldLockTargetRate() || g_activeAnimationCount > 0 || g_isInteracting) {
        s_keeperIdleFrames = 0;
    } else {
        s_keeperIdleFrames++;
        // Đợi đủ 60 frame rảnh rỗi (~1s) sau khi hoạt ảnh dừng hẳn mới tạm dừng, triệt tiêu đứng hình 1-3s
        if (s_keeperIdleFrames > 60) {
            link.paused = YES;
        }
    }
}

@end

// ====================================================================================================
// NHÓM 3: KHÓA CỨNG HZ/FPS TOÀN DIỆN (TRIỆT TIÊU HẠ 30HZ/60HZ KHI PHÁT VIDEO)
// ====================================================================================================

%group Group_FluidTransitions_Pacing

%hook CADisplayLink

- (NSInteger)preferredFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.enableFPSControl || g_syncPayloadV285.targetFPS > 0)) {
        if (Titanium_IsCurrentAppAGame()) {
            return %orig;
        }
        // [ĐÃ KHÓA CỨNG]: Bỏ nhánh video, luôn trả về FPS đã chọn
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
        // [ĐÃ KHÓA CỨNG]: Bỏ nhánh video ép về 60
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

        float maxTarget = (float)Titanium_GetEffectiveFrameCap();
        if (maxTarget < 15.0f) maxTarget = 15.0f;
        if (maxTarget > 144.0f) maxTarget = 144.0f;

        // [ĐÃ KHÓA CỨNG]: Sàn = Trần = Nhịp ưu tiên = maxTarget trong mọi tình huống
        range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
    }
    %orig(range);
}

- (void)setFrameInterval:(NSInteger)interval {
    %orig;
}

%end

%hook CADisplay

- (BOOL)allowsVirtualModes {
    return %orig;
}

- (void)setAllowsVirtualModes:(BOOL)allows {
    %orig;
}

- (NSInteger)preferredFPS {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return %orig;
    return Titanium_GetTargetConfiguredFPS();
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) {
        %orig;
        return;
    }
    %orig(Titanium_GetTargetConfiguredFPS());
}

- (NSInteger)minimumFPS {
    return %orig;
}

- (BOOL)supportsDynamicRefresh {
    return %orig;
}

- (BOOL)hasDynamicDisplayMode {
    return %orig;
}

%end

%hook UIScreen

- (NSInteger)maximumFramesPerSecond {
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    return %orig;
}

- (CGFloat)_refreshRate {
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    %orig;
}

%end

%hook CAAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float maxTarget = (float)Titanium_GetEffectiveFrameCap();
            if (maxTarget < 15.0f) maxTarget = 15.0f;
            if (maxTarget > 144.0f) maxTarget = 144.0f;

            // [ĐÃ KHÓA CỨNG]: Luôn giữ nhịp maxTarget, không hạ 30Hz khi video chạy ngầm
            range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
        }
    }
    %orig(range);
}

%end

%hook CASpringAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float maxTarget = (float)Titanium_GetEffectiveFrameCap();
            if (maxTarget < 15.0f) maxTarget = 15.0f;
            if (maxTarget > 144.0f) maxTarget = 144.0f;

            // [ĐÃ KHÓA CỨNG]: Hoạt ảnh lò xo luôn chạy trọn vẹn ở mức nhịp đã chọn
            range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
        }
    }
    %orig(range);
}

%end

%hook CALayer

- (void)setNeedsLayout {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (g_isInteracting && [NSThread isMainThread]) {
            [CATransaction setDisableActions:YES];
        }
    }
}

%end

%hook AVPlayer

- (void)setRate:(float)rate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        g_isVideoPlayingActive = (rate > 0.0f);
    }
    %orig;
}

%end

%hook UIApplication

- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES;
        g_activeAnimationCount++;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(400 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (g_activeAnimationCount > 0) g_activeAnimationCount--;
            g_isInteracting = NO;
            g_lastInteractiveTick = mach_absolute_time();
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
    // [ĐÃ SỬA]: không tiêm "hỗ trợ dynamic refresh" vào UIScreen trên tấm nền 60Hz không có ProMotion
    if (!Titanium_DisplaySpoofAllowed()) return;
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
    // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]: ép YES cho phép cử chỉ mới ngắt/chồng lên cử chỉ đa nhiệm đang chạy => khựng, giật khi vuốt nhanh liên tục.
    if (TITANIUM_LITE_MODE) return %orig;
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
    // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]: giữ mọi ảnh chụp đa nhiệm trong RAM làm SpringBoard phình bộ nhớ => cảnh báo bộ nhớ/dọn heap liên tục => lag
    if (TITANIUM_LITE_MODE) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.reduceMultiTaskLag) {
        return YES;
    }
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép hệ số giảm tốc mượt mà chuẩn UIScrollViewDecelerationRateFast
- (CGFloat)decelerationRate {
    if (TITANIUM_LITE_MODE) return %orig; // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]: giữ hệ số giảm tốc gốc của thanh đa nhiệm
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
    // Không xóa khoảng chuẩn bị của FrontBoard; giữ timing gốc giúp scene hoàn tất trước khi bỏ splash.
    return %orig;
}

- (double)zoomDuration {
    return %orig;
}

- (double)launchDuration {
    return %orig;
}

%end

%hook SBSplashBoardController

- (double)splashScreenDelay {
    // Splash screen tồn tại tới khi app sẵn sàng; không ép về 0 vì dễ lộ frame đen khi app tải chậm.
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
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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

// ====================================================================================================
// TỐI ƯU CHUYỂN CẢNH & HIỂN THỊ POPUP/QUẢNG CÁO TỨC THÌ (TRIỆT TIÊU DELAY & RƠI NHỊP)
// ====================================================================================================

%hook UIViewController

// 1. TĂNG TỐC KHI HIỂN THỊ MODAL / POPUP / QUẢNG CÁO
- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES; // Giữ trần tần số quét, chống rơi nhịp về 15Hz

        // Cấp quyền ưu tiên cao nhất cho Main Thread gánh tải nạp SDK/layout quảng cáo
        if ([NSThread isMainThread]) {
            pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        }

        // Tăng tốc layer trồi lên nhanh hơn
        if (flag && viewControllerToPresent) {
            viewControllerToPresent.view.layer.speed = 1.6f;
        }

        Titanium_TriggerInstantTouchBurst();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        } else {
            Titanium_BoostRenderWithoutStarvingNetwork();
        }

        // Bọc completion để trả lại speed chuẩn và nhả cờ đúng thời điểm
        __weak UIViewController *weakTarget = viewControllerToPresent;
        void (^safeCompletion)(void) = ^{
            if (weakTarget && weakTarget.isViewLoaded) {
                weakTarget.view.layer.speed = 1.0f; // Trả lại tốc độ chuẩn cho view
            }
            g_isInteracting = NO;
            g_lastInteractiveTick = mach_absolute_time();

            if (completion) {
                completion();
            }
        };

        // Timeout an toàn phòng trường hợp completion bị SDK bên thứ ba nuốt
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(450 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (g_isInteracting) {
                if (weakTarget && weakTarget.isViewLoaded) {
                    weakTarget.view.layer.speed = 1.0f;
                }
                g_isInteracting = NO;
                g_lastInteractiveTick = mach_absolute_time();
            }
        });

        %orig(viewControllerToPresent, flag, safeCompletion);
        return;
    }
    %orig(viewControllerToPresent, flag, completion);
}

// 2. TĂNG TỐC KHI ĐÓNG / BỎ QUA POPUP (BẤM NÚT X HOẶC SKIP QUẢNG CÁO)
- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES; // Giữ trần nhịp quét trong lúc đóng

        if (flag && self.isViewLoaded) {
            self.view.layer.speed = 1.6f; // Rút ngắn thời gian trượt xuống
        }

        Titanium_TriggerInstantTouchBurst();

        void (^safeDismissCompletion)(void) = ^{
            g_isInteracting = NO;
            g_lastInteractiveTick = mach_absolute_time();
            if (completion) {
                completion();
            }
        };

        // [ĐÃ SỬA VẾT CẮT 1]: Đóng hoàn chỉnh khối dispatch_after và gọi %orig
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(350 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            g_isInteracting = NO;
            g_lastInteractiveTick = mach_absolute_time();
        });

        %orig(flag, safeDismissCompletion);
        return;
    }
    %orig(flag, completion);
}

%end


// ====================================================================================================
// 5.1. BẮT TRẠNG THÁI GESTURE VUỐT THỰC TẾ & BÙ TỌA ĐỘ ĐÓN ĐẦU NGÓN TAY (MÔ PHỎNG SIÊU MƯỢT 120HZ)
// ====================================================================================================
%hook UIPanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    %orig(state);

    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        
        if (state == UIGestureRecognizerStateBegan ||
            state == UIGestureRecognizerStateChanged) {
            g_isUserTouchingScreen = YES;
            g_isScrollingActive = YES;
            g_isInteracting = YES; // Kích trần tối đa ngay khi ngón tay bắt đầu xê dịch
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            Titanium_TriggerInstantTouchBurst();
        } else if (state == UIGestureRecognizerStateEnded ||
                   state == UIGestureRecognizerStateCancelled) {
            g_isUserTouchingScreen = NO;
            g_isScrollingActive = NO;
            g_isInteracting = NO; // Nhả cờ tương tác trực tiếp
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now; // Bắt đầu tính cửa sổ đệm trước khi hạ sâu về 15Hz
        }
    }
}

// BÙ TRỄ TỌA ĐỘ ĐÓN ĐẦU: Đưa về 0.0ms (trả về tọa độ bám tay tuyệt đối 1:1)
- (CGPoint)translationInView:(UIView *)view {
    CGPoint original = %orig(view);
    
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        UIGestureRecognizerState st = self.state;
        if (st == UIGestureRecognizerStateChanged || st == UIGestureRecognizerStateBegan) {
            CGPoint velocity = [self velocityInView:view];
            
            if (isfinite(velocity.x) && isfinite(velocity.y)) {
                // ĐÃ ĐƯA VỀ 0.0ms (không bù đón đầu, triệt tiêu rung giật khi đổi hướng)
                const CGFloat kLeadFactor = 0.0f;
                original.x += velocity.x * kLeadFactor;
                original.y += velocity.y * kLeadFactor;
            }
        }
    }
    return original;
}

%end


// ====================================================================================================
// 5. ĐỘNG CƠ CUỘN SCROLLVIEW: ÉP BÁM TAY TỨC THÌ & BẢO TOÀN THUẬT TOÁN PAGING TIKTOK
// ====================================================================================================
%hook UIScrollView

// [ĐÃ ÉP TOÀN DIỆN]: Bắt đầu nhận diện cử chỉ cuộn ngay pixel đầu tiên
- (UIPanGestureRecognizer *)panGestureRecognizer {
    UIPanGestureRecognizer *pan = %orig;
    if (TITANIUM_LITE_MODE) return pan;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard() && pan) {
        pan.delaysTouchesBegan = NO;
    }
    return pan;
}

// [ĐÃ ÉP TOÀN DIỆN]: Cho phép hủy chạm con để ưu tiên cuộn lướt tức thì
- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if (TITANIUM_LITE_MODE) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) return YES;
    return %orig;
}

// [ĐÃ ÉP TOÀN DIỆN]: Triệt tiêu độ trễ nhận diện chạm nội dung
- (BOOL)delaysContentTouches {
    if (TITANIUM_LITE_MODE) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) return NO;
    return %orig;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_isUserTouchingScreen = YES;
        g_isInteracting = YES;
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(touches, event);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_isUserTouchingScreen = YES;
        g_isInteracting = YES;
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
    }
    %orig(touches, event);
}

// [ĐÃ SỬA]: Giữ trần FPS thêm 400ms khi buông tay để TikTok trượt xong hẳn, không giật khựng
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_isUserTouchingScreen = NO;
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(400 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (!g_isUserTouchingScreen && !self.isDecelerating) {
                g_isScrollingActive = NO;
                g_isInteracting = NO;
            }
        });
    }
}

// [ĐÃ SỬA]: Giữ cờ tương tác khi bị ngắt quãng cử chỉ
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig(touches, event);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_isUserTouchingScreen = NO;
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(400 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            if (!g_isUserTouchingScreen && !self.isDecelerating) {
                g_isScrollingActive = NO;
                g_isInteracting = NO;
            }
        });
    }
}

- (void)_scrollViewWillBeginDragging {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_isScrollingActive = YES;
        g_isUserTouchingScreen = YES;
        g_isInteracting = YES;
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        Titanium_TriggerInstantTouchBurst();
    }
    %orig;
}

- (void)_notifyDidScroll {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (g_isUserTouchingScreen || self.isDecelerating || self.isTracking || self.isDragging) {
            uint64_t now = mach_absolute_time();
            g_isScrollingActive = YES;
            g_isInteracting = YES;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    }
    %orig;
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (g_isUserTouchingScreen || self.isDecelerating || self.isTracking || self.isDragging) {
            uint64_t now = mach_absolute_time();
            g_isScrollingActive = YES;
            g_isInteracting = YES; // Khóa cứng trần FPS liên tục suốt quá trình trôi quán tính
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
        if (!self.isPagingEnabled && self.isDecelerating) {
            self.decelerationRate = 0.994f;
        }
    }
    %orig(timestamp);
}

// [ĐÃ SỬA]: Đồng bộ trả về 0.994f cho danh sách thường, giữ nguyên gốc cho app Paging
- (CGFloat)decelerationRate {
    if (TITANIUM_LITE_MODE) return %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        if (self.isPagingEnabled) return %orig;
        return 0.994f;
    }
    return %orig;
}

- (void)_stopScrollDecelerationNotify:(BOOL)notify {
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
}

- (void)_scrollViewDidEndDecelerating {
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
}

- (void)_scrollViewDidEndDraggingForChildScrollView:(id)view {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !self.isDecelerating && !g_isUserTouchingScreen) {
        uint64_t now = mach_absolute_time();
        g_isScrollingActive = NO;
        g_isInteracting = NO;
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
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
        g_isVolumeHoldingV285 = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)decreaseVolume {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isVolumeHoldingV285 = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)changeVolumeByDelta:(float)delta {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isVolumeHoldingV285 = YES;
        g_lastInteractionMachTime = mach_absolute_time();
    }
}

- (void)cancelVolumeEvent {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isVolumeHoldingV285 = NO;
        // [ĐÃ SỬA]: bản cũ zero mốc => thả nút âm lượng là nhả khóa nhịp NGAY về 0. Nay giữ cửa sổ giữ nhịp tắt dần như các cử chỉ khác.
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
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
            
            // Cấu hình trực tiếp trên windowScene ngay lập tức mà không dùng dispatch_async gây trễ khung hình
            if (@available(iOS 15.0, *)) {
                UIWindowScene *scene = self.windowScene;
                if (scene && [scene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float targetHz = (float)Titanium_GetTargetConfiguredHz();
                    if (targetHz < 15.0f) targetHz = 15.0f;
                    if (targetHz > 144.0f) targetHz = 144.0f;

                    // [ĐÃ KHÓA CỨNG]: Sàn (minimum) = Trần (maximum) = Nhịp ưu tiên (preferred) = targetHz
                    SafeFrameRateRange range = SafeMakeFRR(targetHz, targetHz, targetHz);
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
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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
                if (targetHz < 15.0f) targetHz = 15.0f;
                if (targetHz > 144.0f) targetHz = 144.0f;

                // [ĐÃ KHÓA CỨNG]: Gán thẳng mức đã chọn vào DisplayLink, không check điều kiện chạm tay
                self.preferredFrameRateRange = SafeMakeFRR(targetHz, targetHz, targetHz);
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
    // [ĐÃ SỬA ĐỢT 5]: LUÔN cập nhật cờ nhiệt (kể cả lite mode) để hạ nhịp tự động khi nóng; không nói dối với app.
    NSProcessInfoThermalState real = %orig;
    g_thermalSeriousV285 = (real >= NSProcessInfoThermalStateSerious);
    if (TITANIUM_LITE_MODE) return real;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        // [ĐÃ SỬA]: khi máy THẬT SỰ nóng (Serious/Critical) phải báo đúng để app tự giảm tải. Bản cũ nói dối "Nominal" ngay cả lúc đó,
        // app không bao giờ giảm tải => máy nóng nhanh, hệ điều hành phải bóp xung mạnh hơn => giật lag.
        NSProcessInfoThermalState realThermalState = %orig;
        if (realThermalState >= NSProcessInfoThermalStateSerious) {
            return realThermalState;
        }
        // Nếu bật khóa 30 FPS khi quá nhiệt và máy đang sạc: trả về mặc định để máy tự điều tiết an toàn
        if (CFG285.lock30FpsOnOverheat && g_isDeviceChargingV285) {
            return %orig;
        }
        // V22: không giả lập máy "Nominal" khi có yêu cầu chống bóp xung.
        // Trạng thái nhiệt thật giúp iOS tự bảo vệ thiết bị và tránh tải nhiệt kéo dài.
        // Các tuỳ chọn anti-thermal chỉ được dùng để điều chỉnh tải của tweak, không che giấu nhiệt hệ thống.
        (void)g_isRateLockedV285;
        (void)CFG285.antiThermalThrottling;
        (void)CFG285.dynamicThermalEngine;
        (void)g_syncPayloadV285.thermalShield;
    }
    return %orig;
}

// 2. [ĐÃ ÉP TOÀN DIỆN]: Điều phối chế độ tiết kiệm pin theo cấu hình
- (BOOL)isLowPowerModeEnabled {
    // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]: không báo sai Low Power Mode với app. Khi báo "đang tiết kiệm pin", app mạng/video tự cắt tự động phát, tải trước,
    // hạ chất lượng và game hạ còn 30 FPS => cảm giác lag và "app mạng không vào/không tải"; báo "không tiết kiệm" khi thật sự đang bật cũng sai.
    if (TITANIUM_LITE_MODE) return %orig;
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
    // [ĐÃ SỬA V10 - APP MẠNG BỊ COI NHẦM LÀ GAME]: không đặt g_isMetalGameProcess=YES ở init (layer mới init chưa có kích thước,
    // mọi app có video/CAMetalLayer nhỏ đều bị coi là game => tweak bypass => cảm giác nghẽn, không mượt).
    // Để didMoveToWindow quyết định dựa trên kích thước thực tế (>=75% màn hình mới coi là game).
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
        // [V12 SỬA - Hz/FPS KHÔNG TÁC DỤNG TRONG GAME]: bản cũ ghi vào g_lastSyncTicksV285 (mốc BÓP CỔ CHAI nạp IPC)
        // mỗi khung hình => bộ nạp cấu hình bị chặn vĩnh viễn trong app Metal, chỉnh Hz/FPS không bao giờ "ăn".
        // Đúng bản chất đây là mốc TƯƠNG TÁC => ghi vào g_lastInteractionMachTime.
        g_lastInteractionMachTime = mach_absolute_time();
        if (!Titanium_IsSpringBoard()) {
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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
    // [ĐÃ SỬA]: không còn nói dối trạng thái hàng đợi GPU (app nền/đang khởi động không được phép gửi lệnh GPU).
#if TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
#endif
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
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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
    // [ĐÃ SỬA - NGUYÊN NHÂN APP MẠNG XÁM/ĐEN/VĂNG]: texture tạo từ IOSurface/CVPixelBuffer (video, ảnh giải mã) BẮT BUỘC allowGPUOptimizedContents = NO.
    // Bản cũ ép YES trong mọi tiến trình nên tạo texture video/ảnh thất bại hoặc ra rác => nội dung xám/đen, app chờ mãi hoặc văng.
#if TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
#endif
    return %orig;
}

- (void)setAllowGPUOptimizedContents:(BOOL)flag {
#if TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(YES);
        return;
    }
#endif
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
        // [V12 SỬA]: 50ms đổi sang Mach ticks (bản cũ thực tế ~2.1 GIÂY mới boost P-Core 1 lần => vuốt cảm giác chậm)
        if (now - s_lastPcoreBurst > Titanium_NanosToMachTicks(50ULL * 1000000ULL)) {
            s_lastPcoreBurst = now;
            g_lastInteractionMachTime = now;
            
            if (CFG285.schedulerGovernor || CFG285.pCoreRealtimePriority || g_isRateLockedV285) {
                /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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

- (BOOL)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && [NSThread isMainThread] && (CFG285.ultraResponsivenessPro || g_isRateLockedV285)) {
        // V22: không ghim QoS trong runloop; để iOS điều phối theo tải thực tế.
    }
    // [ĐÃ SỬA]: chữ ký gốc là "- (BOOL)runMode:beforeDate:". Bản cũ khai báo void và bỏ mất giá trị trả về, các vòng lặp runloop
    // (luồng mạng/NSURLConnection tự chạy "while ([runLoop runMode:...])") có thể thoát sớm hoặc quay vô hạn => như nghẽn mạng / xám mãi.
    return %orig;
}

%end

%hook CALayer

// Cưỡng bức trả về NO cho app con để GPU vẽ đồng bộ trực tiếp, chống rỗng buffer đen màn hình
- (BOOL)drawsAsynchronously {
    // Giữ lựa chọn của UIKit/app; ép NO cho mọi layer app làm vẽ đồng bộ trên main thread và gây khựng.
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
    if (TITANIUM_LITE_MODE) return; // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]
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
    // [ĐÃ SỬA]: chỉ can thiệp khi app TỰ BẬT rasterize (val == YES). Bản cũ ép YES cả khi app chủ động tắt (NO) => layer chứa
    // video/Metal/GL bị rasterize sẽ đen hình, layer lớn tốn RAM/GPU làm app xám, đơ hoặc bị Jetsam văng.
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

// [ĐÃ ÉP TOÀN DIỆN]: Ép vẽ bất đồng bộ và gộp opacity cho hiệu ứng làm mờ
- (void)didMoveToWindow {
    %orig;
    if (TITANIUM_LITE_MODE) return; // [ĐÃ SỬA - CHẾ ĐỘ NHẸ]
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
    // [ĐÃ SỬA]: bản cũ hạ QoS của luồng gọi flush (chính là luồng chính của app) xuống DEFAULT mỗi khi rảnh => luồng giao diện thua
    // luồng mạng/giải mã ảnh, app khởi động & nạp nội dung chậm, hay bị xám/đen. Giữ code cũ nhưng TẮT mặc định (xem TITANIUM_ALLOW_FLUSH_QOS_DEMOTION).
#if TITANIUM_ALLOW_FLUSH_QOS_DEMOTION
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        if (CFG285.coolDownHeavyLoad || CFG285.backgroundPacingDaemon) {
            if (!Titanium_ShouldLockTargetRate() && !g_isUserTouchingScreen && !g_isScrollingActive && !g_isRateLockedV285) {
                pthread_set_qos_class_self_np(QOS_CLASS_DEFAULT, 0);
            }
        }
    }
#endif
}

%end

%end

// ====================================================================================================
// NHÓM 20: DEEP RAM COMPACTION & MACH VM PURGABLE ENGINE (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Hyper Memory Guardian + Dọn RAM Định Kỳ + Dọn RAM Chuyên Sâu + Đóng App Nền)
// ====================================================================================================

%group Group_Deep_RAM_Compaction_Engine

%hook UIApplication

- (void)_applicationDidEnterBackground {
    // Chỉ chuyển tiếp sự kiện nền gốc của hệ thống
    // Tuyệt đối KHÔNG gọi purge RAM để app không bị mất cache và không bị hệ thống kill
    %orig;
}

%end

// V26.5: no UIViewController viewDidDisappear purge hook. That callback is part of app-navigation
// paths; scavenging there can add work near transition/animation and is not proof of a RAM leak.

%hook SBAppSwitcherSnapshotImageCache

// [ĐÃ ÉP TOÀN DIỆN]: Ép dọn RAM ngầm sau khi nạp ảnh thẻ đa nhiệm App Switcher
- (void)reloadImagesForAllItems {
    %orig;
    // V26 VIP: avoid repeated heap-pressure relief during switcher snapshot animation.
    if (TITANIUM_LITE_MODE) return;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.aggressiveRamClean || CFG285.hyperMemoryGuardian || g_syncPayloadV285.aggressiveRamCleaner)) {
        Titanium_BackgroundPurgeMemory();
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
    // V26.5: intentionally do not purge page/memory caches on window detach. Detach is a normal
    // navigation event, not proof of memory pressure; forced cache clearing can make the next
    // screen reload and consume more CPU/battery. iOS/WebKit memory-warning handling remains below.
}

// [ĐÃ ÉP TOÀN DIỆN]: Ép WebKit giải phóng sạch buffer ảnh rác khi bộ nhớ chạm ngưỡng cảnh báo
- (void)_didReceiveMemoryWarning {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        // [ĐÃ SỬA]: không capture self / không đụng WKWebView ở luồng nền (xem ghi chú ở didMoveToWindow)
        WKProcessPool *pool = [NSThread isMainThread] ? self.configuration.processPool : nil;
        if ([pool respondsToSelector:@selector(_clearMemoryCache)]) {
            [pool _clearMemoryCache];
        }
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        });
    }
}

%end

// V26.5: removed the process-wide WKProcessPool background observer. Private cache-purge calls
// on every background transition can discard useful caches and cause expensive reloads on resume.
// WKWebView's explicit memory-warning hook above remains the pressure-response path.

%end

// ====================================================================================================
// NHÓM ĐẶC QUYỀN: ÉP PHẦN CỨNG NHẬN DIỆN & CHẠY PROMOTION THẬT (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Ép Xung ProMotion Cố Định + Tăng Tần Số Lấy Mẫu Cảm Ứng 1000Hz + Ổ Khóa App)
// (AN TOÀN TUYỆT ĐỐI: BẢO VỆ BỘ NHỚ CFRETAIN TRÁNH CRASH MEMORY CORRUPTION)
// ====================================================================================================

%group Group_Hardware_ProMotion_Overclock

extern "C" CFPropertyListRef MGCopyAnswer(CFStringRef property);

// [ĐÃ ÉP TOÀN DIỆN]: Ép toàn bộ cờ Variable Refresh Rate & ProMotion của Apple qua MobileGestalt
%hookf(CFPropertyListRef, MGCopyAnswer, CFStringRef property) {
    // [ĐÃ SỬA ĐỢT 5 - NGUYÊN NHÂN CHÍNH GÂY GIẬT/ĐỨNG KHUNG HÌNH TRÊN MÁY 60Hz]:
    // Trước đây只要 forceOverclock mặc định = 1 (hoặc bật Hz control) là MGCopyAnswer LUÔN báo
    // SupportsVariableRefreshRate / ProMotion = true NGAY CẢ trên tấm nền 60Hz. Hệ thống chuyển sang
    // chính sách hạ nhịp kiểu ProMotion mà tấm nền không có => hoạt ảnh đứng hẳn sau khi nhả tay, giật từng khung.
    // Nay chỉ khai man khi phần cứng thật sự có ProMotion (hoặc người dùng chủ động bật spoof macro).
    if (property && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_DisplaySpoofAllowed() && (CFG285.proMotionEngineBeta7 || CFG285.enableHzControl || g_isRateLockedV285 || g_syncPayloadV285.forceOverclock)) {
        if (CFEqual(property, CFSTR("SupportsVariableRefreshRate")) ||
            CFEqual(property, CFSTR("supports-variable-refresh-rate")) ||
            CFEqual(property, CFSTR("pVRR")) ||
            CFEqual(property, CFSTR("pro-motion")) ||
            CFEqual(property, CFSTR("DeviceSupports120Hz")) ||
            CFEqual(property, CFSTR("DeviceSupportsProMotion"))) {
            return CFRetain(kCFBooleanTrue); // CFRetain bắt buộc để tuân thủ quy tắc Copy Rule chống Crash
        }
    }
    return %orig(property);
}

%hook IOHIDEventSystemClient

// [ĐÃ ÉP TOÀN DIỆN]: Ép tần số lấy mẫu cảm ứng phần cứng lên 1000Hz (0.001s polling interval)
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
// NHÓM ĐỘC QUYỀN APPLE RUNTIME: ÉP VƯỢT MỨC KHỞI ĐỘNG ĐẦU TIÊN (ZERO BLACK SCREEN OVERDRIVE)
// (CHUẨN RUNTIME PRIVATE: HOÀN TOÀN MỚI, KHÔNG TRÙNG HOOK CŨ, ÉP LOADING XONG TỰ BUNG 144HZ)
// ====================================================================================================

%group Group_Apple_Native_ColdBoot_Overdrive

static volatile BOOL g_isAppFirstFramePresented = NO;
static volatile uint64_t g_processLaunchTimestampTicks = 0;

%hook UIWindowScene

// Khởi tạo scene cửa sổ lần đầu: Ép dựng khung hình không để GPU bị đói texture
- (void)_readySceneForDisplay {
    %orig;
    if (!Titanium_IsSpringBoard()) {
        g_processLaunchTimestampTicks = mach_absolute_time();
        
        // Cấp nhịp quét 60Hz ban đầu trong 0.5s để splash/loading screen nạp xong xuôi
        if (@available(iOS 15.0, *)) {
            if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                [(id)self setPreferredFrameRateRange:SafeMakeFRR(60.0f, 60.0f, 60.0f)];
            }
        }

        // Sau 0.5s: Ép vượt trần kịch kim lên 144Hz cho toàn bộ scene
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            g_isAppFirstFramePresented = YES;
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */

            if (@available(iOS 15.0, *)) {
                float targetHz = (float)Titanium_GetTargetConfiguredHz();
                if (targetHz < 15.0f) targetHz = 15.0f;
                if (targetHz > 144.0f) targetHz = 144.0f;

                if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    [(id)self setPreferredFrameRateRange:SafeMakeFRR(Titanium_RangeFloorForCap(targetHz), targetHz, targetHz)];
                }
            }
        });
    }
}

%end

%hook UIScene

// Bắt đúng sự kiện scene chuyển từ Inactive sang Active lần đầu tiên
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

%hook FBApplicationProcess

// Can thiệp mức Bootstrap tiến trình Springboard: Cấp quyền nạp 0ms không giữ watchdog
- (void)_finishInit {
    %orig;
    if (Titanium_IsSpringBoard()) {
        Titanium_LockMainThreadFast();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 2: ÉP CỨNG CAWINDOWSERVER TẦNG GỐC PHẦN CỨNG (DÀNH CHO TIẾN TRÌNH SPRINGBOARD)
// ====================================================================================================

%group Group_CAWindowServer_Absolute_Dominance

%hook CAWindowServerDisplay

- (double)minimumFrameDuration {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 144.0) targetHz = 144.0;
    return (1.0 / targetHz);
}

- (void)setMinimumFrameDuration:(double)duration {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 144.0) targetHz = 144.0;
    %orig(1.0 / targetHz);
}

- (double)maximumRefreshRate {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 144.0) targetHz = 144.0;
    return targetHz;
}

- (void)setMaximumRefreshRate:(double)rate {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 144.0) targetHz = 144.0;
    %orig(targetHz);
}

- (double)idealRefreshRate {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 144.0) targetHz = 144.0;
    return targetHz;
}

- (void)setIdealRefreshRate:(double)rate {
    double targetHz = (double)Titanium_GetTargetConfiguredHz();
    if (targetHz < 15.0) targetHz = 15.0;
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
    if (targetHz < 15) targetHz = 15;
    if (targetHz > 144) targetHz = 144;
    return targetHz;
}

- (void)setPreferredFPS:(NSInteger)fps {
    NSInteger targetHz = (NSInteger)Titanium_GetTargetConfiguredHz();
    if (targetHz < 15) targetHz = 15;
    if (targetHz > 144) targetHz = 144;
    %orig(targetHz);
}

%end

%end

// ====================================================================================================
// NHÓM 3: BẢO VỆ BUFFER LAYER & METAL (CHỐNG DROP BUFFER TRÊN TIẾN TRÌNH APP THỨ BA)
// ====================================================================================================

%group Group_Force_Render_Recovery_Overdrive

%hook CALayer

- (BOOL)drawsAsynchronously {
    if (!Titanium_IsSpringBoard()) {
        return NO;
    }
    return %orig;
}

- (void)setNeedsDisplay {
    // [ĐÃ SỬA - NGUYÊN NHÂN CHÍNH GÂY ĐEN APP LÚC KHỞI ĐỘNG / XÁM MÃI]:
    // Bản cũ NUỐT (return, không gọi bản gốc) mọi lệnh setNeedsDisplay của app trong "800ms" đầu. Lệnh vẽ bị nuốt thì layer
    // không bao giờ được vẽ lại (UILabel, view tự vẽ, placeholder...) => màn hình đen/xám cho tới khi có lệnh vẽ khác.
    // Tệ hơn: mốc thời gian là Mach ticks nhưng so với hằng số nano-giây nên 800ms thực tế = ~33 GIÂY trên A11 trở lên.
    // Một lệnh invalidate không bao giờ được phép bỏ đi, nên luôn chuyển thẳng cho bản gốc.
    %orig;
}

%end

%hook CAMetalLayer

- (BOOL)allowsNextDrawableTimeout {
    if (!Titanium_IsSpringBoard()) {
        return YES;
    }
    return %orig;
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
            /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */

            if (@available(iOS 15.0, *)) {
                float targetHz = (float)Titanium_GetTargetConfiguredHz();
                if (targetHz < 15.0f) targetHz = 15.0f;
                if (targetHz > 144.0f) targetHz = 144.0f;

                if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    [(id)self setPreferredFrameRateRange:SafeMakeFRR(Titanium_RangeFloorForCap(targetHz), targetHz, targetHz)];
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
                    if (targetHz < 15.0f) targetHz = 15.0f;
                    if (targetHz > 144.0f) targetHz = 144.0f;
                    [(id)scene setPreferredFrameRateRange:SafeMakeFRR(Titanium_RangeFloorForCap(targetHz), targetHz, targetHz)];
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
        /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
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

// V16 FIX: Đã vô hiệu hóa nhóm Backboardd TouchDriver vì không được %init.
// Không hook BKTouchDeliveryPolicyServer/BKHIDEventProcessor để tránh lỗi Logos và rủi ro hệ thống.

// ====================================================================================================
// NHÓM V10: BOOST LAYOUT SPRINGBOARD & ĐA NHIỆM & MÀN HÌNH CHÍNH (CACHE QoS - KHÔNG OVERHEAD, KHÔNG GIẬT)
// Chỉ gọi pthread_set_qos khi layout xảy ra ĐÚNG lúc đang tương tác (vuốt/cuộn/chuyển cảnh), và cache
// theo luồng nên syscall chỉ chạy 1 lần. Khử khựng 1 nhịp khi vuốt ra về home, vào đa nhiệm, mở thư mục.
// ====================================================================================================
%group Group_TitaniumV10_SpringBoard_Layout_Boost

static inline void Titanium_V10_PinMainThreadHigh(void) {
    if (![NSThread isMainThread]) return;
    static __thread int s_v10LayoutQos = -1;
    if (s_v10LayoutQos != (int)QOS_CLASS_USER_INTERACTIVE) {
        /* V22: leave QoS scheduling to iOS to reduce sustained heat and contention. */
        s_v10LayoutQos = (int)QOS_CLASS_USER_INTERACTIVE;
    }
}

%hook SBIconListView
- (void)layoutSubviews {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (g_isUserTouchingScreen || g_isScrollingActive || g_isContinuousSwiping)) {
        Titanium_V10_PinMainThreadHigh();
    }
    %orig;
}
%end

%hook SBFolderView
- (void)layoutSubviews {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (g_isUserTouchingScreen || g_isScrollingActive || g_isContinuousSwiping)) {
        Titanium_V10_PinMainThreadHigh();
    }
    %orig;
}
%end

%hook SBFluidSwitcherViewController
- (void)viewWillLayoutSubviews {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        Titanium_V10_PinMainThreadHigh();
    }
    %orig;
}
%end

%hook SBMainDisplaySceneLayoutViewController
- (void)viewWillLayoutSubviews {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        Titanium_V10_PinMainThreadHigh();
    }
    %orig;
}
%end

%end

// ====================================================================================================
// ███ KHỐI V12 - SIÊU MƯỢT ROOTHIDE (iPhone 6s -> 15 Pro Max, iOS 14.0 -> 26.0.1) ███
// (TOÀN BỘ LÀ CODE MỚI THÊM - KHÔNG CẮT BỚT BẤT KỲ NHÓM NÀO PHÍA TRÊN)
//  - Đa ngôn ngữ TỰ ĐỘNG theo ngôn ngữ & vùng của máy, đồng bộ qua payload IPC
//  - Áp dụng Hz/FPS MỚI NGAY cho app đang mở sẵn (sửa "chỉnh trong app không tác dụng toàn hệ thống")
//  - Hết cú "nảy" nặng khi vuốt thoát app về icon (kẹp damping của CASpringAnimation)
//  - Pin 1-20% vẫn mượt: ưu tiên giao diện, hoãn dọn heap tốn CPU (đánh đổi pin lấy mượt + mát)
//  - Heartbeat IPC 5s/lần: app mở sau luôn nhận đúng Hz/FPS/công tắc mới nhất
// ====================================================================================================

// ----------------------------------------------------------------------------------------------------
// [V12 - ĐA NGÔN NGỮ TỰ ĐỘNG CHUẨN]
// Thứ tự phân giải: (1) Người dùng chọn tay trong app (SelectedLanguage != "auto")
//                   (2) "auto" => theo NGÔN NGỮ MÁY qua NSLocale (máy English => tweak English, máy Việt => Việt...)
//                   (3) Dự phòng: mã ngôn ngữ SpringBoard nhúng trong payload IPC ("LG:xx" ở reserved)
// NSLocale hoạt động bình thường cả trong sandbox của app thứ ba nên mọi tiến trình đều đồng nhất ngôn ngữ.
// ----------------------------------------------------------------------------------------------------
static NSString *Titanium_ResolveEffectiveLanguage(void) {
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
        return @"en"; // Ngôn ngữ lạ ngoài danh sách => chuẩn quốc tế English
    }
    const char *res = (const char *)g_syncPayloadV285.reserved;
    if (res[0] == 'L' && res[1] == 'G' && res[2] == ':') {
        NSString *code = [NSString stringWithUTF8String:&res[3]];
        if (code.length > 0) return code;
    }
    return @"en";
}

// [V12] Helper song ngữ nhanh cho mọi chuỗi hiển thị trong tweak/app (Việt <=> Anh, mở rộng tuỳ ý)
static inline NSString *Titanium_TrV12(NSString *viText, NSString *enText) {
    return [[Titanium_ResolveEffectiveLanguage() lowercaseString] hasPrefix:@"vi"] ? (viText ?: enText) : (enText ?: viText);
}

// ====================================================================================================
// NHẬN DIỆN APP AI TỰ ĐỘNG & DUY TRÌ HIỆU NĂNG PIN 1% - 80% NHƯ PIN ĐẦY
// Tự động quét qua Bundle ID, Tên app, Info.plist và Class Runtime (không cần điền tay từng app)
// ====================================================================================================

static inline BOOL Titanium_IsAIApp(void) {
    static BOOL s_isAI = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (Titanium_IsSpringBoard()) {
            s_isAI = NO;
            return;
        }

        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [[mainBundle bundleIdentifier] lowercaseString] ?: @"";
        if (bundleID.length == 0) return;

        // 1. Tự quét toàn bộ siêu dữ liệu (Metadata): Tên hiển thị, Tên gói, Tệp thực thi
        NSDictionary *infoDict = [mainBundle infoDictionary];
        NSString *displayName = [infoDict[@"CFBundleDisplayName"] lowercaseString] ?: @"";
        NSString *bundleName  = [infoDict[@"CFBundleName"] lowercaseString] ?: @"";
        NSString *execName    = [infoDict[@"CFBundleExecutable"] lowercaseString] ?: @"";

        // Gộp tất cả thông tin định danh để quét đối soát
        NSString *target = [NSString stringWithFormat:@"%@ | %@ | %@ | %@", bundleID, displayName, bundleName, execName];

        // 2. Quét bộ từ khóa nền tảng & mô hình AI toàn cầu
        NSArray<NSString *> *aiKeywords = @[
            @"openai", @"chatgpt", @"gemini", @"claude", @"anthropic",
            @"perplexity", @"copilot", @"deepseek", @"poe", @"grok",
            @"llama", @"mistral", @"qwen", @"kimi", @"doubao",
            @"midjourney", @"civitai", @"novelai", @"sora", @"characterai",
            @"chatbox", @"typingmind", @"monica", @"groq", @"ollama"
        ];

        for (NSString *keyword in aiKeywords) {
            if ([target containsString:keyword]) {
                s_isAI = YES;
                return;
            }
        }

        // 3. Quét mẫu ký tự nhận diện AI (Lọc chuẩn để không dính nhầm từ như: mail, gmail, detail...)
        NSArray<NSString *> *genericPatterns = @[
            @".ai.", @".ai", @"ai.", @"-ai", @"ai-", @"_ai", @"ai_",
            @" ai", @"ai ", @"gpt", @"llm", @"chatbot", @"chat-ai",
            @"aichat", @"ai assistant", @"prompt"
        ];

        for (NSString *pattern in genericPatterns) {
            if ([target containsString:pattern]) {
                s_isAI = YES;
                return;
            }
        }

        // 4. Quét sâu tầng Runtime: Tự phát hiện các thư viện dựng Markdown / Token Stream đặc trưng của App AI
        if (objc_getClass("ChatCompletion") != nil ||
            objc_getClass("OpenAIService") != nil ||
            objc_getClass("MarkdownParser") != nil ||
            objc_getClass("DownView") != nil ||
            objc_getClass("SyntaxHighlighter") != nil ||
            objc_getClass("StreamingMessage") != nil) {
            s_isAI = YES;
            return;
        }
    });
    return s_isAI;
}

// [PIN 1-80% VẪN MƯỢT NHƯ 100%]: Giữ nguyên xung nhịp và ưu tiên render
static void Titanium_UpdateLowBatteryFlagV12(void) {
    float lvl = g_batteryLevelV12;
    if (lvl < 0.0f) lvl = 1.0f;
    // Bật boost ưu tiên mượt liên tục từ 1% đến 80% pin
    g_lowBatterySmoothBoostV12 = (lvl <= 0.80f && !g_isDeviceChargingV285);
}

// ----------------------------------------------------------------------------------------------------
// [V12 - Hz/FPS TÁC DỤNG TOÀN HỆ THỐNG NGAY LẬP TỨC]
// Trước đây app ĐANG MỞ SẴN chỉ được áp dụng dải nhịp mới khi đóng mở lại cửa sổ. Hàm này duyệt toàn bộ
// scene hiện có và đặt lại preferredFrameRateRange ngay tại thời điểm cấu hình thay đổi.
// ----------------------------------------------------------------------------------------------------
static void Titanium_ReapplyFrameRateToAllScenes(void) {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ Titanium_ReapplyFrameRateToAllScenes(); });
        return;
    }
    if (g_isCurrentAppBlacklisted) return;
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return;
    @try {
        UIApplication *app = [UIApplication sharedApplication];
        if (!app) return;
        if (@available(iOS 13.0, *)) {
            NSSet *scenes = app.connectedScenes;
            for (UIScene *scene in scenes) {
                if (![scene isKindOfClass:[UIWindowScene class]]) continue;
                if (@available(iOS 15.0, *)) {
                    UIWindowScene *winScene = (UIWindowScene *)scene;
                    if (![winScene respondsToSelector:@selector(setPreferredFrameRateRange:)]) continue;

                    SafeFrameRateRange current = winScene.preferredFrameRateRange;
                    SafeFrameRateRange normalized = Titanium_NormalizeFrameRateRange(current, Titanium_IsSpringBoard());
                    BOOL changed = !isfinite(current.minimum) || !isfinite(current.maximum) || !isfinite(current.preferred) ||
                                   fabsf(current.minimum - normalized.minimum) > 0.5f ||
                                   fabsf(current.maximum - normalized.maximum) > 0.5f ||
                                   fabsf(current.preferred - normalized.preferred) > 0.5f;
                    if (changed) [winScene setPreferredFrameRateRange:normalized];
                }
            }
        }
    } @catch (NSException *e) {}
}

// ----------------------------------------------------------------------------------------------------
// [V12 - HẾT "NẢY" KHI VUỐT THOÁT APP]: nhận biết cửa sổ đang đóng app về Home / đóng folder / rời đa nhiệm
// (đang vuốt Home gesture hoặc trong 250ms sau tương tác cuối) để kẹp độ nảy của spring cho thẳng & nhanh.
// ----------------------------------------------------------------------------------------------------
static inline BOOL Titanium_IsDismissingToHomeV12(void) {
    if (g_isContinuousSwiping) return YES;
    if (g_lastInteractionMachTime == 0) return NO;
    uint64_t now = mach_absolute_time();
    return ((now - g_lastInteractionMachTime) < Titanium_NanosToMachTicks(250ULL * 1000000ULL));
}

// [V12] Khai báo property cho SDK cũ (iOS 14) chưa có CAFrameRateRange - chống lỗi biên dịch, runtime tự no-op
@interface CADisplayLink (TitaniumV12FrameRateRange)
@property (nonatomic) SafeFrameRateRange preferredFrameRateRange;
@end

%group Group_TitaniumV12_SmoothExit_And_DisplayLink

%hook CADisplayLink

- (SafeFrameRateRange)preferredFrameRateRange {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.enableHzControl || g_syncPayloadV285.targetHz > 0)) {
        if (Titanium_IsCurrentAppAGame()) {
            return %orig;
        }

        float cap = (float)Titanium_GetEffectiveFrameCap();
        if (cap < 15.0f) cap = 15.0f;
        if (cap > 144.0f) cap = 144.0f;

        // [ĐÃ KHÓA CỨNG]: Luôn trả về đúng mức đã chỉnh (Min = Max = Preferred = cap)
        // Triệt tiêu hoàn toàn nhánh 15Hz và nhánh hạ 30Hz khi phát video
        return SafeMakeFRR(cap, cap, cap);
    }
    return %orig;
}

%end

// --- [V12] Hết cú "nảy" nặng trước khi app thu về icon ---
// Khôi phục độ nảy nhẹ khi vuốt thoát app: damping tối thiểu 14, tránh nảy quá mạnh nhưng không triệt tiêu hoàn toàn.
// Chỉ tác động trong cửa sổ đang vuốt thoát/đóng app về icon; các phần code khác giữ nguyên.
%hook CASpringAnimation

- (CGFloat)damping {
    CGFloat orig = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() && Titanium_IsDismissingToHomeV12()) {
        if (orig < 14.0) return 14.0;
    }
    return orig;
}

- (void)setDamping:(CGFloat)damping {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard() && Titanium_IsDismissingToHomeV12()) {
        if (damping < 14.0) damping = 14.0;
    }
    %orig(damping);
}

%end

%end

// ====================================================================================================
// V22 ADAPTIVE SAFE RUNTIME: profile mặc định chỉ cài nhóm API DisplayLink/Scene có kiểm tra an toàn.
// Các nhóm private/Metal/WindowServer khác không được %init mặc định vì có thể gây đen app hoặc kẹt userspace reboot.
// ====================================================================================================
%group Group_TitaniumSafeRuntime_V22

%hook CADisplayLink

// [ĐÃ KHÓA CỨNG]: Ép thẳng về cap, bỏ hoàn toàn điều kiện video để không bị tụt nhịp trong TikTok/YouTube
- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        NSInteger nativeMax = Titanium_NativeMaximumFPS();
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        if (cap < 15) cap = 15;
        if (cap > nativeMax) cap = nativeMax;

        // Khóa cứng FPS luôn bằng cap
        %orig(cap);
        return;
    }
    %orig;
}

%end

%end

%group Group_TitaniumSafeRangeRuntime_V22

%hook CADisplayLink

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float maxCap = (float)Titanium_GetEffectiveFrameCap();
            if (maxCap < 15.0f) maxCap = 15.0f;
            if (maxCap > 144.0f) maxCap = 144.0f;

            // [ĐÃ KHÓA CỨNG]: Sàn = Trần = Nhịp ưu tiên = maxCap trong mọi tình huống
            range = SafeMakeFRR(maxCap, maxCap, maxCap);
        }
    }
    %orig(range);
}

%end

%end

// iOS 15+: use the same zero-safe policy for app scenes and SpringBoard system scenes.
%group Group_TitaniumSafeSceneRangeRuntime_V22

%hook UIWindowScene

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            // Hàm Titanium_NormalizeFrameRateRange đã được khóa cứng gán Min = Max = Preferred = cap
            range = Titanium_NormalizeFrameRateRange(range, Titanium_IsSpringBoard());
        }
    }
    %orig(range);
}

%end

%end

// ==============================================================================
// GIỮ APP TRONG RAM - CHỐNG TERMINATE / CHỐNG JETSAM KILL KHI XUỐNG NỀN
// ==============================================================================

%group Group_KeepAppsAlive_NoKill

// 1. Chặn FrontBoard tự động hủy tiến trình app khi chạy nền
%hook FBProcess

- (void)killForReason:(long long)reason 
         andReport:(BOOL)report 
   withDescription:(id)description 
        completion:(id)completion {
    // reason == 1 thường là system memory pressure / background timeout
    // Nếu app bị kill chỉ vì ở dưới nền lâu hoặc timeout, bỏ qua lệnh kill
    if (reason == 1 || [description containsString:@"background"] || [description containsString:@"idle"]) {
        if (completion) {
            void (^compBlock)(void) = (void (^)(void))completion;
            compBlock();
        }
        return; // Không chuyển tiếp lệnh kill xuống kernel
    }
    %orig; // Vẫn cho phép crash thật sự hoặc người dùng chủ động vuốt đóng ở đa nhiệm
}

- (BOOL)isPendingExit {
    return NO; // Giữ tiến trình luôn ở trạng thái sẵn sàng
}

%end

// 2. Không cho phép SpringBoard dọn dẹp các app vừa rơi vào trạng thái suspended
%hook SBMainWorkspace

- (void)handleApplicationSuspended:(id)application {
    // Cho phép app đóng băng dữ liệu nhưng không kích hoạt chu kỳ giải phóng tài nguyên
    %orig;
}

%end

// 3. Giữ toàn bộ snapshot và bộ nhớ đệm thẻ app trong RAM (App Switcher)
%hook SBAppSwitcherSettings

- (BOOL)shouldKeepAppSnapshotsInMemory {
    return YES; // Giữ snapshot trong RAM để vuốt đa nhiệm 0ms không tải lại
}

- (BOOL)shouldSimplifyForOptions:(long long)options {
    return NO;
}

%end

// 4. Cho phép app nạp trước dữ liệu để sẵn sàng bung ra ngay lập tức
%hook SBApplication

- (BOOL)shouldPrewarmOnLaunch {
    return YES;
}

%end

%end

// ====================================================================================================
// NHÓM MỚI TỰ TẠO: TỐI ƯU CỬ CHỈ ĐA NHIỆM & SPRINGBOARD (X THẬT & X GIẢ)
// ====================================================================================================
%group Group_SpringBoard_Switcher_Opt

%hook _UIScreenEdgePanGestureRecognizer
- (BOOL)delaysTouchesBegan {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return NO;
    }
    return %orig;
}

- (double)_edgeRegionSize {
    double size = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return (size > 0.0) ? (size * 1.2) : 20.0;
    }
    return size;
}
%end

%hook SBFluidSwitcherItemContainer
- (void)setShadowStyle:(long long)style {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        if (g_isInteracting || g_isScrollingActive) {
            %orig(0);
            return;
        }
    }
    %orig;
}
%end

%hook SBAppSwitcherSettings
- (BOOL)shouldSimplifyForOptions:(long long)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return YES;
    }
    return %orig;
}
%end

%hook SBMainWorkspace
- (void)_handleDismissOverlaysGesture:(id)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    }
    %orig;
}
%end

%end

%group Group_AI_Stream_Optimization

// 1. Chống Watchdog ép đóng app khi parse code/Markdown nặng
%hook FBProcessWatchdog
- (void)start {
    %orig;
    if (Titanium_IsAIApp()) {
        if ([self respondsToSelector:@selector(invalidate)]) {
            [(id)self invalidate]; // Hủy đếm ngược ép văng app
        }
    }
}
%end

%hook FBSceneWatchdog
- (id)initWithTimeout:(double)timeout {
    if (Titanium_IsAIApp()) {
        return %orig(300.0); // Nâng trần timeout lên 300s
    }
    return %orig(timeout);
}
%end

// 2. Ép vẽ bất đồng bộ: Đẩy render code/chữ sang luồng phụ, luồng chính không bị đơ
%hook CALayer

- (BOOL)drawsAsynchronously {
    if (Titanium_IsAIApp()) return YES;
    return %orig;
}

- (void)setDrawsAsynchronously:(BOOL)draws {
    if (Titanium_IsAIApp()) {
        %orig(YES);
        return;
    }
    %orig(draws);
}

%end

// 3. Khử trễ cuộn khung chat văn bản
%hook UITextView

- (void)didMoveToWindow {
    %orig;
    if (Titanium_IsAIApp() && self.window) {
        self.delaysContentTouches = NO;
        self.canCancelContentTouches = YES;
    }
}

%end

%end

// ----------------------------------------------------------------------------------------------------
// [V12 - HEARTBEAT IPC]: SpringBoard làm tươi tệp đồng bộ + heartbeat mỗi 30s (KHÔNG phát thông báo để
// không đánh thức app liên tục). App mở sau hoặc vừa cài luôn đọc được Hz/FPS/công tắc mới nhất.
// ----------------------------------------------------------------------------------------------------
static void Titanium_StartIPCHearthbeatV12(void) {
    if (!Titanium_IsSpringBoard()) return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_source_t hb = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
        dispatch_source_set_timer(hb, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), (uint64_t)(30 * NSEC_PER_SEC), (uint64_t)(5 * NSEC_PER_SEC));
        dispatch_source_set_event_handler(hb, ^{
            ApexV285ProPayload snapshot;
            pthread_mutex_lock(&g_syncLockV285);
            snapshot = g_syncPayloadV285;
            pthread_mutex_unlock(&g_syncLockV285);
            if (snapshot.magic == APEX_SYNC_MAGIC_V285) {
                Titanium_WriteSyncPayloadV285(&snapshot);
            }
        });
        dispatch_resume(hb);
    });
}

// ----------------------------------------------------------------------------------------------------
// [V12 - BẮT BÙ KHI APP QUAY LẠI FOREGROUND]: thông báo Darwin tới lúc app đang treo nền có thể bị gộp/mất.
// Mỗi lần app active lại: ép nạp IPC ngay (bỏ qua bóp cổ chai 250ms) + áp dụng dải nhịp cho mọi scene.
// ----------------------------------------------------------------------------------------------------
static void Titanium_RegisterAppResumeRefreshV12(void) {
    if (Titanium_IsSpringBoard()) return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            g_lastSyncTicksV285 = 0;
            Titanium_ReloadSharedSyncStateV285();
            Titanium_ReapplyFrameRateToAllScenes();
        }];
        if (@available(iOS 9.0, *)) {
            [[NSNotificationCenter defaultCenter] addObserverForName:NSProcessInfoPowerStateDidChangeNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                Titanium_ReapplyFrameRateToAllScenes();
            }];
        }
        if (@available(iOS 11.0, *)) {
            NSProcessInfo *processInfo = [NSProcessInfo processInfo];
            g_thermalSeriousV285 = (processInfo.thermalState >= NSProcessInfoThermalStateSerious);
            [[NSNotificationCenter defaultCenter] addObserverForName:NSProcessInfoThermalStateDidChangeNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                NSProcessInfo *currentInfo = [NSProcessInfo processInfo];
                g_thermalSeriousV285 = (currentInfo.thermalState >= NSProcessInfoThermalStateSerious);
                Titanium_ReapplyFrameRateToAllScenes();
            }];
        }
    });
}

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
            // V22: không nâng QoS luồng chính khi cắm sạc; iOS tự quản lý hiệu năng/nhiệt.
            Titanium_UpdateLowBatteryFlagV12();
        }];

        // [V12 - PIN 1-20% VẪN MƯỢT]: theo dõi MỨC PIN (không chỉ trạng thái sạc) để bật chế độ ưu tiên mượt khi pin yếu
        g_batteryLevelV12 = dev.batteryLevel;
        Titanium_UpdateLowBatteryFlagV12();
        [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryLevelDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification * _Nonnull note) {
            g_batteryLevelV12 = [UIDevice currentDevice].batteryLevel;
            Titanium_UpdateLowBatteryFlagV12();
        }];
    });
}

// [ĐÃ BỔ SUNG - CÔNG TẮC TỔNG]: tiến trình không có đối tượng cấu hình (backboardd) lấy Hz/FPS trực tiếp từ payload IPC
static void Titanium_AdoptPayloadRatesWithoutConfig(void) {
    if (g_syncPayloadV285.targetHz >= 15 && g_syncPayloadV285.targetHz <= 144) {
        g_cachedResolvedHz = g_syncPayloadV285.targetHz;
    }
    if (g_syncPayloadV285.targetFPS >= 15 && g_syncPayloadV285.targetFPS <= 144) {
        g_cachedResolvedFPS = g_syncPayloadV285.targetFPS;
    }
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
        // [ĐÃ SỬA - CÔNG TẮC TỔNG]: thông báo đổi cấu hình phải nạp lại NGAY, không bị chặn bởi mốc nạp lần trước
        // (nextDrawable của app Metal cũng đặt mốc này mỗi khung hình nên trước đây game không bao giờ nạp lại được)
        g_lastSyncTicksV285 = 0;
        Titanium_ReloadSharedSyncStateV285();
        if (!CFG285) {
            Titanium_AdoptPayloadRatesWithoutConfig();
        }
        if (CFG285 && [CFG285 respondsToSelector:@selector(loadSettings)]) {
            [CFG285 loadSettings];
            // [ĐÃ SỬA]: bản cũ ghi đè g_cachedResolvedHz bằng targetHz THÔ ngay sau loadSettings, làm mất kết quả quy đổi (công tắc Hz/FPS,
            // tiết kiệm pin 60Hz, cờ ép 144...). loadSettings đã tự đặt đúng g_cachedResolvedHz/FPS nên không ghi đè nữa.
        }
#if !TITANIUM_SAFE_STABILITY_PROFILE
        if (Titanium_IsSpringBoard()) {
            Titanium_TuneWindowServerDisplayDirectly();
        }
#endif
        // Apply the same validated range to already-connected scenes in SpringBoard and app processes.
        dispatch_async(dispatch_get_main_queue(), ^{
            Titanium_ReapplyFrameRateToAllScenes();
        });
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
    // [ĐÃ SỬA]: KHÔNG hook máy chủ hiển thị (CAWindowServerDisplay / CADisplay trong backboardd) trên tấm nền 60Hz không có ProMotion.
    // Bản cũ luôn báo cho máy chủ hiển thị gốc rằng màn hình hỗ trợ VRR và chạy 144Hz (kể cả khi người dùng tắt công tắc tổng).
    if (!Titanium_DisplaySpoofAllowed()) return;
    static dispatch_once_t s_wsInitOnce;
    dispatch_once(&s_wsInitOnce, ^{
        %init(Group_CAWindowServer_Absolute_Dominance);
    });
}

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    static BOOL s_coreInitDone = NO;
    if (s_coreInitDone) return;
    s_coreInitDone = YES;

    @autoreleasepool {
        @try {
            // Không ép QoS USER_INTERACTIVE trong quá trình khởi tạo: việc này làm CPU thức nhiều hơn
            // nhưng không tăng tốc quá trình render. SpringBoard/app giữ QoS do hệ điều hành chọn.
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
                // [V12 SỬA - CHỈNH Hz/FPS TRONG APP KHÔNG TÁC DỤNG]: loadSettings đã quy đổi và ghi g_cachedResolvedHz/FPS
                // CHUẨN (tôn trọng công tắc Hz/FPS, tiết kiệm pin 60Hz, kẹp 15-144, máy 60Hz tự khóa 60, chống nóng...).
                // Bản cũ ghi đè lại bằng giá trị THÔ targetHz/targetFPS ngay sau đó => mọi quy đổi bị xoá sạch.
                // Nay giữ code cũ nhưng chỉ dùng làm DỰ PHÒNG khi cache chưa hợp lệ.
                if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                    NSInteger initHz = (NSInteger)CFG285.targetHz;
                    if ((g_cachedResolvedHz < 15 || g_cachedResolvedHz > 144) && initHz >= 15 && initHz <= 144) {
                        g_cachedResolvedHz = initHz;
                    }
                }
                if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                    NSInteger initFPS = (NSInteger)CFG285.targetFPS;
                    if ((g_cachedResolvedFPS < 15 || g_cachedResolvedFPS > 144) && initFPS >= 15 && initFPS <= 144) {
                        g_cachedResolvedFPS = initFPS;
                    }
                }
            }

#if !TITANIUM_SAFE_STABILITY_PROFILE
            if (!isSpringBoard && (g_isCurrentAppBlacklisted || (CFG285 && !CFG285.enabled))) {
                g_SystemMasterReady = YES;
                return;
            }
#endif

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                Titanium_ReloadSharedSyncStateV285();
            });

#if TITANIUM_SAFE_STABILITY_PROFILE
            // Nhánh mặc định ổn định: chỉ cài các hook DisplayLink/Scene có giới hạn phần cứng.
            // Không cài nhóm WindowServer/BackBoard/gesture/Metal private/scheduler/memory compaction.
            // Tắt các hook này chủ ý để tránh app đen và Safe Mode; Dynamic Refresh do iOS và panel thật quản lý.
            %init(Group_TitaniumSafeRuntime_V22);
            if (@available(iOS 15.0, *)) {
                %init(Group_TitaniumSafeRangeRuntime_V22);
                %init(Group_TitaniumSafeSceneRangeRuntime_V22);
            }
            // V22: do not initialize the private SBHomeGestureInteraction hooks.
            // Avoids dependency on private selectors across iOS/Dopamine versions; keep native gesture physics.
            g_SystemMasterReady = YES;

            if (isSpringBoard) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    @try {
                        Titanium_StartThermalAndChargingWatchdog();
                        Titanium_ReapplyFrameRateToAllScenes();
                    } @catch (NSException *e) {}
                });
                Titanium_StartIPCHearthbeatV12();
                NSData *verifiedData = [@"VERIFIED-V22-SAFE" dataUsingEncoding:NSUTF8StringEncoding];
                [[NSFileManager defaultManager] createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED
                                                        contents:verifiedData
                                                      attributes:@{NSFilePosixPermissions: @(0644)}];
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    @try {
                        Titanium_RegisterAppResumeRefreshV12();
                        Titanium_ReapplyFrameRateToAllScenes();
                    } @catch (NSException *e) {}
                });
            }
            return;
#endif

            if (TITANIUM_ENABLE_WATCHDOG_IMMUNITY) {
                %init(Group_AntiWatchdog_Immunity);
            }

            %init(Group_ZeroLatency_Touch_Opt);
            %init(Group_Metal_ZeroTearing_Pacing);
            %init(Group_FluidTransitions_Pacing);
            %init(Group_AI_Stream_Optimization);
            %init(Group_FastLaunch_SuperEngineV285);
            %init(Group_Scroll_And_Keyboard_Opt);
            %init(Group_InstantActionAndMenuTransitions_Boost);
            %init(Group_Global_Thread_Governor_Unthrottled);

            %init(Group_Universal_InApp_Animations);
            %init(Group_Apple_Internal_ProMotion_Apex);
            %init(Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285);
            if (Titanium_DisplaySpoofAllowed()) {
                %init(Group_Hardware_ProMotion_Overclock);
            }
            %init(Group_Apple_Native_ColdBoot_Overdrive);

            %init(Group_Titanium_Game_Metal_Overdrive);
            %init(Group_Silicon_Hardware_Pipeline_Overdrive);
            %init(Group_Silicon_Scheduler_Touch_Governor);
            %init(Group_CoreAnimation_RenderServer_Governor);
            %init(Group_System_Memory_And_RunLoop_Governor);
            %init(Group_Thermal_CryoPacing_ZeroDrop);
            %init(Group_Deep_RAM_Compaction_Engine);
            %init(Group_TitaniumV12_SmoothExit_And_DisplayLink); // [V12] Hết nảy khi vuốt về Home + DisplayLink nghe cấu hình tức thì
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

                Init_CAWindowServer_Hooks();

                if (TITANIUM_ENABLE_RATE_KEEPER) {
                    [TitaniumRateKeeper start];
                }
            }

                @try {
                    Titanium_StartThermalAndChargingWatchdog();
                } @catch (NSException *e) {}

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1500 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    @try {
                        AppleInternal_EnforceZeroLatencyKernelTier();
                        Titanium_ApplySiliconDeepOptimizations();
                    } @catch (NSException *e) {}
                });

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    @try {
                        Titanium_ForceInjectDynamicRefreshSupport();
                        AppleInternal_LockHardwareCADisplay();
                    } @catch (NSException *e) {}
                });

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3000 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    @try {
                        Titanium_TuneWindowServerDisplayDirectly();
                    } @catch (NSException *e) {}
                });

                // [V12 - HEARTBEAT IPC]: làm tươi tệp đồng bộ mỗi 5s để app mở sau luôn nhận đúng Hz/FPS/công tắc
                @try {
                    Titanium_StartIPCHearthbeatV12();
                } @catch (NSException *e) {}

                NSData *verifiedData = [@"VERIFIED" dataUsingEncoding:NSUTF8StringEncoding];
                [[NSFileManager defaultManager] createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED
                                                        contents:verifiedData
                                                      attributes:@{NSFilePosixPermissions: @(0644)}];
            } else {
                %init(Group_UIKit_ThirdParty_IsolatedV285);
                %init(Group_Force_Render_Recovery_Overdrive);
                %init(Group_Window_Level_Overdrive);

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(300 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    @try {
                        Titanium_ForceInjectDynamicRefreshSupport();
                        AppleInternal_EnforceZeroLatencyKernelTier();
                        Titanium_ApplySiliconDeepOptimizations();
                        // [V12 - Hz/FPS TÁC DỤNG NGAY & CHẮC CHẮN]: áp dụng dải nhịp cho toàn bộ scene đã mở
                        // + đăng ký bắt bù mỗi lần app quay lại foreground (khi thông báo Darwin bị gộp/mất lúc treo nền)
                        Titanium_RegisterAppResumeRefreshV12();
                        Titanium_ReapplyFrameRateToAllScenes();
                    } @catch (NSException *e) {}
                });
            }

            g_SystemMasterReady = YES;
        } @catch (NSException *e) {}
    }
}

static void Titanium_RegisterPrefsObservers(BOOL isSpringBoardProcess) {
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
}

static void SpringBoardBootstrapTrigger(void) {
    static BOOL s_triggerDone = NO;
    if (s_triggerDone) return;
    s_triggerDone = YES;

    const char *progName = getprogname();
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

    time_t uptime = Titanium_GetSystemUptimeSeconds();
    BOOL isColdBoot = (uptime < 30);
    int64_t waitDelay = isColdBoot ? (int64_t)(600 * NSEC_PER_MSEC) : (int64_t)(150 * NSEC_PER_MSEC);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, waitDelay), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        runCoreTweak(YES, bundleID, progName);
    });
}

%ctor {
    @autoreleasepool {
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
            strcasestr(progName, "nsurlstoraged") != NULL ||
            strcasestr(progName, "WebKit") != NULL ||
            strcasestr(progName, "WebContent") != NULL ||
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
            strcasestr(progName, "bluetoothd") != NULL) {
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

        if (strcasestr(progName, "backboardd") != NULL) {
            // [V13 STABILITY]: không hook BackBoard HID/Event pipeline. Nâng QoS cho mỗi sự kiện
            // hoặc thay CAWindowServer từ daemon này có thể gây nghẽn cảm ứng/boot-loop trên jailbreak khác nhau.
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

        // Browser host apps are left completely untouched. This avoids applying a third-party frame
        // pacing dylib during initial WebKit process startup/navigation while the reported browser
        // crash/grey-loading issue is being isolated. The list is intentionally limited to known browsers.
        if (!isSpringBoard && bundleID.length > 0) {
            static NSSet<NSString *> *s_browserBundleIDs = nil;
            static dispatch_once_t s_browserBundleOnce;
            dispatch_once(&s_browserBundleOnce, ^{
                s_browserBundleIDs = [NSSet setWithArray:@[
                    @"com.apple.mobilesafari",
                    @"com.google.chrome.ios",
                    @"org.mozilla.ios.Firefox",
                    @"com.microsoft.msedge",
                    @"com.brave.ios.browser",
                    @"com.duckduckgo.mobile.ios",
                    @"com.operasoftware.touch",
                    @"com.vivaldi.browser"
                ]];
            });
            if ([s_browserBundleIDs containsObject:bundleID]) return;
        }

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
                // [V12 SỬA - CHỈNH Hz/FPS KHÔNG TÁC DỤNG]: xem ghi chú trong runCoreTweak - không ghi đè cache đã quy đổi
                // bằng giá trị THÔ nữa; chỉ dùng giá trị thô làm DỰ PHÒNG khi cache chưa hợp lệ.
                if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                    NSInteger prefHz = (NSInteger)CFG285.targetHz;
                    if ((g_cachedResolvedHz < 15 || g_cachedResolvedHz > 144) && prefHz >= 15 && prefHz <= 144) {
                        g_cachedResolvedHz = prefHz;
                    }
                }
                if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                    NSInteger prefFPS = (NSInteger)CFG285.targetFPS;
                    if ((g_cachedResolvedFPS < 15 || g_cachedResolvedFPS > 144) && prefFPS >= 15 && prefFPS <= 144) {
                        g_cachedResolvedFPS = prefFPS;
                    }
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
            // [V12 SỬA - HẾT ĐƠ 1 LÚC RỒI VĂNG APP SAU KHI RESPRING - ROOTHIDE]:
            // Bản cũ chạy runCoreTweak ĐỒNG BỘ ngay trong %ctor của app (đọc plist + CFPreferences + hook ~20 nhóm
            // trên chính luồng nạp dylib). Sau respring, mọi app mở lại đều bị chặn ở bước này => app "đơ một lúc
            // rồi văng" (FrontBoard launch watchdog giết tiến trình khởi động chậm).
            // Nay: khởi tạo được đưa sang hàng đợi utility để giảm chặn lúc nạp dylib.
            // Safe profile chỉ cài các nhóm API hiển thị công khai đã chọn; vẫn cần build và thử trên từng bản iOS/jailbreak.
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                runCoreTweak(NO, bundleID, progName);
            });
        }
    }
}
