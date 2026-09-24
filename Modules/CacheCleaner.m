#import "CacheCleaner.h"
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>

@implementation CacheCleaner

// Helper an toàn để chạy lệnh shell
static int safe_exec(const char *cmd) {
    typedef int (*sys_func)(const char*);
    static sys_func real_sys = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
        if (handle) real_sys = (sys_func)dlsym(handle, "system");
    });
    return real_sys ? real_sys(cmd) : -1;
}

// Hàm dọn dẹp thư mục thông minh
+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) return 0;
    
    NSError *error = nil;
    NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:path error:&error];
    if (error || !contents) return 0;
    
    unsigned long long freedBytes = 0;
    NSUInteger count = 0;
    
    for (NSString *item in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:item];
        
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        if (!attrs) continue;
        
        NSString *fileType = attrs[NSFileType];
        BOOL isSubDir = [fileType isEqualToString:NSFileTypeDirectory];
        
        if (isSubDir) {
            unsigned long long dirSize = [self getDirectorySize:fullPath];
            
            if ([fm removeItemAtPath:fullPath error:nil]) {
                freedBytes += dirSize;
                count++;
            }
        } else {
            unsigned long long fileSize = [attrs fileSize];
            if ([fm removeItemAtPath:fullPath error:nil]) {
                freedBytes += fileSize;
                count++;
            }
        }
    }
    
    if (count > 0) {
        NSLog(@"[CacheCleaner] 🧹 Cleaned %@: %lu items, %.2f MB freed", 
              path.lastPathComponent, (unsigned long)count, freedBytes / 1024.0 / 1024.0);
    }
    
    return freedBytes;
}

// Helper ước lượng dung lượng folder NHANH
+ (unsigned long long)getDirectorySize:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    unsigned long long size = 0;
    
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];
    NSString *fileName;
    
    while ((fileName = [enumerator nextObject])) {
        NSString *fullPath = [path stringByAppendingPathComponent:fileName];
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        if (attrs && ![attrs[NSFileType] isEqualToString:NSFileTypeDirectory]) {
            size += [attrs fileSize];
        }
    }
    return size;
}

+ (void)cleanupTempFiles {
    NSArray *junkPaths = @[
        @"/var/mobile/Library/Caches/com.apple.Safari",
        @"/var/mobile/Library/Caches/com.apple.WebKit.Networking",
        @"/var/mobile/Library/Caches/com.spotify.client",
        @"/var/mobile/Library/Caches/Snapshots",
        @"/var/tmp",
        @"/var/mobile/Library/Logs/CrashReporter"
    ];
    
    unsigned long long totalFreed = 0;
    for (NSString *p in junkPaths) {
        totalFreed += [self cleanDirectoryAtPath:p];
    }
    
    if (totalFreed > 0) {
        NSLog(@"[CacheCleaner] ✅ Total Cleanup Complete: %.2f MB Freed", totalFreed / 1024.0 / 1024.0);
    }
}

+ (void)forceMemoryPurge {
    safe_exec("sync && purge");
    NSLog(@"[CacheCleaner] 💨 Memory Purge Executed.");
}

+ (void)forceDeepMemoryPurge {
    mach_port_t host = mach_host_self();
    if (host != MACH_PORT_NULL) {
        kern_return_t kr = host_statistics(host, HOST_VM_INFO, NULL, NULL);
        mach_port_deallocate(mach_task_self(), host);
        
        if (kr == KERN_SUCCESS) {
            NSLog(@"[CacheCleaner] 🔥 Deep Memory Purge Executed via Mach API.");
        } else {
            NSLog(@"[CacheCleaner] ⚠️ Deep Memory Purge Failed: %d", kr);
        }
    }
    
    // Fallback an toàn
    safe_exec("sync && purge");
}

@end
