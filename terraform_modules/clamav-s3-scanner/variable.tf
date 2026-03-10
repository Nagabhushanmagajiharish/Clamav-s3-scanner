variable "resource_prefix" {
  description = "Prefix used for resource names"
  type        = string
}

variable "environment" {
  description = "Deployment environment name"
  type        = string
}

variable "source_bucket_name" {
  description = "Bucket that receives uploaded files before scanning"
  type        = string
}

variable "source_bucket_arn" {
  description = "ARN of the source upload bucket"
  type        = string
}

variable "vpc_id" {
  description = "VPC where the scanner service will run"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for the scanner service"
  type        = list(string)
}

variable "ecs_cluster_arn" {
  description = "ARN of the ECS cluster used by the scanner service"
  type        = string
}

variable "scanner_image" {
  description = "Container image URI for the scanner worker"
  type        = string
}

variable "scanner_cpu" {
  description = "CPU units for the scanner task"
  type        = number
  default     = 1024
}

variable "scanner_memory" {
  description = "Memory in MiB for the scanner task"
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Number of scanner tasks to run"
  type        = number
  default     = 1
}

variable "assign_public_ip" {
  description = "Whether the Fargate task should receive a public IP"
  type        = bool
  default     = true
}

variable "object_prefix" {
  description = "Prefix inside the source bucket that should trigger scans"
  type        = string
  default     = "uploads/"
}

variable "delete_source_object" {
  description = "Delete the source object after a successful scan result copy"
  type        = bool
  default     = false
}
