#ifndef SYSTEM_BLOCKER_H
#define SYSTEM_BLOCKER_H

#import <Foundation/Foundation.h>

@interface SystemBlocker : NSObject

+ (instancetype)sharedInstance;

/**
 * Khởi tạo bộ chặn. Gọi trong %ctor khi Master Switch bật.
 */
- (void)initBlockers;

/**
 * Dừng bộ chặn (Khôi phục mặc định).
 */
- (void)stopBlockers;

/**
 * Kiểm tra xem chế độ chặn đang bật hay tắt.
 */
- (BOOL)isActive;

@end

#endif
