variable "lambda_function_name" {
  description = "Lambda function name"
  type        = string
}

variable "lambda_role_name" {
  description = "Name of the IAM role for Lambda"
  type        = string
}

variable "s3_bucket" {
  description = "The name of the S3 bucket for the Terraform state"
  type        = string
}

variable "deployment_package_key" {
  description = "Path to the deployment package inside the S3 bucket"
  type        = string
}

variable "create_lambda_role" {
  description = "Set to true to create a new IAM role, false to reference existing one"
  type        = bool
  default     = true
}