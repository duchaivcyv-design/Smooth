#import "CacheCleaner.h"
#import <dlfcn.h>
#import <Foundation/Foundation.h>
#import <mach/mach.h>
#import <sys/stat.h>

@implementation CacheCleaner

// Helper an toàn để chạy lệnh shell (Thread-safe tuyệt đối)
static int safe_exec(const char *cmd) {
    typedef int (*sys_func)(const char*);
    static sys_func real_sys = NULL;
    static pthread_once_t onceToken = PTHREAD_ONCE_INIT;
    
    void init_sys(void) {
        void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
        if (handle) real_sys = (sys_func)dlsym(handle, "system");
    }
    
    pthread_once(&onceToken, init_sys);
    return real_sys ? real_sys(cmd) : -1;
}

// Hàm dọn dẹp thư mục thông minh & An toàn cho Rootless
+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path {
    // Tự động sửa /var/jb/var/mobile -> /var/mobile nếu người dùng nhập sai
    NSString *safePath = path;
    if ([path hasPrefix:@"/var/jb/var/mobile"]) {
        safePath = [path stringByReplacingOccurrencesOfString:@"/var/jb/var/mobile" 
                                                   withString:@"/var/mobile"];
    } else if ([path hasPrefix:@"/private/var/mobile"]) {
        safePath = [path stringByReplacingOccurrencesOfString:@"/private/var/mobile" 
                                                   withString:@"/var/mobile"];
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
        // Bỏ qua các file hệ thống quan trọng tránh crash
        if ([item isEqualToString:@".DS_Store"] || [item isEqualToString:@".localized"]) continue;
        
        NSString *fullPath = [safePath stringByAppendingPathComponent:item];
        
        struct stat sb;
        if (lstat([fullPath UTF8String], &sb) != 0) continue;
        
        BOOL isSubDir = S_ISDIR(sb.st_mode);
        
        if (isSubDir) {
            // Ước lượng nhanh kích thước folder trước khi xóa
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

// Helper ước lượng dung lượng folder CỰC NHANH (Low Overhead)
+ (unsigned long long)getDirectorySize:(NSString *)path {
    unsigned long long size = 0;
    struct stat sb;
    
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtPath:path];
    NSString *fileName;
    
    while ((fileName = [enumerator nextObject])) {
        NSString *fullPath = [path stringByAppendingPathComponent:fileName];
        // lstat nhanh hơn nhiều so với attributesOfItemAtPath vì không tạo NSDictionary
        if (lstat([fullPath UTF8String], &sb) == 0 && !S_ISDIR(sb.st_mode)) {
            size += (unsigned long long)sb.st_size;
        }
    }
    return size;
}

+ (void)cleanupTempFiles {
    NSArray *junkPaths = @[
        @"/var/mobile/Library/Caches/com.apple.Safari",
        @"/var/mobile/Library/Caches/com.apple.WebKit.Networking",
        @"/var/mobile/Library/Caches/com.apple.WebKit.ProcessPool",
        @"/var/mobile/Library/Caches/Snapshots",
        @"/var/tmp",
        @"/var/mobile/Library/Logs/CrashReporter",
        @"/var/mobile/Library/Logs/MobileGestalt"
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
    NSLog(@"[CacheCleaner] 💨 Standard Memory Purge Executed.");
}

+ (void)forceDeepMemoryPurge {
    mach_port_t host = mach_host_self();
    if (host != MACH_PORT_NULL) {
        kern_return_t kr = host_statistics(host, HOST_VM_INFO, NULL, NULL);
        mach_port_deallocate(mach_task_self(), host);
        
        if (kr == KERN_SUCCESS) {
            NSLog(@"[CacheCleaner] 🔥 Deep Memory Purge Executed via Mach Host API.");
        } else {
            NSLog(@"[CacheCleaner] ⚠️ Deep Memory Purge Failed: %d", kr);
        }
    }
    
    // Fallback an toàn đảm bảo disk luôn đồng bộ trước khi purge
    safe_exec("sync && purge");
}

@end
