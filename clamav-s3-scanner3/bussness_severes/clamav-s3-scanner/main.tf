provider "aws" {
  region = var.aws_region
}

module "upload_api" {
  source = "../../terraform_modules/api-s3-connector"

  resource_prefix = "${var.resource_prefix}-${var.environment}-upload"
}

module "vpc" {
  source = "../../terraform_modules/vpc"

  environment     = var.environment
  resource_prefix = var.resource_prefix
  vpc_cidr_block  = var.cidr_block
}

module "ecs_cluster" {
  source = "../../terraform_modules/ecs_cluster"

  ecs_cluster_name = "${var.resource_prefix}-${var.environment}-clamav"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "scanner" {
  source = "../../terraform_modules/clamav-s3-scanner"

  resource_prefix      = var.resource_prefix
  environment          = var.environment
  source_bucket_name   = module.upload_api.bucket_name
  source_bucket_arn    = module.upload_api.bucket_arn
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.public_subnet_ids
  ecs_cluster_arn      = module.ecs_cluster.cluster_arn
  scanner_image        = var.scanner_image
  scanner_cpu          = var.scanner_cpu
  scanner_memory       = var.scanner_memory
  desired_count        = var.desired_count
  delete_source_object = var.delete_source_object
}
