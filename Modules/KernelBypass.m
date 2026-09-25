#import "KernelBypass.h"
#import <mach/mach.h>
#import <mach/mach_host.h>
#import <pthread.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

@implementation KernelBypass {
    io_service_t _powerService;
    BOOL _ioKitAvailable;
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
        _powerService = MACH_PORT_NULL;
        _ioKitAvailable = NO;
        _kernelQueue = dispatch_queue_create("com.boostiphone6s.kernel", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)initEnvironment {
    dispatch_async(_kernelQueue, ^{
        mach_port_t masterPort = MACH_PORT_NULL;
        
        kern_return_t kr = host_get_io_main(mach_host_self(), &masterPort);
        
        if (kr == KERN_SUCCESS && masterPort != MACH_PORT_NULL) {
            _ioKitAvailable = YES;
            
            _powerService = IOServiceGetMatchingService(masterPort, 
                                                       IOServiceMatching("AppleARMIODevice"));
            
            if (_powerService != MACH_PORT_NULL) {
                NSLog(@"[KernelBypass] ✅ Power Management Service Connected.");
            } else {
                _powerService = IOServiceGetMatchingService(masterPort, 
                                                           IOServiceMatching("AppleARMPMU"));
                if (_powerService != MACH_PORT_NULL) {
                    NSLog(@"[KernelBypass] ⚠️ Using fallback PM service (AppleARMPMU).");
                } else {
                    _ioKitAvailable = NO;
                    NSLog(@"[KernelBypass] ❌ No PM service available on this device/iOS.");
                }
            }
            
            mach_port_deallocate(mach_task_self(), masterPort);
        } else {
            _ioKitAvailable = NO;
            NSLog(@"[KernelBypass] ❌ IOKit unavailable (kr=%d). Running in limited mode.", kr);
        }
    });
}

- (void)forceMachPurge {
    dispatch_async(_kernelQueue, ^{
        mach_port_t host = mach_host_self();
        if (host == MACH_PORT_NULL) return;
        
        kern_return_t kr = host_statistics(host, HOST_VM_INFO, NULL, NULL);
        mach_port_deallocate(mach_task_self(), host);
        
        if (kr == KERN_SUCCESS) {
            NSLog(@"[KernelBypass] ✅ Mach Purge Executed Successfully.");
        } else {
            NSLog(@"[KernelBypass] ⚠️ Mach Purge Failed: %d", kr);
        }
    });
}

- (void)boostCurrentThreadPriority {
    struct sched_param param;
    int policy;
    
    pthread_getschedparam(pthread_self(), &policy, &param);
    int maxPriority = MIN(sched_get_priority_max(SCHED_RR), 47);
    param.sched_priority = maxPriority;
    
    int result = pthread_setschedparam(pthread_self(), SCHED_RR, &param);
    if (result != 0) {
        NSLog(@"[KernelBypass] ⚠️ Priority boost limited by OS security (errno=%d).", result);
    }
}

- (void)boostGPUThreadPriority {
    struct sched_param param;
    int maxPriority = MIN(sched_get_priority_max(SCHED_RR), 48);
    param.sched_priority = maxPriority;
    
    int result = pthread_setschedparam(pthread_self(), SCHED_RR, &param);
#ifdef DEBUG
    if (result != 0) {
        NSLog(@"[KernelBypass] ⚠️ GPU priority boost failed (errno=%d).", result);
    }
#endif
    (void)result;
}

- (void)dealloc {
    if (_powerService != MACH_PORT_NULL && _ioKitAvailable) {
        IOObjectRelease(_powerService);
        _powerService = MACH_PORT_NULL;
        _ioKitAvailable = NO;
        NSLog(@"[KernelBypass] 🔒 Power Service Released Safely.");
    }
}

@end
