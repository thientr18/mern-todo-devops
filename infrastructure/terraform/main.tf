terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_droplet" "vps" {
  name   = var.droplet_name
  region = var.region
  size   = "s-2vcpu-4gb"
  image  = "ubuntu-24-04-x64"

  ssh_keys = [var.ssh_key]
}

output "droplet_ip" {
  value = digitalocean_droplet.vps.ipv4_address
}