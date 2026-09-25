#import "CacheCleaner.h"
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <sys/stat.h>
#include <pthread.h>

// ★ GLOBAL CALLBACK CHO PTHREAD_ONCE - SCOPE FILE LEVEL ★
static int (*g_cached_system)(const char *) = NULL;
static pthread_once_t g_system_init_once = PTHREAD_ONCE_INIT;

static void cached_system_init(void) {
    typedef int (*sys_func)(const char*);
    void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
    if (handle) {
        g_cached_system = (sys_func)dlsym(handle, "system");
    }
}

static int safe_exec(const char *cmd) {
    pthread_once(&g_system_init_once, cached_system_init);
    return g_cached_system ? g_cached_system(cmd) : -1;
}

@implementation CacheCleaner

+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path {
    NSString *safePath = path;
    if ([path hasPrefix:@"/var/jb/var/mobile"]) {
        safePath = [path stringByReplacingOccurrencesOfString:@"/var/jb/var/mobile" withString:@"/var/mobile"];
    } else if ([path hasPrefix:@"/private/var/mobile"]) {
        safePath = [path stringByReplacingOccurrencesOfString:@"/private/var/mobile" withString:@"/var/mobile"];
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:safePath isDirectory:&isDir] || !isDir) return 0;

    NSError *error = nil;
    NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:safePath error:&error];
    if (error || !contents) return 0;

    unsigned long long freedBytes = 0;
    NSUInteger count = 0;

    for (NSString *item in contents) {
        if ([item isEqualToString:@".DS_Store"] || [item isEqualToString:@".localized"]) continue;

        NSString *fullPath = [safePath stringByAppendingPathComponent:item];
        struct stat sb;
        if (lstat([fullPath UTF8String], &sb) != 0) continue;

        BOOL isSubDir = S_ISDIR(sb.st_mode);

        if (isSubDir) {
            unsigned long long dirSize = [self getDirectorySize:fullPath];
            if ([fm removeItemAtPath:fullPath error:nil]) {
                freedBytes += dirSize;
                count++;
            }
        } else {
            unsigned long long fileSize = (unsigned long long)sb.st_size;
            if ([fm removeItemAtPath:fullPath error:nil]) {
                freedBytes += fileSize;
                count++;
            }
        }
    }

    if (count > 0) {
        NSLog(@"[CacheCleaner] 🧹 Cleaned %@: %lu items, %.2f MB freed",
              safePath.lastPathComponent, (unsigned long)count, freedBytes / 1024.0 / 1024.0);
    }

    return freedBytes;
}

+ (unsigned long long)getDirectorySize:(NSString *)path {
    unsigned long long size = 0;
    struct stat sb;

    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
    NSString *fileName;

    while ((fileName = [enumerator nextObject])) {
        NSString *fullPath = [path stringByAppendingPathComponent:fileName];
        if (lstat([fullPath UTF8String], &sb) == 0 && !S_ISDIR(sb.st_mode)) {
            size += (unsigned long long)sb.st_size;
        }
    }
    return size;
}

// ★ SỬA: TRẢ VỀ unsigned long long THAY VÌ void ★
+ (unsigned long long)cleanupTempFiles {
    NSArray *junkPaths = @[
        @"/var/mobile/Library/Caches/com.apple.Safari",
        @"/var/mobile/Library/Caches/com.apple.WebKit.Networking",
        @"/var/mobile/Library/Caches/com.apple.WebKit.ProcessPool",
        @"/var/mobile/Library/Caches/Snapshots",
        @"/var/tmp",
        @"/var/mobile/Library/Logs/CrashReporter",
        @"/var/mobile/Library/Logs/MobileGestalt",
        @"/var/mobile/Library/Caches/com.apple.UIKit.keyboardCache",
        @"/var/mobile/Library/Caches/com.apple.nsurlsessiond"
    ];

    unsigned long long totalFreed = 0;
    for (NSString *p in junkPaths) {
        totalFreed += [self cleanDirectoryAtPath:p];
    }

    if (totalFreed > 0) {
        NSLog(@"[CacheCleaner] ✅ Total Cleanup Complete: %.2f MB Freed", totalFreed / 1024.0 / 1024.0);
    }

    return totalFreed;
}

+ (void)forceMemoryPurge {
    safe_exec("sync && purge");
    NSLog(@"[CacheCleaner] 💨 Standard Memory Purge Executed.");
}

+ (void)forceDeepMemoryPurge {
    mach_port_t host = mach_host_self();
    if (host != MACH_PORT_NULL) {
        vm_statistics_data_t vmStats;
        mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
        kern_return_t kr = host_statistics(host, HOST_VM_INFO, (host_info_t)&vmStats, &infoCount);
        mach_port_deallocate(mach_task_self(), host);

        if (kr == KERN_SUCCESS) {
            NSLog(@"[CacheCleaner] 🔥 Deep Memory Purge | Free pages: %u | Active: %u | Inactive: %u",
                  vmStats.free_count, vmStats.active_count, vmStats.inactive_count);
        } else {
            NSLog(@"[CacheCleaner] ⚠️ Deep Memory Purge Failed: %d", kr);
        }
    }

    safe_exec("sync && purge");
}

+ (void)clearURLCache {
    NSURLCache *cache = [NSURLCache sharedURLCache];
    [cache removeAllCachedResponses];
    NSLog(@"[CacheCleaner] 🌐 URL Cache Cleared.");
}

+ (void)clearImageCache {
    Class cacheClass = NSClassFromString(@"UIImageCache");
    if (cacheClass) {
        SEL sel = NSSelectorFromString(@"sharedImageCache");
        if ([cacheClass respondsToSelector:sel]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id cache = [cacheClass performSelector:sel];
            SEL clearSel = NSSelectorFromString(@"clearCache");
            if ([cache respondsToSelector:clearSel]) {
                [cache performSelector:clearSel];
            }
            #pragma clang diagnostic pop
        }
    }
    NSLog(@"[CacheCleaner] 🖼️ Image Cache Cleared.");
}

// ★ SỬA: cleanupTempFiles GIỜ TRẢ VỀ unsigned long long NÊN CỘNG ĐƯỢC ★
+ (unsigned long long)fullSystemCleanup {
    unsigned long long total = 0;
    total += [self cleanupTempFiles];
    [self clearURLCache];
    [self clearImageCache];
    [self forceMemoryPurge];
    NSLog(@"[CacheCleaner] 🏁 Full System Cleanup Complete: %.2f MB", total / 1024.0 / 1024.0);
    return total;
}

@end
