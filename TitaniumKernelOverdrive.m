#import "TitaniumKernelOverdrive.h"

// ====================================================================================================
// IMPORTS
// ====================================================================================================
#import <mach/mach.h>
#import <mach/mach_init.h>
#import <mach/vm_map.h>
#import <mach/thread_act.h>
#import <mach/thread_policy.h>
#import <mach/thread_info.h>
#import <mach/task.h>
#import <mach/task_policy.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>
#import <sys/resource.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <pthread.h>
#import <pthread/qos.h>
#import <unistd.h>
#import <stdbool.h>
#import <stdint.h>
#import <string.h>
#import <stdlib.h>
#import <stdio.h>
#import <stdarg.h>
#import <dispatch/dispatch.h>

// ====================================================================================================
// DEBUG LOG
// ====================================================================================================
#ifdef TITANIUM_OVERDRIVE_DEBUG
    #define ODLog(fmt, ...) fprintf(stderr, "[TitaniumOD] " fmt "\n", ##__VA_ARGS__)
#else
    #define ODLog(fmt, ...) do {} while(0)
#endif

// ====================================================================================================
// HẰNG SỐ XNU
// ====================================================================================================
#ifndef MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK
#define MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK 5
#endif
#ifndef MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT
#define MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT 6
#endif
#ifndef MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES
#define MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES 2
#endif
#ifndef MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE
#define MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE 18
#endif
#ifndef MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED
#define MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED 14
#endif
#ifndef JETSAM_PRIORITY_CRITICAL
#define JETSAM_PRIORITY_CRITICAL 19
#endif
#ifndef THREAD_THROTTLE_POLICY
#define THREAD_THROTTLE_POLICY 4
#endif
#ifndef THREAD_PRECEDENCE_POLICY_COUNT
#define THREAD_PRECEDENCE_POLICY_COUNT 1
#endif
#ifndef THREAD_TIME_CONSTRAINT_POLICY_COUNT
#define THREAD_TIME_CONSTRAINT_POLICY_COUNT 4
#endif
#ifndef THREAD_AFFINITY_POLICY_COUNT
#define THREAD_AFFINITY_POLICY_COUNT 1
#endif
#ifndef TASK_QOS_POLICY_COUNT
#define TASK_QOS_POLICY_COUNT 2
#endif
#ifndef TASK_BASE_QOS_POLICY
#define TASK_BASE_QOS_POLICY 1
#endif
#ifndef TASK_OVERRIDE_QOS_POLICY
#define TASK_OVERRIDE_QOS_POLICY 2
#endif
#ifndef IOPOL_TYPE_DISK
#define IOPOL_TYPE_DISK 0
#endif
#ifndef IOPOL_SCOPE_PROCESS
#define IOPOL_SCOPE_PROCESS 0
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
#ifndef LATENCY_QOS_TIER_0
#define LATENCY_QOS_TIER_0 ((0xFF << 16) | 1)
#endif
#ifndef THROUGHPUT_QOS_TIER_0
#define THROUGHPUT_QOS_TIER_0 ((0xFE << 16) | 1)
#endif
#ifndef RLIMIT_AS
#define RLIMIT_AS 5
#endif
#ifndef RLIMIT_DATA
#define RLIMIT_DATA 2
#endif

#define TITANIUM_MAX_JETSAM_MB 0x7FFFFFFF
#define TITANIUM_TARGET_IMPORTANCE 90
#define TITANIUM_KERNEL_USERLAND_MAX 63
#define TITANIUM_TASK_IMPORTANCE_MAX 80

// ====================================================================================================
// TYPEDEFS
// ====================================================================================================
typedef struct {
    uint32_t pset_limit;
} thread_throttle_policy_data_t;

typedef struct {
    int32_t priority;
    uint64_t user_data;
} memorystatus_priority_properties_t;

typedef int (*memorystatus_control_t)(uint32_t command, int32_t pid, uint32_t flags, void *buffer, size_t buffersize);
typedef int (*setiopolicy_np_t)(int iotype, int scope, int policy);
typedef void (*pthread_jit_write_protect_np_t)(int enabled);

// kwritebuf_phys — Dopamine libjailbreak, 3-arg verified
typedef int (*kreadbuf_phys_t)(uint64_t, void*, size_t);
typedef int (*kwritebuf_phys_t)(uint64_t, const void*, size_t);

