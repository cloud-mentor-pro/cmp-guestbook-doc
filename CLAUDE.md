# CLAUDE.md

## Bối cảnh dự án

Đây là **bài lab thực hành** cho lớp AWS SAA, thiết kế như một bài
**capstone** tổng hợp các kiến thức học viên đã học trước đó: EC2, AMI,
VPC 3-tier, S3, RDS, Route 53, ALB, ASG — thành 1 kiến trúc production
hoàn chỉnh.

- **Tên bài học:** "Đưa ứng dụng lên Production: High Availability & Auto Scaling"
- **Phụ đề:** Bài capstone — tổng hợp EC2, AMI, VPC, S3, RDS, Route53,
  ALB, ASG đã học thành 1 kiến trúc production hoàn chỉnh, demo 2 chiến
  lược deploy (code-only vs rebuild AMI)
- **Thời lượng lớp học:** 120 phút
- **Đối tượng:** Học viên đã học qua EC2, AMI, VPC, S3, RDS, Route53,
  ALB, ASG — bài này KHÔNG dạy lại các service đó.
- **Trọng tâm thao tác trong lớp:** Target Group, ALB, ASG (thao tác thủ
  công) + 2 chiến lược deploy (đổi code vs đổi AMI) — phần hạ tầng còn
  lại (VPC, S3, IAM...) dựng sẵn qua CloudFormation.
- **AWS Region:** **`us-east-1`** — cố định cho toàn bộ lab (CloudFormation,
  RDS, ALB, AMI, Route 53 Alias Record...). Không tự ý đổi sang region
  khác khi viết code/script/tài liệu.
- **Mỗi học viên có 1 AWS account riêng** (không dùng chung 1 account cho
  cả lớp) — quyết định này ảnh hưởng trực tiếp tới cách đặt tên S3 Bucket
  (xem mục "Naming Convention").

## Yêu cầu chuẩn bị trước buổi học (Prerequisites)

Những thứ này KHÔNG được tạo trong lab (không có bước "tạo mới" trong
`docs/`) — học viên/Mentor phải chuẩn bị sẵn trước khi vào buổi học:

- **Route 53 Hosted Zone:** đã có sẵn domain + Hosted Zone riêng cho
  từng học viên trước buổi học. `docs/08-route53-custom-domain.md` chỉ
  hướng dẫn tạo **Alias Record** trỏ vào ALB, không hướng dẫn tạo Hosted
  Zone.
- **Tài khoản GitHub:** để **fork** repo public `cmp-guestbook-app` về tài
  khoản cá nhân trước buổi học.
- **AWS CLI v2 + Session Manager plugin trên máy local:** cần để mở SSM
  port-forwarding tunnel tới RDS

## Ứng dụng demo: Cloud Mentor Pro Guestbook

Một app "sổ lưu bút" đơn giản, đóng vai trò minh họa kiến trúc, không
phải trọng tâm nghiệp vụ:

- Form ghi lưu bút: `name`, `message` → lưu vào **RDS**
- Upload ảnh qua **S3 Presigned URL** — browser upload thẳng lên S3,
  KHÔNG đi qua EC2 (đúng chuẩn presigned URL đã học ở bài S3)
- Trang chủ hiển thị trạng thái kết nối trực quan: ✅/❌ Database
- Hiển thị Instance ID

### API endpoints

```
GET  /          → Trang chủ: status DB, danh sách guestbook entries (mới nhất trước)
GET  /presign    → Trả về presigned URL (PUT) để browser upload ảnh trực tiếp lên S3
POST /submit     → Nhận name, message, image_key → INSERT vào RDS
```

### Data model (RDS)

