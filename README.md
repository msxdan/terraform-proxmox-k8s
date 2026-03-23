<div align="center">

  <img src="https://raw.githubusercontent.com/msxdan/terraform-proxmox-k8s/main/.github/logo.svg" alt="terraform-proxmox-k8s" width="200" height="auto" />
  <h1>terraform-proxmox-k8s</h1>

  <p>
    OpenTofu / Terraform module to deploy a fully operational Talos Linux Kubernetes cluster on Proxmox VE.
  </p>

<!-- Badges -->
<p>
  <a href="https://github.com/msxdan/terraform-proxmox-k8s/releases/latest">
    <img src="https://img.shields.io/github/release/msxdan/terraform-proxmox-k8s?logo=github" alt="latest release" />
  </a>
  <a href="https://registry.terraform.io/modules/msxdan/k8s/proxmox">
    <img src="https://img.shields.io/badge/Terraform-Registry-7B42BC?logo=terraform" alt="Terraform Registry" />
  </a>
  <a href="https://search.opentofu.org/module/msxdan/k8s/proxmox">
    <img src="https://img.shields.io/badge/OpenTofu-Registry-FFDA18?logo=opentofu" alt="OpenTofu Registry" />
  </a>
  <a href="https://github.com/msxdan/terraform-proxmox-k8s/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/msxdan/terraform-proxmox-k8s?logo=github" alt="license" />
  </a>
</p>

</div>

<br />

<!-- Table of Contents -->

# :notebook_with_decorative_cover: Overview

