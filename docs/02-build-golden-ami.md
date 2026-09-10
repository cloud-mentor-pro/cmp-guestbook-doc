# Bước 02 — Build Golden AMI

**Thời lượng gợi ý:** ~10 phút thao tác + chạy nền song song với bước 03

## Mục tiêu

- Hiểu khái niệm "Golden AMI": AMI chứa sẵn OS + runtime (Node.js) +
  package cần thiết, **không chứa code ứng dụng**.
- Thực hành build AMI từ chính **Bastion** — Bastion là instance
  AMI-builder duy nhất trong lab (chỉ IAM Role của Bastion có quyền
  `ec2:CreateImage`), không dùng
  instance builder riêng.
- Đây là AMI dùng cho Launch Template ở bước 06, và cũng là AMI sẽ được
  build lại (v2) ở bước 10 khi demo "deploy đổi AMI".

## Vì sao build AMI cần làm SỚM trong buổi học

`ec2:CreateImage` mất khoảng 5-8 phút để AMI chuyển sang trạng thái
`available`. Nếu để học viên ngồi chờ, sẽ mất thời gian chết. Vì vậy:

1. Bấm nút build AMI **ngay khi vừa xong**, rồi chuyển sang bước 03 (tạo RDS)
   **mà không chờ AMI xong**.
2. Trong lúc AMI + RDS cùng chạy nền, tiếp tục bước 04-05 (Target Group, ALB)
   — các bước này không phụ thuộc AMI/RDS.
3. Chỉ cần kiểm tra AMI đã `available` trước khi làm bước 06 (Launch Template).

## Các bước thao tác (tóm tắt)

1. Kết nối vào **Bastion** qua **SSM Session Manager** (không SSH).
2. Cài đặt runtime:
   - Amazon Linux 2023: dùng `dnf`
   - (Ghi chú tương thích Amazon Linux 2 nếu có instance cũ hơn: dùng `yum`)
3. Cài Node.js (qua `dnf`/`yum`, hoặc NodeSource nếu cần version mới hơn
   repo mặc định).
4. Cài `git` — bắt buộc, vì User Data ở bước 06 dùng `git clone`/`git
   pull` để lấy code ứng dụng từ GitHub lúc instance khởi động.
5. **Không** copy code ứng dụng vào lúc này — AMI chỉ chứa runtime.
   Code sẽ được pull từ **GitHub repo** qua User Data lúc instance khởi
   động (bước 06).
6. Tạo sẵn **systemd unit** `guestbook.service` (chạy `node
   src/server.js`, lắng nghe thẳng port 80) — chưa cần code, chỉ cần
   file service đã có sẵn để User Data ở bước 06 gọi `systemctl restart
   guestbook.service` sau khi pull code.
7. **Dọn state SSM Agent trên Bastion — BẮT BUỘC, làm ngay trong session
   đang mở, trước khi thoát ra để Create Image (bước 8).** Bastion tự
   đăng ký SSM ngay từ lúc boot ở bước 01 (độc lập với việc bạn có SSM
   vào hay không) — nếu Create Image nguyên trạng, AMI sẽ chụp luôn
   "chứng minh thư" (registration key) của Bastion, khiến **mọi**
   instance App sau này do ASG launch ra dùng chung identity đó, không
   tự đăng ký SSM riêng được (lỗi `TargetNotConnected` khi `aws ssm
   start-session`). Lệnh nằm ngay trong khối copy-paste bước 2-6 bên
   dưới (không cần rời sang local) — chạy **xoá file trước, dừng agent
   sau**, để việc xoá chắc chắn hoàn tất trước khi có rủi ro session bị
   cắt lúc agent dừng.
8. Từ EC2 Console → chọn instance Bastion → **Actions → Image and
   templates → Create image**.
   - Đặt tên có version: `lab-guestbook-ami-v1`
   - Lưu ý: mặc định `Create Image` sẽ **reboot** Bastion (đảm bảo AMI
     nhất quán ở tầng filesystem) — nếu đang có SSM tunnel tới RDS mở
     song song (bước 03), tunnel sẽ bị rớt tạm thời, mở lại sau khi
     Bastion reboot xong.
