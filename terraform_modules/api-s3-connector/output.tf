output "bucket_name" {
  description = "Name of the upload bucket"
  value       = aws_s3_bucket.upload-bucket-bushan-2001.bucket
}

output "bucket_arn" {
  description = "ARN of the upload bucket"
  value       = aws_s3_bucket.upload-bucket-bushan-2001.arn
}

output "api_endpoint" {
  description = "Invoke URL for the HTTP API"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "lambda_function_name" {
  description = "Name of the Lambda function that issues presigned URLs"
  value       = aws_lambda_function.presign_lambda.function_name
}
