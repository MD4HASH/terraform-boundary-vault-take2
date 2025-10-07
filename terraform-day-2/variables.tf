variable "boundary_auth_method_login_name" {
  description = "Initial admin username for Boundary"
  type        = string
  default     = "admin"
}

variable "boundary_auth_method_password" {
  description = "Password for the initial admin user"
  type        = string
  sensitive   = true
  default     = "astKxaWhH3XOZAWxSsry"
}

variable "boundary_auth_method_id" {
  description = "Auth Method ID for password login (from init output)"
  type        = string
  default     = "ampw_6U1pdagwiO"
}


variable "aws_region" {
  default = "us-east-1"
}
