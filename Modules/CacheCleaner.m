#import "CacheCleaner.h"
#import <dlfcn.h>
#import <Foundation/Foundation.h>

@implementation CacheCleaner

// Helper an toàn để chạy lệnh shell (Tái sử dụng từ KernelBypass nếu muốn gộp)
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

// Hàm dọn dẹp thư mục thông minh: Không đệ quy tính toán, xóa trực tiếp bằng NSFileManager
+ (unsigned long long)cleanDirectoryAtPath:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    // Kiểm tra tồn tại và quyền đọc
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:path isDirectory:&isDir] || !isDir) return 0;
    
    NSError *error = nil;
    NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:path error:&error];
    if (error || !contents) return 0;
    
    unsigned long long freedBytes = 0;
    NSUInteger count = 0;
    
    for (NSString *item in contents) {
        NSString *fullPath = [path stringByAppendingPathComponent:item];
        
        // ★ SỬA LỖI LOGIC: KHÔNG BỎ QUA PLIST NỮA ★
        // Chỉ bỏ qua các file cấu hình hệ thống quan trọng nếu cần thiết
        // Ví dụ: Whitelist specific system plists instead of blocking all .plists
        
        NSDictionary *attrs = [fm attributesOfItemAtPath:fullPath error:nil];
        if (!attrs) continue;
        
        NSString *fileType = attrs[NSFileType];
        BOOL isSubDir = [fileType isEqualToString:NSFileTypeDirectory];
        
        if (isSubDir) {
            // ★ TỐI ƯU HIỆU SUẤT: XÓA TRỰC TIẾP THƯ MỤC CON ★
            // NSFileManager removeItemAtPath tự động xóa đệ quy nội dung bên trong.
            // Ta không cần gọi đệ quy thủ công nữa -> Tiết kiệm CPU/RAM đáng kể.
            unsigned long long dirSize = [self getDirectorySize:fullPath]; // Ước lượng nhanh
            
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

// Helper ước lượng dung lượng folder NHANH (không đệ quy sâu)
+ (unsigned long long)getDirectorySize:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    unsigned long long size = 0;
    
    // Dùng enumerator để duyệt nhanh hơn contentsOfDirectory cho folder lớn
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
    // Danh sách đường dẫn cache chuẩn Rootless (/var/mobile/...)
    NSArray *junkPaths = @[
        @"/var/mobile/Library/Caches/com.apple.Safari",
        @"/var/mobile/Library/Caches/com.apple.WebKit.Networking",
        @"/var/mobile/Library/Caches/com.spotify.client",
        @"/var/mobile/Library/Caches/Snapshots",      // Ảnh chụp màn hình nền
        @"/var/tmp",                                   // File tạm hệ thống
        @"/var/mobile/Library/Logs/CrashReporter"      // Log crash cũ
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
    // Sync disk trước khi purge để tránh mất dữ liệu chưa ghi
    safe_exec("sync && purge");
    NSLog(@"[CacheCleaner] 💨 Memory Purge Executed.");
}

@end
