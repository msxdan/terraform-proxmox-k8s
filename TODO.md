# TODO

Backlog of new variables, components, and improvements for future versions.

When upgrading chart versions, review variable defaults for breaking changes —
keep `UPGRADE.md` aligned with any additions here.

Design principle: the module delivers a **production-ready cluster** with
networking, storage, certificates, monitoring, GPU and GitOps pre-configured.
Everything else (apps, logging, CI/CD) is managed by the GitOps tool the module
installs.

---

## Cilium

### MUST HAVE

- [ ] `routing_mode` (string, default `"tunnel"`) — `native` vs `tunnel`. Homelabs on flat L2 networks benefit from `native` routing for performance and simplicity.
- [ ] `ipv4_native_routing_cidr` (string, default `""`) — Required when `routing_mode=native`. Tells Cilium which CIDR is natively routed to skip SNAT.
- [ ] `auto_direct_node_routes` (bool, default `false`) — Installs pod CIDR routes automatically between nodes on L2 networks. Required for `routing_mode=native` without a BGP router.
- [ ] `hubble` (object) — Observability layer. Expose `enabled` (default `true`), `relay.enabled` (default `false`), `ui.enabled` (default `false`), `metrics` (list of strings, e.g. `["dns:query;ignoreAAAA","drop","tcp","flow"]`).
- [ ] `operator_replicas` (number, default `2`) — Single-node or small clusters (1-3 nodes) should set to `1` to avoid scheduling issues and wasted resources.

### SHOULD HAVE

- [ ] `encryption` (object) — WireGuard/IPsec encryption between pods. Expose `enabled` (default `false`), `type` (default `"wireguard"`), `node_encryption` (default `false`).
- [ ] `bpf_masquerade` (bool, default `false`) — Native eBPF masquerading instead of iptables. Significant performance improvement on kernel 5.10+ (Talos default).
- [ ] `bandwidth_manager` (bool, default `false`) — EDT-based bandwidth management and BBR congestion control via `kubernetes.io/egress-bandwidth` annotation.
- [ ] `bgp_control_plane` (bool, default `false`) — Alternative to L2 announcements for LoadBalancer service advertisement via BGP.
- [ ] `prometheus` (object) — Expose `enabled` (default `false`) and `service_monitor_enabled` (default `false`) for Prometheus Operator integration.
- [ ] `mtu` (number, default `0`) — `0` = auto-detect. VMs with VXLAN or WireGuard overlays may need manual MTU (e.g. 1400 for WireGuard). Wrong MTU causes packet drops.
- [ ] `ipv6` (bool, default `false`) — Enable dual-stack networking.

### NICE TO HAVE

- [ ] `tunnel_protocol` (string, default `"vxlan"`) — `vxlan` or `geneve`. Only relevant when `routing_mode=tunnel`.
- [ ] `cluster_name` (string, default `"default"`) — Required for Cluster Mesh. Must be set at install time, cannot be changed later.
- [ ] `cluster_id` (number, default `0`) — Required for Cluster Mesh alongside `cluster_name`.
- [ ] `loadbalancer_acceleration` (string, default `"disabled"`) — XDP acceleration (`disabled`, `native`, `best-effort`) for NodePort/LoadBalancer throughput.
- [ ] `loadbalancer_mode` (string, default `"snat"`) — DSR (Direct Server Return) skips SNAT on return path, improving performance.
- [ ] `loadbalancer_algorithm` (string, default `"random"`) — `maglev` provides consistent backend selection.
- [ ] `host_firewall` (bool, default `false`) — Host-level network policy enforcement via CiliumClusterwideNetworkPolicy.
- [ ] `ingress_controller` (bool, default `false`) — Cilium's built-in Ingress controller as alternative to nginx/traefik.
- [ ] `egress_gateway` (bool, default `false`) — Deterministic egress IPs for external firewall whitelisting.
- [ ] `envoy_enabled` (bool, default `true`) — Standalone Envoy DaemonSet. Disable to save resources if not using L7 features.

---

## Cert Manager

### MUST HAVE

- [ ] `enable_certificate_owner_ref` (bool, default `false`) — Auto-delete TLS Secrets when the Certificate resource is deleted. Prevents orphaned secrets accumulating.
- [ ] `priority_class_name` (string, default `""`) — Set to `"system-cluster-critical"` to survive node pressure. cert-manager is critical infrastructure.
- [ ] `pod_disruption_budget` (bool, default `false`) — Essential when `replicas > 1` to prevent all replicas being evicted during drains/upgrades.
- [ ] `webhook_replicas` (number, default `1`) — Webhook is the critical admission controller. Should match controller replicas for real HA.

