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
  name        = "allow_ssh"
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
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  count = 700  # Creates 1000 instances
  key_name = "l2"
  security_groups = [aws_security_group.allow_ssh.name]  # Attach the security group here

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
    Name = "Hello-${count.index}"
  }
}