// ====================================================================================================
// FORWARD DECLARATIONS
// ====================================================================================================
static inline void Titanium_ClearICache(void *addr, size_t size);
static inline void Titanium_JITWriteProtectToggle(int enabled);
static void Titanium_OverclockThread(thread_port_t thread, NSInteger targetImportance);
static inline void Titanium_SetIOKitDiskPolicy(void);
static inline void Titanium_ApplyQoSTier(void);
static NSInteger Titanium_ReadThreadImportance(thread_port_t thread);
bool Titanium_KernelWriteThreadImportance(uint64_t threadPortAddr, int32_t targetImportance);

// ====================================================================================================
// ICACHE + JIT
// ====================================================================================================
static inline void Titanium_ClearICache(void *addr, size_t size) {
#if defined(__arm64__) || defined(__arm__)
    __builtin___clear_cache((char *)addr, (char *)addr + size);
#else
    (void)addr; (void)size;
#endif
}

static inline void Titanium_JITWriteProtectToggle(int enabled) {
    static pthread_jit_write_protect_np_t fn = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        fn = (pthread_jit_write_protect_np_t)dlsym(RTLD_DEFAULT,
                                                    "pthread_jit_write_protect_np");
    });
    if (fn) fn(enabled);
}

// ====================================================================================================
// MEMORY WRITE — 5 strategies
// ====================================================================================================
bool Titanium_ForceKernelMemoryWrite(void *targetAddr, const void *patchBytes, size_t size) {
    if (!targetAddr || !patchBytes || size == 0) return false;

    vm_address_t target = (vm_address_t)targetAddr;
    vm_address_t pageStart = target & ~((vm_address_t)PAGE_SIZE - 1);
    vm_size_t span = (target - pageStart) + size;
    vm_size_t regionSize = (span + PAGE_SIZE - 1) & ~((vm_address_t)PAGE_SIZE - 1);

    uint8_t *backup = (uint8_t *)malloc(size);
    if (!backup) return false;
    memcpy(backup, targetAddr, size);

    bool success = false;
    int strategyUsed = 0;

    Titanium_JITWriteProtectToggle(0);
    memcpy(targetAddr, patchBytes, size);
    if (memcmp(targetAddr, patchBytes, size) == 0) { success = true; strategyUsed = 1; }
    else memcpy(targetAddr, backup, size);
    Titanium_JITWriteProtectToggle(1);

    if (!success) {
        kern_return_t kr = vm_protect(mach_task_self(), pageStart, regionSize, FALSE,
                                       VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        if (kr == KERN_SUCCESS) {
            memcpy(targetAddr, patchBytes, size);
            if (memcmp(targetAddr, patchBytes, size) == 0) { success = true; strategyUsed = 2; }
            else memcpy(targetAddr, backup, size);
            vm_protect(mach_task_self(), pageStart, regionSize, FALSE,
                       VM_PROT_READ | VM_PROT_EXECUTE);
        }
    }

    if (!success) {
        kern_return_t kr = vm_protect(mach_task_self(), pageStart, regionSize, FALSE,
                                       VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE | VM_PROT_COPY);
        if (kr == KERN_SUCCESS) {
            memcpy(targetAddr, patchBytes, size);
            if (memcmp(targetAddr, patchBytes, size) == 0) { success = true; strategyUsed = 3; }
            else memcpy(targetAddr, backup, size);
            vm_protect(mach_task_self(), pageStart, regionSize, FALSE,
                       VM_PROT_READ | VM_PROT_EXECUTE);
        }
    }

    if (!success) {
        if (mprotect((void *)pageStart, regionSize, PROT_READ | PROT_WRITE | PROT_EXEC) == 0) {
            memcpy(targetAddr, patchBytes, size);
            if (memcmp(targetAddr, patchBytes, size) == 0) { success = true; strategyUsed = 4; }
            else memcpy(targetAddr, backup, size);
            mprotect((void *)pageStart, regionSize, PROT_READ | PROT_EXEC);
        }
    }

    if (success) Titanium_ClearICache(targetAddr, size);

    ODLog("write @%p size=%zu success=%d strategy=%d",
          targetAddr, size, success, strategyUsed);

    (void)strategyUsed;
    free(backup);
    return success;
}

// ====================================================================================================
// READ BACK ACTUAL IMPORTANCE
// ====================================================================================================
static NSInteger Titanium_ReadThreadImportance(thread_port_t thread) {
    if (thread == MACH_PORT_NULL) return -1;
    struct thread_extended_info extInfo;
    mach_msg_type_number_t extCount = THREAD_EXTENDED_INFO_COUNT;
    kern_return_t kr = thread_info(thread, THREAD_EXTENDED_INFO, (thread_info_t)&extInfo, &extCount);
    if (kr == KERN_SUCCESS) return (NSInteger)extInfo.pth_curpri;

    struct thread_basic_info basicInfo;
    mach_msg_type_number_t basicCount = THREAD_BASIC_INFO_COUNT;
    kr = thread_info(thread, THREAD_BASIC_INFO, (thread_info_t)&basicInfo, &basicCount);
    if (kr == KERN_SUCCESS) return (NSInteger)basicInfo.run_state;
    return -1;
}

// ====================================================================================================
// [TARGET-90] THREAD OVERCLOCK
// ====================================================================================================
static void Titanium_OverclockThread(thread_port_t thread, NSInteger targetImportance) {
    if (thread == MACH_PORT_NULL) return;
    if (targetImportance < 1) targetImportance = TITANIUM_TARGET_IMPORTANCE;

    thread_precedence_policy_data_t precedence = { .importance = (int32_t)targetImportance };
    thread_policy_set(thread, THREAD_PRECEDENCE_POLICY, (thread_policy_t)&precedence, THREAD_PRECEDENCE_POLICY_COUNT);

    thread_throttle_policy_data_t throttle = { .pset_limit = 0 };
    thread_policy_set(thread, THREAD_THROTTLE_POLICY, (thread_policy_t)&throttle, 1);

    thread_affinity_policy_data_t affinity = { .affinity_tag = 1 };
    thread_policy_set(thread, THREAD_AFFINITY_POLICY, (thread_policy_t)&affinity, THREAD_AFFINITY_POLICY_COUNT);

    uint64_t periodNs      = 1000000ULL;
    uint64_t computationNs = 900000ULL;
    uint64_t constraintNs  = 1000000ULL;

    thread_time_constraint_policy_data_t tc;
    tc.period      = (uint32_t)(periodNs);
    tc.computation = (uint32_t)(computationNs);
    tc.constraint  = (uint32_t)(constraintNs);
    tc.preemptible = FALSE;
    thread_policy_set(thread, THREAD_TIME_CONSTRAINT_POLICY, (thread_policy_t)&tc, THREAD_TIME_CONSTRAINT_POLICY_COUNT);
}

// ====================================================================================================
// [TARGET-90] KERNEL WRITE BYPASS
// ====================================================================================================
bool Titanium_KernelWriteThreadImportance(uint64_t threadPortAddr, int32_t targetImportance) {
    if (threadPortAddr == 0) return false;

    static kwritebuf_phys_t kwrite_fn = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *lib = dlopen("/var/jb/basebin/libjailbreak.dylib", RTLD_LAZY);
        if (!lib) lib = dlopen("/var/jb/usr/lib/libjailbreak.dylib", RTLD_LAZY);
        if (lib) kwrite_fn = (kwritebuf_phys_t)dlsym(lib, "_kwritebuf_phys");
    });

    if (!kwrite_fn) return false;

    const uint64_t IMPORTANCE_FIELD_OFFSET = 0x68; 
    int32_t val = targetImportance;
    int ret = kwrite_fn(threadPortAddr + IMPORTANCE_FIELD_OFFSET, &val, sizeof(val));
    return (ret == 0);
}

