# Get the latest Ubuntu AMI
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

  owners = ["099720109477"] # Canonical's AWS account
}


The errors you're encountering are related to:

Security Group VPC Issue: The VPCIdNotSpecified error occurs because the security group requires an explicit VPC ID when there is no default VPC. If you don't have a default VPC in your account, you need to specify a VPC for the security group.

IAM Role Already Exists: The EntityAlreadyExists error indicates that a role with the name EC2Role already exists in your IAM configuration.

Here's how to address these issues:

Solution 1: Specify a VPC ID for the Security Group
If you already have a VPC, specify its ID when creating the security group. You can add a vpc_id attribute to the aws_security_group resource.

Update your security group resource like this:

hcl
Copy code
# Define a security group with SSH access
resource "aws_security_group" "allow_ssh_port" {
  name        = "allow_ssh_port"
  description = "Allow SSH access from anywhere"
  vpc_id      = "your-vpc-id"  # Replace "your-vpc-id" with your actual VPC ID

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

# Create IAM Role for EC2
resource "aws_iam_role" "ec2_role_one" {
  name = "EC2Role_New"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach a policy to the role (Example: AmazonEC2ReadOnlyAccess)
resource "aws_iam_role_policy_attachment" "ec2_read_only" {
  role       = aws_iam_role.ec2_role_one.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

# Create an instance profile for the role
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2InstanceProfile"
  role = aws_iam_role.ec2_role_one.name
}

# Launch EC2 instance with user data and IAM instance profile
resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type  # User-defined instance type
  key_name               = "test_key"        # Ensure this key pair exists in your AWS account
  security_groups        = [aws_security_group.allow_ssh_port.name]
  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<-EOF
              #!/bin/bash
              
              # Update and upgrade the system
              sudo apt update -y && sudo apt upgrade -y

              # Create a new user (e.g., 'ec2user') with a home directory
              useradd -m ec2user

              # Set a password for the new user (change 'YourSecurePassword' to your desired password)
              echo "ec2user:User1Password" | chpasswd

              # Create an SSH directory for the new user and set permissions
              mkdir -p /home/ec2user/.ssh
              chmod 700 /home/ec2user/.ssh

              # Add your SSH public key (replace with your actual key)
              echo "MIIEpAIBAAKCAQEA3l7NPtSeor1pPD7DyTNGTL4M1boduc8pDXUe+TaPeQwBI04K
              iFLXxIbP4BAx82JLNCbMgGyhbrSS3gNc0TUUczTp25vP1qDSWMba3QUPQsu3MgVU
              NxENA9FDqfoOy3VZuiiv9oF2ebNAwTEe+/2oyDEsLla/daS2yxLNWW+lHyaWM63T
              WCCgtXd987wVu0juq2h/c0LGwdq+dDlhjjcZQnJVK9HoI8JOU7naTTH3MKpWWJCE
              ERPh7HCijjU9rUQooFv4ybg0s94MJkH06qIzUv4tKl7ygV0Ut3LgHrG0ETqXwkJ1
              lp3FbqXvN+vCf+sSUYEgldYv8ul/OckrtKzstQIDAQABAoIBAGtPAGjTngIWuZPz
              DfQoJEKga/0vpWynRb5SyLGm3LGjU2FAJeEHaUxTajlMV26F/piaKJHI2lZcGYu9
              v6rNnKLD5B6wICoIzbk9rRx/do/bUvp2i99PASLYd3itTTpt1PD69X9VlmDAWf1g
              wP0Fuc9xu0pZXmddJ0D0P9hrAhn3VHC7+TomnH7SIaSL08xn8rpaALdNGnWreSuA
              o9CCNtZiSK4G4tDL4CKk+DumXA5xfuRHcT48fkQG6S7RyMPSQWWx0/3PiebTNSy9
              sfKEufct/uTW7Pl6jod9KfCqUteQMrK4oadd4Jc9IuCoSSfXbo5snsUvox6LRFSC
              cOxld/kCgYEA+rnYNOelWZ7NrF57D8uxlXqdvgLuFzvW8k3oHi1dsLwMIEG+cTxU
              LyRqkBgnzKKftgL+xB7vL0LVTswURbUAkpXMooDxfVX1JISm6Hxc1Vz/MDb+De9e
              ey1o5OMaiZyMffv09C1zoA31M2IZAVchSOYDrxUPKqfW3hr01hs6s4MCgYEA4wxD
              NDiQuSFDIHONZq5FEM5jWLNCKsgqHEtokKPfUpmXL8elJPTxS6Lb/9haB61CB/q6
              nX9x5nKWFpkAF3oocXAWtrnxT/rGNhnNsvOE10zBHMF39semPS3sw7SFknjt7sCg
              Mmx0cErWTtW/xB705TvuymIk5kHPNd5j31zhEWcCgYAK3HggOpSwIC/6spEUKxfD
              SO+CZrAXs5DpKDTQ8dgoKs0/rHlqgFmJPUOcgF9g/v56LQEKT+i+nF+PLUoHhwLC
              VtjphTpw2oNnFJQCaDjBSWkIlqlEw0TNgzcTCz+ADJcNche3aCylF1Wy5yH8K+EW
              PliUgg4JJAIr1vEaQU22rwKBgQC6dlGiy2mfgH+eYQeZcjlqSfUw3VbTx7s9rXhc
              gRhgv554MN+hcD/SPBetD8MwVsvJvdIQkp+6ABTezhxTK5GXR9R/kElrw6mQuLRD
              6NYJ8xENSp3435HY4KR3PQQNfJ762ts1Tfh6WBuUdtqceEfrEsNTFjLznsxLky42
              PBLitQKBgQCoSM2NafuB2i+pTL1/IFKOmWrQoS/FXa/6h+U1Qy7eP/y3u3CiKywe
              HXa6iSKbUtIzNwJJ29MrqbDvNBWnc1GkGyTCshmJbT14f5C64XgzcYStcDG1WeMZ
              OK4dStCLBOu64t4Z7cHpQ3fN+ve+1ZeqQZK89SCRFmitwfgEl1RnvQ==" > /home/ec2user/.ssh/authorized_keys
              chmod 600 /home/ec2user/.ssh/authorized_keys
              chown -R ec2user:ec2user /home/ec2user/.ssh

              # Disable root login over SSH
              sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
              systemctl restart sshd
              # Install Node.js and npm
              curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
              sudo apt install -y nodejs

              # Verify installations
              node -v
              npm -v
              EOF

  tags = {
    Name = "WebServer"
  }
}
