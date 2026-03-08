variable "do_token" {
  description = "DigitalOcean API Token"
  type        = string
  sensitive   = true
}

variable "ssh_key" {
    description = "SSH Key to access the droplet"
    type        = string
    sensitive   = true
}

variable "region" {
  default = "sgp1"
}

variable "droplet_name" {
  default = "todo-vps"
}