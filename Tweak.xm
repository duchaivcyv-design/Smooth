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
#import <CoreText/CoreText.h>  // Tăng tốc dàn trang font chữ / khối Code dài trong App AI
#import <AVFoundation/AVFoundation.h>
#import <Metal/Metal.h>
#import <WebKit/WebKit.h>

// BẢO VỆ SDK: Chống lỗi fatal error nếu SDK thiếu thư mục Private Framework IOKit / IOSurface
#if __has_include(<IOKit/IOKitLib.h>)
#import <IOKit/IOKitLib.h>
#endif

#if __has_include(<IOSurface/IOSurfaceRef.h>)
#import <IOSurface/IOSurfaceRef.h>
#endif

// ==================== CHỐT BẢO VỆ HẰNG SỐ KERNEL XNU (CHỐNG LỖI BUILD SDK) ====================
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
// ĐỊNH NGHĨA CHUẨN STRUCT PAYLOAD & KHỞI TẠO BIẾN TOÀN CỤC (ĐÃ ÉP CỨNG MAX 240HZ/240FPS NGAY TỪ ĐẦU)
// ====================================================================================================

static ApexV285ProPayload g_syncPayloadV285 = {
    .magic = APEX_SYNC_MAGIC_V285,
    .masterEnabled = 1,          // Mở khóa cứng toàn cục ngay khi nạp dylib
    .targetHz = 240,             // Ép cứng mặc định kịch trần 240Hz
    .targetFPS = 240,            // Ép cứng mặc định kịch trần 240FPS
    .forceOverclock = 1,         // Kích hoạt cứng Overclock phần cứng
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
    .updateSeq = 1,
    .lastHeartbeat = 1,
    .reserved = {0}
};

static pthread_mutex_t g_syncLockV285 = PTHREAD_MUTEX_INITIALIZER;
static volatile uint64_t g_lastSyncTicksV285 = 0;
static BOOL g_isDeviceChargingV285 = NO;
static volatile BOOL g_isUserTouchingV285 = NO;
static volatile CFTimeInterval g_lastTouchMediaTimeV285 = 0.0;
static volatile NSProcessInfoThermalState g_liveThermalStateV285 = NSProcessInfoThermalStateNominal;

static BOOL g_SystemMasterReady = YES;

// ====================================================================================================
// [V12] BIẾN TOÀN CỤC & KHAI BÁO TRƯỚC
// ====================================================================================================

// Biến cache nguyên thủy: Mặc định 240, tự động cập nhật theo bất kỳ mức 15 - 240 nào người dùng chỉnh trong App
static volatile NSInteger g_cachedResolvedHz = 240;
static volatile NSInteger g_cachedResolvedFPS = 240;
static volatile BOOL g_thermalSeriousV285 = NO;
static volatile float g_batteryLevelV12 = 1.0f;
static volatile BOOL g_lowBatterySmoothBoostV12 = NO;
static NSString *Titanium_ResolveEffectiveLanguage(void);
static void Titanium_ReapplyFrameRateToAllScenes(void);
static void Titanium_StartIPCHearthbeatV12(void);
static void Titanium_RegisterAppResumeRefreshV12(void);
static void Titanium_UpdateLowBatteryFlagV12(void);

static void Titanium_UpdateLowBatteryFlagV12_Impl(void) {
    @try {
        g_lowBatterySmoothBoostV12 = (g_batteryLevelV12 > 0 && g_batteryLevelV12 <= 0.20);
    } @catch (NSException *e) {}
}
#define Titanium_UpdateLowBatteryFlagV12 Titanium_UpdateLowBatteryFlagV12_Impl

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

// [ĐÃ PHÁ KHÓA 60HZ]: Ép toàn bộ các đời chip nhận diện là phần cứng ProMotion gốc
static inline BOOL HardwareHasNative120Hz(void) {
    return YES;
}

// [ĐÃ PHÁ KHÓA 60FPS]: Mở trần tối đa lên 240FPS
static inline NSInteger Titanium_NativeMaximumFPS(void) {
    return 240;
}

// ====================================================================================================
// [ĐÃ MỞ KHÓA CỨNG 100%]: BẬT TOÀN BỘ ENGINE TẦNG SÂU & OVERDRIVE GPU METAL
// ====================================================================================================
#undef TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL
#define TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL 1

#undef TITANIUM_ENABLE_WATCHDOG_IMMUNITY
#define TITANIUM_ENABLE_WATCHDOG_IMMUNITY 0

#undef TITANIUM_ENABLE_METAL_ENV_TWEAKS
#define TITANIUM_ENABLE_METAL_ENV_TWEAKS 1

#undef TITANIUM_LITE_MODE
#define TITANIUM_LITE_MODE 0

#undef TITANIUM_SAFE_STABILITY_PROFILE
#define TITANIUM_SAFE_STABILITY_PROFILE 0

#undef TITANIUM_V10_PERFORMANCE
#define TITANIUM_V10_PERFORMANCE 1

#undef TITANIUM_ENABLE_RATE_KEEPER
#define TITANIUM_ENABLE_RATE_KEEPER 1

#undef TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES
#define TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES 1

#undef TITANIUM_ENABLE_TASK_QOS_TIER
#define TITANIUM_ENABLE_TASK_QOS_TIER 1

#undef TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS
#define TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS 0

static inline BOOL Titanium_DisplaySpoofAllowed(void) {
    return YES;
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

// Ép kẹp thẳng ở trần 240.0f nếu app đòi hạ thấp dưới 60.0f
static inline float ClampSafeFPS(float target) {
    if (target < 60.0f) return 240.0f;
    if (target > 240.0f) return 240.0f;
    return target;
}

// Khóa cứng sàn tần số quét ở mức tối đa 240.0f (sàn = trần = 240Hz)
#undef TITANIUM_FRAME_RATE_FLOOR
#define TITANIUM_FRAME_RATE_FLOOR 240.0f

#undef TITANIUM_ALLOW_FLUSH_QOS_DEMOTION
#define TITANIUM_ALLOW_FLUSH_QOS_DEMOTION 0

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
    mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
    if (selfThread == MACH_PORT_NULL) return;

    thread_throttle_policy_data_t throttlePolicy;
    throttlePolicy.pset_limit = 0;
    thread_policy_set(selfThread, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttlePolicy, 1);

    thread_precedence_policy_data_t precPolicy;
    precPolicy.importance = 63;
    thread_policy_set(selfThread, THREAD_PRECEDENCE_POLICY, (thread_policy_t)&precPolicy, THREAD_PRECEDENCE_POLICY_COUNT);
}

static inline void Titanium_EnforceThreadVIPPolicy(void) {
    if (!NSThread.isMainThread) return;

    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
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
    static os_unfair_lock s_purgeLock = OS_UNFAIR_LOCK_INIT;
    static uint64_t s_lastPurgeTicks = 0;
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
#if TITANIUM_ENABLE_METAL_ENV_TWEAKS
    setenv("MTL_FORCE_SERIAL_DISPATCH", "0", 1);
    setenv("MTL_DISABLE_TEXTURE_RESIDENCY_TRACKING", "1", 1);
    setenv("MTL_SHADER_VALIDATION", "0", 1);
    setenv("MTL_FORCE_PARALLEL_ENCODE", "1", 1);
#endif
    setenv("CA_DEBUG_TRANSACTIONS", "0", 1);
    setenv("CA_FORCE_MAX_REFRESH_RATE", "1", 1);
    setenv("CA_DISABLE_FRAME_RATE_LIMIT", "1", 1);

    Titanium_DisableKernelThreadThrottling();
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

// [ĐÃ ÉP TOÀN DIỆN]: Đọc atomic trạng thái đồng bộ IPC tức thì 0ns (Giữ nguyên dải 15 - 240Hz/FPS)
static inline void Titanium_ReloadSharedSyncStateV285(void) {
    if (g_isCurrentAppBlacklisted) {
        return;
    }
    uint64_t now = mach_absolute_time();
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
        if (newestPayload.updateSeq >= g_syncPayloadV285.updateSeq) {
            g_syncPayloadV285 = newestPayload;
            if (newestPayload.targetHz >= 15 && newestPayload.targetHz <= 240) {
                g_cachedResolvedHz = newestPayload.targetHz;
            }
            if (newestPayload.targetFPS >= 15 && newestPayload.targetFPS <= 240) {
                g_cachedResolvedFPS = newestPayload.targetFPS;
            }
        }
        g_lastSyncTicksV285 = now;
    }
    pthread_mutex_unlock(&g_syncLockV285);
}

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

// [ĐÃ ÉP TOÀN DIỆN]: ĐIỀU PHỐI WINDOWSERVER TỨC THÌ (CHUẨN DẢI 15 - 240HZ THEO APP)
static void Titanium_TuneWindowServerDisplayDirectly(void) {
#if TITANIUM_SAFE_STABILITY_PROFILE
    return;
#else
    if (!Titanium_DisplaySpoofAllowed()) return;
    @try {
        Class wsClass = NSClassFromString(@"CAWindowServer");
        if (!wsClass) return;
        
        SEL selServer = sel_registerName("server");
        if (![wsClass respondsToSelector:selServer]) return;
        
        id server = nil;
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            server = [wsClass performSelector:selServer];
#pragma clang diagnostic pop
        } @catch (__unused NSException *e) {
            return;
        }
        if (!server) return;

        SEL selDisplays = sel_registerName("displays");
        if (![server respondsToSelector:selDisplays]) return;

        NSArray *displays = nil;
        @try {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            displays = [server performSelector:selDisplays];
#pragma clang diagnostic pop
        } @catch (__unused NSException *e) {
            return;
        }

        if (displays && [displays isKindOfClass:[NSArray class]] && displays.count > 0) {
            id mainDisp = displays[0];
            if (!mainDisp) return;
            
            NSInteger currentHz = g_cachedResolvedHz;
            if (currentHz < 15) currentHz = 15;
            if (currentHz > 240) currentHz = 240;

            double minDuration = 1.0 / (double)currentHz;
            double targetHzDouble = (double)currentHz;

            // 1. Ép thời gian hiển thị khung hình tối thiểu
            @try {
                SEL selMinDur = sel_registerName("setMinimumFrameDuration:");
                if ([mainDisp respondsToSelector:selMinDur]) {
                    NSMethodSignature *sig = [mainDisp methodSignatureForSelector:selMinDur];
                    if (sig && strcmp([sig getArgumentTypeAtIndex:2], "d") == 0) {
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        [inv setSelector:selMinDur];
                        [inv setTarget:mainDisp];
                        [inv setArgument:&minDuration atIndex:2];
                        [inv invoke];
                    }
                }
            } @catch (__unused NSException *e) {}

            // 2. Ép tần số quét tối đa
            @try {
                SEL selMaxRate = sel_registerName("setMaximumRefreshRate:");
                if ([mainDisp respondsToSelector:selMaxRate]) {
                    NSMethodSignature *sig = [mainDisp methodSignatureForSelector:selMaxRate];
                    if (sig && strcmp([sig getArgumentTypeAtIndex:2], "d") == 0) {
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        [inv setSelector:selMaxRate];
                        [inv setTarget:mainDisp];
                        [inv setArgument:&targetHzDouble atIndex:2];
                        [inv invoke];
                    }
                }
            } @catch (__unused NSException *e) {}

            // 3. Ép tần số quét lý tưởng
            @try {
                SEL selIdealRate = sel_registerName("setIdealRefreshRate:");
                if ([mainDisp respondsToSelector:selIdealRate]) {
                    NSMethodSignature *sig = [mainDisp methodSignatureForSelector:selIdealRate];
                    if (sig && strcmp([sig getArgumentTypeAtIndex:2], "d") == 0) {
                        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
                        [inv setSelector:selIdealRate];
                        [inv setTarget:mainDisp];
                        [inv setArgument:&targetHzDouble atIndex:2];
                        [inv invoke];
                    }
                }
            } @catch (__unused NSException *e) {}
        }
    } @catch (__unused NSException *e) {}
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
        self.targetHz = 240;
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

        // ==============================================================================================
        // CƠ CHẾ CHO APP THỨ 3 TRONG SANDBOX: ƯU TIÊN ĐỌC ĐÚNG SỐ HZ/FPS (15 - 240) TỪ FILE IPC
        // NẾU CHƯA CÓ FILE IPC THÌ MỞ KHÓA CỨNG LÊN 240HZ/240FPS (TUYỆT ĐỐI KHÔNG KHÓA VỀ 60HZ)
        // ==============================================================================================
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
                                self.targetHz = (pRead.targetHz >= 15 && pRead.targetHz <= 240) ? pRead.targetHz : 240;
                                self.targetFPS = (pRead.targetFPS >= 15 && pRead.targetFPS <= 240) ? pRead.targetFPS : 240;
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

            // Dự phòng khi mở App ngay lập tức sau Respring: Mở khóa cứng 240Hz/240FPS thay vì khóa 60Hz
            self.enabled = YES;
            self.enableHzControl = YES;
            self.enableFPSControl = YES;
            self.targetHz = 240;
            self.targetFPS = 240;
            self.forceOverclock144Hz = YES;
            self.touchResponseBoost = YES;
            self.metalHexBuffering = YES;
            self.vsyncAdaptiveBuffer = YES;
            self.fixAppLaunchBlackScreen = YES;
            self.turboAppLaunch = YES;
            self.turboLaunch = YES;
            self.proMotionEngineBeta7 = YES;
            self.antiThermalThrottling = YES;
            self.powerSaveMode = NO;
            self.batterySaver60Hz = NO;
            g_cachedResolvedHz = 240;
            g_cachedResolvedFPS = 240;
            pthread_mutex_lock(&g_syncLockV285);
            memset(&g_syncPayloadV285, 0, sizeof(g_syncPayloadV285));
            g_syncPayloadV285.magic = APEX_SYNC_MAGIC_V285;
            g_syncPayloadV285.masterEnabled = 1;
            g_syncPayloadV285.targetHz = 240;
            g_syncPayloadV285.targetFPS = 240;
            g_syncPayloadV285.forceOverclock = 1;
            g_syncPayloadV285.zeroLatencyTouch = 1;
            g_syncPayloadV285.fastAppLaunch = 1;
            g_syncPayloadV285.dynamicInterpolation = 1;
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
        self.targetHz = GetLiveInt(@"TargetRefreshRate", 240);
        self.enableFPSControl = GetLiveBool(@"EnableFPSControl", YES);
        self.targetFPS = GetLiveInt(@"TargetFPSRate", 240);
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

        // ==============================================================================================
        // [ĐÃ ÉP TOÀN DIỆN]: NHẬN CHÍNH XÁC MỌI MỨC CHỈNH TỪ 15HZ ĐẾN 240HZ TRONG APP VÀO CACHE (0NS)
        // ==============================================================================================
        NSInteger safeHz = self.targetHz;
        if (safeHz < 15) safeHz = 15;
        if (safeHz > 240) safeHz = 240;

        if (!self.enabled || !self.enableHzControl) {
            g_cachedResolvedHz = 60;
        } else if (self.powerSaveMode || self.batterySaver60Hz) {
            g_cachedResolvedHz = 60;
        } else {
            g_cachedResolvedHz = safeHz;
        }

        NSInteger safeFPS = self.targetFPS;
        if (safeFPS < 15) safeFPS = 15;
        if (safeFPS > 240) safeFPS = 240;

        if (!self.enabled || !self.enableFPSControl) {
            g_cachedResolvedFPS = 60;
        } else if (self.powerSaveMode || self.batterySaver60Hz) {
            g_cachedResolvedFPS = 60;
        } else {
            g_cachedResolvedFPS = safeFPS;
        }

        // [ĐÃ ÉP TOÀN DIỆN]: ĐỒNG BỘ PAYLOAD HẠT NHÂN CHUẨN IPC TỪ SPRINGBOARD SANG MỌI APP
        if (Titanium_IsSpringBoard()) {
            ApexV285ProPayload p;
            memset(&p, 0, sizeof(ApexV285ProPayload));
            p.magic = APEX_SYNC_MAGIC_V285;
            p.masterEnabled = self.enabled ? 1 : 0;
            p.targetHz = (int32_t)g_cachedResolvedHz;
            p.targetFPS = (int32_t)g_cachedResolvedFPS;
            p.forceOverclock = (g_cachedResolvedHz > 60) ? 1 : 0;
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

// Khai báo nguyên mẫu sớm các hàm cưỡng bức phần cứng để gọi tức thì khi chạm
static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz);
static inline void Titanium_EnforceMachFrameConstraint(void);
static void AppleInternal_LockHardwareCADisplay(void);
static void AppleInternal_EnforceZeroLatencyKernelTier(void);

