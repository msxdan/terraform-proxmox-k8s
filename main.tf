# --- Image ---

locals {
  factory_url = "https://factory.talos.dev"
  arch        = "amd64"
  platform    = "nocloud"

  # Talos 1.12+ uses HostnameConfig document instead of machine.network.hostname
  talos_minor             = tonumber(regex("v?1\\.(\\d+)", var.talos_version)[0])
  use_hostname_config_doc = local.talos_minor >= 12

  # Always include qemu-guest-agent for Proxmox VMs
  proxmox_extensions = distinct(concat(["siderolabs/qemu-guest-agent"], var.talos_extensions))

  # Gateway API manifests (auto-generated from gateway_api variable)
  gateway_api_manifests = var.gateway_api.enabled ? concat(
    ["https://github.com/kubernetes-sigs/gateway-api/releases/download/v${var.gateway_api.version}/standard-install.yaml"],
    var.gateway_api.enable_tlsroute ? [
      "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api.version}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml"
    ] : []
  ) : []
  all_extra_manifests = concat(local.gateway_api_manifests, var.extra_manifests)

  # NVIDIA RuntimeClass (required for nvidia-device-plugin runtimeClassName: nvidia)
  nvidia_runtime_class_patch = var.nvidia_device_plugin.enabled ? [yamlencode({
    cluster = {
      inlineManifests = [{
        name = "nvidia-runtime-class"
        contents = yamlencode({
          apiVersion = "node.k8s.io/v1"
          kind       = "RuntimeClass"
          metadata   = { name = "nvidia" }
          handler    = "nvidia"
        })
      }]
    }
  })] : []

  # Proxmox CSI namespace with privileged PodSecurity (CSI node plugin needs hostPath, SYS_ADMIN, /dev)
  proxmox_csi_namespace_patch = var.proxmox_csi.enabled ? [yamlencode({
    cluster = {
      inlineManifests = [{
        name = "csi-proxmox-namespace"
        contents = yamlencode({
          apiVersion = "v1"
          kind       = "Namespace"
          metadata = {
            name = "csi-proxmox"
            labels = {
              "pod-security.kubernetes.io/enforce" = "privileged"
            }
          }
        })
      }]
    }
  })] : []

  # Cilium L2 LoadBalancer IP Pool + L2 Announcement Policy
  cilium_l2_patch = var.cilium.l2 != null ? (var.cilium.l2.enabled ? [yamlencode({
    cluster = {
      inlineManifests = concat(
        [for pool in var.cilium.l2.ip_pools : {
          name = "cilium-lb-pool-${pool.name}"
          contents = yamlencode({
            apiVersion = "cilium.io/v2alpha1"
            kind       = "CiliumLoadBalancerIPPool"
            metadata = {
              name      = pool.name
              namespace = "kube-system"
            }
            spec = {
              blocks = [{
                start = pool.start
                stop  = pool.stop
              }]
            }
          })
        }],
        [{
          name = "cilium-l2-announcement-policy"
          contents = yamlencode({
            apiVersion = "cilium.io/v2alpha1"
            kind       = "CiliumL2AnnouncementPolicy"
            metadata = {
              name      = "l2policy"
              namespace = "kube-system"
            }
            spec = {
              nodeSelector = {
                matchExpressions = [{
                  key      = "kubernetes.io/os"
                  operator = "In"
                  values   = ["linux"]
                }]
                matchLabels = var.cilium.l2.node_selector
              }
              interfaces      = var.cilium.l2.interfaces
              externalIPs     = true
              loadBalancerIPs = true
            }
          })
        }]
      )
    }
  })] : []) : []

  # Proxmox CSI topology labels (region = cluster name, zone = Proxmox node)
  # Applied automatically to each node when proxmox_csi is enabled
  proxmox_csi_topology_patch = {
    for k, v in var.nodes : k => var.proxmox_csi.enabled ? [yamlencode({
      machine = {
        nodeLabels = {
          "topology.kubernetes.io/region" = var.proxmox_csi.region
          "topology.kubernetes.io/zone"   = v.host_node
        }
      }
    })] : []
  }

  # --- Per-node extension support ---

  # Effective extensions per node (node override or global, always with qemu-guest-agent)
  node_extensions = {
    for k, v in var.nodes : k => sort(distinct(concat(
      ["siderolabs/qemu-guest-agent"],
      v.talos_extensions != null ? v.talos_extensions : var.talos_extensions
    )))
  }

  # Extension profile key per node (hash for deduplication)
  node_ext_key = {
    for k, exts in local.node_extensions : k => substr(sha1(jsonencode(exts)), 0, 8)
  }

  # Nodes with custom extensions (different from the default set)
  default_ext_key   = substr(sha1(jsonencode(sort(local.proxmox_extensions))), 0, 8)
  nodes_with_custom = { for k, v in var.nodes : k => v if local.node_ext_key[k] != local.default_ext_key }
  custom_ext_keys   = { for k, _ in local.nodes_with_custom : k => local.node_ext_key[k] }

  # Unique custom extension profiles (deduplicated by hash)
  custom_ext_groups = { for k, key in local.custom_ext_keys : key => k... }
  custom_ext_profiles = {
    for key, nodes in local.custom_ext_groups : key => local.node_extensions[nodes[0]]
  }

  # Custom schematic IDs (from data source, available during plan)
  custom_schematic_ids = {
    for key, _ in local.custom_ext_profiles : key => jsondecode(data.http.custom_schematic_id[key].response_body)["id"]
  }

  # Default schematic ID
  schematic_id = jsondecode(data.http.schematic_id.response_body)["id"]

  # Per-node schematic ID (resource-based, for machine configs and upgrades)
  node_schematic_id = {
    for k, v in var.nodes : k => (
      local.node_ext_key[k] != local.default_ext_key
      ? talos_image_factory_schematic.custom[local.custom_ext_keys[k]].id
      : talos_image_factory_schematic.this.id
    )
  }

  # Custom ISO downloads (unique host_node + ext_key pairs)
  custom_iso_raw = {
    for k, v in local.nodes_with_custom : "${v.host_node}_${local.custom_ext_keys[k]}" => {
      host_node = v.host_node
      ext_key   = local.custom_ext_keys[k]
    }...
  }
  custom_iso_entries = {
    for key, entries in local.custom_iso_raw : key => entries[0]
  }
}

