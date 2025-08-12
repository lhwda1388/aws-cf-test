#!/bin/bash



PROJECT_NAME=$1
DISTRIBUTION_ID=$2
AWS_PROFILE=$3

export AWS_PROFILE=$AWS_PROFILE

FUNCTION_NAME=$PROJECT_NAME-edge

# edge 폴더의 파일들을 zip으로 압축
chmod +x ./scripts/package.sh
./scripts/package.sh

# Lambda 함수 업데이트
aws lambda update-function-code \
  --region us-east-1 \
  --function-name $FUNCTION_NAME \
  --zip-file fileb://edge.zip \
  --publish \
  --no-cli-pager

echo "Lambda 함수 업데이트 완료"

# 잠시 대기 (버전 생성 완료 대기)
sleep 5

# 새 버전의 ARN 가져오기
NEW_VERSION_ARN=$(aws lambda publish-version \
  --region us-east-1 \
  --function-name $FUNCTION_NAME \
  --query 'FunctionArn' \
  --output text \
  --no-cli-pager)

echo "새 버전 ARN: $NEW_VERSION_ARN"

# ARN이 비어있는지 확인
if [ -z "$NEW_VERSION_ARN" ]; then
  echo "새 버전 ARN을 가져올 수 없습니다. Lambda 함수 상태를 확인하세요."
  exit 1
fi


# CloudFront 배포 설정 업데이트
aws cloudfront get-distribution-config --id $DISTRIBUTION_ID --output json --no-cli-pager > dist-config.json
ETAG=$(jq -r '.ETag' dist-config.json)

# DistributionConfig만 추출하여 새 파일 생성
jq '.DistributionConfig' dist-config.json > dist-config-clean.json

# Lambda ARN 업데이트
jq --arg arn "$NEW_VERSION_ARN" '.DefaultCacheBehavior.LambdaFunctionAssociations.Items[0].LambdaFunctionARN = $arn' dist-config-clean.json > dist-config-new.json

# CloudFront 배포 업데이트
aws cloudfront update-distribution \
  --id $DISTRIBUTION_ID \
  --if-match $ETAG \
  --distribution-config file://dist-config-new.json \
  --no-cli-pager

# 임시 파일 삭제
rm dist-config.json dist-config-clean.json dist-config-new.json

# 압축 파일 삭제
rm edge.zip