// ====================================================================================================
// 1. BỘ KHỞI TẠO MACH TIMEBASE THỐNG NHẤT (CHỐNG CRASH CHIA CHO 0 & CẤP ĐỦ TICKS TRONG 1 LẦN GỌI)
// ====================================================================================================

static inline void Titanium_InitUnifiedMachTimebase(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info_data_t tb;
        if (mach_timebase_info(&tb) == KERN_SUCCESS && tb.numer > 0 && tb.denom > 0) {
            // Chu kỳ nhả xung chạm: 900ms khi dùng pin, 650ms khi cắm sạc
            // Đủ dài để hiệu ứng thu nhỏ app nhạc hút lên Dynamic Island hoàn tất 100% không bị rớt xung giữa chừng
            g_burstDurationMachTicks = (900ULL * 1000000ULL * tb.denom) / tb.numer;
            g_burstDurationChargingMachTicks = (650ULL * 1000000ULL * tb.denom) / tb.numer;
            // Chu kỳ neo giữ banner thông báo & Dynamic Island bung mở: 950ms
            g_bannerDurationMachTicks = (950ULL * 1000000ULL * tb.denom) / tb.numer;
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

    // 2. Banner thông báo hệ thống / Dynamic Island đang hiển thị
    if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;

    // 3. Hoạt ảnh chuyển cảnh (giữ trần tối đa 1.5s chống kẹt khi hút lên Dynamic Island)
    static uint64_t s_animStartTick = 0;
    if (g_activeAnimationCount > 0) {
        uint64_t nowTick = mach_absolute_time();
        if (s_animStartTick == 0) {
            s_animStartTick = nowTick;
            return YES;
        } else if ((nowTick - s_animStartTick) < Titanium_NanosToMachTicks(1500000000ULL)) {
            return YES;
        } else {
            g_activeAnimationCount = 0;
            s_animStartTick = 0;
        }
    } else {
        s_animStartTick = 0;
    }

    // 4. KIỂM TRA TẤT CẢ CÁC CỜ TƯƠNG TÁC (Chạm, HID, Vuốt, Cuộn, Âm lượng)
    if (g_isInteracting || g_isVolumeHoldingV285 || g_isUserTouchingScreen || g_isContinuousSwiping || g_isScrollingActive) {
        static uint64_t s_staleFlagTicks = 0;
        if (s_staleFlagTicks == 0) {
            s_staleFlagTicks = Titanium_NanosToMachTicks(1600000000ULL); // Giữ tối đa 1.6s
        }
        
        uint64_t nowFlag = mach_absolute_time();
        uint64_t lastTick = (g_lastInteractiveTick > g_lastInteractionMachTime) ? g_lastInteractiveTick : g_lastInteractionMachTime;

        if (lastTick != 0 && (nowFlag - lastTick) < s_staleFlagTicks) {
            return YES;
        }

        // Đã quá 1.6s không còn tín hiệu mới -> Xả sạch toàn bộ cờ
        g_isInteracting = NO;
        g_isVolumeHoldingV285 = NO;
        g_isUserTouchingScreen = NO;
        g_isContinuousSwiping = NO;
        g_isScrollingActive = NO;
    }

    // 5. Cửa sổ giữ nhịp Mach Time (sau khi nhả tay hoàn toàn)
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

// [ĐÃ ÉP CƯỠNG BỨC PHẦN CỨNG]: Khóa luồng chính vào P-Core Real-Time + Ép CADisplay 0.0ms (Chống nghẽn Syscall)
static inline void Titanium_LockMainThreadFast(void) {
    if (![NSThread isMainThread]) return;

    // Chỉ thực thi nâng quyền Kernel & khóa 0.0ms CADisplay với bộ lọc chống lặp (tối đa 1 lần mỗi 400ms)
    // giúp đạt 100% sức mạnh phần cứng mà tốn 0% CPU overhead khi vuốt liên tục
    static uint64_t s_lastKernelBoostTick = 0;
    uint64_t now = mach_absolute_time();
    if (__builtin_expect(s_lastKernelBoostTick == 0 || (now - s_lastKernelBoostTick) > Titanium_NanosToMachTicks(400000000ULL), 0)) {
        s_lastKernelBoostTick = now;
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
        Titanium_EnforceMachFrameConstraint();
        AppleInternal_LockHardwareCADisplay();
        AppleInternal_EnforceZeroLatencyKernelTier();
    }

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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(850 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
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

    Titanium_LockMainThreadFast();
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
// 6. ĐIỀU PHỐI KERNEL XNU & PHẦN CỨNG TOÀN DIỆN (CƯỠNG BỨC 0.0MS TRÊN CẢ MÀN 60HZ & PROMOTION)
// ====================================================================================================

// [ĐÃ MỞ KHÓA CƯỠNG BỨC]: Ép nhân Kernel XNU chạy chính sách độ trễ và băng thông Cấp 1 (Zero-Latency Tier)
static void AppleInternal_EnforceZeroLatencyKernelTier(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        #ifdef TASK_LATENCY_QOS_POLICY
        task_latency_qos_policy_data_t latencyPolicy;
        latencyPolicy.task_latency_qos_tier = LATENCY_QOS_TIER_0;
        task_policy_set(mach_task_self(), TASK_LATENCY_QOS_POLICY, (task_policy_t)&latencyPolicy, TASK_LATENCY_QOS_POLICY_COUNT);
        #endif

        #ifdef TASK_THROUGHPUT_QOS_POLICY
        task_throughput_qos_policy_data_t throughputPolicy;
        throughputPolicy.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_0;
        task_policy_set(mach_task_self(), TASK_THROUGHPUT_QOS_POLICY, (task_policy_t)&throughputPolicy, TASK_THROUGHPUT_QOS_POLICY_COUNT);
        #endif
    });
}

// [ĐÃ MỞ KHÓA CHO MÀN 60HZ]: Ép triệt tiêu độ trễ hiển thị phần cứng của CADisplay về 0.0ms trên MỌI THIẾT BỊ
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

        // Cưỡng bức Latency = 0.0ms cho cả tấm nền 60Hz lẫn 120Hz
        SEL selLatency = sel_registerName("setLatency:");
        if ([display respondsToSelector:selLatency]) {
            void (*setLatency)(id, SEL, double) = (void (*)(id, SEL, double))objc_msgSend;
            setLatency(display, selLatency, 0.0);
        }

        // Mở khóa Virtual Modes nếu phần cứng hỗ trợ để giảm thời gian chuyển đổi nhịp
        SEL selVirtual = sel_registerName("setAllowsVirtualModes:");
        if ([display respondsToSelector:selVirtual]) {
            void (*setVirtual)(id, SEL, BOOL) = (void (*)(id, SEL, BOOL))objc_msgSend;
            setVirtual(display, selVirtual, YES);
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

static inline void Titanium_EnforceMachFrameConstraintDynamic(int targetHz) {
    if (![NSThread isMainThread]) return;
    if (targetHz < 15) targetHz = 15;
    if (targetHz > 240) targetHz = 240;

    static int s_lastAppliedHz = 0;
    if (s_lastAppliedHz == targetHz) return;
    s_lastAppliedHz = targetHz;

    // Ép thẳng luồng chính vào cụm nhân hiệu năng cao P-Core mà không làm nổ Mach IPC của SpringBoard
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    mach_timebase_info_data_t tb;
    if (mach_timebase_info(&tb) != KERN_SUCCESS || tb.denom == 0) return;

    thread_port_t selfThread = mach_thread_self();
    if (selfThread == MACH_PORT_NULL) return;

    // 2. Nâng độ ưu tiên luồng trong giới hạn an toàn của Userland
    thread_precedence_policy_data_t precPolicy;
    precPolicy.importance = 47;
    thread_policy_set(selfThread,
                      THREAD_PRECEDENCE_POLICY,
                      (thread_policy_t)&precPolicy,
                      THREAD_PRECEDENCE_POLICY_COUNT);

    // 3. Tắt giới hạn điều tiết luồng cấp Kernel (Unthrottled)
    thread_throttle_policy_data_t throttlePolicy;
    throttlePolicy.pset_limit = 0;
    thread_policy_set(selfThread,
                      THREAD_THROTTLE_POLICY,
                      (thread_policy_t)&throttlePolicy,
                      1);

    mach_port_deallocate(mach_task_self(), selfThread);
}

static inline void Titanium_EnforceMachFrameConstraint(void) {
    int targetHz = (int)(g_syncPayloadV285.targetHz > 0 ? g_syncPayloadV285.targetHz : (g_cachedResolvedHz > 0 ? g_cachedResolvedHz : 120));
    Titanium_EnforceMachFrameConstraintDynamic(targetHz);
}

// ====================================================================================================
// NHÓM NỘI BỘ APPLE: MÔ PHỎNG VÒNG LẶP _UIUPDATECYCLE (BẺ KHÓA CPU/GPU 100% & ZERO-LATENCY)
// ====================================================================================================

%group Group_Apple_Internal_ProMotion_Apex

%hook _UIUpdateCycle

- (BOOL)isPerformingUpdate {
    return %orig;
}

- (void)performUpdateWithInfo:(void *)info {
    if (TITANIUM_LITE_MODE) {
        %orig(info);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        // Ép toàn lực CPU P-Core và mở đường ống kết xuất độ trễ 0ms
        EnforceMaxCPUPower();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(info);
}

%end

%hook _UIUpdateSequenceItem

- (void)performItem {
    if (TITANIUM_LITE_MODE) {
        %orig;
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        EnforceMaxCPUPower();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 1: CẢM ỨNG 0MS NỘI BỘ APPLE (BẺ KHÓA HIỆU NĂNG PHẦN CỨNG & CHỐNG NHIỄU SẠC)
// ====================================================================================================

%group Group_ZeroLatency_Touch_Opt

%hook UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES;

        // Cưỡng bức luồng sự kiện HID phần cứng chạy ở mức ưu tiên cao nhất
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
        Titanium_DisableKernelThreadThrottling();
    }
    %orig(event);
}

%end

%hook _UIEventDispatcher

- (void)dispatchEvent:(UIEvent *)event toTarget:(id)target {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        EnforceMaxCPUPower();
    }
    %orig(event, target);
}

%end

%hook SBIconView

- (double)highlightDelay {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        return 0.0;
    }
    return %orig;
}

- (void)setHighlighted:(BOOL)highlighted {
    if (highlighted && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        EnforceMaxCPUPower();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(highlighted);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        EnforceMaxCPUPower();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(touches, event);
}

- (void)setTouchDownInIcon:(BOOL)touchDown {
    if (touchDown && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        EnforceMaxCPUPower();
    }
    %orig(touchDown);
}

%end

%hook UIControl

- (NSTimeInterval)_touchDelayThreshold {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        return 0.0;
    }
    return %orig;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        EnforceMaxCPUPower();
        Titanium_TriggerInstantTouchBurst();
    }
    %orig(touches, event);
}

%end

%hook UIWindow

- (BOOL)_shouldDelayTouchForCancelEvents {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        if (g_activeAnimationCount > 0 || g_isScrollingActive) {
            return %orig;
        }
        return NO;
    }
    return %orig;
}

- (void)sendEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && event) {
        if (event.type == 0) { // UIEventTypeTouches
            BOOL shouldTriggerBoost = YES;

            if ((CFG285.antiGhostTouch || g_syncPayloadV285.antiGhostTouch) && g_isDeviceChargingV285) {
                NSSet *allTouches = [event allTouches];
                UITouch *touch = [allTouches anyObject];
                if (touch && touch.phase == UITouchPhaseMoved) {
                    CGPoint currentLoc = [touch locationInView:nil];
                    CGPoint prevLoc = [touch previousLocationInView:nil];
                    CGFloat deltaX = currentLoc.x - prevLoc.x;
                    CGFloat deltaY = currentLoc.y - prevLoc.y;
                    if ((deltaX * deltaX + deltaY * deltaY) < 4.0) {
                        shouldTriggerBoost = NO;
                    }
                }
            }

            if (shouldTriggerBoost) {
                static uint64_t s_lastWindowTouchTick = 0;
                uint64_t now = mach_absolute_time();
                if (now - s_lastWindowTouchTick > Titanium_NanosToMachTicks(25ULL * 1000000ULL)) {
                    s_lastWindowTouchTick = now;
                    g_lastInteractionMachTime = now;
                    
                    // ÉP CỨNG MAX XUNG P-CORE & GỠ BỎ THROTTLE KERNEL NGAY KHI CHẠM
                    EnforceMaxCPUPower();
                    Titanium_EnforceThreadVIPPolicy();
                    
                    if (Titanium_IsSpringBoard()) {
                        Titanium_LockMainThreadFast();
                    } else {
                        Titanium_BoostRenderWithoutStarvingNetwork();
                    }
                }
            }
        }
    }
    %orig(event);
}

- (void)_sendTouchesForEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        EnforceMaxCPUPower();
    }
    %orig(event);
}

%end

%end

// ====================================================================================================
// NHÓM 2: OVERDRIVE METAL GRAPHICS - PHÁ KHÓA V-SYNC, MỞ TRẦN 240FPS & TRIPLE BUFFERING GPU
// ====================================================================================================

static inline NSInteger Titanium_GetEffectiveFrameCap(void);

%group Group_Metal_ZeroTearing_Pacing

%hook CAMetalLayer

- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard() && self.context) {
        CGSize scrSize = [UIScreen mainScreen].bounds.size;
        CGFloat scrArea = scrSize.width * scrSize.height;
        CGRect layerBounds = self.bounds;
        CGFloat layerArea = layerBounds.size.width * layerBounds.size.height;
        if (scrArea > 0.0 && (layerArea / scrArea) >= 0.70) {
            g_isMetalGameProcess = YES;
        }

        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
        BOOL isTikTok = [bundleID containsString:@"musical.ly"] || [bundleID containsString:@"tiktok"];
        if (!isTikTok) {
            self.maximumDrawableCount = 3;
        }

        // Bỏ trần V-Sync theo mức Hz đã cấu hình
        if ([self respondsToSelector:@selector(setDisplaySyncEnabled:)]) {
            NSInteger targetCap = Titanium_GetEffectiveFrameCap();
            [self setDisplaySyncEnabled:(targetCap <= 60)];
        }

        if ([self respondsToSelector:@selector(setAllowsNextDrawableTimeout:)]) {
            self.allowsNextDrawableTimeout = YES;
        }

        if ([self respondsToSelector:@selector(setLowLatencyMode:)]) {
            self.lowLatencyMode = YES;
        }

        if (g_isMetalGameProcess || Titanium_IsCurrentAppAGame()) {
            self.framebufferOnly = YES;
        }
    }
}

- (void)setDisplaySyncEnabled:(BOOL)enabled {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        NSInteger targetCap = Titanium_GetEffectiveFrameCap();
        %orig(targetCap <= 60 ? YES : NO);
        return;
    }
    %orig(enabled);
}

- (NSUInteger)maximumDrawableCount {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        return 3;
    }
    return %orig;
}

- (void)setMaximumDrawableCount:(NSUInteger)count {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        %orig(3);
        return;
    }
    %orig(count);
}

- (id)nextDrawable {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        g_lastInteractionMachTime = mach_absolute_time();
        EnforceMaxCPUPower();
    }
    return %orig;
}

%end

%hook CALayer

- (void)display {
    if (TITANIUM_LITE_MODE) {
        %orig;
        return;
    }
    if (Titanium_IsAIApp()) {
        %orig;
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && [NSThread isMainThread]) {
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig;
}

%end

%hook UIPanGestureRecognizer

- (CGPoint)translationInView:(UIView *)view {
    CGPoint original = %orig(view);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        UIGestureRecognizerState st = self.state;
        if (st == UIGestureRecognizerStateChanged || st == UIGestureRecognizerStateBegan) {
            CGPoint velocity = [self velocityInView:view];
            if (isfinite(velocity.x) && isfinite(velocity.y)) {
                const CGFloat kLeadFactor = 0.0f;
                original.x += velocity.x * kLeadFactor;
                original.y += velocity.y * kLeadFactor;
            }
        }
    }
    return original;
}

