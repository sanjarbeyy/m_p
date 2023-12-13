terraform {
  cloud {
    organization = "sanjarbey"

    workspaces {
      name = "mini_projectnew"
    }
  }
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