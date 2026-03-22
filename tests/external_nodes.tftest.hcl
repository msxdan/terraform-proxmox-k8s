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

run "no_external_nodes_by_default" {
  command = plan

  assert {
    condition     = length(output.worker_ips) == 1
    error_message = "Should have 1 worker without external nodes"
  }

  assert {
    condition     = length(output.external_image_urls) == 0
    error_message = "Should have no external image URLs"
  }
}

run "with_external_worker" {
  command = plan

  variables {
    external_nodes = {
      "rpi-01" = {
        ip   = "10.0.0.30"
        arch = "arm64"
      }
    }
  }

  override_data {
    target = data.http.external_schematic_id
    values = {
      response_body = "{\"id\": \"external-schematic-id\"}"
    }
  }

  assert {
    condition     = length(output.worker_ips) == 2
    error_message = "Should have 2 workers (1 proxmox + 1 external)"
  }

  assert {
    condition     = contains(output.worker_ips, "10.0.0.30")
    error_message = "External worker IP should be in worker_ips"
  }

  assert {
    condition     = length(output.external_schematic_ids) == 1
    error_message = "Should have external schematic IDs"
  }

  assert {
    condition     = length(output.external_image_urls) == 1
    error_message = "Should have 1 external image URL entry"
  }
}

run "gpu_passthrough" {
  command = plan

  variables {
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
      "gpu-worker" = {
        host_node     = "pve-01"
        machine_type  = "worker"
        ip            = "10.0.0.25"
        mac_address   = "AA:BB:CC:DD:01:25"
        vm_id         = 1200
        cpu           = 8
        ram_dedicated = 16384
        hostpci = [{
          device  = "hostpci0"
          mapping = "gpu-nvidia"
          pcie    = true
        }]
      }
    }
  }

  assert {
    condition     = length(proxmox_virtual_environment_vm.this) == 2
    error_message = "Should create 2 VMs"
  }
}

run "per_node_extensions" {
  command = plan

  variables {
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
      "gpu-worker" = {
        host_node     = "pve-02"
        machine_type  = "worker"
        ip            = "10.0.0.25"
        mac_address   = "AA:BB:CC:DD:01:25"
        vm_id         = 1200
        cpu           = 8
        ram_dedicated = 16384
        talos_extensions = [
          "siderolabs/nonfree-kmod-nvidia-production",
          "siderolabs/nvidia-container-toolkit-production"
        ]
      }
    }
  }

  override_data {
    target = data.http.custom_schematic_id
    values = {
      response_body = "{\"id\": \"nvidia-schematic-id\"}"
    }
  }

  # Default ISO on pve-01 (cp-01 + worker-01 use default extensions)
  assert {
    condition     = length(proxmox_virtual_environment_download_file.talos_iso) == 1
    error_message = "Should download default ISO to 1 host (pve-01)"
  }

  # Custom ISO on pve-02 (gpu-worker uses NVIDIA extensions)
  assert {
    condition     = length(proxmox_virtual_environment_download_file.custom_talos_iso) == 1
    error_message = "Should download custom ISO to 1 host (pve-02)"
  }

  # 3 VMs total
  assert {
    condition     = length(proxmox_virtual_environment_vm.this) == 3
    error_message = "Should create 3 VMs"
  }
}
