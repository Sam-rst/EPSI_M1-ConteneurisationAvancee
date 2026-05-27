provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "tp-cont"
      Environment = "docker"
      ManagedBy   = "terraform"
      Owner       = "samuel.ressiot@gmail.com"
    }
  }
}
