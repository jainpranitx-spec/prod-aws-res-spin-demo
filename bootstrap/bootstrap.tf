terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

resource "random_string" "bucket_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "aws_s3_bucket" "state_bucket" {
  # Result will be something like: prod-aws-tf-state-save-x4b7df
  bucket = "prod-aws-tf-state-save-${random_string.bucket_suffix.result}" 
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.state_bucket.id
  description = "The dynamic name of the generated S3 backend bucket"
}