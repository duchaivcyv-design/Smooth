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
    
    // Thử chạy sbreload
    const char *args1[] = {"sbreload", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)args1, NULL);
    
    // Thử chạy killall
    const char *args2[] = {"killall", "-9", "SpringBoard", NULL};
    posix_spawn(&pid, "/var/jb/usr/bin/killall", NULL, NULL, (char *const *)args2, NULL);
    
    // Thử chạy lệnh qua system
    system("killall -9 SpringBoard");
    system("/var/jb/usr/bin/sbreload");
}

@end
