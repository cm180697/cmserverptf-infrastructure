# monitoring.tf

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "Portfolio-Website-Dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric",
        x      = 0,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApiGatewayV2", "Count", "ApiId", module.lambda_api.api_id, { "label" = "API Requests" }],
            [".", "4xx", ".", ".", { "label" = "4xx Errors" }],
            [".", "5xx", ".", ".", { "label" = "5xx Errors" }]
          ],
          period = 300,
          stat   = "Sum",
          region = var.aws_region,
          title  = "API Gateway: Request & Error Counts"
        }
      },
      {
        type   = "metric",
        x      = 12,
        y      = 0,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/ApiGatewayV2", "Latency", "ApiId", module.lambda_api.api_id]
          ],
          period = 300,
          stat   = "Average",
          region = var.aws_region,
          title  = "API Gateway: Average Latency"
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 7,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", module.lambda_api.lambda_function_name, { "label" = "Invocations" }],
            [".", "Errors", ".", ".", { "label" = "Errors" }]
          ],
          period = 300,
          stat   = "Sum",
          region = var.aws_region,
          title  = "Lambda: Invocation & Error Counts"
        }
      },
      {
        type   = "metric",
        x      = 12,
        y      = 7,
        width  = 12,
        height = 6,
        properties = {
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", module.lambda_api.lambda_function_name]
          ],
          period = 300,
          stat   = "Average",
          region = var.aws_region,
          title  = "Lambda: Average Duration"
        }
      }
    ]
  })
}
