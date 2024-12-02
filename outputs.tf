output "vpc_id" {
  description = "The ID of the created VPC"
  value       = aws_vpc.ccVPC.id
}

output "public_subnet_id" {
  description = "The ID of the created public subnet"
  value       = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  description = "The ID of the created private subnet"
  value       = aws_subnet.private_subnet.id
}

output "internet_gateway_id" {
  description = "The ID of the created internet gateway"
  value       = aws_internet_gateway.igw.id
}

output "public_route_table_id" {
  description = "The ID of the created public route table"
  value       = aws_route_table.public_route_table.id
}

output "security_group_id" {
  description = "The ID of the security group allowing SSH access"
  value       = aws_security_group.allow_ssh.id
}

output "cloudwatch_log_group_name" {
  description = "The name of the CloudWatch Log Group for audit trail"
  value       = aws_cloudwatch_log_group.audit_log_group.name
}

output "artifact_history_bucket_name" {
  description = "The name of the S3 bucket for artifact history"
  value       = aws_s3_bucket.artifact_history_bucket.bucket
}

output "ec2_instance_id" {
  description = "The ID of the created EC2 instance"
  value       = aws_instance.web.id
}

output "external_ebs_volume_id" {
  description = "The ID of the attached external EBS volume"
  value       = aws_ebs_volume.external_disk_1.id
}

output "iam_role_cloudwatch_s3" {
  description = "The name of the IAM role for CloudWatch and S3 access"
  value       = aws_iam_role.cloudwatch_s3_role.name
}

# output "dynamodb_table_name" {
#   description = "The name of the DynamoDB table"
#   value       = aws_dynamodb_table.products.name
# }
