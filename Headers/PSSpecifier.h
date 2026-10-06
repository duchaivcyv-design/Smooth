#ifndef PSSPECIFIER_H
#define PSSPECIFIER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

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

@interface PSSpecifier : NSObject

@property (nonatomic, copy, nullable) NSString *identifier;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, assign) PSCellType cellType;
@property (nonatomic, weak, nullable) id target;
@property (nonatomic, assign, nullable) SEL getter;
@property (nonatomic, assign, nullable) SEL setter;
@property (nonatomic, assign, nullable) SEL action;
@property (nonatomic, strong, nullable) id defaultValue;
@property (nonatomic, copy, nullable) NSString *defaultsDomain;
@property (nonatomic, copy, nullable) NSString *key;
@property (nonatomic, strong, nullable) NSArray *validValues;
@property (nonatomic, strong, nullable) NSArray *titleStrings;
@property (nonatomic, copy, nullable) NSString *detailControllerClass;
@property (nonatomic, assign) CGFloat sliderMin;
@property (nonatomic, assign) CGFloat sliderMax;
@property (nonatomic, assign) BOOL showValue;
@property (nonatomic, copy, nullable) NSString *footerText;
@property (nonatomic, copy, nullable) NSString *placeholder;
@property (nonatomic, copy, nullable) NSString *iconName;
@property (nonatomic, copy, nullable) NSString *postNotificationName;
@property (nonatomic, copy, nullable) NSString *keyboardType;

// Bảng thuộc tính chuẩn của Preferences.framework là NSMutableDictionary
@property (nonatomic, strong, nullable) NSMutableDictionary *properties;

+ (instancetype)preferenceSpecifierNamed:(nullable NSString *)name
                                  target:(nullable id)target
                                     set:(nullable SEL)setSelector
                                     get:(nullable SEL)getSelector
                                  detail:(nullable Class)detailClass
                                    cell:(PSCellType)cellType
                                    edit:(nullable Class)editClass;

+ (instancetype)emptyGroupSpecifier;
+ (instancetype)groupSpecifierWithName:(nullable NSString *)name;

- (instancetype)init;

// 2 phương thức cốt lõi bắt buộc phải có cho Preferences/PreferenceLoader
- (nullable id)propertyForKey:(NSString *)key;
- (void)setProperty:(nullable id)value forKey:(NSString *)key;

- (nullable id)performGetter;
- (void)performSetterWithValue:(nullable id)value;
- (void)performAction;
- (void)sendPostNotification;

@end

NS_ASSUME_NONNULL_END

#endif /* PSSPECIFIER_H */
