#import "CacheCleaner.h"
#import <spawn.h>
#import <sys/wait.h>

extern char **environ;

@implementation CacheCleaner

+ (void)forceMemoryPurge {
    pid_t pid;
    char *argv[] = {(char *)"/usr/bin/purge", NULL};
    posix_spawn(&pid, "/usr/bin/purge", NULL, NULL, argv, environ);
}

+ (void)forceDeepMemoryPurge {
    pid_t pid;
    char *argv[] = {(char *)"/bin/sh", (char *)"-c", (char *)"sync && purge", NULL};
    posix_spawn(&pid, "/bin/sh", NULL, NULL, argv, environ);
}

@end
