output "clean_bucket_name" {
  description = "Bucket that stores clean files"
  value       = aws_s3_bucket.clean.bucket
}

output "infected_bucket_name" {
  description = "Bucket that stores infected files"
  value       = aws_s3_bucket.infected.bucket
}

output "scan_queue_url" {
  description = "URL of the scan queue"
  value       = aws_sqs_queue.scan.id
}

output "scan_queue_arn" {
  description = "ARN of the scan queue"
  value       = aws_sqs_queue.scan.arn
}

output "scanner_service_name" {
  description = "ECS service name for the scanner worker"
  value       = aws_ecs_service.scanner.name
}

output "scanner_log_group_name" {
  description = "CloudWatch Logs group for the scanner worker"
  value       = aws_cloudwatch_log_group.scanner.name
}
