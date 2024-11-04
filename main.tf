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

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name = "l2"

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