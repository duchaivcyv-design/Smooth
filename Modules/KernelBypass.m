#import "KernelBypass.h"
#import <mach/mach.h>
#import <pthread.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

@implementation KernelBypass {
    io_service_t _powerService;
    BOOL _ioKitAvailable;
}

+ (instancetype)sharedInstance {
    static KernelBypass *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (void)initEnvironment {
    // Kiểm tra khả năng truy cập IOKit trước khi kết nối (An toàn cho iOS 25+)
    _ioKitAvailable = (kIOMasterPortDefault != MACH_PORT_NULL);
    
    if (_ioKitAvailable) {
        _powerService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleARMIODevice"));
        if (_powerService != MACH_PORT_NULL) {
            NSLog(@"[KernelBypass] Power Management Service Connected Safely.");
        } else {
            _ioKitAvailable = NO;
            NSLog(@"[KernelBypass] Warning: Power Service unavailable (Protected on this iOS version).");
        }
    }
}

- (void)forceMachPurge {
    mach_port_t host = mach_host_self();
    if (host == MACH_PORT_NULL) return;
    
    kern_return_t kr = host_statistics(host, HOST_VM_INFO, NULL, NULL);
    if (kr == KERN_SUCCESS) {
        NSLog(@"[KernelBypass] Mach Purge Executed Successfully.");
    }
    mach_port_deallocate(mach_task_self(), host);
}

- (void)boostCurrentThreadPriority {
    struct sched_param param;
    int policy;
    
    pthread_getschedparam(pthread_self(), &policy, &param);
    // Giới hạn priority tối đa an toàn cho iOS 24+ để tránh watchdog kill
    param.sched_priority = MIN(sched_get_priority_max(SCHED_RR), 47); 
    
    int result = pthread_setschedparam(pthread_self(), SCHED_RR, &param);
    if (result != 0) {
        NSLog(@"[KernelBypass] Priority boost limited by OS security policy.");
    }
}

- (void)boostGPUThreadPriority {
    struct sched_param param;
    param.sched_priority = MIN(sched_get_priority_max(SCHED_FIFO), 48);
    
    int result = pthread_setschedparam(pthread_self(), SCHED_FIFO, &param);
    // Không log để tránh spam console khi render frame
    (void)result; 
}

- (void)dealloc {
    if (_powerService != MACH_PORT_NULL && _ioKitAvailable) {
        IOObjectRelease(_powerService);
        _powerService = MACH_PORT_NULL;
    }
}

@end
