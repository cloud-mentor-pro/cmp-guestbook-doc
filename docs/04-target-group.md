# Bước 04 — Tạo Target Group

**Thời lượng gợi ý:** 5 phút

## Mục tiêu

- Hiểu vai trò của Target Group: nơi ALB gửi traffic đến, và là nơi
  Auto Scaling Group đăng ký/hủy đăng ký instance tự động.
- Tạo Target Group trước khi tạo ALB (vì ALB Listener cần trỏ vào 1
  Target Group có sẵn).

## Các bước thao tác (tóm tắt)

1. EC2 Console → Target Groups → Create target group.
   - Tên: `lab-guestbook-tg`.
2. Target type: **Instances** (ASG sẽ tự đăng ký instance vào đây).
3. Protocol: HTTP, Port: 80.
4. VPC: chọn VPC đã tạo ở bước 01.
5. Health check:
   - Protocol: HTTP
   - Path: `/`
   - Healthy threshold / Unhealthy threshold / Timeout / Interval: giữ
     giá trị mặc định, giải thích ngắn gọn ý nghĩa từng thông số
6. Chưa cần đăng ký target nào ở bước này — để trống, vì instance sẽ do
   ASG tự động đăng ký ở bước 06.

## Checklist hoàn thành bước này

- [ ] Target Group đã tạo, protocol/port đúng (HTTP:80)
- [ ] Health check path đã cấu hình và học viên hiểu ý nghĩa từng thông số
- [ ] Chưa có target nào được đăng ký (đúng như dự kiến, sẽ do ASG đảm nhiệm)
