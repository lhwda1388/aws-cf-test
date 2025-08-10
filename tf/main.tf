# =============================================================================
# 테라폼 설정 (Terraform Configuration)
# =============================================================================
# 이 블록은 테라폼 자체의 설정을 정의합니다
terraform {
  # 테라폼 버전 요구사항 (1.5.0 이상 필요)
  required_version = ">= 1.5.0"
  
  # 사용할 프로바이더들을 정의
  required_providers {
    # AWS 프로바이더: AWS 서비스와 상호작용
    aws = {
      source  = "hashicorp/aws"  # 공식 AWS 프로바이더
      version = ">= 5.50.0"      # 5.50.0 이상 버전 사용
    }
    # Random 프로바이더: 랜덤 값 생성 (현재는 사용하지 않음)
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

# =============================================================================
# AWS 프로바이더 설정 (AWS Provider Configuration)
# =============================================================================
# AWS 서비스에 접근하기 위한 인증 및 리전 설정

# 메인 AWS 프로바이더 (대부분의 리소스용)
provider "aws" {
  region = var.region  # variables.tf에서 정의한 리전 사용 (기본값: ap-northeast-2)

  # 로컬 환경에서 AWS_PROFILE 쓰면 여기에 굳이 profile 안 적어도 됩니다.
  # profile = "your-profile"
}

# Lambda@Edge 전용 프로바이더 (반드시 us-east-1 리전 필요)
# Lambda@Edge는 CloudFront와 함께 작동하므로 us-east-1에만 배포 가능
provider "aws" {
  alias  = "use1"      # 별칭으로 구분
  region = "us-east-1" # Lambda@Edge는 반드시 us-east-1에 있어야 함
}

# =============================================================================
# 데이터 소스 (Data Sources)
# =============================================================================
# 기존 AWS 리소스에서 정보를 가져오는 용도

# 현재 AWS 계정 정보 가져오기 (계정 ID, 사용자 ARN 등)
data "aws_caller_identity" "me" {}





# =============================================================================
# IAM 역할 참조 (Identity and Access Management)
# =============================================================================
# 기존에 생성된 Lambda 실행 역할을 사용
# 별도로 IAM 역할을 생성하지 않고 기존 역할의 ARN을 변수로 받아서 사용

# =============================================================================
# S3 버킷 설정 (Simple Storage Service)
# =============================================================================
# 정적 웹사이트 파일들을 저장하는 스토리지

# 1) S3 버킷 생성 (정적 파일 저장소)
resource "aws_s3_bucket" "site" {
  bucket = "${var.project}-site"  # 버킷 이름 (예: cf-test-site)
  force_destroy = true            # terraform destroy 시 버킷 내용도 함께 삭제
  
  
}

# S3 버킷 소유권 설정 (ACL 비활성화)
resource "aws_s3_bucket_ownership_controls" "site" {
  bucket = aws_s3_bucket.site.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# 2) 퍼블릭 액세스 차단 설정
# 보안을 위해 S3 버킷을 직접 접근 불가능하게 만듦
# CloudFront를 통해서만 접근 가능하도록 설정
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id  # 위에서 생성한 버킷
  block_public_acls       = true                   # 퍼블릭 ACL 차단
  block_public_policy     = false                  # 퍼블릭 정책은 허용 (CloudFront용)
  ignore_public_acls      = true                   # 퍼블릭 ACL 무시
  restrict_public_buckets = true                   # 퍼블릭 버킷 정책 제한
  
  depends_on = [aws_s3_bucket_ownership_controls.site]
}

# =============================================================================
# Lambda@Edge 함수 (Lambda at Edge)
# =============================================================================
# CloudFront 엣지 서버에서 실행되는 서버리스 함수
# 요청/응답을 실시간으로 수정할 수 있음

# Lambda@Edge 함수 생성 (반드시 us-east-1 리전에 배포)
resource "aws_lambda_function" "edge" {
  provider         = aws.use1                    # us-east-1 리전 프로바이더 사용
  function_name    = "${var.project}-edge"       # 함수 이름 (예: cf-test-edge)
  role             = var.lambda_exec_role_arn # 위에서 생성한 IAM 역할
  handler          = "index.handler"             # 실행할 함수 (edge/index.js의 handler)
  runtime          = "nodejs20.x"                # Node.js 20.x 런타임
  filename         = "${path.module}/../edge.zip" # 압축된 함수 코드 파일
  source_code_hash = filebase64sha256("${path.module}/../edge.zip")  # 코드 변경 감지용 해시
  publish          = true                        # 버전 생성 (CloudFront 연결 필수)
}

# =============================================================================
# CloudFront Origin Access Control (OAC)
# =============================================================================
# S3 버킷에 대한 안전한 접근 제어
# CloudFront만 S3에 접근할 수 있도록 하는 보안 설정

# Origin Access Control 생성
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project}-oac"  # OAC 이름 (예: cf-test-oac)
  description                       = "OAC for ${aws_s3_bucket.site.bucket}"  # 설명
  origin_access_control_origin_type = "s3"                  # S3 오리진용
  signing_behavior                  = "always"              # 항상 서명
  signing_protocol                  = "sigv4"               # AWS Signature Version 4 사용
}

