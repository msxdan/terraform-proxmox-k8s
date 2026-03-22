# External Bare-Metal Nodes (e.g., Raspberry Pi)
#
# Adds bare-metal nodes that are NOT managed by Proxmox.
# These nodes join the cluster as workers via Talos machine config.
#
# Workflow:
#   1. Add external_nodes to your config
#   2. Run `tofu plan` — the external_image_urls output shows download links
#   3. Flash the raw image to the node (SD card, USB, etc.) — NOT ISO for SBCs!
#   4. Boot the node
#   5. Run `tofu apply` — the module pushes machine config and joins the cluster

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
  }

  external_nodes = {
    "rpi5-01" = {
      ip   = "192.168.97.50"
      arch = "arm64"
      overlay = {
        name  = "rpi_5"
        image = "siderolabs/sbc-rpi_5"
      }
    }
    "rpi5-02" = {
      ip   = "192.168.97.52"
      arch = "arm64"
      overlay = {
        name  = "rpi_5"
        image = "siderolabs/sbc-rpi_5"
      }
      talos_extensions = [
        "siderolabs/iscsi-tools",
        "siderolabs/util-linux-tools",
        "siderolabs/nfs-utils"
      ]
      config_patches = [<<-EOF
        machine:
          nodeLabels:
            node.kubernetes.io/arch: arm64
            role: storage
          kubelet:
            extraConfig:
              registerWithTaints:
                - key: arch
                  value: arm64
                  effect: NoSchedule
      EOF
      ]
    }
  }

  external_talos_extensions = [
    "siderolabs/iscsi-tools",
    "siderolabs/util-linux-tools"
  ]
}

output "external_image_urls" {
  description = "Download URLs for external node images (ISO, raw.xz, raw.zst)"
  value       = module.cluster.external_image_urls
}

# Flash example (SBCs — use raw, NOT ISO):
#   wget <raw_xz_url> -O talos-rpi5.raw.xz
#   xz -d talos-rpi5.raw.xz
#   sudo dd if=talos-rpi5.raw of=/dev/sdX bs=4M status=progress
