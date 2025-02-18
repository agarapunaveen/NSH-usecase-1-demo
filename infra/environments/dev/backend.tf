terraform{
  backend "s3" {
    bucket         = "nsh-usecase-1"
    key            = "NSH-fargate/dev/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
  }
}
