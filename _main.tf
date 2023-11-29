// --------------------------------- Providers -------------------------------
// Say Terraform to store its state in an S3 bucket in the us-east-1 region. 
// The state file is essential for maintaining the state of your infrastructure.
terraform {
  backend "s3" {
    bucket = "luxoft-academy-adm022-tfstate"
    key    = "anton-pegov"
    region = "us-east-1"
  }

  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">=1.12.0"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

// --------------------------------- Locals ---------------------------------
// The locals block is used to define values that are calculated or derived
// within your Terraform configuration. These values are not meant to be
// inputs from users or external sources; instead, they are computed within
// the configuration to make it more readable and to avoid repeating expressions.

locals {
  host_name = "${var.tag}.${var.domain}"
  compose = base64encode(templatefile("${path.module}/compose.yaml.tmpl", {
    region        = data.aws_region.current.name
    django_secret = random_id.secret.hex
    password      = random_password.password.result
    port          = var.port
    image         = var.image
    }
  ))
}

// ----------------------------------- Data -----------------------------------
// A data source is a way to fetch and use data in your Terraform configuration that is
// not managed by Terraform itself. It allows you to retrieve information from an external
// source and use it in your Terraform configuration. Data sources are read-only, meaning
// Terraform uses them to query information but doesn't modify the external system.

data "aws_ssm_parameter" "ami" {
  name = "/adm022/ami"
}

data "aws_ssm_parameter" "private_subnets" {
  name = "/adm022/private_subnet_ids"
}

data "aws_ssm_parameter" "vpc_id" {
  name = "/adm022/vpc_id"
}

data "aws_ssm_parameter" "listener_arn" {
  name = "/adm022/listener_arn"
}

data "aws_region" "current" {}

// --------------------------------- Resources ---------------------------------
// The resource block in Terraform is used to define and provision infrastructure
// resources. It is one of the fundamental building blocks in Terraform configurations
// and represents a resource that Terraform should manage. Resources can be physical
// components like virtual machines, databases, or network interfaces, as well as
// logical components like DNS records or configuration settings.

// Define the IAM role for EC2. This role is assumed by EC2 instances and allow
// them to communicate with AWS Systems Manager (SSM).
resource "aws_iam_role" "this" {
  name               = "${var.tag}-instance"
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

// Attach the "AmazonSSMManagedInstanceCore" policy to the created role. This role is 
// assumed by EC2 instances and allows them to communicate with AWS Systems Manager (SSM).
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

// Attach the "EC2InstanceProfileForImageBuilderECRContainerBuilds" policy to the created role.
// This policy allows EC2 instances to push and pull images from Amazon Elastic Container Registry (ECR).
resource "aws_iam_role_policy_attachment" "ecr" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
}

//  Create an IAM instance profile and associates it with the previously defined IAM role.
resource "aws_iam_instance_profile" "this" {
  name = var.tag
  role = aws_iam_role.this.name
}

// Create the security group for the EC2 instance to controll http traffic.
// Allow incoming traffic on port 8000 and allows all outbound traffic.
// Allow incoming SSH traffic from any IP address (0.0.0.0/0)
resource "aws_security_group" "allow_http" {
  name        = "public_http_${var.tag}"
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
  key_name   = "${var.tag}-instance-ssh-key"
  public_key = file("~/.ssh/aws_test.pub")
}

resource "random_id" "secret" {
  byte_length = 50
}

resource "random_password" "password" {
  length  = 16
  special = false
}

// This resource creates an EC2 instance (aws_instance.this) using the specified Amazon Machine Image (AMI),
// instance type, subnet, IAM instance profile, security group, and other configurations.
resource "aws_instance" "this" {
  key_name               = "${var.tag}-instance-ssh-key"
  ami                    = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  subnet_id              = split(",", data.aws_ssm_parameter.private_subnets.value)[0]
  iam_instance_profile   = aws_iam_instance_profile.this.name
  vpc_security_group_ids = [aws_security_group.allow_http.id]
  # associate_public_ip_address = true

  tags = {
    "Name" = var.tag
  }

  lifecycle {
    create_before_destroy = true
  }

  user_data = <<-EOF
    #cloud-config
    fqdn: ${var.tag}
    write_files:
      - path: /home/ec2-user/docker-compose.yaml
        encoding: b64
        content: '${local.compose}'
    runcmd:
      - eval $(aws ecr get-login --no-include-email --region ${data.aws_region.current.name})
      - sudo docker-compose -f /home/ec2-user/docker-compose.yaml up -d

  EOF
}

// Create an Elastic IP address and associate it with the EC2 instance.
resource "aws_eip" "this" {
  instance = aws_instance.this.id
  vpc      = true
}

// Create a target group for the load balancer.
resource "aws_lb_target_group" "this" {
  name     = var.tag
  port     = var.port
  protocol = "HTTP"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value
}

// Attach the EC2 instance to the target group.
resource "aws_lb_target_group_attachment" "this" {
  target_group_arn = aws_lb_target_group.this.arn
  target_id        = aws_instance.this.id
  port             = var.port
}

// Create a load balancer listener rule that forwards requests to the target group.
resource "aws_lb_listener_rule" "this" {
  listener_arn = data.aws_ssm_parameter.listener_arn.value

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    host_header {
      values = [local.host_name]
    }
  }
}

// --------------------------------- Outputs ---------------------------------

output "public_ip" {
  description = "The public IP address of the EC2 instance"
  value       = aws_eip.this.public_ip
}

output "instance_id" {
  description = "The ID of the EC2 instance"
  value       = aws_instance.this.id
}

// Call 'terraform output password' to see the value of this output
output "password" {
  description = "The password for the Django admin user"
  value       = random_password.password.result
  sensitive   = true
}

output "ami" {
  description = "The AMI used for the EC2 instance"
  value       = data.aws_ssm_parameter.ami.value
  sensitive   = true
}
