#import "KernelBypass.h"
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <pthread.h>
#import <sched.h>

@implementation KernelBypass {
    mach_port_t _hostPort;
    BOOL _environmentReady;
    dispatch_queue_t _kernelQueue;
}

+ (instancetype)sharedInstance {
    static KernelBypass *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _hostPort = MACH_PORT_NULL;
        _environmentReady = NO;
        _kernelQueue = dispatch_queue_create("com.boostiphone6s.kernelbypass", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)initEnvironment {
    if (_environmentReady) return;
    
    dispatch_sync(_kernelQueue, ^{
        // Lấy host port cho Mach operations
        self->_hostPort = mach_host_self();
        
        if (self->_hostPort != MACH_PORT_NULL) {
            self->_environmentReady = YES;
            NSLog(@"[KernelBypass] ✅ Environment initialized (host_port: %u)", self->_hostPort);
        } else {
            NSLog(@"[KernelBypass] ⚠️ Failed to get host port");
        }
        
        // Log VM statistics ban đầu
        NSDictionary *stats = [self getVMStatistics];
        NSLog(@"[KernelBypass] Initial VM Stats - Free: %@ | Active: %@ | Inactive: %@ | Wired: %@",
              stats[@"free_count"], stats[@"active_count"],
              stats[@"inactive_count"], stats[@"wire_count"]);
    });
}

- (void)boostCurrentThreadPriority {
    struct sched_param param;
    int policy = SCHED_RR;
    
    // Lấy priority max cho SCHED_RR
    int maxPriority = sched_get_priority_max(policy);
    
    if (maxPriority <= 0) {
        // Fallback: dùng giá trị mặc định
        maxPriority = 47; // Giá trị phổ biến trên iOS
    }
    
    param.sched_priority = maxPriority;
    
    int result = pthread_setschedparam(pthread_self(), policy, &param);
    
    if (result == 0) {
        NSLog(@"[KernelBypass] ✅ Thread priority boosted to %d (SCHED_RR)", maxPriority);
    } else {
        NSLog(@"[KernelBypass] ⚠️ Failed to boost thread priority (errno: %d)", result);
        
        // Fallback: thử tăng nice value
        if (setpriority(PRIO_PROCESS, 0, -20) == 0) {
            NSLog(@"[KernelBypass] ✅ Fallback: nice value set to -20");
        }
    }
}

- (void)forceMachPurge {
    if (!_environmentReady) {
        NSLog(@"[KernelBypass] ⚠️ Environment not ready, call initEnvironment first");
        return;
    }
    
    dispatch_async(_kernelQueue, ^{
        // Đọc stats trước purge
        vm_statistics_data_t vmStatsBefore;
        mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
        
        kern_return_t kr = host_statistics(self->_hostPort, HOST_VM_INFO,
                                           (host_info_t)&vmStatsBefore, &infoCount);
        
        if (kr != KERN_SUCCESS) {
            NSLog(@"[KernelBypass] ⚠️ Failed to read VM stats before purge (kr: %d)", kr);
            return;
        }
        
        NSLog(@"[KernelBypass] Before purge - Free: %u | Active: %u | Inactive: %u",
              vmStatsBefore.free_count, vmStatsBefore.active_count, vmStatsBefore.inactive_count);
        
        // Thực hiện purge qua system command
        // (Mach API không cung cấp direct purge, phải dùng purge command)
        extern int safe_system(const char *); // Từ CacheCleaner
        
        // Gọi trực tiếp qua dlsym
        typedef int (*sys_func)(const char *);
        void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
        if (handle) {
            sys_func sys = (sys_func)dlsym(handle, "system");
            if (sys) {
                sys("purge");
            }
            dlclose(handle);
        }
        
        // Đọc stats sau purge
        vm_statistics_data_t vmStatsAfter;
        infoCount = HOST_VM_INFO_COUNT;
        kr = host_statistics(self->_hostPort, HOST_VM_INFO,
                             (host_info_t)&vmStatsAfter, &infoCount);
        
        if (kr == KERN_SUCCESS) {
            uint32_t freedPages = vmStatsAfter.free_count - vmStatsBefore.free_count;
            float freedMB = (freedPages * 4096.0) / (1024.0 * 1024.0); // Giả sử page size 4KB
            
            NSLog(@"[KernelBypass] ✅ After purge - Free: %u | Freed: %.1f MB",
                  vmStatsAfter.free_count, freedMB);
        }
    });
}

- (NSDictionary *)getVMStatistics {
    if (!_environmentReady) {
        return @{
            @"free_count": @0,
            @"active_count": @0,
            @"inactive_count": @0,
            @"wire_count": @0
        };
    }
    
    __block NSDictionary *result = nil;
    
    dispatch_sync(_kernelQueue, ^{
        vm_statistics_data_t vmStats;
        mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
        
        kern_return_t kr = host_statistics(self->_hostPort, HOST_VM_INFO,
                                           (host_info_t)&vmStats, &infoCount);
        
        if (kr == KERN_SUCCESS) {
            result = @{
                @"free_count": @(vmStats.free_count),
                @"active_count": @(vmStats.active_count),
                @"inactive_count": @(vmStats.inactive_count),
                @"wire_count": @(vmStats.wire_count),
                @"page_size": @(vm_kernel_page_size)
            };
        } else {
            result = @{
                @"free_count": @0,
                @"active_count": @0,
                @"inactive_count": @0,
                @"wire_count": @0,
                @"error": @(kr)
            };
        }
    });
    
    return result ?: @{};
}

- (void)boostGPUThreadPriority {
    // GPU threads thường chạy trên QOS_CLASS_USER_INTERACTIVE
    // Boost lên cao nhất có thể
    
    struct sched_param param;
    int policy = SCHED_RR;
    int maxPriority = sched_get_priority_max(policy);
    
    if (maxPriority <= 0) maxPriority = 47;
    
    // Giảm 1 bậc so với max để tránh chiếm hoàn toàn CPU
    param.sched_priority = maxPriority - 1;
    
    int result = pthread_setschedparam(pthread_self(), policy, &param);
    
    if (result == 0) {
        NSLog(@"[KernelBypass] ✅ GPU thread priority boosted to %d", param.sched_priority);
    } else {
        NSLog(@"[KernelBypass] ⚠️ Failed to boost GPU thread priority (errno: %d)", result);
    }
}

@end
