terraform {
  backend "s3" {
    bucket = "${{ secrets.S3_BUCKET }}"           # Your existing bucket
    key    = "terraform/chatbot-lambda.tfstate"  # Path inside bucket
    region = "us-east-1"
  }
}