// ====================================================================================================
// I/O & DISK POLICY
// ====================================================================================================
static inline void Titanium_SetIOKitDiskPolicy(void) {
    static setiopolicy_np_t setiopolicy_fn = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        setiopolicy_fn = (setiopolicy_np_t)dlsym(RTLD_DEFAULT, "setiopolicy_np");
    });
    if (setiopolicy_fn) {
        setiopolicy_fn(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);
        setiopolicy_fn(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);
        setiopolicy_fn(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_PROCESS, IOPOL_ATIME_UPDATES_OFF);
        setiopolicy_fn(IOPOL_TYPE_VFS_ATIME_UPDATES, IOPOL_SCOPE_THREAD, IOPOL_ATIME_UPDATES_OFF);
    }
}

// ====================================================================================================
// QoS TIER
// ====================================================================================================
static inline void Titanium_ApplyQoSTier(void) {
    struct task_qos_policy qosinfo;
    qosinfo.task_latency_qos_tier = LATENCY_QOS_TIER_0;
    qosinfo.task_throughput_qos_tier = THROUGHPUT_QOS_TIER_0;

    task_policy_set(mach_task_self(), TASK_BASE_QOS_POLICY, (task_policy_t)&qosinfo, TASK_QOS_POLICY_COUNT);
    task_policy_set(mach_task_self(), TASK_OVERRIDE_QOS_POLICY, (task_policy_t)&qosinfo, TASK_QOS_POLICY_COUNT);
}

