#ifndef PSSPECIFIER_H
#define PSSPECIFIER_H

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Enum định nghĩa loại cell trong PreferenceKit.
 * Khớp chính xác với PSConstants.h trong Private Framework.
 */
typedef NS_ENUM(NSInteger, PSType) {
    PSGroupCell = 0,
    PSTitleValueCell = 1,
    PSSliderCell = 2,
    PSSwitchCell = 3,
    PSEditTextCell = 4,
    PSStaticTextCell = 5,
    PSLinkCell = 6,
    PSMultiValueCell = 7,
    PSRadioGroupCell = 8,
    PSCheckboxCell = 9
};

/**
 * Đối tượng mô tả một mục cấu hình trong Settings.
 * Được tạo bởi [PSSpecifier preferenceSpecifierNamed:title:detail:cell:edit:get:set:values:titles:min:max:]
 */
@interface PSSpecifier : NSObject

@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, copy, nullable) NSString *label;
@property (nonatomic, assign) PSType cellType;

/**
 * Khởi tạo specifier mới (constructor chuẩn của PreferenceKit).
 * @param name Tên internal key dùng để lưu trữ value.
 * @param title Tiêu đề hiển thị trên UI.
 * @param detail Mô tả chi tiết (footer text).
 * @param type Loại cell (PSTitleValueCell, PSSwitchCell...).
 * @param editClass Class xử lý editing (thường là nil).
 * @param getSelector Selector lấy giá trị hiện tại.
 * @param setSelector Selector lưu giá trị mới.
 * @param values Mảng giá trị khả dụng (cho MultiValue/Radio).
 * @param titles Mảng tiêu đề tương ứng với values.
 * @param min Giá trị tối thiểu (cho Slider).
 * @param max Giá trị tối đa (cho Slider).
 */
- (instancetype)initWithName:(nullable NSString *)name
                       title:(nullable NSString *)title
                      detail:(nullable NSString *)detail
                        cell:(PSType)type
                    editClass:(nullable Class)editClass
                          get:(SEL)getSelector
                          set:(SEL)setSelector
                       values:(nullable NSArray *)values
                       titles:(nullable NSArray *)titles
                          min:(double)min
                          max:(double)max;

@end

NS_ASSUME_NONNULL_END

#endif /* PSSPECIFIER_H */
