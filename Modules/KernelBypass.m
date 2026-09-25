#import "KernelBypass.h"
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <pthread.h>
#import <sched.h>
#import <spawn.h>
#import <sys/resource.h>

// environ declaration cho posix_spawn trên iOS 26 SDK
extern char **environ;

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
        self->_hostPort = mach_host_self();
        
        if (self->_hostPort != MACH_PORT_NULL) {
            self->_environmentReady = YES;
            NSLog(@"[KernelBypass] Environment initialized (host_port: %u)", self->_hostPort);
        } else {
            NSLog(@"[KernelBypass] Failed to get host port");
        }
        
        NSDictionary *stats = [self getVMStatistics];
        NSLog(@"[KernelBypass] Initial VM Stats - Free: %@ | Active: %@ | Inactive: %@",
              stats[@"free_count"], stats[@"active_count"], stats[@"inactive_count"]);
    });
}

- (void)boostCurrentThreadPriority {
    struct sched_param param;
    int policy = SCHED_RR;
    int maxPriority = sched_get_priority_max(policy);
    
    if (maxPriority <= 0) {
        maxPriority = 47;
    }
    
    param.sched_priority = maxPriority;
    
    int result = pthread_setschedparam(pthread_self(), policy, &param);
    
    if (result == 0) {
        NSLog(@"[KernelBypass] Thread priority boosted to %d (SCHED_RR)", maxPriority);
    } else {
        NSLog(@"[KernelBypass] Failed to boost thread priority (errno: %d)", result);
        if (setpriority(PRIO_PROCESS, 0, -20) == 0) {
            NSLog(@"[KernelBypass] Fallback: nice value set to -20");
        }
    }
}

- (void)forceMachPurge {
    if (!_environmentReady) {
        NSLog(@"[KernelBypass] Environment not ready, call initEnvironment first");
        return;
    }
    
    dispatch_async(_kernelQueue, ^{
        vm_statistics_data_t vmStatsBefore;
        mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
        
        kern_return_t kr = host_statistics(self->_hostPort, HOST_VM_INFO,
                                           (host_info_t)&vmStatsBefore, &infoCount);
        
        if (kr != KERN_SUCCESS) {
            NSLog(@"[KernelBypass] Failed to read VM stats before purge (kr: %d)", kr);
            return;
        }
        
        NSLog(@"[KernelBypass] Before purge - Free: %u | Active: %u | Inactive: %u",
              vmStatsBefore.free_count, vmStatsBefore.active_count, vmStatsBefore.inactive_count);
        
        // ★ FIX: Dùng posix_spawn thay vì dlopen/system() ★
        // iOS 26 SDK block dlopen/dlsym nhưng posix_spawn vẫn hoạt động bình thường
        pid_t pid;
        const char *argv[] = {"purge", NULL};
        int spawnResult = posix_spawn(&pid, "/usr/bin/purge", NULL, NULL, (char *const *)argv, environ);
        
        if (spawnResult == 0) {
            int status;
            waitpid(pid, &status, 0);
            NSLog(@"[KernelBypass] Purge command executed via posix_spawn");
        } else {
            NSLog(@"[KernelBypass] posix_spawn failed for purge (errno: %d)", spawnResult);
        }
        
        vm_statistics_data_t vmStatsAfter;
        infoCount = HOST_VM_INFO_COUNT;
        kr = host_statistics(self->_hostPort, HOST_VM_INFO,
                             (host_info_t)&vmStatsAfter, &infoCount);
        
        if (kr == KERN_SUCCESS) {
            uint32_t freedPages = vmStatsAfter.free_count - vmStatsBefore.free_count;
            float freedMB = (freedPages * 4096.0f) / (1024.0f * 1024.0f);
            
            NSLog(@"[KernelBypass] After purge - Free: %u | Freed: %.1f MB",
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
                @"wire_count": @(vmStats.wire_count)
            };
        } else {
            result = @{
                @"free_count": @0,
                @"active_count": @0,
                @"inactive_count": @0,
                @"wire_count": @0
            };
        }
    });
    
    return result ?: @{};
}

- (void)boostGPUThreadPriority {
    struct sched_param param;
    int policy = SCHED_RR;
    int maxPriority = sched_get_priority_max(policy);
    
    if (maxPriority <= 0) maxPriority = 47;
    
    param.sched_priority = maxPriority - 1;
    
    int result = pthread_setschedparam(pthread_self(), policy, &param);
    
    if (result == 0) {
        NSLog(@"[KernelBypass] GPU thread priority boosted to %d", param.sched_priority);
    } else {
        NSLog(@"[KernelBypass] Failed to boost GPU thread priority (errno: %d)", result);
    }
}

@end
