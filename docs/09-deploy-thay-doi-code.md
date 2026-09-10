# Bước 09 — Demo Deploy: Thay đổi Code (không build lại AMI)

**Thời lượng gợi ý:** 15 phút

## Mục tiêu

Chứng minh: khi chỉ thay đổi **code ứng dụng** (không đổi runtime/OS),
**không cần build lại AMI** — chỉ cần đưa code mới lên **GitHub repo**
và yêu cầu ASG thay thế instance (Instance Refresh); instance mới sẽ tự
`git pull` bản mới nhất lúc khởi động.

## Chuẩn bị trước giờ học

- Đã có sẵn 2 phiên bản code trên GitHub repo của lab: bản đang chạy
  (ví dụ branch/tag `v1`, hoặc commit hiện tại của `main`) và bản mới
  (`v2`, hoặc 1 commit/tag tiếp theo) — có thay đổi nhỏ, dễ nhận biết
  bằng mắt (ví dụ đổi màu banner, đổi câu chào trên trang chủ) để demo
  nhanh, thấy rõ khác biệt.
- Xác nhận trước: repo public (khuyến nghị cho lab, để User Data
  `git clone`/`git pull` không cần credential) hoặc đã chuẩn bị sẵn cơ
  chế xác thực nếu repo private.

## Các bước thao tác (tóm tắt)

1. Merge/push code v2 lên GitHub — `APP_REF` trong User Data của Launch
   Template **luôn giữ nguyên `main`** (KHÔNG đổi sang tag riêng cho mỗi
   version). Chỉ cần push code mới lên `main`, instance mới sẽ tự
   `git pull` bản mới nhất khi khởi động.
   > Vì sao bắt buộc dùng branch `main` cố định (không phải tag) cho demo
   > này: nếu đổi `APP_REF` sang tag mới, giá trị đó nằm trong User Data
   > → phải tạo **Launch Template version mới** → phá vỡ chính điểm dạy
   > cốt lõi của bước này ("Launch Template không đổi", xem "Điểm nhấn
   > giảng dạy" bên dưới). Đây cũng chính là mặt trái của trade-off đã
   > nêu — branch di động giúp demo này gọn, nhưng kém an toàn hơn tag/commit
   > cố định trong production thật.
2. Vào ASG Console → Instance refresh → Start instance refresh.
   - Min healthy percentage: ví dụ 90% — đảm bảo không rớt toàn bộ traffic.
3. Quan sát trực tiếp trên Console: instance cũ lần lượt bị thay bằng
   instance mới (rolling replace). Instance mới khởi động → User Data
   chạy `git clone`/`git pull` lấy code v2 → Target Group chuyển trạng
   thái `draining` (instance cũ) → `healthy` (instance mới).
4. Trong lúc chờ, liên tục refresh **domain đã gắn ở bước 08** (thay vì
   ALB DNS thô) trên trình duyệt để học viên thấy: **traffic không bị
   gián đoạn hoàn toàn**, một số request vẫn được phục vụ bởi instance
   cũ cho tới khi nó bị drain xong — đồng thời củng cố: domain không đổi
   dù backend đang thay instance.
5. Sau khi Instance Refresh hoàn tất → xác nhận toàn bộ trang web hiển
   thị phiên bản v2.

## Điểm nhấn giảng dạy

- Nhấn mạnh: **Launch Template không đổi** — vẫn dùng AMI v1. Chỉ có
  code trên GitHub thay đổi. Đây chính là điểm khác biệt cốt lõi so
  với bước 10.
- Liên hệ thực tế: đây là mô hình đơn giản hóa của một pipeline CI/CD
  (ví dụ GitHub Actions + CodeDeploy/CodePipeline sẽ tự động hóa đúng
  các bước thủ công này — trigger tự động ngay khi có commit/tag mới,
  thay vì bấm Instance Refresh thủ công).
- Nhấn mạnh vai trò `MinHealthySize`/`Min healthy percentage` trong việc
  đảm bảo zero/giảm thiểu downtime khi rolling deploy.
- **Câu hỏi thảo luận (trade-off của pattern `git pull` lúc boot):**
  đây KHÔNG phải best practice cho production. Instance mới lúc
  scale-out phụ thuộc GitHub + NAT Gateway phải sống thì mới boot
  healthy được — nếu GitHub down hoặc NAT Gateway (đã là SPOF trong lab
  này, xem bước 01) gặp sự cố đúng lúc traffic tăng đột biến, ASG có
  thể không launch được instance mới nào cả. Ngoài ra nếu `APP_REF`
  trỏ vào branch di động thay vì commit/tag cố định, các instance
  launch lệch nhau vài phút có thể chạy khác phiên bản code. Hỏi học
  viên: production thật nên cải tiến theo hướng nào? (gợi ý: CodeDeploy
  kéo artifact đã build từ S3, hoặc bake code thẳng vào AMI — đánh đổi
  là mất đi việc "chỉ cần push code, không cần build lại AMI" như demo
  này).

## Checklist hoàn thành bước này

- [ ] Code v2 đã push/merge lên branch `main` (đúng `APP_REF` User Data đang dùng, không đổi sang tag)
- [ ] Instance Refresh chạy thành công, không có instance nào bị stuck
- [ ] Toàn bộ instance sau refresh chạy đúng code v2 (xác nhận qua UI)
- [ ] Học viên hiểu rõ: Launch Template/AMI không thay đổi trong demo này