### SHOULD HAVE

- [ ] `prometheus_servicemonitor` (bool, default `false`) — Auto-create ServiceMonitor for cert-manager metrics (certificate expiry, ACME errors).
- [ ] `log_level` (number, default `2`) — Range 0-6. Bump to 4-5 when debugging DNS01 challenges, reduce to 1 in production to cut log volume.
- [ ] `cluster_resource_namespace` (string, default `""`) — Where ClusterIssuer credentials (Cloudflare API tokens, Route53 secrets) are stored. Some orgs require a specific namespace for RBAC.
- [ ] `webhook_host_network` (bool, default `false`) — Required when API server cannot reach pod IPs (some CNI setups, managed K8s).
- [ ] `webhook_secure_port` (number, default `10250`) — Change if `webhook_host_network=true` to avoid conflicts with kubelet.

### NICE TO HAVE

- [ ] `max_concurrent_challenges` (number, default `60`) — Increase for clusters with many Certificates/Ingresses.
- [ ] `default_issuer_name` (string, default `""`) — Auto-provision certificates for Ingresses annotated with `kubernetes.io/tls-acme: "true"`.
- [ ] `default_issuer_kind` (string, default `""`) — Companion to `default_issuer_name` (`ClusterIssuer` or `Issuer`).
- [ ] `feature_gates` (string, default `""`) — Toggle experimental features (e.g. `ServerSideApply`).
- [ ] `cainjector_enabled` (bool, default `true`) — Disable to save ~50MB RAM if only using ACME (no CA injection needed).

---

## NVIDIA Device Plugin

### MUST HAVE

- [ ] `gfd_enabled` (bool, default `false`) — GPU Feature Discovery auto-labels nodes with GPU model, memory, CUDA version. Essential for clusters with multiple GPU models for proper scheduling.
- [ ] `mig_strategy` (string, default `"none"`) — Multi-Instance GPU partitioning for A100/A30/H100. Options: `none`, `single`, `mixed`. Changes the entire resource model Kubernetes sees.

### SHOULD HAVE

- [ ] `device_list_strategy` (string, default `null`) — How GPU device info is passed to containers (`envvar`, `volume-mounts`, `cdi-annotations`, `cdi-cri`). CDI-based strategies required for rootless containers.
- [ ] `fail_on_init_error` (bool, default `true`) — Set to `false` to prevent crash-loops on non-GPU nodes in mixed clusters. Plugin starts but exposes 0 GPUs.

### NICE TO HAVE

- [ ] `cdi_feature_flags` (string, default `null`) — Advanced CDI spec generation flags (e.g. `"allow-host-access"`).

---

## Longhorn (experimental)

### MUST HAVE

- [ ] `backup_target` (string, default `null`) — S3/NFS backup destination (e.g. `s3://bucket@region/path`, `nfs://server:/path`). Without backups, one node failure = data loss.
- [ ] `backup_target_credential_secret` (string, default `null`) — Kubernetes Secret name with S3/NFS credentials for the backup target.
- [ ] `storage_over_provisioning_percentage` (number, default `100`) — Homelabs with limited disks need overcommit (200-300%). Default of 100% is very conservative.
- [ ] `storage_minimal_available_percentage` (number, default `25`) — Minimum free disk before Longhorn stops scheduling. 25% is aggressive for small disks — lower to 10-15%.

### SHOULD HAVE

- [ ] `default_data_locality` (string, default `"disabled"`) — `best-effort` keeps a replica on the same node as the consuming pod, reducing network reads. Major performance impact on 1GbE networks.
- [ ] `replica_auto_balance` (string, default `"disabled"`) — Auto-rebalance replicas when nodes are added. Without it, new nodes sit idle for storage.
- [ ] `guaranteed_instance_manager_cpu` (number, default `12`) — CPU percentage reserved per node. On 4-core homelab nodes, 12% is excessive — lower to 5% or 0.
- [ ] `ui_service_type` (string, default `"ClusterIP"`) — `NodePort` or `LoadBalancer` for direct UI access.

### NICE TO HAVE

- [ ] `data_path` (string, default `"/var/lib/longhorn/"`) — Override when root disk is small and a secondary disk is mounted elsewhere.

---

## Proxmox CSI

Current template covers the typical use case. No pending items.

---

## AMD GPU support

