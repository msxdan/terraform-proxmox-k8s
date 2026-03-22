# GPU Time-Slicing — Share one GPU across multiple pods
#
# CUDA time-slicing allows multiple pods to share a single physical GPU.
# Each pod gets full access to GPU memory, but execution is interleaved.
#
# With replicas=4, one RTX 3060 Ti (8GB) appears as 4 nvidia.com/gpu resources.
#
# IMPORTANT: Time-slicing does NOT provide memory isolation.
# All pods share the full VRAM. If total usage exceeds GPU memory,
# all pods on that GPU may crash with OOM errors.
#
# Recommended replicas by GPU memory:
#   8 GB (RTX 3060 Ti) → 2-4 replicas
#  12 GB (RTX 4070 Ti) → 4-6 replicas
#  24 GB (RTX 4090)    → 4-8 replicas

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
    "gpu-worker-01" = {
      host_node     = "pve-02"
      machine_type  = "worker"
      ip            = "192.168.97.22"
      mac_address   = "BC:24:11:97:01:22"
      vm_id         = 4102
      cpu           = 4
      ram_dedicated = 8192
      talos_extensions = [
        "siderolabs/nonfree-kmod-nvidia-production",
        "siderolabs/nvidia-container-toolkit-production"
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

  nvidia_device_plugin = {
    enabled               = true
    version               = "0.18.2"
    time_slicing_replicas = 4
  }
}

# After apply, the node shows 4 nvidia.com/gpu resources:
#
#   kubectl describe node gpu-worker-01 | grep nvidia.com/gpu
#   # nvidia.com/gpu: 4
