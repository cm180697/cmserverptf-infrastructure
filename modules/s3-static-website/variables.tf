variable "domain_name" {
  description = "The custom domain name for the website."
  type        = string
}

variable "website_url" {
  description = "The full HTTPS URL of the portfolio website."
  type        = string
}

variable "alb_dns_name" {
  description = "The DNS name of the internal Application Load Balancer."
  type        = string
}