# --- Default schematic (nodes without custom extensions) ---

resource "talos_image_factory_schematic" "this" {
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = local.proxmox_extensions
      }
    }
  })
}

data "http" "schematic_id" {
  url    = "${local.factory_url}/schematics"
  method = "POST"
  request_body = templatefile("${path.module}/templates/schematic.tftpl", {
    extensions = local.proxmox_extensions
  })
}

resource "proxmox_virtual_environment_download_file" "talos_iso" {
  for_each = toset(distinct([for k, v in var.nodes : v.host_node if local.node_ext_key[k] == local.default_ext_key]))

  node_name           = each.key
  content_type        = "iso"
  datastore_id        = "local"
  overwrite           = true
  overwrite_unmanaged = true
  verify              = true
  upload_timeout      = 600

  url       = "${local.factory_url}/image/${local.schematic_id}/${var.talos_version}/${local.platform}-${local.arch}.iso"
  file_name = "talos-${local.schematic_id}-${var.talos_version}-${local.platform}-${local.arch}.img"
}

# --- Custom extension schematics (nodes with per-node overrides) ---

resource "talos_image_factory_schematic" "custom" {
  for_each = local.custom_ext_profiles
  schematic = yamlencode({
    customization = {
      systemExtensions = {
        officialExtensions = each.value
      }
    }
  })
}

data "http" "custom_schematic_id" {
  for_each = local.custom_ext_profiles
  url      = "${local.factory_url}/schematics"
  method   = "POST"
  request_body = templatefile("${path.module}/templates/schematic.tftpl", {
    extensions = each.value
  })
}

resource "proxmox_virtual_environment_download_file" "custom_talos_iso" {
  for_each = local.custom_iso_entries

  node_name           = each.value.host_node
  content_type        = "iso"
  datastore_id        = "local"
  overwrite           = true
  overwrite_unmanaged = true
  verify              = true
  upload_timeout      = 600

  url       = "${local.factory_url}/image/${local.custom_schematic_ids[each.value.ext_key]}/${var.talos_version}/${local.platform}-${local.arch}.iso"
  file_name = "talos-${local.custom_schematic_ids[each.value.ext_key]}-${var.talos_version}-${local.platform}-${local.arch}.img"
}

# --- VMs ---

resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.nodes

  node_name = each.value.host_node
  name      = each.key
  tags      = each.value.machine_type == "controlplane" ? ["k8s", "control-plane"] : ["k8s", "worker"]
  on_boot   = true
  vm_id     = each.value.vm_id

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "seabios"

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.ram_dedicated
  }

  network_device {
    bridge      = "vmbr0"
    mac_address = each.value.mac_address
  }

  disk {
    datastore_id = each.value.datastore_id
    interface    = "scsi0"
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    file_format  = "raw"
    size         = each.value.disk_size
    file_id = (
      local.node_ext_key[each.key] != local.default_ext_key
      ? proxmox_virtual_environment_download_file.custom_talos_iso["${each.value.host_node}_${local.custom_ext_keys[each.key]}"].id
      : proxmox_virtual_environment_download_file.talos_iso[each.value.host_node].id
    )
  }

  dynamic "hostpci" {
    for_each = each.value.hostpci
    content {
      device  = hostpci.value.device
      mapping = hostpci.value.mapping
      id      = hostpci.value.id
      pcie    = hostpci.value.pcie
      rombar  = hostpci.value.rombar
    }
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = each.value.datastore_id
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  lifecycle {
    ignore_changes = [disk[0].file_id]
  }
}

# --- Talos Configuration ---

resource "talos_machine_secrets" "this" {
  talos_version = var.talos_version
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes = concat(
    [for k, v in var.nodes : v.ip],
    [for k, v in var.external_nodes : v.ip]
  )
  endpoints = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
}

data "talos_machine_configuration" "this" {
  for_each           = var.nodes
  cluster_name       = var.cluster.name
  cluster_endpoint   = "https://${var.cluster.endpoint}:6443"
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  machine_type       = each.value.machine_type
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    each.value.machine_type == "controlplane" ? [
      templatefile("${path.module}/templates/control-plane.yaml.tftpl", {
        hostname                           = local.use_hostname_config_doc ? "" : each.key
        virtual_ip                         = var.cluster.virtual_ip
        platform                           = local.platform
        talos_config                       = { image = { version = var.talos_version }, kernel_args = var.kernel_args }
        schematic_id                       = local.node_schematic_id[each.key]
        allow_scheduling_on_control_planes = var.cluster.allow_scheduling_on_control_planes
        extra_manifests                    = local.all_extra_manifests
      })
      ] : [
      templatefile("${path.module}/templates/worker.yaml.tftpl", {
        hostname     = local.use_hostname_config_doc ? "" : each.key
        platform     = local.platform
        talos_config = { image = { version = var.talos_version }, kernel_args = var.kernel_args }
        schematic_id = local.node_schematic_id[each.key]
      })
    ],
    # Talos 1.12+: hostname via HostnameConfig document (replaces deprecated machine.network.hostname)
    local.use_hostname_config_doc ? [yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = each.key
    })] : [],
    # NVIDIA RuntimeClass (controlplane only, creates the RuntimeClass K8s resource)
    each.value.machine_type == "controlplane" ? local.nvidia_runtime_class_patch : [],
    # Proxmox CSI namespace with privileged PodSecurity (controlplane only)
    each.value.machine_type == "controlplane" ? local.proxmox_csi_namespace_patch : [],
    # Cilium L2 LoadBalancer IP Pool + Announcement Policy (controlplane only)
    each.value.machine_type == "controlplane" ? local.cilium_l2_patch : [],
    # Proxmox CSI topology labels (region + zone per node)
    local.proxmox_csi_topology_patch[each.key],
    # Per-node config patches (Talos strategic merge patches)
    each.value.config_patches
  )
}

resource "talos_machine_configuration_apply" "this" {
  depends_on                  = [proxmox_virtual_environment_vm.this]
  for_each                    = var.nodes
  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  lifecycle {
    replace_triggered_by = [proxmox_virtual_environment_vm.this[each.key]]
  }
}

# --- Bootstrap ---

resource "time_sleep" "wait_for_vms" {
  depends_on      = [proxmox_virtual_environment_vm.this]
  create_duration = "60s"
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [
    time_sleep.wait_for_vms,
    talos_machine_configuration_apply.this
  ]
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  client_configuration = talos_machine_secrets.this.client_configuration
}

# --- Kubeconfig ---

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this
  ]
  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
}

# --- External Nodes (bare-metal, e.g. Raspberry Pi) ---

