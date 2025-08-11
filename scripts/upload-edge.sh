#!/bin/bash



PROJECT_NAME=$1
AWS_PROFILE=$2

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
  --publish

# 새 버전의 ARN 가져오기
NEW_VERSION_ARN=$(aws lambda list-function-versions \
  --region us-east-1 \
  --function-name $FUNCTION_NAME \
  --query 'Versions[-1].FunctionArn' \
  --output text)

# CloudFront 배포 ID 가져오기
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='${FUNCTION_NAME} distribution'].Id" --output text)

# CloudFront 배포 설정 업데이트
aws cloudfront get-distribution-config --id $DISTRIBUTION_ID --output json > dist-config.json
ETAG=$(jq -r '.ETag' dist-config.json)
jq --arg arn "$NEW_VERSION_ARN" '.DistributionConfig.DefaultCacheBehavior.LambdaFunctionAssociations.Items[0].LambdaFunctionARN = $arn' dist-config.json > dist-config-new.json

# CloudFront 배포 업데이트
aws cloudfront update-distribution \
  --id $DISTRIBUTION_ID \
  --if-match $ETAG \
  --distribution-config file://dist-config-new.json

# 임시 파일 삭제
rm dist-config.json dist-config-new.json

# 압축 파일 삭제
rm edge.zip
