#import "SystemBlocker.h"
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

@implementation SystemBlocker {
    BOOL _active;
}

+ (instancetype)sharedInstance {
    static SystemBlocker *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)initBlockers {
    if (_active) return;
    _active = YES;
    
    // Đẩy việc chặn Daemon ra luồng nền (Background) để không gây khựng UI
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @autoreleasepool {
            // Chặn mở rộng: Thêm crash_mover và symptom_diagnostics (gây ngốn pin ngầm)
            NSArray *daemons = @[@"analyticsd", @"adid", @"rapportd", @"awdd", @"crash_mover", @"symptom_diagnostics"];
            for (NSString *daemon in daemons) {
                pid_t pid;
                NSString *service = [NSString stringWithFormat:@"com.apple.%@", daemon];
                // Gọi TRỰC TIẾP launchctl, bỏ qua /bin/sh để tốc độ thực thi chỉ mất 0.001s
                char *argv[] = {(char *)"/var/jb/bin/launchctl", (char *)"stop", (char *)[service UTF8String], NULL};
                
                if (posix_spawn(&pid, "/var/jb/bin/launchctl", NULL, NULL, argv, environ) == 0) {
                    waitpid(pid, NULL, WNOHANG); // Non-blocking wait (Không bắt CPU phải chờ đợi)
                }
            }
        }
    });
}

@end
