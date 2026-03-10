
provider "aws" {
  region = "eu-west-1"
}

module "api" {
  source          = "../../terraform_modules/api-s3-connector"
  resource_prefix = "bushan-api-s3-connector"
}

