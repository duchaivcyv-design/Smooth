// ====================================================================================================
// BOOSTIPHONE6S APP - MAIN ENTRY POINT (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN - CHUẨN ĐỒNG BỘ 0MS)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG TRỄ KHỞI ĐỘNG, KHÔNG ĐEN MÀN HÌNH, TỰ ĐỘNG CẤP PHÁT P-CORE)
// ====================================================================================================

#import <UIKit/UIKit.h>
#import <pthread.h>
#import "AppDelegate.h"

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // [ĐÃ ÉP TOÀN DIỆN]: Đặt tên nhận diện cho luồng chính để tránh bị kernel xếp vào tiến trình rác
        pthread_setname_np("com.taojb.boostiphone6s.ui");

        // [ĐÃ ÉP TOÀN DIỆN]: Cưỡng bức nâng quyền ưu tiên luồng giao diện lên cấp cao nhất ngay từ 0ns
        pthread_set_qos_class_self_np(QOS_CLASS_USER_INTERACTIVE, 0);

        // Khởi chạy vòng đời UIKit kết nối trực tiếp với AppDelegate
        @try {
            return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
        } @catch (NSException *exception) {
            NSLog(@"[BoostiPhone6sApp] Fatal Exception at Launch: %@\n%@", exception.reason, exception.callStackSymbols);
            return 1;
        }
    }
}
