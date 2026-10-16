#ifndef PSSPECIFIER_H
#define PSSPECIFIER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifndef _PSCellType_DEFINED
#define _PSCellType_DEFINED
typedef NS_ENUM(NSInteger, PSCellType) {
    PSGroupCell = 0,
    PSLinkCell = 1,
    PSLinkListCell = 2,
    PSListItemCell = 3,
    PSTitleValueCell = 4,
    PSSliderCell = 5,
    PSSwitchCell = 6,
    PSStaticTextCell = 7,
    PSEditTextCell = 8,
    PSSegmentCell = 9,
    PSGiantCell = 10,
    PSGiantIconCell = 11,
    PSMultiValueCell = 12,
    PSSecureEditTextCell = 13,
    PSButtonCell = 14,
    PSEditTextViewCell = 15,
    PSSpinnerCell = 16,
};
#endif

@interface PSSpecifier : NSObject

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *identifier;
@property (nonatomic, assign) PSCellType cellType;
@property (nonatomic, assign) Class detailControllerClass;
@property (nonatomic, assign) Class editPaneClass;
@property (nonatomic, assign) SEL getter;
@property (nonatomic, assign) SEL setter;
@property (nonatomic, assign) SEL action;
@property (nonatomic, weak) id target;
@property (nonatomic, retain) NSMutableDictionary *properties;

+ (instancetype)preferenceSpecifierNamed:(nullable NSString *)name
                                  target:(nullable id)target
                                     set:(nullable SEL)setSelector
                                     get:(nullable SEL)getSelector
                                  detail:(nullable Class)detailClass
                                    cell:(PSCellType)cellType
                                    edit:(nullable Class)editClass;

+ (instancetype)emptyGroupSpecifier;
+ (instancetype)groupSpecifierWithName:(nullable NSString *)name;
+ (instancetype)groupSpecifierWithID:(nullable NSString *)identifier;
+ (instancetype)groupSpecifierWithID:(nullable NSString *)identifier name:(nullable NSString *)name;

- (nullable id)propertyForKey:(NSString *)key;
- (void)setProperty:(nullable id)value forKey:(NSString *)key;
- (void)removePropertyForKey:(NSString *)key;

- (nullable id)performGetter;
- (void)performSetterWithValue:(nullable id)value;
- (void)performAction;

@end

NS_ASSUME_NONNULL_END

#endif /* PSSPECIFIER_H */
