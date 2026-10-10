// ====================================================================================================
// NHẬT KÝ SỬA LỖI (CHỈ SỬA ĐÚNG CHỖ, GIỮ NGUYÊN TOÀN BỘ PHẦN CÒN LẠI) - các chỗ sửa đều có nhãn [ĐÃ SỬA]
//  1. Đứng khung hình mức 0 khi không chạm: sàn dải tần 1Hz -> 60Hz (CADisplayLink / CAAnimation / CASpringAnimation),
//     CADisplay.minimumFPS 15 -> 60 trên máy 60Hz, không còn "nhả khóa ngay về 0" khi nhả tay / nhả nút âm lượng,
//     cờ Failed của pan gesture không còn xóa trạng thái chạm, kéo dài cửa sổ giữ nhịp sau khi nhả tay.
//  2. Đen app lúc mở: hook CALayer setNeedsDisplay từng NUỐT lệnh vẽ (800ms nhưng tính nhầm đơn vị => ~33 GIÂY trên A11).
//  3. Văng app trình duyệt / WebKit: không còn dùng WKWebView ở luồng nền và không còn capture self/pool vĩnh viễn.
//  5. Xám mãi / như nghẽn mạng: cùng nguyên nhân (2) + QoS luồng chính bị hạ sau mỗi CATransaction flush
//     + rasterize bị ép bật dù app tắt + getter maximumDrawableCount trả sai + NSRunLoop runMode sai kiểu trả về.
//  ĐỢT 2 (truy tìm tiếp lỗi 1 và 2 + công tắc tổng):
//  6. Màn hình KHÔNG có ProMotion (vd iPhone 8 Plus) chỉ quét tối đa 60Hz. Bản cũ vẫn "khai man" với hệ điều hành rằng máy hỗ trợ
//     VRR/ProMotion/dynamic refresh/144Hz (MobileGestalt, CADisplay, CAWindowServerDisplay, UIScreen). Hệ thống chuyển sang chính sách
//     hạ nhịp kiểu ProMotion mà tấm nền không có => hoạt ảnh đứng hẳn sau khi nhả tay cho tới khi chạm lại, app đen lúc mở.
//     Nay mặc định KHÔNG khai man trên máy không có ProMotion và không yêu cầu quá 60Hz. Muốn trả về hành vi cũ: định nghĩa
//     TITANIUM_SPOOF_DISPLAY_ON_60HZ_PANEL = 1.
//  7. Công tắc tổng / loại trừ app: nạp payload ngay (không còn trễ), app bị tắt trong tab App không còn nạp bất kỳ hook nào,
//     backboardd cũng đọc công tắc (trước đây luôn bị ép 144Hz), sửa lỗi đơn vị làm chặn nạp lại cấu hình tới ~10 giây.
//  8. Tắt mặc định: miễn nhiễm watchdog FrontBoard (có thể hủy assertion lúc mở app) và biến môi trường MTL_* (gây hình đen app Metal).
//  9. Bộ giữ nhịp (CADisplayLink giữ nhịp) cho SpringBoard: đã có mã nhưng MẶC ĐỊNH TẮT từ đợt 3 (cờ "đang cuộn" bị kẹt làm nó chạy mãi => nóng máy).
//  ĐỢT 3 (app có mạng không vào được / giật lag nóng máy / chỉnh Hz-FPS không có tác dụng):
// 10. App có mạng (video, ảnh, feed) xám/đen/văng: hook Metal ép MTLTextureDescriptor.allowGPUOptimizedContents = YES làm hỏng texture
//     IOSurface của video/ảnh (CoreVideo cần NO), và _MTLCommandQueue.executionEnabled = YES nói dối trạng thái hàng đợi GPU.
//     Nay MẶC ĐỊNH TẮT (TITANIUM_ENABLE_METAL_CONTRACT_OVERRIDES = 0). Hook WebKit không còn nạp vào app thứ ba (xem macro bên dưới).
// 11. Chỉnh Hz/FPS không có tác dụng: cờ ForceOverclock144Hz đã lưu từ lần chọn 144 vẫn ép CẢ Hz LẪN FPS về 144 dù bạn đã chọn thấp hơn,
//     và mọi hook ép trần tối thiểu 60. Nay chọn thấp hơn 144 là có hiệu lực, trần hiệu lực = giá trị THẤP HƠN giữa Hz và FPS
//     (có thể hạ tới 15 toàn hệ thống). Máy 60Hz không thể cao hơn 60 nên giá trị lớn hơn 60 được coi là 60.
// 12. Nóng máy / giật: tắt tắt V-Sync của CAMetalLayer trên tấm nền 60Hz (gây xé hình + GPU chạy hết công suất), tắt đặt Task QoS tier
//     (đánh thức CPU liên tục), cờ cử chỉ/cuộn/âm lượng bị kẹt nay tự hết hạn sau 2 giây, và khi máy thật sự nóng (Serious/Critical)
//     không còn nói dối "Nominal" để app tự giảm tải.
//  ĐỢT 4 (nghẽn mạng app mạng / lag vuốt + đa nhiệm + popup / nóng nhanh / bật tắt 15-144 không ăn toàn hệ thống / thiếu key):
// 13. NGHẼN MẠNG + NÓNG NHANH: nguyên nhân gốc là SPAM SYSCALL pthread_set_qos_class_self_np / setiopolicy_np trên luồng chính ở hầu hết
//     hook (NSRunLoop runMode, CATransaction flush, touch, scroll, chuyển cảnh...) gọi lại mỗi khung hình/mỗi sự kiện => CPU không nghỉ,
//     nóng máy, scheduler đói luồng mạng/socket nên app mạng nghẽn. Nay QoS USER_INTERACTIVE chỉ đặt MỘT lần mỗi luồng (macro bọc
//     pthread_set_qos_class_self_np), IOPolicy đĩa chỉ đặt MỘT lần mỗi luồng, và không kích xung khi đang phát video thụ động.
// 14. LAG VUỐT APP / ĐA NHIỆM / MÀN HÌNH CHÍNH / POPUP: ngoài (13), thêm hook MỚI: SBFluidSwitcherModifier shouldasyncRenderAppLayouts
//     (render bất đồng bộ bố cục thẻ đa nhiệm), SBAppSwitcherSettings shouldSimplifyForOptions (giảm tải GPU khi mở đa nhiệm),
//     UIScrollView _smoothScrollWithVelocity:targetContentOffset: (kích xung đúng lúc quán tính cuộn bắt đầu, không chờ hook chạm),
//     SBMainDisplaySceneLayoutViewController viewWillLayoutSubviews (giữ nhịp lúc layout màn hình chính) => dựng đồ họa nhanh, không ngắt quãng.
// 15. BẬT/TẮT & CHỈNH 15-144 KHÔNG ĂN TOÀN HỆ THỐNG: (a) các chỗ nạp cấu hình (runCoreTweak, nhánh Settings, callback reload) ĐÈ LẠI
//     g_cachedResolvedHz/FPS bằng giá trị THÔ CFG285.targetHz (bỏ qua cờ EnableHzControl/Enabled/tiết kiệm pin) => tắt công tắc vẫn 144;
//     nay bỏ hẳn các chỗ đè này (loadSettings đã tính đúng vào cache); (b) thêm hook UIWindowScene setPreferredFrameRateRange: kẹp
//     sàn/trần theo trần hiệu lực => MỌI scene/app bị kẹp theo đúng giá trị chỉnh trong app tweak; (c) backboardd/app nhận payload mới
//     là cập nhật cache ngay qua callback sẵn có.
// 16. THIẾU KEY LIÊN KẾT APP: bổ sung alias key khi đọc cấu hình: MasterEnabled/IsEnabled, EnableHz/HzControlEnabled,
//     EnableFPS/FPSControlEnabled, TargetHz/RefreshRate/HzRate, TargetFPS/FPSRate/FrameRate (đọc key gốc trước, alias sau).
// ====================================================================================================
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
// [ĐÃ SỬA - ĐỢT 4]: CHỐNG SPAM SYSCALL QoS LUỒNG (NGUYÊN NHÂN NÓNG MÁY + NGHẼN CPU => LAG MẠNG & LAG UI)
// pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE) được gọi lại ở HẦU KHÉT hook trên mỗi sự kiện/mỗi khung hình.
// Mỗi lần gọi là một syscall xuống XNU; hàng nghìn lần/giây làm CPU không nghỉ, nóng máy, đói luồng mạng/socket.
// Nay bọc lại: QoS USER_INTERACTIVE chỉ đặt MỘT lần cho mỗi luồng (QoS khác - vd hạ về DEFAULT khi bật macro - vẫn đi thẳng).
// ====================================================================================================
static inline int Titanium_RealSetQoSClassSelf(pthread_qos_class_t qos, int relative) {
return pthread_set_qos_class_self_np(qos, relative);
}
static inline int Titanium_SetQoSClassSelfCoalesced(pthread_qos_class_t qos, int relative) {
if (qos == QOS_CLASS_USER_INTERACTIVE) {
static __thread int s_uiQoSApplied = 0;
if (s_uiQoSApplied) return 0;
s_uiQoSApplied = 1;
return Titanium_RealSetQoSClassSelf(qos, relative);
}
return Titanium_RealSetQoSClassSelf(qos, relative);
}
#define pthread_set_qos_class_self_np(q, r) Titanium_SetQoSClassSelfCoalesced((q), (r))
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
- (void)killForReason:(long long)reason andReport:(BOOL)report withDescription:(NSString *)description completion:(id)completion;
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
- (BOOL)attemptUnlockWithPasscode:(NSString *)passcode finishUIUnlock:(BOOL)finish;
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
// [ĐÃ SỬA - ĐỢT 4]: IOPolicy đĩa chỉ đặt MỘT lần mỗi luồng (trước đây gọi lại trên mỗi lần khóa nhịp => spam syscall)
static __thread int s_ioPolicyApplied = 0;
if (!s_ioPolicyApplied) {
s_ioPolicyApplied = 1;
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
// [ĐÃ BỔ SUNG - CÔNG TẮC TỔNG / LOẠI TRỪ APP]: SpringBoard đọc được plist cấu hình nên ghi danh sách bundle ID bị TẮT ra tệp văn bản
// (mỗi dòng một ID). App thứ ba trong sandbox đọc tệp này để biết mình có bị loại trừ hay không.
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
if (data.length > 0) {
write(fd, data.bytes, data.length);
}
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
// [ĐÃ SỬA - ĐỢT 4 - THIẾU KEY LIÊN KẾT APP]: đọc thêm các KEY ALIAS mà app tweak có thể ghi (key gốc vẫn ưu tiên trước).
BOOL (^GetLiveBoolMulti)(NSArray *, BOOL) = ^BOOL(NSArray *keys, BOOL d) {
for (NSString *k in keys) {
if (diskDict && diskDict[k] != nil) return [diskDict[k] boolValue];
CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
if (val) {
BOOL b = CFBooleanGetValue((CFBooleanRef)val);
CFRelease(val);
return b;
}
}
return d;
};
NSInteger (^GetLiveIntMulti)(NSArray *, NSInteger) = ^NSInteger(NSArray *keys, NSInteger d) {
for (NSString *k in keys) {
if (diskDict && diskDict[k] != nil) return [diskDict[k] integerValue];
CFPropertyListRef val = CFPreferencesCopyAppValue((__bridge CFStringRef)k, PREF_DOMAIN);
if (val) {
int n = 0;
CFNumberGetValue((CFNumberRef)val, kCFNumberIntType, &n);
CFRelease(val);
return (NSInteger)n;
}
}
return d;
};
self.enabled = GetLiveBoolMulti((@[@"Enabled", @"MasterEnabled", @"IsEnabled"]), YES);
self.selectedLanguage = GetLiveString(@"SelectedLanguage", @"auto");
self.enableHzControl = GetLiveBoolMulti((@[@"EnableHzControl", @"EnableHz", @"HzControlEnabled"]), YES);
self.targetHz = GetLiveIntMulti((@[@"TargetRefreshRate", @"TargetHz", @"RefreshRate", @"HzRate"]), 144);
self.enableFPSControl = GetLiveBoolMulti((@[@"EnableFPSControl", @"EnableFPS", @"FPSControlEnabled"]), YES);
self.targetFPS = GetLiveIntMulti((@[@"TargetFPSRate", @"TargetFPS", @"FPSRate", @"FrameRate"]), 144);
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
p.updateSeq = (uint64_t)mach_absolute_time();
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
static inline BOOL Titanium_ShouldLockTargetRate(void) {
// Giữ target rate CHỈ khi còn trạng thái tương tác; thả ra thì bỏ khóa ngay.
if (g_isRateLockedV285) return YES;
// [ĐÃ SỬA - CHỐNG CỜ KẸT]: các cờ chạm/vuốt/cuộn/âm lượng chỉ được xóa khi nhả tay; nhưng cuộn quán tính còn đặt lại cờ "đang cuộn" SAU khi
// nhả tay nên cờ kẹt YES mãi => khóa nhịp vĩnh viễn (nóng máy, CPU không nghỉ). Quá 2 giây không có tương tác nào thì tự xả cờ.
if (g_isVolumeHoldingV285 || g_isUserTouchingScreen || g_isContinuousSwiping || g_isScrollingActive) {
static uint64_t s_staleFlagTicks = 0;
if (s_staleFlagTicks == 0) {
s_staleFlagTicks = Titanium_NanosToMachTicks(2000000000ULL);
}
uint64_t nowFlag = mach_absolute_time();
if (g_lastInteractionMachTime == 0 || (nowFlag - g_lastInteractionMachTime) < s_staleFlagTicks) {
return YES;
}
g_isVolumeHoldingV285 = NO;
g_isUserTouchingScreen = NO;
g_isContinuousSwiping = NO;
g_isScrollingActive = NO;
}
// 2. Có banner thông báo đang hoạt động
if (g_isNotificationBannerActive || Titanium_IsNotificationBannerActive()) return YES;
// 3. Có hoạt ảnh chuyển cảnh (TIMEOUT BẢO VỆ: Chống kẹt cờ làm nóng máy & tụt xung)
// [ĐÃ SỬA]: (a) 1.2s được quy đổi sang Mach ticks chuẩn (bản cũ so sánh ticks với nano-giây => thực tế ~50 giây trên A11).
//           (b) Reset mốc khi bộ đếm về 0; bản cũ giữ mốc cũ nên lần hoạt ảnh kế tiếp bị hủy ngay (mất khóa nhịp giữa chừng).
static uint64_t s_animStartTick = 0;
if (g_activeAnimationCount > 0) {
uint64_t nowTick = mach_absolute_time();
if (s_animStartTick == 0) {
s_animStartTick = nowTick;
return YES;
} else if ((nowTick - s_animStartTick) < Titanium_NanosToMachTicks(1200000000ULL)) { // Giới hạn tối đa 1.2s
return YES;
} else {
g_activeAnimationCount = 0;
s_animStartTick = 0;
}
} else {
s_animStartTick = 0;
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
pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
// [ĐÃ SỬA - ĐỢT 4]: IOPolicy đĩa chỉ đặt MỘT lần mỗi luồng (bản cũ đặt lại trên mỗi lần khóa nhịp => spam syscall nóng máy)
static __thread int s_ioBoostedOnce = 0;
if (!s_ioBoostedOnce) {
s_ioBoostedOnce = 1;
setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
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
// [ĐÃ SỬA - ĐỢT 4 - NGHẼN MẠNG]: đang phát video/stream thụ động thì KHÔNG kích xung thêm (CPU/GPU tranh chấp với luồng
// giải mã & luồng mạng => khựng mạng). Chỉ kích khi người dùng thật sự tương tác.
if (Titanium_IsPassiveVideoPlayback()) return;
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
// [ĐÃ SỬA]: tắt V-Sync trên tấm nền 60Hz chỉ gây xé hình + vòng vẽ chạy hết công suất GPU (nóng máy, khựng); chỉ áp dụng trên ProMotion.
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && CFG285.vsyncAdaptiveBuffer && !Titanium_IsSpringBoard() && Titanium_DisplaySpoofAllowed()) {
%orig(NO);
return;
}
%orig;
}
// [ĐÃ ÉP TOÀN DIỆN]: Cưỡng bức Triple Buffering (3) khi layer đã có kích thước thực tế (chống nghẽn buffer gây đen app)
- (NSUInteger)maximumDrawableCount {
// [ĐÃ SỬA]: getter PHẢI trả số drawable THẬT của layer. Bản cũ "nói dối" luôn là 3 dù layer thực tế chỉ có 2
// (app đặt trước khi layer có superlayer/kích thước) => app tạo 3 khung đang bay nhưng chỉ có 2 drawable => treo/đen màn hình.
// Phần ép Triple Buffering vẫn giữ nguyên ở setMaximumDrawableCount bên dưới.
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
// [ĐÃ SỬA - TRUNG THỰC VỚI PHẦN CỨNG]: tấm nền không có ProMotion chỉ quét tối đa 60Hz. Yêu cầu 144Hz không tạo thêm khung hình nào
// mà làm hệ thống đàm phán nhịp sai (hoạt ảnh đứng hẳn khi không chạm, app đen lúc mở).
if (!Titanium_DisplaySpoofAllowed() && userHz > 60) userHz = 60;
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
// [ĐÃ SỬA - TRUNG THỰC VỚI PHẦN CỨNG]: xem ghi chú ở Titanium_GetTargetConfiguredHz (khóa 30 FPS vẫn hoạt động bình thường)
if (!Titanium_DisplaySpoofAllowed() && userFPS > 60) userFPS = 60;
return userFPS;
}
// [ĐÃ BỔ SUNG - Hz/FPS CÓ TÁC DỤNG TOÀN HỆ THỐNG]: trần khung hình hiệu lực = giá trị THẤP HƠN giữa Hz và FPS đã chọn.
// Hạ Hz hoặc FPS (vd 30) là toàn bộ hoạt ảnh/display link của hệ thống và app chạy tối đa ở mức đó. Tăng thì bị chặn bởi khả năng thật của màn hình.
static inline NSInteger Titanium_GetEffectiveFrameCap(void) {
NSInteger hzCap = Titanium_GetTargetConfiguredHz();
NSInteger fpsCap = Titanium_GetTargetConfiguredFPS();
return (hzCap < fpsCap) ? hzCap : fpsCap;
}
// Sàn dải tần theo trần: bình thường 60; nếu trần thấp hơn 60 (người dùng hạ xuống 30...) thì sàn bằng trần để trần có hiệu lực thật.
static inline float Titanium_RangeFloorForCap(float cap) {
return (cap < TITANIUM_FRAME_RATE_FLOOR) ? cap : TITANIUM_FRAME_RATE_FLOOR;
}
#if TITANIUM_ENABLE_RATE_KEEPER
// ====================================================================================================
// [ĐÃ BỔ SUNG]: BỘ GIỮ NHỊP CHO SPRINGBOARD (KEEP-ALIVE DISPLAYLINK)
// Trong video: hoạt ảnh chạy một đoạn rồi ĐỨNG HẲN 1-3 giây ngay khi nhả tay và chỉ chạy tiếp khi có chạm / bấm nút âm lượng.
// Bộ này chạy một CADisplayLink trống (sàn 60Hz) CHỈ trong cửa sổ giữ nhịp (Titanium_ShouldLockTargetRate), để đường ống hiển thị
// và vòng lặp chính của SpringBoard luôn được đánh thức mỗi khung hình tới khi hoạt ảnh xong, rồi tự tạm dừng khi rảnh.
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
// Thăm dò nhẹ 20 lần/giây: bắt mọi chỗ đặt mốc tương tác mà không gọi trực tiếp bộ giữ nhịp
s_keeperPoller = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
dispatch_source_set_timer(s_keeperPoller, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)), (uint64_t)(50 * NSEC_PER_MSEC), (uint64_t)(20 * NSEC_PER_MSEC));
dispatch_source_set_event_handler(s_keeperPoller, ^{
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_ShouldLockTargetRate()) {
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
if (targetHz < 60.0f) targetHz = 60.0f;
if (targetHz > 144.0f) targetHz = 144.0f;
s_keeperLink.preferredFrameRateRange = SafeMakeFRR(TITANIUM_FRAME_RATE_FLOOR, targetHz, targetHz);
}
[s_keeperLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}
s_keeperIdleFrames = 0;
s_keeperLink.paused = NO;
}
+ (void)tick:(CADisplayLink *)link {
if (Titanium_ShouldLockTargetRate()) {
s_keeperIdleFrames = 0;
} else {
s_keeperIdleFrames++;
if (s_keeperIdleFrames > 20) {
link.paused = YES;
}
}
}
@end
#endif
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
// [ĐÃ SỬA]: bản cũ cho phép dải tần từ 1Hz => khi buông tay hệ thống hạ nhịp quét về ~0 (đứng khung hình mức 0).
// Nay: sàn 60Hz (hoặc bằng trần nếu trần thấp hơn 60), trần = giá trị thấp hơn giữa Hz và FPS đã chọn => chỉnh xuống có tác dụng
// toàn hệ thống (bản cũ ép trần tối thiểu 60 nên hạ Hz/FPS không bao giờ có hiệu lực).
float maxTarget = (float)Titanium_GetEffectiveFrameCap();
if (maxTarget < 15.0f) maxTarget = 15.0f;
if (maxTarget > 144.0f) maxTarget = 144.0f;
range = SafeMakeFRR(Titanium_RangeFloorForCap(maxTarget), maxTarget, maxTarget);
}
}
%orig(range);
}
- (void)setFrameInterval:(NSInteger)interval {
%orig;
}
%end
%hook CADisplay
// [ĐÃ SỬA]: các cờ khả năng màn hình bên dưới (virtual modes / dynamic refresh) CHỈ được khai man trên phần cứng ProMotion thật.
// Khai man trên tấm nền 60Hz khiến hệ thống hạ nhịp theo kiểu ProMotion (đứng khung hình mức 0 khi không chạm).
- (BOOL)allowsVirtualModes {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_DisplaySpoofAllowed()) return YES;
return %orig;
}
- (void)setAllowsVirtualModes:(BOOL)allows {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && Titanium_DisplaySpoofAllowed()) {
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
// [ĐÃ SỬA]: màn hình 60Hz (không có ProMotion) không thể chạy dưới 60Hz; báo "15" mời hệ thống hạ nhịp về ~0.
// Máy ProMotion thật vẫn giữ 15 như cũ.
return HardwareHasNative120Hz() ? 15 : (NSInteger)TITANIUM_FRAME_RATE_FLOOR;
}
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
// [ĐÃ SỬA]: theo trần hiệu lực (thấp hơn giữa Hz/FPS) để app/game tự giới hạn khi người dùng hạ xuống; bản cũ ép tối thiểu 60
NSInteger capFps = Titanium_GetEffectiveFrameCap();
return (capFps < 15) ? 15 : capFps;
}
return %orig;
}
- (NSInteger)_maximumFramesPerSecond {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
NSInteger capFps = Titanium_GetEffectiveFrameCap();
return (capFps < 15) ? 15 : capFps;
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
// [ĐÃ SỬA]: trần hiệu lực theo Hz/FPS đã chọn, cho phép hạ dưới 60 (xem ghi chú ở hook CADisplayLink)
float maxTarget = (float)Titanium_GetEffectiveFrameCap();
if (maxTarget < 15.0f) maxTarget = 15.0f;
if (maxTarget > 144.0f) maxTarget = 144.0f;
if (Titanium_IsPassiveVideoPlayback()) {
range = SafeMakeFRR(30.0f, 60.0f, 60.0f);
} else {
// [ĐÃ SỬA]: sàn 1Hz -> 60Hz (hoặc bằng trần nếu trần thấp hơn 60)
range = SafeMakeFRR(Titanium_RangeFloorForCap(maxTarget), maxTarget, maxTarget);
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
// [ĐÃ SỬA]: trần hiệu lực theo Hz/FPS đã chọn, cho phép hạ dưới 60 (xem ghi chú ở hook CADisplayLink)
float maxTarget = (float)Titanium_GetEffectiveFrameCap();
if (maxTarget < 15.0f) maxTarget = 15.0f;
if (maxTarget > 144.0f) maxTarget = 144.0f;
// [ĐÃ SỬA]: sàn 1Hz -> 60Hz (hoặc bằng trần nếu trần thấp hơn 60)
range = SafeMakeFRR(Titanium_RangeFloorForCap(maxTarget), maxTarget, maxTarget);
}
}
%orig(range);
}
%end
%hook AVPlayer
- (void)setRate:(float)rate {
// [ĐÃ SỬA]: chỉ ghi nhận video trong tiến trình app. SpringBoard không phải trình phát video; nếu cờ này kẹt YES trong SpringBoard
// thì lúc không chạm toàn bộ hoạt ảnh hệ thống bị ép về dải 30-60 thay vì giữ nhịp cấu hình.
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
// 5.1. BẮT TRẠNG THÁI GESTURE VUỐT THỰC TẾ (KHÔNG PHỤ THUỘC VOLUME)
// Chỉ neo target khi gesture pan thực sự bắt đầu/thay đổi; khi kết thúc thì nhả ngay.
%hook UIPanGestureRecognizer
- (void)setState:(UIGestureRecognizerState)state {
%orig(state);
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
if (state == UIGestureRecognizerStateBegan ||
state == UIGestureRecognizerStateChanged) {
g_isUserTouchingScreen = YES;
g_isScrollingActive = YES;
g_lastInteractionMachTime = mach_absolute_time();
Titanium_TriggerInstantTouchBurst();
} else if (state == UIGestureRecognizerStateEnded ||
state == UIGestureRecognizerStateCancelled) {
// [ĐÃ SỬA]: (a) bỏ UIGestureRecognizerStateFailed: một recognizer Failed chưa từng Began nên không được xóa trạng thái chạm
//           (SpringBoard có rất nhiều pan recognizer Failed ngay khi vừa chạm => khóa nhịp bị nhả giữa lúc ngón tay còn trên màn hình)
//           (b) không zero mốc nữa: để cửa sổ giữ nhịp tự tắt dần sau khi nhả tay thay vì nhả khóa ngay về 0
g_isUserTouchingScreen = NO;
g_isScrollingActive = NO;
g_lastInteractionMachTime = mach_absolute_time();
}
}
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
g_isUserTouchingScreen = NO;
g_isScrollingActive = NO;
g_lastInteractionMachTime = mach_absolute_time(); // [ĐÃ SỬA]: không zero mốc, để cửa sổ giữ nhịp tắt dần
}
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
%orig(touches, event);
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
g_isUserTouchingScreen = NO;
g_isScrollingActive = NO;
g_lastInteractionMachTime = mach_absolute_time(); // [ĐÃ SỬA]: không zero mốc, để cửa sổ giữ nhịp tắt dần
}
}
- (void)_scrollViewWillBeginDragging {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
g_isScrollingActive = YES;
g_isUserTouchingScreen = YES;
Titanium_TriggerInstantTouchBurst();
}
%orig;
}
- (void)_notifyDidScroll {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
if (g_isUserTouchingScreen) {
g_isScrollingActive = YES;
g_lastInteractionMachTime = mach_absolute_time();
}
}
%orig;
}
- (void)_smoothScrollWithTimestamp:(double)timestamp {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
if (g_isUserTouchingScreen) {
g_isScrollingActive = YES;
g_lastInteractionMachTime = mach_absolute_time();
}
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
// NHÓM 3: GIA TỐC TOÀN BỘ HIỆU ỨNG BÊN TRONG ỨNG DỤNG (CHẾ ĐỘ ÉP TOÀN DIỆN)
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
// [ĐÃ BỔ SUNG - ĐỢT 4]: NHÓM MƯỢT HÓA TOÀN DIỆN & KẸP DẢI TẦN TOÀN HỆ THỐNG (MULTITASK ASYNC RENDER +
// QUÁN TÍNH CUỘN + LAYOUT MÀN HÌNH CHÍNH + WINDOWSCENE CLAMP THEO TRẦN 15-144 ĐÃ CHỈNH)
// ====================================================================================================
%group Group_Smoothness_Switcher_And_SceneClamp_V286
// 1. RENDER BẤT ĐỒNG BỘ BỐ CỤC THẺ ĐA NHIỆM: mở đa nhiệm không phải chờ dựng tuần tự từng thẻ => hết khựng khi vuốt vào đa nhiệm
%hook SBFluidSwitcherModifier
- (BOOL)shouldasyncRenderAppLayouts {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.reduceMultiTaskLag || CFG285.fixAppExitStutter || g_syncPayloadV285.antiStutterExit)) {
return YES;
}
return %orig;
}
%end
// 2. GIẢN LƯỢC RENDER KHI ĐA NHIỆM NẶNG: bớt lớp bóng/chi tiết thừa của thẻ => GPU nhẹ hơn, mượt hơn, mát hơn
%hook SBAppSwitcherSettings
- (BOOL)shouldSimplifyForOptions:(long long)options {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.reduceMultiTaskLag || CFG285.fixAppExitStutter || g_syncPayloadV285.antiStutterExit)) {
return YES;
}
return %orig;
}
%end
// 3. KÍCH XUNG ĐÚNG LÚC QUÁN TÍNH CUỘN BẮT ĐẦU (kể cả cuộn quán tính do thả tay) => không còn khựng giữa chừng khi vuốt
%hook UIScrollView
- (void)_smoothScrollWithVelocity:(CGPoint)velocity targetContentOffset:(CGPoint)targetContentOffset {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
g_isScrollingActive = YES;
g_lastInteractionMachTime = mach_absolute_time();
Titanium_TriggerInstantTouchBurst();
}
%orig;
}
%end
// 4. GIỮ NHỊP KHI MÀN HÌNH CHÍNH LAYOUT (xoay trang, thêm/xóa icon, mở folder) => không khựng khung hình lúc chuyển cảnh
%hook SBMainDisplaySceneLayoutViewController
- (void)viewWillLayoutSubviews {
%orig;
if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
g_lastInteractionMachTime = mach_absolute_time();
}
}
- (void)viewDidLayoutSubviews {
%orig;
if (IS_ACTIVE || g_syncPayloadV285.masterEnabled) {
g_lastInteractionMachTime = mach_absolute_time();
}
}
%end
// 5. [ĐÃ SỬA - ĐỢT 4 - 15-144 TOÀN HỆ THỐNG]: MỌI lần app/hệ thống đặt dải tần cho scene đều bị kẹp theo
//    trần hiệu lực (giá trị thấp hơn giữa Hz/FPS đã chỉnh) và sàn 60Hz (hoặc bằng trần nếu trần < 60).
//    Bản cũ chỉ kẹp ở CADisplayLink/CAAnimation nên nhiều scene tự đặt dải riêng => chỉnh trong app tweak không ăn.
%hook UIWindowScene
- (void)setPreferredFrameRateRange:(SafeFrameRateRange)range {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted) {
float maxTarget = (float)Titanium_GetEffectiveFrameCap();
if (maxTarget < 15.0f) maxTarget = 15.0f;
if (maxTarget > 144.0f) maxTarget = 144.0f;
range = SafeMakeFRR(Titanium_RangeFloorForCap(maxTarget), maxTarget, maxTarget);
}
%orig(range);
}
%end
%end
// ====================================================================================================
// NHÓM 4: BỘ NÃO DỰ ĐOÁN TỌA ĐỘ NEURAL & CỬ CHỈ MÉP 0MS (CHẾ ĐỘ ÉP TOÀN DIỆN)
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
// NHÓM 17: COREANIMATION RENDER SERVER GOVERNOR (ĐÃ ÉP ĐỒNG BỘ GPU - TRIỆU TIÊU ĐEN APP)
// ====================================================================================================
%group Group_CoreAnimation_RenderServer_Governor
%hook NSRunLoop
- (BOOL)runMode:(NSRunLoopMode)mode beforeDate:(NSDate *)limitDate {
if ((IS_ACTIVE || g_syncPayloadV285.masterEnabled) && !g_isCurrentAppBlacklisted && [NSThread isMainThread] && (CFG285.ultraResponsivenessPro || g_isRateLockedV285)) {
pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
}
// [ĐÃ SỬA]: chữ ký gốc là "- (BOOL)runMode:beforeDate:". Bản cũ khai báo void và bỏ mất giá trị trả về, các vòng lặp runloop
// (luồng mạng/NSURLConnection tự chạy "while ([runLoop runMode:...])") có thể thoát sớm hoặc quay vô hạn => như nghẽn mạng / xám mãi.
return %orig;
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
// NHÓM 19: CRYO-PACING DUTY-CYCLE & VRAM THERMAL DISSIPATION (CHẾ ĐỘ ÉP TOÀN DIỆN)
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
// NHÓM 20: DEEP RAM COMPACTION & MACH VM PURGABLE ENGINE (CHẾ ĐỘ ÉP TOÀN DIỆN)
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
// [ĐÃ SỬA]: bản cũ chạy self.configuration trên luồng nền và capture self vào block nền => khi block là nơi giữ tham chiếu cuối,
// WKWebView bị dealloc ở luồng nền (WebKit bắt buộc luồng chính) => văng app trình duyệt. Nay: lấy pool và gọi API WebKit
// NGAY trên luồng chính, chỉ đẩy phần dọn heap thuần C xuống luồng nền (không capture đối tượng UIKit/WebKit).
WKProcessPool *pool = self.configuration.processPool;
if ([pool respondsToSelector:@selector(_clearMemoryCache)]) {
[pool _clearMemoryCache];
}
if ([pool respondsToSelector:@selector(_purgePageCache)]) {
[pool _purgePageCache];
}
dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
malloc_zone_pressure_relief(malloc_default_zone(), 0);
});
}
}
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
%hook WKProcessPool
// [ĐÃ ÉP TOÀN DIỆN]: Lắng nghe sự kiện App vào background để ép WebKit xả cache tự động
- (instancetype)init {
WKProcessPool *pool = %orig;
if (pool && (IS_ACTIVE || g_syncPayloadV285.masterEnabled)) {
// [ĐÃ SỬA]: bản cũ capture `pool` bằng tham chiếu mạnh trong observer sống vĩnh viễn (rò rỉ mọi WKProcessPool, tiến trình web
// không bao giờ được giải phóng) và gọi API WebKit ở luồng nền. Nay: tham chiếu YẾU + gọi ngay trên hàng đợi chính.
__weak WKProcessPool *weakPool = pool;
[[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidEnterBackgroundNotification
object:nil
queue:[NSOperationQueue mainQueue]
usingBlock:^(NSNotification *note) {
WKProcessPool *strongPool = weakPool;
if (!strongPool) return;
if ([strongPool respondsToSelector:@selector(_clearMemoryCache)]) {
[strongPool _clearMemoryCache];
}
if ([strongPool respondsToSelector:@selector(_purgePageCache)]) {
[strongPool _purgePageCache];
}
}];
}
return pool;
}
%end
%end
// ====================================================================================================
// NHÓM ĐẶC QUYỀN: ÉP PHẦN CỨNG NHẬN DỆN & CHẠY PROMOTION THẬT (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN)
// (KẾT NỐI: Ép Xung ProMotion Cố Định + Tăng Tần Số Lấy Mẫu Cảm Ứng 1000Hz + Ổ Khóa App)
// (AN TOÀN TUYỆT ĐỐI: BẢO VỆ BỘ NHỚ CFRETAIN TRÁNH CRASH MEMORY CORRUPTION)
// ====================================================================================================
%group Group_Hardware_ProMotion_Overclock
extern "C" CFPropertyListRef MGCopyAnswer(CFStringRef property);
// [ĐÃ ÉP TOÀN DIỆN]: Ép toàn bộ cờ Variable Refresh Rate & ProMotion của Apple qua MobileGestalt
%hookf(CFPropertyListRef, MGCopyAnswer, CFStringRef property) {
if (property && (IS_ACTIVE || g_syncPayloadV285.masterEnabled) && (CFG285.proMotionEngineBeta7 || CFG285.enableHzControl || g_isRateLockedV285 || g_syncPayloadV285.forceOverclock)) {
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
// NHÓM BACKBOARDD
%group Group_Backboardd_TouchDriver_Overdrive
%hook BKTouchDeliveryPolicyServer
// Ép đường truyền cảm ứng bypass qua mọi hàng đợi kiểm tra độ trễ
- (id)init {
id orig = %orig;
pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
return orig;
}
%end
%hook BKHIDEventProcessor
// Ép xử lý sự kiện HID cảm ứng thời gian thực (Realtime Processing)
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
// [ĐÃ SỬA - ĐỢT 4 - BẬT/TẮT 15-144 KHÔNG ĂN]: BỎ việc đè g_cachedResolvedHz bằng CFG285.targetHz THÔ.
// Bản cũ đè lại cache ngay sau loadSettings => bỏ qua cờ EnableHzControl/Enabled/tiết kiệm pin (tắt công tắc vẫn 144Hz).
// loadSettings đã tính đúng giá trị resolved vào cache rồi, không được đè lại ở đây.
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
// [ĐÃ SỬA]: KHÔNG hook máy chủ hiển thị (CAWindowServerDisplay / CADisplay trong backboardd) trên tấm nền 60Hz không có ProMotion.
// Bản cũ luôn báo cho máy chủ hiển thị gốc rằng màn hình hỗ trợ VRR và chạy 144Hz (kể cả khi người dùng tắt công tắc tổng).
if (!Titanium_DisplaySpoofAllowed()) return;
static dispatch_once_t s_wsInitOnce;
dispatch_once(&s_wsInitOnce, ^{
%init(Group_CAWindowServer_Absolute_Dominance);
});
}
// ====================================================================================================
// RUNTIME INITIALIZER: ĐÃ ĐỒNG BỘ HOÀN TOÀN
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
// [ĐÃ SỬA - ĐỢT 4]: BỎ đoạn đè g_cachedResolvedHz/FPS bằng CFG285.targetHz/targetFPS THÔ ở đây.
// Bản cũ đè ngay sau loadSettings nên cờ bật/tắt Hz-FPS và chế độ tiết kiệm pin bị vô hiệu hóa lúc khởi động
// (tắt trong app tweak mà tiến trình vẫn chạy 144). loadSettings đã ghi đúng giá trị resolved vào cache.
}
// [ĐÃ SỬA - CÔNG TẮC TỔNG / LOẠI TRỪ APP]: app bị tắt trong tab App, hoặc công tắc tổng đang TẮT khi app khởi chạy,
// thì KHÔNG nạp bất kỳ nhóm hook nào vào tiến trình này (tắt thật sự, không chỉ "gác" điều kiện).
// Lưu ý: app đã mở lúc công tắc tổng tắt cần mở lại sau khi bật công tắc mới có hook.
if (!isSpringBoard && (g_isCurrentAppBlacklisted || (CFG285 && !CFG285.enabled))) {
g_SystemMasterReady = YES;
return;
}
dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
Titanium_ReloadSharedSyncStateV285();
});
// 0. BẢO VỆ WATCHDOG
// [ĐÃ SỬA]: mặc định TẮT (TITANIUM_ENABLE_WATCHDOG_IMMUNITY = 0), xem ghi chú ở phần định nghĩa macro
if (TITANIUM_ENABLE_WATCHDOG_IMMUNITY) {
%init(Group_AntiWatchdog_Immunity);
}
// 1. CÁC NHÓM CẢM ỨNG & HIỆU ỨNG HỆ THỐNG
%init(Group_ZeroLatency_Touch_Opt);
%init(Group_Metal_ZeroTearing_Pacing);
%init(Group_FluidTransitions_Pacing);
%init(Group_FastLaunch_SuperEngineV285);
%init(Group_Scroll_And_Keyboard_Opt);
%init(Group_InstantActionAndMenuTransitions_Boost);
%init(Group_Global_Thread_Governor_Unthrottled);
// 2. GIA TỐC PHẦN CỨNG & DỰ ĐOÁN ĐỒ HỌA
%init(Group_Universal_InApp_Animations);
// [ĐÃ BỔ SUNG - ĐỢT 4]: nhóm mượt hóa toàn diện + kẹp dải tần toàn hệ thống (chạy cho cả SpringBoard lẫn app)
%init(Group_Smoothness_Switcher_And_SceneClamp_V286);
%init(Group_Apple_Internal_ProMotion_Apex);
%init(Group_Apple_NeuralTouch_And_EdgeZeroLatency_V285);
// [ĐÃ SỬA]: nhóm khai man ProMotion qua MobileGestalt chỉ nạp trên phần cứng ProMotion thật
if (Titanium_DisplaySpoofAllowed()) {
%init(Group_Hardware_ProMotion_Overclock);
}
// [ĐÃ THÊM]: Cấp nhịp quét khởi tạo Scene ban đầu chống đen app
%init(Group_Apple_Native_ColdBoot_Overdrive);
// 3. ĐỒ HỌA SILICON, ĐIỀU PHỐI CPU & RAM
%init(Group_Titanium_Game_Metal_Overdrive);
%init(Group_Silicon_Hardware_Pipeline_Overdrive);
%init(Group_Silicon_Scheduler_Touch_Governor);
%init(Group_CoreAnimation_RenderServer_Governor);
%init(Group_System_Memory_And_RunLoop_Governor);
%init(Group_Thermal_CryoPacing_ZeroDrop);
%init(Group_Deep_RAM_Compaction_Engine);
// [ĐÃ SỬA]: app có mạng thường nhúng WKWebView (đăng nhập/nội dung web); nhóm này chỉ nạp vào app thứ ba khi bật macro
if (isSpringBoard || TITANIUM_ENABLE_WEBKIT_HOOKS_IN_APPS) {
%init(Group_WebKit_RAM_Optimizer);
}
// 4. PHÂN TÁCH NÚT HOME VẬT LÝ CHO THIẾT BỊ CLASSIC
if (Titanium_IsClassicHomeButtonDevice()) {
%init(Group_HardwareSegregation_ClassicHomeV285);
}
// 5. PHÂN LẬP NẠP SPRINGBOARD VÀ APP THỨ BA
if (isSpringBoard) {
%init(Group_LiquidGlass_Opt);
%init(Group_Switcher30Apps_Virtualization);
%init(Group_Display_SpringBoardV285);
%init(Group_V285_FloatingWindow_PiP);
%init(Group_SpringBoard_ProcessManagerV285);
// ÉP CỨNG TẦNG GỐC MÁY CHỦ HIỂN THỊ (GỌI QUA HÀM TRỢ LỰC)
Init_CAWindowServer_Hooks();
#if TITANIUM_ENABLE_RATE_KEEPER
[TitaniumRateKeeper start];
#endif
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
%init(Group_UIKit_ThirdParty_IsolatedV285);
// BẢO VỆ BUFFER TRÁNH ĐEN MÀN HÌNH
%init(Group_Force_Render_Recovery_Overdrive);
// GIA TỐC CẤP WINDOW / SCENE DUY NHẤT (ĐÃ DỌN SẠCH TRÙNG LẶP)
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
// BOOTSTRAP TRIGGER & CONSTRUCTOR (ĐÃ BỔ SUNG CHẶN TOÀN BỘ TIẾN TRÌNH MẠNG TRIỆT TIÊU NGHẼN MẠNG)
// ====================================================================================================
// [ĐÃ SỬA - CÔNG TẮC TỔNG]: tách phần đăng ký observer thành hàm dùng chung để backboardd cũng nhận được thay đổi công tắc
// (trước đây nhánh backboardd thoát sớm nên không bao giờ nạp cấu hình/IPC và luôn bị ép 144Hz).
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
if (!isSpringBoardProcess) {
// Chỉ app / backboardd nghe thông báo "đã ghi xong payload"; SpringBoard chính là bên phát nên không nghe (tránh vòng lặp)
CFNotificationCenterAddObserver(darwinCenter, NULL, (CFNotificationCallback)ReloadPreferencesCallbackV285, CFSTR(NOTIFY_PAYLOAD_WRITTEN), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}
});
}
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
// 1. Chặn nạp vào chính app cấu hình và các tweak liên quan
if (strcasestr(progName, "smooth") != NULL ||
strcasestr(progName, "boosti") != NULL ||
strcasestr(progName, "liquid") != NULL) {
return;
}
if (strcasestr(progName, "networkd") != NULL ||           // Daemon lõi điều phối socket và luồng mạng iOS
strcasestr(progName, "trustd") != NULL ||             // Daemon thẩm định chứng chỉ SSL/TLS
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
strcasestr(progName, "identityservicesd") != NULL ||  // iMessage & FaceTime network daemon
strcasestr(progName, "imagent") != NULL ||            // Quản lý kết nối tin nhắn iMessage
strcasestr(progName, "bluetoothd") != NULL) {         // Giao tiếp mạng Bluetooth
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
strcasestr(progName, "passd")) {
return;
}
// ==============================================================================================
// 4. [XỬ LÝ ĐỘC LẬP]: TIẾN TRÌNH BACKBOARDD (ĐIỀU PHỐI CẢM ỨNG HID & MÁY CHỦ HIỂN THỊ GỐC)
// ==============================================================================================
if (strcasestr(progName, "backboardd") != NULL) {
// [ĐÃ SỬA - CÔNG TẮC TỔNG]: backboardd cũng đọc payload IPC và lắng nghe thay đổi công tắc
Titanium_RegisterPrefsObservers(NO);
Titanium_ReloadSharedSyncStateV285();
Titanium_AdoptPayloadRatesWithoutConfig();
%init(Group_Backboardd_TouchDriver_Overdrive);
Init_CAWindowServer_Hooks();
return; // Khởi tạo xong tiến trình xuất hình và cảm ứng gốc, thoát an toàn
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
// [ĐÃ SỬA - ĐỢT 4]: BỎ đoạn đè cache bằng giá trị thô targetHz/targetFPS (giữ nguyên hành vi bật/tắt đã resolve trong loadSettings)
}
return;
}
// [ĐÃ SỬA]: dùng hàm đăng ký dùng chung (đã gồm thông báo "đã ghi xong payload" cho app)
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
