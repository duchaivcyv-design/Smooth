#import "KernelBypass.h"
#import <mach/mach.h>
#import <pthread.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <Foundation/Foundation.h>

@implementation KernelBypass {
    io_service_t _powerService;
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
    // Khởi tạo kết nối IOKit Power Management để can thiệp sâu vào CPU/GPU
    _powerService = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching("AppleARMIODevice"));
    
    if (_powerService != MACH_PORT_NULL) {
        NSLog(@"[KernelBypass] Power Management Service Connected.");
    } else {
        NSLog(@"[KernelBypass] Warning: Could not connect to Power Management Service.");
    }
}

- (void)forceMachPurge {
    // Ép giải phóng bộ nhớ vật lý ngay lập tức qua Mach Port
    mach_port_t host = mach_host_self();
    kern_return_t kr = host_statistics(host, HOST_VM_INFO, NULL, NULL);
    
    if (kr == KERN_SUCCESS) {
        NSLog(@"[KernelBypass] Mach Purge Executed Successfully.");
    } else {
        NSLog(@"[KernelBypass] Mach Purge Failed with code: %d", kr);
    }
    
    mach_port_deallocate(mach_task_self(), host);
}

- (void)boostCurrentThreadPriority {
    // Nâng priority luồng hiện tại lên Realtime (cao nhất có thể trên iOS)
    struct sched_param param;
    int policy;
    
    pthread_getschedparam(pthread_self(), &policy, &param);
    param.sched_priority = sched_get_priority_max(SCHED_RR);
    
    int result = pthread_setschedparam(pthread_self(), SCHED_RR, &param);
    if (result == 0) {
        NSLog(@"[KernelBypass] Thread Priority Boosted to Realtime (SCHED_RR).");
    } else {
        NSLog(@"[KernelBypass] Failed to boost thread priority: %d", result);
    }
}

// ★★★ V6.0 NEW: BOOST GPU THREAD PRIORITY ★★★
- (void)boostGPUThreadPriority {
    // Hàm này được gọi trực tiếp từ hooked_gpu_driver_submitCommand trong Tweak.xm
    // Giúp đảm bảo lệnh render GPU được xử lý trước các tác vụ nền khác
    
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    
    // SCHED_FIFO an toàn hơn SCHED_RR cho GPU rendering vì không bị抢占 bởi cùng mức độ ưu tiên
    int result = pthread_setschedparam(pthread_self(), SCHED_FIFO, &param);
    
    if (result == 0) {
        // Chỉ log khi debug, tránh spam console khi chơi game
        // NSLog(@"[KernelBypass] GPU Thread Priority Set to SCHED_FIFO Max.");
    }
}

- (void)dealloc {
    if (_powerService != MACH_PORT_NULL) {
        IOObjectRelease(_powerService);
        _powerService = MACH_PORT_NULL;
    }
}

@end