- [ ] **AMD Device Plugin** — Support for AMD GPUs (ROCm) as alternative to NVIDIA. Requires Talos extensions (`amdgpu-firmware`, `amd-rocm-container-toolkit`), kernel module loading (`amdgpu`), and the [AMD GPU device plugin](https://github.com/ROCm/k8s-device-plugin) Helm chart. Similar pattern to NVIDIA: per-node extensions, config patches for kernel modules, device plugin with `amd.com/gpu` resources. Not tested — no AMD GPUs available.

---

## New components

Components to add as optional Helm releases in future versions. Each must
follow the same pattern: `enabled = false` by default, Terraform variable
with sensible defaults, `templatefile()` for values, escape hatch via `values`
list.

### MUST — Infrastructure almost every cluster needs

- [ ] **External DNS** — Automates DNS records for Services/Ingresses/HTTPRoutes. Near-mandatory when using Gateway API (which the module already configures). Supports Cloudflare, Route53, Google DNS, etc. No Talos-specific config, but tight integration with Cilium Gateway API and cert-manager.
- [ ] **Kube Prometheus Stack** — Monitoring is day 1, not day 2. Without metrics you don't know if the cluster is healthy. Includes Prometheus, Grafana, Alertmanager, node-exporter, kube-state-metrics. Talos-specific: `node-exporter` needs `hostNetwork`, host PID, and tolerations; Prometheus benefits from persistent storage via Proxmox CSI or Longhorn (both already managed by the module).

### SHOULD — Very common, benefit from module-level integration

- [ ] **ArgoCD** — GitOps is the de facto standard for managing everything after bootstrap. The module creates the cluster, ArgoCD manages the rest. Closes the lifecycle loop. Consider also Flux as alternative — expose a `gitops` variable with `tool = "argocd" | "flux"`.
- [ ] **External Secrets Operator** — Integrates secrets from Vault, AWS SSM, SOPS, 1Password, etc. Users need secrets from day 1 (TLS certs, API keys, DB passwords). Avoids the anti-pattern of hardcoding secrets in tfvars.
- [ ] **Velero** — Cluster backup and disaster recovery (etcd snapshots + PV snapshots). Critical for homelabs without HA storage. Needs `velero-plugin-for-csi` for Proxmox CSI snapshot integration — direct tie-in with the storage the module manages.

### NICE — Useful but more opinionated

- [ ] **Kyverno** — Policy engine for Pod Security Standards, image policies, resource quotas. Replacement for deprecated PodSecurityPolicy. No Talos-specific config.
- [ ] **Reflector** — Replicates Secrets/ConfigMaps across namespaces. Common need with cert-manager wildcard certificates (one cert, many namespaces).
- [ ] **Reloader** — Restarts pods when a referenced Secret/ConfigMap changes. Useful with cert-manager certificate rotation.
- [ ] **DCGM Exporter** — NVIDIA GPU metrics (temperature, utilization, memory, power) for Prometheus. Complements the NVIDIA Device Plugin already in the module. Talos-specific: same `runtimeClassName: nvidia` and CDI config as the device plugin.
- [ ] **Descheduler** — Rebalances pods across nodes. Useful in homelabs where nodes reboot frequently (Talos upgrades, power events).
- [ ] **Local Path Provisioner** — Simple StorageClass for nodes without Proxmox CSI (e.g., external bare-metal Raspberry Pi). Talos-specific: uses `/var/local` as writable path.
- [ ] **Cluster Autoscaler** (Karpenter + Proxmox + Talos) — Automatic node provisioning and scaling. Requires Proxmox cloud provider integration.

### Deliberately excluded

| Component | Reason |
|-----------|--------|
| Ingress NGINX | [Officially retired March 2026](https://kubernetes.io/blog/2025/11/11/ingress-nginx-retirement/) — no more releases, bugfixes or security patches. Gateway API (already in the module) is the replacement. |
| Istio / Linkerd | Cilium already covers L7 service mesh via Envoy. Adding Istio on top is redundant and conflicts with the CNI. |
| Traefik | Cilium Gateway API + optional Ingress NGINX covers all use cases. Three ingress controllers is excessive. |
| Harbor | Full application, not cluster infrastructure. Deploy via ArgoCD. |
| Rancher | Management platform, not a cluster component. |
| Loki / Fluentbit | Logging is important but too opinionated (every user has their stack). Better deployed via ArgoCD after bootstrap. |

---

## Upgrade considerations

When bumping chart versions, check for:

1. **Renamed/removed values** — e.g. cert-manager renamed `installCRDs` to `crds.enabled` in v1.15.
2. **Changed defaults** — e.g. Cilium changed default `routingMode` behavior between versions.
3. **New required values** — new chart versions may require values that were previously optional.
4. **Deprecated features** — features marked deprecated may be removed in the next major version.

Any variable added from this list must be reflected in `UPGRADE.md` with:
- The version that introduced the variable
- Default value changes between chart versions
- Migration steps if a value is renamed or removed
