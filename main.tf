# Data source for Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Calculate new sizes
locals {
  new_root_size     = var.initial_root_size + var.size_change
  new_external_size = var.initial_external_size - var.size_change
}

resource "aws_vpc" "ccVPC" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"

  tags = {
    Name = "ccVPC"
  }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.ccVPC.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.ccVPC.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-northeast-1a"

  tags = {
    Name = "PrivateSubnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.ccVPC.id

  tags = {
    Name = "InternetGateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.ccVPC.id

  route {
    cidr_block = "0.0.0.0/0" # Allow internet traffic
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}


resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_new"
  description = "Allow SSH access"
  vpc_id      = aws_vpc.ccVPC.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CloudWatch Log Group for Audit Trail
resource "aws_cloudwatch_log_group" "audit_log_group" {
  name              = "/aws/ec2/audit_trail"
  retention_in_days = 90

  tags = {
    Name = "AuditTrailLogs"
  }
}

# S3 Bucket for Artifact History
resource "aws_s3_bucket" "artifact_history_bucket" {
  bucket = "artifact-history-bucket-${random_id.s3_suffix.hex}"

  tags = {
    Name = "ArtifactHistory"
  }
}

resource "random_id" "s3_suffix" {
  byte_length = 4
}

# IAM Role for EC2 Instance
resource "aws_iam_role" "cloudwatch_s3_role" {
  name               = "CloudWatchS3AccessRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Effect   = "Allow"
    }]
  })
}

# IAM Policy for Logging to CloudWatch and Writing to S3
resource "aws_iam_policy" "cloudwatch_s3_policy" {
  name        = "CloudWatchS3AccessPolicy"
  description = "Policy to allow logging to CloudWatch and writing to S3"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "logs:CreateLogGroup"
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Action   = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:log-group:/aws/ec2/audit_trail:*"
      },
      {
        Action   = "s3:PutObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.artifact_history_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_policy" {
  role       = aws_iam_role.cloudwatch_s3_role.name
  policy_arn = aws_iam_policy.cloudwatch_s3_policy.arn
}


# EC2 instance in public subnet
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = "ec2_key"
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]

  root_block_device {
    volume_size = local.new_root_size
    volume_type = "gp2"
  }
  user_data = templatefile("./user_data.sh", {
    artifact_bucket    = aws_s3_bucket.artifact_history_bucket.bucket
  })

  tags = {
    Name = "Hello_EC2"
  }
}

# External EBS volume
resource "aws_ebs_volume" "external_disk_1" {
  availability_zone = "ap-northeast-1a"
  size              = local.new_external_size
  tags = {
    Name = "ExternalDisk1"
  }
}

# Attach the external EBS volume to the EC2 instance
resource "aws_volume_attachment" "ebs_attachment_1" {
  device_name = "/dev/xvdh"
  volume_id   = aws_ebs_volume.external_disk_1.id
  instance_id = aws_instance.web.id
  force_detach = true
}

resource "aws_iam_role" "dynamo_role" {
  name               = "DynamoDBAccessRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Effect   = "Allow"
      Sid      = ""
    }]
  })
}

resource "aws_iam_policy" "dynamo_policy" {
  name        = "DynamoDBFullAccess"
  description = "Provides full access to DynamoDB"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "dynamodb:*"
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "dynamo_attachment" {
  role       = aws_iam_role.dynamo_role.name
  policy_arn = aws_iam_policy.dynamo_policy.arn
}

resource "aws_dynamodb_table" "products" {
  name           = "products"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  range_key      = "barcode"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "barcode"
    type = "S"
  }

  attribute {
    name = "name"
    type = "S"
  }

  attribute {
    name = "description"
    type = "S"
  }

  global_secondary_index {
    name               = "DescriptionNamePriceIndex"
    hash_key           = "name"
    range_key          = "description"
    projection_type    = "ALL"
  }
}
