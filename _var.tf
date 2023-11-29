// --------------------------------- Variables ---------------------------------
// The variables block is used to declare input variables.
// These variables act as parameters that can be provided when running Terraform
// commands or in a terraform.tfvars file. The purpose of input variables is to
// make your Terraform configuration more flexible and reusable.

variable "instance_type" {
  default = "t3.micro"
}

variable "tag" {
  default = "anton-pegov"
}

variable "region" {
  default = "us-west-1"
}

variable "ami" {
  default = "ami-0d5eff06f840b45e9"
}

variable "domain" {
  default = "adm022.luxoft.academy"
}