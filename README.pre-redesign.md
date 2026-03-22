# terraform-proxmox-k8s

OpenTofu/Terraform module to deploy a fully operational Talos Linux Kubernetes cluster on Proxmox VE.

## Features

- Provisions VMs on Proxmox with Talos Linux ISO from Image Factory
- Generates Talos machine configs with custom schematics (extensions baked in)
- Bootstraps the cluster and outputs kubeconfig + talosconfig
- Installs CNI (Cilium) and optionally Metrics Server, Cert Manager, Longhorn
- Supports control plane VIP for HA
- Gateway API CRDs with simple toggle (`gateway_api.enabled = true`)
- Compatible with **Talos 1.11** and **1.12+** (auto-detects hostname config format)
- Rolling Talos OS upgrades with per-node control
- Post-deploy health check validates cluster readiness
- CNI disabled in Talos (Cilium installed via Helm)
- kube-proxy disabled by default (replaced by Cilium eBPF)
- **Per-node extension overrides** (e.g., NVIDIA GPU extensions only on GPU nodes)
- **GPU passthrough** via PCI device passthrough (hostpci)
- **External bare-metal nodes** (e.g., Raspberry Pi ARM) without Proxmox

## Usage

```hcl
module "cluster" {
  source = "../../modules/terraform-proxmox-k8s"

  cluster = {
    name       = "homelab"
    endpoint   = "192.168.97.1"
    virtual_ip = "192.168.97.1"
  }

  talos_version      = "v1.12.5"
  kubernetes_version = "1.35.2"

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

  cilium         = { version = "1.19.1" }
  metrics_server = { version = "3.13.0" }
  cert_manager   = { version = "1.20.0" }

  gateway_api = {
    enabled         = true
    version         = "1.4.0"
    enable_tlsroute = true # required for Cilium 1.19
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

## Requirements

| Name | Version |
| --- | --- |
| Terraform / OpenTofu | >= 1.10.0, < 2.0.0 |
| [bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox) | >= 0.68.0 |
| [siderolabs/talos](https://registry.terraform.io/providers/siderolabs/talos) | >= 0.10.0 |
| [hashicorp/helm](https://registry.terraform.io/providers/hashicorp/helm) | >= 2.0.0 |
| [hashicorp/http](https://registry.terraform.io/providers/hashicorp/http) | >= 3.0.0 |
| [hashicorp/time](https://registry.terraform.io/providers/hashicorp/time) | >= 0.9.0 |

Tested with OpenTofu 1.11.5. Tests require OpenTofu >= 1.11 (mock provider bug in 1.10).

### Tested provider versions

| Provider | Tested versions | Minimum |
| --- | --- | --- |
| bpg/proxmox | 0.98.1 | >= 0.68.0 |
| siderolabs/talos | 0.10.1 | >= 0.10.0 |
| hashicorp/helm | 2.17.0, 3.1.1 | >= 2.0.0 |
| hashicorp/http | 3.5.0 | >= 3.0.0 |
| hashicorp/time | 0.13.1 | >= 0.9.0 |

> **Helm provider 2.x vs 3.x**: The module is compatible with both. The 3.x
> breaking changes (`kubernetes` block → nested object, `set` blocks → lists)
> only affect the provider configuration in the root module, not this module's
> resources. See the [v3 upgrade guide](https://github.com/hashicorp/terraform-provider-helm/blob/main/docs/guides/v3-upgrade-guide.md).

## Inputs

| Name | Description | Type | Default | Required |
| --- | --- | --- | --- | --- |
| `cluster` | Cluster configuration (name, endpoint, virtual_ip, allow_scheduling_on_control_planes) | `object` | — | yes |
| `nodes` | Map of node configurations (host_node, machine_type, ip, mac_address, vm_id, cpu, ram_dedicated, disk_size, datastore_id, update, talos_extensions, config_patches, hostpci) | `map(object)` | — | yes |
| `talos_version` | Talos OS version (e.g. `v1.12.5`) | `string` | — | yes |
| `kubernetes_version` | Kubernetes version (e.g. `1.35.2`) | `string` | — | yes |
| `talos_extensions` | Additional Talos extensions for all Proxmox nodes (`qemu-guest-agent` always included) | `list(string)` | `[]` | no |
| `kernel_args` | Extra kernel arguments | `list(string)` | `["net.ifnames=0"]` | no |
| `gateway_api` | Gateway API CRDs (enabled, version, enable_tlsroute) | `object` | `{ enabled = false }` | no |
| `extra_manifests` | URLs to additional manifests applied via Talos `extraManifests` on control planes | `list(string)` | `[]` | no |
| `cilium` | Cilium CNI configuration (version, values) | `object` | `{ version = "1.19.1" }` | no |
| `metrics_server` | Metrics Server configuration (enabled, version, values) | `object` | `{ enabled = true, version = "3.13.0" }` | no |
| `cert_manager` | Cert Manager configuration (enabled, version, values) | `object` | `{ enabled = true, version = "1.20.0" }` | no |
| `longhorn` | **EXPERIMENTAL** — Longhorn storage configuration (enabled, version, values). Not validated in production. | `object` | `{ enabled = false, version = "1.11.0" }` | no |
| `nvidia_device_plugin` | NVIDIA Device Plugin for GPU workloads (enabled, version, values, time_slicing_replicas, rename_by_default) | `object` | `{ enabled = false, version = "0.18.2" }` | no |
| `proxmox_csi` | Proxmox CSI Plugin for PV storage (enabled, version, proxmox_url, token_id, token_secret, region, insecure, storage_classes, values) | `object` | `{ enabled = false, version = "0.5.5" }` | no |
| `external_nodes` | External bare-metal nodes not managed by Proxmox (machine_type, ip, arch, platform, kernel_args, update, talos_extensions, config_patches, overlay) | `map(object)` | `{}` | no |
| `external_talos_extensions` | Default Talos system extensions for external nodes (overridden by per-node talos_extensions) | `list(string)` | `[]` | no |
| `talos_version_target` | Target Talos version for rolling upgrade (set only during upgrades) | `string` | `null` | no |

## Outputs

| Name | Description | Sensitive |
| --- | --- | --- |
| `kubeconfig_raw` | Raw kubeconfig content | yes |
| `kubeconfig_host` | Kubernetes API server host | yes |
| `kubeconfig_client_certificate` | Kubernetes client certificate (base64) | yes |
| `kubeconfig_client_key` | Kubernetes client key (base64) | yes |
| `kubeconfig_ca_certificate` | Kubernetes CA certificate (base64) | yes |
| `talosconfig_raw` | Raw talosconfig content | yes |
| `client_configuration` | Talos client configuration for API calls | yes |
| `schematic_id` | Talos Image Factory schematic ID (default) | no |
| `control_plane_ips` | Control plane node IPs | no |
| `worker_ips` | Worker node IPs | no |
| `endpoints` | Talos API endpoints | no |
| `external_schematic_ids` | Talos Image Factory schematic IDs for external nodes (per node) | no |
| `external_image_urls` | Image download URLs for external nodes (ISO, raw) | no |

## Architecture

```
                    ┌─────────────────────────────────┐
                    │         Talos Image Factory      │
                    │   (builds ISO with extensions)   │
                    └──────────────┬──────────────────┘
                                   │ ISO / raw image
                    ┌──────────────▼──────────────────┐
                    │          Proxmox VE              │
                    │                                  │
                    │  ┌──────┐ ┌──────┐ ┌──────┐     │
                    │  │ CP-1 │ │ CP-2 │ │ CP-3 │     │  Control Planes
                    │  └──┬───┘ └──┬───┘ └──┬───┘     │  (etcd + API server)
                    │     │   VIP  │        │         │
                    │  ┌──▼───┐ ┌──▼───┐ ┌──▼────┐   │
                    │  │ W-1  │ │ W-2  │ │W-GPU  │   │  Workers
                    │  └──────┘ └──────┘ └───────┘   │  (GPU passthrough)
                    └────────────────┬────────────────┘
                                     │ Talos API
                              ┌──────▼──────┐
                              │  RPi / ARM  │  External nodes
                              │  (bare-metal)│  (not on Proxmox)
                              └─────────────┘
