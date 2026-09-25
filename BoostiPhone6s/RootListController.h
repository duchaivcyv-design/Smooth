#ifndef ROOTLISTCONTROLLER_H
#define ROOTLISTCONTROLLER_H

#import <Preferences/PSListController.h>

NS_ASSUME_NONNULL_BEGIN

@interface RootListController : PSListController

/**
 * Xử lý nút Respring thủ công từ Settings.
 */
- (void)respring:(id)sender;

/**
 * Xử lý thoát Safe Mode và reset cấu hình.
 */
- (void)resetSafeMode:(id)sender;

@end

NS_ASSUME_NONNULL_END

#endif /* ROOTLISTCONTROLLER_H */
