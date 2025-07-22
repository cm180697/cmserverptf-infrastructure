# This variable holds the primary AWS region for our resources.
variable "aws_region" {
  description = "The AWS region to create resources in."
  type        = string
  default     = "us-east-2"
}

# This variable holds our custom domain name.
variable "domain_name" {
  description = "The custom domain name for the website."
  type        = string
  default     = "cmserverptf.click"
}

variable "website_url" {
  description = "The full HTTPS URL of the portfolio website."
  type        = string
  default     = "https://www.cmserverptf.click"
}