```

The module:
1. Creates schematics at Talos Image Factory with your extensions (per-node if overridden)
2. Downloads the ISO to each Proxmox node
3. Creates VMs booting from the ISO
4. Generates and applies Talos machine configs
5. Bootstraps the first control plane
6. Installs Cilium CNI and optional components (Metrics Server, Cert Manager, Longhorn)
7. Runs a health check to validate cluster readiness
8. Outputs kubeconfig and talosconfig

## Components

Essential Kubernetes components deployed automatically as part of `tofu apply`:

| Component | Description | Deployed via |
| --- | --- | --- |
| **Cilium CNI** | High-performance CNI plugin using eBPF. Replaces kube-proxy, provides native routing, L2 announcements for LoadBalancer services, and Gateway API support. | Helm |
| **Metrics Server** *(optional, enabled by default)* | Collects container resource metrics (CPU/memory) from kubelets, enabling HPA/VPA. Uses `--kubelet-insecure-tls` for Talos compatibility. | Helm |
| **Cert Manager** *(optional, enabled by default)* | Automates TLS certificate lifecycle. Supports DNS01 validation with Cloudflare for wildcard certificates. | Helm |
| **Longhorn** *(optional)* | Distributed block storage providing replicated persistent volumes. Supports snapshots and backups. Disabled by default. | Helm |
| **NVIDIA Device Plugin** *(optional)* | Exposes `nvidia.com/gpu` resources to Kubernetes, enabling GPU scheduling. Required for GPU passthrough nodes. Disabled by default. | Helm |
| **Proxmox CSI Plugin** *(optional)* | Creates PersistentVolumes backed by Proxmox storage (LVM, ZFS, Ceph). Alternative to Longhorn — uses existing Proxmox storage instead of in-cluster replication. Disabled by default. | Helm (OCI) |

### L2 LoadBalancer (CiliumLoadBalancerIPPool + CiliumL2AnnouncementPolicy)

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

| Option | Description | Default |
| --- | --- | --- |
| `ip_pools` | List of IP ranges for LoadBalancer services (name, start, stop) | — (required) |
| `interfaces` | Network interfaces for ARP announcements | `["eth0"]` |
| `node_selector` | Labels to filter which nodes can announce IPs | `{}` (all nodes) |

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

### Gateway API and Cilium

Gateway API CRDs and Cilium are **complementary**, not duplicated:
- `gateway_api.enabled = true` installs the **CRD definitions** (Gateway, HTTPRoute, etc.) via Talos `extraManifests`
- Cilium with `gatewayAPI.enabled: true` (in its Helm values) acts as the **controller** that implements those CRDs

Without the CRDs installed, Cilium's Gateway API controller has nothing to reconcile.

**TLSRoute note**: Cilium 1.19 requires TLSRoute `v1alpha2` CRD (bug [#38420](https://github.com/cilium/cilium/issues/38420)), which is NOT in the Gateway API standard channel. Set `enable_tlsroute = true` to install it from the experimental channel. This will be unnecessary once Cilium supports TLSRoute `v1` (expected Cilium 1.20+).

## Talos version compatibility

| Talos | Hostname method | Notes |
| --- | --- | --- |
| v1.11.x | `machine.network.hostname` | Classic v1alpha1 config |
| v1.12.x+ | `HostnameConfig` document | Multi-doc format, `auto: off` to override provider default |

The module auto-detects the Talos minor version and uses the appropriate format.

## Per-node extensions

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

### Available extensions

Common extensions for different use cases:

| Category | Extension | Purpose |
| --- | --- | --- |
| **GPU (NVIDIA)** | `siderolabs/nonfree-kmod-nvidia-production` | NVIDIA proprietary kernel driver |
| | `siderolabs/nvidia-container-toolkit-production` | NVIDIA container runtime |
| **GPU (Intel)** | `siderolabs/i915` | Intel GPU kernel modules |
| **GPU (AMD)** | `siderolabs/amdgpu` | AMD GPU firmware + kernel modules |
| **Storage** | `siderolabs/iscsi-tools` | iSCSI (required by Longhorn) |
| | `siderolabs/util-linux-tools` | Companion for iscsi-tools |
| | `siderolabs/nfs-utils` | NFS with file locking |
| | `siderolabs/zfs` | ZFS filesystem |
| **Networking** | `siderolabs/tailscale` | Tailscale mesh VPN |
| | `siderolabs/cloudflared` | Cloudflare Tunnel |
| **Runtime** | `siderolabs/gvisor` | gVisor sandbox runtime |
| | `siderolabs/spin` | WebAssembly runtime |

Full list: [github.com/siderolabs/extensions](https://github.com/siderolabs/extensions)

## Per-node config patches

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

### Node taints

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

## GPU passthrough

Proxmox nodes support PCI device passthrough for GPU workloads via the `hostpci`
field on individual nodes.

### Proxmox host prerequisites

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

### PCI passthrough modes

There are two ways to reference a PCI device. Use **one** of `mapping` or `id`:

#### Resource mapping (recommended)

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

#### Direct PCI ID (root only)

If the API user is `root@pam`, you can reference the PCI device directly:

```hcl
hostpci = [{
  device = "hostpci0"
  id     = "0000:01:00.0"
  pcie   = true
  rombar = true
}]
```

### Finding the PCI device ID

On the Proxmox host:

```bash
lspci -nn | grep -i 'vga\|nvidia\|amd.*radeon'
# Example output: 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation ...
```

### Talos extensions and kernel modules for GPU

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

### NVIDIA Device Plugin

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

### GPU time-slicing

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

| Option | Description | Default |
| --- | --- | --- |
| `time_slicing_replicas` | Number of virtual GPU slices per physical GPU. `0` disables time-slicing. | `0` |
| `rename_by_default` | If `true`, advertise as `nvidia.com/gpu.shared` instead of `nvidia.com/gpu` | `false` |

When `rename_by_default = true`, pods must request `nvidia.com/gpu.shared: 1` instead
of `nvidia.com/gpu: 1`. This is useful when mixing exclusive and shared GPUs in the
same cluster — exclusive GPUs keep `nvidia.com/gpu` while shared ones use `nvidia.com/gpu.shared`.

**Important**: time-slicing does NOT provide memory isolation. All pods share the
full GPU memory. If a pod exceeds available memory, all pods on that GPU may crash
with OOM errors. Use `replicas` conservatively based on your workload's memory needs.

### Verifying GPU access

After deploying, verify the GPU is detected:

```bash
# Check node capacity
kubectl describe node <gpu-node> | grep nvidia

