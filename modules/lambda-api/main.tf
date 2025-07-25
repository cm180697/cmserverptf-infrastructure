# DynamoDB Table for visitor counter
resource "aws_dynamodb_table" "visitor_counter_table" {
  name         = "visitor-counter-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S" # S for String
  }

  provisioner "local-exec" {
    command = "aws dynamodb put-item --table-name ${self.name} --item '{\"id\": {\"S\": \"visitor_count\"}, \"visitor_count\": {\"N\": \"0\"}}' --region ${var.aws_region}"
  }
}

# IAM Role for Lambda function
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda-visitor-counter-role"

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

# Lambda Function
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../functions/visitor-counter"
  output_path = "${path.module}/../../functions/visitor-counter.zip"
}

resource "aws_lambda_function" "visitor_counter_lambda" {
  function_name    = "visitor-counter"
  handler          = "app.lambda_handler"
  runtime          = "python3.10"
  role             = aws_iam_role.lambda_exec_role.arn
  
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME  = aws_dynamodb_table.visitor_counter_table.name
      PRIMARY_KEY = "visitor_count"
    }
  }
}

# API Gateway
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "VisitorCounterAPI"
  protocol_type = "HTTP"
  cors_configuration {
    allow_origins = [var.website_url]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["Content-Type"]
  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.lambda_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_counter_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "api_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "api_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "api_gateway_permission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}