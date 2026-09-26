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
    
    NSArray *daemons = @[@"analyticsd", @"adid", @"rapportd", @"awdd"];
    for (NSString *daemon in daemons) {
        pid_t pid;
        NSString *cmd = [NSString stringWithFormat:@"/var/jb/bin/launchctl stop com.apple.%@", daemon];
        char *argv[] = {(char *)"/bin/sh", (char *)"-c", (char *)[cmd UTF8String], NULL};
        posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
    }
}

@end
