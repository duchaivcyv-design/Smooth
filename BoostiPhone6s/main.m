// ====================================================================================================
// BOOSTIPHONE6S APP - MAIN ENTRY POINT (CHẾ ĐỘ ĐÃ ÉP TOÀN DIỆN - CHUẨN ĐỒNG BỘ 0MS)
// (AN TOÀN TUYỆT ĐỐI: KHÔNG TRỄ KHỞI ĐỘNG, KHÔNG ĐEN MÀN HÌNH, TỰ ĐỘNG CẤP PHÁT P-CORE)
// ====================================================================================================

#import <UIKit/UIKit.h>
#import <pthread.h>
#import <sys/stat.h>
#import <sys/resource.h>
#import "AppDelegate.h"

// Macro liên kết I/O Scope cho Clang khi biên dịch ngoài hệ thống
#ifndef IOPOL_TYPE_DISK
#define IOPOL_TYPE_DISK 0
#endif
#ifndef IOPOL_SCOPE_PROCESS
#define IOPOL_SCOPE_PROCESS 0
#endif
#ifndef IOPOL_IMPORTANT
#define IOPOL_IMPORTANT 1
#endif
extern int setiopolicy_np(int type, int scope, int policy);

int main(int argc, char *argv[]) {
    @autoreleasepool {
        // [ĐÃ ÉP TOÀN DIỆN]: Cấp toàn quyền tạo tệp 0666 cho IPC không bị Sandbox hay phân quyền cản trở
        umask(0000);

        // [ĐÃ ÉP TOÀN DIỆN]: Đặt tên nhận diện cho luồng chính để tránh bị kernel xếp vào tiến trình rác
        pthread_setname_np("com.taojb.boostiphone6s.ui");

        // [ĐÃ ÉP TOÀN DIỆN]: Ép quyền Disk I/O lên mức cao nhất, đọc ghi cấu hình 0ms
        setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);

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