- [:star2: Features](#star2-features)
- [:package: Components](#package-components)
- [:construction: Roadmap](#construction-roadmap)
- [:rocket: Getting Started](#rocket-getting-started)
- [:gear: Advanced Configuration](#gear-advanced-configuration)
- [:recycle: Lifecycle](#recycle-lifecycle)
- [:open_file_folder: Examples](#open_file_folder-examples)
- [:scroll: License](#scroll-license)

---

<!-- Features -->

## :star2: Features

- **One command, full cluster:** `tofu apply` provisions VMs, installs Talos, bootstraps Kubernetes, deploys CNI and add-ons, and validates cluster health — all in a single run.
- **Immutable & secure:** Powered by [Talos Linux](https://www.talos.dev/) — no SSH, no shell, no drift. API-managed, CIS-hardened, runs entirely from memory.
- **High availability:** Control plane VIP, multi-node etcd, and rolling upgrades that maintain quorum automatically.
- **GPU-ready:** NVIDIA PCI passthrough with time-slicing — run multiple ML workloads on a single GPU out of the box.
- **Hybrid clusters:** Mix Proxmox VMs with bare-metal nodes in the same cluster — supports both AMD64 and ARM64 architectures (Raspberry Pi, x86 servers, and more).
- **Per-node customization:** Override Talos extensions, kernel modules, labels, taints, and PCI devices on individual nodes without affecting the rest of the cluster.
- **Production networking:** Cilium eBPF replaces kube-proxy, with L2 LoadBalancer, Gateway API, and optional WireGuard encryption.
- **Flexible storage:** Choose between Proxmox CSI (use your existing LVM/ZFS/Ceph) or Longhorn (distributed in-cluster replication).
- **Safe upgrades:** Validated upgrade paths between component versions with step-by-step procedures and rollback documentation.
- **Fully declarative:** Everything is code — no manual `kubectl` or `helm install` steps required after deployment.

<!-- Components -->

## :package: Components

Essential Kubernetes components deployed automatically as part of `tofu apply`:

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=cilium.io&sz=32" width="16" height="16">
    <b><a href="https://cilium.io">Cilium CNI</a></b>
  </summary>
  High-performance CNI plugin using eBPF. Replaces kube-proxy, provides native routing, L2 announcements for LoadBalancer services, and Gateway API support.

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=kubernetes.io&sz=32" width="16" height="16">
    <b><a href="https://kubernetes-sigs.github.io/metrics-server/">Metrics Server</a></b> <i>(optional, enabled by default)</i>
  </summary>
  Collects container resource metrics (CPU/memory) from kubelets, enabling HPA/VPA. Uses <code>--kubelet-insecure-tls</code> for Talos compatibility.

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=cert-manager.io&sz=32" width="16" height="16">
    <b><a href="https://cert-manager.io">Cert Manager</a></b> <i>(optional, enabled by default)</i>
  </summary>
  Automates TLS certificate lifecycle. Supports ACME (Let's Encrypt), DNS01/HTTP01 validation, and multiple DNS providers.

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=longhorn.io&sz=32" width="16" height="16">
    <b><a href="https://longhorn.io">Longhorn</a></b> <i>(optional, experimental)</i>
  </summary>
  Distributed block storage providing replicated persistent volumes. Supports snapshots and backups. Disabled by default. <b>Not validated in production — use at your own risk.</b>

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=github.com&sz=32" width="16" height="16">
    <b><a href="https://github.com/NVIDIA/k8s-device-plugin">NVIDIA Device Plugin</a></b> <i>(optional)</i>
  </summary>
  Exposes <code>nvidia.com/gpu</code> resources to Kubernetes, enabling GPU scheduling and time-slicing (share one GPU across multiple pods). Required for GPU passthrough nodes. Disabled by default.

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=github.com&sz=32" width="16" height="16">
    <b><a href="https://github.com/sergelogvinov/proxmox-csi-plugin">Proxmox CSI Plugin</a></b> <i>(optional)</i>
  </summary>
  Creates PersistentVolumes backed by Proxmox storage (LVM, ZFS, Ceph). Alternative to Longhorn — uses existing Proxmox storage instead of in-cluster replication. Disabled by default.

### :construction: Roadmap

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=kubernetes.io&sz=32" width="16" height="16">
    <b><a href="https://github.com/kubernetes-sigs/external-dns">External DNS</a></b>
  </summary>
  Automates DNS records for Services and HTTPRoutes. Supports Cloudflare, Route53, Google DNS, and more.

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=prometheus.io&sz=32" width="16" height="16">
    <b><a href="https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack">Kube Prometheus Stack</a></b>
  </summary>
  Full monitoring stack with Prometheus, Grafana, Alertmanager, and node-exporter.

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=velero.io&sz=32" width="16" height="16">
    <b><a href="https://velero.io">Velero</a></b>
  </summary>
  Cluster backup and disaster recovery with CSI snapshot support.

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=external-secrets.io&sz=32" width="16" height="16">
    <b><a href="https://external-secrets.io">External Secrets Operator</a></b>
  </summary>
  Integrates secrets from Vault, AWS SSM, SOPS, 1Password, and more.

- <summary>
    <img align="center" src="https://www.google.com/s2/favicons?domain=argo-cd.readthedocs.io&sz=32" width="16" height="16">
    <b><a href="https://argo-cd.readthedocs.io">ArgoCD</a></b> / <b><a href="https://fluxcd.io">Flux</a></b>
  </summary>
  GitOps-based continuous delivery for managing cluster applications after bootstrap.

See [TODO.md](TODO.md) for the full roadmap.

---

## :rocket: Getting Started

### :white_check_mark: Prerequisites

- [OpenTofu](https://opentofu.org/docs/intro/install/) >= 1.10.0 or [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.10.0
- [talosctl](https://www.talos.dev/latest/talos-guides/install/talosctl) to manage the Talos cluster
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) to manage Kubernetes
- A [Proxmox VE](https://www.proxmox.com/) host with API access and SSH configured

### :dart: Installation

Create your module configuration (e.g. `main.tf`):

```hcl
module "cluster" {
  source = "msxdan/k8s/proxmox"

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
      ram_dedicated = 4096
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
}

provider "proxmox" {
  endpoint  = "https://pve-01.example.com:8006/"
  api_token = "user@pam!token=secret"
  insecure  = true
  ssh {
    agent    = true
    username = "root"
    node {
      name    = "pve-01"
      address = "pve-01.example.com"
    }
  }
}

provider "helm" {
  kubernetes {
    host                   = module.cluster.kubeconfig_host
    client_certificate     = base64decode(module.cluster.kubeconfig_client_certificate)
    client_key             = base64decode(module.cluster.kubeconfig_client_key)
    cluster_ca_certificate = base64decode(module.cluster.kubeconfig_ca_certificate)
  }
}
```

Initialize and deploy the cluster:

```sh
tofu init -upgrade
tofu apply
```

### :key: Cluster Access

Extract configuration files:

```sh
tofu output -raw kubeconfig_raw > kubeconfig
tofu output -raw talosconfig_raw > talosconfig
export KUBECONFIG=kubeconfig
export TALOSCONFIG=talosconfig
```

Verify the cluster:

```sh
talosctl health
kubectl get nodes -o wide
kubectl get pods -A
```

### :boom: Teardown

```sh
tofu destroy
```

---

## Architecture (example)

```
 ┌─────────────────────────────────────────────────────────────────────────────┐
 │                              Talos Image Factory                            │
 │                               factory.talos.dev                             │
 │                                                                             │
 │    Schematic A (default)       Schematic B (NVIDIA)         Schematic       │
 │    qemu-guest-agent            qemu-guest-agent             CSBC overlay    │
 │                                nvidia-kmod                  iscsi-tools     │
 │                                nvidia-toolkit                               │
 └──────┬──────────────────────────────┬───────────────────────────┬───────────┘
        │ ISO                          │ ISO                       │ raw image
        ▼                              ▼                           ▼
 ┌──────────────────────────────────────────────────────┐   ┌──────────────────┐
 │                   Proxmox VE Cluster                 │   │  External Nodes  │
 │                                                      │   │   (bare-metal)   │
 │  ┌─ PVE Host 1 ─────────────────────────────-─────┐  │   │                  │
 │  │                                                │  │   │  ┌────────────┐  │
 │  │    ┌──────────┐  ┌──────────┐  ┌──────────┐    │  │   │  │   RPi 5    │  │
 │  │    │  CP-1    │  │  CP-2    │  │  CP-3    │    │  │   │  │   ARM64    │  │
 │  │    │  etcd    │  │  etcd    │  │  etcd    │    │  │   │  └────────────┘  │
 │  │    │  API svr │  │  API svr │  │  API svr │    │  │   │                  │
 │  │    └────┬─────┘  └────┬─────┘  └────┬─────┘    │  │   │  ┌────────────┐  │
 │  │         └─────-───────┴─────────────┘          │  │   │  │   Server   │  │
 │  │                   Virtual IP                   │  │   │  │   AMD64    │  │
 │  │    ┌──────────┐  ┌──────────┐  ┌──────────┐    │  │   │  └────────────┘  │
 │  │    │ Worker-1 │  │ Worker-2 │  │ Worker-3 │    │  │   │                  │
 │  │    │          │  │          │  │          │    │  │   └──────────────────┘
 │  │    └──────────┘  └──────────┘  └──────────┘    │  │
 │  └────────────────────────────────────────────────┘  │
 │                                                      │
 │  ┌─ PVE Host 2 ───────────────────────────────────┐  │
 │  │                                                │  │
 │  │  ┌──────────────────────────────────────────┐  │  │
 │  │  │  GPU Worker                              │  │  │
 │  │  │                                          │  │  │
 │  │  │  ┌──────────────┐  ┌──────────────────┐  │  │  │
 │  │  │  │  RTX 3060 Ti │  │  RTX 3060 12GB   │  │  │  │
 │  │  │  │  8GB (4x TS) │  │  (4x time-slice) │  │  │  │
 │  │  │  └──────────────┘  └──────────────────┘  │  │  │
 │  │  └──────────────────────────────────────────┘  │  │
 │  └────────────────────────────────────────────────┘  │
 └──────────────────────────────────────────────────────┘
```

---

## :gear: Advanced Configuration

<!-- L2 LoadBalancer -->
<details>
<summary><b>L2 LoadBalancer (CiliumLoadBalancerIPPool + CiliumL2AnnouncementPolicy)</b></summary>

<br>

Assign external IPs to `type: LoadBalancer` services and announce them via ARP
on the local network:

```hcl
cilium = {
  l2 = {
    ip_pools = [{
      name  = "svc-lb-pool"
      start = "192.168.97.100"
      stop  = "192.168.97.199"
    }]
    # Restrict L2 announcements to Proxmox nodes (have eth0 interface)
    node_selector = {
      "topology.kubernetes.io/region" = "homelab"
    }
  }
}
```

| Option          | Description                                                     | Default          |
| --------------- | --------------------------------------------------------------- | ---------------- |
| `ip_pools`      | List of IP ranges for LoadBalancer services (name, start, stop) | — (required)     |
| `interfaces`    | Network interfaces for ARP announcements                        | `["eth0"]`       |
| `node_selector` | Labels to filter which nodes can announce IPs                   | `{}` (all nodes) |

The module creates both the `CiliumLoadBalancerIPPool` and `CiliumL2AnnouncementPolicy`
as Talos inline manifests on control plane nodes. The Cilium Helm values must also have
`l2announcements.enabled: true` (included in the default values file).

**Important: `node_selector`** — If you have external bare-metal nodes (e.g., Raspberry Pi),
you should set `node_selector` to exclude them. External nodes may use a different network
interface name (e.g., `end0` instead of `eth0` due to UKI boot without `net.ifnames=0`),
which prevents L2 announcements from working. Use `topology.kubernetes.io/region` (set
automatically when `proxmox_csi` is enabled) or any other label present only on Proxmox nodes.

**Updating L2 config** — Talos inline manifests do not update Kubernetes resources that
already exist. If you change the L2 configuration (IP ranges, node selector, interfaces),
delete the existing resources and Talos will recreate them with the new config:

```bash
kubectl delete ciliuml2announcementpolicy l2policy
kubectl delete ciliumloadbalancerippool <pool-name>
# Talos recreates them automatically from the inline manifests
```

</details>

<!-- Gateway API -->
<details>
<summary><b>Gateway API and Cilium</b></summary>

<br>

Gateway API CRDs and Cilium are **complementary**, not duplicated:

- `gateway_api.enabled = true` installs the **CRD definitions** (Gateway, HTTPRoute, etc.) via Talos `extraManifests`
- Cilium with `gatewayAPI.enabled: true` (in its Helm values) acts as the **controller** that implements those CRDs

Without the CRDs installed, Cilium's Gateway API controller has nothing to reconcile.

**TLSRoute note**: Cilium 1.19 requires TLSRoute `v1alpha2` CRD (bug [#38420](https://github.com/cilium/cilium/issues/38420)), which is NOT in the Gateway API standard channel. Set `enable_tlsroute = true` to install it from the experimental channel. This will be unnecessary once Cilium supports TLSRoute `v1` (expected Cilium 1.20+).

</details>

<!-- Talos version compatibility -->
<details>
<summary><b>Talos version compatibility</b></summary>

<br>

| Talos    | Hostname method            | Notes                                                      |
| -------- | -------------------------- | ---------------------------------------------------------- |
| v1.11.x  | `machine.network.hostname` | Classic v1alpha1 config                                    |
| v1.12.x+ | `HostnameConfig` document  | Multi-doc format, `auto: off` to override provider default |

The module auto-detects the Talos minor version and uses the appropriate format.

</details>

<!-- Per-node extensions -->
<details>
<summary><b>Per-node extensions</b></summary>

<br>

By default, all Proxmox nodes share the same extensions (`qemu-guest-agent` + `talos_extensions`).
Nodes with specialized hardware can override extensions via the `talos_extensions` field
in the node definition. Each unique extension set creates its own schematic and ISO.

```hcl
nodes = {
  # Standard worker — uses default extensions (qemu-guest-agent)
  "worker-01" = {
    host_node     = "pve-01"
    machine_type  = "worker"
    ip            = "192.168.97.20"
    mac_address   = "BC:24:11:97:01:20"
    vm_id         = 4100
    cpu           = 4
    ram_dedicated = 8192
  }

  # GPU worker — gets its own schematic with NVIDIA extensions
  "gpu-worker" = {
    host_node     = "pve-02"
    machine_type  = "worker"
    ip            = "192.168.97.25"
    mac_address   = "BC:24:11:97:01:25"
    vm_id         = 4200
    cpu           = 8
    ram_dedicated = 16384
    talos_extensions = [
      "siderolabs/nonfree-kmod-nvidia-production",
      "siderolabs/nvidia-container-toolkit-production"
    ]
    config_patches = [<<-EOF
      machine:
        kernel:
          modules:
            - name: nvidia
            - name: nvidia_uvm
            - name: nvidia_drm
              parameters:
                - modeset=1
    EOF
    ]
    hostpci = [{
      device  = "hostpci0"
      mapping = "gpu-nvidia"
      pcie    = true
    }]
  }
}
```

This creates two separate ISOs:

- **Default** (`qemu-guest-agent`): downloaded to pve-01 for worker-01
- **NVIDIA** (`qemu-guest-agent` + NVIDIA drivers): downloaded to pve-02 for gpu-worker

Existing nodes are **not affected** when adding custom extensions to a new node.
The `lifecycle { ignore_changes = [disk[0].file_id] }` prevents VM recreation.

#### Available extensions

Common extensions for different use cases:

| Category         | Extension                                        | Purpose                           |
| ---------------- | ------------------------------------------------ | --------------------------------- |
| **GPU (NVIDIA)** | `siderolabs/nonfree-kmod-nvidia-production`      | NVIDIA proprietary kernel driver  |
|                  | `siderolabs/nvidia-container-toolkit-production` | NVIDIA container runtime          |
| **GPU (Intel)**  | `siderolabs/i915`                                | Intel GPU kernel modules          |
| **GPU (AMD)**    | `siderolabs/amdgpu`                              | AMD GPU firmware + kernel modules |
| **Storage**      | `siderolabs/iscsi-tools`                         | iSCSI (required by Longhorn)      |
|                  | `siderolabs/util-linux-tools`                    | Companion for iscsi-tools         |
|                  | `siderolabs/nfs-utils`                           | NFS with file locking             |
|                  | `siderolabs/zfs`                                 | ZFS filesystem                    |
| **Networking**   | `siderolabs/tailscale`                           | Tailscale mesh VPN                |
|                  | `siderolabs/cloudflared`                         | Cloudflare Tunnel                 |
| **Runtime**      | `siderolabs/gvisor`                              | gVisor sandbox runtime            |
|                  | `siderolabs/spin`                                | WebAssembly runtime               |

Full list: [github.com/siderolabs/extensions](https://github.com/siderolabs/extensions)

</details>

<!-- Per-node config patches -->
<details>
<summary><b>Per-node config patches</b></summary>

<br>

Individual nodes can receive additional Talos machine config patches via the
`config_patches` field. These are [strategic merge patches](https://www.talos.dev/latest/talos-guides/configuration/patching/)
applied on top of the base machine configuration, following the same mechanism
as `talosctl --config-patch`.

```hcl
"gpu-worker" = {
  # ... host_node, ip, etc.
  config_patches = [<<-EOF
    machine:
      kernel:
        modules:
          - name: nvidia
      nodeLabels:
        nvidia.com/gpu: "true"
      sysctls:
        net.core.rmem_max: "7500000"
  EOF
  ]
}
```

Common use cases:

- **Kernel modules**: `machine.kernel.modules` — load drivers not auto-detected
- **Node labels**: `machine.nodeLabels`
- **Node taints**: `machine.kubelet.extraConfig.registerWithTaints` (see below)
- **Sysctls**: `machine.sysctls`
- **Environment variables**: `machine.env`
- **Extra files**: `machine.files`

Multiple patches per node are supported and merged in order.

#### Node taints

**Do NOT use `machine.nodeTaints`** — the Talos node taint controller modifies taints
via the Kubernetes API, which is blocked by the `NodeRestriction` admission controller.

Use `machine.kubelet.extraConfig.registerWithTaints` instead, which applies taints
during kubelet registration (before `NodeRestriction` kicks in):

```hcl
config_patches = [<<-EOF
  machine:
    kubelet:
      extraConfig:
        registerWithTaints:
          - key: arch
            value: arm64
            effect: NoSchedule
EOF
]
```

**Note**: `registerWithTaints` only takes effect during **initial node registration**.
If the node is already registered, apply the taint manually first:

```bash
kubectl taint nodes <node-name> arch=arm64:NoSchedule
```

The config ensures the taint persists across node reinstallations or re-registrations.

</details>

<!-- GPU passthrough -->
<details>
<summary><b>GPU passthrough</b></summary>

<br>

Proxmox nodes support PCI device passthrough for GPU workloads via the `hostpci`
field on individual nodes.

#### Proxmox host prerequisites

Before adding a GPU passthrough node, the Proxmox host must be configured:

1. **IOMMU enabled in BIOS**: `VT-d` (Intel) or `AMD-Vi` (AMD)
2. **Kernel parameter**: Add `intel_iommu=on` or `amd_iommu=on` in `/etc/default/grub`, then `update-grub` and reboot
3. **GPU driver blacklisted on host**: Prevent the host from claiming the GPU
   ```bash
   # /etc/modprobe.d/blacklist-gpu.conf
   blacklist nouveau
   blacklist nvidia
   ```
4. **VFIO modules loaded**: Add to `/etc/modules`
   ```
   vfio
   vfio_iommu_type1
   vfio_pci
   ```

#### PCI passthrough modes

There are two ways to reference a PCI device. Use **one** of `mapping` or `id`:

##### Resource mapping (recommended)

Resource mappings allow non-root API users to use PCI passthrough. Since Proxmox 8,
this is the **only option** unless the API user is `root@pam`.

1. Create a resource mapping in **Datacenter > Resource Mappings > PCI Devices > Add**
2. Give it a name (e.g., `gpu-nvidia`) and select the PCI device
3. Reference it with `mapping`:

```hcl
hostpci = [{
  device  = "hostpci0"
  mapping = "gpu-nvidia"
  pcie    = true
}]
```

##### Direct PCI ID (root only)

If the API user is `root@pam`, you can reference the PCI device directly:

```hcl
hostpci = [{
  device = "hostpci0"
  id     = "0000:01:00.0"
  pcie   = true
  rombar = true
}]
```

#### Finding the PCI device ID

On the Proxmox host:

```bash
lspci -nn | grep -i 'vga\|nvidia\|amd.*radeon'
# Example output: 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ...
```

#### Talos extensions and kernel modules for GPU

If the GPU is **NVIDIA**, add the driver extensions and kernel modules to the node:

```hcl
talos_extensions = [
  "siderolabs/nonfree-kmod-nvidia-production",
  "siderolabs/nvidia-container-toolkit-production"
]
config_patches = [<<-EOF
  machine:
    kernel:
      modules:
        - name: nvidia
        - name: nvidia_uvm
        - name: nvidia_drm
          parameters:
            - modeset=1
EOF
]
```

The extensions provide the kernel modules, but Talos doesn't auto-load them via
`modules.alias`. The `config_patches` with `machine.kernel.modules` tells Talos
to load them explicitly at boot.

For **Intel** GPUs use `siderolabs/i915` (+ `siderolabs/mei` for Arc GPUs).
For **AMD** GPUs use `siderolabs/amdgpu`.

#### NVIDIA Device Plugin

Enable the device plugin to expose `nvidia.com/gpu` resources to Kubernetes:

```hcl
nvidia_device_plugin = {
  enabled = true
  version = "0.18.2"
}
```

The module automatically:

- Deploys the NVIDIA Device Plugin Helm chart with Talos-specific defaults
- Creates the `nvidia` RuntimeClass (via Talos inline manifest on control planes)
- Configures CDI hook path (`/usr/local/bin/nvidia-cdi-hook`) for Talos
- Sets node affinity to schedule only on nodes with `nvidia.com/gpu.present=true` label

Make sure GPU nodes include the `nvidia.com/gpu.present` label in their `config_patches`:

```yaml
machine:
  nodeLabels:
    nvidia.com/gpu.present: "true"
```

#### GPU time-slicing

GPU time-slicing allows multiple pods to share a single GPU via CUDA time-slicing.
Each pod gets a virtual GPU replica with full access to the GPU memory, but the
GPU interleaves execution between pods.

To enable time-slicing, pass a config map via the device plugin's `values`:

```hcl
nvidia_device_plugin = {
  enabled = true
  values = [yamlencode({
    config = {
      map = {
        default = yamlencode({
          version = "v1"
          sharing = {
            timeSlicing = {
              renameByDefault = false
              resources = [{
                name     = "nvidia.com/gpu"
                replicas = 4
              }]
            }
          }
        })
      }
      default = "default"
    }
  })]
}
```

With `replicas = 4`, each physical GPU appears as 4 `nvidia.com/gpu` resources.
Pods request `nvidia.com/gpu: 1` as usual, but up to 4 pods can share the GPU.

| Option                  | Description                                                                 | Default |
| ----------------------- | --------------------------------------------------------------------------- | ------- |
| `time_slicing_replicas` | Number of virtual GPU slices per physical GPU. `0` disables time-slicing.   | `0`     |
| `rename_by_default`     | If `true`, advertise as `nvidia.com/gpu.shared` instead of `nvidia.com/gpu` | `false` |

When `rename_by_default = true`, pods must request `nvidia.com/gpu.shared: 1` instead
of `nvidia.com/gpu: 1`. This is useful when mixing exclusive and shared GPUs in the
same cluster — exclusive GPUs keep `nvidia.com/gpu` while shared ones use `nvidia.com/gpu.shared`.

**Important**: time-slicing does NOT provide memory isolation. All pods share the
full GPU memory. If a pod exceeds available memory, all pods on that GPU may crash
with OOM errors. Use `replicas` conservatively based on your workload's memory needs.

#### Verifying GPU access

After deploying, verify the GPU is detected:

```bash
# Check node capacity
kubectl describe node <gpu-node> | grep nvidia

# Run nvidia-smi test pod
kubectl run nvidia-smi --rm -it --restart=Never \
  --image=nvcr.io/nvidia/cuda:12.8.1-base-ubi8 \
  --overrides='{"spec":{"runtimeClassName":"nvidia","containers":[{"name":"nvidia-smi","image":"nvcr.io/nvidia/cuda:12.8.1-base-ubi8","command":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":1}}}]}}' \
  — nvidia-smi
```

#### Complete GPU node example

```hcl
# Variables
nvidia_device_plugin = { enabled = true }

# Node definition
nodes = {
  "gpu-worker-01" = {
    host_node     = "pve-02"
    machine_type  = "worker"
    ip            = "192.168.97.22"
    mac_address   = "BC:24:11:97:01:22"
    vm_id         = 4102
    cpu           = 4
    ram_dedicated = 8192
    datastore_id  = "local-lvm"
    talos_extensions = [
      "siderolabs/nonfree-kmod-nvidia-production",
      "siderolabs/nvidia-container-toolkit-production"
    ]
    config_patches = [<<-EOF
      machine:
        kernel:
          modules:
            - name: nvidia
            - name: nvidia_uvm
            - name: nvidia_drm
              parameters:
                - modeset=1
        nodeLabels:
          nvidia.com/gpu.present: "true"
    EOF
    ]
    hostpci = [{
      device  = "hostpci0"
      mapping = "gpu-nvidia"
      pcie    = true
    }]
  }
}
```

</details>

<!-- Proxmox CSI Plugin -->
<details>
<summary><b>Proxmox CSI Plugin</b></summary>

<br>

The [Proxmox CSI Plugin](https://github.com/sergelogvinov/proxmox-csi-plugin) enables
Kubernetes to create PersistentVolumes directly on Proxmox storage backends (LVM, ZFS,
Ceph, NFS). This is a lighter alternative to Longhorn — it uses the storage you already
have in Proxmox instead of replicating data across nodes.

#### Prerequisites

1. **Proxmox cluster**: Your Proxmox instance must be clustered (even a single node can
   be clustered with itself via `pvecm create <name>`)
2. **API token**: Create a dedicated user, role, and token with the required permissions:

   ```bash
   # On the Proxmox host
   pveum user add kubernetes-csi@pve
   pveum role add CSI -privs "VM.Audit VM.Config.Disk Datastore.Allocate Datastore.AllocateSpace Datastore.Audit"
   pveum aclmod / -user kubernetes-csi@pve -role CSI
   pveum user token add kubernetes-csi@pve csi -privsep 0
   ```

   Required privileges:
   | Privilege | Purpose |
   | --- | --- |
   | `VM.Audit` | List VMs to map nodes to Proxmox hosts |
   | `VM.Config.Disk` | Attach/detach disks to VMs |
   | `Datastore.Audit` | List available storage pools and capacity |
   | `Datastore.Allocate` | Create and delete volumes |
   | `Datastore.AllocateSpace` | Allocate space on storage pools |

   **Important**: `PVEVMAdmin` alone is NOT sufficient — it lacks `Datastore.Audit` and
   `Datastore.Allocate*` which are required for the CSI controller to discover and
   provision storage.

#### Configuration

```hcl
proxmox_csi = {
  enabled      = true
  version      = "0.5.5"                              # Helm chart version
  proxmox_url  = "https://pve-01.example.com:8006/api2/json"
  token_id     = "kubernetes-csi@pve!csi"              # API token ID
  token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # API token secret
  region       = "my-cluster"                          # Proxmox cluster name (pvecm status)
  insecure     = true                                  # optional (default: false) — skip TLS verification

  # Define StorageClasses backed by Proxmox storage pools
  storage_classes = [
    {
      name           = "proxmox-zfs"        # Kubernetes StorageClass name
      storage        = "local-zfs"          # Proxmox storage ID
      reclaim_policy = "Delete"             # optional (default: "Delete") — Delete or Retain
      fstype         = "ext4"               # optional (default: "ext4") — ext4 or xfs
      cache          = "none"               # optional (default: "none") — none, directsync, writeback, writethrough
      ssd            = true                 # optional (default: false) — enable SSD optimizations
    },
    {
      name    = "proxmox-lvm"
      storage = "local-lvm"
      fstype  = "xfs"
    }
  ]
}
```

#### Topology-aware scheduling

The Proxmox CSI plugin **requires** topology labels on nodes to map Kubernetes nodes to Proxmox hosts and create volumes on the correct storage backend. The module sets these labels automatically on all Proxmox nodes when `proxmox_csi` is enabled:

- `topology.kubernetes.io/region` = Proxmox cluster name (from `region` variable)
- `topology.kubernetes.io/zone` = Proxmox host name (from `host_node` in the node definition)

Without these labels, the CSI plugin cannot determine where to provision storage. Each StorageClass is bound to specific Proxmox storage — if the storage only exists on one host, pods using that StorageClass will only schedule on nodes running on that host.

#### PodSecurity

The CSI node plugin requires privileged access (`hostPath` volumes, `SYS_ADMIN` capability).
The module automatically creates the `csi-proxmox` namespace with the
`pod-security.kubernetes.io/enforce: privileged` label via Talos inline manifest on
control plane nodes.

#### Usage

After deploying, use the StorageClass in your PVCs:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes: ["ReadWriteOnce"]
  storageClassName: proxmox-zfs
  resources:
    requests:
      storage: 10Gi
```

#### Proxmox CSI vs Longhorn

| Feature                  | Proxmox CSI                               | Longhorn                             |
| ------------------------ | ----------------------------------------- | ------------------------------------ |
| **Storage backend**      | Proxmox (LVM, ZFS, Ceph, NFS)             | In-cluster distributed               |
| **Replication**          | Depends on backend (Ceph = yes, LVM = no) | Built-in (configurable replicas)     |
| **Performance**          | Native — no overhead                      | Network overhead for replication     |
| **Snapshots**            | Via Proxmox                               | Built-in                             |
| **Cross-node migration** | Only with shared storage (Ceph, NFS)      | Automatic                            |
| **Dependencies**         | Proxmox API access                        | iSCSI extensions on Talos            |
| **Best for**             | Single-node or Ceph-backed clusters       | Multi-node HA without shared storage |

</details>

<!-- External nodes -->
<details>
<summary><b>External nodes (bare-metal)</b></summary>

<br>

The module supports adding bare-metal nodes (e.g., Raspberry Pi, x86 servers) that
are not managed by Proxmox. These nodes join the cluster as workers or control planes.
They must be pre-booted with the correct Talos image.

```hcl
external_nodes = {
  # Raspberry Pi 5 — requires overlay for SBC boot support
  "rpi-01" = {
    ip   = "192.168.97.50"
    arch = "arm64"
    overlay = {
      name  = "rpi_5"
      image = "siderolabs/sbc-rpi_5"
    }
    talos_extensions = [
      "siderolabs/iscsi-tools",
      "siderolabs/nfs-utils"
    ]
    config_patches = [<<-EOF
      machine:
        nodeLabels:
          node.kubernetes.io/arch: arm64
        kubelet:
          extraConfig:
            registerWithTaints:
              - key: arch
                value: arm64
                effect: NoSchedule
    EOF
    ]
  }

  # x86 bare-metal server — no overlay needed
  "server-01" = {
    ip   = "192.168.97.60"
    arch = "amd64"
    talos_extensions = [
      "siderolabs/iscsi-tools",
      "siderolabs/util-linux-tools"
    ]
  }
}

# Default extensions for nodes that don't specify talos_extensions
external_talos_extensions = ["siderolabs/iscsi-tools"]
```

Each external node with different extensions/overlay generates its own schematic and
image, just like Proxmox nodes. The `external_talos_extensions` variable serves as
the default for nodes that don't specify `talos_extensions`.

#### SBC overlays (Raspberry Pi, etc.)

Single-board computers (SBCs) like Raspberry Pi require a **board overlay** in the
Talos schematic for proper boot support. Without the overlay, the device won't boot
(stuck at bootloader).

**Important**: SBC nodes with overlays automatically skip `extraKernelArgs` (incompatible
with UKI boot used by SBC overlays).

| Board          | Overlay name   | Image                         |
| -------------- | -------------- | ----------------------------- |
| Raspberry Pi 5 | `rpi_5`        | `siderolabs/sbc-rpi_5`        |
| Raspberry Pi 4 | `rpi_4`        | `siderolabs/sbc-rpi_4`        |
| Banana Pi M64  | `bananapi_m64` | `siderolabs/sbc-bananapi_m64` |
| Jetson Nano    | `jetson_nano`  | `siderolabs/sbc-jetson_nano`  |
| Rock Pi 4      | `rockpi_4`     | `siderolabs/sbc-rockpi_4`     |
| Pine64         | `pine64`       | `siderolabs/sbc-pine64`       |

The naming convention is always `name = "<board>"` and `image = "siderolabs/sbc-<board>"`.
To find the correct board name:

1. Go to [factory.talos.dev](https://factory.talos.dev) and select your Talos version
2. Choose **SBC** as target — the board list shows all supported overlays
3. The board name shown in the factory is the overlay `name`, prefix with `siderolabs/sbc-` for `image`

Full list: [Talos SBC support](https://www.talos.dev/latest/talos-guides/install/single-board-computers/)

**Note**: SBCs cannot boot from ISO images. Always use the `raw_xz` image and flash
it to the SD card / eMMC / USB drive.

#### Getting the image before apply

The `external_image_urls` output provides download links (ISO, raw.xz, raw.zst)
for each external node. Since it uses a data source, the URLs are available
during `tofu plan`:

```bash
# 1. Add external_nodes to your tfvars
# 2. Run plan — the URLs appear in planned outputs
tofu plan

# The output shows (each node gets its own URLs based on its extensions + overlay):
# + external_image_urls = {
#     "rpi-01" = {
#       raw_xz  = "https://factory.talos.dev/image/<schematic>/<version>/metal-arm64.raw.xz"
#       ...
#     }
#   }

# 3. Download the raw image and flash to SD card
wget <raw_xz_url> -O talos-rpi5.raw.xz

# Option A: Raspberry Pi Imager — select "Use custom" and pick the .raw.xz file
# Option B: dd
xz -d talos-rpi5.raw.xz
sudo dd if=talos-rpi5.raw of=/dev/sdX bs=4M status=progress

# 4. Boot the device
# 5. Apply to push config and join the cluster
tofu apply
```

External nodes use separate Image Factory schematics (no `qemu-guest-agent` needed
for bare metal). Nodes sharing the same extensions + overlay reuse the same schematic.

</details>

<!-- Troubleshooting -->
<details>
<summary><b>Troubleshooting</b></summary>

<br>

#### ISO download timeout (HTTP 596)

When using **custom extensions** (per-node or new schematics), Talos Image Factory
builds the image on demand. The first request for a new schematic may take several
minutes while the factory compiles the image. Proxmox will timeout waiting for the
download with an `HTTP 596 - Connection timed out` error.

**Solution**: Simply re-run `tofu apply`. The factory caches built images, so
subsequent downloads complete quickly. The `upload_timeout` is set to 600s (10 minutes)
to accommodate slow builds.

If the problem persists, verify the schematic is valid:

```bash
# Check if the image URL responds (replace with your schematic ID and version)
curl -sI "https://factory.talos.dev/image/<schematic_id>/<talos_version>/nocloud-amd64.iso" | head -5
```

A `200 OK` response means the image is cached and ready. A `404` means the schematic
or version is invalid.

</details>

---

## :recycle: Lifecycle

### Version Compatibility Matrix

Each row is a validated combination of component versions that has been tested and confirmed to work together. The module's [upgrade procedures](UPGRADE.md) support moving between these stacks sequentially (v1 → v2 → v3 → v4). We recommend using one of these combinations to avoid compatibility issues.

| Stack  | Talos       | Kubernetes  | Cilium     | Metrics Server | Cert Manager | Gateway API | NVIDIA Device Plugin | Proxmox CSI | Longhorn   |
| ------ | ----------- | ----------- | ---------- | -------------- | ------------ | ----------- | -------------------- | ----------- | ---------- |
| **v4** | **v1.12.5** | **v1.35.2** | 1.19.1     | 0.8.0          | 1.20.0       | v1.4.0      | **0.19.0**           | 0.18.0      | 1.11.0     |
| **v3** | v1.11.6     | **v1.34.5** | 1.19.1     | 0.8.0          | 1.20.0       | v1.4.0      | 0.18.2               | 0.18.0      | 1.11.0     |
| **v2** | v1.11.6     | **v1.33.9** | **1.19.1** | 0.8.0          | **1.20.0**   | **v1.4.0**  | 0.18.2               | 0.18.0      | **1.11.0** |
| **v1** | v1.11.0     | v1.32.8     | 1.18.1     | 0.8.0          | 1.18.2       | v1.3.0      | 0.18.2               | 0.18.0      | 1.7.3      |

> **Note**: Metrics Server and Proxmox CSI show app versions. The module configures Helm chart versions which differ: Metrics Server chart 3.13.x = app 0.8.x, Proxmox CSI chart 0.5.5 = app 0.18.0.

### Upgrades

The module supports three types of upgrades:

- **Talos OS rolling upgrades**: Per-node, via `talos_version_target` + `update` flag. Nodes reboot one at a time.
- **Stack upgrades**: Kubernetes version + Helm chart versions, via `tofu apply`. Zero downtime, declarative.
- **VM resource changes**: RAM/CPU changes via `ram_dedicated`/`cpu` in tfvars. In-place update + rolling reboot.

See **[UPGRADE.md](UPGRADE.md)** for step-by-step procedures, breaking changes reference, and known issues.

---

## :open_file_folder: Examples

Complete working examples are available in the [`examples/`](examples/) directory:

| Example                                          | Description                                                           |
| ------------------------------------------------ | --------------------------------------------------------------------- |
| [`basic`](examples/basic/)                       | Minimal 3 CP + 2 worker cluster                                       |
| [`cilium-l2`](examples/cilium-l2/)               | Cilium L2 LoadBalancer + Gateway API                                  |
| [`gpu-passthrough`](examples/gpu-passthrough/)   | NVIDIA GPU passthrough with device plugin                             |
| [`gpu-time-slicing`](examples/gpu-time-slicing/) | GPU sharing via CUDA time-slicing (1 GPU -> N virtual GPUs)           |
| [`proxmox-csi`](examples/proxmox-csi/)           | PersistentVolumes backed by Proxmox storage (LVM, ZFS, Ceph)          |
| [`external-nodes`](examples/external-nodes/)     | Raspberry Pi ARM64 bare-metal workers                                 |
| [`full-stack`](examples/full-stack/)             | All features: GPU, Proxmox CSI, external nodes, Gateway API, Longhorn |

---

## :scroll: License

Distributed under the [Apache License 2.0](LICENSE).

## Acknowledgements

- [Talos Linux](https://www.talos.dev/) — Secure, immutable, minimal OS for Kubernetes by SideroLabs
- [Proxmox VE](https://www.proxmox.com/) — Open-source server virtualization platform
- [Cilium](https://cilium.io/) — eBPF-based networking, observability, and security for Kubernetes
