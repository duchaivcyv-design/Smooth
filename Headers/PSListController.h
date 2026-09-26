#ifndef PSLISTCONTROLLER_H
#define PSLISTCONTROLLER_H

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class PSSpecifier;

@interface PSListController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy, nullable) NSArray<PSSpecifier *> *specifiers;
@property (nonatomic, retain, nullable) UITableView *table;
@property (nonatomic, retain, nullable) NSBundle *bundle;
@property (nonatomic, assign, nullable) id target;

- (NSArray<PSSpecifier *> *)loadSpecifiersFromPlistName:(NSString *)plistName
                                                 target:(nullable id)target;
- (void)reloadSpecifiers;
- (void)reloadSpecifier:(PSSpecifier *)specifier;
- (void)reloadSpecifierAtIndex:(NSInteger)index;
- (nullable PSSpecifier *)specifierAtIndex:(NSInteger)index;
- (nullable PSSpecifier *)specifierForID:(NSString *)identifier;
- (void)insertSpecifier:(PSSpecifier *)specifier atRow:(NSInteger)row;
- (void)removeSpecifierAtIndex:(NSInteger)index;
- (void)addSpecifier:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(nullable id)value specifier:(PSSpecifier *)specifier;
- (void)actionForSpecifier:(PSSpecifier *)specifier;
- (void)viewWillAppear:(BOOL)animated;
- (void)viewDidAppear:(BOOL)animated;
- (void)viewDidLoad;
- (void)suspendSpecifierUpdates;
- (void)resumeSpecifierUpdates;
- (void)pushController:(PSSpecifier *)specifier;

@end

NS_ASSUME_NONNULL_END
#endif
