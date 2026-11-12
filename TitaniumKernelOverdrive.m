#import "TitaniumKernelOverdrive.h"

// ====================================================================================================
// IMPORTS — bổ sung headers thiếu
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

// [TARGET-90] Importance request — kernel clamps to 63
#define TITANIUM_TARGET_IMPORTANCE 90
#define TITANIUM_KERNEL_USERLAND_MAX 63
#define TITANIUM_TASK_IMPORTANCE_MAX 80  // task_importance ceiling

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

    // [FIX WERROR] ODLog no-op khi debug tắt → cast để compiler thấy đã dùng
    (void)strategyUsed;

    free(backup);
    return success;
}

// ====================================================================================================
// READ BACK ACTUAL IMPORTANCE — verify kernel clamp
// ====================================================================================================
static NSInteger Titanium_ReadThreadImportance(thread_port_t thread) {
    if (thread == MACH_PORT_NULL) return -1;

    // Try thread_extended_info first (has priority field)
    struct thread_extended_info extInfo;
    mach_msg_type_number_t extCount = THREAD_EXTENDED_INFO_COUNT;
    kern_return_t kr = thread_info(thread, THREAD_EXTENDED_INFO,
                                    (thread_info_t)&extInfo, &extCount);
    if (kr == KERN_SUCCESS) {
        return (NSInteger)extInfo.pth_curpri;
    }

    // Fallback: thread_basic_info
    struct thread_basic_info basicInfo;
    mach_msg_type_number_t basicCount = THREAD_BASIC_INFO_COUNT;
    kr = thread_info(thread, THREAD_BASIC_INFO,
                     (thread_info_t)&basicInfo, &basicCount);
    if (kr == KERN_SUCCESS) {
        return (NSInteger)basicInfo.run_state;
    }

    return -1;
}

// ====================================================================================================
// [TARGET-90] THREAD OVERCLOCK — push to 90 via API, verify, apply realtime class
// ====================================================================================================
static void Titanium_OverclockThread(thread_port_t thread, NSInteger targetImportance) {
    if (thread == MACH_PORT_NULL) return;

    if (targetImportance < 1) targetImportance = TITANIUM_TARGET_IMPORTANCE;

    // ---- STEP 1: Precedence — request 90, kernel clamps to 63 ----
    thread_precedence_policy_data_t precedence = { .importance = (int32_t)targetImportance };
    kern_return_t kr = thread_policy_set(thread, THREAD_PRECEDENCE_POLICY,
                                          (thread_policy_t)&precedence,
                                          THREAD_PRECEDENCE_POLICY_COUNT);
    NSInteger actualAfterPrecedence = Titanium_ReadThreadImportance(thread);
    ODLog("precedence set req=%ld actual=%ld kr=%d",
          (long)targetImportance, (long)actualAfterPrecedence, kr);

    // ---- STEP 2: Throttle off ----
    thread_throttle_policy_data_t throttle = { .pset_limit = 0 };
    thread_policy_set(thread, THREAD_THROTTLE_POLICY,
                      (thread_policy_t)&throttle, 1);

    // ---- STEP 3: P-core affinity ----
    thread_affinity_policy_data_t affinity = { .affinity_tag = 1 };
    thread_policy_set(thread, THREAD_AFFINITY_POLICY,
                      (thread_policy_t)&affinity, THREAD_AFFINITY_POLICY_COUNT);

    // ---- STEP 4: TIME_CONSTRAINT_POLICY — realtime class BYPASSES 63 clamp ----
    // Kernel treats this as realtime scheduling, not normal thread priority.
    // Period/computation/constraint in nanoseconds. Aggressive = realtime.
    uint64_t periodNs      = 1000000ULL;   // 1 ms
    uint64_t computationNs = 900000ULL;    // 90% duty cycle — max
    uint64_t constraintNs  = 1000000ULL;   // must meet deadline in 1ms

    thread_time_constraint_policy_data_t tc;
    tc.period      = (uint32_t)(periodNs);
    tc.computation = (uint32_t)(computationNs);
    tc.constraint  = (uint32_t)(constraintNs);
    tc.preemptible = FALSE;   // [TARGET-90] NOT preemptible = hard realtime
    thread_policy_set(thread, THREAD_TIME_CONSTRAINT_POLICY,
                      (thread_policy_t)&tc, THREAD_TIME_CONSTRAINT_POLICY_COUNT);

    NSInteger finalImportance = Titanium_ReadThreadImportance(thread);
    ODLog("thread final importance=%ld (requested %ld)",
          (long)finalImportance, (long)targetImportance);
}

