
terraform {
  backend "s3" {
    bucket = "luxoft-academy-adm022-tfstate"
    key    = "anton-pegov"
    region = "us-east-1"
  }
}

// Define the provider
provider "aws" {
  region = "eu-west-1"
}

// Define the tag
locals {
  tag = "anton-pegov"
}

// Define the IAM role for EC2
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

// Attach the policy to the role
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

// Create the IAM instance profile
resource "aws_iam_instance_profile" "this" {
  name = local.tag
  role = aws_iam_role.this.name
}

// Create the security group for the EC2 instance to controll http access
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

// Create the EC2 instance
resource "aws_instance" "this" {
  ami                         = "ami-007217baf201fea8a"
  instance_type               = "t3.micro"
  subnet_id                   = "subnet-070631c536dac3160"
  iam_instance_profile        = aws_iam_instance_profile.this.name
  vpc_security_group_ids      = [aws_security_group.allow_http.id]
  associate_public_ip_address = true

  tags = {
    "Name" = local.tag
  }

}