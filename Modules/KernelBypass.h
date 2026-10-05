#ifndef KERNEL_BYPASS_H
#define KERNEL_BYPASS_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Khai báo an toàn cho các tác vụ kiểm tra nhanh từ Tweak.xm
BOOL KernelBypass_IsRootHide(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_BEGIN

@interface KernelBypass : NSObject

@property (nonatomic, assign, readonly) BOOL isRootHideEnvironment;
@property (nonatomic, copy, readonly) NSString *currentJailbreakRoot;

+ (instancetype)sharedInstance;

// Khởi tạo môi trường, nhận diện tiền tố jailbreak động và mở rộng sandbox /var
- (void)initEnvironment;

// Nâng mức ưu tiên luồng hiện tại bằng QoS User Interactive & P-Core Affinity (Không bỏ đói socket mạng)
- (void)boostCurrentThreadPriority;
- (void)boostThreadWithTargetHz:(uint32_t)targetHz;

// Giải phóng bộ nhớ đệm trang nhân cấp Mach VM (VM_PURGABLE_PURGE_ALL)
- (void)forceMachPurge;

// Kiểm tra quyền truy cập đường dẫn an toàn qua bypass sandbox
- (BOOL)canAccessPathSafely:(NSString *)path;

@end

NS_ASSUME_NONNULL_END

#endif /* KERNEL_BYPASS_H */
