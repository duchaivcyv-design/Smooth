#import "CacheCleaner.h"
#import <UIKit/UIKit.h>
#import <mach/mach.h>
#import <mach/vm_map.h>
#import <malloc/malloc.h>
#import <dlfcn.h>
#import <sys/stat.h>

// Khai báo extern an toàn cho vm_purgable_control thay vì import mach_vm.h
#ifndef VM_PURGABLE_PURGE_ALL
#define VM_PURGABLE_PURGE_ALL 3
#endif

#ifndef VM_FLAGS_PURGABLE
#define VM_FLAGS_PURGABLE 0x0001
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
}

+ (instancetype)sharedInstance {
    static CacheCleaner *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
    });
    return inst;
}

+ (void)forceMemoryPurge {
    malloc_zone_pressure_relief(NULL, 0);
}

+ (void)forceDeepMemoryPurge {
    malloc_zone_pressure_relief(NULL, 0);
    mach_port_t selfTask = mach_task_self();

    int purgeState = 0;
    vm_purgable_control(selfTask, 0, VM_PURGABLE_PURGE_ALL, &purgeState);

    // Phát thông báo cảnh báo bộ nhớ an toàn trên main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:nil];
    });
}

+ (void)cleanAppTemporaryCaches {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSString *tmpDir = NSTemporaryDirectory();
        NSArray *tmpFiles = [fm contentsOfDirectoryAtPath:tmpDir error:nil];
        for (NSString *file in tmpFiles) {
            if ([file isEqualToString:@".boost_hz_sync"] || [file isEqualToString:@".boost_boot_counter"]) {
                continue;
            }
            [fm removeItemAtPath:[tmpDir stringByAppendingPathComponent:file] error:nil];
        }

        NSArray *cacheDirs = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        if (cacheDirs.count > 0) {
            NSString *cacheDir = cacheDirs.firstObject;
            NSArray *cacheFiles = [fm contentsOfDirectoryAtPath:cacheDir error:nil];
            for (NSString *file in cacheFiles) {
                if ([file containsString:@"WebKit"] || [file containsString:@"Cache.db"]) {
                    [fm removeItemAtPath:[cacheDir stringByAppendingPathComponent:file] error:nil];
                }
            }
        }
    });
}

+ (void)cleanSystemCachesAndSnapshots {
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        NSString *jbRoot = CacheCleaner_GetJbRoot();
        NSString *prefCache = [NSString stringWithFormat:@"%@/var/mobile/Library/Caches/com.taojb.boostiphone6s", jbRoot];
        [[NSFileManager defaultManager] removeItemAtPath:prefCache error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:@"/var/mobile/Library/Caches/com.taojb.boostiphone6s" error:nil];
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
    dispatch_queue_t queue = dispatch_queue_create("com.taojb.cachecleaner.timer", DISPATCH_QUEUE_SERIAL);
    _cleanerTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    uint64_t intervalNs = (uint64_t)(interval * NSEC_PER_SEC);
    dispatch_source_set_timer(_cleanerTimer, dispatch_time(DISPATCH_TIME_NOW, intervalNs), intervalNs, 1.0 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(_cleanerTimer, ^{
        [CacheCleaner forceDeepMemoryPurge];
    });
    dispatch_resume(_cleanerTimer);
}

- (void)stopTimer {
    if (_cleanerTimer) {
        dispatch_source_cancel(_cleanerTimer);
        _cleanerTimer = nil;
    }
}

@end
