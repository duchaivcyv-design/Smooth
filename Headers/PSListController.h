#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface PSListController : UIViewController {
    NSArray *_specifiers;
}

- (NSArray *)loadSpecifiersFromPlistName:(NSString *)plistName target:(id)target;
- (void)reloadSpecifiers;
@end
