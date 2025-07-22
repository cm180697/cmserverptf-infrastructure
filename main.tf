# ==============================================================================
# PROVIDER CONFIGURATION
# We configure two providers: one for our main region and one specifically
# for us-east-1, which is required for the ACM certificate used by CloudFront.
# ==============================================================================

provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# ==============================================================================
# DATA SOURCES
# Fetching information about our existing Route 53 hosted zone.
# ==============================================================================

data "aws_route53_zone" "primary" {
  name = var.domain_name
}

# ==============================================================================
# S3 BUCKET FOR WEBSITE CONTENT
# All resources related to the S3 bucket.
# ==============================================================================

resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = "cm-portfolio-website-${var.domain_name}"
}

resource "aws_s3_bucket_versioning" "portfolio_bucket_versioning" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "portfolio_public_access_block" {
  bucket = aws_s3_bucket.portfolio_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# This block manages the index.html file object in the S3 bucket.
resource "aws_s3_object" "index_file" {
  bucket       = aws_s3_bucket.portfolio_bucket.id
  key          = "index.html" # The name of the file as it will appear in the bucket.
  source       = "src/index.html" # The local path to the file.
  content_type = "text/html"
  etag         = filemd5("src/index.html") # This tells Terraform to re-upload the file if its content changes.
}

# ==============================================================================
# ACM CERTIFICATE FOR SSL/TLS
# All resources related to creating and validating the certificate.
# Note: These resources use the "us_east_1" provider alias.
# ==============================================================================

resource "aws_acm_certificate" "site_certificate" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.primary.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# ==============================================================================
# CLOUDFRONT DISTRIBUTION (CDN)
# The public-facing entry point for our website.
# ==============================================================================

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id   = "S3-${var.domain_name}"

    # Using Origin Access Control (OAC) - the modern, secure method
    origin_access_control_id = aws_cloudfront_origin_access_control.default.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  aliases = ["www.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.domain_name}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  price_class = "PriceClass_100" # Use only North America and Europe

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert_validation.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Creates the Origin Access Control resource for CloudFront
resource "aws_cloudfront_origin_access_control" "default" {
  name                              = "OAC for ${var.domain_name}"
  description                       = "Origin Access Control for S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# This policy allows CloudFront (via OAC) to access the S3 bucket.
resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.portfolio_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.portfolio_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.s3_distribution.arn
          }
        }
      }
    ]
  })
}

# ==============================================================================
# ROUTE 53 DNS RECORDS
# The final DNS record pointing our domain to CloudFront.
# ==============================================================================

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}


output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.s3_distribution.id
}

# ==============================================================================
# DYNAMODB TABLE FOR VISITOR COUNTER
# This table will store our website's visitor count.
# ==============================================================================

resource "aws_dynamodb_table" "visitor_counter_table" {
  name         = "visitor-counter-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # S for String
  }

  # Initialize the table with our counter item
  provisioner "local-exec" {
    command = "aws dynamodb put-item --table-name ${self.name} --item '{\"id\": {\"S\": \"visitor_count\"}, \"visitor_count\": {\"N\": \"0\"}}' --region ${var.aws_region}"
  }
}

# ==============================================================================
# IAM ROLE FOR LAMBDA FUNCTION
# This role grants our Lambda function permission to write to DynamoDB.
# ==============================================================================

resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-visitor-counter-role"

  # This is the trust policy that allows the Lambda service to assume this role.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# This policy attaches the specific permissions to the role.
resource "aws_iam_role_policy" "lambda_dynamodb_policy" {
  name = "lambda-dynamodb-policy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:UpdateItem",
          "dynamodb:GetItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.visitor_counter_table.arn
      },
      # It's also a best practice to allow logging
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}


# ==============================================================================
# LAMBDA FUNCTION
# This section packages and deploys our Python code.
# ==============================================================================

# This data source creates a zip file from our Python code directory.
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/functions/visitor-counter"
  output_path = "${path.module}/functions/visitor-counter.zip"
}

# This is the Lambda function resource itself.
resource "aws_lambda_function" "visitor_counter_lambda" {
  function_name    = "visitor-counter"
  handler          = "app.lambda_handler" # File name is 'app', function name is 'lambda_handler'
  runtime          = "python3.10"
  role             = aws_iam_role.lambda_exec_role.arn
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  # Pass environment variables to the function
  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.visitor_counter_table.name
      PRIMARY_KEY = "visitor_count"
    }
  }
}

# ==============================================================================
# API GATEWAY
# This creates the public HTTP endpoint that triggers our Lambda.
# ==============================================================================

# Creates the API Gateway itself
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "VisitorCounterAPI"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = [var.website_url] # <-- THIS IS THE CHANGE
    allow_methods = ["GET", "OPTIONS"] # More specific methods
    allow_headers = ["Content-Type"]   # More specific headers
  }
}

# Integrates the API Gateway with our Lambda function
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_counter_lambda.invoke_arn
}

# Defines the route (e.g., GET /) for the API
resource "aws_apigatewayv2_route" "api_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Deploys the API to a "live" stage
resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true
}

# Grants API Gateway permission to invoke the Lambda function
resource "aws_lambda_permission" "api_gateway_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}

# ==============================================================================
# OUTPUTS
# This will display the API endpoint URL after we apply the changes.
# ==============================================================================

output "api_endpoint_url" {
  description = "The invoke URL for the visitor counter API."
  value       = aws_apigatewayv2_api.lambda_api.api_endpoint
}