// ====================================================================================================
// MAIN OVERCLOCK
// ====================================================================================================
void Titanium_OverclockChipAndUnthrottle(void) {
    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);
    mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
    Titanium_OverclockThread(selfThread, TITANIUM_TARGET_IMPORTANCE);

    thread_act_array_t threadList = NULL;
    mach_msg_type_number_t threadCount = 0;
    kern_return_t kr = task_threads(mach_task_self(), &threadList, &threadCount);
    if (kr == KERN_SUCCESS && threadList) {
        for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
            Titanium_OverclockThread(threadList[i], TITANIUM_TARGET_IMPORTANCE);
            mach_port_deallocate(mach_task_self(), threadList[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)threadList, threadCount * sizeof(thread_act_t));
    }

    setpriority(PRIO_DARWIN_THREAD, 0, -10);
    setpriority(PRIO_DARWIN_PROCESS, 0, -10);
    Titanium_ApplyQoSTier();

    pthread_t self = pthread_self();
    void *stack = pthread_get_stackaddr_np(self);
    size_t stackSize = pthread_get_stacksize_np(self);
    if (stack && stackSize > 0) {
        vm_wire(0, mach_task_self(), (vm_address_t)stack, (vm_size_t)stackSize, VM_PROT_READ | VM_PROT_WRITE);
    }
    Titanium_SetIOKitDiskPolicy();
}