9. Ghi lại AMI ID để dùng ở bước 06.

## Lệnh cụ thể (copy-paste bước 2-6, sau khi đã kết nối SSM ở bước 1)

```bash
sudo -i
```

```bash
dnf install -y nodejs git || yum install -y nodejs git   # AL2023 dùng dnf, fallback yum cho AL2
node -v && git --version
```

```bash
cat > /etc/systemd/system/guestbook.service <<'EOF'
[Unit]
Description=CMP Guestbook App
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/guestbook
EnvironmentFile=-/etc/guestbook.env
ExecStart=/usr/bin/node /opt/guestbook/src/server.js
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF
```

```bash
systemctl daemon-reload
systemctl enable guestbook.service
cat /etc/systemd/system/guestbook.service
```

```bash
# Bước 7 — dọn SSM Agent state TRƯỚC KHI Create Image (xem giải thích ở
# mục "Các bước thao tác" phía trên). Xoá file TRƯỚC, dừng agent SAU —
# nếu session bị cắt ngay khi dừng agent thì việc xoá đã xong rồi, không sao.
rm -rf /var/lib/amazon/ssm
systemctl stop amazon-ssm-agent
```

```bash
exit    # thoát sudo -i (bỏ qua nếu session đã tự rớt lúc dừng agent)
exit    # thoát SSM session, quay lại local (tương tự)
```

> Chưa `systemctl start` — chưa có code (`/opt/guestbook` sẽ do User Data
> `git clone` vào ở bước 06), start ở đây sẽ fail vì thiếu `src/server.js`.
> `EnvironmentFile=-/etc/guestbook.env` (dấu `-` = không lỗi nếu file
> chưa tồn tại) — file này cũng do User Data ở bước 06 ghi, chứa
> DB_HOST/DB_USER/DB_PASS/DB_NAME/S3_BUCKET/AWS_REGION.
> `After=network.target cloud-final.service` — **bắt buộc**, tránh race
> condition: vì unit này `enable`d (tự start lúc boot), nếu không chờ
> `cloud-final.service` (chính là service chạy User Data), systemd sẽ cố
> start service **song song** với lúc User Data đang `git clone`
> `/opt/guestbook` — instance mới launch từ ASG sẽ CHDIR fail (thư mục
> chưa tồn tại), dồn dập retry rồi bị systemd đánh dấu Failed, gây health
> check ALB fail giả (instance thường tự hồi lại vài giây sau nhờ User
> Data tự `systemctl restart` ở cuối, nhưng có thể bị ASG hiểu nhầm là
> unhealthy và terminate oan trong lúc đó).
> Nếu cần Node.js mới hơn bản `dnf` cài mặc định, dùng NodeSource trước
> dòng `dnf install`: `curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -`.
>
> Sau khi dừng agent, Bastion sẽ rớt khỏi `Online` trên SSM (bình
> thường, không phải lỗi) — cứ tiếp tục sang bước 8 (Create Image) dù
> session có bị cắt hay không. Sau khi Create Image xong, Bastion tự
> reboot theo cơ chế mặc định → agent tự khởi động lại, tự đăng ký sạch
> cho chính Bastion, không cần làm gì thêm. Việc SSM vào được **instance
> App** (do ASG launch từ AMI vừa tạo) sẽ được xác nhận thật ở bước 06/07.

## Checklist hoàn thành bước này

- [ ] Bastion đã cài đúng Node.js + `git`, có sẵn systemd unit
      `guestbook.service`
- [ ] Đã cài `git` (bắt buộc để User Data pull code từ GitHub ở bước 06)
- [ ] Đã chạy `rm -rf /var/lib/amazon/ssm` rồi `systemctl stop
      amazon-ssm-agent` (đúng thứ tự) ngay trong session, **trước khi**
      Create Image
- [ ] Đã bấm Create Image, đặt tên có version rõ ràng (`-v1`)
- [ ] Đã chuyển sang bước 03 ngay, **không ngồi chờ** AMI hoàn tất
- [ ] Trước khi vào bước 06: xác nhận AMI ở trạng thái `available`
- [ ] Ghi lại AMI ID vào note chung của lớp (để dùng cho Launch Template)