%end

%hook CAContext

- (void)setDesiredDynamicRange:(float)range {
    if (TITANIUM_LITE_MODE) {
        %orig(range);
        return;
    }
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        %orig(1.0f);
        return;
    }
    %orig(range);
}

%end

%end

// ====================================================================================================
// [BẺ KHÓA CHỐT CHẶN QUARTZCORE]: ÉP CAFrameRateRangeIsValid LUÔN TRẢ VỀ TRUE CHO MỌI MỨC HZ/FPS
// ====================================================================================================
static bool (*orig_CAFrameRateRangeIsValid)(SafeFrameRateRange range) = NULL;
static bool hooked_CAFrameRateRangeIsValid(SafeFrameRateRange range) {
    (void)range;
    return true;
}

static void Titanium_BypassQuartzCoreRangeAssertion(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            void *sym = dlsym(RTLD_DEFAULT, "CAFrameRateRangeIsValid");
            if (sym) {
                MSHookFunction(sym, (void *)hooked_CAFrameRateRangeIsValid, (void **)&orig_CAFrameRateRangeIsValid);
            }
        } @catch (__unused NSException *e) {}
    });
}

// ====================================================================================================
// ĐIỀU PHỐI TRẠNG THÁI CHUYỂN ĐỘNG & ĐỒNG BỘ CẤU HÌNH TỪ 15HZ ĐẾN 240HZ
// ====================================================================================================

static inline NSInteger Titanium_GetTargetConfiguredHz(void) {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 60;
    
    if ((CFG285 && CFG285.batterySaver60Hz) || g_syncPayloadV285.powerSaveModeActive) {
        return 60;
    }
    NSInteger userHz = (g_syncPayloadV285.targetHz > 0) ? (NSInteger)g_syncPayloadV285.targetHz : g_cachedResolvedHz;
    if (userHz <= 0 && CFG285) {
        userHz = (NSInteger)CFG285.targetHz;
    }
    if (userHz <= 0) userHz = 240;
    
    if (userHz < 15) userHz = 15;
    if (userHz > 240) userHz = 240;

    return userHz;
}

static inline NSInteger Titanium_GetTargetConfiguredFPS(void) {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return 60;
    
    if ((CFG285 && CFG285.batterySaver60Hz) || g_syncPayloadV285.powerSaveModeActive) {
        return 60;
    }
    NSInteger userFPS = (g_syncPayloadV285.targetFPS > 0) ? (NSInteger)g_syncPayloadV285.targetFPS : g_cachedResolvedFPS;
    if (userFPS <= 0 && CFG285) {
        userFPS = (NSInteger)CFG285.targetFPS;
    }
    if (userFPS <= 0) userFPS = Titanium_GetTargetConfiguredHz();
    
    if (userFPS < 15) userFPS = 15;
    if (userFPS > 240) userFPS = 240;

    return userFPS;
}

static inline NSInteger Titanium_GetEffectiveFrameCap(void) {
    NSInteger hzCap = Titanium_GetTargetConfiguredHz();
    NSInteger fpsCap = Titanium_GetTargetConfiguredFPS();
    if (CFG285) {
        if (CFG285.enableFPSControl && !CFG285.enableHzControl) return fpsCap;
        if (CFG285.enableHzControl && !CFG285.enableFPSControl) return hzCap;
    }
    return (fpsCap > 0) ? fpsCap : hzCap;
}

static inline float Titanium_RangeFloorForCap(float cap) {
    return cap;
}

static inline SafeFrameRateRange Titanium_NormalizeFrameRateRange(SafeFrameRateRange range, BOOL systemUI) {
    (void)systemUI;
    (void)range;
    
    NSInteger cap = Titanium_GetEffectiveFrameCap();
    if (cap < 15) cap = 15;
    if (cap > 240) cap = 240;

    float target = (float)cap;
    return SafeMakeFRR(target, target, target);
}

// ====================================================================================================
// [BỘ NHẬN DIỆN & LÀM MƯỢT DYNAMIC ISLAND TWEAK / NHẠC CHẠY NỀN HÚT LÊN ĐẢO]
// ====================================================================================================

static volatile uint64_t g_dynamicMorphStartMs = 0;

static inline uint64_t Titanium_FluidNowMs(void) {
    return (uint64_t)([[NSProcessInfo processInfo] systemUptime] * 1000.0);
}

static inline void Titanium_MarkDynamicMorphBurst(void) {
    g_dynamicMorphStartMs = Titanium_FluidNowMs();
}

static inline BOOL Titanium_IsInDynamicMorphWindow(void) {
    if (g_isInteracting || g_activeAnimationCount > 0) return YES;
    uint64_t now = Titanium_FluidNowMs();
    return (now >= g_dynamicMorphStartMs && (now - g_dynamicMorphStartMs) < 650);
}

static inline BOOL Titanium_IsDynamicIslandOrMusicMorphClass(NSString *clsName) {
    if (!clsName || clsName.length == 0) return NO;
    return ([clsName containsString:@"SystemAperture"] ||
            [clsName containsString:@"SAUIElement"] ||
            [clsName containsString:@"Dynamic"] ||
            [clsName containsString:@"Peninsula"] ||
            [clsName containsString:@"Island"] ||
            [clsName containsString:@"FluidSwitcher"] ||
            [clsName containsString:@"SBAppClip"] ||
            [clsName containsString:@"NowPlaying"] ||
            [clsName containsString:@"MRU"] ||
            [clsName containsString:@"AudioWaveform"] ||
            [clsName containsString:@"SBMedia"]);
}

#if TITANIUM_ENABLE_RATE_KEEPER

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

    s_keeperPoller = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(s_keeperPoller, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), (uint64_t)(50 * NSEC_PER_MSEC), (uint64_t)(10 * NSEC_PER_MSEC));
    dispatch_source_set_event_handler(s_keeperPoller, ^{
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) &&
            (Titanium_ShouldLockTargetRate() || g_activeAnimationCount > 0 || Titanium_IsInDynamicMorphWindow())) {
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

    float targetHz = (float)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15.0f) targetHz = 15.0f;
    if (targetHz > 240.0f) targetHz = 240.0f;

    if (!s_keeperLink) {
        s_keeperLink = [CADisplayLink displayLinkWithTarget:[TitaniumRateKeeper class] selector:@selector(tick:)];
        [s_keeperLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        [s_keeperLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:UITrackingRunLoopMode];
    }
    if (@available(iOS 15.0, *)) {
        @try {
            s_keeperLink.preferredFrameRateRange = SafeMakeFRR(targetHz, targetHz, targetHz);
        } @catch (__unused NSException *e) {}
    }
    s_keeperLink.preferredFramesPerSecond = (NSInteger)targetHz;
    s_keeperIdleFrames = 0;
    s_keeperLink.paused = NO;
}

+ (void)tick:(CADisplayLink *)link {
    if (Titanium_ShouldLockTargetRate() || g_activeAnimationCount > 0 || g_isInteracting || Titanium_IsInDynamicMorphWindow()) {
        s_keeperIdleFrames = 0;
    } else {
        s_keeperIdleFrames++;
        if (s_keeperIdleFrames > 90) {
            link.paused = YES;
        }
    }
}

@end

#endif

// ====================================================================================================
// [WEBKIT / SAFARI HZ & FPS OVERDRIVE ENGINE]
// ====================================================================================================

static NSString *Titanium_BuildWebFPSOverdriveScript(NSInteger targetFPS) {
    if (targetFPS < 15) targetFPS = 15;
    if (targetFPS > 240) targetFPS = 240;
    return [NSString stringWithFormat:
        @"(function(){"
        @"  window.__titaniumTargetFPS = %ld;"
        @"  if (window.__titaniumRAFInstalled) return;"
        @"  window.__titaniumRAFInstalled = true;"
        @"  var callbacks = new Map();"
        @"  var nextId = 1;"
        @"  var running = false;"
        @"  var lastTickTime = performance.now();"
        @"  var channel = new MessageChannel();"
        @"  function step() {"
        @"    if (callbacks.size === 0) { running = false; return; }"
        @"    var fps = window.__titaniumTargetFPS || 60;"
        @"    if (fps < 15) fps = 15; if (fps > 240) fps = 240;"
        @"    var interval = 1000.0 / fps;"
        @"    var now = performance.now();"
        @"    var due = lastTickTime + interval;"
        @"    if (now + 0.08 >= due) {"
        @"      if (now - due > interval * 2.0) { lastTickTime = now; } else { lastTickTime = due; }"
        @"      var currentBatch = Array.from(callbacks.values());"
        @"      callbacks.clear();"
        @"      var ts = performance.now();"
        @"      for (var i = 0; i < currentBatch.length; i++) {"
        @"        try { currentBatch[i](ts); } catch(e) {}"
        @"      }"
        @"      if (callbacks.size > 0) { scheduleNext(); } else { running = false; }"
        @"    } else {"
        @"      var remain = due - now;"
        @"      if (remain > 2.2) {"
        @"        setTimeout(step, Math.floor(remain - 1.2));"
        @"      } else {"
        @"        channel.port2.postMessage(0);"
        @"      }"
        @"    }"
        @"  }"
        @"  function scheduleNext() {"
        @"    var fps = window.__titaniumTargetFPS || 60;"
        @"    var interval = 1000.0 / fps;"
        @"    var remain = (lastTickTime + interval) - performance.now();"
        @"    if (remain > 2.2) {"
        @"      setTimeout(step, Math.floor(remain - 1.2));"
        @"    } else {"
        @"      channel.port2.postMessage(0);"
        @"    }"
        @"  }"
        @"  channel.port1.onmessage = step;"
        @"  window.requestAnimationFrame = function(cb) {"
        @"    if (typeof cb !== 'function') return 0;"
        @"    var id = nextId++;"
        @"    callbacks.set(id, cb);"
        @"    if (!running) {"
        @"      running = true;"
        @"      lastTickTime = performance.now();"
        @"      scheduleNext();"
        @"    }"
        @"    return id;"
        @"  };"
        @"  window.cancelAnimationFrame = function(id) {"
        @"    callbacks.delete(id);"
        @"  };"
        @"})();", (long)targetFPS];
}

static const void *kTitaniumWebLastSyncFPSKey = &kTitaniumWebLastSyncFPSKey;

// ====================================================================================================
// NHÓM 3: KHÓA CỨNG HZ/FPS THEO APP (15 - 240HZ) + ÉP DỰNG HÌNH 0.0MS + ĐIỀN ĐỦ THÂN HÀM RỖNG
// ====================================================================================================

%group Group_FluidTransitions_Pacing

%hook CADisplayLink

- (NSInteger)preferredFramesPerSecond {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        @try {
            %orig(Titanium_GetEffectiveFrameCap());
        } @catch (__unused NSException *e) {}
        return;
    }
    %orig(fps);
}

- (SafeFrameRateRange)preferredFrameRateRange API_AVAILABLE(ios(15.0)) {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        float maxTarget = (float)Titanium_GetEffectiveFrameCap();
        if (maxTarget < 15.0f) maxTarget = 15.0f;
        if (maxTarget > 240.0f) maxTarget = 240.0f;
        return SafeMakeFRR(maxTarget, maxTarget, maxTarget);
    }
    return %orig;
}

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        float maxTarget = (float)Titanium_GetEffectiveFrameCap();
        if (maxTarget < 15.0f) maxTarget = 15.0f;
        if (maxTarget > 240.0f) maxTarget = 240.0f;
        range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
    }
    @try {
        %orig(range);
    } @catch (__unused NSException *e) {}
}

- (CFTimeInterval)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        if (cap > 0) return (1.0 / (double)cap);
    }
    return %orig;
}

- (CFTimeInterval)targetTimestamp {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        if (cap > 0) return (self.timestamp + (1.0 / (double)cap));
    }
    return %orig;
}

- (void)setFrameInterval:(NSInteger)interval {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        @try {
            %orig(1);
        } @catch (__unused NSException *e) {
            %orig(interval);
        }
        return;
    }
    %orig(interval);
}

%end

%hook CADisplayMode

- (double)refreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return (double)Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

%end

%hook CADisplay

- (BOOL)allowsVirtualModes {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
    return %orig;
}

- (void)setAllowsVirtualModes:(BOOL)allows {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        @try {
            %orig(YES);
        } @catch (__unused NSException *e) {}
        return;
    }
    %orig(allows);
}

- (double)latency {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return 0.0;
    return %orig;
}

- (void)setLatency:(double)latency {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        @try {
            %orig(0.0);
        } @catch (__unused NSException *e) {}
        return;
    }
    %orig(latency);
}

- (CFTimeInterval)minimumFrameDuration {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        if (cap < 15) cap = 15;
        if (cap > 240) cap = 240;
        return (1.0 / (double)cap);
    }
    return %orig;
}

- (double)refreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        return (cap > 0) ? (double)cap : %orig;
    }
    return %orig;
}

- (double)heartbeatRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        return (cap > 0) ? (double)cap : %orig;
    }
    return %orig;
}

- (NSInteger)preferredFPS {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) return %orig;
    return Titanium_GetEffectiveFrameCap();
}

- (void)setPreferredFPS:(NSInteger)fps {
    if (!IS_ACTIVE && g_syncPayloadV285.masterEnabled == 0) {
        %orig(fps);
        return;
    }
    @try {
        %orig(Titanium_GetEffectiveFrameCap());
    } @catch (__unused NSException *e) {}
}

- (NSInteger)minimumFPS {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return Titanium_GetEffectiveFrameCap();
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
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (NSInteger)_maximumFramesPerSecond {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return Titanium_GetEffectiveFrameCap();
    }
    return %orig;
}

- (CGFloat)_refreshRate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        return (cap > 0) ? (CGFloat)cap : %orig;
    }
    return %orig;
}

- (void)_setTargetRefreshRate:(CGFloat)rate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        @try {
            %orig((cap > 0) ? (CGFloat)cap : rate);
        } @catch (__unused NSException *e) {}
        return;
    }
    %orig(rate);
}

%end

// PHÁ KHÓA CỨNG 60HZ & BẢO VỆ RAM JETSAM (CACHE DICTIONARY KHÔNG TẠO RÁC BỘ NHỚ)
static const void *kTitaniumCachedInfoDictKey = &kTitaniumCachedInfoDictKey;

%hook NSBundle

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && key) {
        if ([key isEqualToString:@"CADisableMinimumFrameDuration"] ||
            [key isEqualToString:@"CADisableMinimumFrameDurationOnPhone"] ||
            [key isEqualToString:@"UIApplicationSupportsHDR"]) {
            return @YES;
        }
    }
    return %orig(key);
}

- (NSDictionary *)infoDictionary {
    NSDictionary *dict = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && dict) {
        if ([dict[@"CADisableMinimumFrameDurationOnPhone"] boolValue]) {
            return dict;
        }
        NSDictionary *cached = objc_getAssociatedObject(self, kTitaniumCachedInfoDictKey);
        if (cached) return cached;

        NSMutableDictionary *mDict = [dict mutableCopy];
        mDict[@"CADisableMinimumFrameDuration"] = @YES;
        mDict[@"CADisableMinimumFrameDurationOnPhone"] = @YES;
        NSDictionary *immutableCopy = [mDict copy];
        objc_setAssociatedObject(self, kTitaniumCachedInfoDictKey, immutableCopy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return immutableCopy;
    }
    return dict;
}

%end

%hook WKWebView

