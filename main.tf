
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





#######################################################3

#template

#############################

module "template" {
  source = "git::https://github.com/Dialgatrainer02-lab/proxmox-vm.git"
# 
  proxmox_vm_cpu = {
    cores = var.worker_vm_spec.cores
  }
  proxmox_vm_metadata = {
    name        = "k8-base"
    description = "worker managed by terraform"
    tags        = ["cluster", "terraform", "template"]
    agent       = true
    node_name = var.worker_vm_spec.node_name
    vm_id = 901
    template = true
    started = false
  }
# 
  proxmox_vm_user_account = {
    username = local.username
  }
# 
  # fixme disk limitation
  proxmox_vm_disks = []
  proxmox_vm_memory = {
    dedicated = var.worker_vm_spec.memory
  }
  proxmox_vm_network = {
    dns = {
      domain  = ".Home"
      servers = ["1.1.1.1", "1.0.0.1"]
    }
    ip_config = {
      ipv4 = {
        address = "dhcp"
        gateway = "null"
      }
      ipv6 = {
        address = "dhcp"
        gateway = "null"
      }
    }
  }
  proxmox_vm_boot_image = {
    url = "https://repo.almalinux.org/almalinux/10/cloud/x86_64_v2/images/AlmaLinux-10-GenericCloud-latest.x86_64_v2.qcow2"
  }
}

# scope is to have controlplane and workers deployed and inventory ready for ansible to configure for cluster
module "controlplane" {
  source = "git::https://github.com/Dialgatrainer02-lab/proxmox-vm.git"
  for_each = local.controlplane_vm_nodes

  proxmox_vm_cpu = {
    cores = var.controlplane_vm_spec.cores
  }

  proxmox_vm_clone = {
    node_name = module.template.node_name
    vm_id = module.template.proxmox_vm.vm_id
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
  proxmox_vm_boot_image = null

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

  proxmox_vm_clone = {
    node_name = module.template.node_name
    vm_id = module.template.proxmox_vm.vm_id
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
  proxmox_vm_boot_image = null
}


