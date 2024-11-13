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

# Define initial volume sizes as variables
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

# Define the size change in GiB
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

# Define a security group with SSH access
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_new"
  description = "Allow SSH access from anywhere"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allows SSH from any IP address
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Allows all outbound traffic
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"  # Free Tier eligible instance type
  key_name               = "test_key"
  availability_zone      = "ap-northeast-1a"
  security_groups        = [aws_security_group.allow_ssh.name]

  root_block_device {
    volume_size = local.new_root_size  # Adjusted dynamically
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              # Update and upgrade the system
              sudo apt update -y && sudo apt upgrade -y

              # Install Java Development Kit (JDK)
              sudo apt install openjdk-11-jdk -y

              # Install Node.js and npm
              curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
              sudo apt install -y nodejs

              # Verify installations
              java -version
              node -v
              npm -v

              # Format and mount the first external EBS volume if not already formatted
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

# Create the first external EBS volume
resource "aws_ebs_volume" "external_disk_1" {
  availability_zone = "ap-northeast-1a"
  size              = local.new_external_size  # Adjusted dynamically
  tags = {
    Name = "ExternalDisk1"
  }
}


# Attach the first EBS volume to the EC2 instance
resource "aws_volume_attachment" "ebs_attachment_1" {
  device_name = "/dev/xvdh"
  volume_id   = aws_ebs_volume.external_disk_1.id
  instance_id = aws_instance.web.id
  force_detach = true  # Force detach if it's attached elsewhere
}

