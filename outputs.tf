output "kubeconfig_raw" {
  description = "Raw kubeconfig content"
  value       = talos_cluster_kubeconfig.this.kubeconfig_raw
  sensitive   = true
}

output "kubeconfig_host" {
  description = "Kubernetes API server host"
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
  sensitive   = true
}

output "kubeconfig_client_certificate" {
  description = "Kubernetes client certificate (base64)"
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate
  sensitive   = true
}

output "kubeconfig_client_key" {
  description = "Kubernetes client key (base64)"
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key
  sensitive   = true
}

output "kubeconfig_ca_certificate" {
  description = "Kubernetes CA certificate (base64)"
  value       = talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate
  sensitive   = true
}

output "talosconfig_raw" {
  description = "Raw talosconfig content"
  value       = data.talos_client_configuration.this.talos_config
  sensitive   = true
}

output "client_configuration" {
  description = "Talos client configuration for API calls"
  value       = talos_machine_secrets.this.client_configuration
  sensitive   = true
}

output "schematic_id" {
  description = "Talos image factory schematic ID"
  value       = talos_image_factory_schematic.this.id
}

output "control_plane_ips" {
  description = "Control plane node IPs"
  value = concat(
    [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"],
    [for k, v in var.external_nodes : v.ip if v.machine_type == "controlplane"]
  )
}

output "worker_ips" {
  description = "Worker node IPs"
  value = concat(
    [for k, v in var.nodes : v.ip if v.machine_type == "worker"],
    [for k, v in var.external_nodes : v.ip if v.machine_type == "worker"]
  )
}

output "endpoints" {
  description = "Talos API endpoints"
  value       = data.talos_client_configuration.this.endpoints
}

output "external_schematic_ids" {
  description = "Talos Image Factory schematic IDs for external nodes (per node)"
  value       = { for k, v in var.external_nodes : k => local.ext_node_schematic_id_for_urls[k] }
}

output "external_image_urls" {
  description = "Image download URLs for external nodes (flash to SD card / USB)"
  value = {
    for k, v in var.external_nodes : k => {
      iso     = "${local.factory_url}/image/${local.ext_node_schematic_id_for_urls[k]}/${var.talos_version}/${v.platform}-${v.arch}.iso"
      raw_xz  = "${local.factory_url}/image/${local.ext_node_schematic_id_for_urls[k]}/${var.talos_version}/${v.platform}-${v.arch}.raw.xz"
      raw_zst = "${local.factory_url}/image/${local.ext_node_schematic_id_for_urls[k]}/${var.talos_version}/${v.platform}-${v.arch}.raw.zst"
    }
  }
}
