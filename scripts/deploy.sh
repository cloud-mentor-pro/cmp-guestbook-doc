#!/usr/bin/env bash
#
# deploy.sh — Deploy stack CloudFormation nền tảng (VPC 3-tier, SG, IAM
# Role/Instance Profile, S3 Bucket, Bastion Host) cho lab cmp-guestbook.
# Xem chi tiết phạm vi tài nguyên ở docs/01-cloudformation-foundation.md.
#
# Trước khi chạy: điền AppDomainName (và các tham số khác nếu cần) trong
# cloudformation/parameters.json — xem CLAUDE.md, mục "Naming Convention".
#
# Yêu cầu trên máy local: AWS CLI v2 đã cấu hình credentials.
#
# Cách dùng:
#   ./scripts/deploy.sh [stack-name] [aws-profile]
#
# Ví dụ:
#   ./scripts/deploy.sh                        # stack "lab-guestbook", profile "default"
#   ./scripts/deploy.sh lab-phong-guestbook     # đổi tên stack (vd nhiều học viên chung account)
#   ./scripts/deploy.sh lab-guestbook my-profile

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMPLATE_FILE="${REPO_ROOT}/cloudformation/template.yaml"
PARAMETERS_FILE="${REPO_ROOT}/cloudformation/parameters.json"

STACK_NAME="${1:-lab-guestbook}"
AWS_PROFILE="${2:-default}"
AWS_REGION="us-east-1" # Cố định cho toàn bộ lab — xem CLAUDE.md, mục "Bối cảnh dự án"

echo "Stack:    ${STACK_NAME}"
echo "Profile:  ${AWS_PROFILE}"
echo "Region:   ${AWS_REGION}"
echo "Template: ${TEMPLATE_FILE}"
echo

if command -v cfn-lint &>/dev/null; then
  echo "==> cfn-lint ${TEMPLATE_FILE}"
  cfn-lint "${TEMPLATE_FILE}"
else
  echo "==> cfn-lint không cài trên máy này, bỏ qua bước lint (không bắt buộc)"
fi

echo "==> aws cloudformation deploy"
aws cloudformation deploy \
  --template-file "${TEMPLATE_FILE}" \
  --stack-name "${STACK_NAME}" \
  --parameter-overrides "file://${PARAMETERS_FILE}" \
  --capabilities CAPABILITY_NAMED_IAM \
  --profile "${AWS_PROFILE}" \
  --region "${AWS_REGION}"

echo
echo "==> Outputs (ghi lại để dùng cho các bước thủ công 04-06):"
aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" \
  --profile "${AWS_PROFILE}" \
  --region "${AWS_REGION}" \
  --query 'Stacks[0].Outputs' \
  --output table
