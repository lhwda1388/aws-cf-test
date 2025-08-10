#!/bin/bash

# 프로젝트 이름 가져오기 
PROJECT_NAME=$1

# S3 버킷 이름 생성
BUCKET_NAME="${PROJECT_NAME}-site"

# CloudFront 배포 ID 가져오기
DISTRIBUTION_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?Comment=='${PROJECT_NAME} distribution'].Id" --output text)

# S3에 파일 업로드
cd ../src
aws s3 sync . s3://$BUCKET_NAME

# CloudFront 캐시 무효화
aws cloudfront create-invalidation \
  --distribution-id $DISTRIBUTION_ID \
  --paths "/*"

cd ..

