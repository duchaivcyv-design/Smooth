#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <spawn.h>

@interface RootListController : PSListController
@end

@implementation RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

- (void)respring:(id)sender {
    pid_t pid;
    
    // 1. Thử gọi sbreload trên Rootless (/var/jb/usr/bin/sbreload)
    const char *sbreloadRootless[] = {"sbreload", NULL};
    if (posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)sbreloadRootless, NULL) == 0) {
        return;
    }
    
    // 2. Thử gọi killall trên Rootless (/var/jb/usr/bin/killall)
    const char *killallArgs[] = {"killall", "-9", "SpringBoard", NULL};
    if (posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)killallArgs, NULL) == 0) {
        return;
    }

    // 3. Dự phòng cho Rootful (đường dẫn cũ)
    if (posix_spawn(&pid, "/usr/bin/sbreload", NULL, NULL, (char *const *)sbreloadRootless, NULL) == 0) {
        return;
    }
    posix_spawn(&pid, "/usr/bin/killall", NULL, NULL, (char *const *)killallArgs, NULL);
}

@end
