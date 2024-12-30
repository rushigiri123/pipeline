provider "aws" {
  region = "ap-south-1"
}

# Generate an SSH key pair
resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Create an AWS key pair resource
resource "aws_key_pair" "generated_key" {
  key_name   = "generated_key"
  public_key = tls_private_key.example.public_key_openssh
}

# Create a security group that allows inbound traffic on port 80 and 22
resource "aws_security_group" "allow_http_ssh_inbound" {
  name        = "allow_http_ssh_inbound"
  description = "Allow inbound traffic on port 80 and 22"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

  tags = {
    Name = "allow_http_ssh_inbound"
  }
}

# Create two EC2 instances and associate them with the security group
resource "aws_instance" "webserver" {
  count         = 2
  ami           = "ami-03c68e52484d7488f"  # Replace with a valid AMI ID for your region
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name
  vpc_security_group_ids = [aws_security_group.allow_http_ssh_inbound.id]

  tags = {
    Name = "webserver-instance-${count.index + 1}"
  }

  # Install required tools or dependencies (optional)
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install putty -y
              EOF
}

# Output the public IP addresses of the instances
output "instance_ips" {
  value = aws_instance.webserver.*.public_ip
}

# Output the private key for SSH access (PEM format)
output "private_key_pem" {
  value     = tls_private_key.example.private_key_pem
  sensitive = true
}

# Generate PuTTY-compatible PPK private key
resource "null_resource" "generate_ppk" {
  provisioner "local-exec" {
    command = <<-EOF
                echo "${tls_private_key.example.private_key_pem}" > private_key.pem
                puttygen private_key.pem -o private_key.ppk -O private
              EOF
  }
}

# Output the PuTTY-compatible PPK file location
output "putty_key_path" {
  value = "private_key.ppk"
  description = "Path to the generated PuTTY private key file."
}
