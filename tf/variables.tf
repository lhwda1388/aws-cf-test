variable "project" {
  description = "리소스 접두사"
  type        = string
  default     = "edge-demo"
}

variable "lambda_exec_role_arn" {
  description = "Lambda 실행 역할 ARN (예: arn:aws:iam::<ACCOUNT_ID>:role/terraform/lambda-exec)"
  type        = string
}

variable "region" {
  description = "메인 리전 (S3/CloudFront 관리)"
  type        = string
  default     = "ap-northeast-2"
}