// ====================================================================================================
// [TARGET-90] KERNEL WRITE BYPASS — patch thread struct importance field directly
// Requires: kwritebuf_phys from Dopamine libjailbreak (verified 0x104dbb00c)
// Thread struct offset: FILL — varies per iOS version
// ====================================================================================================
bool Titanium_KernelWriteThreadImportance(uint64_t threadPortAddr, int32_t targetImportance) {
    if (threadPortAddr == 0) return NO;

    // Resolve kwritebuf_phys from libjailbreak
    static kwritebuf_phys_t kwrite_fn = NULL;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *lib = dlopen("/var/jb/basebin/libjailbreak.dylib", RTLD_LAZY);
        if (!lib) lib = dlopen("/var/jb/usr/lib/libjailbreak.dylib", RTLD_LAZY);
        if (lib) {
            kwrite_fn = (kwritebuf_phys_t)dlsym(lib, "_kwritebuf_phys");
        }
    });

    if (!kwrite_fn) {
        ODLog("kwritebuf_phys unavailable — kernel write skipped");
        return NO;
    }

    // FILL: thread struct importance field offset for target iOS version
    // iOS 15: 0x60   iOS 16: 0x68   iOS 16.7 (A11): 0x68
    // Determine by RE or dynamic offset dump — this is a placeholder
    const uint64_t IMPORTANCE_FIELD_OFFSET = 0x68;  // FILL for exact iOS

    // Write targetImportance as int32_t into struct field
    int32_t val = targetImportance;
    int ret = kwrite_fn(threadPortAddr + IMPORTANCE_FIELD_OFFSET, &val, sizeof(val));
    if (ret == 0) {
        ODLog("kernel write importance=%d @0x%llx+0x%llx success",
              targetImportance, threadPortAddr, IMPORTANCE_FIELD_OFFSET);
        return YES;
    }
    ODLog("kernel write failed ret=%d", ret);
    return NO;
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

    task_policy_set(mach_task_self(), TASK_BASE_QOS_POLICY,
                    (task_policy_t)&qosinfo, TASK_QOS_POLICY_COUNT);
    task_policy_set(mach_task_self(), TASK_OVERRIDE_QOS_POLICY,
                    (task_policy_t)&qosinfo, TASK_QOS_POLICY_COUNT);
}

// ====================================================================================================
// MAIN OVERCLOCK — ALL threads, target importance 90
// ====================================================================================================
void Titanium_OverclockChipAndUnthrottle(void) {
    ODLog("OverclockChipAndUnthrottle start (target=%d)", TITANIUM_TARGET_IMPORTANCE);

    pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

    // Current thread first
    mach_port_t selfThread = pthread_mach_thread_np(pthread_self());
    Titanium_OverclockThread(selfThread, TITANIUM_TARGET_IMPORTANCE);

    // Enumerate ALL threads
    thread_act_array_t threadList = NULL;
    mach_msg_type_number_t threadCount = 0;
    kern_return_t kr = task_threads(mach_task_self(), &threadList, &threadCount);
    if (kr == KERN_SUCCESS && threadList) {
        ODLog("task_threads returned %u threads", (unsigned)threadCount);
        for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
            Titanium_OverclockThread(threadList[i], TITANIUM_TARGET_IMPORTANCE);
            mach_port_deallocate(mach_task_self(), threadList[i]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)threadList,
                      threadCount * sizeof(thread_act_t));
    }

    // Nice -10 userland max
    setpriority(PRIO_DARWIN_THREAD, 0, -10);
    setpriority(PRIO_DARWIN_PROCESS, 0, -10);

    // QoS tier
    Titanium_ApplyQoSTier();

    // Wire current thread stack
    pthread_t self = pthread_self();
    void *stack = pthread_get_stackaddr_np(self);
    size_t stackSize = pthread_get_stacksize_np(self);
    if (stack && stackSize > 0) {
        vm_wire(0, mach_task_self(), (vm_address_t)stack,
                (vm_size_t)stackSize, VM_PROT_READ | VM_PROT_WRITE);
    }

    // I/O
    Titanium_SetIOKitDiskPolicy();

    ODLog("OverclockChipAndUnthrottle complete");
}