locals {
  has_external_nodes = length(var.external_nodes) > 0

  # Full profile per external node (extensions + overlay for deduplication)
  ext_node_profile = {
    for k, v in var.external_nodes : k => {
      extensions = sort(distinct(
        v.talos_extensions != null ? v.talos_extensions : var.external_talos_extensions
      ))
      overlay = v.overlay
    }
  }

  # Profile key per external node (hash of extensions + overlay for deduplication)
  ext_node_profile_key = {
    for k, profile in local.ext_node_profile : k => substr(sha1(jsonencode(profile)), 0, 8)
  }

  # Unique profiles across all external nodes
  ext_unique_profiles = {
    for key, nodes in { for k, key in local.ext_node_profile_key : key => k... } :
    key => local.ext_node_profile[nodes[0]]
  }

  # Per-node schematic ID for external nodes (resource — used in machine config)
  ext_node_schematic_id = {
    for k, v in var.external_nodes : k => (
      local.has_external_nodes
      ? talos_image_factory_schematic.external[local.ext_node_profile_key[k]].id
      : ""
    )
  }

  # Per-node schematic ID from data source (available during plan — used in outputs)
  ext_node_schematic_id_for_urls = {
    for k, v in var.external_nodes : k => (
      local.has_external_nodes
      ? jsondecode(data.http.external_schematic_id[local.ext_node_profile_key[k]].response_body).id
      : ""
    )
  }
}

resource "talos_image_factory_schematic" "external" {
  for_each = local.ext_unique_profiles
  schematic = yamlencode(merge(
    {
      customization = {
        systemExtensions = {
          officialExtensions = each.value.extensions
        }
      }
    },
    each.value.overlay != null ? {
      overlay = each.value.overlay
    } : {}
  ))
}

data "http" "external_schematic_id" {
  for_each = local.ext_unique_profiles
  url      = "${local.factory_url}/schematics"
  method   = "POST"
  request_body = jsonencode(merge(
    {
      customization = {
        systemExtensions = {
          officialExtensions = each.value.extensions
        }
      }
    },
    each.value.overlay != null ? {
      overlay = each.value.overlay
    } : {}
  ))
}

data "talos_machine_configuration" "external" {
  for_each           = var.external_nodes
  cluster_name       = var.cluster.name
  cluster_endpoint   = "https://${var.cluster.endpoint}:6443"
  talos_version      = var.talos_version
  kubernetes_version = var.kubernetes_version
  machine_type       = each.value.machine_type
  machine_secrets    = talos_machine_secrets.this.machine_secrets
  config_patches = concat(
    each.value.machine_type == "controlplane" ? [
      templatefile("${path.module}/templates/control-plane.yaml.tftpl", {
        hostname                           = local.use_hostname_config_doc ? "" : each.key
        virtual_ip                         = var.cluster.virtual_ip
        platform                           = each.value.platform
        talos_config                       = { image = { version = var.talos_version }, kernel_args = each.value.overlay != null ? [] : each.value.kernel_args }
        schematic_id                       = local.ext_node_schematic_id[each.key]
        allow_scheduling_on_control_planes = var.cluster.allow_scheduling_on_control_planes
        extra_manifests                    = local.all_extra_manifests
      })
      ] : [
      templatefile("${path.module}/templates/worker.yaml.tftpl", {
        hostname     = local.use_hostname_config_doc ? "" : each.key
        platform     = each.value.platform
        talos_config = { image = { version = var.talos_version }, kernel_args = each.value.overlay != null ? [] : each.value.kernel_args }
        schematic_id = local.ext_node_schematic_id[each.key]
      })
    ],
    local.use_hostname_config_doc ? [yamlencode({
      apiVersion = "v1alpha1"
      kind       = "HostnameConfig"
      auto       = "off"
      hostname   = each.key
    })] : [],
    # NVIDIA RuntimeClass (controlplane only)
    each.value.machine_type == "controlplane" ? local.nvidia_runtime_class_patch : [],
    # Proxmox CSI namespace with privileged PodSecurity (controlplane only)
    each.value.machine_type == "controlplane" ? local.proxmox_csi_namespace_patch : [],
    # Cilium L2 LoadBalancer IP Pool + Announcement Policy (controlplane only)
    each.value.machine_type == "controlplane" ? local.cilium_l2_patch : [],
    # Per-node config patches
    each.value.config_patches
  )
}

resource "talos_machine_configuration_apply" "external" {
  depends_on                  = [talos_machine_bootstrap.this]
  for_each                    = var.external_nodes
  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.external[each.key].machine_configuration
}
