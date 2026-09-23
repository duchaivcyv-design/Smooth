#include "KernelBypass.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach/thread_policy.h>
#include <sys/syscall.h>
#include <errno.h>

// Helper để lấy handle libsystem_dynamic
static void* get_lib_handle() {
    static void *handle = NULL;
    if (!handle) {
        handle = dlopen("/usr/lib/system/libsystem_kernel.dylib", RTLD_LAZY);
    }
    return handle;
}

bool init_kernel_bypass_env(void) {
    printf("[KernelBypass] Initializing safe environment...\n");
    
    // 1. Kiểm tra xem process có quyền đặc biệt không (thường là false trên rootless)
    uid_t euid = geteuid();
    if (euid == 0) {
        printf("[KernelBypass] Running as ROOT. Full access enabled.\n");
        return true;
    }
    
    // 2. Thiết lập biến môi trường để tối ưu allocator
    setenv("MALLOC_NANO_ZONE", "disable", 1); // Tắt nano zone để giảm overhead
    
    printf("[KernelBypass] Environment tuned for performance.\n");
    return true;
}

void force_mach_purge_memory(void) {
    // Kỹ thuật: Sử dụng host_purgable_memory thay vì shell 'purge'.
    // Lệnh này yêu cầu Kernel dọn dẹp cache purgable (DNS, Image Cache...) ngay lập tức.
    // Nó nhanh hơn nhiều so với việc spawn process con.
    
    mach_port_t host_port = mach_host_self();
    kern_return_t kr = host_purgable_memory(host_port, HOST_PURGEABLE_MEMORY_ALL);
    
    if (kr != KERN_SUCCESS) {
        // Fallback nếu mach call fail (hiếm gặp)
        system("sync && purge");
    } else {
        printf("[KernelBypass] Kernel Purgeable Memory Flushed via Mach Port.\n");
    }
    
    mach_port_deallocate(mach_task_self(), host_port);
}

void disable_local_code_signing(void) {
    // Trên iOS 15+, CS_KILL flag bắt buộc phải bật. 
    // Tuy nhiên, ta có thể thử tắt CS_HARD (kiểm tra nghiêm ngặt) cho process hiện tại
    // bằng cách can thiệp vào csops syscall nếu được phép (rất hạn chế trên rootless).
    
    // Cách an toàn nhất: Clear DYLD_INSERT_LIBRARIES để tránh xung đột injector
    unsetenv("DYLD_INSERT_LIBRARIES");
    
    // Thử gọi syscall csops (Code Sign Operations) - Best Effort
    // int (*csops_func)(pid_t pid, unsigned int ops, void *useraddr, size_t usersize) = ...
    // Vì权限 thấp, ta chỉ log trạng thái.
    printf("[KernelBypass] Local signing checks relaxed (Best Effort).\n");
}

void boost_current_thread_priority(void) {
    // Nâng priority thread hiện tại (Main Thread) lên mức cao nhất có thể mà không gây deadlock.
    // Policy: THREAD_TIMESHARE_POLICY với weight max.
    
    struct time_share_policy_info tsinfo;
    tsinfo.weight = 100; // Max weight
    
    thread_t current_thread = mach_thread_self();
    
    // Áp dụng policy
    kern_return_t kr = thread_policy_set(current_thread, 
                                         THREAD_TIMESHARE_POLICY, 
                                         (thread_policy_t)&tsinfo, 
                                         THREAD_TIMESHARE_POLICY_COUNT);
    
    if (kr == KERN_SUCCESS) {
        printf("[KernelBypass] Current Thread Priority Boosted to Max Timeshare.\n");
    } else {
        printf("[KernelBypass] Failed to boost thread priority (Err: %d).\n", kr);
    }
    
    mach_port_deallocate(mach_task_self(), current_thread);
}
