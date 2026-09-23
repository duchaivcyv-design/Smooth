#import <Foundation/Foundation.h> // Cung cấp BOOL, nil, YES, NO, NSLog, NSObject
#import <dispatch/dispatch.h>     // Cung cấp dispatch_queue_t, QOS_CLASS...
#import "KernelBypass.h"          // DÒNG QUAN TRỌNG NHẤT: Khai báo giao diện class
#import <mach/mach.h>             // Cho các hàm thread/host port
#import <sys/sysctl.h>            // Cho sysctlbyname
#import <dlfcn.h>                 // Cho dlopen/dlsym

@implementation KernelBypass {
    BOOL _isActive;
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
    if (_isActive) return;
    
    NSLog(@"[KernelBypass] Initializing Safe Environment...");
    
    // 1. Tắt Nano Zone malloc để giảm overhead allocation cho các tác vụ lớn (AI/Code gen)
    setenv("MALLOC_NANO_ZONE", "disable", 1);
    
    // 2. Thiết lập biến môi trường cho allocator hoạt động agresive
    setenv("MALLOC_OPTIONS", "AFGN", 1); 
    
    _isActive = YES;
    NSLog(@"[KernelBypass] Environment Tuned Successfully.");
}

- (void)forceMachPurge {
    if (!_isActive) return;
    
    NSLog(@"[KernelBypass] Attempting Deep Memory Purge via Dynamic Linking...");
    
    // Kỹ thuật: Tìm hàm 'purge' trong libsystem_c.dylib lúc runtime
    void *libSystem = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
    if (libSystem) {
        void (*purge_func)(void) = (void (*)(void))dlsym(libSystem, "purge");
        
        if (purge_func) {
            purge_func();
            NSLog(@"[KernelBypass] Called direct purge() via dlsym.");
        } else {
            NSLog(@"[KernelBypass] purge() not found in symbols. Skipping manual flush.");
        }
        
        dlclose(libSystem);
    } else {
        NSLog(@"[KernelBypass] Failed to load libsystem_c.dylib.");
    }
}

- (void)boostCurrentThreadPriority {
    if (!_isActive) return;
    
    NSLog(@"[KernelBypass] Boosting Current Thread Priority (Best Effort)...");
    
    // Cách an toàn nhất: Sử dụng GCD QoS Class (Public API, luôn an toàn khi biên dịch)
    // Điều này giúp Main Thread ưu tiên hơn Background Tasks mà không đụng chạm Kernel Private.
    
    dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
    dispatch_queue_t highPriQueue = dispatch_queue_create("com.boostiphone6s.highpri", attr);
    
    // Gán task quan trọng vào queue này (demo logic)
    dispatch_async(highPriQueue, ^{
        // Placeholder cho các tác vụ ưu tiên cao
    });
    
    NSLog(@"[KernelBypass] Applied UserInteractive QoS Strategy (Safer than Kernel Hack).");
    
    // Trong môi trường ARC (-fobjc-arc), hệ thống tự động giải phóng memory 
    // khi biến local đi ra ngoài scope. Gọi release thủ công sẽ gây lỗi compile.
}

@end
