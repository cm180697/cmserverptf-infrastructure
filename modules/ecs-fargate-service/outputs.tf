output "ecr_repository_url" {
  description = "The URL of the ECR repository."
  value       = aws_ecr_repository.app.repository_url
}

output "load_balancer_dns_name" {
  description = "The DNS name of the Application Load Balancer."
  value       = aws_lb.app.dns_name
}