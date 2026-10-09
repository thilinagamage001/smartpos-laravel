variable "project" {
  description = "Project name"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID to launch EC2 into"
  type        = string
}

variable "sg_id" {
  description = "Security group ID to attach to EC2"
  type        = string
}

variable "key_name" {
  description = "EC2 key pair name for SSH access"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type (t3.micro is AWS Free Tier eligible)"
  type        = string
  default     = "t3.micro"
}

variable "instance_profile" {
  description = "IAM instance profile name to attach"
  type        = string
}

variable "db_host" {
  description = "RDS PostgreSQL endpoint hostname"
  type        = string
}

variable "db_username" {
  description = "RDS PostgreSQL master username"
  type        = string
}

variable "db_password" {
  description = "RDS PostgreSQL master password"
  type        = string
  sensitive   = true
}

variable "git_repo_url" {
  description = "Git repository URL to clone on first boot"
  type        = string
  default     = "https://github.com/thilinagamage001/smartpos-laravel.git"
}

variable "git_branch" {
  description = "Git branch to clone on first boot"
  type        = string
  default     = "develop"
}