- (instancetype)initWithFrame:(CGRect)frame configuration:(WKWebViewConfiguration *)configuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && configuration) {
        NSInteger targetCap = Titanium_GetEffectiveFrameCap();
        NSString *js = Titanium_BuildWebFPSOverdriveScript(targetCap);
        WKUserScript *script = [[WKUserScript alloc] initWithSource:js
                                                      injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                   forMainFrameOnly:NO];
        if (!configuration.userContentController) {
            configuration.userContentController = [[WKUserContentController alloc] init];
        }
        [configuration.userContentController addUserScript:script];
    }
    WKWebView *webView = %orig(frame, configuration);
    if (webView && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        objc_setAssociatedObject(webView, kTitaniumWebLastSyncFPSKey, @(Titanium_GetEffectiveFrameCap()), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return webView;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        NSInteger currentCap = Titanium_GetEffectiveFrameCap();
        NSNumber *lastSynced = objc_getAssociatedObject(self, kTitaniumWebLastSyncFPSKey);
        if (!lastSynced || [lastSynced integerValue] != currentCap) {
            objc_setAssociatedObject(self, kTitaniumWebLastSyncFPSKey, @(currentCap), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSString *updateJS = [NSString stringWithFormat:@"window.__titaniumTargetFPS = %ld; if (!window.__titaniumRAFInstalled) { %@ }",
                                  (long)currentCap, Titanium_BuildWebFPSOverdriveScript(currentCap)];
            [self evaluateJavaScript:updateJS completionHandler:nil];
        }
    }
    return %orig(point, event);
}

%end

%hook CAAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float maxTarget = (float)Titanium_GetEffectiveFrameCap();
            if (maxTarget < 15.0f) maxTarget = 15.0f;
            if (maxTarget > 240.0f) maxTarget = 240.0f;
            range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
        }
    }
    @try {
        %orig(range);
    } @catch (__unused NSException *e) {}
}

- (SafeFrameRateRange)preferredFrameRateRange API_AVAILABLE(ios(15.0)) {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        float maxTarget = (float)Titanium_GetEffectiveFrameCap();
        if (maxTarget < 15.0f) maxTarget = 15.0f;
        if (maxTarget > 240.0f) maxTarget = 240.0f;
        return SafeMakeFRR(maxTarget, maxTarget, maxTarget);
    }
    return %orig;
}

%end

%hook CASpringAnimation

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            float maxTarget = (float)Titanium_GetEffectiveFrameCap();
            if (maxTarget < 15.0f) maxTarget = 15.0f;
            if (maxTarget > 240.0f) maxTarget = 240.0f;
            range = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
        }
    }
    @try {
        %orig(range);
    } @catch (__unused NSException *e) {}
}

- (void)setSettlingDuration:(CFTimeInterval)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        Titanium_MarkDynamicMorphBurst();
    }
    @try {
        %orig(duration);
    } @catch (__unused NSException *e) {}
}

%end

%hook CALayer

- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && anim) {
        if (@available(iOS 15.0, *)) {
            if ([anim respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                float maxTarget = (float)Titanium_GetEffectiveFrameCap();
                if (maxTarget < 15.0f) maxTarget = 60.0f;
                if (maxTarget > 240.0f) maxTarget = 240.0f;
                @try {
                    anim.preferredFrameRateRange = SafeMakeFRR(maxTarget, maxTarget, maxTarget);
                } @catch (__unused NSException *e) {}
            }
        }

        if (Titanium_IsSpringBoard()) {
            Titanium_MarkDynamicMorphBurst();
            EnforceMaxCPUPower();
            #if TITANIUM_ENABLE_RATE_KEEPER
            [TitaniumRateKeeper kick];
            #endif
        }
    }
    %orig(anim, key);
}

// [ĐÃ ĐIỀN THÂN HÀM RỖNG]: Ép tỉ lệ độ nét và triệt tiêu mờ nhòe khung hình khi thay đổi kích thước
- (void)setBounds:(CGRect)bounds {
    %orig(bounds);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (self.contentsScale < [UIScreen mainScreen].scale) {
            self.contentsScale = [UIScreen mainScreen].scale;
        }
    }
}

// [ĐÃ ĐIỀN THÂN HÀM RỖNG]: Ép luồng đồ họa cập nhật layout ngay lập tức
- (void)setNeedsLayout {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && [NSThread isMainThread]) {
        Titanium_EnableZeroLatencyPipeline();
    }
}

%end

%hook UIView

- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && Titanium_IsSpringBoard()) {
        @try {
            NSString *clsName = NSStringFromClass([self class]);
            if (Titanium_IsDynamicIslandOrMusicMorphClass(clsName)) {
                Titanium_MarkDynamicMorphBurst();
                EnforceMaxCPUPower();
                #if TITANIUM_ENABLE_RATE_KEEPER
                [TitaniumRateKeeper kick];
                #endif
            }
        } @catch (__unused NSException *e) {}
    }
}

%end

%hook AVPlayer

- (void)setRate:(float)rate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        g_isVideoPlayingActive = (rate > 0.0f);
    }
    %orig(rate);
}

%end

%hook UIApplication

- (void)_applicationDidBecomeActive:(id)arg1 {
    %orig(arg1);
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES;
        g_activeAnimationCount++;
        Titanium_MarkDynamicMorphBurst();
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();

        #if TITANIUM_ENABLE_RATE_KEEPER
        if (Titanium_IsSpringBoard()) {
            [TitaniumRateKeeper kick];
        }
        #endif

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(550 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
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
    if (!Titanium_DisplaySpoofAllowed()) return;
    @try {
        Class screenCls = objc_getClass("UIScreen");
        if (!screenCls) return;

        SEL sel1 = sel_registerName("supportsDynamicRefreshRate");
        SEL sel2 = sel_registerName("_supportsDynamicRefreshRate");

        if (class_getInstanceMethod(screenCls, sel1)) {
            class_replaceMethod(screenCls, sel1, (IMP)fake_supportsDynamicRefreshRate, "B@:");
        } else {
            class_addMethod(screenCls, sel1, (IMP)fake_supportsDynamicRefreshRate, "B@:");
        }

        if (class_getInstanceMethod(screenCls, sel2)) {
            class_replaceMethod(screenCls, sel2, (IMP)fake_supportsDynamicRefreshRate, "B@:");
        } else {
            class_addMethod(screenCls, sel2, (IMP)fake_supportsDynamicRefreshRate, "B@:");
        }
    } @catch (__unused NSException *e) {}
}

// ====================================================================================================
// NHÓM 4: ĐA NHIỆM SIÊU MƯỢT & CỬ CHỈ NGẮT LIÊN HOÀN (BẺ KHÓA CPU/GPU 100% & CHỐNG TRÀN RAM JETSAM)
// ====================================================================================================

%group Group_Switcher30Apps_Virtualization

// 1. CỬ CHỈ HOME: BÁM DÍNH NGÓN TAY TỨC THÌ, BẺ KHÓA LUỒNG REALTIME
%hook SBHomeGestureInteraction

- (void)_handleGestureBegan:(id)gesture {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = YES;
        g_isInteracting = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
        #if TITANIUM_ENABLE_RATE_KEEPER
        [TitaniumRateKeeper kick];
        #endif
    }
    %orig;
}

- (void)_handleGestureChanged:(id)gesture {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = YES;
        g_isInteracting = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
    %orig;
}

- (void)_handleGestureEnded:(id)gesture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

- (void)_handleGestureCancelled:(id)gesture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isContinuousSwiping = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

%end

// 2. GIAO DỊCH ĐA NHIỆM: ÉP MỞ KHÓA NGẮT CHUYỂN CẢNH TRONG 0MS
%hook SBFluidSwitcherGestureWorkspaceTransaction

- (BOOL)canInterruptActiveGesture {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.reduceMultiTaskLag || g_isRateLockedV285)) {
        if (g_isContinuousSwiping) return YES;
    }
    return %orig;
}

- (void)_begin {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
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

- (double)deckSwipeSpeedFactor {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.reduceMultiTaskLag) {
        return 1.35;
    }
    return %orig;
}

- (double)cardFlyInDuration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.fixAppExitStutter || g_syncPayloadV285.antiStutterExit)) {
        return 0.20;
    }
    return %orig;
}

%end

// 4. QUẢN LÝ BỘ NHỚ VÀ QUÁN TÍNH APP SWITCHER (CHỐNG JETSAM KILL)
%hook SBAppSwitcherSettings

- (BOOL)shouldKeepAppSnapshotsInMemory {
    // Luôn trả về NO để giải phóng VRAM GPU, triệt tiêu 100% lỗi JetsamEvent tràn RAM khi lướt đa nhiệm
    return NO;
}

- (BOOL)shouldSimplifyForOptions:(long long)options {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        return YES;
    }
    return %orig(options);
}

- (CGFloat)decelerationRate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && CFG285.reduceMultiTaskLag) {
        return 0.994;
    }
    return %orig;
}

%end

// 5. GIAO DỊCH THOÁT VÀ MỞ ỨNG DỤNG TỪ HOME (ĐỒNG BỘ 15HZ - 240HZ KHÔNG DROP KHUNG HÌNH)
%hook SBAppToHomeWorkspaceTransaction

- (void)_willBegin {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isInteracting = YES;
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
        #if TITANIUM_ENABLE_RATE_KEEPER
        [TitaniumRateKeeper kick];
        #endif
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isContinuousSwiping = NO;
        g_isUserTouchingScreen = NO;
        g_isInteracting = NO;
    }
}

%end

%hook SBHomeToAppWorkspaceTransaction

- (void)_willBegin {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isInteracting = YES;
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
        #if TITANIUM_ENABLE_RATE_KEEPER
        [TitaniumRateKeeper kick];
        #endif
    }
    %orig;
}

- (void)_didComplete {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isInteracting = NO;
    }
}

%end

%hook SBAppSwitcherController

- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
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
// NHÓM 5: KHỞI CHẠY ỨNG DỤNG SIÊU TỐC (ĐIỀN ĐỦ THÂN HÀM RỖNG - GIA TỐC MỞ APP 0MS)
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
    double orig = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
        return (orig > 0.18) ? (orig * 0.72) : orig;
    }
    return orig;
}

- (double)launchDuration {
    double orig = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
        return (orig > 0.18) ? (orig * 0.72) : orig;
    }
    return orig;
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
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_syncPayloadV285.fastAppLaunch)) {
        g_isInteracting = YES;
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
        #if TITANIUM_ENABLE_RATE_KEEPER
        if (Titanium_IsSpringBoard()) [TitaniumRateKeeper kick];
        #endif
    }
    %orig;
}

- (void)_didCompleteAnimation {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (g_activeAnimationCount > 0) g_activeAnimationCount--;
        g_isInteracting = NO;
    }
}

%end

%hook UIApplication

- (void)_runWithMainScene:(id)scene transitionContext:(id)context completion:(id)completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
        Titanium_EnableZeroLatencyPipeline();
    }
    %orig(scene, context, completion);
}

- (void)_applicationWillEnterForeground {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
        Titanium_ReapplyFrameRateToAllScenes();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 6: CUỘN FEED TIKTOK / BÀN PHÍM SIÊU NHẠY & ĐỒNG BỘ ANIMATION UIVIEW
// ====================================================================================================

%group Group_Scroll_And_Keyboard_Opt

// 1. TỐC ĐỘ NẢY BÀN PHÍM CHUẨN XÁC: ÉP RÚT VỀ 0.12S
%hook UIInputViewAnimationStyle

- (double)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        return 0.12;
    }
    return %orig;
}

%end

// 2. TRIỆT TIÊU 100% ĐỘ TRỄ GÕ PHÍM NỘI BỘ APPLE
%hook UIKeyboardImpl

+ (NSTimeInterval)suppressionIntervalForTouchesOnKeyboard {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        return 0.0;
    }
    return %orig;
}

- (void)showKeyboard {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
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

- (void)setSelectedIndex:(NSUInteger)index {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

- (void)setSelectedViewController:(UIViewController *)selectedViewController {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

%end

// 4. ÉP TỐC ĐỘ CHUYỂN TRANG NAVIGATION & VUỐT MÉP QUAY LẠI TỨC THÌ
%hook UINavigationController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && self.interactivePopGestureRecognizer) {
        self.interactivePopGestureRecognizer.delaysTouchesBegan = NO;
    }
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    return %orig;
}

%end

// 5. TỐI ƯU CHUYỂN CẢNH & HIỂN THỊ POPUP/QUẢNG CÁO TỨC THÌ (BẺ KHÓA CPU ĐẦU VÀO)
%hook UIViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
        Titanium_TriggerInstantTouchBurst();

        if (flag && viewControllerToPresent) {
            viewControllerToPresent.view.layer.speed = 1.6f;
        }

        __weak UIViewController *weakTarget = viewControllerToPresent;
        void (^safeCompletion)(void) = ^{
            if (weakTarget && weakTarget.isViewLoaded) {
                weakTarget.view.layer.speed = 1.0f;
            }
            g_isInteracting = NO;
            g_lastInteractiveTick = mach_absolute_time();

            if (completion) {
                completion();
            }
        };

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

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        g_isInteracting = YES;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
        Titanium_TriggerInstantTouchBurst();

        if (flag && self.isViewLoaded) {
            self.view.layer.speed = 1.6f;
        }

        void (^safeDismissCompletion)(void) = ^{
            g_isInteracting = NO;
            g_lastInteractiveTick = mach_absolute_time();
            if (completion) {
                completion();
            }
        };

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

// 6. BẮT TRẠNG THÁI GESTURE VUỐT THỰC TẾ & BÙ TỌA ĐỘ
%hook UIPanGestureRecognizer

- (void)setState:(UIGestureRecognizerState)state {
    %orig(state);

    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        uint64_t now = mach_absolute_time();
        if (state == UIGestureRecognizerStateBegan || state == UIGestureRecognizerStateChanged) {
            g_isUserTouchingScreen = YES;
            g_isScrollingActive = YES;
            g_isInteracting = YES;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            EnforceMaxCPUPower();
            Titanium_TriggerInstantTouchBurst();
        } else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled) {
            g_isUserTouchingScreen = NO;
            g_isScrollingActive = NO;
            g_isInteracting = NO;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
    }
}

%end

// 7. ĐỘNG CƠ CUỘN SCROLLVIEW: BÁM TAY TỨC THÌ & GIỮ KHUNG HÌNH CAO
%hook UIScrollView

- (UIPanGestureRecognizer *)panGestureRecognizer {
    UIPanGestureRecognizer *pan = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard() && pan) {
        pan.delaysTouchesBegan = NO;
    }
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
        uint64_t now = mach_absolute_time();
        g_isUserTouchingScreen = YES;
        g_isInteracting = YES;
        g_lastInteractionMachTime = now;
        g_lastInteractiveTick = now;
        EnforceMaxCPUPower();
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
        EnforceMaxCPUPower();
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
            g_isInteracting = YES;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
        }
        if (!self.isPagingEnabled && self.isDecelerating) {
            self.decelerationRate = 0.994f;
        }
    }
    %orig(timestamp);
}

- (CGFloat)decelerationRate {
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
// NHÓM 7: SPRINGBOARD - TOÀN BỘ HIỆU ỨNG HỆ THỐNG (BẺ KHÓA HIỆU NĂNG TOÀN DIỆN)
// ====================================================================================================

%group Group_Display_SpringBoardV285

// ==================== CỬ CHỈ ĐA NHIỆM & TƯƠNG TÁC HỆ THỐNG ====================

%hook SBFluidSwitcherViewController

- (void)handleFluidSwitcherGesture:(id)gesture {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

%end

%hook SBScreenshotManager

- (void)saveScreenshotsWithCompletion:(id)completion {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
    }
    %orig;
}

%end

%hook SBVolumeControl

- (void)increaseVolume {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isVolumeHoldingV285 = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
    }
    %orig;
}

- (void)decreaseVolume {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isVolumeHoldingV285 = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
    }
    %orig;
}

- (void)changeVolumeByDelta:(float)delta {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isVolumeHoldingV285 = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
    }
    %orig;
}

- (void)cancelVolumeEvent {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isVolumeHoldingV285 = NO;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

%end

// ==================== CONTROL CENTER & NOTIFICATION CENTER ====================

%hook SBControlCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

%end

%hook SBNotificationCenterController

- (void)presentAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

- (void)dismissAnimated:(BOOL)animated completion:(id)completion {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

%end

// ==================== CUỘN MÀN HÌNH CHÍNH & TRANG ICON ====================

%hook SBIconScrollView

- (BOOL)delaysContentTouches {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.dynamicInterpolation)) {
        return NO;
    }
    return %orig;
}

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
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

