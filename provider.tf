terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.40.0"
    }
  }
}

provider "aws"{
  region = "ap-northeast-2"

  access_key  = var.access_key
  secret_key  = var.secret_key

  assume_role {
    role_arn = var.assume_role
  }
}
