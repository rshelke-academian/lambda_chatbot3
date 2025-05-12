
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Get current account ID for dynamic policy ARN
data "aws_caller_identity" "current" {}

# Reference existing S3 bucket (do NOT create it)
data "aws_s3_bucket" "lambda_bucket" {
  bucket = var.s3_bucket
}

# Conditional IAM role creation
variable "create_lambda_role" {
  type    = bool
  default = false
}

resource "aws_iam_role" "lambda_role" {
  count = var.create_lambda_role ? 1 : 0
  name  = var.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

data "aws_iam_role" "lambda_role" {
  count = var.create_lambda_role ? 0 : 1
  name  = var.lambda_role_name
}

locals {
  lambda_role_arn  = var.create_lambda_role ? aws_iam_role.lambda_role[0].arn : data.aws_iam_role.lambda_role[0].arn
  lambda_role_name = var.create_lambda_role ? aws_iam_role.lambda_role[0].name : data.aws_iam_role.lambda_role[0].name
}

# Reference existing IAM policy for Bedrock access
data "aws_iam_policy" "lambda_bedrock_policy" {
  arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/chatbot-lambda-bedrock-policy"
}

# Lambda function
resource "aws_lambda_function" "chatbot_lambda" {
  function_name = var.lambda_function_name
  s3_bucket     = data.aws_s3_bucket.lambda_bucket.id
  s3_key        = var.deployment_package_key
  role          = local.lambda_role_arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"
  timeout       = 30
  memory_size   = 256

  environment {
    variables = {
      BEDROCK_MODEL_ID = "us.anthropic.claude-3-7-sonnet-20250219-v1:0"
    }
  }
}

# IAM role policy attachments
resource "aws_iam_role_policy_attachment" "lambda_bedrock_policy_attachment" {
  role       = local.lambda_role_name
  policy_arn = data.aws_iam_policy.lambda_bedrock_policy.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic_policy_attachment" {
  role       = local.lambda_role_name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# API Gateway for Lambda
resource "aws_apigatewayv2_api" "lambda_api" {
  name          = "${var.lambda_function_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda_stage" {
  api_id      = aws_apigatewayv2_api.lambda_api.id
  name        = "prod"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.lambda_api.id
  integration_type   = "AWS_PROXY"
  connection_type    = "INTERNET"
  description        = "Lambda integration"
  integration_method = "POST"
  integration_uri    = aws_lambda_function.chatbot_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "lambda_route" {
  api_id    = aws_apigatewayv2_api.lambda_api.id
  route_key = "POST /chat"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chatbot_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.lambda_api.execution_arn}/*/*"
}
