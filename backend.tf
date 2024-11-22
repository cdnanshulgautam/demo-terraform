terraform {
  backend "s3" {
    bucket = "github-actions-demo-33"
    key    = "github-actions-demo.tfstate"
    region = "ap-northeast-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
