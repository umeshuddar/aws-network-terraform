variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name, used in tags"
  type        = string
  default     = "lab"
}

variable "project_name" {
  description = "Short name used as a prefix on resource names"
  type        = string
  default     = "netlab"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "If true, deploy only 1 NAT Gateway (cheaper, less HA). If false, one per AZ."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "EC2 instance type for bastion and app instance"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "Name of an existing EC2 key pair to use for SSH access. Leave empty to skip SSH key assignment (e.g. if using SSM Session Manager only)."
  type        = string
  default     = ""
}

variable "bastion_allowed_cidr" {
  description = "CIDR allowed to SSH into the bastion host. Set this to YOUR_IP/32 — never leave as 0.0.0.0/0."
  type        = string
  default     = "0.0.0.0/0" # override in tfvars / CI with your actual IP
}

variable "enable_bastion" {
  description = "Whether to create the bastion + private app EC2 instances (set false to only build networking)"
  type        = bool
  default     = true
}
