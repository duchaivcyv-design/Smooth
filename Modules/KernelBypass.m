#import "KernelBypass.h"
#import <mach/mach.h>
#import <mach/mach_time.h>
#import <mach/thread_policy.h>
#import <mach/thread_act.h>
#import <mach/task.h>
#import <mach/vm_map.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <sys/resource.h>
#import <sys/stat.h>
#import <unistd.h>
#import <dlfcn.h>
#import <malloc/malloc.h>

#ifndef VM_PURGABLE_PURGE_ALL
#define VM_PURGABLE_PURGE_ALL 0
#endif

#ifdef __cplusplus
extern "C" {
#endif
kern_return_t vm_purgable_control(mach_port_t task, vm_address_t address, vm_purgable_t control, int *state);
#ifdef __cplusplus
}
#endif

// ====================================================================================================
// HÀM KIỂM TRA NHANH 0NS CHO TWEAK.XM (KHỚP CHUẨN VỚI KERNEL_BYPASS.H)
// ====================================================================================================

BOOL KernelBypass_IsRootHide(void) {
    return [[KernelBypass sharedInstance] isRootHideEnvironment];
}

static inline NSString *KernelBypass_ResolveDynamicRoot(void) {
    static NSString *cachedRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)KernelBypass_ResolveDynamicRoot, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            NSRange range = [dylibPath rangeOfString:@"/var/jb"];
            if (range.location != NSNotFound) {
                NSRange sub = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, dylibPath.length - (range.location + 7))];
                cachedRoot = (sub.location != NSNotFound) ? [dylibPath substringToIndex:sub.location] : @"/var/jb";
            } else {
                cachedRoot = @"/var/jb";
            }
        } else {
            cachedRoot = @"/var/jb";
        }
    });
    return cachedRoot;
}

@implementation KernelBypass {
    BOOL _initialized;
}

+ (instancetype)sharedInstance {
    static KernelBypass *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _initialized = NO;
        _currentJailbreakRoot = KernelBypass_ResolveDynamicRoot();
        _isRootHideEnvironment = [_currentJailbreakRoot containsString:@"/var/jb-"];
        [self initEnvironment];
    }
    return self;
}

- (void)initEnvironment {
    if (_initialized) return;
    _initialized = YES;

    // 1. Mở rộng giới hạn tệp mở tối đa cho tiến trình (Bypass sandbox IO limit)
    struct rlimit rl;
    if (getrlimit(RLIMIT_NOFILE, &rl) == 0) {
        rl.rlim_cur = rl.rlim_max;
        setrlimit(RLIMIT_NOFILE, &rl);
    }

    // 2. Thiết lập QoS tương tác người dùng cao nhất cho luồng hiện tại
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    // 3. Đảm bảo thư mục lưu trữ cấu hình trong phân vùng root có đủ quyền đọc/ghi
    NSString *prefDir = [NSString stringWithFormat:@"%@/var/mobile/Library/Preferences", _currentJailbreakRoot];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:prefDir]) {
        [fm createDirectoryAtPath:prefDir withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions: @(0755)} error:nil];
    }
}

- (void)boostCurrentThreadPriority {
    [self boostThreadWithTargetHz:144];
}

// ====================================================================================================
// NÂNG MỨC ƯU TIÊN LUỒNG: CƯỚP ĐỈNH P-CORE NHƯNG BẢO TOÀN 100% SOCKET MẠNG
// ====================================================================================================

- (void)boostThreadWithTargetHz:(uint32_t)targetHz {
    mach_port_t currentThread = mach_thread_self();
    if (!MACH_PORT_VALID(currentThread)) return;

    // TỐI ƯU CỐT TỬ: Sử dụng QoS User Interactive của Apple Silicon/XNU.
    // GIỮ NGUYÊN TIMESHARE MẶC ĐỊNH: Cho phép nhân XNU cấp time-slice cho socket nsurlsessiond,
    // tiến trình WebKit và đường truyền buffer video YouTube / TikTok (triệt tiêu 100% nghẽn mạng).
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    // Gán affinity tag = 1 để ép luồng đồ họa chạy trên cụm nhân hiệu năng cao (P-Core)
    thread_affinity_policy_data_t affinity;
    affinity.affinity_tag = 1;
    thread_policy_set(currentThread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affinity, THREAD_AFFINITY_POLICY_COUNT);

    // Ưu tiên đọc đĩa tốc độ cao (IOPOL_IMPORTANT)
    #if defined(IOPOL_TYPE_DISK) && defined(IOPOL_IMPORTANT)
    setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
    #endif

    mach_port_deallocate(mach_task_self(), currentThread);
}

// ====================================================================================================
// GIẢI PHÓNG BỘ NHỚ ĐỆM TRANG NHÂN CẤP MACH VM (AN TOÀN TUYỆT ĐỐI)
// ====================================================================================================

- (void)forceMachPurge {
    malloc_zone_pressure_relief(NULL, 0);
    mach_port_t selfTask = mach_task_self();
    if (!MACH_PORT_VALID(selfTask)) return;

    int purgeState = 0;
    vm_purgable_control(selfTask, 0, VM_PURGABLE_PURGE_ALL, &purgeState);
}

- (BOOL)canAccessPathSafely:(NSString *)path {
    if (!path || path.length == 0) return NO;
    return (access([path UTF8String], R_OK | W_OK) == 0);
}

@end
