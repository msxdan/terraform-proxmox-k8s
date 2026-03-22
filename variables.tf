variable "talos_version" {
  description = "Talos OS version"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
}

variable "talos_extensions" {
  description = "Additional Talos system extensions (qemu-guest-agent is always included for Proxmox nodes)"
  type        = list(string)
  default     = []
}

variable "kernel_args" {
  description = "Extra kernel arguments"
  type        = list(string)
  default     = ["net.ifnames=0"]
}

variable "cluster" {
  description = "Cluster configuration"
  type = object({
    name                               = string
    endpoint                           = string
    virtual_ip                         = optional(string)
    allow_scheduling_on_control_planes = optional(bool, false)
  })
}

variable "nodes" {
  description = "Cluster nodes configuration"
  type = map(object({
    host_node        = string
    machine_type     = string
    ip               = string
    mac_address      = string
    vm_id            = number
    cpu              = number
    ram_dedicated    = number
    disk_size        = optional(number, 100)
    datastore_id     = optional(string, "local-zfs")
    update           = optional(bool, false)
    talos_extensions = optional(list(string))
    config_patches   = optional(list(string), [])
    hostpci = optional(list(object({
      device  = string
      mapping = optional(string)
      id      = optional(string)
      pcie    = optional(bool, true)
      rombar  = optional(bool, true)
    })), [])
  }))
}

variable "gateway_api" {
  description = "Gateway API CRDs configuration"
  type = object({
    enabled         = optional(bool, false)
    version         = optional(string, "1.4.0")
    enable_tlsroute = optional(bool, false)
  })
  default = {}
}

variable "extra_manifests" {
  description = "URLs to additional manifests applied via Talos extraManifests on control planes"
  type        = list(string)
  default     = []
}

# --- Component versions ---

variable "cilium" {
  description = "Cilium CNI configuration"
  type = object({
    version = optional(string, "1.19.1")
    values  = optional(list(string), [])
    l2 = optional(object({
      enabled = optional(bool, true)
      ip_pools = list(object({
        name  = optional(string, "default-pool")
        start = string
        stop  = string
      }))
      interfaces    = optional(list(string), ["^eth", "^en"])
      node_selector = optional(map(string), {})
    }))
  })
  default = {}
}

variable "metrics_server" {
  description = "Metrics Server configuration"
  type = object({
    enabled = optional(bool, true)
    version = optional(string, "3.13.0")
    values  = optional(list(string), [])
  })
  default = {}
}

variable "cert_manager" {
  description = "Cert Manager configuration"
  type = object({
    enabled                          = optional(bool, true)
    version                          = optional(string, "1.20.0")
    replicas                         = optional(number, 1)
    dns01_recursive_nameservers      = optional(list(string), [])
    dns01_recursive_nameservers_only = optional(bool, true)
    values                           = optional(list(string), [])
  })
  default = {}
}

variable "longhorn" {
  description = "Longhorn distributed storage configuration (EXPERIMENTAL — not validated in production)"
  type = object({
    enabled               = optional(bool, false)
    version               = optional(string, "1.11.0")
    default_replica_count = optional(number, 2)
    values                = optional(list(string), [])
  })
  default = {}
}

variable "nvidia_device_plugin" {
  description = "NVIDIA Device Plugin for GPU workloads (exposes nvidia.com/gpu resources)"
  type = object({
    enabled               = optional(bool, false)
    version               = optional(string, "0.18.2")
    values                = optional(list(string), [])
    time_slicing_replicas = optional(number, 0)
    rename_by_default     = optional(bool, false)
  })
  default = {}
}

variable "proxmox_csi" {
  description = "Proxmox CSI Plugin — creates PVs backed by Proxmox storage (LVM, ZFS, Ceph)"
  type = object({
    enabled      = optional(bool, false)
    version      = optional(string, "0.5.5")
    values       = optional(list(string), [])
    proxmox_url  = optional(string)
    token_id     = optional(string)
    token_secret = optional(string)
    region       = optional(string)
    insecure     = optional(bool, false)
    storage_classes = optional(list(object({
      name           = string
      storage        = string
      reclaim_policy = optional(string, "Delete")
      fstype         = optional(string, "ext4")
      cache          = optional(string, "none")
      ssd            = optional(bool, false)
    })), [])
  })
  default = {}
}

# --- External Nodes ---

variable "external_nodes" {
  description = "External bare-metal nodes not managed by Proxmox (e.g., Raspberry Pi)"
  type = map(object({
    machine_type     = optional(string, "worker")
    ip               = string
    arch             = optional(string, "arm64")
    platform         = optional(string, "metal")
    kernel_args      = optional(list(string), ["net.ifnames=0"])
    update           = optional(bool, false)
    talos_extensions = optional(list(string))
    config_patches   = optional(list(string), [])
    overlay = optional(object({
      name  = string
      image = string
    }))
  }))
  default = {}
}

variable "external_talos_extensions" {
  description = "Default Talos system extensions for external nodes (no qemu-guest-agent needed for bare metal)"
  type        = list(string)
  default     = []
}

# --- Upgrades ---

variable "talos_version_target" {
  description = "Target Talos version for rolling upgrade. Set only during upgrades, null otherwise."
  type        = string
  default     = null
}
