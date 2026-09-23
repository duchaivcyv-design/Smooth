// ★ SỬA ĐƯỜNG DẪN IMPORT: Bỏ "..", giữ nguyên tên folder ★
#import "Headers/PSListController.h" 
#import <Foundation/Foundation.h>

@interface RootListController : PSListController
@end

@implementation RootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        // Gọi method loadSpecifiersFromPlistName... 
        // Vì class cha PSListController có method này, runtime sẽ tìm thấy nó.
        _specifiers = [self loadSpecifiersFromPlistName:@"root" target:self];
    }
    return _specifiers;
}

@end
