# Bước 06 — Launch Template & Auto Scaling Group

**Thời lượng gợi ý:** 15 phút

## Điều kiện tiên quyết

- AMI ở bước 02 đã ở trạng thái `available`.
- RDS ở bước 03 đã ở trạng thái `available` (hoặc ít nhất đã có
  endpoint để điền vào User Data — có thể instance đầu tiên fail kết
  nối DB tạm thời, ASG sẽ tự thay thế sau khi Instance Refresh nếu cần,
  nhưng tốt nhất nên đợi RDS xong trước bước này).

## Mục tiêu

- Tạo Launch Template: định nghĩa AMI, instance type, Security Group,
  IAM Instance Profile, và **User Data script** (pull code từ **GitHub**
- Tạo Auto Scaling Group dùng Launch Template trên, đặt trong **App
  Subnet (private, 2 AZ)**, gắn vào Target Group ở bước 04.

## Phần 1 — Launch Template

Nội dung cấu hình chính (chi tiết User Data script sẽ viết ở giai đoạn
sau, chưa thuộc phạm vi tổ chức thư mục này). Đặt tên `lab-guestbook-lt`:

1. AMI: chọn AMI v1 từ bước 02.
2. Instance type: nhỏ (vd: `t3.micro`).
3. Security Group: **App Security Group** đã tạo ở bước 01 (chỉ nhận
   traffic từ ALB SG).
4. IAM Instance Profile: **App Instance Profile** đã tạo ở bước 01 (có
   quyền SSM + S3).
5. User Data: script nhỏ, cố định — nhiệm vụ duy nhất là **`git clone`/
   `git pull` code mới nhất từ GitHub repo (theo `APP_REPO_URL` +
   `APP_REF`) và khởi động lại service**. Đồng thời set các biến môi
   trường kết nối DB (DB_HOST, DB_USER, DB_PASS, DB_NAME lấy từ giá trị
   đã ghi ở bước 03), biến S3_BUCKET (từ Output CloudFormation bước
   01 — bucket này chỉ dùng cho ảnh guestbook, **không** liên quan code
   ứng dụng), và AWS_REGION=us-east-1 (cố định cho toàn bộ lab).
6. Không dùng key pair — instance sẽ được truy cập qua SSM nếu cần
   debug.

### User Data — dán nguyên vào ô "User data" khi tạo Launch Template

Thay các giá trị trong `<...>` bằng giá trị thật của lớp (`DB_HOST`/
`DB_USER`/`DB_PASS` lấy từ RDS tạo ở bước 03, `S3_BUCKET` lấy từ
CloudFormation Output ở bước 01) trước khi dán:

```bash
#!/bin/bash
set -euo pipefail

APP_DIR="/opt/guestbook"
APP_REPO_URL="https://github.com/cloud-mentor-pro/cmp-guestbook-app.git"
APP_REF="main"   # cố định "main" cho toàn bộ lab

# AMI v1 co unit After=cloud-final.service. User Data chay trong cloud-final,
# nen restart service tai day co the tao ordering wait. Bo dependency nay
# truoc khi start app trong qua trinh bootstrap.
sed -i 's/ cloud-final.service//g' /etc/systemd/system/guestbook.service
systemctl daemon-reload

# Biến môi trường cho systemd (EnvironmentFile=-/etc/guestbook.env, đã khai
# báo sẵn trong systemd unit ở bước 02)
cat > /etc/guestbook.env <<ENV
PORT=80
DB_HOST=<rds-endpoint-tu-buoc-03>
DB_USER=<db-username>
DB_PASS=<db-password>
DB_NAME=guestbook
S3_BUCKET=<bucket-name-tu-cloudformation-output-buoc-01>
AWS_REGION=us-east-1
ENV
chmod 600 /etc/guestbook.env

# Lấy code ứng dụng từ GitHub - clone lần đầu (thư mục chưa tồn tại vì AMI
# không chứa code), hoặc pull (reset cứng) nếu instance chạy lại User Data
if [ -d "$APP_DIR/.git" ]; then
  cd "$APP_DIR"
  git fetch origin
  git reset --hard "origin/$APP_REF"
else
  git clone --branch "$APP_REF" "$APP_REPO_URL" "$APP_DIR"
fi

cd "$APP_DIR"
npm install --production

systemctl restart guestbook.service
```

## Phần 2 — Auto Scaling Group

Đặt tên `lab-guestbook-asg`:

1. Chọn Launch Template vừa tạo.
2. VPC + Subnet: chọn **2 App Subnet (private)** — nhấn mạnh: app
   instances không cần public IP, toàn bộ traffic vào đều qua ALB.
3. Attach to existing Load Balancer → chọn Target Group ở bước 04.
4. Health check type: **ELB** (không chỉ dùng EC2 status check — để
   ASG dựa vào kết quả health check của ALB, sát với thực tế ứng dụng
   hơn là chỉ kiểm tra instance sống/chết).
5. Desired capacity: 2, Min: 2, Max: 4 (ví dụ, tùy thời gian demo scale
   nếu có).
6. Không cần cấu hình scaling policy phức tạp trong phạm vi lab này —
   ghi chú đây là chủ đề có thể mở rộng ở buổi sau (target tracking,
   scheduled scaling...).

## Checklist hoàn thành bước này

- [ ] Launch Template tạo thành công, đúng AMI/SG/IAM Profile/User Data
- [ ] ASG đặt trong App Subnet (private), gắn đúng Target Group
- [ ] Health check type: ELB
- [ ] Desired capacity đạt, tất cả instance ở trạng thái `healthy` trong Target Group
- [ ] Đã set đúng biến môi trường DB_HOST/DB_USER/DB_PASS/DB_NAME/S3_BUCKET/APP_REPO_URL/APP_REF/AWS_REGION trong User Data
- [ ] Xác nhận `git clone`/`git pull` chạy thành công lúc instance khởi động (kiểm tra qua log User Data nếu cần)
