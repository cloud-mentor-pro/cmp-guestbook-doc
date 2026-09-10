# Đưa ứng dụng lên Production: High Availability & Auto Scaling

> Bài workshop — tổng hợp EC2, AMI, VPC, S3, RDS, Route53, ALB, ASG đã
> học thành 1 kiến trúc production hoàn chỉnh, demo 2 chiến lược deploy
> (code-only vs rebuild AMI).

Bài lab dành cho học viên lớp AWS SAA — Cloud Mentor Pro.
Thời lượng: **~120 phút**.

## Đối tượng học viên & kiến thức tiền đề

Học viên đã học qua: EC2, AMI, VPC, S3, RDS, Route53, ALB, ASG. Bài này
**không dạy lại** các service trên mà tổng hợp chúng vào 1 kiến trúc
production hoàn chỉnh: hạ tầng nền (VPC, S3, IAM...) dựng sẵn qua
CloudFormation, còn Target Group, ALB, ASG và **2 chiến lược deploy**
được thao tác thủ công trong lớp.

## Ứng dụng demo: Cloud Mentor Pro Guestbook

App nhỏ (Node.js + Express) có:
- Form ghi lưu bút (name, message) → lưu **RDS**
- Upload ảnh qua **S3 Presigned URL** (browser upload trực tiếp, không qua EC2)
- Hiển thị trạng thái kết nối Database ngay trên trang chủ (✅ / ❌)

## Cấu trúc thư mục

```
cmp-guestbook-doc/
├── README.md                          # File này
├── docs/                              # Các bước thực hiện, mỗi bước 1 file .md
│   ├── 00-tong-quan-kien-truc.md
│   ├── 01-cloudformation-foundation.md
│   ├── 02-build-golden-ami.md
│   ├── 03-tao-rds.md
│   ├── 04-target-group.md
│   ├── 05-application-load-balancer.md
│   ├── 06-auto-scaling-group.md
│   ├── 07-test-end-to-end.md
│   ├── 08-route53-custom-domain.md
│   ├── 09-deploy-thay-doi-code.md
│   ├── 10-deploy-thay-doi-ami.md
│   └── 11-cleanup-teardown.md
├── cloudformation/                    # Template + parameters
│   ├── template.yaml
│   └── parameters.json
└── scripts/                            # Script hỗ trợ deploy
```

## Thứ tự thực hiện trong buổi học

Xem chi tiết trong từng file ở `docs/`, theo đúng thứ tự đánh số
`01` → `11`. File `00` nên đọc trước giờ học (hoặc dùng làm slide mở đầu).

## Ghi chú

- Toàn bộ truy cập vào EC2 (Bastion + App instances) dùng **SSM Session
  Manager** — không dùng SSH key pair.
- Tài nguyên nền tảng (VPC, subnet, SG, NAT, Bastion, IAM Role, S3) được
  dựng bằng **CloudFormation** để tiết kiệm thời gian lớp học.
- Tài nguyên chính của bài học (Target Group, ALB, ASG) được tạo **thủ
  công** để học viên hiểu rõ từng thành phần.
- Thực hiện **bước 11 (Cleanup)** để tránh phát sinh
  chi phí ngoài giờ học, đặc biệt là NAT Gateway và RDS.
