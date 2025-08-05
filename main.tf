provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

module "s3_static_website" {
  source      = "./modules/s3-static-website"
  domain_name = var.domain_name
  website_url = var.website_url
  alb_dns_name = module.ecs_fargate_service.load_balancer_dns_name # <-- Pass the output

  providers = {
    aws.us_east_1 = aws.us_east_1
  }
}

module "lambda_api" {
  source      = "./modules/lambda-api"
  aws_region  = var.aws_region
  website_url = var.website_url
}

module "ecs_fargate_service" {
  source     = "./modules/ecs-fargate-service"
  aws_region = var.aws_region
}


# --- Root Outputs ---
output "s3_bucket_id" {
  description = "The ID of the S3 bucket."
  value       = module.s3_static_website.s3_bucket_id
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = module.s3_static_website.cloudfront_distribution_id
}

output "api_endpoint_url" {
  description = "The invoke URL for the visitor counter API (Lambda)."
  value       = module.lambda_api.api_endpoint_url
}

output "ecr_repository_url" {
  description = "The URL of the ECR repository."
  value       = module.ecs_fargate_service.ecr_repository_url
}

# The public endpoint for the container is now the main website URL with /api/
output "container_api_endpoint" {
  description = "The public invoke URL for the containerized API."
  value       = "${var.website_url}/api/"
}