# Bước 08 — Route 53: Gắn Custom Domain

**Thời lượng gợi ý:** 10 phút

## Mục tiêu

Học viên đã học Route 53 ở bài trước — bước này chỉ thao tác nhanh:
tạo **Alias Record** trỏ domain/subdomain vào ALB, không giảng lại lý
thuyết Route 53.

Bước này cố ý đặt **trước** 2 demo deploy (bước 09-10), không đặt cuối
buổi: từ đây trở đi, học viên dùng **domain riêng** thay vì ALB DNS name
để quan sát 2 demo deploy tiếp theo — chứng minh trực quan rằng domain
(entry point) đứng yên trong khi backend (ASG instances) xoay vòng phía
sau, đúng bản chất của kiến trúc ALB + ASG.

## Điều kiện tiên quyết

- Đã có sẵn 1 Hosted Zone (public hoặc dùng domain phụ của Cloud Mentor
  Pro dành riêng cho lab, ví dụ `lab.cloudmentor.pro`) — nên **tạo sẵn
  Hosted Zone trước giờ học** để không tốn thời gian chờ propagate NS
  record trong lớp.
- ALB đã `Active` (bước 05).

> ⚠️ **Domain ở bước này phải khớp CHÍNH XÁC** với giá trị tham số
> `AppDomainName` đã điền trong `cloudformation/parameters.json` ở bước
> 01 (dùng để cấu hình CORS cho S3 Bucket). Nếu gõ domain khác (kể cả
> sai 1 ký tự, thiếu/thừa `www.`...), upload/xem ảnh guestbook qua domain
> này sẽ bị **lỗi CORS** — giống hệt lỗi `blocked by CORS policy` đã gặp
> lúc debug local với `localhost:3000`. Muốn đổi domain lúc này thì phải
> `aws cloudformation deploy` lại stack với `AppDomainName` mới trước.

## Các bước thao tác (tóm tắt)

1. Route 53 Console → Hosted zones → chọn zone đã có sẵn.
2. Create record:
   - Record name: ví dụ `asg-lab.cloudmentor.pro` (mỗi học viên/nhóm
     có thể dùng subdomain riêng nếu thực hành độc lập, tránh trùng)
   - Record type: **A**
   - Toggle **Alias**: bật
   - Route traffic to: **Alias to Application Load Balancer** → chọn
     đúng region → chọn ALB đã tạo ở bước 05
3. Create record → chờ vài chục giây để propagate (thường nhanh vì
   dùng Alias tới AWS resource).
4. Test truy cập ứng dụng qua domain mới thay vì ALB DNS name thô — từ
   giờ dùng domain này cho 2 demo deploy ở bước 09-10.

## Điểm nhấn giảng dạy

- Nhấn mạnh lợi ích của **Alias record** so với CNAME thông thường:
  không tính phí truy vấn, tự động cập nhật nếu ALB đổi IP, hỗ trợ apex
  domain (root domain) mà CNAME không làm được.
- Liên hệ: đây là bước cuối cùng hoàn thiện trải nghiệm người dùng —
  từ giờ học viên có thể chia sẻ 1 domain dễ nhớ thay vì ALB DNS dài.

## Checklist hoàn thành bước này

- [ ] Alias Record (type A) trỏ đúng vào ALB
- [ ] Domain vừa tạo khớp chính xác với `AppDomainName` trong `parameters.json` (bước 01)
- [ ] Truy cập được ứng dụng qua domain mới, hiển thị đúng nội dung
- [ ] Thử upload ảnh qua domain mới — không bị lỗi CORS
- [ ] Học viên hiểu sự khác biệt giữa Alias record và CNAME record
