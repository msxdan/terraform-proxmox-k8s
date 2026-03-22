# Full-Stack Cluster
#
# Complete example with all features:
#   - 3 control planes with VIP
#   - Standard workers + GPU worker with time-slicing
#   - External ARM64 node (Raspberry Pi)
#   - Cilium with L2 LoadBalancer + Gateway API
#   - Longhorn distributed storage (experimental)
#   - NVIDIA Device Plugin with GPU time-slicing
#   - Proxmox CSI Plugin for PVs

module "cluster" {
  source = "../../"

  talos_version      = "v1.12.5"
  kubernetes_version = "1.35.2"

  cluster = {
    name       = "production"
    endpoint   = "192.168.97.1"
    virtual_ip = "192.168.97.1"
  }

  talos_extensions = [
    "siderolabs/iscsi-tools",
    "siderolabs/util-linux-tools"
  ]

  nodes = {
    "master-01" = {
      host_node     = "pve-01"
      machine_type  = "controlplane"
      ip            = "192.168.97.10"
      mac_address   = "BC:24:11:97:00:10"
      vm_id         = 4000
      cpu           = 2
      ram_dedicated = 4096
      disk_size     = 40
      datastore_id  = "local-zfs"
    }
    "master-02" = {
      host_node     = "pve-01"
      machine_type  = "controlplane"
      ip            = "192.168.97.11"
      mac_address   = "BC:24:11:97:00:11"
      vm_id         = 4001
      cpu           = 2
      ram_dedicated = 4096
      disk_size     = 40
    }
    "master-03" = {
      host_node     = "pve-01"
      machine_type  = "controlplane"
      ip            = "192.168.97.12"
      mac_address   = "BC:24:11:97:00:12"
      vm_id         = 4002
      cpu           = 2
      ram_dedicated = 4096
      disk_size     = 40
    }
    "worker-01" = {
      host_node     = "pve-01"
      machine_type  = "worker"
      ip            = "192.168.97.20"
      mac_address   = "BC:24:11:97:01:20"
      vm_id         = 4100
      cpu           = 4
      ram_dedicated = 8192
      disk_size     = 200
    }
    "worker-02" = {
      host_node     = "pve-01"
      machine_type  = "worker"
      ip            = "192.168.97.21"
      mac_address   = "BC:24:11:97:01:21"
      vm_id         = 4101
      cpu           = 4
      ram_dedicated = 8192
      disk_size     = 200
    }
    "gpu-worker-01" = {
      host_node     = "pve-02"
      machine_type  = "worker"
      ip            = "192.168.97.22"
      mac_address   = "BC:24:11:97:01:22"
      vm_id         = 4102
      cpu           = 8
      ram_dedicated = 16384
      disk_size     = 200
      talos_extensions = [
        "siderolabs/nonfree-kmod-nvidia-production",
        "siderolabs/nvidia-container-toolkit-production",
        "siderolabs/iscsi-tools",
        "siderolabs/util-linux-tools"
      ]
      config_patches = [<<-EOF
        machine:
          kernel:
            modules:
              - name: nvidia
              - name: nvidia_uvm
              - name: nvidia_drm
                parameters:
                  - modeset=1
          nodeLabels:
            nvidia.com/gpu.present: "true"
      EOF
      ]
      hostpci = [{
        device  = "hostpci0"
        mapping = "gpu-nvidia"
        pcie    = true
      }]
    }
  }

  external_nodes = {
    "rpi-01" = {
      ip   = "192.168.97.50"
      arch = "arm64"
      overlay = {
        name  = "rpi_5"
        image = "siderolabs/sbc-rpi_5"
      }
    }
  }
  external_talos_extensions = [
    "siderolabs/iscsi-tools",
    "siderolabs/util-linux-tools"
  ]

  cilium = {
    version = "1.19.1"
    l2 = {
      ip_pools = [{
        name  = "svc-lb-pool"
        start = "192.168.97.100"
        stop  = "192.168.97.199"
      }]
    }
  }

  cert_manager = {
    enabled = true
    version = "1.20.0"
  }

  longhorn = {
    enabled = true
    version = "1.11.0"
  }

  nvidia_device_plugin = {
    enabled               = true
    version               = "0.18.2"
    time_slicing_replicas = 4
  }

  proxmox_csi = {
    enabled      = true
    version      = "0.5.5"
    proxmox_url  = "https://pve-01.example.com:8006/api2/json"
    token_id     = "kubernetes-csi@pve!csi"
    token_secret = var.proxmox_csi_token_secret
    region       = "my-cluster"
    insecure     = true
    storage_classes = [
      {
        name    = "proxmox-zfs"
        storage = "local-zfs"
        ssd     = true
      },
      {
        name    = "proxmox-lvm"
        storage = "local-lvm"
        fstype  = "xfs"
      }
    ]
  }

  gateway_api = {
    enabled         = true
    version         = "1.4.0"
    enable_tlsroute = true
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

output "control_plane_ips" {
  value = module.cluster.control_plane_ips
}

output "worker_ips" {
  value = module.cluster.worker_ips
}

output "external_image_urls" {
  value = module.cluster.external_image_urls
}
