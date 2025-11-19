
locals {
  username = "cluster_admin"

  # Common node type definitions
  node_specs = {
    controlplane = {
      nodes        = var.controlplane_vm_nodes
      ip_config    = var.controlplane_vm_spec.ip_config
      start_offset = 34
    }
    worker = {
      nodes        = var.worker_vm_nodes
      # ip_config    = var.worker_vm_spec.ip_config
      ip_config = var.controlplane_vm_spec.ip_config # use the same network
      start_offset = 56
    }
  }

  # Generic function-like expression to build IP maps for any node type
  node_ip_maps = {
    for role, spec in local.node_specs :
    role => {
      for idx, node in spec.nodes : node => {
        ip_config = {
          ipv4 = {
            address = format(
              "%s/%s",
              cidrhost(spec.ip_config.ipv4.subnet, spec.start_offset + idx),
              split("/", spec.ip_config.ipv4.subnet)[1]
            )
            gateway = spec.ip_config.ipv4.gateway
          }
          ipv6 = {
            address = format(
              "%s/%s",
              cidrhost(spec.ip_config.ipv6.subnet, spec.start_offset + idx),
              split("/", spec.ip_config.ipv6.subnet)[1]
            )
            gateway = spec.ip_config.ipv6.gateway
          }
        }
      }
    }
  }

  # Expose the specific maps you need
  controlplane_node_ip_map = local.node_ip_maps.controlplane
  worker_node_ip_map       = local.node_ip_maps.worker

  # For compatibility with original code
  controlplane_vm_nodes = local.controlplane_node_ip_map
  worker_vm_nodes       = local.worker_node_ip_map
}



# scope is to have controlplane and workers deployed and inventory ready for ansible to configure for cluster
module "controlplane" {
  source = "git::https://github.com/Dialgatrainer02-lab/proxmox-vm.git"
  for_each = local.controlplane_vm_nodes

  proxmox_vm_cpu = {
    cores = var.controlplane_vm_spec.cores
  }
  proxmox_vm_metadata = {
    name        = each.key
    description = "controlplane managed by terraform"
    tags        = ["cluster", "terraform", "controlplane"]
    agent       = true
    node_name = var.controlplane_vm_spec.node_name
  }

  proxmox_vm_user_account = {
    username = local.username
  }

  # fixme disk limitation
  proxmox_vm_disks = [{
    datastore_id = var.controlplane_vm_spec.disk.datastore_id
    file_format  = "raw"
    interface    = "virtio0"
    size = var.controlplane_vm_spec.disk.size
  }]

  proxmox_vm_memory = {
    dedicated = var.controlplane_vm_spec.memory
  }
  proxmox_vm_network = {
    dns = {
      domain  = ".Home"
      servers = ["1.1.1.1", "1.0.0.1"]
    }
    ip_config = each.value.ip_config
  }
  proxmox_vm_boot_image = {
    url = "https://repo.almalinux.org/almalinux/10/cloud/x86_64_v2/images/AlmaLinux-10-GenericCloud-latest.x86_64_v2.qcow2"
  }

}




#
#
#
#                           WORKER nodes
#
#


module "worker" {
  source = "git::https://github.com/Dialgatrainer02-lab/proxmox-vm.git"
  for_each = local.worker_vm_nodes
# 
  proxmox_vm_cpu = {
    cores = var.worker_vm_spec.cores
  }
  proxmox_vm_metadata = {
    name        = each.key
    description = "worker managed by terraform"
    tags        = ["cluster", "terraform", "worker"]
    agent       = true
    node_name = var.worker_vm_spec.node_name
  }
# 
  proxmox_vm_user_account = {
    username = local.username
  }
# 
  # fixme disk limitation
  proxmox_vm_disks = [{
    datastore_id = var.worker_vm_spec.disk.datastore_id
    file_format  = "raw"
    interface    = "virtio0"
    size = var.worker_vm_spec.disk.size
  }]
# 
  proxmox_vm_memory = {
    dedicated = var.worker_vm_spec.memory
  }
  proxmox_vm_network = {
    dns = {
      domain  = ".Home"
      servers = ["1.1.1.1", "1.0.0.1"]
    }
    ip_config = each.value.ip_config
  }
  proxmox_vm_boot_image = {
    url = "https://repo.almalinux.org/almalinux/10/cloud/x86_64_v2/images/AlmaLinux-10-GenericCloud-latest.x86_64_v2.qcow2"
  }
}




locals {
  inventory = {
    controlplane = {
      hosts = {
        for controlplane in var.controlplane_vm_nodes: controlplane => {
          ansible_host = module.controlplane[controlplane].ip_config.ipv4[0]
          ansible_ssh_private_key_file = local_sensitive_file.controlplane_private_key[controlplane].filename
          ansible_user = local.username
          ipv6_address = [for addr in module.controlplane[controlplane].ip_config.ipv6 :
            addr if !can(regex("^(::|fc|fd|fe8|fe9|fea|feb|ff)", addr))][0]
        }
      }
    }
    worker = {
      hosts = {
        for worker in var.worker_vm_nodes: worker => {
          ansible_host = module.worker[worker].ip_config.ipv4[0]
          ansible_ssh_private_key_file = local_sensitive_file.worker_private_key[worker].filename
          ansible_user = local.username
          ipv6_address = [for addr in module.worker[worker].ip_config.ipv6 :
    addr if !can(regex("^(::|fc|fd|fe8|fe9|fea|feb|ff)", addr))][0]
        }
      }
    }
    all = {
      vars = {
        ansible_port = 22
      }
    }
  }
}

# eventually the cluster module
