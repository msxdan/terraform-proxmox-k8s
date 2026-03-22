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
    "cp-02" = {
      host_node     = "pve-01"
      machine_type  = "controlplane"
      ip            = "10.0.0.11"
      mac_address   = "AA:BB:CC:DD:00:11"
      vm_id         = 1001
      cpu           = 2
      ram_dedicated = 2048
    }
    "cp-03" = {
      host_node     = "pve-02"
      machine_type  = "controlplane"
      ip            = "10.0.0.12"
      mac_address   = "AA:BB:CC:DD:00:12"
      vm_id         = 1002
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
    "worker-02" = {
      host_node     = "pve-02"
      machine_type  = "worker"
      ip            = "10.0.0.21"
      mac_address   = "AA:BB:CC:DD:01:21"
      vm_id         = 1101
      cpu           = 4
      ram_dedicated = 8192
    }
  }

}

run "vm_count" {
  command = plan

  assert {
    condition     = length(proxmox_virtual_environment_vm.this) == 5
    error_message = "Should create 5 VMs"
  }
}

run "node_ip_outputs" {
  command = plan

  assert {
    condition     = length(output.control_plane_ips) == 3
    error_message = "Should have 3 control plane IPs"
  }

  assert {
    condition     = length(output.worker_ips) == 2
    error_message = "Should have 2 worker IPs"
  }
}

run "iso_per_host" {
  command = plan

  assert {
    condition     = length(proxmox_virtual_environment_download_file.talos_iso) == 2
    error_message = "Should download ISO once per unique host_node (pve-01 and pve-02)"
  }
}
