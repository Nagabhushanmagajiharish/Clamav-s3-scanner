module "vpc" {
  source = "../../terraform_modules/vpc"

  environment            = var.environment
  resource_prefix        = var.resource_prefix
  vpc_cidr_block         = var.cidr_block
 }

# module "ecs_cluster" {
#   source = "../terraform_modules/ecs_cluster"

#   ecs_cluster_name = "ecs-${var.resource_prefix}-${var.environment}"

#   tags = {
#     Environment = var.environment
#     ManagedBy   = "terraform"
#   }
# }