#import "CacheCleaner.h"
#import <dlfcn.h>
#import <sys/stat.h>
#import <dirent.h>

// Function pointer cho system() - load qua dlsym để tránh implicit declaration warning
typedef int (*system_func_t)(const char *);
static system_func_t g_system_func = NULL;
static dispatch_once_t g_system_once_token;

/**
 * Load hàm system() từ libsystem_c.dylib thông qua dlsym.
 * An toàn hơn việc gọi trực tiếp system() vì tránh compiler warning
 * và cho phép kiểm tra null trước khi gọi.
 */
static void load_system_function(void) {
    dispatch_once(&g_system_once_token, ^{
        void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
        if (handle) {
            g_system_func = (system_func_t)dlsym(handle, "system");
        }
    });
}

/**
 * Wrapper an toàn để gọi system command.
 * Kiểm tra null pointer trước khi gọi.
 * @param command Command string để execute
 * @return Return code từ system(), hoặc -1 nếu không thể execute
 */
static int safe_system(const char *command) {
    load_system_function();
    if (g_system_func) {
        return g_system_func(command);
    }
    return -1;
}

@implementation CacheCleaner

+ (void)forceMemoryPurge {
    NSLog(@"[CacheCleaner] Executing standard memory purge...");
    
    int result = safe_system("purge");
    
    if (result == 0) {
        NSLog(@"[CacheCleaner] ✅ Memory purge completed successfully");
    } else {
        NSLog(@"[CacheCleaner] ⚠️ Memory purge returned code: %d", result);
    }
    
    // Bổ sung: clear NSURLCache
    [self clearURLCache];
}

+ (void)forceDeepMemoryPurge {
    NSLog(@"[CacheCleaner] Executing deep memory purge (sync + purge)...");
    
    // Sync đảm bảo tất cả pending writes được flush xuống disk
    // trước khi purge RAM, tránh data loss
    int result = safe_system("sync && purge");
    
    if (result == 0) {
        NSLog(@"[CacheCleaner] ✅ Deep memory purge completed successfully");
    } else {
        NSLog(@"[CacheCleaner] ⚠️ Deep memory purge returned code: %d", result);
    }
    
    // Bổ sung: clear NSURLCache và image cache
    [self clearURLCache];
    
    // Clear UIKit image cache
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}

+ (void)clearURLCache {
    NSURLCache *sharedCache = [NSURLCache sharedURLCache];
    if (sharedCache) {
        NSUInteger memoryCapacity = sharedCache.memoryCapacity;
        NSUInteger diskCapacity = sharedCache.diskCapacity;
        
        [sharedCache removeAllCachedResponses];
        
        NSLog(@"[CacheCleaner] ✅ URL cache cleared (Memory: %lu MB, Disk: %lu MB)",
              (unsigned long)(memoryCapacity / 1024 / 1024),
              (unsigned long)(diskCapacity / 1024 / 1024));
    }
}

+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path {
    if (!path || path.length == 0) return 0;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    
    if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) {
        return 0;
    }
    
    unsigned long long freedBytes = 0;
    NSError *error = nil;
    NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:path error:&error];
    
    if (error || !contents) {
        NSLog(@"[CacheCleaner] ⚠️ Cannot read directory: %@ - %@", path, error.localizedDescription);
        return 0;
    }
    
    for (NSString *item in contents) {
        // Bỏ qua hidden files và system files
        if ([item hasPrefix:@"."]) continue;
        
        NSString *fullPath = [path stringByAppendingPathComponent:item];
        unsigned long long itemSize = [self getDirectorySize:fullPath];
        
        NSError *removeError = nil;
        if ([fm removeItemAtPath:fullPath error:&removeError]) {
            freedBytes += itemSize;
        } else {
            NSLog(@"[CacheCleaner] ⚠️ Cannot remove: %@ - %@", fullPath, removeError.localizedDescription);
        }
    }
    
    if (freedBytes > 0) {
        NSLog(@"[CacheCleaner] ✅ Cleaned %@: %.2f MB freed",
              path.lastPathComponent, freedBytes / 1024.0 / 1024.0);
    }
    
    return freedBytes;
}

+ (unsigned long long)getDirectorySize:(NSString *)path {
    if (!path || path.length == 0) return 0;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    
    if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
        return 0;
    }
    
    if (!isDir) {
        // Là file đơn lẻ
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        return [attrs[NSFileSize] unsignedLongLongValue];
    }
    
    // Là thư mục - duyệt đệ quy
    unsigned long long totalSize = 0;
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
    NSString *file;
    
    while ((file = [enumerator nextObject])) {
        NSString *fullPath = [path stringByAppendingPathComponent:file];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        if (attrs) {
            totalSize += [attrs[NSFileSize] unsignedLongLongValue];
        }
    }
    
    return totalSize;
}

+ (unsigned long long)cleanAllSystemCaches {
    NSLog(@"[CacheCleaner] Starting full system cache cleanup...");
    
    unsigned long long totalFreed = 0;
    
    // Danh sách các thư mục cache phổ biến trên iOS
    NSArray<NSString *> *cachePaths = @[
        // Safari caches
        @"/var/mobile/Library/Caches/com.apple.Safari",
        @"/var/mobile/Library/Caches/com.apple.Safari.SafeBrowsing",
        
        // WebKit caches
        @"/var/mobile/Library/Caches/com.apple.WebKit.Networking",
        @"/var/mobile/Library/Caches/com.apple.WebKit.ProcessPool",
        
        // System caches
        @"/var/mobile/Library/Caches/com.apple.nsurlsessiond",
        @"/var/mobile/Library/Caches/com.apple.akd",
        
        // App snapshots
        @"/var/mobile/Library/Caches/Snapshots",
        
        // Temp files
        @"/var/tmp",
        @"/var/mobile/Library/Caches/com.apple.UIKit.keyboardCache",
        
        // Rootless paths
        @"/var/jb/var/mobile/Library/Caches/com.apple.Safari",
        @"/var/jb/var/tmp"
    ];
    
    for (NSString *cachePath in cachePaths) {
        totalFreed += [self cleanDirectoryAtPath:cachePath];
    }
    
    // Clear URL cache
    [self clearURLCache];
    
    NSLog(@"[CacheCleaner] ✅ Full cleanup complete: %.2f MB total freed",
          totalFreed / 1024.0 / 1024.0);
    
    return totalFreed;
}

@end
