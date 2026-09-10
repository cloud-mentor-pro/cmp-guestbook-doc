# Bước 10 — Demo Deploy: Thay đổi AMI (rebuild runtime)

**Thời lượng gợi ý:** 15 phút

## Mục tiêu

Chứng minh: khi thay đổi ở tầng **runtime/OS** (nâng version Node.js,
thêm package, patch OS...), **bắt buộc phải build AMI mới** và tạo
**Launch Template version mới** — không thể chỉ đổi code trên GitHub
như bước 09.

## Điều kiện tiên quyết

AMI v2 đã được bấm build từ cuối bước 07 (chạy nền trong lúc làm bước
08 — Route 53, và bước 09 — đổi code) — kiểm tra đã chuyển sang trạng
thái `available` trước khi bắt đầu bước này.

## Các bước thao tác (tóm tắt)

1. Kiểm tra AMI v2 ở EC2 Console → Images → AMIs → trạng thái `available`.
2. Vào Launch Template đã tạo ở bước 06 → **Create new template version**.
   - Giữ nguyên mọi cấu hình khác (SG, IAM Profile, User Data) — chỉ đổi AMI ID sang AMI v2.
3. Set version mới này làm **Default version** của Launch Template.
4. Vào ASG Console → Instance refresh → Start instance refresh (tương
   tự bước 09, nhưng lần này Launch Template version đã đổi).
5. Quan sát: ASG lần lượt terminate instance cũ (chạy AMI v1), launch
   instance mới (chạy AMI v2).
6. Xác nhận sau khi hoàn tất: toàn bộ instance mới chạy đúng AMI v2 —
   có thể kiểm tra qua thay đổi đã đưa vào AMI v2 (ví dụ version package
   mới, hoặc 1 dấu hiệu nhận biết đã chèn sẵn khi build AMI v2 ở bước 02/07).

## So sánh trực tiếp với bước 09 (nên làm ngay sau khi xong, còn trong bước này)

| | Bước 09: Đổi code | Bước 10: Đổi AMI |
|---|---|---|
| Thay đổi ở đâu | Code trên GitHub repo (branch/tag) | Image AMI |
| Launch Template | Không đổi | Tạo version mới |
| Thời gian build | Gần như tức thì (push GitHub) | 5-8 phút (build AMI) |
| Khi nào dùng | Sửa UI, sửa logic ứng dụng | Nâng version runtime, patch OS, đổi package hệ thống |
| Cơ chế rollout | Instance Refresh (Launch Template không đổi, instance mới `git pull`) | Instance Refresh (Launch Template version mới) |

## Điểm nhấn giảng dạy

- Cùng một lệnh/thao tác Instance Refresh, nhưng bản chất khác nhau ở
  chỗ Launch Template có version mới hay không — đây là điểm học viên
  hay nhầm lẫn nhất, nên nhấn mạnh lại bằng bảng so sánh trên.
- Nhắc lại: đây chính là lý do vì sao kiến trúc tách biệt AMI (runtime)
  và Code (GitHub) ngay từ đầu bài học — nếu gộp chung, mọi thay đổi dù
  nhỏ đều phải build lại AMI, rất lãng phí thời gian trong thực tế.

## Checklist hoàn thành bước này

- [ ] AMI v2 ở trạng thái `available` trước khi bắt đầu
- [ ] Launch Template có version mới, trỏ đúng AMI v2, đã set làm default
- [ ] Instance Refresh hoàn tất, toàn bộ instance chạy AMI v2
- [ ] Học viên phân biệt được rõ ràng sự khác nhau giữa bước 09 và bước 10