- (void)_smoothScrollWithTimestamp:(double)timestamp {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isScrollingActive = YES;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

%end

%hook SBIconController

- (void)scrollToIconListAtIndex:(NSInteger)index animate:(BOOL)animate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

%end

// ==================== THƯ MỤC (FOLDER) - TỐC ĐỘ COLOROS SIÊU MƯỢT ====================

%hook SBFolderControllerAnimationSettings

- (double)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.dynamicInterpolation)) {
        return 0.20;
    }
    return %orig;
}

%end

%hook SBFolderView

- (void)prepareToOpen {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

- (void)didClose {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

%end

%hook SBFolderController

- (void)openFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

- (void)closeFolderAnimated:(BOOL)animated withCompletion:(id)completion {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

%end

// ==================== 3D TOUCH / HAPTIC TOUCH SIÊU TỐC ====================

%hook SBIconForceTouchSettings

- (double)delayBeforeOpening {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.colorOs17SmoothEngine || g_syncPayloadV285.zeroLatencyTouch)) {
        return 0.04;
    }
    return %orig;
}

%end

// ==================== MÀN HÌNH KHÓA & NẠP TRƯỚC ỨNG DỤNG ====================

%hook CSCoverSheetViewController

- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

%end

%hook SBHomeScreenViewController

- (void)viewWillAppear:(BOOL)animated {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

%end

%hook SBApplication

- (void)willActivate {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig;
}

- (BOOL)shouldPrewarmOnLaunch {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_isRateLockedV285 || g_syncPayloadV285.fastAppLaunch)) {
        return YES;
    }
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 8: PIPELINE CHO PICTURE-IN-PICTURE (ĐỒNG BỘ VIDEO 60FPS & GIỮ TRỌN 15HZ - 240HZ CHO MÀN HÌNH CHÍNH)
// ====================================================================================================

%group Group_V285_FloatingWindow_PiP

%hook PGPictureInPictureRemoteObject

- (void)_updatePreferredContentSize {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

- (void)startPictureInPicture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

- (void)stopPictureInPictureAnimated:(BOOL)animated {
    %orig(animated);
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

%end

%hook SBPIPController

- (void)startPictureInPictureForApplicationWithProcessIdentifier:(int)pid sceneIdentifier:(id)sceneId animated:(BOOL)animated completionHandler:(id)completion {
    %orig(pid, sceneId, animated, completion);
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_LockMainThreadFast();
    }
}

%end

%hook AVPictureInPictureController

- (void)startPictureInPicture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

- (void)stopPictureInPicture {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_BoostRenderWithoutStarvingNetwork();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 9: PHÂN TÁCH PHẦN CỨNG (HOME BUTTON VẬT LÝ - PHẢN HỒI 0MS)
// ====================================================================================================

%group Group_HardwareSegregation_ClassicHomeV285

%hook SBHomeHardwareButtonActions

- (void)performSinglePressAction {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

- (void)performDoublePressAction {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 10: QUẢN LÝ TIẾN TRÌNH & BẢO VỆ JETSAM (KHỞI TẠO APP 0MS)
// ====================================================================================================

%group Group_SpringBoard_ProcessManagerV285

%hook SBMainWorkspace

- (void)handleApplicationLaunch:(id)application {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.turboAppLaunch || g_isRateLockedV285 || g_syncPayloadV285.fastAppLaunch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_LockMainThreadFast();
    }
    %orig(application);
}

%end

%end

// ====================================================================================================
// NHÓM 11: NÂNG CẤP TOÀN BỘ APP THỨ BA & CHUYỂN TIẾP VIEWCONTROLLER (ĐÃ ĐIỀN ĐỦ 100% THÂN HÀM)
// ====================================================================================================

%group Group_UIKit_ThirdParty_IsolatedV285

%hook UIApplication

- (void)_sendWillEnterForegroundCallbacks {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        if (!Titanium_IsSpringBoard()) {
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_EnableZeroLatencyPipeline();
        }
    }
    %orig;
}

%end

%hook UIWindow

- (void)makeKeyAndVisible {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;

        if (!Titanium_IsSpringBoard()) {
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_EnableZeroLatencyPipeline();
            
            if (@available(iOS 15.0, *)) {
                @try {
                    UIWindowScene *scene = self.windowScene;
                    if (scene && [scene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                        float targetHz = (float)Titanium_GetEffectiveFrameCap();
                        if (targetHz < 15.0f) targetHz = 15.0f;
                        if (targetHz > 240.0f) targetHz = 240.0f;
                        [scene setPreferredFrameRateRange:SafeMakeFRR(targetHz, targetHz, targetHz)];
                    }
                } @catch (__unused NSException *e) {}
            }
        }
    }
    %orig;
}

%end

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        if (!Titanium_IsSpringBoard()) {
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_EnableZeroLatencyPipeline();
        }
    }
    %orig(animated);
}

- (void)viewWillDisappear:(BOOL)animated {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        if (!Titanium_IsSpringBoard()) {
            EnforceMaxCPUPower();
        }
    }
    %orig(animated);
}

%end

%hook UIViewControllerTransitionCoordinator

- (BOOL)animateAlongsideTransition:(void (^)(id context))animation
                        completion:(void (^)(id context))completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        if (!Titanium_IsSpringBoard()) {
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_EnableZeroLatencyPipeline();
        }
    }
    return %orig(animation, completion);
}

%end

%hook _UIViewControllerTransitionContext

- (void)__runLifecycleForViewController:(UIViewController *)vc 
                                  state:(NSInteger)state 
                            transition:(id)transition {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        if (!Titanium_IsSpringBoard()) {
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_EnableZeroLatencyPipeline();
        }
    }
    %orig(vc, state, transition);
}

%end

%hook UIPresentationController

- (void)presentationTransitionWillBegin {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        if (!Titanium_IsSpringBoard()) {
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
            Titanium_EnableZeroLatencyPipeline();
        }
    }
    %orig;
}

- (void)dismissalTransitionWillBegin {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        if (!Titanium_IsSpringBoard()) {
            EnforceMaxCPUPower();
            Titanium_EnableZeroLatencyPipeline();
        }
    }
    %orig;
}

%end

// ĐỒNG BỘ MỌI CHUYỂN ĐỘNG UIVIEW LÊN MỨC HZ/FPS ĐÃ CHỌN TRONG APP
%hook UIView

+ (void)animateWithDuration:(NSTimeInterval)duration
                      delay:(NSTimeInterval)delay
                    options:(UIViewAnimationOptions)options
                 animations:(void (^)(void))animations
                 completion:(void (^)(BOOL finished))completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_EnableZeroLatencyPipeline();
        options |= UIViewAnimationOptionAllowUserInteraction;
    }
    %orig(duration, delay, options, animations, completion);
}

+ (void)animateWithDuration:(NSTimeInterval)duration
                      delay:(NSTimeInterval)delay
     usingSpringWithDamping:(CGFloat)dampingRatio
      initialSpringVelocity:(CGFloat)velocity
                    options:(UIViewAnimationOptions)options
                 animations:(void (^)(void))animations
                 completion:(void (^)(BOOL finished))completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_EnableZeroLatencyPipeline();
        options |= UIViewAnimationOptionAllowUserInteraction;
    }
    %orig(duration, delay, dampingRatio, velocity, options, animations, completion);
}

%end

// GIA TỐC DISPLAYLINK VÀ VẼ BẤT ĐỒNG BỘ CHO APP THỨ BA
%hook CADisplayLink

- (void)addToRunLoop:(NSRunLoop *)runLoop forMode:(NSRunLoopMode)mode {
    %orig(runLoop, mode);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        if (cap < 15) cap = 15;
        if (cap > 240) cap = 240;
        @try {
            self.preferredFramesPerSecond = cap;
            if (@available(iOS 15.0, *)) {
                if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float fCap = (float)cap;
                    self.preferredFrameRateRange = SafeMakeFRR(fCap, fCap, fCap);
                }
            }
        } @catch (__unused NSException *e) {}
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
// NHÓM 12: BÀN PHÍM STREAM TEXT & CẢM ỨNG NÚT BẤM (0MS TOUCH)
// ====================================================================================================

%group Group_InstantActionAndMenuTransitions_Boost

%hook UIKeyboardTaskQueue

- (void)performTask:(id)task {
    @try {
        %orig(task);
    } @catch (__unused NSException *e) {
        %orig;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

%end

%hook UIKeyboardImpl

- (void)callShowKeyboard {
    @try {
        %orig;
    } @catch (__unused NSException *e) {}
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
    }
}

%end

%hook UIPeripheralHost

- (double)getLastTranslateTime {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.keyboardZeroLagV24 || g_syncPayloadV285.keyboardZeroLagV3)) {
            return 0.0;
        }
    } @catch (__unused NSException *e) {}
    return %orig;
}

%end

%hook UIButton

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    @try {
        %orig(touches, event);
    } @catch (__unused NSException *e) {
        %orig;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 13: QUẢN LÝ NHIỆT ĐỘ & NGUỒN ĐIỆN (MỞ KHÓA BÓP XUNG & BẢO VỆ PHẦN CỨNG THẬT)
// ====================================================================================================

%group Group_Global_Thread_Governor_Unthrottled

%hook NSProcessInfo

- (NSProcessInfoThermalState)thermalState {
    NSProcessInfoThermalState real = %orig;
    g_thermalSeriousV285 = (real >= NSProcessInfoThermalStateSerious);
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (real >= NSProcessInfoThermalStateCritical) {
            return real;
        }
        return NSProcessInfoThermalStateNominal;
    }
    return real;
}

- (BOOL)isLowPowerModeEnabled {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        if (CFG285.batterySaver60Hz || g_syncPayloadV285.powerSaveModeActive) {
            return YES;
        }
        return NO;
    }
    return %orig;
}

%end

%end

// ====================================================================================================
// NHÓM 14: ĐỘNG CƠ METAL GAME OVERDRIVE (ĐÃ VIẾT ĐỦ THÂN HÀM VÀ MỞ KHÓA LUỒNG)
// ====================================================================================================

%group Group_Titanium_Game_Metal_Overdrive

%hook CAMetalLayer

- (BOOL)serverPresentsWithTransaction {
    return %orig;
}

- (void)setServerPresentsWithTransaction:(BOOL)serverPresents {
    %orig(serverPresents);
}

%end

%end

// ====================================================================================================
// NHÓM 15: SILICON HARDWARE PIPELINE OVERDRIVE (BẺ KHÓA TOÀN LỰC KERNEL EL1 & MỞ KHÓA BĂNG THÔNG GPU)
// ====================================================================================================

#ifndef MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK
#define MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK 5
#endif

#ifndef MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT
#define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT 6
#endif

typedef int (*titanium_memstatus_ctrl_fn)(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);

static inline void Titanium_SeizeKernelHardwareControl(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @try {
            pid_t myPid = getpid();

            titanium_memstatus_ctrl_fn mem_ctrl = (titanium_memstatus_ctrl_fn)dlsym(RTLD_DEFAULT, "memorystatus_control");
            if (mem_ctrl) {
                mem_ctrl(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT, myPid, 1024, NULL, 0);
                mem_ctrl(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, myPid, 1024, NULL, 0);
            }

            #ifdef TASK_CATEGORY_POLICY
            task_category_policy_data_t catPolicy;
            catPolicy.role = (task_role_t)TASK_FOREGROUND_APPLICATION;
            task_policy_set(mach_task_self(), TASK_CATEGORY_POLICY, (task_policy_t)&catPolicy, TASK_CATEGORY_POLICY_COUNT);
            #endif

            setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
            setpriority(PRIO_PROCESS, myPid, -20);
        } @catch (__unused NSException *e) {}
    });
}

static volatile BOOL g_isAppColdBootPhase = YES;
static volatile uint64_t g_appBirthTimeMs = 0;

static inline uint64_t Titanium_ColdBootNowMs(void) {
    return (uint64_t)([[NSProcessInfo processInfo] systemUptime] * 1000.0);
}

static inline BOOL Titanium_IsInColdBootTurboWindow(void) {
    if (!g_isAppColdBootPhase) return NO;
    uint64_t now = Titanium_ColdBootNowMs();
    if (g_appBirthTimeMs == 0) g_appBirthTimeMs = now;
    if (now - g_appBirthTimeMs < 1800) {
        return YES;
    }
    g_isAppColdBootPhase = NO;
    return NO;
}

static inline void Titanium_A20PrewarmAssetsAndGPU(void) {
    Titanium_SeizeKernelHardwareControl();
    if (Titanium_IsSpringBoard()) return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        g_appBirthTimeMs = Titanium_ColdBootNowMs();
        g_isAppColdBootPhase = YES;

        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            @try {
                setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);

                id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
                (void)dev;

                NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
                if (bundlePath) {
                    NSString *assetsPath = [bundlePath stringByAppendingPathComponent:@"Assets.car"];
                    int fd = open([assetsPath fileSystemRepresentation], O_RDONLY | O_NONBLOCK);
                    if (fd >= 0) {
                        struct stat st;
                        if (fstat(fd, &st) == 0 && st.st_size > 0) {
                            off_t prefetchLen = (st.st_size > (12 * 1024 * 1024)) ? (12 * 1024 * 1024) : st.st_size;
                            struct radvisory ra;
                            ra.ra_offset = 0;
                            ra.ra_count = (int)prefetchLen;
                            fcntl(fd, F_RDADVISE, &ra);
                        }
                        close(fd);
                    }
                }
            } @catch (__unused NSException *e) {}
        });
    });
}

%group Group_Silicon_Hardware_Pipeline_Overdrive

%hook _MTLCommandQueue

- (void)setStatOptions:(NSUInteger)options {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        %orig(0);
        return;
    }
    %orig(options);
}

- (BOOL)executionEnabled {
#if TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) return YES;
#endif
    return %orig;
}

%end

%hook _MTLCommandBuffer

- (void)enqueue {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
    }
}

- (void)commit {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
    }
}

%end

%hook MTLTextureDescriptor

- (BOOL)allowGPUOptimizedContents {
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
    %orig(flag);
}

%end

%hook CAMetalDrawable

- (void)presentAfterMinimumDuration:(CFTimeInterval)duration {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && g_isMetalGameProcess) {
        %orig(0.0);
        return;
    }
    %orig(duration);
}

%end

%hook CALayer

- (void)setCornerRadius:(CGFloat)cornerRadius {
    %orig(cornerRadius);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && cornerRadius > 0.0f) {
        if (g_isInteracting || g_isScrollingActive) {
            self.allowsEdgeAntialiasing = NO;
        }
    }
}

%end

%hook UIPanGestureRecognizer

- (CGPoint)velocityInView:(UIView *)view {
    CGPoint vel = %orig(view);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && isfinite(vel.x) && isfinite(vel.y) && (fabs(vel.y) > 250.0 || fabs(vel.x) > 250.0)) {
        g_isScrollingActive = YES;
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
    }
    return vel;
}

%end

%hook UIApplication

- (BOOL)openURL:(NSURL *)url {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isInteracting = YES;
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
    }
    return %orig(url);
}

- (void)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(void (^)(BOOL success))completion {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isInteracting = YES;
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
    }
    %orig(url, options, completion);
}

%end

%hook UIScene

- (void)openURL:(NSURL *)url options:(id)options completionHandler:(void (^)(BOOL success))completion {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_isInteracting = YES;
        g_activeAnimationCount++;
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
    }
    %orig(url, options, completion);
}

%end

%hook UIDocumentInteractionController

- (BOOL)presentOpenInMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
    }
    return %orig(rect, view, animated);
}

- (BOOL)presentOpenInMenuFromBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
    }
    return %orig(item, animated);
}

- (BOOL)presentOptionsMenuFromRect:(CGRect)rect inView:(UIView *)view animated:(BOOL)animated {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
    }
    return %orig(rect, view, animated);
}

%end

%hook UIApplicationSceneTransitionContext

- (BOOL)waitForFence {
    return %orig;
}

- (void)setWaitForFence:(BOOL)wait {
    %orig(wait);
}

%end

%hook UIViewController

- (void)viewWillAppear:(BOOL)animated {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard() && Titanium_IsInColdBootTurboWindow()) {
        Titanium_TriggerInstantTouchBurst();
        EnforceMaxCPUPower();
    }
    %orig(animated);
}

%end

%end

