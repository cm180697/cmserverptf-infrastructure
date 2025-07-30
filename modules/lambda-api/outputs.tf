output "api_endpoint_url" {
  description = "The invoke URL for the visitor counter API."
  value       = aws_apigatewayv2_api.lambda_api.api_endpoint
}

output "api_id" {
  description = "The ID of the API Gateway."
  value       = aws_apigatewayv2_api.lambda_api.id
}

output "lambda_function_name" {
  description = "The name of the Lambda function."
  value       = aws_lambda_function.visitor_counter_lambda.function_name
}
