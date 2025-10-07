terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region
}

variable "region" {
  default = "us-east-1"
}

# DynamoDB table
resource "aws_dynamodb_table" "urls" {
  name         = "url_shortener"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"

  attribute {
    name = "code"
    type = "S"
  }
}

# If you also have this block in your file, make sure it uses multi-line syntax:
# (Only include if your file has the IAM doc; otherwise you can ignore.)
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}
