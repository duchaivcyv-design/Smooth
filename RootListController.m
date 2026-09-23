#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Foundation/Foundation.h>

@interface RootListController : PSListController
@end

@implementation RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"root" target:self];
    }
    return _specifiers;
}

// Optional: Xử lý sự kiện khi toggle switch
- (void)toggleChanged:(UISwitch *)sender {
    // Logic bổ sung nếu cần
}

@end