```sql
CREATE TABLE guestbook (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    message VARCHAR(255),
    image_key VARCHAR(255),      -- object key trong S3, KHÔNG lưu full URL
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Biến môi trường (đơn giản, KHÔNG dùng Parameter Store/Secrets Manager)

Quyết định rõ ràng: học viên đã học RDS nhưng bài lab này giữ đơn giản,
dùng biến môi trường thường (set trong User Data của Launch Template),
KHÔNG dùng SSM Parameter Store hay Secrets Manager (việc đó để dành cho
bài nâng cao sau này).

```
DB_HOST=<rds-endpoint>
DB_USER=<username>
DB_PASS=<password>
DB_NAME=guestbook
S3_BUCKET=<tên-bucket-từ-cloudformation-output>   # CHỈ dùng cho ảnh guestbook, KHÔNG chứa code app
APP_REPO_URL=<https://github.com/.../repo.git>    # Repo GitHub chứa code ứng dụng
APP_REF=<branch-hoặc-tag>                          # vd: main, v1, v2 — dùng để checkout đúng bản khi deploy
AWS_REGION=us-east-1                               # Cố định cho toàn bộ lab, xem mục "Bối cảnh dự án"
```

## Nguyên tắc kiến trúc cốt lõi: tách biệt AMI (runtime) và Code (GitHub)

Đây là quyết định thiết kế **quan trọng nhất** của cả bài lab, mọi code
viết ra phải tôn trọng nguyên tắc này:

- **Golden AMI** chỉ chứa: OS (Amazon Linux 2023) + runtime (Node.js) +
  package cần thiết (bao gồm cả `git`, dùng để pull code ở bước khởi
  động). **KHÔNG chứa code ứng dụng.**
- **Code ứng dụng** nằm trên **GitHub repo**, được `git clone`/`git pull`
  về lúc instance khởi động qua **User Data script** trong Launch Template.
- User Data script phải **nhỏ, cố định, không đổi** giữa các lần deploy
  code — nhiệm vụ duy nhất: clone/pull đúng `APP_REF` từ `APP_REPO_URL`
  → deploy → start service.
- Repo `cmp-guestbook-app` là **public** trên GitHub. Mỗi học viên **fork** repo
  này về tài khoản cá nhân, rồi điền URL fork của mình vào `APP_REPO_URL`
  (biến môi trường trong User Data). Vì repo public, `git clone` chỉ cần
  HTTPS, không cần credential — đúng nguyên tắc "không dùng Secrets
  Manager" của lab.
- **S3 trong lab này KHÔNG dùng để chứa code ứng dụng** — S3 chỉ phục vụ
  upload ảnh guestbook qua presigned URL (đúng vai trò đã học ở bài S3).

> `git clone`/`git pull` từ GitHub ngay lúc boot **không phải best
> practice cho production**, vì tạo phụ thuộc mạng ngoài (GitHub +
> NAT Gateway) đúng lúc ASG cần launch instance mới (scale-out) — nếu
> GitHub hoặc NAT Gateway (vốn đã là SPOF, xem mục NAT Gateway bên
> dưới) gặp sự cố, instance mới có thể không boot healthy được. Ngoài
> ra nếu `APP_REF` trỏ vào branch di động (vd `main`) thay vì
> commit/tag cố định, 2 instance launch lệch nhau vài phút có thể chạy
> 2 phiên bản code khác nhau. Production thật thường dùng CodeDeploy
> (kéo artifact đã build từ S3) hoặc bake code thẳng vào AMI. Lab này
> **cố tình chọn pattern đơn giản** để làm nổi bật rõ khái niệm tách
> AMI/Code trong 120 phút — KHÔNG sửa sang CodeDeploy/CodePipeline vì
> lệch trọng tâm bài học (ALB + ASG).

Nhờ tách biệt này, project cần hỗ trợ rõ **2 kịch bản deploy khác nhau**:

| | Deploy đổi Code | Deploy đổi AMI |
|---|---|---|
| Thay đổi ở đâu | Code trên GitHub repo (branch/tag mới) | Golden AMI (runtime/OS) |
| Launch Template | Không đổi | Tạo version mới, trỏ AMI mới |
| Cơ chế rollout | ASG Instance Refresh (instance mới `git pull` bản mới nhất) | ASG Instance Refresh (sau khi có LT version mới) |
| Dùng khi nào | Sửa UI, sửa logic ứng dụng | Nâng version runtime, patch OS, đổi package hệ thống |

## Hạ tầng: CloudFormation (Foundation) + thao tác thủ công (Core lab)

Quyết định rõ ràng về việc CÁI GÌ dựng bằng CloudFormation, CÁI GÌ để
học viên tự tay làm trong lớp (vì đó là trọng tâm bài học):

### Dựng bằng CloudFormation (`cloudformation/template.yaml`)

- **VPC 3-tier, 6 subnet, 2 AZ:**
  - 2 Public Subnet (tier ALB)
  - 2 Private App Subnet (tier ứng dụng)
  - 2 Private DB Subnet (tier database)
- Internet Gateway, **1 NAT Gateway** (đặt ở Public Subnet AZ-1, chấp
  nhận đây là điểm chưa "highly available"
- Route Table cho từng tier + associations
- **DB Subnet Group** (dùng cho RDS)
- **Security Groups:**
  - Bastion SG: không mở inbound (truy cập qua SSM)
  - ALB SG: inbound 80/443 từ `0.0.0.0/0`
  - App SG: inbound 80 chỉ từ ALB SG
  - DB SG: inbound 3306 từ App SG **và** từ Bastion SG (Bastion cần
    reach RDS để phục vụ SSM port-forwarding tunnel — xem mục "Nguyên
    tắc truy cập: SSM Session Manager ONLY")
- **IAM Role/Instance Profile cho App instances:**
  - Managed policy `AmazonSSMManagedInstanceCore`
  - Inline policy: `s3:GetObject`, `s3:PutObject` trên bucket của lab (chỉ
    dùng để sinh presigned URL cho ảnh guestbook — **không** liên quan
    code app, vì code app pull từ GitHub qua `git clone`/`git pull`)
- **IAM Role/Instance Profile cho Bastion:**
  - Managed policy `AmazonSSMManagedInstanceCore`
  - Inline policy: quyền tạo AMI (`ec2:CreateImage`, `ec2:DescribeImages`, v.v.) — Bastion đóng vai trò AMI-builder
- **S3 Bucket:**
  - Chỉ dùng để lưu **ảnh guestbook** (upload qua presigned URL) — không
    dùng để chứa code ứng dụng
  - **CORS configuration** — 3 origin cụ thể, vì học viên test app qua
    **3 giai đoạn khác nhau** trong buổi học (ALB DNS thô ở bước 07,
    trước khi có domain riêng ở bước 08):
    ```yaml
    CorsConfiguration:
      CorsRules:
        - AllowedOrigins:
            - http://localhost:3000                              # local dev (xem README cmp-guestbook-app)
            - !Sub 'http://*.${AWS::Region}.elb.amazonaws.com'    # ALB DNS thô, dùng ở bước 07 (trước khi gắn domain)
            - !Sub 'http://${AppDomainName}'                      # domain riêng học viên, gắn ở bước 08
          AllowedMethods: [GET, PUT]
          AllowedHeaders: ['*']
          ExposeHeaders: [ETag]
          MaxAgeSeconds: 3000
    ```
    Cần thêm tham số **`AppDomainName`** (vd `asg-lab.cloudmentor.pro`) —
    học viên điền domain riêng đã có sẵn Hosted Zone (xem "Yêu cầu chuẩn
    bị trước buổi học") **ngay từ bước 01**, dù Alias Record thật sự chỉ
    được tạo ở bước 08 — vì CORS phải cấu hình sẵn từ lúc dựng bucket.
  - Versioning bật sẵn
- **Bastion Host** (EC2 nhỏ, Public Subnet AZ-1, dùng làm AMI-builder)
- **Tham số CloudFormation nằm trong file JSON riêng** (`cloudformation/parameters.json`), KHÔNG hard-code trong template — để dễ tái sử dụng cho nhiều lớp học khác nhau

### Tạo thủ công trong lớp (trọng tâm bài học — không đưa vào CloudFormation)

- Build Golden AMI (qua Bastion/SSM)
- Tạo RDS instance (engine: **MySQL**)
- Target Group
- Application Load Balancer
- Launch Template + Auto Scaling Group
- Route 53 Alias Record (trỏ vào Hosted Zone đã có sẵn — xem mục
  "Yêu cầu chuẩn bị trước buổi học"; đặt **trước** 2 demo deploy trong
  timeline — xem mục Timeline bên dưới)

## Naming Convention (áp dụng cho mọi resource, kể cả tạo thủ công)

- **Format:** `{Environment}-guestbook-{resource-abbrev}[-{qualifier}]`
  — toàn bộ chữ thường, gạch ngang.
- **`{Environment}`**: tham số CloudFormation, giá trị mặc định `lab`.
  Nếu nhiều học viên dùng chung 1 AWS account, mỗi học viên đổi thành
  `lab-<alias-ngắn>` (vd `lab-phong`) để tránh trùng tên và dễ nhận diện
  resource của ai trên Console dùng chung.
- **`guestbook`**: project code cố định, luôn xuất hiện trong mọi tên
  (không phải tham số).
- **Resource-abbrev**: viết tắt ngắn, không spell-out — xem bảng dưới.

### Bảng tên resource

| Resource | Tên |
|---|---|
| VPC | `{env}-guestbook-vpc` |
| Internet Gateway | `{env}-guestbook-igw` |
| NAT Gateway | `{env}-guestbook-nat` |
| Subnet | `{env}-guestbook-subnet-public-1/2`, `-app-1/2`, `-db-1/2` |
| Route Table | `{env}-guestbook-rtb-public`, `-app`, `-db` |
| DB Subnet Group | `{env}-guestbook-dbsubnetgroup` |
| Security Group | `{env}-guestbook-sg-bastion`, `-alb`, `-app`, `-db` |
| IAM Role / Instance Profile | `{env}-guestbook-role-app`/`-bastion`, `-profile-app`/`-bastion` |
| S3 Bucket | `{env}-guestbook-s3-{account-id}` — xem lý do dùng AccountId bên dưới |
| Bastion EC2 | `{env}-guestbook-bastion` |
| Golden AMI | `{env}-guestbook-ami-v1`, `-v2` |
| RDS instance | `{env}-guestbook-db` |
| Target Group | `{env}-guestbook-tg` |
| Application Load Balancer | `{env}-guestbook-alb` |
| Launch Template | `{env}-guestbook-lt` |
| Auto Scaling Group | `{env}-guestbook-asg` |

### S3 Bucket: hậu tố AccountId để tránh trùng tên giữa nhiều học viên

S3 bucket name phải **globally unique** trên toàn AWS. Vì **mỗi học
viên có 1 AWS account riêng** (xem "Bối cảnh dự án"), dùng `AWS::AccountId`
làm hậu tố là đủ để đảm bảo không trùng — đơn giản, dễ giải thích cho
học viên (pseudo-parameter cơ bản), và tên ổn định qua các lần deploy
lại (không như hậu tố random):

```yaml
GuestbookBucket:
  Type: AWS::S3::Bucket
  Properties:
    BucketName: !Sub '${Environment}-guestbook-s3-${AWS::AccountId}'
    VersioningConfiguration:
      Status: Enabled
