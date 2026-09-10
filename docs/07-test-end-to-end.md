# Bước 07 — Test end-to-end trước khi demo deploy

**Thời lượng gợi ý:** 8 phút

## Mục tiêu

Xác nhận toàn bộ hệ thống hoạt động đúng **trước khi** gắn domain (bước
08) và bước vào 2 demo deploy (bước 09-10). Nếu bỏ qua bước này, khi
demo deploy gặp lỗi sẽ không biết lỗi phát sinh từ đâu (do code mới,
hay do hạ tầng nền có vấn đề từ trước).

## Các việc cần kiểm tra

1. Truy cập ứng dụng qua **ALB DNS name** (ghi lại từ bước 05).
2. Trang chủ hiển thị đúng trạng thái:
   - ✅ Đã kết nối Database thành công
   - Hiển thị được Instance ID (lấy qua IMDSv2) — xác nhận request đang
     được load balance qua nhiều instance khác nhau (refresh nhiều lần,
     quan sát Instance ID đổi qua lại giữa các AZ).
3. Thử tính năng chính của Guestbook:
   - Nhập tên + lời nhắn → Submit → xác nhận entry mới hiển thị trong danh sách.
   - Upload 1 ảnh → xác nhận:
     - Gọi được `/presign` để lấy presigned URL
     - Ảnh PUT thẳng lên S3 thành công (kiểm tra qua S3 Console)
     - Ảnh hiển thị đúng trong danh sách guestbook sau khi submit
4. Vào Target Group Console → xác nhận toàn bộ instance đang ở trạng
   thái `healthy`.

## Nếu có lỗi — hướng xử lý nhanh (tham khảo, không thuộc phạm vi checklist)

- Lỗi ❌ chưa kết nối DB: kiểm tra lại Security Group DB (đã mở port từ
  App SG chưa), kiểm tra biến môi trường DB_HOST trong User Data.
- Lỗi upload ảnh thất bại: kiểm tra CORS configuration của S3 Bucket,
  kiểm tra IAM policy của App Instance Profile.
- Instance `unhealthy` trong Target Group: kiểm tra health check path,
  kiểm tra App Security Group có cho phép ALB SG gọi vào port 80 không.

## Checklist hoàn thành bước này

- [ ] Truy cập ALB DNS thành công, trang hiển thị ✅ kết nối DB
- [ ] Submit guestbook entry thành công, dữ liệu lưu đúng vào RDS
- [ ] Upload ảnh qua presigned URL thành công, ảnh hiển thị đúng
- [ ] Toàn bộ instance trong Target Group ở trạng thái `healthy`
- [ ] (Chuẩn bị cho bước 09-10) Đã bấm **Create Image lần 2** (AMI v2) để chạy nền, chuẩn bị cho demo bước 10
