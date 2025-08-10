#!/bin/bash

# =============================================================================
# 테라폼 리소스 삭제 스크립트 (Terraform Destroy Script)
# =============================================================================
# 이 스크립트는 CloudFront + Lambda@Edge + S3 리소스를 모두 삭제합니다
# 
# 사용법: ./scripts/destroy.sh <ACCOUNT_ID> <AWS_PROFILE>
# 예시: ./scripts/destroy.sh 123456789012 my-aws-profile
# 
# ⚠️  주의: 이 스크립트는 모든 리소스를 영구적으로 삭제합니다!

# 스크립트 실행 시 전달받은 인자들을 변수에 저장
ACCOUNT_ID=$1        # 첫 번째 인자: AWS 계정 ID (예: 123456789012)
export AWS_PROFILE=$2 # 두 번째 인자: AWS 프로파일명 (예: default, my-profile)

echo "⚠️  경고: 모든 리소스가 삭제됩니다!"
echo "삭제될 리소스:"
echo "- S3 버킷 (cf-test-site)"
echo "- CloudFront 배포"
echo "- Lambda@Edge 함수"
echo "- S3 버킷 정책"
echo "- Origin Access Control"
echo ""

# 사용자 확인
read -p "정말로 삭제하시겠습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "삭제가 취소되었습니다."
    exit 1
fi

# =============================================================================
# 테라폼 디렉토리로 이동
# =============================================================================
echo "📁 tf 디렉토리로 이동..."
cd ./tf

# =============================================================================
# 리소스 삭제 실행
# =============================================================================
echo "🗑️  리소스 삭제 시작..."
echo "삭제할 리소스 목록을 확인합니다..."

# 삭제 계획 확인
terraform plan -destroy -var="lambda_exec_role_arn=arn:aws:iam::${ACCOUNT_ID}:role/lambda-exec"

echo ""
read -p "위 리소스들을 삭제하시겠습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "삭제가 취소되었습니다."
    exit 1
fi

# 실제 삭제 실행
echo "🗑️  리소스 삭제 중..."
terraform destroy -auto-approve -var="lambda_exec_role_arn=arn:aws:iam::${ACCOUNT_ID}:role/lambda-exec"

echo ""
echo "✅ 모든 리소스가 삭제되었습니다!"
echo "참고: IAM 역할은 별도로 삭제해야 합니다 (보안상 자동 삭제 안됨)"
