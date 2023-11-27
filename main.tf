// Say Terraform to store its state in an S3 bucket (luxoft-academy-adm022-tfstate) in the us-east-1 region. 
// The state file is essential for maintaining the state of your infrastructure.
terraform {
  backend "s3" {
    bucket = "luxoft-academy-adm022-tfstate"
    key    = "anton-pegov"
    region = "us-east-1"
  }
}

// Define the provider.
provider "aws" {
  region = "eu-west-1"
}

// Define the constants.
locals {
  tag = "anton-pegov"
}

// Define the IAM role for EC2.
// This role is assumed by EC2 instances and allows them to communicate with AWS Systems Manager (SSM).
resource "aws_iam_role" "this" {
  name               = "${local.tag}-instance"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

// Attach the "AmazonSSMManagedInstanceCore" policy to the created role.
// This role is assumed by EC2 instances and allows them to communicate with AWS Systems Manager (SSM).
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

//  Create an IAM instance profile and associates it with the previously defined IAM role.
resource "aws_iam_instance_profile" "this" {
  name = local.tag
  role = aws_iam_role.this.name
}

// Create the security group for the EC2 instance to controll http traffic.
// Allow incoming traffic on port 8000 and allows all outbound traffic.
// Allow incoming SSH traffic from any IP address (0.0.0.0/0)
resource "aws_security_group" "allow_http" {
  name        = "public_http_${local.tag}"
  description = "Allow HTTP public"
  vpc_id      = "vpc-01536fff4483278e3"

  ingress {
    description = "HTTP from VPC"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

// Ddd ssh keys straight from Terraform
resource "aws_key_pair" "this" {
  key_name   = "${local.tag}-instance-ssh-key"
  public_key = file("~/.ssh/aws_test.pub")	
}

// This resource creates an EC2 instance (aws_instance.this) using the specified Amazon Machine Image (AMI),
// instance type, subnet, IAM instance profile, security group, and other configurations.
resource "aws_instance" "this" {
  key_name                    = "${local.tag}-instance-ssh-key"
  ami                         = "ami-0cd9de031a6a1b509"
  instance_type               = "t3.micro"
  subnet_id                   = "subnet-070631c536dac3160"
  iam_instance_profile        = aws_iam_instance_profile.this.name
  vpc_security_group_ids      = [aws_security_group.allow_http.id]
  associate_public_ip_address = true

  tags = {
    "Name" = "${local.tag}-instance"
  }

  lifecycle {
    create_before_destroy = true
  }
}

// Create an Elastic IP address and associate it with the EC2 instance.
resource "aws_eip" "this" {
  instance = aws_instance.this.id
  vpc      = true
}