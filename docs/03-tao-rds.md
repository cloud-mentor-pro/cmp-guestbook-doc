# Bước 03 — Tạo RDS (chạy song song với bước 02)

**Thời lượng gợi ý:** ~5 phút thao tác + chạy nền song song với bước 02

## Mục tiêu

- Tạo RDS instance (MySQL/MariaDB) trong DB Subnet (private, 2 AZ) đã
  dựng sẵn ở bước 01.
- Vì học viên đã học RDS ở bài trước, bước này **không giảng lại lý
  thuyết RDS** — chỉ thao tác nhanh để phục vụ app.

## Lưu ý quan trọng: bấm bước này NGAY sau khi bấm Create Image ở bước 02

RDS instance mất khoảng 5-10 phút để chuyển sang trạng thái `available`.
Bấm tạo RDS ngay sau khi build AMI (không chờ AMI xong) để 2 tiến trình
chạy nền song song — tiết kiệm ~10 phút chết của buổi học.

## Các bước thao tác (tóm tắt)

1. Vào RDS Console → Create database.
2. Engine: MySQL (hoặc MariaDB tùy lựa chọn của lớp).
3. Instance class: nhỏ nhất phù hợp (vd: `db.t3.micro`) — đây là lab,
   không cần cấu hình production.
4. **Subnet group**: chọn DB Subnet Group đã tạo sẵn ở bước 01 (CloudFormation).
5. **Security Group**: chọn DB Security Group đã tạo sẵn ở bước 01
   (mở port 3306 từ App Security Group **và** Bastion Security Group —
   Bastion cần để phục vụ SSM tunnel chạy schema, xem bên dưới).
6. **Public access**: chọn **No** — RDS phải nằm hoàn toàn private,
   nhấn mạnh lại nguyên tắc 3-tier đã học.
7. **DB instance identifier**: `lab-guestbook-db`. Đặt username, password
   — ghi lại để dùng làm biến môi trường ở bước 06 (Launch Template User Data).
8. Bấm Create database → chuyển ngay sang bước 04 (Target Group), không
   chờ RDS available.

## Schema khởi tạo (chạy sau khi RDS available, từ LOCAL qua tunnel)

Không SSM vào Bastion để gõ SQL tại chỗ — thay vào đó mở **SSM
port-forwarding tunnel** từ máy local, xuyên qua Bastion, tới thẳng
RDS (Bastion chỉ đóng vai trò trạm trung chuyển, không cần cài `mysql
client`). Cách này giữ Bastion tối giản và cho phép dùng GUI tool quen
thuộc (TablePlus, DBeaver, MySQL Workbench...) trên máy cá nhân thay vì
gõ SQL trong terminal SSM session.

1. **Yêu cầu trên local** (xem "Yêu cầu chuẩn bị trước buổi học"):
   AWS CLI v2 + Session Manager plugin đã cài, credentials có quyền
   `ssm:StartSession` trên Bastion.
2. **Mở tunnel** (1 terminal riêng, giữ chạy nền trong lúc thao tác).
   Lấy `<bastion-instance-id>` từ CloudFormation Output
   `BastionInstanceId` (bước 01) hoặc EC2 Console:
   ```bash
   ./scripts/db-tunnel.sh <bastion-instance-id> <rds-endpoint> 13306
   ```
3. **Kết nối** từ terminal khác (hoặc GUI tool như TablePlus/DBeaver/
   MySQL Workbench) trỏ vào `127.0.0.1:13306`:
   ```bash
   mysql -h 127.0.0.1 -P 13306 -u <username> -p
   ```
4. **Chạy schema:**
   ```sql
   CREATE DATABASE guestbook;
   USE guestbook;

   CREATE TABLE guestbook (
       id INT AUTO_INCREMENT PRIMARY KEY,
       name VARCHAR(100) NOT NULL,
       message VARCHAR(255),
       image_key VARCHAR(255),
       created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
   );
   ```
5. `Ctrl+C` ở terminal mở tunnel (bước 2) để đóng lại khi xong.

> Lưu ý Security Group: DB SG phải cho phép inbound 3306 từ **Bastion
> SG** (không chỉ App SG) — vì traffic TCP thật sự tới RDS xuất phát từ
> Bastion, SSM chỉ chuyển tiếp kênh local↔Bastion. Đã cấu hình sẵn ở
> bước 01 (CloudFormation).

### Lệnh cụ thể (copy-paste)

Lấy `<bastion-instance-id>` (không cố định — mỗi lần CloudFormation
deploy lại sẽ ra ID khác):

```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lab-guestbook-bastion" "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].InstanceId" --output text
```

Terminal 1 — mở tunnel, giữ chạy nền (thay `<bastion-instance-id>` bằng
kết quả lệnh trên; endpoint dưới đây lấy từ RDS Console sau khi instance
`available`):

```bash
./scripts/db-tunnel.sh <bastion-instance-id> \
  lab-guestbook-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com \
  13306
```

Terminal 2 — kết nối và chạy schema (thay `<username>` bằng master
username đã đặt lúc tạo RDS ở mục 7 phía trên — **phải khớp chính xác**
giá trị sẽ điền vào `DB_USER` ở User Data bước 06, không phải giá trị
mẫu ở local dev `.env.example`):

```bash
mysql -h 127.0.0.1 -P 13306 -u <username> -p
```

```sql
CREATE DATABASE guestbook;
USE guestbook;

CREATE TABLE guestbook (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    message VARCHAR(255),
    image_key VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

SHOW TABLES;   -- xác nhận thấy bảng "guestbook"
```

`Ctrl+C` ở Terminal 1 để đóng tunnel khi xong.

> Ghi chú: bước chạy schema này có thể thực hiện xen kẽ trong lúc chờ
> AMI/ALB/ASG ở các bước sau — miễn hoàn tất trước bước 07 (test end-to-end).

## Checklist hoàn thành bước này

- [ ] RDS instance đã bấm Create (không cần chờ available ngay)
- [ ] Đã ghi lại: DB endpoint, username, password, tên database
- [ ] Trước bước 07: RDS ở trạng thái `available` và đã chạy xong script tạo bảng `guestbook` (qua tunnel `scripts/db-tunnel.sh`)
- [ ] Xác nhận DB Security Group cho phép kết nối từ App Security Group **và** Bastion Security Group (không mở public)
