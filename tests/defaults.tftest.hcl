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
    "worker-01" = {
      host_node     = "pve-01"
      machine_type  = "worker"
      ip            = "10.0.0.20"
      mac_address   = "AA:BB:CC:DD:01:20"
      vm_id         = 1100
      cpu           = 4
      ram_dedicated = 8192
    }
  }

}

run "default_component_versions" {
  command = plan

  assert {
    condition     = helm_release.cilium.version == "1.19.1"
    error_message = "Default Cilium version should be 1.19.1"
  }

  assert {
    condition     = helm_release.metrics_server[0].version == "3.13.0"
    error_message = "Default Metrics Server version should be 3.13.0"
  }

  assert {
    condition     = length(helm_release.cert_manager) == 1
    error_message = "Cert Manager should be enabled by default"
  }

  assert {
    condition     = helm_release.cert_manager[0].version == "1.20.0"
    error_message = "Default Cert Manager version should be 1.20.0"
  }

  assert {
    condition     = length(helm_release.longhorn) == 0
    error_message = "Longhorn should be disabled by default"
  }
}
