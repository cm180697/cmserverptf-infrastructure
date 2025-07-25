output "api_endpoint_url" {
  description = "The invoke URL for the visitor counter API."
  value       = aws_apigatewayv2_api.lambda_api.api_endpoint
}