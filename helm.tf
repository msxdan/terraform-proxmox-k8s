# --- CNI (Cilium) ---

resource "helm_release" "cilium" {
  depends_on = [
    time_sleep.wait_for_api_server
  ]

  name       = "cilium"
  namespace  = "kube-system"
  repository = "https://helm.cilium.io/"
  chart      = "cilium"
  version    = var.cilium.version
  values = concat(
    [templatefile("${path.module}/values/cilium.yaml.tftpl", {
      gateway_api_enabled = var.gateway_api.enabled
      l2_enabled          = var.cilium.l2 != null ? var.cilium.l2.enabled : false
    })],
    var.cilium.values
  )
}

# --- Metrics Server ---

resource "helm_release" "metrics_server" {
  count = var.metrics_server.enabled ? 1 : 0

  depends_on = [
    helm_release.cilium
  ]

  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server.version
  values = concat([
    yamlencode({ args = ["--kubelet-insecure-tls"] })
  ], var.metrics_server.values)
}

# --- Cert Manager ---

resource "helm_release" "cert_manager" {
  count = var.cert_manager.enabled ? 1 : 0

  depends_on = [
    helm_release.cilium
  ]

  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager.version
  values = concat(
    [templatefile("${path.module}/values/cert-manager.yaml.tftpl", {
      replicas                         = var.cert_manager.replicas
      dns01_recursive_nameservers      = var.cert_manager.dns01_recursive_nameservers
      dns01_recursive_nameservers_only = var.cert_manager.dns01_recursive_nameservers_only
    })],
    var.cert_manager.values
  )
}

# --- Longhorn ---

resource "helm_release" "longhorn" {
  count = var.longhorn.enabled ? 1 : 0

  depends_on = [
    helm_release.cilium
  ]

  name             = "longhorn"
  namespace        = "longhorn-system"
  create_namespace = true
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = var.longhorn.version
  values = concat(
    [templatefile("${path.module}/values/longhorn.yaml.tftpl", {
      default_replica_count = var.longhorn.default_replica_count
    })],
    var.longhorn.values
  )
}

# --- NVIDIA Device Plugin ---

resource "helm_release" "nvidia_device_plugin" {
  count = var.nvidia_device_plugin.enabled ? 1 : 0

  depends_on = [
    helm_release.cilium
  ]

  name       = "nvidia-device-plugin"
  namespace  = "kube-system"
  repository = "https://nvidia.github.io/k8s-device-plugin"
  chart      = "nvidia-device-plugin"
  version    = var.nvidia_device_plugin.version
  values = concat(
    [templatefile("${path.module}/values/nvidia-device-plugin.yaml.tftpl", {
      time_slicing_replicas = var.nvidia_device_plugin.time_slicing_replicas
      rename_by_default     = var.nvidia_device_plugin.rename_by_default
    })],
    var.nvidia_device_plugin.values
  )
}

# --- Proxmox CSI Plugin ---

resource "helm_release" "proxmox_csi" {
  count = var.proxmox_csi.enabled ? 1 : 0

  depends_on = [
    helm_release.cilium
  ]

  name             = "proxmox-csi-plugin"
  namespace        = "csi-proxmox"
  create_namespace = true
  chart            = "oci://ghcr.io/sergelogvinov/charts/proxmox-csi-plugin"
  version          = var.proxmox_csi.version
  values = concat(
    [templatefile("${path.module}/values/proxmox-csi.yaml.tftpl", {
      proxmox_url     = var.proxmox_csi.proxmox_url
      insecure        = var.proxmox_csi.insecure
      token_id        = var.proxmox_csi.token_id
      token_secret    = var.proxmox_csi.token_secret
      region          = var.proxmox_csi.region
      storage_classes = var.proxmox_csi.storage_classes
    })],
    var.proxmox_csi.values
  )
}

# --- Health Check ---
#
# Uses a resource (not data source) so it only runs during apply,
# not during plan. This prevents failures when adding new nodes
# that don't exist yet.

resource "terraform_data" "cluster_health" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_configuration_apply.external,
    helm_release.cilium,
    helm_release.metrics_server,
    helm_release.cert_manager,
    helm_release.longhorn,
    helm_release.nvidia_device_plugin,
    helm_release.proxmox_csi
  ]

  # Re-check health when node list or versions change
  triggers_replace = [
    jsonencode([for k, v in var.nodes : v.ip]),
    jsonencode([for k, v in var.external_nodes : v.ip]),
    var.talos_version,
    var.kubernetes_version,
  ]

  provisioner "local-exec" {
    command = <<-EOT
      echo "$TALOS_CONFIG" > "${path.module}/.talosconfig" && \
      talosctl health \
        --talosconfig "${path.module}/.talosconfig" \
        --control-plane-nodes ${join(",", concat(
    [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"],
    [for k, v in var.external_nodes : v.ip if v.machine_type == "controlplane"]
    ))} \
        --worker-nodes ${join(",", concat(
    [for k, v in var.nodes : v.ip if v.machine_type == "worker"],
    [for k, v in var.external_nodes : v.ip if v.machine_type == "worker"]
))} \
        --nodes ${[for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]} \
        --wait-timeout 10m; \
      RC=$?; rm -f "${path.module}/.talosconfig"; exit $RC
    EOT
environment = {
  TALOS_CONFIG = data.talos_client_configuration.this.talos_config
}
}
}
