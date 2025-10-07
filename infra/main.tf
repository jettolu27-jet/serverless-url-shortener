terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    archive = { source = "hashicorp/archive", version = "~> 2.5" }
  }
  required_version = ">= 1.5.0"
}

provider "aws" { region = var.region }

variable "region"        { default = "us-east-1" }
variable "project_name"  { default = "url-shortener" }

# DynamoDB table
resource "aws_dynamodb_table" "urls" {
  name         = "${var.project_name}-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "code"
  attribute { name = "code"; type = "S" }
}

# Package Lambda code from local folder ../lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda.zip"
}

# IAM role for Lambda
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service", identifiers = ["lambda.amazonaws.com"] }
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "${var.project_name}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_rw" {
  name = "${var.project_name}-ddb-rw"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = ["dynamodb:PutItem", "dynamodb:GetItem"],
      Resource = aws_dynamodb_table.urls.arn
    }]
  })
}

# Lambda function
resource "aws_lambda_function" "api" {
  function_name = "${var.project_name}-fn"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.shorten_handler"
  runtime       = "python3.11"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout       = 10

  environment {
    variables = {
      TABLE = aws_dynamodb_table.urls.name
    }
  }
}

# Second Lambda for redirect (same code, different handler)
resource "aws_lambda_function" "redirect" {
  function_name = "${var.project_name}-redirect-fn"
  role          = aws_iam_role.lambda_role.arn
  handler       = "app.redirect_handler"
  runtime       = "python3.11"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout       = 10

  environment {
    variables = {
      TABLE = aws_dynamodb_table.urls.name
    }
  }
}

# HTTP API
resource "aws_apigatewayv2_api" "http" {
  name          = "${var.project_name}-api"
  protocol_type = "HTTP"
}

resource "aws_lambda_permission" "apigw_invoke_shorten" {
  statement_id  = "AllowAPIGatewayInvokeShorten"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_lambda_permission" "apigw_invoke_redirect" {
  statement_id  = "AllowAPIGatewayInvokeRedirect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redirect.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}

resource "aws_apigatewayv2_integration" "shorten_int" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.api.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "redirect_int" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.redirect.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "shorten" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /shorten"
  target    = "integrations/${aws_apigatewayv2_integration.shorten_int.id}"
}

resource "aws_apigatewayv2_route" "resolve" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /{code}"
  target    = "integrations/${aws_apigatewayv2_integration.redirect_int.id}"
}

resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = "$default"
  auto_deploy = true
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.http.api_endpoint
}
