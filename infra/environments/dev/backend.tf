terraform{
  backend "s3" {
    bucket         = "52297389-bucket-1"
    key            = "NSH-fargate/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
