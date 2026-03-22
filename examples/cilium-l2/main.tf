# Cilium L2 LoadBalancer + Gateway API
#
# Assigns external IPs to `type: LoadBalancer` services and announces
# them via ARP on the local network. No external load balancer needed.
#
# Combined with Gateway API, this gives you a complete ingress stack:
#   - L2 pool provides the external IP
#   - Gateway API routes HTTP/HTTPS traffic to backend services
#   - Cert Manager handles TLS certificates

module "cluster" {
  source = "../../"

  talos_version      = "v1.12.5"
  kubernetes_version = "1.35.2"

  cluster = {
    name       = "homelab"
    endpoint   = "192.168.97.1"
    virtual_ip = "192.168.97.1"
  }

  nodes = {
    "master-01" = {
      host_node     = "pve-01"
      machine_type  = "controlplane"
      ip            = "192.168.97.10"
      mac_address   = "BC:24:11:97:00:10"
      vm_id         = 4000
      cpu           = 2
      ram_dedicated = 2048
      disk_size     = 20
    }
    "worker-01" = {
      host_node     = "pve-01"
      machine_type  = "worker"
      ip            = "192.168.97.20"
      mac_address   = "BC:24:11:97:01:20"
      vm_id         = 4100
      cpu           = 4
      ram_dedicated = 8192
    }
  }

  cilium = {
    version = "1.19.1"
    l2 = {
      ip_pools = [{
        name  = "svc-lb-pool"
        start = "192.168.97.100"
        stop  = "192.168.97.199"
      }]
    }
  }

  gateway_api = {
    enabled         = true
    version         = "1.4.0"
    enable_tlsroute = true
  }
}

# After apply, create a Gateway:
#
#   apiVersion: gateway.networking.k8s.io/v1
#   kind: Gateway
#   metadata:
#     name: main-gateway
#   spec:
#     gatewayClassName: cilium
#     listeners:
#       - name: http
#         protocol: HTTP
#         port: 80
#
# The Gateway gets an IP from the L2 pool automatically.
# Route traffic with HTTPRoute resources.
