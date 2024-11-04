terraform {
  backend "s3" {
    bucket = "github-actions-demo-22"
    key    = "github-actions-demo.tfstate"
    region = "ap-northeast-2"
  }
}
