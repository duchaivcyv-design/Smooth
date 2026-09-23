// ★ IMPORT HEADER TƯƠNG ĐỐI (Từ thư mục Headers vừa tạo) ★
#import "../Headers/PSListController.h" 
#import "../Headers/PSSpecifier.h"
#import <Foundation/Foundation.h>

@interface RootListController : PSListController
@end

@implementation RootListController

// ★ QUAN TRỌNG: Khai báo dynamic để tránh lỗi Undefined Symbol lúc Link ★
// Điều này bảo compiler rằng: "Đừng lo, lúc chạy tôi sẽ tự tìm class cha"
@dynamic specifiers; 

- (NSArray *)specifiers {
    if (!_specifiers) {
        // Load giao diện từ file root.plist
        _specifiers = [self loadSpecifiersFromPlistName:@"root" target:self];
    }
    return _specifiers;
}

// Optional: Xử lý sự kiện toggle nếu cần logic phức tạp hơn plist
- (void)toggleChanged:(UISwitch *)sender {
    // Logic bổ sung nếu cần
}

@end
