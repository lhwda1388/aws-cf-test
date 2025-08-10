output "account_id" {
  value = data.aws_caller_identity.me.account_id
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
