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

run "keda_enabled" {
  command = plan

  variables {
    keda = { enabled = true }
  }

  assert {
    condition     = length(helm_release.keda) == 1
    error_message = "KEDA should be created when enabled"
  }

  assert {
    condition     = length(helm_release.keda_http_add_on) == 0
    error_message = "KEDA HTTP add-on should not be created when http is not enabled"
  }
}

run "keda_http_add_on_enabled" {
  command = plan

  variables {
    keda = {
      enabled = true
      http    = { enabled = true }
    }
  }

  assert {
    condition     = length(helm_release.keda) == 1
    error_message = "KEDA should be created when enabled"
  }

  assert {
    condition     = length(helm_release.keda_http_add_on) == 1
    error_message = "KEDA HTTP add-on should be created when http is enabled"
  }

}

run "keda_http_requires_keda" {
  command = plan

  variables {
    keda = {
      enabled = false
      http    = { enabled = true }
    }
  }

  assert {
    condition     = length(helm_release.keda) == 0
    error_message = "KEDA should not be created when disabled"
  }

  assert {
    condition     = length(helm_release.keda_http_add_on) == 0
    error_message = "KEDA HTTP add-on should not be created when KEDA is disabled"
  }
}

