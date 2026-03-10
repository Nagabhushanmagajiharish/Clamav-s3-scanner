locals {

  azs = slice(data.aws_availability_zones.available.names, 0, 2) #[eu-west-2a, eu-west-2b]

  subnets = {
    for index, az in local.azs :
    az => cidrsubnet(var.vpc_cidr_block, 8, index)
  }

  name = "${var.resource_prefix}-${var.environment}"
}


data "aws_availability_zones" "available" {}