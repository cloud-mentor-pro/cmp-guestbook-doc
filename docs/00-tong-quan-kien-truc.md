# Bước 00 — Tổng quan kiến trúc (đọc trước giờ học)

## Mục tiêu

- **Đây là bài capstone**: tổng hợp EC2, AMI, VPC, S3, RDS, Route 53, ALB,
  ASG đã học thành **một kiến trúc production hoàn chỉnh**.
- Ôn nhanh kiến trúc 3-tier mà học viên đã biết (VPC, S3, RDS, Route53).
- Giới thiệu ứng dụng demo: **Cloud Mentor Pro Guestbook**.

## Kiến trúc mục tiêu (sau khi hoàn thành lab)

```
                          Route 53 (Alias Record)
                                   │
                                   ▼
                    ┌─────────────────────────┐
                    │   Application Load       │
   Internet ───────►│   Balancer (public)      │
                    └─────────┬────────────────┘
                              │  Target Group
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        ┌──────────┐   ┌──────────┐    ┌──────────┐
        │ App EC2  │   │ App EC2  │    │ App EC2  │   ◄── Auto Scaling Group
        │ (AZ-1)   │   │ (AZ-2)   │    │  (...)    │       (Private App Subnet)
        └────┬─────┘   └────┬─────┘    └────┬─────┘
             │  presigned URL           │
             ▼                          ▼
        ┌──────────┐              ┌──────────┐
        │    S3     │              │   RDS     │
        │  (ảnh)    │              │ (Private  │
        └──────────┘              │  DB Subnet)│
                                   └──────────┘

        Bastion Host (Public Subnet) ── SSM Session Manager only
```

## Mapping kiến thức cũ → vai trò trong bài lab

| Kiến thức đã học | Vai trò trong lab hôm nay |
|---|---|
| EC2 | Compute chạy ứng dụng (App instances) và Bastion (AMI-builder) |
| AMI | Đóng gói sẵn OS + runtime (Golden AMI) để ASG launch instance mới nhanh, nhất quán |
| VPC (3-tier, 6 subnet) | Hạ tầng mạng: Public (ALB) / App (private) / DB (private) |
| S3 + Presigned URL | Lưu ảnh upload từ Guestbook, browser upload trực tiếp |
| RDS | Lưu dữ liệu guestbook (name, message, image_key) |
| Route 53 | Custom domain trỏ vào ALB |
| ALB | Phân phối traffic, health check, single entry point |
| ASG | Tự động scale, tự thay thế instance lỗi, rolling deploy |

## Timeline tổng thể buổi học (120 phút)

| Bước | Nội dung | Thời gian |
|---|---|---|
| 01 | CloudFormation: VPC, SG, NAT, Bastion, IAM Role, S3 | 15' |
| 02 | Build Golden AMI (qua Bastion/SSM) | ~10' (chạy nền) |
| 03 | Tạo RDS (chạy song song bước 02) | ~10' (chạy nền) |
| 04 | Tạo Target Group | 5' |
| 05 | Tạo Application Load Balancer | 12' |
| 06 | Tạo Launch Template + Auto Scaling Group | 15' |
| 07 | Test end-to-end qua ALB DNS | 8' |
| 08 | Route 53 — gắn custom domain | 10' |
| 09 | Demo deploy: thay đổi code (GitHub) | 15' |
| 10 | Demo deploy: thay đổi AMI | 15' |
| 11 | Cleanup / Teardown | 5' |
| — | Buffer / Q&A | 10' |

Ghi chú: bước 02 và 03 chạy **song song** (không chờ tuần tự) để tiết kiệm
thời gian — xem chi tiết trong từng file tương ứng.
