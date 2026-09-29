#ifndef SYSTEM_BLOCKER_H
#define SYSTEM_BLOCKER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SystemBlocker : NSObject

@property (nonatomic, assign, readonly) BOOL isAnalyticsBlocked;
@property (nonatomic, assign, readonly) BOOL isSandboxBypassed;

+ (instancetype)sharedInstance;

// Khởi tạo các rào chắn hệ thống, chặn telemetry và tối ưu I/O
- (void)initBlockers;

// Kiểm tra xem một URL hoặc endpoint có thuộc danh sách telemetry ngầm bị chặn hay không
- (BOOL)shouldBlockTelemetryURL:(NSURL *)url;

// Kiểm tra xem tiến trình hoặc daemon có cần bị cách ly logging hay không
- (BOOL)shouldMuteLoggingForBundle:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END

#endif
