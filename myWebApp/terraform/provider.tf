provider "aws" {
  region = "eu-west-2"
}

terraform {
  backend "s3" {
    # Replace this with your bucket name!
    bucket         = "glamorous-devops-terraform-state"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "glamorous-devops-test-terraform-lock"
    encrypt        = true
  }
}

