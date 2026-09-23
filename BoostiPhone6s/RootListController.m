#import "RootListController.h"
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

@implementation RootListController {
    PSListController *_listController;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Boost iPhone 6s-X";
    
    // Khởi tạo list controller để đọc root.plist
    _listController = [[PSListController alloc] init];
    [_listController loadSpecifiersFromPlist:YES];
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlist:YES];
    }
    return _specifiers;
}

@end