# =============================================================================
# CloudFront 배포 (Content Delivery Network)
# =============================================================================
# 전 세계에 콘텐츠를 빠르게 전달하는 CDN
# S3의 정적 파일을 캐싱하고 전 세계 사용자에게 제공

# CloudFront 배포 생성 (Lambda@Edge 연결 시 버전 ARN 필요)
resource "aws_cloudfront_distribution" "cdn" {


  enabled             = true                    # 배포 활성화
  comment             = "${var.project} distribution"  # 배포 설명
  price_class         = "PriceClass_200"        # 가격 클래스 (미국, 유럽, 아시아)
  is_ipv6_enabled     = true                    # IPv6 지원
  default_root_object = "index.html"            # 루트 경로 요청 시 기본 파일

  # 오리진 설정 (콘텐츠가 저장된 원본 서버)
  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name  # S3 버킷 도메인
    origin_id                = "s3Origin"                                      # 오리진 식별자
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id    # OAC 연결
  }

  # 기본 캐시 동작 설정
  default_cache_behavior {
    target_origin_id       = "s3Origin"         # 위에서 정의한 S3 오리진
    viewer_protocol_policy = "redirect-to-https" # HTTP 요청을 HTTPS로 리다이렉트

    allowed_methods = ["GET", "HEAD"]  # 허용된 HTTP 메서드
    cached_methods  = ["GET", "HEAD"]  # 캐시할 HTTP 메서드

    compress = true  # 콘텐츠 압축 활성화

    # Lambda@Edge 함수 연결
    lambda_function_association {
      event_type   = "viewer-request"                    # 요청 시점에 실행
      lambda_arn   = aws_lambda_function.edge.qualified_arn  # ★ 버전 ARN (publish=true로 생성됨)
      include_body = false                               # 요청 본문 포함 안함
    }

    # ForwardedValues 설정 (CloudFront API 요구사항)
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  # 지역 제한 설정
  restrictions {
    geo_restriction { 
      restriction_type = "none"  # 모든 국가에서 접근 가능
    }
  }

  # SSL 인증서 설정
  viewer_certificate { 
    cloudfront_default_certificate = true  # CloudFront 기본 SSL 인증서 사용
  }
}

# =============================================================================
# S3 버킷 정책 (Bucket Policy)
# =============================================================================
# S3 버킷에 대한 접근 권한 설정
# CloudFront OAC만 읽기 허용하도록 보안 설정

# 5) S3 버킷 정책 문서 생성
#   - Principal: cloudfront.amazonaws.com (CloudFront 서비스)
#   - Condition: AWS:SourceArn == 배포 ARN (특정 CloudFront 배포만 허용)
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "AllowCloudFrontOACRead"  # 정책 설명
    effect  = "Allow"                    # 허용
    principals {
      type        = "Service"            # AWS 서비스
      identifiers = ["cloudfront.amazonaws.com"]  # CloudFront 서비스만
    }
    actions   = ["s3:GetObject"]         # 파일 읽기 권한만
    resources = ["${aws_s3_bucket.site.arn}/*"]  # 버킷 내 모든 객체

    # 추가 보안 조건: 특정 CloudFront 배포만 허용
    condition {
      test     = "StringEquals"          # 정확히 일치
      variable = "AWS:SourceArn"         # 요청 출처 ARN
      values   = [aws_cloudfront_distribution.cdn.arn]  # 위에서 생성한 CloudFront 배포
    }
  }
}

# S3 버킷에 정책 적용
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id  # 위에서 생성한 S3 버킷
  policy = data.aws_iam_policy_document.bucket_policy.json  # 위에서 정의한 정책
}

# =============================================================================
# S3 파일 업로드 (Static Files Upload)
# =============================================================================
# src 폴더의 모든 정적 파일을 S3 버킷에 업로드

# 6) src 폴더의 모든 파일 목록 가져오기
locals {
  src_files = fileset("${path.module}/../src", "**/*")  # src 폴더 내 모든 파일과 하위 폴더
}

# 각 파일을 개별 S3 객체로 업로드
resource "aws_s3_object" "src_files" {
  for_each = local.src_files  # 각 파일마다 반복 실행
  
  bucket = aws_s3_bucket.site.id                    # 위에서 생성한 S3 버킷
  key    = each.value                               # 파일 경로 (예: index.html, css/style.css)
  source = "${path.module}/../src/${each.value}"    # 로컬 파일 경로
  
  content_type = "all"  # AWS가 파일 확장자에 따라 자동으로 MIME 타입 설정
}