// ====================================================================================================
// [TARGET-90] KERNEL-WRITE PATCH — bypass 63 clamp on ALL threads
// Call AFTER Titanium_OverclockChipAndUnthrottle, requires Dopamine kwritebuf_phys
// ====================================================================================================
void Titanium_KernelWriteAllThreadImportance(void) {
    ODLog("KernelWriteAllThreadImportance start");

    thread_act_array_t threadList = NULL;
    mach_msg_type_number_t threadCount = 0;
    kern_return_t kr = task_threads(mach_task_self(), &threadList, &threadCount);
    if (kr != KERN_SUCCESS || !threadList) return;

    int success = 0;
    int fail = 0;
    for (mach_msg_type_number_t i = 0; i < threadCount; i++) {
        // FILL: convert mach_port_t → kernel thread struct address
        // Path: task->threads list hoặc zmq port table lookup
        // PLACEHOLDER — supply your own lookup here
        uint64_t threadStructAddr = 0;  // FILL

        if (threadStructAddr != 0 &&
            Titanium_KernelWriteThreadImportance(threadStructAddr, TITANIUM_TARGET_IMPORTANCE)) {
            success++;
        } else {
            fail++;
        }
        mach_port_deallocate(mach_task_self(), threadList[i]);
    }
    vm_deallocate(mach_task_self(), (vm_address_t)threadList,
                  threadCount * sizeof(thread_act_t));

    ODLog("kernel importance write: success=%d fail=%d", success, fail);

    // [FIX WERROR] ODLog no-op khi debug tắt → cast chặn unused-but-set warning
    (void)success;
    (void)fail;
}

// ====================================================================================================
// JETSAM BREAK
// ====================================================================================================
void Titanium_BreakJetsamMemoryLimits(void) {
    ODLog("BreakJetsamMemoryLimits start");

    memorystatus_control_t mem_ctrl = (memorystatus_control_t)dlsym(RTLD_DEFAULT,
                                                                     "memorystatus_control");
    if (!mem_ctrl) {
        ODLog("memorystatus_control not found");
        return;
    }

    pid_t pid = getpid();

    int32_t hwm = TITANIUM_MAX_JETSAM_MB;
    int r1 = mem_ctrl(MEMORYSTATUS_CMD_SET_JETSAM_HIGH_WATER_MARK, pid, 0, &hwm, sizeof(hwm));

    int32_t taskLimit = TITANIUM_MAX_JETSAM_MB;
    int r2 = mem_ctrl(MEMORYSTATUS_CMD_SET_JETSAM_TASK_LIMIT, pid, 0, &taskLimit, sizeof(taskLimit));

    memorystatus_priority_properties_t props;
    props.priority = JETSAM_PRIORITY_CRITICAL;
    props.user_data = 0;
    int r3 = mem_ctrl(MEMORYSTATUS_CMD_SET_PRIORITY_PROPERTIES, pid, 0, &props, sizeof(props));

    int r4 = mem_ctrl(MEMORYSTATUS_CMD_SET_PROCESS_IS_FREEZABLE, pid, 0, NULL, 0);
    int r5 = mem_ctrl(MEMORYSTATUS_CMD_SET_PROCESS_IS_MANAGED, pid, 0, NULL, 0);

    struct rlimit rl;
    rl.rlim_cur = RLIM_INFINITY;
    rl.rlim_max = RLIM_INFINITY;
    setrlimit(RLIMIT_AS, &rl);
    setrlimit(RLIMIT_DATA, &rl);

    ODLog("jetsam: hwm=%d limit=%d prio=%d freezable=%d managed=%d",
          r1, r2, r3, r4, r5);
}

// ====================================================================================================
// CONVENIENCE — apply everything
// ====================================================================================================
void Titanium_WireAllMemory(void *addr, size_t size) {
    if (!addr || size == 0) return;
    vm_wire(0, mach_task_self(), (vm_address_t)addr,
            (vm_size_t)size, VM_PROT_READ | VM_PROT_WRITE);
}

void Titanium_ApplyAllOverdrive(void) {
    Titanium_OverclockChipAndUnthrottle();
    Titanium_BreakJetsamMemoryLimits();
}
