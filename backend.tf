# backend.tf
terraform {
  backend "s3" {
    bucket         = "cm-terraform-remote-state-20240720"  # This is the bucke name
    key            = "global/s3/terraform.tfstate"         # This is the "path" to the state file inside the bucket
    region         = "us-east-2"                           # The region where you created the bucket
    dynamodb_table = "terraform-state-lock"                # The name of the DynamoDB table
    encrypt        = true
  }
}