#import "CacheCleaner.h"
#import <dlfcn.h>

@implementation CacheCleaner

// Helper an toàn để chạy lệnh shell
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
        if ([item.pathExtension isEqualToString:@"plist"]) continue;
        
        // ★ FIX LỖI COMPILE HERE ★
        // Sử dụng API chuẩn: attributesOfItemAtPath:error:
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        
        if (!attrs) continue; // Skip nếu không đọc được attribute
        
        // Kiểm tra xem là Directory hay File thông qua fileType string
        NSString *fileType = attrs[NSFileType];
        BOOL isDir = [fileType isEqualToString:NSFileTypeDirectory];
        
        if (isDir) {
            // Đệ quy xóa thư mục con
            // Để tính dung lượng chính xác của folder lớn rất tốn CPU, 
            // nên ở chế độ "Fast Clean" ta ước lượng hoặc bỏ qua việc cộng dồn chi tiết cho sub-folder.
            // Ta chỉ cần đảm bảo nó được remove thành công.
            
            // Gọi đệ quy để dọn bên trong trước
            [self cleanDirectoryAtPath:fullPath]; 
            
            // Sau đó xóa cái folder rỗng đó đi
            if ([fm removeItemAtPath:fullPath error:nil]) {
                // Cộng thêm một khoản ước lượng nhỏ cho overhead folder
                freedBytes += 4096; 
            }
        } else {
            // Xóa file đơn lẻ
            unsigned long long size = [attrs fileSize];
            
            if ([fm removeItemAtPath:fullPath error:nil]) {
                freedBytes += size;
            }
        }
    }
    
    NSLog(@"[BoostiPhone6s] 🧹 Cleaned %@ -> Estimated Freed: %.2f MB", 
          path.lastPathComponent, freedBytes / 1024.0 / 1024.0);
    
    return freedBytes;
}

+ (void)cleanupTempFiles {
    NSArray *junkPaths = @[
        @"/private/var/mobile/Library/Caches/com.apple.Safari",       
        @"/private/var/mobile/Library/Caches/com.spotify.client",     
        @"/private/var/tmp",                                          
        @"/private/var/mobile/Library/Logs"                           
    ];
    
    for (NSString *p in junkPaths) {
        [self cleanDirectoryAtPath:p];
    }
}

+ (void)forceMemoryPurge {
    safe_exec("sync && purge");
}

@end
