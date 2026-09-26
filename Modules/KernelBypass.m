#import "KernelBypass.h"
#import <mach/mach.h>
#import <pthread.h>
#import <sched.h>

@implementation KernelBypass {
    mach_port_t _hostPort;
    BOOL _ready;
}

+ (instancetype)sharedInstance {
    static KernelBypass *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)initEnvironment {
    if (_ready) return;
    _hostPort = mach_host_self();
    _ready = (_hostPort != MACH_PORT_NULL);
}

- (void)boostCurrentThreadPriority {
    struct sched_param param;
    int policy = SCHED_RR;
    param.sched_priority = sched_get_priority_max(policy);
    pthread_setschedparam(pthread_self(), policy, &param);
}

- (void)forceMachPurge {
    if (!_ready) return;
    vm_statistics_data_t stats;
    mach_msg_type_number_t count = HOST_VM_INFO_COUNT;
    host_statistics(_hostPort, HOST_VM_INFO, (host_info_t)&stats, &count);
}

@end