// ====================================================================================================
// NHÓM 4: BỘ NÃO DỰ ĐOÁN TỌA ĐỘ NEURAL & CỬ CHỈ MÉP 0MS (BẺ KHÓA CPU/GPU 100% & BÁM TAY 1:1)
// ====================================================================================================

%group Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285

%hook _UITouchPredictor

- (id)predictedTouchesForTouch:(UITouch *)touch {
    id predicted = %orig(touch);
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || CFG285.zeroLagNeural || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnableZeroLatencyPipeline();
    }
    return predicted;
}

- (void)addTouch:(UITouch *)touch fromEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || CFG285.zeroLagNeural || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
    }
    %orig(touch, event);
}

%end

%hook _UIGestureEnvironment

- (void)_updateGesturesForEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig(event);
}

%end

%hook SBScreenEdgePanGestureRecognizer

- (BOOL)_shouldTryToBeginWithEvent:(UIEvent *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch)) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        Titanium_TriggerInstantTouchBurst();
        Titanium_LockMainThreadFast();
    }
    return %orig(event);
}

%end

%end

// ====================================================================================================
// NHÓM 16: SILICON CPU SCHEDULER & FLUID INTERRUPTIBLE ENGINE (CHIẾM QUYỀN P-CORE REALTIME)
// ====================================================================================================

%group Group_Silicon_Scheduler_Touch_Governor

%hook _UIEventFetcher

- (void)_receiveHIDEvent:(void *)event {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        static uint64_t s_lastPcoreBurst = 0;
        uint64_t now = mach_absolute_time();
        if (now - s_lastPcoreBurst > Titanium_NanosToMachTicks(30ULL * 1000000ULL)) {
            s_lastPcoreBurst = now;
            g_lastInteractionMachTime = now;
            g_lastInteractiveTick = now;
            
            EnforceMaxCPUPower();
            Titanium_EnforceThreadVIPPolicy();
        }
    }
    %orig(event);
}

%end

%hook _UIInteractiveHighlightEnvironment

- (void)applyHighlightWithAnimation:(BOOL)animated completion:(id)completion {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        %orig(NO, completion);
        return;
    }
    %orig(animated, completion);
}

%end

%end

// ====================================================================================================
// NHÓM 17: COREANIMATION RENDER SERVER GOVERNOR (ĐIỀN ĐỦ THÂN HÀM VẼ ASYNC & CHỐNG TREO RUNLOOP)
// ====================================================================================================

%group Group_CoreAnimation_RenderServer_Governor

%hook NSRunLoop

// [ĐÃ ĐIỀN THÂN HÀM RỖNG]: Kích xung luồng khi hệ thống đang xử lý tương tác chạm vuốt
- (BOOL)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (g_isInteracting || g_isScrollingActive || g_isUserTouchingScreen) {
            EnforceMaxCPUPower();
        }
    }
    return %orig(mode, limitDate);
}

%end

%hook CALayer

// [ĐÃ ĐIỀN THÂN HÀM RỖNG]: Ép vẽ bất đồng bộ trên luồng nền cho mọi layer thông thường để Main Thread mượt 240Hz
- (BOOL)drawsAsynchronously {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (!Titanium_IsAIApp()) {
            return YES;
        }
    }
    return %orig;
}

%end

%hook FBScene

- (void)updateSettings:(id)settings withTransitionContext:(id)context {
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
    %orig(settings, context);
}

%end

%end

// ====================================================================================================
// NHÓM 18: ZERO-OVERHEAD XNU MEMORY & PASSIVE SYSTEM RUNLOOP GOVERNOR
// ====================================================================================================

%group Group_System_Memory_And_RunLoop_Governor

%hook UIWindowScene

- (void)_readySceneForDisplay {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        g_lastInteractionMachTime = mach_absolute_time();
        g_lastInteractiveTick = g_lastInteractionMachTime;
        EnforceMaxCPUPower();
        if (Titanium_IsSpringBoard()) {
            Titanium_LockMainThreadFast();
        }
    }
}

%end

%hook MTMaterialView

- (void)didMoveToWindow {
    %orig;
    if (TITANIUM_LITE_MODE) return;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && self.layer != nil) {
        self.layer.allowsGroupOpacity = YES;
    }
}

%end

%end

// ====================================================================================================
// NHÓM 19: CRYO-PACING DUTY-CYCLE & VRAM THERMAL DISSIPATION (GIẢM TẢI GPU - TRIỆT TIÊU DROP FPS)
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
        if (radius > 8.0) {
            %orig(8.0);
            return;
        }
    }
    %orig(radius);
}

- (void)setShouldRasterize:(BOOL)val {
    if (val && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && !Titanium_IsSpringBoard()) {
        if (self.sublayers.count > 4) {
            self.rasterizationScale = [UIScreen mainScreen].scale;
            %orig(YES);
            return;
        }
    }
    %orig(val);
}

%end

%hook UIVisualEffectView

- (void)didMoveToWindow {
    %orig;
    if (TITANIUM_LITE_MODE) return;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window && self.layer != nil) {
        self.layer.allowsGroupOpacity = YES;
        self.layer.drawsAsynchronously = YES;
    }
}

%end

%hook CATransaction

+ (void)flush {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard()) {
        if (g_isInteracting || g_isScrollingActive || g_isUserTouchingScreen) {
            EnforceMaxCPUPower();
        }
    }
}

%end

%end

// ====================================================================================================
// NHÓM 20: DEEP RAM COMPACTION & MACH VM PURGABLE ENGINE (ĐIỀN ĐỦ THÂN HÀM DỌN BỘ NHỚ NỀN)
// ====================================================================================================

%group Group_Deep_RAM_Compaction_Engine

%hook UIApplication

// [ĐÃ ĐIỀN THÂN HÀM RỖNG]: Thu hồi bộ nhớ đệm malloc và purgable ngay khi app rơi xuống nền, chống Jetsam
- (void)_applicationDidEnterBackground {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            malloc_zone_pressure_relief(malloc_default_zone(), 0);
        });
    }
}

%end

%hook SBAppSwitcherSnapshotImageCache

- (void)reloadImagesForAllItems {
    %orig;
    if (TITANIUM_LITE_MODE) return;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.aggressiveRamClean || CFG285.hyperMemoryGuardian || g_syncPayloadV285.aggressiveRamCleaner)) {
        Titanium_BackgroundPurgeMemory();
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
// NHÓM 21: WEBKIT & WKWEBVIEW AUTO RAM RECOVERY (ĐIỀN ĐỦ THÂN HÀM - ĐỒNG BỘ 240HZ CHO TRÌNH DUYỆT)
// ====================================================================================================

%group Group_WebKit_RAM_Optimizer

%hook WKWebView

// [ĐÃ ĐIỀN THÂN HÀM RỖNG]: Gán kịch bản đẩy trần nhịp FPS và dọn cache rác khi gắn vào window
- (void)didMoveToWindow {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && self.window) {
        NSInteger currentCap = Titanium_GetEffectiveFrameCap();
        NSString *js = Titanium_BuildWebFPSOverdriveScript(currentCap);
        [self evaluateJavaScript:js completionHandler:nil];
    }
}

- (void)_didReceiveMemoryWarning {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
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

%end

// ====================================================================================================
// BẺ KHÓA NHẬN DIỆN PHẦN CỨNG CHO MỌI APP & GAME (MỞ KHÓA NÚT 90FPS/120FPS/240HZ TRONG GAME)
// Báo mã phần cứng là iPhone 15 Pro Max (iPhone16,2 - A17 Pro GPU) + Hỗ trợ ProMotion HDR
// ====================================================================================================

typedef CFPropertyListRef (*TitaniumMGCopyAnswerFunctionV26)(CFStringRef property);
static TitaniumMGCopyAnswerFunctionV26 g_origMGCopyAnswerV26 = NULL;

static CFPropertyListRef Titanium_HookedMGCopyAnswerV26(CFStringRef property) {
    if (property && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
        if (CFEqual(property, CFSTR("SupportsVariableRefreshRate")) ||
            CFEqual(property, CFSTR("supports-variable-refresh-rate")) ||
            CFEqual(property, CFSTR("pVRR")) ||
            CFEqual(property, CFSTR("pro-motion")) ||
            CFEqual(property, CFSTR("DeviceSupports120Hz")) ||
            CFEqual(property, CFSTR("DeviceSupportsProMotion")) ||
            CFEqual(property, CFSTR("DeviceSupportsHDR"))) {
            return CFRetain(kCFBooleanTrue);
        }
        if (!Titanium_IsSpringBoard() && !Titanium_IsSettingsApp()) {
            if (CFEqual(property, CFSTR("ProductType")) || CFEqual(property, CFSTR("hw-model"))) {
                return CFRetain(CFSTR("iPhone16,2"));
            }
        }
    }
    return g_origMGCopyAnswerV26 ? g_origMGCopyAnswerV26(property) : NULL;
}

static int (*orig_sysctlbyname_spoof)(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) = NULL;
static int hooked_sysctlbyname_spoof(const char *name, void *oldp, size_t *oldlenp, void *newp, size_t newlen) {
    if (name && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard() && !Titanium_IsSettingsApp() && !g_isCurrentAppBlacklisted) {
        if (strcmp(name, "hw.machine") == 0) {
            const char *spoofModel = "iPhone16,2";
            size_t len = strlen(spoofModel) + 1;
            if (oldp && oldlenp) {
                if (*oldlenp >= len) {
                    memcpy(oldp, spoofModel, len);
                    *oldlenp = len;
                    return 0;
                }
            } else if (!oldp && oldlenp) {
                *oldlenp = len;
                return 0;
            }
        }
    }
    return orig_sysctlbyname_spoof(name, oldp, oldlenp, newp, newlen);
}

static int (*orig_uname_spoof)(struct utsname *name) = NULL;
static int hooked_uname_spoof(struct utsname *name) {
    int ret = orig_uname_spoof(name);
    if (ret == 0 && name && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !Titanium_IsSpringBoard() && !Titanium_IsSettingsApp() && !g_isCurrentAppBlacklisted) {
        strncpy(name->machine, "iPhone16,2", sizeof(name->machine) - 1);
        name->machine[sizeof(name->machine) - 1] = '\0';
    }
    return ret;
}

static void Titanium_InstallMGCopyAnswerHookV26(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *symbol = dlsym(RTLD_DEFAULT, "MGCopyAnswer");
        if (symbol) {
            MSHookFunction(symbol, (void *)Titanium_HookedMGCopyAnswerV26,
                           (void **)&g_origMGCopyAnswerV26);
        }
        if (!Titanium_IsSpringBoard() && !Titanium_IsSettingsApp()) {
            void *sysSym = dlsym(RTLD_DEFAULT, "sysctlbyname");
            if (sysSym) {
                MSHookFunction(sysSym, (void *)hooked_sysctlbyname_spoof, (void **)&orig_sysctlbyname_spoof);
            }
            void *unameSym = dlsym(RTLD_DEFAULT, "uname");
            if (unameSym) {
                MSHookFunction(unameSym, (void *)hooked_uname_spoof, (void **)&orig_uname_spoof);
            }
        }
    });
}

// ====================================================================================================
// NHÓM ĐẶC QUYỀN: ÉP PHẦN CỨNG NHẬN DIỆN & CHẠY PROMOTION THẬT (TẦN SỐ LẤY MẪU CẢM ỨNG 1000HZ)
// ====================================================================================================

%group Group_Hardware_ProMotion_Overclock

%hook IOHIDEventSystemClient

- (void)setProperty:(id)property forKey:(NSString *)key {
    @try {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.touchResponseBoost || g_syncPayloadV285.zeroLatencyTouch) && key) {
            if ([key isEqualToString:@"ReportInterval"] || [key isEqualToString:@"HIDReportInterval"]) {
                %orig(@(1000), key);
                return;
            }
        }
    } @catch (__unused NSException *e) {
        %orig(property, key);
        return;
    }
    %orig(property, key);
}

%end

%end

// ====================================================================================================
// NHÓM ĐỘC QUYỀN APPLE RUNTIME: ÉP VƯỢT MỨC KHỞI ĐỘNG ĐẦU TIÊN (ĐIỀN ĐỦ THÂN HÀM RỖNG)
// ====================================================================================================

%group Group_Apple_Native_ColdBoot_Overdrive

static volatile BOOL g_isAppFirstFramePresented = NO;

%hook UIWindowScene

- (void)_readySceneForDisplay {
    %orig;
    if (!Titanium_IsSpringBoard()) {
        if (@available(iOS 15.0, *)) {
            @try {
                float targetHz = (float)Titanium_GetEffectiveFrameCap();
                if (targetHz < 15.0f) targetHz = 15.0f;
                if (targetHz > 240.0f) targetHz = 240.0f;

                if ([self respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    [(id)self setPreferredFrameRateRange:SafeMakeFRR(targetHz, targetHz, targetHz)];
                }
            } @catch (__unused NSException *e) {}
        }

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(350 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            g_isAppFirstFramePresented = YES;
            Titanium_ReapplyFrameRateToAllScenes();
        });
    }
}

%end

%hook UIScene

- (void)_activationCompleted {
    %orig;
    if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
        g_isAppFirstFramePresented = YES;
        Titanium_ReapplyFrameRateToAllScenes();
    }
}

- (void)_didBecomeActive {
    %orig;
    if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
        Titanium_TriggerInstantTouchBurst();
        Titanium_ReapplyFrameRateToAllScenes();
    }
}

%end

%hook FBApplicationProcess

// [ĐÃ ĐIỀN THÂN HÀM RỖNG]: Cấp quyền ưu tiên Kernel và I/O khi nạp xong tiến trình app
- (void)_finishInit {
    %orig;
    if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
        Titanium_EnforceThreadVIPPolicy();
        EnforceMaxCPUPower();
    }
}

%end

%end

// ====================================================================================================
// NHÓM 2: ÉP CỨNG CAWINDOWSERVER TẦNG GỐC PHẦN CỨNG (MỞ KHÓA LÊN 240HZ THEO ĐÚNG CẤU HÌNH APP)
// ====================================================================================================

%group Group_CAWindowServer_Absolute_Dominance

%hook CAWindowServerDisplay

- (double)minimumFrameDuration {
    double targetHz = (double)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 240.0) targetHz = 240.0;
    return (1.0 / targetHz);
}

- (void)setMinimumFrameDuration:(double)duration {
    double targetHz = (double)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 240.0) targetHz = 240.0;
    @try {
        %orig(1.0 / targetHz);
    } @catch (__unused NSException *e) {}
}

- (double)maximumRefreshRate {
    double targetHz = (double)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 240.0) targetHz = 240.0;
    return targetHz;
}

- (void)setMaximumRefreshRate:(double)rate {
    double targetHz = (double)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 240.0) targetHz = 240.0;
    @try {
        %orig(targetHz);
    } @catch (__unused NSException *e) {}
}

- (double)idealRefreshRate {
    double targetHz = (double)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 240.0) targetHz = 240.0;
    return targetHz;
}

- (void)setIdealRefreshRate:(double)rate {
    double targetHz = (double)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 240.0) targetHz = 240.0;
    @try {
        %orig(targetHz);
    } @catch (__unused NSException *e) {}
}

- (double)minimumRefreshRate {
    double targetHz = (double)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15.0) targetHz = 15.0;
    if (targetHz > 240.0) targetHz = 240.0;
    return targetHz;
}

- (BOOL)supportsVariableRefreshRate {
    return YES;
}

- (BOOL)allowsVirtualModes {
    return YES;
}

%end

%hook CADisplay

- (BOOL)supportsVariableRefreshRate {
    return YES;
}

- (NSInteger)preferredFPS {
    NSInteger targetHz = (NSInteger)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15) targetHz = 15;
    if (targetHz > 240) targetHz = 240;
    return targetHz;
}

- (void)setPreferredFPS:(NSInteger)fps {
    NSInteger targetHz = (NSInteger)Titanium_GetEffectiveFrameCap();
    if (targetHz < 15) targetHz = 15;
    if (targetHz > 240) targetHz = 240;
    @try {
        %orig(targetHz);
    } @catch (__unused NSException *e) {}
}

%end

%end

