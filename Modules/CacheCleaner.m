#import "CacheCleaner.h"
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <malloc/malloc.h>
#import <dlfcn.h>
#import <sys/stat.h>

#ifndef VM_PURGABLE_PURGE_ALL
#define VM_PURGABLE_PURGE_ALL 0
#endif

#ifdef __cplusplus
extern "C" {
#endif
kern_return_t vm_purgable_control(vm_map_t target_task, vm_address_t address, vm_purgable_t control, int *state);
#ifdef __cplusplus
}
#endif

static inline NSString *CacheCleaner_GetJbRoot(void) {
    static NSString *cachedRoot = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Dl_info info;
        if (dladdr((const void *)CacheCleaner_GetJbRoot, &info) && info.dli_fname) {
            NSString *dylibPath = [NSString stringWithUTF8String:info.dli_fname];
            NSRange range = [dylibPath rangeOfString:@"/var/jb"];
            if (range.location != NSNotFound) {
                NSRange sub = [dylibPath rangeOfString:@"/" options:0 range:NSMakeRange(range.location + 7, dylibPath.length - (range.location + 7))];
                cachedRoot = (sub.location != NSNotFound) ? [dylibPath substringToIndex:sub.location] : @"/var/jb";
            } else {
                cachedRoot = @"/var/jb";
            }
        } else {
            cachedRoot = @"/var/jb";
        }
    });
    return cachedRoot;
}

@implementation CacheCleaner {
    dispatch_source_t _cleanerTimer;
    dispatch_queue_t _workerQueue;
}

+ (instancetype)sharedInstance {
    static CacheCleaner *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // Hàng đợi Background cô lập hoàn toàn: Không chiếm tài nguyên mạng và P-Core
        _workerQueue = dispatch_queue_create("com.taojb.cachecleaner.worker", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_workerQueue, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0));
    }
    return self;
}

+ (void)forceMemoryPurge {
    malloc_zone_pressure_relief(NULL, 0);
}

+ (void)forceDeepMemoryPurge {
    // 1. Giải phóng vùng nhớ không sử dụng của Malloc
    malloc_zone_pressure_relief(NULL, 0);

    // 2. Thu hồi trang nhớ Purgeable của Task hiện tại theo mã chuẩn XNU
    mach_port_t selfTask = mach_task_self();
    int purgeState = 0;
    vm_purgable_control(selfTask, 0, VM_PURGABLE_PURGE_ALL, &purgeState);

    // 3. Xóa URL Cache đã lưu trong bộ nhớ RAM của tiến trình (giải phóng RAM mà không ngắt kết nối socket)
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

+ (void)cleanAppTemporaryCaches {
    dispatch_async([self sharedInstance]->_workerQueue, ^{
        @autoreleasepool {
            NSFileManager *fm = [NSFileManager defaultManager];
            
            // DỌN DẸP THƯ MỤC TẠM NSTemporaryDirectory
            NSString *tmpDir = NSTemporaryDirectory();
            if (tmpDir) {
                NSArray *tmpFiles = [fm contentsOfDirectoryAtPath:tmpDir error:nil];
                for (NSString *file in tmpFiles) {
                    // Bảo vệ tuyệt đối các tệp IPC đồng bộ cấu hình và file socket
                    if ([file hasPrefix:@".boost_"] || 
                        [file hasPrefix:@".titanium_"] || 
                        [file hasSuffix:@".sock"]) {
                        continue;
                    }
                    [fm removeItemAtPath:[tmpDir stringByAppendingPathComponent:file] error:nil];
                }
            }

            // DỌN DẸP BỘ ĐỆM AN TOÀN (KHÔNG CHẠM VÀO SOCKET WEBKIT ĐANG STREAMING)
            NSArray *cacheDirs = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
            if (cacheDirs.count > 0) {
                NSString *cacheDir = cacheDirs.firstObject;
                NSArray *cacheFiles = [fm contentsOfDirectoryAtPath:cacheDir error:nil];
                for (NSString *file in cacheFiles) {
                    // BẢO VỆ MẠNG: Chỉ xóa Cache.db cũ hoặc snapshot rác, KHÔNG xóa thư mục WebKit đang active
                    if ([file isEqualToString:@"Cache.db"] || [file isEqualToString:@"Cache.db-wal"]) {
                        [fm removeItemAtPath:[cacheDir stringByAppendingPathComponent:file] error:nil];
                    }
                }
            }
        }
    });
}

+ (void)cleanSystemCachesAndSnapshots {
    dispatch_async([self sharedInstance]->_workerQueue, ^{
        @autoreleasepool {
            NSString *jbRoot = CacheCleaner_GetJbRoot();
            NSString *prefCache = [NSString stringWithFormat:@"%@/var/mobile/Library/Caches/com.taojb.boostiphone6s", jbRoot];
            [[NSFileManager defaultManager] removeItemAtPath:prefCache error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Caches/com.taojb.boostiphone6s" error:nil];
            
            // Xóa snapshot giao diện cũ của SpringBoard để giải phóng bộ nhớ đệm hình ảnh
            [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Caches/Snapshots" error:nil];
        }
    });
}

+ (void)startPeriodicCleanerWithInterval:(NSTimeInterval)interval {
    [[self sharedInstance] startTimer:interval];
}

+ (void)stopPeriodicCleaner {
    [[self sharedInstance] stopTimer];
}

- (void)startTimer:(NSTimeInterval)interval {
    [self stopTimer];

    // Khóa trần an toàn tối thiểu 30s để tránh làm thức CPU liên tục gây nóng máy
    if (interval < 30.0) {
        interval = 30.0;
    }

    _cleanerTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _workerQueue);
    if (!_cleanerTimer) return;

    uint64_t intervalNs = (uint64_t)(interval * NSEC_PER_SEC);
    // Cho phép độ trễ nới lỏng (leeway 5s) để kernel gom tác vụ dọn dẹp, tiết kiệm tối đa pin
    dispatch_source_set_timer(_cleanerTimer, 
                              dispatch_time(DISPATCH_TIME_NOW, intervalNs), 
                              intervalNs, 
                              (uint64_t)(5.0 * NSEC_PER_SEC));

    dispatch_source_set_event_handler(_cleanerTimer, ^{
        [CacheCleaner forceDeepMemoryPurge];
        [CacheCleaner cleanAppTemporaryCaches];
    });

    dispatch_resume(_cleanerTimer);
}

- (void)stopTimer {
    if (_cleanerTimer) {
        dispatch_source_cancel(_cleanerTimer);
        _cleanerTimer = nil;
    }
}

- (void)dealloc {
    [self stopTimer];
}

@end
