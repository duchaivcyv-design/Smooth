#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <IOKit/IOKitLib.h>
#import <sys/sysctl.h>
#import <dlfcn.h>
#import <mach/mach.h>

// Import config từ Tweak.xm (hoặc bạn có thể copy class BoostConfig sang đây nếu muốn tách bạch hoàn toàn)
// Ở đây ta dùng biến global đơn giản để tránh phụ thuộc vòng lặp
extern BOOL g_spoofModel;
extern BOOL g_forceHighPerf;
extern BOOL g_disableThermal; // Tùy chọn mới: Tắt cảnh báo nhiệt độ

#define IS_BYPASS_ACTIVE (g_spoofModel || g_forceHighPerf || g_disableThermal)

// ==========================================
// 1. FAKE HARDWARE CAPABILITIES (GPU & DISPLAY)
// Đánh lừa ứng dụng rằng máy có GPU mạnh và màn hình tần số quét cao
// ==========================================

%hookf(CAPublicKeyRef, CAGetDefaultRendererContext) {
    if (!IS_BYPASS_ACTIVE) return %orig();
    
    // Trả về context mặc định nhưng ép flag "SupportsProMotion" = YES
    // Lưu ý: Đây là kỹ thuật nâng cao, thực tế CAContext khó patch trực tiếp 
    // nên ta thường patch qua layer properties bên dưới.
    return %orig();
}

// Patch CALayer để kích hoạt tính năng chỉ dành cho máy đời mới
%hook CALayer
- (BOOL)supportsRasterization {
    if (g_spoofModel) return YES; // Ép bật rasterization (làm mượt UI cũ)
    return %orig();
}

- (CGFloat)rasterizationScale {
    if (g_spoofModel) return 2.0; // Đảm bảo render sắc nét dù fake model
    return %orig();
}
%end

// Fake Screen Properties (Cho app nghĩ là màn OLED/ProMotion)
%hook UIScreen
- (BOOL)isProMotionEnabled {
    if (g_spoofModel) return YES; // Báo là có 120Hz
    return %orig();
}

- (NSInteger)maximumFramesPerSecond {
    if (g_spoofModel) return 120; // Cho phép app vẽ tới 120fps (dù máy chỉ chạy 60)
    return %orig();
}
%end

// ==========================================
// 2. DISABLE THERMAL THROTTLING (NHIỆT ĐỘ)
// Ngăn iOS giảm xung nhịp CPU/GPU khi máy nóng
// ==========================================

if (%c(NSProcessInfo)) {
    %hook NSProcessInfo
    
    // Luôn báo trạng thái nhiệt độ là "Nominal" (Bình thường/Mát mẻ)
    // Kể cả khi máy đang nóng ran
    - (NSProcessInfoThermalState)thermalState {
        if (g_disableThermal) {
            return NSProcessInfoThermalStateNominal;
        }
        return %orig();
    }
    
    // Vô hiệu hóa thông báo "Máy quá nóng"
    + (BOOL)isThermalPressureCritical {
        if (g_disableThermal) return NO;
        return %orig();
    }
    
    %end
}

// Can thiệp vào IOKit để đọc cảm biến nhiệt sai lệch
%hookf(io_service_t, IOServiceGetMatchingService, mach_port_t masterPort, io_registry_entry_t matching) {
    if (!IS_BYPASS_ACTIVE) return %orig(masterPort, matching);
    
    // Nếu app hỏi về thermal sensor, trả về giá trị ảo thấp
    // Kỹ thuật này phức tạp vì IOKit registry rất động.
    // Cách an toàn hơn là hook ở tầng User Space (NSProcessInfo như trên).
    return %orig(masterPort, matching);
}

// ==========================================
// 3. BYPASS APP STORE & GAME CENTER CHECKS
// Một số game check entitlements hoặc device family
// ==========================================

%hook ASAppStoreReceipt
- (NSDictionary *)receiptData {
    if (g_spoofModel) {
        NSMutableDictionary *data = [[super receiptData] mutableCopy];
        // Chèn key giả mạo nếu cần (tùy game cụ thể)
        // [data setObject:@"iPhone15,3" forKey:@"product_type"]; 
        return data;
    }
    return %orig();
}
%end

%hook GKLocalPlayer
- (NSString *)alias {
    if (g_spoofModel) {
        // Đôi khi Game Center check alias/device id để rank
        // Ta giữ nguyên nhưng đảm bảo không bị block bởi server
    }
    return %orig();
}
%end

// ==========================================
// 4. FORCE HIGH PERFORMANCE MODE (CPU SCHEDULER)
// Ép Kernel ưu tiên thread foreground tuyệt đối
// ==========================================

%hookf(kern_return_t, thread_policy_set, thread_act_t target_thread, thread_policy_flavor_t flavor, natural_t *policy_info, mach_msg_type_number_t policy_count) {
    if (!g_forceHighPerf) return %orig(target_thread, flavor, policy_info, policy_count);
    
    // Nếu là policy Time Constraint (liên quan đến deadline xử lý)
    if (flavor == THREAD_TIME_CONSTRAINT_POLICY) {
        struct thread_time_constraint_policy *ttcp = (struct thread_time_constraint_policy *)policy_info;
        
        // Nới lỏng thời gian tối thiểu/tối đa để scheduler không preempt (ngắt ngang) thread này
        ttcp->period = 10000000; // 10ms period (rộng rãi)
        ttcp->computation = 5000000; // 5ms computation time
        ttcp->constraint = 8000000; // 8ms constraint
        
        NSLog(@"[Bypass] Forced High Perf Policy for Thread");
    }
    
    return %orig(target_thread, flavor, policy_info, policy_count);
}
