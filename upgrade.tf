# Rolling upgrade support for Talos nodes.
#
# Upgrade procedure:
#   1. Set talos_version_target in tfvars
#   2. Set update = true on ONE control plane node
#   3. tofu apply -> upgrades that node and waits for health
#   4. Repeat step 2-3 for remaining control plane nodes (one at a time)
#   5. Set update = true on worker nodes (can do multiple workers at once)
#   6. tofu apply -> upgrades workers
#   7. Set talos_version = new version, remove talos_version_target, reset all update = false
#   8. tofu apply -> clean state

locals {
  upgrade_version = coalesce(var.talos_version_target, var.talos_version)

  # Per-node upgrade image (uses each node's schematic)
  node_upgrade_image = {
    for k, v in var.nodes : k => "factory.talos.dev/installer/${local.node_schematic_id[k]}:${local.upgrade_version}"
  }

  # Separate nodes to upgrade by role for ordered execution
  cp_nodes_to_upgrade     = { for k, v in var.nodes : k => v if v.update && v.machine_type == "controlplane" }
  worker_nodes_to_upgrade = { for k, v in var.nodes : k => v if v.update && v.machine_type == "worker" }

  # External nodes upgrade (per-node schematic)
  ext_node_upgrade_image = {
    for k, v in var.external_nodes : k => "factory.talos.dev/installer/${local.ext_node_schematic_id[k]}:${local.upgrade_version}"
  }
  external_cp_nodes_to_upgrade     = { for k, v in var.external_nodes : k => v if v.update && v.machine_type == "controlplane" }
  external_worker_nodes_to_upgrade = { for k, v in var.external_nodes : k => v if v.update && v.machine_type == "worker" }
}

resource "terraform_data" "upgrade_controlplane" {
  for_each = var.talos_version_target != null ? local.cp_nodes_to_upgrade : {}

  triggers_replace = [var.talos_version_target]

  provisioner "local-exec" {
    command = <<-EOT
      echo "$TALOS_CONFIG" > "${path.module}/.talosconfig" && \
      talosctl upgrade \
        --talosconfig "${path.module}/.talosconfig" \
        --nodes ${each.value.ip} \
        --image ${local.node_upgrade_image[each.key]} \
        --wait; \
      RC=$?; rm -f "${path.module}/.talosconfig"; exit $RC
    EOT
    environment = {
      TALOS_CONFIG = data.talos_client_configuration.this.talos_config
    }
  }
}

resource "terraform_data" "upgrade_worker" {
  depends_on = [terraform_data.upgrade_controlplane]
  for_each   = var.talos_version_target != null ? local.worker_nodes_to_upgrade : {}

  triggers_replace = [var.talos_version_target]

  provisioner "local-exec" {
    command = <<-EOT
      echo "$TALOS_CONFIG" > "${path.module}/.talosconfig" && \
      talosctl upgrade \
        --talosconfig "${path.module}/.talosconfig" \
        --nodes ${each.value.ip} \
        --image ${local.node_upgrade_image[each.key]} \
        --wait; \
      RC=$?; rm -f "${path.module}/.talosconfig"; exit $RC
    EOT
    environment = {
      TALOS_CONFIG = data.talos_client_configuration.this.talos_config
    }
  }
}

# --- External node upgrades ---

resource "terraform_data" "upgrade_external_controlplane" {
  depends_on = [terraform_data.upgrade_controlplane]
  for_each   = var.talos_version_target != null ? local.external_cp_nodes_to_upgrade : {}

  triggers_replace = [var.talos_version_target]

  provisioner "local-exec" {
    command = <<-EOT
      echo "$TALOS_CONFIG" > "${path.module}/.talosconfig" && \
      talosctl upgrade \
        --talosconfig "${path.module}/.talosconfig" \
        --nodes ${each.value.ip} \
        --image ${local.ext_node_upgrade_image[each.key]} \
        --wait; \
      RC=$?; rm -f "${path.module}/.talosconfig"; exit $RC
    EOT
    environment = {
      TALOS_CONFIG = data.talos_client_configuration.this.talos_config
    }
  }
}

resource "terraform_data" "upgrade_external_worker" {
  depends_on = [
    terraform_data.upgrade_controlplane,
    terraform_data.upgrade_external_controlplane
  ]
  for_each = var.talos_version_target != null ? local.external_worker_nodes_to_upgrade : {}

  triggers_replace = [var.talos_version_target]

  provisioner "local-exec" {
    command = <<-EOT
      echo "$TALOS_CONFIG" > "${path.module}/.talosconfig" && \
      talosctl upgrade \
        --talosconfig "${path.module}/.talosconfig" \
        --nodes ${each.value.ip} \
        --image ${local.ext_node_upgrade_image[each.key]} \
        --wait; \
      RC=$?; rm -f "${path.module}/.talosconfig"; exit $RC
    EOT
    environment = {
      TALOS_CONFIG = data.talos_client_configuration.this.talos_config
    }
  }
}