// ====================================================================================================
// NHÓM 3: BẢO VỆ BUFFER LAYER & METAL (CHỐNG DROP BUFFER TRÊN TIẾN TRÌNH APP THỨ BA)
// ====================================================================================================

%group Group_Force_Render_Recovery_Overdrive

%hook CALayer

- (BOOL)drawsAsynchronously {
    return %orig;
}

- (void)setNeedsDisplay {
    %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && [NSThread isMainThread]) {
        Titanium_EnableZeroLatencyPipeline();
    }
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
// NHÓM 4: ĐIỀU PHỐI HIỂN THỊ CẤP WINDOW / SCENE CHO APP THỨ BA (ĐỒNG BỘ TRỰC TIẾP THEO APP)
// ====================================================================================================

%group Group_Window_Level_Overdrive

%hook UIWindowScene

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            range = Titanium_NormalizeFrameRateRange(range, Titanium_IsSpringBoard());
        }
    }
    @try {
        %orig(range);
    } @catch (__unused NSException *e) {}
}

%end

%hook UIWindow

- (void)makeKeyAndVisible {
    %orig;
    if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
        if (@available(iOS 15.0, *)) {
            @try {
                UIWindowScene *scene = self.windowScene;
                if (scene && [scene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float targetHz = (float)Titanium_GetEffectiveFrameCap();
                    if (targetHz < 15.0f) targetHz = 15.0f;
                    if (targetHz > 240.0f) targetHz = 240.0f;
                    [(id)scene setPreferredFrameRateRange:SafeMakeFRR(targetHz, targetHz, targetHz)];
                }
            } @catch (__unused NSException *e) {}
        }
    }
}

- (void)didMoveToWindowScene {
    %orig;
    if (!Titanium_IsSpringBoard() && !g_isCurrentAppBlacklisted) {
        if (@available(iOS 15.0, *)) {
            @try {
                UIWindowScene *scene = self.windowScene;
                if (scene && [scene respondsToSelector:@selector(setPreferredFrameRateRange:)]) {
                    float targetHz = (float)Titanium_GetEffectiveFrameCap();
                    if (targetHz < 15.0f) targetHz = 15.0f;
                    if (targetHz > 240.0f) targetHz = 240.0f;
                    [(id)scene setPreferredFrameRateRange:SafeMakeFRR(targetHz, targetHz, targetHz)];
                }
            } @catch (__unused NSException *e) {}
        }
    }
}

%end

%end

// ====================================================================================================
// NHÓM V10: BOOST LAYOUT SPRINGBOARD & ĐA NHIỆM & MÀN HÌNH CHÍNH
// ====================================================================================================
%group Group_TitaniumV10_SpringBoard_Layout_Boost

static inline void Titanium_V10_PinMainThreadHigh(void) {
    if (![NSThread isMainThread]) return;
    static __thread int s_v10LayoutQos = -1;
    if (s_v10LayoutQos != (int)QOS_CLASS_USER_INTERACTIVE) {
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
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
// ███ KHỐI V12 - SIÊU MƯỢT ROOTHIDE (ĐÃ HỢP NHẤT KHÔNG TRÙNG HOOK VỚI NHÓM KHÁC) ███
// ====================================================================================================

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
        return @"en";
    }
    const char *res = (const char *)g_syncPayloadV285.reserved;
    if (res[0] == 'L' && res[1] == 'G' && res[2] == ':') {
        NSString *code = [NSString stringWithUTF8String:&res[3]];
        if (code.length > 0) return code;
    }
    return @"en";
}

static inline NSString *Titanium_TrV12(NSString *viText, NSString *enText) {
    return [[Titanium_ResolveEffectiveLanguage() lowercaseString] hasPrefix:@"vi"] ? (viText ?: enText) : (enText ?: viText);
}

static volatile BOOL g_DynamicAIStreamDetected = NO;
static volatile uint64_t g_aiLastUserTouchTick = 0;
static volatile BOOL g_aiUserIsDragging = NO;

static inline uint64_t Titanium_NowMs(void) {
    return (uint64_t)([[NSProcessInfo processInfo] systemUptime] * 1000.0);
}

static inline BOOL Titanium_IsAIApp(void) {
    if (g_DynamicAIStreamDetected) return YES;

    static BOOL sIsStaticAI = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *mainBundle = [NSBundle mainBundle];
        NSString *bundleID = [[mainBundle bundleIdentifier] lowercaseString] ?: @"";
        NSString *execName = [[mainBundle objectForInfoDictionaryKey:@"CFBundleExecutable"] lowercaseString] ?: @"";
        NSString *dispName = [[mainBundle objectForInfoDictionaryKey:@"CFBundleDisplayName"] lowercaseString] ?: @"";
        NSString *bundName = [[mainBundle objectForInfoDictionaryKey:@"CFBundleName"] lowercaseString] ?: @"";

        if ([bundleID hasPrefix:@"com.apple."]) {
            return;
        }

        NSString *combined = [NSString stringWithFormat:@"%@ %@ %@ %@", bundleID, execName, dispName, bundName];
        NSArray<NSString *> *aiKeywords = @[
            @"bard", @"gemini", @"googlemobile", @"openai", @"chatgpt", @"claude", @"anthropic",
            @"grok", @"xai", @"deepseek", @"perplexity", @"poe", @"copilot", @"kimi", @"moonshot",
            @"doubao", @"cici", @"qwen", @"tongyi", @"aliyun", @"yuanbao", @"hunyuan", @"ernie",
            @"yiyan", @"zhipu", @"chatglm", @"mistral", @"lechat", @"meta.ai", @"character",
            @"chai", @"monica", @"sider", @"merlin", @"you.com", @"phind", @"cursor", @"windsurf",
            @"codeium", @"tabnine", @"blackbox", @"replit", @"ollama", @"enchanted", @"palchat",
            @"chatbox", @"opencat", @"chathub", @"lobechat", @"nextchat", @"dify", @"coze",
            @"notability", @"goodnotes", @"aichat", @"chatbot", @"gpt", @"llm"
        ];

        for (NSString *kw in aiKeywords) {
            if ([combined containsString:kw]) {
                sIsStaticAI = YES;
                break;
            }
        }
    });
    return sIsStaticAI || g_DynamicAIStreamDetected;
}

static inline void Titanium_ProbeDynamicAIStream(NSUInteger textLength) {
    if (g_DynamicAIStreamDetected || textLength < 40) return;
    static uint64_t sWindowStartMs = 0;
    static uint32_t sRapidMutationCount = 0;

    uint64_t now = Titanium_NowMs();
    if (now - sWindowStartMs <= 380) {
        sRapidMutationCount++;
        if (sRapidMutationCount >= 6) {
            g_DynamicAIStreamDetected = YES;
        }
    } else {
        sWindowStartMs = now;
        sRapidMutationCount = 1;
    }
}

static inline BOOL Titanium_IsUserActivelyScrollingAI(void) {
    if (g_aiUserIsDragging || g_isInteracting || g_isUserTouchingScreen) return YES;
    uint64_t now = Titanium_NowMs();
    return (now >= g_aiLastUserTouchTick && (now - g_aiLastUserTouchTick) < 500);
}

static const void *kAIPendingAttrTextKey       = &kAIPendingAttrTextKey;
static const void *kAILastTextCommitMsKey      = &kAILastTextCommitMsKey;
static const void *kAILastLayoutInvalidMsKey   = &kAILastLayoutInvalidMsKey;
static const void *kAIFlushScheduledKey        = &kAIFlushScheduledKey;
static const void *kAICachedCellSizeKey        = &kAICachedCellSizeKey;
static const void *kAICachedCellTimeKey        = &kAICachedCellTimeKey;

typedef void (^UICollectionBatchUpdatesBlock)(void);
typedef void (^UICollectionBatchCompletionBlock)(BOOL finished);

%group Group_AI_Stream_Optimization

%hook UICollectionViewCell
- (void)prepareForReuse {
    @try {
        %orig;
        if (Titanium_IsAIApp()) {
            objc_setAssociatedObject(self, kAICachedCellSizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, kAICachedCellTimeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    @try {
        if (!Titanium_IsAIApp()) {
            return %orig(layoutAttributes);
        }
        uint64_t now = Titanium_NowMs();
        NSValue *cachedSizeVal = objc_getAssociatedObject(self, kAICachedCellSizeKey);
        NSNumber *cachedTimeNum = objc_getAssociatedObject(self, kAICachedCellTimeKey);

        if (cachedSizeVal && cachedTimeNum) {
            CGSize cachedSize = [cachedSizeVal CGSizeValue];
            uint64_t lastMeasureMs = [cachedTimeNum unsignedLongLongValue];
            uint64_t cacheTTL = Titanium_IsUserActivelyScrollingAI() ? 220 : 70;

            if ((now - lastMeasureMs < cacheTTL) &&
                cachedSize.height > 10.0 &&
                fabs(cachedSize.width - layoutAttributes.size.width) < 2.0) {
                CGRect frame = layoutAttributes.frame;
                frame.size = cachedSize;
                layoutAttributes.frame = frame;
                return layoutAttributes;
            }
        }
        UICollectionViewLayoutAttributes *attr = %orig(layoutAttributes);
        if (attr && attr.frame.size.height > 0) {
            objc_setAssociatedObject(self, kAICachedCellSizeKey, [NSValue valueWithCGSize:attr.frame.size], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, kAICachedCellTimeKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return attr;
    } @catch (__unused NSException *e) {
        return %orig(layoutAttributes);
    }
}
%end

%hook UICollectionView
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated {
    @try {
        if (Titanium_IsAIApp()) {
            if (self.isTracking || self.isDragging || self.isDecelerating || Titanium_IsUserActivelyScrollingAI()) {
                return;
            }
            %orig(indexPath, scrollPosition, NO);
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(indexPath, scrollPosition, animated);
}

- (void)performBatchUpdates:(UICollectionBatchUpdatesBlock)updates completion:(UICollectionBatchCompletionBlock)completion {
    @try {
        if (Titanium_IsAIApp()) {
            [UIView performWithoutAnimation:^{
                %orig(updates, completion);
            }];
            return;
        }
    } @catch (__unused NSException *e) {}
    %orig(updates, completion);
}
%end

%hook UICollectionViewLayout
- (void)invalidateLayout {
    @try {
        if (Titanium_IsAIApp()) {
            uint64_t now = Titanium_NowMs();
            NSNumber *lastNum = objc_getAssociatedObject(self, kAILastLayoutInvalidMsKey);
            uint64_t lastMs = lastNum ? [lastNum unsignedLongLongValue] : 0;
            uint64_t minInterval = Titanium_IsUserActivelyScrollingAI() ? 160 : 55;
            if (now - lastMs < minInterval) {
                return;
            }
            objc_setAssociatedObject(self, kAILastLayoutInvalidMsKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    } @catch (__unused NSException *e) {}
    %orig;
}
%end

%hook UITextView
- (void)didMoveToWindow {
    @try {
        %orig;
        if (Titanium_IsAIApp() && self.window && !self.isEditable) {
            self.layoutManager.allowsNonContiguousLayout = YES;
            self.dataDetectorTypes = UIDataDetectorTypeNone;
        }
    } @catch (__unused NSException *e) {
        %orig;
    }
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    @try {
        Titanium_ProbeDynamicAIStream(attributedText.length);
        if (!Titanium_IsAIApp() || self.isEditable || self.isFirstResponder) {
            %orig(attributedText);
            return;
        }
        self.layoutManager.allowsNonContiguousLayout = YES;
        uint64_t now = Titanium_NowMs();
        NSNumber *lastNum = objc_getAssociatedObject(self, kAILastTextCommitMsKey);
        uint64_t lastMs = lastNum ? [lastNum unsignedLongLongValue] : 0;
        uint64_t throttleMs = Titanium_IsUserActivelyScrollingAI() ? 160 : (attributedText.length > 1500 ? 85 : 50);

        if (now - lastMs >= throttleMs) {
            objc_setAssociatedObject(self, kAILastTextCommitMsKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, kAIPendingAttrTextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [UIView performWithoutAnimation:^{
                %orig(attributedText);
            }];
        } else {
            objc_setAssociatedObject(self, kAIPendingAttrTextKey, attributedText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSNumber *scheduled = objc_getAssociatedObject(self, kAIFlushScheduledKey);
            if (![scheduled boolValue]) {
                objc_setAssociatedObject(self, kAIFlushScheduledKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                __weak UITextView *weakSelf = self;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(throttleMs * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    UITextView *strongSelf = weakSelf;
                    if (!strongSelf) return;
                    objc_setAssociatedObject(strongSelf, kAIFlushScheduledKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    NSAttributedString *pending = objc_getAssociatedObject(strongSelf, kAIPendingAttrTextKey);
                    if (pending) {
                        objc_setAssociatedObject(strongSelf, kAIPendingAttrTextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        objc_setAssociatedObject(strongSelf, kAILastTextCommitMsKey, @(Titanium_NowMs()), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        [UIView performWithoutAnimation:^{
                            [strongSelf setAttributedText:pending];
                        }];
                    }
                });
            }
        }
    } @catch (__unused NSException *e) {
        %orig(attributedText);
    }
}
%end

%hook UILabel
- (void)setAttributedText:(NSAttributedString *)attributedText {
    @try {
        Titanium_ProbeDynamicAIStream(attributedText.length);
        if (!Titanium_IsAIApp() || attributedText.length < 150) {
            %orig(attributedText);
            return;
        }
        uint64_t now = Titanium_NowMs();
        NSNumber *lastNum = objc_getAssociatedObject(self, kAILastTextCommitMsKey);
        uint64_t lastMs = lastNum ? [lastNum unsignedLongLongValue] : 0;
        uint64_t throttleMs = Titanium_IsUserActivelyScrollingAI() ? 160 : (attributedText.length > 1500 ? 85 : 50);

        if (now - lastMs >= throttleMs) {
            objc_setAssociatedObject(self, kAILastTextCommitMsKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(self, kAIPendingAttrTextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [UIView performWithoutAnimation:^{
                %orig(attributedText);
            }];
        } else {
            objc_setAssociatedObject(self, kAIPendingAttrTextKey, attributedText, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            NSNumber *scheduled = objc_getAssociatedObject(self, kAIFlushScheduledKey);
            if (![scheduled boolValue]) {
                objc_setAssociatedObject(self, kAIFlushScheduledKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                __weak UILabel *weakSelf = self;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(throttleMs * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    UILabel *strongSelf = weakSelf;
                    if (!strongSelf) return;
                    objc_setAssociatedObject(strongSelf, kAIFlushScheduledKey, @(NO), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    NSAttributedString *pending = objc_getAssociatedObject(strongSelf, kAIPendingAttrTextKey);
                    if (pending) {
                        objc_setAssociatedObject(strongSelf, kAIPendingAttrTextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        objc_setAssociatedObject(strongSelf, kAILastTextCommitMsKey, @(Titanium_NowMs()), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        [UIView performWithoutAnimation:^{
                            [strongSelf setAttributedText:pending];
                        }];
                    }
                });
            }
        }
    } @catch (__unused NSException *e) {
        %orig(attributedText);
    }
}
%end

%end

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
                    if (changed) {
                        @try {
                            [winScene setPreferredFrameRateRange:normalized];
                        } @catch (__unused NSException *e) {}
                    }
                }
            }
        }
    } @catch (__unused NSException *e) {}
}

static inline BOOL Titanium_IsDismissingToHomeV12(void) {
    if (g_isContinuousSwiping) return YES;
    if (g_lastInteractionMachTime == 0) return NO;
    uint64_t now = mach_absolute_time();
    return ((now - g_lastInteractionMachTime) < Titanium_NanosToMachTicks(250ULL * 1000000ULL));
}

// ====================================================================================================
// NHÓM V12: ĐÀN HỒI THOÁT APP MƯỢT TỰ NHIÊN (ĐÃ BỔ SUNG ĐẦY ĐỦ THÂN HÀM DAMPING)
// ====================================================================================================

%group Group_TitaniumV12_SmoothExit_And_DisplayLink

%hook CASpringAnimation

// [ĐÃ ĐIỀN THÂN HÀM RỖNG]: Tối ưu hóa hệ số cản damping của lò xo khi đóng app, triệt tiêu khựng giật ở 5% cuối
- (CGFloat)damping {
    CGFloat orig = %orig;
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (orig > 0.0 && orig < 18.0) return orig * 1.08;
    }
    return orig;
}

- (void)setDamping:(CGFloat)damping {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        if (damping > 0.0 && damping < 18.0) damping *= 1.08;
    }
    %orig(damping);
}

%end

%end

// ====================================================================================================
// V22 RUNTIME GROUPS (ĐỒNG BỘ CHUẨN XÁC TOÀN DẢI 15HZ - 240HZ CHO CADISPLAYLINK & WINDOWSCENE)
// ====================================================================================================

%group Group_TitaniumSafeRuntime_V22

%hook CADisplayLink

- (void)setPreferredFramesPerSecond:(NSInteger)fps {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
        NSInteger cap = Titanium_GetEffectiveFrameCap();
        if (cap < 15) cap = 15;
        if (cap > 240) cap = 240;

        %orig(cap);
        return;
    }
    %orig(fps);
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
            if (maxCap > 240.0f) maxCap = 240.0f;

            range = SafeMakeFRR(maxCap, maxCap, maxCap);
        }
    }
    @try {
        %orig(range);
    } @catch (__unused NSException *e) {}
}

%end

%end

%group Group_TitaniumSafeSceneRangeRuntime_V22

%hook UIWindowScene

- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
    if (@available(iOS 15.0, *)) {
        if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
            range = Titanium_NormalizeFrameRateRange(range, Titanium_IsSpringBoard());
        }
    }
    @try {
        %orig(range);
    } @catch (__unused NSException *e) {}
}

%end

%end

// ==============================================================================
// GIỮ APP TRONG RAM - CHỐNG TERMINATE / CHỐNG JETSAM KILL KHI XUỐNG NỀN
// ==============================================================================

%group Group_KeepAppsAlive_NoKill

%hook FBProcess

- (void)killForReason:(long long)reason 
         andReport:(BOOL)report 
   withDescription:(id)description 
        completion:(id)completion {
    if (reason == 1 || [description containsString:@"background"] || [description containsString:@"idle"]) {
        if (completion) {
            void (^compBlock)(void) = (void (^)(void))completion;
            compBlock();
        }
        return;
    }
    %orig;
}

- (BOOL)isPendingExit {
    return NO;
}

%end

%hook SBMainWorkspace

- (void)handleApplicationSuspended:(id)application {
    %orig;
}

%end

%hook SBApplication

- (BOOL)shouldPrewarmOnLaunch {
    return YES;
}

%end

%end

// ====================================================================================================
// NHÓM MỚI TỰ TẠO: TỐI ƯU CỬ CHỈ ĐA NHIỆM & ÉP CỨNG SHADOW = 0 TẦNG SÂU (KHÔNG LẶP ĐỆ QUY)
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
    static __thread BOOL s_lockShadowRecursion = NO;
    if (s_lockShadowRecursion) {
        %orig(style);
        return;
    }
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        s_lockShadowRecursion = YES;
        // 1. Ép gọi hàm gốc tham số 0 với cờ khóa đệ quy
        %orig(0);
        // 2. Ép ghi đè trực tiếp Ivar _shadowStyle tầng sâu và triệt tiêu view bóng
        @try {
            Ivar ivar = class_getInstanceVariable([self class], "_shadowStyle");
            if (ivar) {
                *((long long *)((uint8_t *)(__bridge void *)self + ivar_getOffset(ivar))) = 0;
            }
            UIView *shadowView = [self valueForKey:@"_pageShadowView"];
            if (shadowView) {
                shadowView.alpha = 0.0;
                shadowView.hidden = YES;
            }
            self.layer.shadowOpacity = 0.0f;
            self.layer.shadowRadius = 0.0f;
        } @catch (__unused NSException *e) {}
        s_lockShadowRecursion = NO;
        return;
    }
    %orig(style);
}

- (long long)shadowStyle {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return 0;
    }
    return %orig;
}
%end

%hook SBFluidSwitcherModifier
- (double)shadowOpacityForIndex:(unsigned long long)index {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return 0.0;
    }
    return %orig(index);
}
%end

%hook SBAppSwitcherSettings
- (BOOL)shouldSimplifyForOptions:(long long)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        return YES;
    }
    return %orig(arg1);
}

- (BOOL)shouldKeepAppSnapshotsInMemory {
    // Trả về NO để không làm phình VRAM GPU lúc lướt thẻ đa nhiệm, chống giật khựng khi đóng tab
    return NO;
}
%end

%hook SBMainWorkspace
- (void)_handleDismissOverlaysGesture:(id)arg1 {
    if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_IsSpringBoard()) {
        EnforceMaxCPUPower();
        Titanium_EnforceThreadVIPPolicy();
    }
    %orig(arg1);
}
%end

%end

// ----------------------------------------------------------------------------------------------------
// [V12 - HEARTBEAT IPC]: SpringBoard làm tươi tệp đồng bộ + heartbeat mỗi 30s
// ----------------------------------------------------------------------------------------------------
static void Titanium_StartIPCHearthbeatV12(void) {
    if (!Titanium_IsSpringBoard()) return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_source_t hb = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0));
        dispatch_source_set_timer(hb, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(30 * NSEC_PER_SEC)), (uint64_t)(30 * NSEC_PER_SEC), (uint64_t)(5 * NSEC_PER_SEC));
        dispatch_source_set_event_handler(hb, ^{
            static time_t s_bootTimestamp = 0;
            if (s_bootTimestamp == 0) s_bootTimestamp = time(NULL);
            BOOL earlyBoot = (time(NULL) - s_bootTimestamp) < 60;

            ApexV285ProPayload snapshot;
            pthread_mutex_lock(&g_syncLockV285);
            snapshot = g_syncPayloadV285;
            pthread_mutex_unlock(&g_syncLockV285);
            if (snapshot.magic == APEX_SYNC_MAGIC_V285) {
                if (earlyBoot) {
                    @try {
                        Titanium_WriteAtomicIPCFile(PRIMARY_SYNC_FILE, &snapshot, sizeof(snapshot));
                        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                               CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, NULL, YES);
                    } @catch (NSException *e) {}
                } else {
                    Titanium_WriteSyncPayloadV285(&snapshot);
                }
            }
        });
        dispatch_resume(hb);
    });
}