```

### Tags chuẩn (áp dụng cho mọi resource CloudFormation tạo ra)

```yaml
Tags:
  - { Key: Name,        Value: !Sub '${Environment}-guestbook-<resource>' }
  - { Key: Environment, Value: !Ref Environment }
  - { Key: Project,     Value: guestbook }
```

### Quy ước khác

- **`GroupName`/`RoleName`/`InstanceProfileName` set tường minh**, trùng
  với Name tag — không để CloudFormation tự sinh tên ngẫu nhiên khó
  nhận diện (ngoại lệ: S3 Bucket, xem lý do ở bảng trên).
- **Logical Resource ID trong `template.yaml`**: PascalCase, resource-type
  đứng trước (vd `SecurityGroupApp`, `IamRoleBastion`, `RouteTablePublic`)
  — dễ tìm/sort trong template và Console.
- **Output/Export**: `!Sub '${AWS::StackName}-<Mô-tả><Id|Name|Arn|DnsName>'`
  — hậu tố nói rõ kiểu giá trị trả về.

## Nguyên tắc truy cập: SSM Session Manager ONLY

Quyết định rõ ràng, áp dụng cho **toàn bộ EC2 trong project** (Bastion
và App instances):

- **KHÔNG dùng SSH key pair** ở bất kỳ đâu trong lab này.
- Toàn bộ truy cập instance (debug, build AMI...) đều qua **AWS Systems
  Manager Session Manager**.
- Mọi IAM Role cho EC2 phải gắn managed policy `AmazonSSMManagedInstanceCore`.
- Metadata retrieval trong code/script phải dùng **IMDSv2** (token-based),
  không dùng IMDSv1.

### Chạy SQL trên RDS: tunnel từ LOCAL qua Bastion (không SSH, không cài mysql client trên Bastion)

Quyết định đã chốt: **không** SSM vào Bastion rồi gõ SQL tại chỗ. Thay
vào đó dùng SSM Session Manager **port forwarding tới remote host**
(`AWS-StartPortForwardingSessionToRemoteHost`) để mở tunnel từ máy local
→ Bastion → RDS, rồi chạy SQL/dùng GUI tool (mysql client, TablePlus,
DBeaver, MySQL Workbench...) ngay trên local:

```bash
aws ssm start-session \
  --target <bastion-instance-id> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<rds-endpoint>"],"portNumber":["3306"],"localPortNumber":["13306"]}'
