variable "aws_region" {
  description = "AWS region for the deployment"
  type        = string
  default     = "eu-west-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/20"
}

variable "scanner_image" {
  description = "Container image URI for the ClamAV worker"
  type        = string
}

variable "scanner_cpu" {
  description = "CPU units for the scanner task"
  type        = number
  default     = 1024
}

variable "scanner_memory" {
  description = "Memory for the scanner task in MiB"
  type        = number
  default     = 2048
}

variable "desired_count" {
  description = "Number of scanner tasks"
  type        = number
  default     = 1
}

variable "delete_source_object" {
  description = "Delete the uploaded object after copying the scan result"
  type        = bool
  default     = false
}
