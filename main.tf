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

# Create an EBS volume within the Free Tier limit
resource "aws_ebs_volume" "external_disk" {
  availability_zone = "ap-northeast-1a"
  size              = 10  # Free Tier limit for EBS storage is up to 30 GiB
  tags = {
    Name = "ExternalDisk"
  }
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = "test_key"
  availability_zone = "ap-northeast-1a"
  security_groups   = [aws_security_group.allow_ssh.name]

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
              EOF

  tags = {
    Name = "Hello"
  }
}
# Attach the EBS volume to the EC2 instance
resource "aws_volume_attachment" "ebs_attachment" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.external_disk.id
  instance_id = aws_instance.web.id
}