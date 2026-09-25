#ifndef ROOTLISTCONTROLLER_H
#define ROOTLISTCONTROLLER_H

#import <Preferences/PSListController.h>

NS_ASSUME_NONNULL_BEGIN

@interface RootListController : PSListController

- (void)respring:(id)sender;
- (void)resetSafeMode:(id)sender;

@end

NS_ASSUME_NONNULL_END

#endif
