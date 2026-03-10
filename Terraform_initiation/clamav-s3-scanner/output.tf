output "upload_api_url" {
  description = "HTTP API endpoint used to request presigned upload URLs"
  value       = module.upload_api.api_endpoint
}

output "upload_bucket_name" {
  description = "Bucket that receives uploaded files before scanning"
  value       = module.upload_api.bucket_name
}

output "clean_bucket_name" {
  description = "Bucket that stores clean files"
  value       = module.scanner.clean_bucket_name
}

output "infected_bucket_name" {
  description = "Bucket that stores infected files"
  value       = module.scanner.infected_bucket_name
}

output "scan_queue_url" {
  description = "SQS queue used by the scanner service"
  value       = module.scanner.scan_queue_url
}
