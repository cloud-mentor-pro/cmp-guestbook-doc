# Bước 05 — Tạo Application Load Balancer

**Thời lượng gợi ý:** 12 phút

## Mục tiêu

- Tạo ALB làm điểm vào duy nhất (single entry point) cho ứng dụng.
- Gắn ALB vào Target Group đã tạo ở bước 04.
- Đặt nền cho bước 08 (Route 53) — ALB DNS name sẽ là đích của Alias Record.

## Các bước thao tác (tóm tắt)

1. EC2 Console → Load Balancers → Create Load Balancer → chọn
   **Application Load Balancer**.
   - Tên: `lab-guestbook-alb`
2. Scheme: **Internet-facing**.
3. IP address type: IPv4.
4. VPC: chọn VPC đã tạo ở bước 01.
5. Mappings: chọn **2 Public Subnet** (2 AZ khác nhau) — nhấn mạnh: ALB
   bắt buộc phải trải trên ≥2 AZ, đây chính là yếu tố tạo nên **High
   Availability** ở tầng phân phối traffic.
6. Security Group: chọn **ALB Security Group** đã tạo sẵn ở bước 01
   (inbound 80/443 từ `0.0.0.0/0`).
7. Listener: HTTP:80 → Forward đến Target Group đã tạo ở bước 04.
8. (Tùy chọn nếu còn thời gian) HTTPS:443 — cần ACM certificate, có thể
   bỏ qua và làm sau.
9. Tạo xong → ghi lại **ALB DNS name** để dùng test ở bước 07 và cấu
   hình Route 53 ở bước 08.

## Điểm nhấn giảng dạy

- Giải thích listener rule mặc định (forward toàn bộ traffic đến 1
  Target Group) — liên hệ tới path-based/host-based routing như một
  chủ đề nâng cao (không cần thực hành trong lab này).
- Nhấn mạnh: ALB **chưa có instance nào phía sau** — sẽ hiển thị lỗi
  `503 Service Temporarily Unavailable` cho đến khi ASG ở bước 06 đăng
  ký instance khỏe mạnh vào Target Group.

## Checklist hoàn thành bước này

- [ ] ALB ở trạng thái `Active`
- [ ] Listener HTTP:80 đã trỏ đúng Target Group ở bước 04
- [ ] ALB đặt ở 2 Public Subnet thuộc 2 AZ khác nhau
- [ ] Đã ghi lại ALB DNS name
- [ ] Học viên hiểu vì sao truy cập ALB DNS lúc này sẽ báo lỗi 503 (bình thường, vì chưa có ASG)
