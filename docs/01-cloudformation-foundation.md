# Bước 01 — CloudFormation: Dựng hạ tầng nền

**Thời lượng gợi ý:** 15 phút
**File liên quan:** `cloudformation/template.yaml`, `cloudformation/parameters.json` — điền `AppDomainName` trong
`parameters.json` bằng domain riêng của bạn trước khi deploy

## Mục tiêu

Dựng toàn bộ hạ tầng nền bằng 1 lệnh `aws cloudformation deploy`, để
không tốn thời gian lớp học vào những phần học viên đã biết (VPC, S3
CORS, IAM Role cơ bản).

## Phạm vi tài nguyên trong template

### Networking (VPC 3-tier, 6 subnet, 2 AZ)
- 1 VPC
- 2 Public Subnet (tier ALB) — mỗi AZ 1 subnet
- 2 Private App Subnet (tier ứng dụng) — mỗi AZ 1 subnet
- 2 Private DB Subnet (tier database) — mỗi AZ 1 subnet
- 1 Internet Gateway
- 1 NAT Gateway (đặt ở Public Subnet AZ-1) + Elastic IP
- Route Table cho từng tier (Public / App / DB) + associations
- DB Subnet Group (dùng cho RDS ở bước 03)

### Security Groups
- **Bastion SG**: không mở inbound port nào (truy cập qua SSM, không cần SSH)
- **ALB SG**: inbound 80/443 từ `0.0.0.0/0`
- **App SG**: inbound 80 chỉ từ ALB SG
- **DB SG**: inbound 3306 (MySQL) từ App SG **và** từ Bastion SG (Bastion
  cần reach RDS để làm trạm trung chuyển cho SSM port-forwarding tunnel
  từ local, dùng chạy schema SQL ở bước 03 — không phải App traffic)

### IAM
- **App Instance Role + Instance Profile**:
  - Managed policy `AmazonSSMManagedInstanceCore` (truy cập qua SSM)
  - Inline policy: `s3:PutObject`, `s3:GetObject` trên bucket của lab
    (dùng để sinh presigned URL)
- **Bastion Instance Role + Instance Profile**:
  - Managed policy `AmazonSSMManagedInstanceCore`
  - Inline policy: quyền tạo AMI (`ec2:CreateImage`, `ec2:DescribeImages`...)
    nếu dùng Bastion làm luôn AMI-builder

### S3
- 1 Bucket lưu ảnh upload từ Guestbook
- `BucketName`: `lab-guestbook-s3-<account-id>` — có hậu tố
  `AWS::AccountId` để tránh trùng tên giữa các học viên (mỗi học viên 1
  AWS account riêng)
- CORS configuration cho phép `PUT`/`GET` từ 3 origin: `http://localhost:3000`
  (local dev), ALB DNS thô dạng wildcard (`http://*.us-east-1.elb.amazonaws.com`,
  dùng ở bước 07), và domain riêng học viên (`AppDomainName`, gắn ở bước 08)
- Versioning bật sẵn (phòng khi cần rollback trong demo deploy code)

### Bastion Host
- 1 EC2 instance nhỏ (t3.micro) trong Public Subnet AZ-1
- Gắn Instance Profile của Bastion
- Không cần key pair — truy cập qua **SSM Session Manager**
- Dùng làm AMI-builder trong bước 02

## Tham số (parameters.json)

Tách riêng file `parameters.json` khỏi `template.yaml` để:
- Dễ tái sử dụng template cho nhiều lớp học khác nhau (đổi CIDR, tên bucket...)
- Học viên không cần sửa trực tiếp vào code CloudFormation

Nhóm tham số dự kiến:
- `Environment` — prefix đặt tên tài nguyên (mặc định `lab`, đổi thành
  `lab-<alias>` nếu nhiều học viên dùng chung 1 AWS account)
- `AppDomainName` — domain riêng của học viên (vd `asg-lab.cloudmentor.pro`),
  dùng để cấu hình CORS cho S3 Bucket ngay từ bước này, dù Alias Record
  thật sự chỉ tạo ở bước 08
- CIDR block cho VPC và 6 subnet
- AMI ID cho Bastion (dùng SSM Parameter `latest Amazon Linux 2023`)
- Instance type cho Bastion

## Output cần thiết (CloudFormation Outputs)

Các giá trị này sẽ được dùng lại ở các bước thủ công tiếp theo (04-06):
- VPC ID
- Danh sách Public Subnet IDs, App Subnet IDs, DB Subnet IDs
- ALB Security Group ID, App Security Group ID, DB Security Group ID
- App Instance Profile ARN/Name
- S3 Bucket Name
- Bastion Instance ID
- DB Subnet Group Name

## Checklist hoàn thành bước này

- [ ] Stack CloudFormation ở trạng thái `CREATE_COMPLETE`
- [ ] Vào được Bastion qua SSM Session Manager (Console → EC2 → Connect → Session Manager)
- [ ] Xác nhận Bastion instance có Instance Profile đúng (kiểm tra qua `aws sts get-caller-identity` trong session)
- [ ] Ghi lại các Output cần dùng cho bước 02-06 (có thể copy vào 1 file note hoặc dùng trực tiếp qua `aws cloudformation describe-stacks`)
