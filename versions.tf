terraform {
  required_version = "~> 1.10.6"
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.88.0"
    }
  }
}
