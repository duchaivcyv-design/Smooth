#import "CacheCleaner.h"
#import <dlfcn.h>

@implementation CacheCleaner

// Helper an toàn để chạy lệnh shell (tránh lỗi system() unavailable)
static int safe_exec(const char *cmd) {
    typedef int (*sys_func)(const char*);
    static sys_func real_sys = NULL;
    if (!real_sys) {
        void *handle = dlopen("/usr/lib/system/libsystem_c.dylib", RTLD_LAZY);
        if (handle) real_sys = (sys_func)dlsym(handle, "system");
    }
    return real_sys ? real_sys(cmd) : -1;
}

+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    unsigned long long freedBytes = 0;
    
    // Kiểm tra đường dẫn có tồn tại không
    if (![fm fileExistsAtPath:path]) return 0;
    
    NSError *error = nil;
    NSArray *contents = [fm contentsOfDirectoryAtPath:path error:&error];
    
    if (error || !contents) return 0;
    
    for (NSString *item in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:item];
        
        // Bỏ qua các file cấu hình quan trọng nếu cần (tùy chỉnh whitelist)
        // Ví dụ: Không xóa file .plist cài đặt app
        if ([item.pathExtension isEqualToString:@"plist"]) continue;
        
        BOOL isDir = NO;
        [fm attributesOfItemAtPath:fullPath result:nil isDirectory:&isDir];
        
        if (isDir) {
            // Đệ quy xóa thư mục con
            NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
            unsigned long long size = [attrs fileSize];
            
            // Xóa cả thư mục và nội dung bên trong
            if ([fm removeItemAtPath:fullPath error:nil]) {
                freedBytes += size;
            }
        } else {
            // Xóa file đơn lẻ
            NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
            unsigned long long size = [attrs fileSize];
            
            if ([fm removeItemAtPath:fullPath error:nil]) {
                freedBytes += size;
            }
        }
    }
    
    NSLog(@"[BoostiPhone6s] 🧹 Cleaned %@ -> Freed %.2f MB", 
          path.lastPathComponent, freedBytes / 1024.0 / 1024.0);
    
    return freedBytes;
}

+ (void)cleanupTempFiles {
    // Các đường dẫn cache "bẩn" phổ biến trên iOS 15-16
    NSArray *junkPaths = @[
        @"/private/var/mobile/Library/Caches/com.apple.Safari",       // Safari WebKit
        @"/private/var/mobile/Library/Caches/com.spotify.client",     // Spotify Offline songs (cẩn thận!)
        @"/private/var/mobile/Library/Caches/com.tencent.qqmusic",    // Nhạc QQ/Tencent
        @"/private/var/tmp",                                          // Temp files chung
        @"/private/var/mobile/Library/Logs"                           // Log system cũ
    ];
    
    for (NSString *p in junkPaths) {
        [self cleanDirectoryAtPath:p];
    }
}

+ (void)forceMemoryPurge {
    // Gọi lệnh purge của Unix để ép Kernel trả RAM về pool trống
    safe_exec("sync && purge");
}

@end
