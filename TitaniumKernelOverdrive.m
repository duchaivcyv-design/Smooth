#import "TitaniumKernelOverdrive.h"
#import <mach/vm_map.h>
#import <mach/thread_act.h>
#import <mach/thread_policy.h>
#import <sys/mman.h>
#import <sys/resource.h>
#import <dlfcn.h>
#import <pthread.h>
#import <unistd.h>
#import <stdbool.h>

// ====================================================================================================
// ĐỊNH NGHĨA HẰNG SỐ XNU KERNEL
// ====================================================================================================
#ifndef MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK
#define MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK 5
#endif
#ifndef MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT
#define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT 6
#endif
#ifndef THREAD_THROTTLE_POLICY
#define THREAD_THROTTLE_POLICY 4
#endif
#ifndef IOPOL_TYPE_DISK
#define IOPOL_TYPE_DISK 0
#endif
#ifndef IOPOL_SCOPE_PROCESS
#define IOPOL_SCOPE_PROCESS 0
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

#define TITANIUM_MAX_JETSAM_MB 10240 // ~10GB (Tương đương mức vô hạn cho iOS)

typedef struct {
    uint32_t pset_limit;
} thread_throttle_policy_data_t;

typedef int (*memorystatus_control_t)(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);
typedef int (*setiopolicy_np_t)(int iotype, int scope, int policy);

// ====================================================================================================
// BẺ KHÓA BỘ NHỚ & KERNEL
// ====================================================================================================

static inline void clear_icache(void *addr, size_t size) {
#if defined(__arm64__) || defined(__arm__)
    __builtin___clear_cache((char *)addr, (char *)addr + size);
#else
    (void)addr; (void)size;
#endif
}

bool Titanium_ForceKernelMemoryWrite(void *targetAddr, const void *patchBytes, size_t size) {
    if (!targetAddr || !patchBytes || size == 0) return false;

    vm_address_t pageStart = (vm_address_t)targetAddr & ~((vm_address_t)PAGE_SIZE - 1);
    vm_size_t regionSize = ((vm_address_t)targetAddr + size - pageStart + PAGE_SIZE - 1) & ~((vm_address_t)PAGE_SIZE - 1);

    // Mở quyền ghi (Bao gồm cả cờ COPY cho COW pages)
    kern_return_t kr = vm_protect(mach_task_self(), pageStart, regionSize, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    if (kr != KERN_SUCCESS) {
        // Fallback nếu vm_protect fail
        if (mprotect((void *)pageStart, regionSize, PROT_READ | PROT_WRITE | PROT_EXEC) != 0) {
            return false;
        }
    }

    // Ghi đè nội dung nhị phân
    memcpy(targetAddr, patchBytes, size);

    // Khôi phục quyền R-X và clear cache
    vm_protect(mach_task_self(), pageStart, regionSize, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    clear_icache(targetAddr, size);

    return true;
}

void Titanium_OverclockChipAndUnthrottle(void) {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    thread_port_t currentThread = mach_thread_self();
    if (currentThread != MACH_PORT_NULL) {
        // Đặt mức ưu tiên cao nhất cho luồng (Max Precedence)
        thread_precedence_policy_data_t precedence;
        precedence.importance = 63;
        thread_policy_set(currentThread, THREAD_PRECEDENCE_POLICY, (thread_policy_t)&precedence, THREAD_PRECEDENCE_POLICY_COUNT);

        // Hủy bỏ throttle của nhân đối với luồng (No Throttle)
        thread_throttle_policy_data_t throttle;
        throttle.pset_limit = 0;
        thread_policy_set(currentThread, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttle, 1);

        mach_port_deallocate(mach_task_self(), currentThread);
    }

    // Tối ưu hóa I/O đĩa (Sử dụng dlsym để tránh crash khi Apple thay đổi API)
    static setiopolicy_np_t setiopolicy_fn = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setiopolicy_fn = (setiopolicy_np_t)dlsym(RTLD_DEFAULT, "setiopolicy_np");
    });

    if (setiopolicy_fn) {
        setiopolicy_fn(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        setiopolicy_fn(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
    }
}

void Titanium_BreakJetsamMemoryLimits(void) {
    memorystatus_control_t mem_ctrl = (memorystatus_control_t)dlsym(RTLD_DEFAULT, "memorystatus_control");
    if (mem_ctrl) {
        pid_t pid = getpid();
        // Ép giới hạn bộ nhớ lên mức tối đa
        mem_ctrl(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT, pid, TITANIUM_MAX_JETSAM_MB, NULL, 0);
        mem_ctrl(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, pid, TITANIUM_MAX_JETSAM_MB, NULL, 0);
    }
}
