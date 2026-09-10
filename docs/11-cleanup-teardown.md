# Bước 11 — Cleanup / Teardown

**Thời lượng gợi ý:** 5 phút (cuối buổi) + nhắc học viên tự kiểm tra sau giờ học

## Mục tiêu

Tránh phát sinh chi phí ngoài giờ học. Đây là lab public trên GitHub,
nên phần này cần viết **rõ ràng, theo đúng thứ tự phụ thuộc**, để học
viên tự làm theo mà không bị lỗi do xóa nhầm thứ tự (ví dụ xóa VPC
trước khi xóa NAT Gateway sẽ báo lỗi).

## Tài nguyên tốn phí cao cần lưu ý

1. **NAT Gateway** — tính phí theo giờ + theo dung lượng, tốn nhất
   trong lab này. **Lưu ý quan trọng:** NAT Gateway do CloudFormation
   quản lý (tạo ở bước 01), nên **chỉ bị xóa ở bước cuối cùng** (xóa
   CloudFormation stack, mục 9 bên dưới) — không có cách xóa riêng lẻ
   sớm hơn mà không phá vỡ stack. Vì vậy: **đừng trì hoãn bước 9**, thực
   hiện toàn bộ trình tự cleanup (mục 1-9) ngay sau khi kết thúc buổi
   học, không để qua đêm — đây chính là lý do NAT Gateway tốn phí nhất.
2. **RDS instance** — tính phí theo giờ, xóa sớm nếu không cần giữ lại
   dữ liệu (hoặc snapshot lại nếu cần lưu để đối chiếu). Khác NAT
   Gateway, RDS được tạo thủ công (bước 03) nên **có thể xóa độc lập,
   sớm hơn**, không cần chờ tới bước xóa stack.

## Thứ tự xóa đề xuất (từ trên xuống, theo đúng phụ thuộc)

1. Xóa **Route 53 Record** (Alias record trỏ vào ALB) — nếu Hosted Zone
   dùng chung cho nhiều lớp thì chỉ xóa record, giữ lại Hosted Zone.
2. Xóa **Auto Scaling Group** (set Desired = 0 trước, hoặc xóa thẳng ASG
   — ASG sẽ tự terminate toàn bộ instance đang quản lý).
3. Xóa **Application Load Balancer**.
4. Xóa **Target Group**.
5. Xóa **Launch Template** (tất cả version).
6. Xóa **RDS instance** (bỏ tick "Create final snapshot" nếu không cần lưu).
7. Xóa **AMI** (cả v1 và v2) — nhớ xóa kèm **snapshot** liên quan (EBS
   snapshot đứng sau AMI, xóa AMI không tự động xóa snapshot).
8. Xóa **object trong S3 Bucket** (bucket có versioning nên cần xóa cả
   version cũ trước khi xóa được bucket), sau đó xóa bucket nếu không
   cần giữ lại cho lớp sau.
9. Cuối cùng: xóa **CloudFormation stack** ở bước 01 — thao tác này sẽ
   tự động dọn: VPC, subnet, route table, Internet Gateway, **NAT
   Gateway + Elastic IP** (tài nguyên tốn phí nhất, xem lưu ý ở đầu
   file), Security Group, IAM Role (App + Bastion), Bastion instance.
   - Lưu ý: nếu S3 Bucket được tạo trong CloudFormation và chưa xóa
     hết object ở bước 8, việc xóa stack sẽ **fail** — luôn xóa object
     trong bucket trước khi xóa stack.

## Checklist cleanup

- [ ] Route 53 record đã xóa
- [ ] ASG đã xóa (không còn instance nào chạy)
- [ ] ALB + Target Group đã xóa
- [ ] Launch Template đã xóa
- [ ] RDS instance đã xóa (đã quyết định có cần snapshot hay không)
- [ ] AMI + snapshot liên quan đã xóa (cả v1, v2)
- [ ] S3 Bucket đã rỗng (kể cả version cũ) trước khi xóa stack
- [ ] CloudFormation stack ở trạng thái `DELETE_COMPLETE`
- [ ] Kiểm tra lại Billing Console / Cost Explorer sau 24h để chắc chắn không còn resource nào bị bỏ sót
