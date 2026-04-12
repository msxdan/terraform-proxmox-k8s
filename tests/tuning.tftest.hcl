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

run "default_tuning_plans_successfully" {
  command = plan

  assert {
    condition     = data.talos_machine_configuration.this["cp-01"].machine_type == "controlplane"
    error_message = "Control plane node should have correct machine type"
  }

  assert {
    condition     = data.talos_machine_configuration.this["worker-01"].machine_type == "worker"
    error_message = "Worker node should have correct machine type"
  }
}

run "custom_controlplane_tuning" {
  command = plan

  variables {
    machine_tuning = {
      controlplane = {
        sysctls = {
          "net.core.somaxconn" = "32768"
        }
        shutdown_grace_period  = "30s"
        image_gc_high          = 80
        image_gc_low           = 60
        server_tls_bootstrap   = true
        seccomp_default        = true
        allowed_unsafe_sysctls = []
      }
    }
  }

  assert {
    condition     = data.talos_machine_configuration.this["cp-01"].machine_type == "controlplane"
    error_message = "Control plane should plan with custom controlplane tuning"
  }
}

run "custom_worker_tuning" {
  command = plan

  variables {
    machine_tuning = {
      worker = {
        sysctls = {
          "net.core.somaxconn" = "32768"
          "vm.max_map_count"   = "262144"
        }
        shutdown_grace_period = "30s"
        server_tls_bootstrap  = true
        seccomp_default       = true
      }
    }
  }

  assert {
    condition     = data.talos_machine_configuration.this["worker-01"].machine_type == "worker"
    error_message = "Worker should plan with custom worker tuning"
  }
}

run "custom_cluster_tuning" {
  command = plan

  variables {
    cluster_tuning = {
      kubeconfig_cert_lifetime  = "24h0m0s"
      etcd_election_timeout     = "10000"
      etcd_heartbeat_interval   = "2000"
      api_server_cpu_request    = "1"
      api_server_memory_request = "2Gi"
    }
  }

  assert {
    condition     = data.talos_machine_configuration.this["cp-01"].machine_type == "controlplane"
    error_message = "Control plane should plan with custom cluster_tuning"
  }
}

run "empty_sysctls" {
  command = plan

  variables {
    machine_tuning = {
      controlplane = { sysctls = {} }
      worker       = { sysctls = {} }
    }
  }

  assert {
    condition     = data.talos_machine_configuration.this["cp-01"].machine_type == "controlplane"
    error_message = "Control plane should plan with empty sysctls"
  }

  assert {
    condition     = data.talos_machine_configuration.this["worker-01"].machine_type == "worker"
    error_message = "Worker should plan with empty sysctls"
  }
}