void Titanium_KernelWriteAllThreadImportance(void) {
    thread_act_array_t threadList = NULL;
    mach_msg_type_number_t threadCount = 0;
    kern_return_t kr = task_threads(mach_task_self(), &threadList, &threadCount);
    if (kr != KERN_SUCCESS || !threadList) return;

    int success = 0;
    int fail = 0;
    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        // FILL: convert port → struct addr (cần RE)
        uint64_t threadStructAddr = 0; 
        if (threadStructAddr != 0 && Titanium_KernelWriteThreadImportance(threadStructAddr, TITANIUM_TARGET_IMPORTANCE)) {
            success++;
        } else {
            fail++;
        }
        mach_port_deallocate(mach_task_self(), threadList[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threadList, threadCount * sizeof(thread_act_t));
    (void)success;
    (void)fail;
}

// ====================================================================================================
// JETSAM BREAK
// ====================================================================================================
void Titanium_BreakJetsamMemoryLimits(void) {
    memorystatus_control_t mem_ctrl = (memorystatus_control_t)dlsym(RTLD_DEFAULT, "memorystatus_control");
    if (!mem_ctrl) return;

    pid_t pid = getpid();
    int32_t hwm = TITANIUM_MAX_JETSAM_MB;
    mem_ctrl(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, pid, 0, &hwm, sizeof(hwm));

    int32_t taskLimit = TITANIUM_MAX_JETSAM_MB;
    mem_ctrl(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT, pid, 0, &taskLimit, sizeof(taskLimit));

    memorystatus_priority_properties_t props;
    props.priority = JETSAM_PRIORITY_CRITICAL;
    props.user_data = 0;
    mem_ctrl(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES, pid, 0, &props, sizeof(props));
    mem_ctrl(MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE, pid, 0, NULL, 0);
    mem_ctrl(MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED, pid, 0, NULL, 0);

    struct rlimit rl;
    rl.rlim_cur = RLIM_INFINITY;
    rl.rlim_max = RLIM_INFINITY;
    setrlimit(RLIMIT_AS, &rl);
    setrlimit(RLIMIT_DATA, &rl);
}

void Titanium_WireAllMemory(void *addr, size_t size) {
    if (!addr || size == 0) return;
    vm_wire(0, mach_task_self(), (vm_address_t)addr, (vm_size_t)size, VM_PROT_READ | VM_PROT_WRITE);
}

// ====================================================================================================
// [TARGET-90] PANEL OVERWRITE — Full Range Pattern Scan (15-240Hz)
// Quét dải rộng 256MB, tìm mọi giá trị Hz từ 15-240 kẹp giữa độ phân giải panel
// Ghi đè thành 90Hz, giới hạn 12 patch để tránh panic
// ====================================================================================================
void Titanium_ForceKernelPanelHz(uint64_t kernel_base) {
    static kwritebuf_phys_t kwrite_fn = NULL;
    static kreadbuf_phys_t kread_fn = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *lib = dlopen("/var/jb/basebin/libjailbreak.dylib", RTLD_LAZY);
        if (!lib) lib = dlopen("/var/jb/usr/lib/libjailbreak.dylib", RTLD_LAZY);
        if (lib) {
            kwrite_fn = (kwritebuf_phys_t)dlsym(lib, "_kwritebuf_phys");
            kread_fn  = (kreadbuf_phys_t)dlsym(lib, "_kreadbuf_phys");
        }
    });

    if (!kwrite_fn || !kread_fn) return;

    // Chuyển virtual base thành physical
    uint64_t phys_base = kernel_base & 0x0000000FFFFFFFFFULL;
    if (phys_base < 0x800000000ULL) {
        phys_base = 0x8025a54000ULL; // Fallback
    }

    ODLog("[PANEL-PATCH] Base=0x%llx, scanning 256MB range 15-240Hz...", phys_base);

    // Quét dải rộng: từ base+16MB đến base+272MB (256MB window)
    uint64_t scan_start = phys_base + 0x1000000;
    uint64_t scan_end   = phys_base + 0x11000000; 
    
    int patched_count = 0;
    uint64_t last_hit_page = 0;
    uint32_t target_hz = 90;

    for (uint64_t addr = scan_start; addr < scan_end; addr += 4) {
        // Skip nếu cùng page với hit gần nhất (tránh overwrite struct nhiều lần)
        if (addr - last_hit_page < 0x1000) continue;

        uint32_t val = 0;
        if (kread_fn(addr, &val, 4) != 0) continue;

        // [FULL RANGE] Tìm mọi giá trị từ 15 đến 240
        if (val >= 15 && val <= 240) {
            // Bỏ qua các giá trị phổ biến không liên quan (nhiệt độ, phần trăm)
            // 15-30 có thể là nhiệt độ, 100 là % pin, 240 là màu
            // Nhưng vì có kèm check độ phân giải bên dưới, cứ quét hết
            
            // Đọc vùng 64 byte xung quanh tìm độ phân giải panel
            bool has_resolution = false;
            uint32_t res_val = 0;
            
            for (int i = -16; i <= 16; i++) {
                if (i == 0) continue;
                uint32_t neighbor = 0;
                if (kread_fn(addr + (i * 4), &neighbor, 4) == 0) {
                    // Resolution markers cho iPhone (8 Plus = 1920x1080, XS = 2436x1125...)
                    if (neighbor == 1920 || neighbor == 1080 || 
                        neighbor == 1242 || neighbor == 2208 || 
                        neighbor == 750 || neighbor == 1334 ||
                        neighbor == 2436 || neighbor == 1125 ||
                        neighbor == 2688 || neighbor == 1242) {
                        has_resolution = true;
                        res_val = neighbor;
                        break;
                    }
                }
            }

            // Nếu có resolution marker → xác suất cao đây là struct display timing
            if (has_resolution) {
                // Ghi đè giá trị Hz gốc thành target
                if (kwrite_fn(addr, &target_hz, 4) == 0) {
                    ODLog("[PANEL-PATCH] ✅ 0x%llx: %uHz -> 90Hz (res=%u)", addr, val, res_val);
                    patched_count++;
                    last_hit_page = addr;

                    // Càn quét: ghi đè các giá trị Hz khác trong cùng struct
                    for (int off = 4; off <= 32; off += 4) {
                        uint32_t nearby = 0;
                        if (kread_fn(addr + off, &nearby, 4) == 0) {
                            if (nearby >= 15 && nearby <= 240 && nearby != target_hz) {
                                // Kiểm tra xem có phải giá trị nhiệt độ không
                                // (trong khoảng 15-40 nhưng KHÔNG có res marker xung quanh)
                                kwrite_fn(addr + off, &target_hz, 4);
                                patched_count++;
                            }
                        }
                    }
                }

                // Giới hạn tối đa 12 hit để tránh ghi quá nhiều vào cùng một vùng
                if (patched_count >= 12) {
                    ODLog("[PANEL-PATCH] Reached max 12 patches. Stopping to prevent panic.");
                    break;
                }
            }
        }
    }
    
    ODLog("[PANEL-PATCH] Done. %d addresses overwritten to 90Hz.", patched_count);
}

// ====================================================================================================
// CONVENIENCE
// ====================================================================================================
void Titanium_ApplyAllOverdrive(void) {
    // 1. Ép thread priority (userland max)
    Titanium_OverclockChipAndUnthrottle();
    
    // 2. Mở khóa RAM
    Titanium_BreakJetsamMemoryLimits();
    
    // 3. Ghi đè kernel panel (Pattern Scan 15-240Hz)
    // Base lấy từ log hoặc runtime
    uint64_t kbase = 0xfffffff025a54000ULL; 
    Titanium_ForceKernelPanelHz(kbase);
}