```

Sau đó connect `mysql -h 127.0.0.1 -P 13306 -u <user> -p` (hoặc GUI
tool) từ 1 terminal/app khác. Xem script tiện ích `scripts/db-tunnel.sh`
và các bước cụ thể ở `docs/03-tao-rds.md`.

- **Lý do chọn cách này thay vì cài `mysql client` trên Bastion:**
  Bastion giữ tối giản (chỉ cần đúng vai trò AMI-builder + SSM Agent,
  không cài thêm phần mềm không liên quan), và học viên dùng được GUI
  tool quen thuộc trên máy cá nhân thay vì gõ SQL trong terminal SSM
  session — trải nghiệm tốt hơn cho mục đích demo/dạy học.
- **Vẫn đúng nguyên tắc SSM ONLY:** không SSH, không cần Bastion có
  public IP mở port, không cần mở Security Group cho IP của học viên —
  toàn bộ traffic đi qua kênh SSM đã mã hoá.
- **Về mặt network:** Bastion là bên thực sự mở kết nối TCP 3306 tới
  RDS (SSM chỉ là kênh chuyển tiếp local↔Bastion), nên **DB SG phải mở
  3306 cho Bastion SG**, không chỉ App SG (xem mục Security Groups).
- **Yêu cầu trên máy local của học viên** (bổ sung vào "Yêu cầu chuẩn
  bị trước buổi học"): AWS CLI v2 đã cấu hình credentials, cài **Session
  Manager plugin** cho AWS CLI (bắt buộc riêng cho port forwarding,
  khác với việc chỉ mở session tương tác), và credentials có quyền
  `ssm:StartSession` nhắm tới Bastion instance.

## Compatibility yêu cầu cho script (User Data / AMI build)

- Script cài đặt phải hỗ trợ cả `dnf` (Amazon Linux 2023 — mặc định
  dùng cho lab) và `yum` (Amazon Linux 2 — fallback tương thích).
- AMI chính thức dùng cho lab: **Amazon Linux 2023**.
- Golden AMI **phải cài sẵn `git`** — User Data dùng `git clone`/`git
  pull` để lấy code ứng dụng từ GitHub lúc instance khởi động.

## Runtime ứng dụng: Node.js + Express

Quyết định đã chốt với Mentor:

- Ứng dụng Guestbook viết bằng **Node.js + Express** (repo `cmp-guestbook-app`,
  thư mục `src/`).
- Golden AMI cài Node.js (qua `dnf`/`yum`, có fallback NodeSource nếu
  cần version mới hơn repo mặc định của Amazon Linux 2023) + `git`.
  **KHÔNG** cài Nginx hay Apache — không dùng reverse proxy.
- **Express lắng nghe thẳng port 80** — đúng với App SG hiện có
  (`inbound 80 chỉ từ ALB SG`), không cần đổi port Target Group hay sửa
  Security Group.
- Process chạy dưới dạng **systemd service** (ví dụ `guestbook.service`),
  chạy bằng user `root` (hoặc dùng `setcap cap_net_bind_service` cho
  binary `node` nếu muốn tránh chạy bằng root) để có quyền bind port 80.
  systemd đảm nhiệm restart tự động khi crash và start lúc boot.
- **Thư mục code trên instance:** `/opt/guestbook` (`WorkingDirectory`
  của systemd unit, đích `git clone`/`git pull` của User Data). Đặt sẵn
  trong Golden AMI qua unit file `guestbook.service` (chưa có code, xem
  `docs/02-build-golden-ami.md`).
- **Biến môi trường nạp qua file, không qua `Environment=` từng dòng:**
  systemd unit khai báo `EnvironmentFile=-/etc/guestbook.env` (dấu `-`
  đầu = không lỗi nếu file chưa tồn tại lúc build AMI). User Data ở bước
  06 chỉ cần ghi `/etc/guestbook.env` (`KEY=VALUE` mỗi dòng: DB_HOST,
  DB_USER, DB_PASS, DB_NAME, S3_BUCKET, AWS_REGION) rồi `systemctl
  restart guestbook.service` — không cần sửa lại unit file mỗi lần deploy.
- User Data script (nhỏ, cố định) chỉ làm: `git clone`/`git pull` đúng
  `APP_REF` từ `APP_REPO_URL` vào `/opt/guestbook` → `npm install
  --production` → ghi `/etc/guestbook.env` → `systemctl restart
  guestbook.service`.

## Cấu trúc thư mục dự án (đã thống nhất, không tự ý đổi)

```
cmp-guestbook-doc/                       # Repo lab (repo này)
├── README.md                          # Tổng quan project
├── docs/                              # Các bước thực hành, mỗi bước 1 file .md
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
├── cloudformation/
│   ├── template.yaml                  # Đã viết, đã pass cfn-lint — đúng phạm vi ở mục "Dựng bằng CloudFormation"
│   └── parameters.json                # Tham số tách riêng khỏi template
└── scripts/                           # Script hỗ trợ deploy (build AMI, trigger Instance Refresh...)

