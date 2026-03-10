# Mandatory Variables
variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix for resource names"
  type        = string
}

# Optional
variable "aws_region" {
  description = "AWS region where resources will be created"
  type        = string
  default     = "eu-east-1"
}

variable "cidr_block" {
  description = "VPC cidr blcok to be created"
  type        = string
  default     = "10.0.0.0/20"
}