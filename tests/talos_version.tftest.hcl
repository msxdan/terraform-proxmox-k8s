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

run "talos_112_hostname_config" {
  command = plan

  variables {
    talos_version = "v1.12.5"
  }

  assert {
    condition     = length(data.talos_machine_configuration.this["cp-01"].config_patches) == 2
    error_message = "Talos 1.12 should have 2 config patches (control-plane + HostnameConfig document)"
  }
}

run "talos_111_hostname_legacy" {
  command = plan

  variables {
    talos_version = "v1.11.6"
  }

  assert {
    condition     = length(data.talos_machine_configuration.this["cp-01"].config_patches) == 1
    error_message = "Talos 1.11 should have 1 config patch (control-plane only, hostname in template)"
  }
}
