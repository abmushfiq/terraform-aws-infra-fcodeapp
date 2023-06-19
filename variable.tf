
variable "ecrRepoName" {
  type        = string
  description = "This is our aws ecr repo name (inside available node app docker image)"
  default     = "test-student-api-fcode"
}

variable "rds_username" {
  type        = string
  description = "This db default user name"
  default     = "postgres"
}

variable "database_master_password" {
  type        = string
  description = "This db password default value if you want set extranally in .tfvars files"
  default     = "postgres"
}

variable "acess" {
  type    = string
  default = ""
}

variable "sec" {
  type    = string
  default = ""
}
