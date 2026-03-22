# Upgrade & Operations Guide

Complete guide for upgrading and operating Talos Linux clusters managed by this module.

## Table of Contents

- [Version Compatibility](#version-compatibility)
  - [Validated Stacks](#validated-stacks)
  - [Kubernetes / Component Support Range](#kubernetes--component-support-range)
- [Upgrade Principles](#upgrade-principles)
- [Upgrading Talos OS (Rolling)](#upgrading-talos-os-rolling)
  - [How it works](#how-talos-upgrades-work)
  - [Pre-upgrade checklist](#pre-upgrade-checklist)
  - [Procedure](#procedure-eg-v1110-to-v1116)
  - [Post-upgrade verification](#post-upgrade-verification)
  - [etcd quorum](#etcd-quorum)
- [Upgrading Kubernetes & Components (Stack)](#upgrading-kubernetes--components-stack)
  - [How it works](#how-stack-upgrades-work)
  - [Upgrade order](#upgrade-order)
  - [Pre-flight / Post-flight checks](#pre-flight-checks)
  - [Validated procedures](#validated-procedures)
- [Cluster Operations](#cluster-operations)
  - [Changing VM Resources (RAM / CPU)](#changing-vm-resources-ram--cpu)
  - [Removing Nodes](#removing-nodes)
  - [Sizing Recommendations](#sizing-recommendations)
- [Reference](#reference)
  - [Breaking Changes](#breaking-changes)
  - [Known Issues](#known-issues)

---

## Version Compatibility

### Validated Stacks

Each row is a validated combination of component versions tested to work together. The module's upgrade procedures support moving between these stacks sequentially (v1 → v2 → v3 → v4).

| Stack | Talos | Kubernetes | Cilium | Metrics Server | Cert Manager | Gateway API | NVIDIA Device Plugin | Proxmox CSI | Longhorn |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **v5** (future) | v1.12.x | v1.35.x | 1.20.x | 0.8.x | 1.20.x | v1.5.x | 0.19.x | 0.18.x | 1.11.x |
| **v4** (current) | v1.12.5 | v1.35.2 | 1.19.1 | 0.8.0 | 1.20.0 | v1.4.0 | 0.19.0 | 0.18.0 | 1.11.0 |
| **v3** | v1.11.6 | v1.34.5 | 1.19.1 | 0.8.0 | 1.20.0 | v1.4.0 | 0.18.2 | 0.18.0 | 1.11.0 |
| **v2** | v1.11.6 | v1.33.9 | 1.19.1 | 0.8.0 | 1.20.0 | v1.4.0 | 0.18.2 | 0.18.0 | 1.11.0 |
| **v1** (validated) | v1.11.6 | v1.32.8 | 1.18.1 | 0.8.0 | 1.18.2 | v1.3.0 | 0.18.2 | 0.18.0 | 1.7.3 |
| **v1** (base) | v1.11.0 | v1.32.8 | 1.18.1 | 0.8.0 | 1.18.2 | v1.3.0 | 0.18.2 | 0.18.0 | 1.7.3 |

> **Chart vs app versions**: The tables show app versions. The module configures
> Helm chart versions which may differ:
> - Metrics Server: chart 3.12.x = app 0.7.x, chart 3.13.x = app 0.8.x
> - Proxmox CSI: chart 0.5.5 = app 0.18.0

### Kubernetes / Component Support Range

| Component | K8s 1.32 | K8s 1.33 | K8s 1.34 | K8s 1.35 |
| --- | --- | --- | --- | --- |
| **Talos** | v1.9+ | v1.10+ | v1.11+ | v1.12+ |
| **Cilium** | 1.18, 1.19 | 1.18, 1.19 | 1.19 | 1.19 |
| **Metrics Server** | 0.7, 0.8 | 0.7, 0.8 | 0.7, 0.8 | 0.8 |
| **Cert Manager** | 1.17, 1.18 | 1.17-1.20 | 1.19, 1.20 | 1.20 |
| **Gateway API** | v1.3-v1.5 | v1.3-v1.5 | v1.4, v1.5 | v1.4, v1.5 |
| **Longhorn** | 1.8-1.11 | 1.9-1.11 | 1.11 | 1.11 |

> **Gateway API v1.4 vs v1.5 with Cilium 1.19**: Gateway API v1.5.0 graduated
> TLSRoute to standard as `v1`, but sets `v1alpha2` as `served: false`. Cilium 1.19
> only supports TLSRoute `v1alpha2` (bug [#38420](https://github.com/cilium/cilium/issues/38420)),
> so upgrading to v1.5.0 standard breaks Cilium's TLSRoute reconciliation. Stay
> on v1.4.0 with `enable_tlsroute = true` until Cilium supports TLSRoute `v1`
> (expected Cilium 1.20+, ~July 2026).

---

## Upgrade Principles

> **Upgrade one minor version at a time.** Never jump multiple minors (e.g.
> v1.3 to v1.5). Each minor may introduce breaking changes that compound when
> skipped. Always validate cross-component compatibility before changing any
> version — check the compatibility matrix and breaking changes table.
>
> **Order matters.** Upgrade components individually, verify health between each
> step, and never batch all changes into a single apply on the first attempt.

---

## Upgrading Talos OS (Rolling)

Rolling upgrades change the Talos OS version on each node. They **do not** change
machine configs or Kubernetes version. Each node downloads the new image, writes
it to disk, and reboots.

### How Talos upgrades work

```
Bootstrap (first time only):
  Proxmox ISO ──► VM boots ──► Talos installs to disk ──► ISO never used again

Upgrade (all subsequent):
  talosctl upgrade --image factory.talos.dev/installer/SCHEMATIC:vX.Y.Z
  ──► Node downloads image directly from Talos Image Factory
  ──► Image includes extensions baked in via schematic (per-node if overridden)
  ──► Writes new image to disk
  ──► Cordon + drain (automatic, moves pods to other nodes)
  ──► Reboot from disk with new version
  ──► Proxmox ISO is NOT involved
```

The installer URL includes the **schematic ID** which encodes your extensions:

```
factory.talos.dev/installer/<schematic-id>:<version>
                            ^^^^^^^^^^^^^^ ^^^^^^^^
                            extensions     Talos version
```

> **IMPORTANT**: The VM resource uses `lifecycle { ignore_changes = [disk[0].file_id] }`
> to prevent Proxmox from recreating VMs when the ISO version changes. Without this,
> updating `talos_version` would change the ISO reference, causing Proxmox to
> destroy and recreate all VMs, wiping etcd and all cluster state.

### Pre-upgrade checklist

```bash
# Verify all nodes are Ready
kubectl get nodes

# Verify etcd health
talosctl --nodes <cp-ip> etcd status

# Check current Talos version on all nodes
talosctl --nodes <cp-ip-1>,<cp-ip-2>,<cp-ip-3>,<worker-ip-1>,<worker-ip-2> version
```

### Procedure (e.g. v1.11.0 to v1.11.6)

```bash
# 1. Create upgrade target
cat > upgrade.auto.tfvars << 'EOF'
talos_version_target = "v1.11.6"
EOF
```

Then toggle `update = true` on each node, one step at a time:

```bash
# 2. Set master-01 update = true
tofu apply
# Verify
talosctl --nodes <cp-ip-1> version
kubectl get nodes

# 3. master-01 update = false, master-02 update = true
tofu apply
# Verify

# 4. master-02 update = false, master-03 update = true
tofu apply
# Verify

# 5. master-03 update = false, worker-01 + worker-02 update = true
#    (workers can be upgraded in parallel)
tofu apply
# Verify all nodes

# 6. Finalize: update talos_version, reset all update = false, remove upgrade file
rm upgrade.auto.tfvars
tofu apply
```

Each `talosctl upgrade` step automatically:
1. Cordons the node (marks unschedulable)
2. Drains pods to other nodes
3. Downloads the new image from Talos Image Factory
4. Writes the image to disk
5. Reboots
6. Waits for the node to be healthy (`--wait`)

### Post-upgrade verification

```bash
# All nodes should show new version and Ready status
kubectl get nodes -o wide

# Verify etcd cluster health
talosctl --nodes <cp-ip> etcd status

# Verify all pods running
kubectl get pods -A

# Verify Cilium
kubectl -n kube-system exec ds/cilium -- cilium status

# Verify Cilium Gateway API reconciliation
# See "Known Issues > Cilium operator Gateway API race condition" for details.
kubectl -n kube-system logs \
  -l app.kubernetes.io/name=cilium-operator --tail=20 \
  | grep -i "gateway"
# If "Required GatewayAPI resources are not found" appears:
kubectl -n kube-system rollout restart deployment/cilium-operator
```

### etcd quorum

| Control planes | Quorum | Tolerated failures |
| --- | --- | --- |
| 1 | 1 | 0 |
| 3 | 2 | 1 |
| 5 | 3 | 2 |

Always upgrade one control plane at a time to maintain quorum.

---

## Upgrading Kubernetes & Components (Stack)

Upgrading K8s version and Helm chart versions (Cilium, Cert Manager, etc.) is a
**different process** from Talos OS rolling upgrades. These changes are applied
via `tofu apply` and affect the cluster declaratively.

### How stack upgrades work

```
Kubernetes version upgrade (zero downtime):
  Change kubernetes_version in your config
  ──► tofu apply pushes new machine config to all nodes
  ──► Talos updates K8s components (API server, kubelet, etc.)
  ──► No reboot, no cordon/drain needed
  ──► API server restarts briefly per CP, VIP maintains availability
  ──► Workload pods continue running uninterrupted

Helm chart upgrades (zero downtime):
  Change chart version in your config
  ──► tofu apply upgrades Helm release in-place
  ──► Pods roll out with new version (rolling update)
```

> **IMPORTANT**: Changing `kubernetes_version` applies to ALL nodes simultaneously
> (unlike Talos OS upgrades which are per-node). This is safe because Talos handles
> the K8s component upgrade gracefully, but you should always verify cluster health
> before and after.

### Upgrade order

Upgrade components in this order to minimize risk:

1. **Pre-flight checks** (nodes Ready, etcd healthy, no unhealthy pods)
2. **CRDs** (Gateway API — prepare the ground for controllers)
3. **Cilium** (CNI is foundational, verify network health after)
4. **Cert Manager** (one minor at a time: 1.18 to 1.19, then 1.19 to 1.20)
5. **Kubernetes version** (via machine config, affects all nodes)
6. **Post-flight checks** (nodes Ready, etcd healthy, pods Running, etcd defrag)

### Pre-flight checks

```bash
kubectl get nodes
talosctl --nodes <cp-ip> etcd status
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl -n kube-system exec ds/cilium -- cilium status --brief
```

### Post-flight checks

```bash
kubectl get nodes -o wide
talosctl --nodes <cp-ip> etcd status
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl -n kube-system exec ds/cilium -- cilium status --brief

# Verify Cilium Gateway API reconciliation (after any CP reboot/restart)
kubectl -n kube-system logs \
  -l app.kubernetes.io/name=cilium-operator --tail=20 \
  | grep -i "gateway"

# Defrag etcd after bulk CRD/config changes:
talosctl --nodes <cp-ip> etcd defrag
```

### Validated procedures

<details>
<summary><b>v1 to v2</b> — K8s 1.32→1.33, Cilium 1.18→1.19, Cert Manager 1.18→1.20, Gateway API v1.3→v1.4 (~2m 15s)</summary>

<br>

```bash
# Step 1: CRDs (Gateway API v1.4.0 + TLSRoute)
#   gateway_api = { enabled = true, version = "1.4.0", enable_tlsroute = true }
tofu apply

# Verify:
kubectl api-resources --api-group=gateway.networking.k8s.io
kubectl get crd tlsroutes.gateway.networking.k8s.io

# Step 2: Cilium 1.18.1 to 1.19.1
#   cilium = { version = "1.19.1" }
tofu apply

# Verify:
kubectl -n kube-system exec ds/cilium -- cilium version
kubectl -n kube-system get pods -l app.kubernetes.io/name=cilium-operator

# Step 3a: Cert Manager 1.18.2 to 1.19.4
#   cert_manager = { version = "1.19.4" }
tofu apply

# Step 3b: Cert Manager 1.19.4 to 1.20.0
#   cert_manager = { version = "1.20.0" }
tofu apply

# Step 4: Kubernetes 1.32.8 to 1.33.9
#   kubernetes_version = "1.33.9"
tofu apply

# Verify:
kubectl get nodes -o wide
# All nodes should show v1.33.9
```

| Step | Component | Duration |
| --- | --- | --- |
| 1 | CRDs (Gateway API v1.4 + TLSRoute) | <1s |
| 2 | Cilium 1.18 to 1.19 | ~54s |
| 3a | Cert Manager 1.18 to 1.19 | ~17s |
| 3b | Cert Manager 1.19 to 1.20 | ~14s |
| 4 | Kubernetes 1.32 to 1.33 | ~45s |
| **Total** | | **~2m 15s** |

</details>

<details>
<summary><b>v2 to v3</b> — K8s 1.33→1.34 (~40s)</summary>

<br>

```bash
# Step 1: Kubernetes 1.33.9 to 1.34.5
#   kubernetes_version = "1.34.5"
tofu apply

# Verify:
kubectl get nodes -o wide
# All nodes should show v1.34.5
```

| Step | Component | Duration |
| --- | --- | --- |
| 1 | Kubernetes 1.33 to 1.34 | ~40s |

</details>

<details>
<summary><b>v3 to v4</b> — Talos 1.11→1.12 (rolling) + K8s 1.34→1.35 (~6m 22s)</summary>

<br>

Requires two phases because Talos 1.11 rejects K8s 1.35 and vice versa.

**Template migration**: Talos 1.12 deprecates `machine.network.hostname`. The module
handles this automatically by switching to `HostnameConfig` document with `auto: off`
when it detects Talos >= 1.12.

```bash
# Phase 1: Rolling Talos OS upgrade 1.11.6 to 1.12.5
cat > upgrade.auto.tfvars << 'EOF'
talos_version_target = "v1.12.5"
EOF

# Upgrade control planes one at a time (set update=true, apply, verify, reset)
# master-01 → master-02 → master-03
# Workers can be upgraded in parallel
# worker-01 + worker-02 update=true → tofu apply → verify → reset

# Phase 2: K8s 1.34 to 1.35 + finalization
rm upgrade.auto.tfvars
#   talos_version      = "v1.12.5"
#   kubernetes_version = "1.35.2"
tofu apply

# Verify:
kubectl get nodes -o wide
# All nodes should show v1.35.2 + Talos (v1.12.5)

# Defrag etcd after major upgrade:
talosctl --nodes <cp-ip> etcd defrag
```

| Step | Component | Duration |
| --- | --- | --- |
| 1a | Talos OS master-01 | ~59s |
| 1b | Talos OS master-02 | ~58s |
| 1c | Talos OS master-03 | ~86s |
| 1d | Talos OS workers (parallel) | ~48s |
| 2 | K8s 1.34 to 1.35 + finalization | ~1m51s |
| **Total** | | **~6m 22s** |

</details>

---

## Cluster Operations

### Changing VM Resources (RAM / CPU)

Changing `ram_dedicated` or `cpu` on existing nodes is an **in-place update** — the
Proxmox provider modifies the VM configuration via API without destroying/recreating
the VM. However, the changes only take effect after a **reboot**.

```
VM resource change (requires reboot):
  Change ram_dedicated / cpu in your config
  ──► tofu apply updates VM config in Proxmox (no VM destruction)
  ──► VM continues running with old resources until rebooted
  ──► Reboot node via talosctl reboot
  ──► Node comes back with new RAM/CPU
```

> **IMPORTANT**: Verify with `tofu plan` before applying — the plan should show
> `~ update in-place`, never `- destroy` / `+ create`.

#### Control plane nodes (rolling reboot)

Control planes must be rebooted **one at a time** to maintain etcd quorum.

```bash
# 1. Update ram_dedicated / cpu in your config
# 2. tofu plan → verify in-place updates
# 3. tofu apply (all nodes at once is safe — no reboot yet)

# 4. Rolling reboot — one CP at a time
talosctl --nodes <cp-ip-1> reboot
talosctl --nodes <cp-ip-1> health --wait-timeout 3m \
  --control-plane-nodes <cp-ip-1>,<cp-ip-2>,<cp-ip-3> \
  --worker-nodes <worker-ip-1>,<worker-ip-2>

# Repeat for cp-ip-2, cp-ip-3
```

#### Worker nodes

Workers have no quorum constraint. They can be rebooted in parallel or one at a time.

```bash
# Option A: Rolling (zero-downtime for workloads)
kubectl cordon worker-01
kubectl drain worker-01 --ignore-daemonsets --delete-emptydir-data --timeout=60s
talosctl --nodes <worker-ip> reboot
talosctl --nodes <worker-ip> health --wait-timeout 2m
kubectl uncordon worker-01

# Option B: Parallel (faster, but workloads may restart)
talosctl --nodes <worker-ip-1>,<worker-ip-2> reboot
```

#### Post-change verification

```bash
kubectl get nodes -o wide
kubectl top nodes
talosctl --nodes <cp-ip> etcd status
kubectl describe node <node-name> | grep -A 5 "Capacity:"
```

### Removing Nodes

#### Removing a worker node

1. **Drain the node**:
```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```
If the node is **NotReady**, pods will not terminate gracefully. Force-delete stuck pods:
```bash
kubectl delete pod <pod-name> -n <namespace> --force --grace-period=0
```

2. **Verify no non-DaemonSet pods remain**:
```bash
kubectl get pods -A --field-selector spec.nodeName=<node-name> | grep -v DaemonSet
```

3. **Delete from Kubernetes**:
```bash
kubectl delete node <node-name>
```

4. **Reset Talos** (optional — wipes the machine for reuse):
```bash
talosctl reset --nodes <node-ip> --graceful=false
```

5. **Remove from config and apply**:
```bash
tofu apply
```

#### Removing a control plane node

> **WARNING**: Never remove more than one control plane node at a time.
> Removing 2 out of 3 breaks etcd quorum and the cluster becomes unrecoverable.

1. **Verify etcd health**:
```bash
talosctl etcd members --nodes <any-cp-ip>
```

2. **Drain the node**:
```bash
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

3. **Remove from etcd** (BEFORE deleting the node):
```bash
talosctl etcd remove-member --nodes <another-cp-ip> <node-to-remove-ip>
```

4. **Delete from Kubernetes**:
```bash
kubectl delete node <node-name>
```

5. **Reset Talos** (optional):
```bash
talosctl reset --nodes <node-ip> --graceful=false
```

6. **Remove from config and apply**:
```bash
tofu apply
```

7. **Verify etcd quorum**:
```bash
talosctl etcd members --nodes <remaining-cp-ip>
talosctl etcd status --nodes <remaining-cp-ip>
```

### Sizing Recommendations

| Role | Minimum | Recommended | Notes |
| --- | --- | --- | --- |
| Control plane | 2 GB | 4 GB | kube-apiserver (~700Mi) + Cilium (~250Mi) + etcd + OS overhead |
| Worker | 4 GB | 8 GB | Depends on workload — check `kubectl top nodes` |
| GPU worker | 8 GB | 12-16 GB | ML model loading often needs host RAM alongside VRAM |

> **Rule of thumb**: If `kubectl top nodes` shows memory usage above 80% of
> allocatable on any node, it's time to increase RAM.

---

## Reference

### Breaking Changes

#### Component Breaking Changes

| Component | From / To | Breaking Changes | Typical Impact |
| --- | --- | --- | --- |
| **Cilium** | 1.18 / 1.19 | BGPv1 CRDs removed; ClusterMesh policy scope change; `FromRequires`/`ToRequires` removed; several flags removed | None if not using BGP, ClusterMesh policies, or removed flags |
| **Cert Manager** | 1.18 / 1.20 | Container UID/GID changed (1000:0 / 65532:65532); metrics label change; `DefaultPrivateKeyRotationPolicyAlways` now GA | None unless custom UID constraints or affected metrics |
| **Kubernetes** | 1.32 / 1.33 | Endpoints API deprecated (not removed); `flowcontrol.apiserver.k8s.io/v1beta3` removed in 1.32 | None if already on 1.32+ |
| **Kubernetes** | 1.33 / 1.34 | `--cloud-provider`/`--cloud-config` flags removed from kube-apiserver; DRA v1alpha4 gRPC removed | None — Talos manages kube-apiserver flags |
| **Kubernetes** | 1.34 / 1.35 | cgroup v1 rejected by default; IPVS kube-proxy mode deprecated; containerd 1.x last supported release | None — Talos uses cgroup v2, containerd 2.x, and Cilium eBPF (no kube-proxy) |
| **Gateway API** | v1.3 / v1.4 | `GRPCRoute.spec` now required; `BackendTLSPolicy` graduated to standard | None unless using empty GRPCRoute specs |

#### Talos 1.12 Breaking Changes

| Change | Impact |
| --- | --- |
| **Feature flags locked**: `machine.features.rbac`, `machine.features.apidCheckExtKeyUsage`, `cluster.apiServer.disablePodSecurityPolicy` locked to `true` | None unless explicitly setting these to `false` |
| **`machine.network` deprecated**: Replaced by multi-doc network config (HostnameConfig, etc.). Still works for backward compatibility. | Module handles this automatically (HostnameConfig with `auto: off` for Talos 1.12+) |
| **`machine.registries` deprecated**: Replaced by RegistryMirrorConfig, RegistryAuthConfig, RegistryTLSConfig. Still works. | None if not using custom registries |
| **API server cipher suites**: More restrictive defaults per CIS 1.12 benchmark. | None — defaults are fine |
| **KSPP sysctl**: Stricter kernel security posture profile by default. | Improves security, no action needed |
| **Linux kernel**: 6.12.x to 6.18.x. Legacy xtables (`CONFIG_NETFILTER_XTABLES_LEGACY`) disabled. | None if using Cilium eBPF (no iptables) |
| **containerd**: 2.0.x to 2.1.x | Transparent for workloads |
| **etcd**: 3.5.x to 3.6.x. Pulled from `registry.k8s.io/etcd` instead of `gcr.io/etcd-development/etcd`. | None |

### Known Issues

| Issue | Versions | Workaround |
| --- | --- | --- |
| Cilium operator Gateway API race condition on CP reboot | Cilium 1.19.x (likely all versions) | Verify after any control plane reboot. See incident log below. |
| Cilium 1.19 crashes without `TLSRoute v1alpha2` CRD | Cilium 1.19.x with `gatewayAPI.enabled=true` | Set `gateway_api.enable_tlsroute = true`. Bug [#38420](https://github.com/cilium/cilium/issues/38420). |
| Gateway API v1.5.0 incompatible with Cilium 1.19 | v1.5.0 standard + Cilium 1.19.x | v1.5.0 sets TLSRoute `v1alpha2` `served: false`. Stay on v1.4.0 until Cilium supports TLSRoute `v1` (expected 1.20+). Also installs a `ValidatingAdmissionPolicy` blocking experimental CRDs. |
| Talos 1.12 provider generates `HostnameConfig` with `auto: stable` | Talos provider v0.10.1 + talos_version >= v1.12 | Module handles this automatically. Provider issue [#296](https://github.com/siderolabs/terraform-provider-talos/issues/296). |
| etcd high usage after bulk CRD changes | Any | Run `talosctl etcd defrag --nodes <cp-ip>` after large upgrades. |

<details>
<summary><b>Incident log: Cilium operator Gateway API race condition (2026-03-20)</b></summary>

<br>

During a control plane RAM increase (rolling reboot of master-01, master-02, master-03),
the cilium-operator restarted on a node where kube-apiserver was still initializing.
The operator's one-shot Gateway API CRD discovery check failed with EOF, permanently
disabling Gateway API reconciliation for the leader pod.

**Symptoms**:
- Existing HTTPRoutes continued working (already programmed in Envoy)
- New HTTPRoutes created after the reboot had empty `.status` (no `parents` section)
- Cilium operator logs showed: `Required GatewayAPI resources are not found`

**Root cause**: The cilium-operator checks for Gateway API CRDs once at startup.
If the API server is unreachable at that moment, the check fails and is never retried.

**Resolution**: `kubectl -n kube-system rollout restart deployment/cilium-operator`

</details>

<details>
<summary><b>Incident log: Cilium 1.19 + Gateway API v1.5.0</b></summary>

<br>

During a v1 to v2 upgrade attempt, Gateway API was jumped from v1.3.0 directly
to v1.5.0 (violating the "one minor at a time" rule). This caused a cascade:

1. v1.5.0 standard CRDs do not include `TLSRoute v1alpha2`
2. Cilium 1.19 operator crashed: `no matches for kind "TLSRoute" in version "gateway.networking.k8s.io/v1alpha2"`
3. v1.5.0 also installed a `ValidatingAdmissionPolicy` blocking experimental CRDs
4. Manual fix required: delete VAP, install TLSRoute CRD, restart operator pods

**Lesson learned**: Use v1.4.0 with `enable_tlsroute = true` before upgrading Cilium.

**Emergency resolution**:

```bash
# 1. Remove the VAP
kubectl delete validatingadmissionpolicy safe-upgrades.gateway.networking.k8s.io 2>/dev/null
kubectl delete validatingadmissionpolicybinding safe-upgrades.gateway.networking.k8s.io 2>/dev/null

# 2. Install TLSRoute CRD
kubectl apply --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v1.4.0/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml

# 3. Restart crashed operator pods
kubectl -n kube-system delete pods -l app.kubernetes.io/name=cilium-operator

# 4. Verify
kubectl -n kube-system get pods -l app.kubernetes.io/name=cilium-operator
kubectl -n kube-system exec ds/cilium -- cilium status --brief
```

</details>
