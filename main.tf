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

# Initial volume sizes and size change variables
variable "initial_root_size" {
  description = "Initial size of the root volume in GiB"
  type        = number
  default     = 8
}

variable "initial_external_size" {
  description = "Initial size of the external volume in GiB"
  type        = number
  default     = 10
}

variable "size_change" {
  description = "Amount of size to move from external to root volume in GiB"
  type        = number
  default     = 5
}

# Calculate new sizes
locals {
  new_root_size     = var.initial_root_size + var.size_change
  new_external_size = var.initial_external_size - var.size_change
}

resource "aws_vpc" "ccVPC" {
  cidr_block       = "10.0.0.0/16"
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

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y && sudo apt upgrade -y
              sudo apt install openjdk-11-jdk -y
              curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
              sudo apt install -y nodejs
              java -version
              node -v
              npm -v
              if ! file -s /dev/xvdh | grep -q 'ext4'; then
                  sudo mkfs -t ext4 /dev/xvdh
              fi
              sudo mkdir -p /mnt/external_disk_1
              sudo mount /dev/xvdh /mnt/external_disk_1
              echo '/dev/xvdh /mnt/external_disk_1 ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
              sudo chown -R ubuntu:ubuntu /mnt/external_disk_1
              sudo chmod -R 755 /mnt/external_disk_1
              EOF

  tags = {
    Name = "Hello"
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

# DynamoDB table
resource "aws_dynamodb_table" "terraform_locks" {
  name         = "terraform-state-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  tags = {
    Name = "TerraformLocks"
  }

  attribute {
    name = "LockID"
    type = "S"
  }
}
