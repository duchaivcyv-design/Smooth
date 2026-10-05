#ifndef SYSTEM_BLOCKER_H
#define SYSTEM_BLOCKER_H

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

// Kiểm tra nhanh tiến trình daemon trong 0ns cho %ctor của Tweak.xm
BOOL SystemBlocker_ShouldBypassDaemon(const char * _Nullable procName);

// Nhận diện tiến trình mạng để cách ly hoàn toàn, bảo vệ 100% kết nối
BOOL SystemBlocker_IsNetworkProcess(const char * _Nullable procName);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_BEGIN

@interface SystemBlocker : NSObject

@property (nonatomic, assign, readonly) BOOL isAnalyticsBlocked;
@property (nonatomic, assign, readonly) BOOL isSandboxBypassed;

+ (instancetype)sharedInstance;

// Khởi tạo các rào chắn hệ thống, chặn telemetry và tối ưu I/O
- (void)initBlockers;

// Kiểm tra xem một URL hoặc endpoint có thuộc danh sách telemetry ngầm bị chặn hay không (Không chặn domain media)
- (BOOL)shouldBlockTelemetryURL:(NSURL *)url;

// Kiểm tra xem tiến trình hoặc daemon có cần bị cách ly logging hay không
- (BOOL)shouldMuteLoggingForBundle:(NSString *)bundleIdentifier;

@end

NS_ASSUME_NONNULL_END

#endif /* SYSTEM_BLOCKER_H */
