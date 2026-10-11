NỘI DUNG
- source/Tweak_V16_AppleNative_Smooth_Safe.xm: tweak runtime V16.
- source/RootListController.m: giao diện, cài đặt, chọn server và Admin/Admin Dev.
- admin-backend/: backend Node.js/Express đi kèm để tham khảo/triển khai các route Admin.

CÁC ĐIỂM ĐÃ SỬA
1. Tách công tắc Hz và FPS; mỗi công tắc chỉ tác động điều khiển của nó. Bật/tắt sẽ ghi payload và yêu cầu tiến trình hiện tại áp dụng lại giá trị trên các UIWindowScene/CADisplayLink đang được theo dõi.
2. Giá trị nhịp quét thực tế bị giới hạn bởi phần cứng: tối đa 60 Hz trên panel 60 Hz, tối đa 120 Hz trên thiết bị ProMotion được nhận diện. Mục “Mở Rộng 144” là lựa chọn cấu hình, không biến màn hình 60/120 Hz thành 144 Hz.
3. Công tắc Hz/FPS mới mặc định BẬT cho cài đặt mới; sau đó người dùng tự bật/tắt.
4. Căn thanh Liquid Glass theo vùng an toàn trái/phải, cập nhật lại khi layout/đổi hướng đổi kích thước. Chỉ có 5 mục (Home, Hz/FPS, Switch, Apps, Settings); nút tròn chọn tab được căn theo tâm từng mục.
5. Ngôn ngữ mặc định “auto” đọc ngôn ngữ ưu tiên của iOS và lưu mã ngôn ngữ vào payload; giao diện hiện có bản dịch đầy đủ theo nhánh Việt/English, các ngôn ngữ khác hiện dùng English làm phương án dự phòng.
6. Trình chọn server lần đầu vẫn mở Server Free hoặc đăng nhập Server Admin. Đăng nhập thành công mới mở luồng khai thác; Admin Dev console hiện có các thao tác gọi route backend và phân quyền vẫn do backend kiểm soát.
7. URL API có thể sửa tại Cài Đặt → Server API URL hoặc trực tiếp ở hộp đăng nhập Admin. URL HTTPS mặc định trong mã chỉ là gợi ý, CHƯA được xác minh hoặc đảm bảo đang hoạt động.

CẤU HÌNH SERVER
- Triển khai admin-backend lên hosting có HTTPS, dùng .env.example làm mẫu và đặt mật khẩu riêng.
- Tài khoản mẫu trong .env.example: admin username `apple.com`; Admin Dev username `admin.apple.com`. Password đọc từ biến ADMIN_PASSWORD và DEV_ADMIN_PASSWORD ở server. Giá trị ví dụ trong .env.example chỉ dành cho thử nghiệm; không dùng các mật khẩu ví dụ khi public.
- Nhập URL HTTPS thực tế của backend trong app. Không đưa file .env hoặc database có dữ liệu thật vào gói phát hành.
- Admin Dev cần role `admin_dev`; việc ẩn/hiện menu phía app không thay thế kiểm tra quyền server.

GIỚI HẠN KIỂM TRA
- Đã kiểm tra cân bằng ngoặc và cặp Logos group/hook ở mức tĩnh.
- Chưa build Theos vì môi trường này không có SDK/đường build iOS tương ứng; chưa cài thử trên máy jailbreak. Cần build bằng Theos, xem log clang và test trên thiết bị/phiên bản iOS mục tiêu trước khi dùng.
- API hệ thống công khai chỉ có thể đề nghị nhịp khung hình; iOS, ứng dụng/game, nhiệt độ, Low Power Mode và phần cứng vẫn có quyền giới hạn FPS. Không thể bảo đảm mọi surface hệ thống luôn chạy đúng một con số hoặc cam kết hết nóng/crash.
