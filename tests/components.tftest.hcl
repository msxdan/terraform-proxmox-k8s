mock_provider "proxmox" {
  mock_resource "proxmox_virtual_environment_download_file" {
    defaults = {
      id = "local:iso/talos-test.img"
    }
  }
}
mock_provider "talos" {}
mock_provider "helm" {}
mock_provider "http" {}
mock_provider "time" {}
override_data {
  target = data.http.schematic_id
  values = {
    response_body = "{\"id\": \"test-schematic-id\"}"
  }
}

variables {
  cluster = {
    name       = "test-cluster"
    endpoint   = "10.0.0.1"
    virtual_ip = "10.0.0.1"
  }

  talos_version      = "v1.12.5"
  kubernetes_version = "1.35.2"

  nodes = {
    "cp-01" = {
      host_node     = "pve-01"
      machine_type  = "controlplane"
      ip            = "10.0.0.10"
      mac_address   = "AA:BB:CC:DD:00:10"
      vm_id         = 1000
      cpu           = 2
      ram_dedicated = 2048
    }
  }

}

run "longhorn_enabled" {
  command = plan

  variables {
    longhorn = { enabled = true }
  }

  assert {
    condition     = length(helm_release.longhorn) == 1
    error_message = "Longhorn should be created when enabled"
  }

  assert {
    condition     = helm_release.longhorn[0].version == "1.11.0"
    error_message = "Default Longhorn version should be 1.11.0"
  }
}

run "cert_manager_disabled" {
  command = plan

  variables {
    cert_manager = { enabled = false }
  }

  assert {
    condition     = length(helm_release.cert_manager) == 0
    error_message = "Cert Manager should not be created when disabled"
  }
}

run "custom_versions" {
  command = plan

  variables {
    cilium         = { version = "1.20.0" }
    metrics_server = { version = "3.14.0" }
    cert_manager   = { version = "1.21.0" }
  }

  assert {
    condition     = helm_release.cilium.version == "1.20.0"
    error_message = "Cilium version should be overridable"
  }

  assert {
    condition     = helm_release.metrics_server[0].version == "3.14.0"
    error_message = "Metrics Server version should be overridable"
  }

  assert {
    condition     = helm_release.cert_manager[0].version == "1.21.0"
    error_message = "Cert Manager version should be overridable"
  }
}
