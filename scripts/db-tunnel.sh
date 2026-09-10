#!/usr/bin/env bash
#
# db-tunnel.sh — Mở SSM port-forwarding tunnel từ máy local tới RDS,
# xuyên qua Bastion (Bastion chỉ đóng vai trò trạm trung chuyển của
# SSM Session Manager — không cần cài mysql client trên Bastion,
# không dùng SSH).
#
# Sau khi tunnel mở, kết nối từ 1 terminal/GUI tool khác vào
# 127.0.0.1:<local-port> (mysql client, TablePlus, DBeaver, MySQL
# Workbench...). Giữ terminal chạy script này mở trong lúc thao tác;
# Ctrl+C để đóng tunnel.
#
# Yêu cầu trên máy local:
#   - AWS CLI v2 đã cấu hình credentials
#   - Session Manager plugin đã cài (bắt buộc riêng cho port forwarding):
#     https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html
#   - Credentials có quyền ssm:StartSession trên Bastion instance
#
# Cách dùng:
#   ./scripts/db-tunnel.sh <bastion-instance-id> <rds-endpoint> [local-port]
#
# Ví dụ (region của lab: us-east-1):
#   ./scripts/db-tunnel.sh i-0123456789abcdef0 \
#     cloudmentor-lab-db.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com \
#     13306
#
#   # Terminal khác, sau khi tunnel đã mở:
#   mysql -h 127.0.0.1 -P 13306 -u <username> -p

set -euo pipefail

usage() {
  echo "Cách dùng: $0 <bastion-instance-id> <rds-endpoint> [local-port]" >&2
  echo "Ví dụ:     $0 i-0123456789abcdef0 my-db.xxxx.rds.amazonaws.com 13306" >&2
}

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

BASTION_ID="$1"
RDS_ENDPOINT="$2"
LOCAL_PORT="${3:-13306}"
REMOTE_PORT="3306"

echo "Mở tunnel: 127.0.0.1:${LOCAL_PORT} → (qua Bastion ${BASTION_ID}) → ${RDS_ENDPOINT}:${REMOTE_PORT}"
echo "Giữ terminal này mở trong lúc dùng mysql client/GUI tool ở terminal/app khác."
echo "Ctrl+C để đóng tunnel khi xong."
echo

aws ssm start-session \
  --target "${BASTION_ID}" \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters "{\"host\":[\"${RDS_ENDPOINT}\"],\"portNumber\":[\"${REMOTE_PORT}\"],\"localPortNumber\":[\"${LOCAL_PORT}\"]}"
