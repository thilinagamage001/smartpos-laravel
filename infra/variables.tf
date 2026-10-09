variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-southeast-1"
}

variable "project" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "smartpos"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "production"
}

variable "key_name" {
  description = "Name of the EC2 key pair to use for SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro is AWS Free Tier eligible - 750 hrs/month)"
  type        = string
  default     = "t3.micro"
}

variable "db_username" {
  description = "RDS PostgreSQL master username"
  type        = string
  default     = "smartpos_user"
}

variable "db_password" {
  description = "RDS PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "git_repo_url" {
  description = "Git repository URL for automated deployment"
  type        = string
  default     = "https://github.com/thilinagamage001/smartpos-laravel.git"
}

variable "git_branch" {
  description = "Git branch for automated deployment"
  type        = string
  default     = "develop"
}
