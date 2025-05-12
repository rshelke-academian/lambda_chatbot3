terraform {
  backend "s3" {
    bucket = var.s3_bucket
    key    = "terraform/chatbot-lambda.tfstate"  # Path inside bucket
    region = "us-east-1"
  }
}
