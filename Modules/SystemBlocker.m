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
    dispatch_once(&onceToken, ^{ 
        instance = [[self alloc] init]; 
    });
    return instance;
}

- (void)initBlockers {
    if (_active) return;
    _active = YES;
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        @autoreleasepool {
            NSArray *daemons = @[@"analyticsd", @"adid", @"rapportd", @"awdd", @"crash_mover", @"symptom_diagnostics"];
            
            const char *launchctlPath = NULL;
            if (access("/var/jb/bin/launchctl", X_OK) == 0) {
                launchctlPath = "/var/jb/bin/launchctl";
            } else if (access("/var/jb/usr/bin/launchctl", X_OK) == 0) {
                launchctlPath = "/var/jb/usr/bin/launchctl";
            } else if (access("/bin/launchctl", X_OK) == 0) {
                launchctlPath = "/bin/launchctl";
            }
            
            if (!launchctlPath) return;

            for (NSString *daemon in daemons) {
                pid_t pid;
                NSString *service = [NSString stringWithFormat:@"com.apple.%@", daemon];
                char *argv[] = {(char *)launchctlPath, (char *)"stop", (char *)[service UTF8String], NULL};
                
                if (posix_spawn(&pid, launchctlPath, NULL, NULL, argv, environ) == 0) {
                    int status;
                    waitpid(pid, &status, 0); // Don sach tien trinh con, khong gay lag
                }
            }
        }
    });
}

@end