cmp-guestbook-app/                           # Repo GitHub RIÊNG (sibling khi dev local), KHÔNG nằm trong repo lab
├── README.md                          # Gồm cả hướng dẫn chạy local (xem mục "Local development")
├── docker-compose.yml                 # Chỉ chạy MySQL cho local dev — KHÔNG dùng khi deploy lên EC2
├── .env.example                       # Mẫu biến môi trường cho local (copy thành .env, KHÔNG commit .env)
└── src/                               # Source code Guestbook app — pull vào App instance qua git clone/git pull
```

Khi viết code mới, đặt đúng vào thư mục tương ứng ở trên — không tạo
cấu trúc thư mục khác. Lưu ý: `cmp-guestbook-app` là **repo GitHub độc lập**,
không phải thư mục con của `cmp-guestbook-doc` — tách riêng đúng nguyên
tắc AMI (runtime, trong repo lab/CloudFormation) vs Code (app, trong
repo `cmp-guestbook-app`).

## Local development (repo `cmp-guestbook-app`)

Quyết định đã chốt với Mentor — chỉ áp dụng khi học viên/dev chạy app
trên máy cá nhân để code, KHÔNG liên quan tới hạ tầng AWS của lab:

- **MySQL:** chạy qua `docker-compose.yml` (service `mysql:8.0`, khớp
  RDS engine đã chốt), có script/seed tạo sẵn bảng `guestbook` đúng
  schema trong CLAUDE.md. Chỉ dùng cho local — trên AWS vẫn là RDS thật,
  KHÔNG dùng docker-compose.
- **S3:** dùng **bucket S3 thật trên AWS** (không dùng MinIO/LocalStack)
  — tạo thủ công 1 bucket dev riêng (không phải bucket do CloudFormation
  của lab quản lý), bật CORS cho phép origin `localhost`. App local xác
  thực bằng **AWS credentials cá nhân** (`~/.aws/credentials` hoặc biến
  môi trường `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`) — vì máy local
  không có EC2 Instance Profile như trên AWS. Đây là khác biệt duy nhất
  so với môi trường lab thật.
- **Hướng dẫn chạy local:** viết trong `README.md` của `cmp-guestbook-app`
  (không tách file riêng) — gồm: cài Node.js, `docker-compose up -d`
  cho MySQL, tạo bucket S3 dev + CORS thủ công, copy `.env.example` →
  `.env`, `npm install`, `npm run dev`.

## Timeline buổi học (120 phút) — script/tooling nên hỗ trợ đúng nhịp độ này

| Bước | Nội dung | Thời gian |
|---|---|---|
| 01 | CloudFormation: VPC, SG, NAT, Bastion, IAM Role, S3 | 15' |
| 02 | Build Golden AMI (qua Bastion/SSM) | ~10' (chạy nền) |
| 03 | Tạo RDS (chạy **song song** bước 02) | ~10' (chạy nền) |
| 04 | Tạo Target Group | 5' |
| 05 | Tạo Application Load Balancer | 12' |
| 06 | Tạo Launch Template + Auto Scaling Group | 15' |
| 07 | Test end-to-end qua ALB DNS | 8' |
| 08 | Route 53 — gắn custom domain (Alias Record) | 10' |
| 09 | Demo deploy: thay đổi code (GitHub + Instance Refresh), quan sát qua domain | 15' |
| 10 | Demo deploy: thay đổi AMI (rebuild + LT version mới + Instance Refresh) | 15' |
| 11 | Cleanup / Teardown | 5' |
| — | Buffer / Q&A | 10' |

Lưu ý quan trọng: bước 02 (build AMI) và 03 (tạo RDS) chạy **song song**,
không tuần tự — mọi hướng dẫn/script không được giả định RDS đã sẵn sàng
trước khi AMI xong hoặc ngược lại. Tổng thời lượng elapsed (tính bước
02/03 chạy song song, không cộng dồn) là ~120 phút.

Lưu ý thứ tự: Route 53 (bước 08) đặt **trước** 2 demo deploy (bước
09-10), không đặt cuối buổi như thường thấy — quyết định có chủ đích để
từ bước 09 trở đi, học viên quan sát demo deploy qua **domain riêng**
thay vì ALB DNS name thô, chứng minh trực quan domain (entry point)
đứng yên trong khi backend (ASG instances) xoay vòng phía sau. Không có
ràng buộc kỹ thuật nào chặn việc này — Alias Record chỉ cần ALB tồn tại
(xong ở bước 05).

## Việc dọn dẹp (Cleanup) — thứ tự bắt buộc

Vì đây là lab public trên GitHub, mọi script cleanup phải theo đúng thứ
tự phụ thuộc sau (tài nguyên tốn phí cao — NAT Gateway, RDS — nên được
nhắc xóa sớm):

1. Route 53 Record
2. Auto Scaling Group (set Desired = 0 hoặc xóa thẳng)
3. Application Load Balancer
4. Target Group
5. Launch Template (tất cả version)
6. RDS instance
7. AMI (cả v1, v2) + snapshot liên quan
8. Object trong S3 Bucket (kể cả version cũ, vì bucket bật versioning)
9. CloudFormation stack (xóa cuối cùng — sẽ dọn VPC, subnet, SG, IAM Role, Bastion)

## Phong cách làm việc mong muốn

- Tài liệu (`docs/*.md`) viết bằng **tiếng Việt**, giữ văn phong ngắn
  gọn, có checklist rõ ràng ở cuối mỗi bước — giữ nguyên format đã có,
  không tự ý đổi cấu trúc khi chỉnh sửa.
- Code (CloudFormation, app source, scripts) và comment trong code có
  thể dùng tiếng Anh theo chuẩn ngành, nhưng docstring/README hướng dẫn
  sử dụng nên bằng tiếng Việt để phù hợp học viên.
- Khi sửa nội dung đã có, giữ nguyên cấu trúc gốc, không thêm bớt phần
  không được yêu cầu (nguyên tắc "giữ nguyên bản gốc").