# Run nvidia-smi test pod
kubectl run nvidia-smi --rm -it --restart=Never \
  --image=nvcr.io/nvidia/cuda:12.8.1-base-ubi8 \
  --overrides='{"spec":{"runtimeClassName":"nvidia","containers":[{"name":"nvidia-smi","image":"nvcr.io/nvidia/cuda:12.8.1-base-ubi8","command":["nvidia-smi"],"resources":{"limits":{"nvidia.com/gpu":1}}}]}}' \
  -- nvidia-smi
```

### Complete GPU node example

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

## Proxmox CSI Plugin

The [Proxmox CSI Plugin](https://github.com/sergelogvinov/proxmox-csi-plugin) enables
Kubernetes to create PersistentVolumes directly on Proxmox storage backends (LVM, ZFS,
Ceph, NFS). This is a lighter alternative to Longhorn — it uses the storage you already
have in Proxmox instead of replicating data across nodes.

### Prerequisites

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

### Configuration

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

### Topology-aware scheduling

The module automatically sets topology labels on all Proxmox nodes when `proxmox_csi`
is enabled:

- `topology.kubernetes.io/region` = Proxmox cluster name (`region`)
- `topology.kubernetes.io/zone` = Proxmox node name (`host_node`)

This ensures PVs are created on the correct Proxmox node where the pod is scheduled.
Each StorageClass is bound to specific Proxmox storage — if the storage only exists on
one host, pods using that StorageClass will only schedule on nodes running on that host.

The CSI node DaemonSet runs only on Proxmox nodes (filtered by the `region` topology label),
so external bare-metal nodes are automatically excluded.

### PodSecurity

The CSI node plugin requires privileged access (`hostPath` volumes, `SYS_ADMIN` capability).
The module automatically creates the `csi-proxmox` namespace with the
`pod-security.kubernetes.io/enforce: privileged` label via Talos inline manifest on
control plane nodes.

### Usage

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

### Proxmox CSI vs Longhorn

| Feature | Proxmox CSI | Longhorn |
| --- | --- | --- |
| **Storage backend** | Proxmox (LVM, ZFS, Ceph, NFS) | In-cluster distributed |
| **Replication** | Depends on backend (Ceph = yes, LVM = no) | Built-in (configurable replicas) |
| **Performance** | Native — no overhead | Network overhead for replication |
| **Snapshots** | Via Proxmox | Built-in |
| **Cross-node migration** | Only with shared storage (Ceph, NFS) | Automatic |
| **Dependencies** | Proxmox API access | iSCSI extensions on Talos |
| **Best for** | Single-node or Ceph-backed clusters | Multi-node HA without shared storage |

## External nodes (bare-metal)

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
        nodeTaints:
          arch: arm64:NoSchedule
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

### SBC overlays (Raspberry Pi, etc.)

Single-board computers (SBCs) like Raspberry Pi require a **board overlay** in the
Talos schematic for proper boot support. Without the overlay, the device won't boot
(stuck at bootloader).

**Important**: SBC nodes with overlays automatically skip `extraKernelArgs` (incompatible
with UKI boot used by SBC overlays).

| Board | Overlay name | Image |
| --- | --- | --- |
| Raspberry Pi 5 | `rpi_5` | `siderolabs/sbc-rpi_5` |
| Raspberry Pi 4 | `rpi_4` | `siderolabs/sbc-rpi_4` |
| Banana Pi M64 | `bananapi_m64` | `siderolabs/sbc-bananapi_m64` |
| Jetson Nano | `jetson_nano` | `siderolabs/sbc-jetson_nano` |
| Rock Pi 4 | `rockpi_4` | `siderolabs/sbc-rockpi_4` |
| Pine64 | `pine64` | `siderolabs/sbc-pine64` |

The naming convention is always `name = "<board>"` and `image = "siderolabs/sbc-<board>"`.
To find the correct board name:

1. Go to [factory.talos.dev](https://factory.talos.dev) and select your Talos version
2. Choose **SBC** as target — the board list shows all supported overlays
3. The board name shown in the factory is the overlay `name`, prefix with `siderolabs/sbc-` for `image`

Full list: [Talos SBC support](https://www.talos.dev/latest/talos-guides/install/single-board-computers/)

**Note**: SBCs cannot boot from ISO images. Always use the `raw_xz` image and flash
it to the SD card / eMMC / USB drive.

### Getting the image before apply

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

## Troubleshooting

### ISO download timeout (HTTP 596)

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

## Upgrades

The module supports three types of upgrades:

- **Talos OS rolling upgrades**: Per-node, via `talos_version_target` + `update` flag. Nodes reboot one at a time.
- **Stack upgrades**: Kubernetes version + Helm chart versions, via `tofu apply`. Zero downtime, declarative.
- **VM resource changes**: RAM/CPU changes via `ram_dedicated`/`cpu` in tfvars. In-place update + rolling reboot.

See **[UPGRADE.md](UPGRADE.md)** for:
- Complete version compatibility matrix
- Step-by-step upgrade procedures (validated with timings)
- Breaking changes reference per component
- VM resource change procedure (rolling reboot to preserve quorum)
- Known issues and emergency resolution
- etcd quorum rules

## Examples

Complete working examples are available in the [`examples/`](examples/) directory:

| Example | Description |
| --- | --- |
| [`basic`](examples/basic/) | Minimal 3 CP + 2 worker cluster |
| [`cilium-l2`](examples/cilium-l2/) | Cilium L2 LoadBalancer + Gateway API |
| [`gpu-passthrough`](examples/gpu-passthrough/) | NVIDIA GPU passthrough with device plugin |
| [`gpu-time-slicing`](examples/gpu-time-slicing/) | GPU sharing via CUDA time-slicing (1 GPU → N virtual GPUs) |
| [`proxmox-csi`](examples/proxmox-csi/) | PersistentVolumes backed by Proxmox storage (LVM, ZFS, Ceph) |
| [`external-nodes`](examples/external-nodes/) | Raspberry Pi ARM64 bare-metal workers |
| [`full-stack`](examples/full-stack/) | All features: GPU, Proxmox CSI, external nodes, Gateway API, Longhorn |

## Provider configuration

Providers must be configured at the root module and passed in. The module
declares `proxmox`, `talos`, `helm`, `http`, and `time` as `required_providers`.

```hcl
provider "helm" {
  kubernetes {
    host                   = module.cluster.kubeconfig_host
    client_certificate     = base64decode(module.cluster.kubeconfig_client_certificate)
    client_key             = base64decode(module.cluster.kubeconfig_client_key)
    cluster_ca_certificate = base64decode(module.cluster.kubeconfig_ca_certificate)
  }
}
```
