terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
  }
}

provider "aws" {
  region = var.region

  # 로컬 환경에서 AWS_PROFILE 쓰면 여기에 굳이 profile 안 적어도 됩니다.
  # profile = "your-profile"
}

# Lambda@Edge 용 us-east-1
provider "aws" {
  alias  = "use1"
  region = "us-east-1"
}

data "aws_caller_identity" "me" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# 1) S3 버킷 (정적 오리진)
resource "aws_s3_bucket" "site" {
  bucket = "${var.project}-${random_string.suffix.result}"
  force_destroy = true
}

# 퍼블릭 액세스 차단 (CloudFront OAC만 접근하도록)
resource "aws_s3_bucket_public_access_block" "site" {
  bucket                  = aws_s3_bucket.site.id
  block_public_acls       = true
  block_public_policy     = false # 정책으로 허용할 거라 false
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2) Lambda@Edge 함수 (us-east-1, 반드시 publish = true)
resource "aws_lambda_function" "edge" {
  provider         = aws.use1
  function_name    = "${var.project}-edge-${random_string.suffix.result}"
  role             = var.lambda_exec_role_arn
  handler          = "index.handler"
  runtime          = "nodejs20.x"
  filename         = "${path.module}/edge.zip"
  source_code_hash = filebase64sha256("${path.module}/edge.zip")
  publish          = true
}

# 3) Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "${var.project}-oac-${random_string.suffix.result}"
  description                       = "OAC for ${aws_s3_bucket.site.bucket}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 4) CloudFront 배포 (Lambda@Edge 연결 시 버전 ARN 필요)
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  comment             = "${var.project} distribution"
  price_class         = "PriceClass_200"
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "s3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "s3Origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    compress = true

    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = aws_lambda_function.edge.qualified_arn # ★ 버전 ARN
      include_body = false
    }
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate { cloudfront_default_certificate = true }
}

# 5) S3 버킷 정책 (CloudFront OAC만 읽기 허용)
#   - Principal: cloudfront.amazonaws.com
#   - Condition: AWS:SourceArn == 배포 ARN
data "aws_iam_policy_document" "bucket_policy" {
  statement {
    sid     = "AllowCloudFrontOACRead"
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.site.arn}/*"]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.cdn.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = data.aws_iam_policy_document.bucket_policy.json
}

# 6) 샘플 index.html 업로드
resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.site.id
  key          = "index.html"
  content      = "<!doctype html><html><body><h1>Hello from CloudFront + Lambda@Edge</h1></body></html>"
  content_type = "text/html"
}

output "bucket" {
  value = aws_s3_bucket.site.bucket
}

output "cloudfront_domain" {
  value = aws_cloudfront_distribution.cdn.domain_name
}

output "lambda_edge_version_arn" {
  value = aws_lambda_function.edge.qualified_arn
}
