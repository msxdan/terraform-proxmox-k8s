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

run "no_upgrade_by_default" {
  command = plan

  assert {
    condition     = length(terraform_data.upgrade_controlplane) == 0
    error_message = "No upgrade resources should be created without talos_version_target"
  }

  assert {
    condition     = length(terraform_data.upgrade_worker) == 0
    error_message = "No worker upgrade resources should be created without talos_version_target"
  }
}

run "selective_upgrade" {
  command = plan

  variables {
    talos_version_target = "v1.13.0"
    nodes = {
      "cp-01" = {
        host_node     = "pve-01"
        machine_type  = "controlplane"
        ip            = "10.0.0.10"
        mac_address   = "AA:BB:CC:DD:00:10"
        vm_id         = 1000
        cpu           = 2
        ram_dedicated = 2048
        update        = true
      }
      "worker-01" = {
        host_node     = "pve-01"
        machine_type  = "worker"
        ip            = "10.0.0.20"
        mac_address   = "AA:BB:CC:DD:01:20"
        vm_id         = 1100
        cpu           = 4
        ram_dedicated = 8192
        update        = false
      }
    }
  }

  assert {
    condition     = length(terraform_data.upgrade_controlplane) == 1
    error_message = "Should upgrade only the control plane node with update=true"
  }

  assert {
    condition     = length(terraform_data.upgrade_worker) == 0
    error_message = "Should not upgrade worker with update=false"
  }
}