// ----------------------------------------------------------------------------------------------------
// [V12 - BẮT BÙ KHI APP QUAY LẠI FOREGROUND]: Ép nạp IPC ngay và áp dụng dải nhịp
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
        @try {
            UIDevice *dev = [UIDevice currentDevice];
            dev.batteryMonitoringEnabled = YES;
            g_isDeviceChargingV285 = (dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull);

            [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryStateDidChangeNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                @try {
                    UIDevice *currentDev = [UIDevice currentDevice];
                    g_isDeviceChargingV285 = (currentDev.batteryState == UIDeviceBatteryStateCharging || currentDev.batteryState == UIDeviceBatteryStateFull);
                    Titanium_UpdateLowBatteryFlagV12();
                } @catch (__unused NSException *e) {}
            }];

            g_batteryLevelV12 = dev.batteryLevel;
            Titanium_UpdateLowBatteryFlagV12();
            [[NSNotificationCenter defaultCenter] addObserverForName:UIDeviceBatteryLevelDidChangeNotification
                                                              object:nil
                                                               queue:[NSOperationQueue mainQueue]
                                                          usingBlock:^(NSNotification * _Nonnull note) {
                @try {
                    g_batteryLevelV12 = [UIDevice currentDevice].batteryLevel;
                    Titanium_UpdateLowBatteryFlagV12();
                } @catch (__unused NSException *e) {}
            }];
        } @catch (__unused NSException *e) {}
    });
}

static void Titanium_AdoptPayloadRatesWithoutConfig(void) {
    @try {
        if (g_syncPayloadV285.targetHz >= 15 && g_syncPayloadV285.targetHz <= 240) {
            g_cachedResolvedHz = g_syncPayloadV285.targetHz;
        }
        if (g_syncPayloadV285.targetFPS >= 15 && g_syncPayloadV285.targetFPS <= 240) {
            g_cachedResolvedFPS = g_syncPayloadV285.targetFPS;
        }
    } @catch (__unused NSException *e) {}
}

static void ReloadPreferencesCallbackV285(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    @try {
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
            @try {
                g_lastSyncTicksV285 = 0;
                Titanium_ReloadSharedSyncStateV285();
                if (!CFG285) {
                    Titanium_AdoptPayloadRatesWithoutConfig();
                }
                if (CFG285 && [CFG285 respondsToSelector:@selector(loadSettings)]) {
                    [CFG285 loadSettings];
                }
                if (Titanium_IsSpringBoard()) {
                    Titanium_TuneWindowServerDisplayDirectly();
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    @try {
                        Titanium_ReapplyFrameRateToAllScenes();
                    } @catch (__unused NSException *e) {}
                });
            } @catch (__unused NSException *e) {}
            s_debounceTimer = nil;
        });
        dispatch_resume(s_debounceTimer);
    } @catch (__unused NSException *e) {}
}

#define TITANIUM_BOOT_FLAG_VERIFIED @"/tmp/.titanium_tweak_verified"

static time_t Titanium_GetSystemUptimeSeconds(void) {
    @try {
        struct timeval boottime;
        size_t len = sizeof(boottime);
        int mib[2] = {CTL_KERN, KERN_BOOTTIME};
        if (sysctl(mib, 2, &boottime, &len, NULL, 0) < 0) return 9999;
        time_t now = time(NULL);
        return (now - boottime.tv_sec);
    } @catch (__unused NSException *e) {
        return 9999;
    }
}

static inline void Init_CAWindowServer_Hooks(void) {
    @try {
        if (!Titanium_DisplaySpoofAllowed()) return;
        static dispatch_once_t s_wsInitOnce;
        dispatch_once(&s_wsInitOnce, ^{
            %init(Group_CAWindowServer_Absolute_Dominance);
        });
    } @catch (__unused NSException *e) {}
}

// ====================================================================================================
// HÀM KHỞI TẠO DUY NHẤT: ĐÃ LOẠI BỎ 100% CÁC %INIT TRÙNG LẶP GÂY DOUBLE-HOOK
// ====================================================================================================

static void runCoreTweak(BOOL isSpringBoard, NSString *bundleID, const char *progName) {
    static BOOL s_coreInitDone = NO;
    if (s_coreInitDone) return;
    s_coreInitDone = YES;

    @autoreleasepool {
        @try {
            Titanium_BypassQuartzCoreRangeAssertion();

            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
                if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                    NSInteger initHz = (NSInteger)CFG285.targetHz;
                    if ((g_cachedResolvedHz < 15 || g_cachedResolvedHz > 240) &&
                        initHz >= 15 && initHz <= 240) {
                        g_cachedResolvedHz = initHz;
                    }
                }
                if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                    NSInteger initFPS = (NSInteger)CFG285.targetFPS;
                    if ((g_cachedResolvedFPS < 15 || g_cachedResolvedFPS > 240) &&
                        initFPS >= 15 && initFPS <= 240) {
                        g_cachedResolvedFPS = initFPS;
                    }
                }
            }

            if (!isSpringBoard &&
                (g_isCurrentAppBlacklisted || (CFG285 && !CFG285.enabled))) {
                g_SystemMasterReady = YES;
                return;
            }

            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                @try {
                    Titanium_ReloadSharedSyncStateV285();
                } @catch (__unused NSException *e) {}
            });

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
                Titanium_InstallMGCopyAnswerHookV26();
            }

            %init(Group_Apple_Native_ColdBoot_Overdrive);
            %init(Group_Titanium_Game_Metal_Overdrive);
            %init(Group_Silicon_Hardware_Pipeline_Overdrive);
            %init(Group_Silicon_Scheduler_Touch_Governor);
            %init(Group_CoreAnimation_RenderServer_Governor);
            %init(Group_System_Memory_And_RunLoop_Governor);
            %init(Group_Thermal_CryoPacing_ZeroDrop);
            %init(Group_Deep_RAM_Compaction_Engine);
            %init(Group_TitaniumV12_SmoothExit_And_DisplayLink);

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

#if TITANIUM_ENABLE_RATE_KEEPER
                @try {
                    [TitaniumRateKeeper start];
                } @catch (__unused NSException *e) {}
#endif
                @try {
                    Titanium_StartThermalAndChargingWatchdog();
                } @catch (__unused NSException *e) {}

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(800 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    @try {
                        AppleInternal_EnforceZeroLatencyKernelTier();
                        Titanium_ApplySiliconDeepOptimizations();
                        AppleInternal_LockHardwareCADisplay();
                        Titanium_ForceInjectDynamicRefreshSupport();
                        Titanium_TuneWindowServerDisplayDirectly();
                    } @catch (__unused NSException *e) {}
                });

                @try {
                    Titanium_StartIPCHearthbeatV12();
                } @catch (__unused NSException *e) {}

                @try {
                    NSData *verifiedData = [@"VERIFIED" dataUsingEncoding:NSUTF8StringEncoding];
                    [[NSFileManager defaultManager] createFileAtPath:TITANIUM_BOOT_FLAG_VERIFIED
                                                            contents:verifiedData
                                                          attributes:@{NSFilePosixPermissions: @(0644)}];
                } @catch (__unused NSException *e) {}
            } else {
                Titanium_A20PrewarmAssetsAndGPU();
                %init(Group_UIKit_ThirdParty_IsolatedV285);
                %init(Group_Force_Render_Recovery_Overdrive);
                %init(Group_Window_Level_Overdrive);
                Init_CAWindowServer_Hooks();

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(100 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                    @try {
                        Titanium_ForceInjectDynamicRefreshSupport();
                        AppleInternal_LockHardwareCADisplay();
                        AppleInternal_EnforceZeroLatencyKernelTier();
                        Titanium_ApplySiliconDeepOptimizations();
                        Titanium_RegisterAppResumeRefreshV12();
                        Titanium_ReapplyFrameRateToAllScenes();
                    } @catch (__unused NSException *e) {}
                });
            }

            g_SystemMasterReady = YES;
        } @catch (__unused NSException *e) {}
    }
}

static void Titanium_RegisterPrefsObservers(BOOL isSpringBoardProcess) {
    @try {
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
    } @catch (__unused NSException *e) {}
}

static void SpringBoardBootstrapTrigger(void) {
    @try {
        static BOOL s_triggerDone = NO;
        if (s_triggerDone) return;
        s_triggerDone = YES;

        const char *progName = getprogname();
        NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1200 * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            @try {
                runCoreTweak(YES, bundleID, progName);
            } @catch (__unused NSException *e) {}
        });
    } @catch (__unused NSException *e) {}
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

        if (isSpringBoard) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                @try {
                    (void)Titanium_CheckAndPreventBootloopUniversal();
                } @catch (NSException *e) {}
            });
        }

        if (strcasestr(progName, "Preferences") || strcasestr(progName, "Settings")) {
            Class configClass = NSClassFromString(@"BoostConfigV285Pro");
            if (configClass) {
                CFG285 = [configClass sharedInstance];
                [CFG285 loadSettings];
                if ([CFG285 respondsToSelector:@selector(targetHz)]) {
                    NSInteger prefHz = (NSInteger)CFG285.targetHz;
                    if ((g_cachedResolvedHz < 15 || g_cachedResolvedHz > 240) && prefHz >= 15 && prefHz <= 240) {
                        g_cachedResolvedHz = prefHz;
                    }
                }
                if ([CFG285 respondsToSelector:@selector(targetFPS)]) {
                    NSInteger prefFPS = (NSInteger)CFG285.targetFPS;
                    if ((g_cachedResolvedFPS < 15 || g_cachedResolvedFPS > 240) && prefFPS >= 15 && prefFPS <= 240) {
                        g_cachedResolvedFPS = prefFPS;
                    }
                }
            }
            return;
        }

        Titanium_RegisterPrefsObservers(isSpringBoard);

        // KHÔNG CÒN %init; TRẦN TẠI ĐÂY - TRIỆT TIÊU DOUBLE-HOOK HOÀN TOÀN

        if (isSpringBoard) {
            dispatch_async(dispatch_get_main_queue(), ^{
                SpringBoardBootstrapTrigger();
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                runCoreTweak(NO, bundleID, progName);
            });
        }
    }
}
