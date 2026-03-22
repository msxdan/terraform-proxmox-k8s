# Basic 3 control-plane + 2 worker cluster
#
# Minimal configuration for a production-ready Talos Kubernetes cluster
# on Proxmox VE with Cilium CNI, Metrics Server, and Cert Manager.

module "cluster" {
  source = "../../"

  talos_version      = "v1.12.5"
  kubernetes_version = "1.35.2"

  cluster = {
    name       = "homelab"
    endpoint   = "192.168.97.1"
    virtual_ip = "192.168.97.1"
  }

  nodes = {
    "master-01" = {
      host_node     = "pve-01"
      machine_type  = "controlplane"
      ip            = "192.168.97.10"
      mac_address   = "BC:24:11:97:00:10"
      vm_id         = 4000
      cpu           = 2
      ram_dedicated = 2048
      disk_size     = 20
    }
    "master-02" = {
      host_node     = "pve-01"
      machine_type  = "controlplane"
      ip            = "192.168.97.11"
      mac_address   = "BC:24:11:97:00:11"
      vm_id         = 4001
      cpu           = 2
      ram_dedicated = 2048
      disk_size     = 20
    }
    "master-03" = {
      host_node     = "pve-01"
      machine_type  = "controlplane"
      ip            = "192.168.97.12"
      mac_address   = "BC:24:11:97:00:12"
      vm_id         = 4002
      cpu           = 2
      ram_dedicated = 2048
      disk_size     = 20
    }
    "worker-01" = {
      host_node     = "pve-01"
      machine_type  = "worker"
      ip            = "192.168.97.20"
      mac_address   = "BC:24:11:97:01:20"
      vm_id         = 4100
      cpu           = 4
      ram_dedicated = 8192
    }
    "worker-02" = {
      host_node     = "pve-01"
      machine_type  = "worker"
      ip            = "192.168.97.21"
      mac_address   = "BC:24:11:97:01:21"
      vm_id         = 4101
      cpu           = 4
      ram_dedicated = 8192
    }
  }
}

output "kubeconfig" {
  value     = module.cluster.kubeconfig_raw
  sensitive = true
}

output "talosconfig" {
  value     = module.cluster.talosconfig_raw
  sensitive = true
}
