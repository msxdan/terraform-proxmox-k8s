# GPU Passthrough with NVIDIA Device Plugin
#
# Adds a GPU worker node with PCI passthrough for an NVIDIA GPU.
# The NVIDIA Device Plugin exposes nvidia.com/gpu resources to Kubernetes.
#
# Prerequisites on the Proxmox host:
#   1. IOMMU enabled in BIOS (VT-d / AMD-Vi)
#   2. Kernel parameter: intel_iommu=on or amd_iommu=on
#   3. GPU driver blacklisted (nouveau, nvidia)
#   4. VFIO modules loaded (vfio, vfio_iommu_type1, vfio_pci)
#   5. Resource mapping created: Datacenter > Resource Mappings > PCI Devices

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
    "worker-01" = {
      host_node     = "pve-01"
      machine_type  = "worker"
      ip            = "192.168.97.20"
      mac_address   = "BC:24:11:97:01:20"
      vm_id         = 4100
      cpu           = 4
      ram_dedicated = 8192
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
    enabled = true
    version = "0.18.2"
  }
}

# Verify GPU access after apply:
#
#   kubectl describe node gpu-worker-01 | grep nvidia.com/gpu
#   # nvidia.com/gpu: 1
#
#   kubectl run nvidia-smi --rm -it --restart=Never \
#     --image=nvcr.io/nvidia/cuda:12.8.1-base-ubi8 \
#     --overrides='{"spec":{"runtimeClassName":"nvidia","containers":[{"name":"c","image":"nvcr.io/nvidia/cuda:12.8.1-base-ubi8","command":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":1}}}]}}' \
#     -- nvidia-smi
