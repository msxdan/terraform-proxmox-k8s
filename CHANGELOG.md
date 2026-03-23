# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Static IP support** — Set `gateway` and `subnet_mask` per node to assign static IPs via Proxmox cloud-init instead of relying on DHCP reservations.
- **Interface detection via MAC address** — Talos machine config now uses `deviceSelector` with `hardwareAddr` to identify the primary network interface, replacing the hardcoded `eth0`. Works regardless of kernel naming scheme (`eth0`, `enp0s18`, `end0`).
- **External node `interface_name`** — Configurable network interface name for external bare-metal nodes (default: `eth0`). Useful for SBCs with UKI boot that use `end0`.
- **External node `mac_address`** — Optional MAC address for external nodes to use `deviceSelector` instead of interface name.
- **API server readiness wait** — 30-second wait after bootstrap before installing Cilium, eliminating the need for a second `tofu apply` on new clusters.

### Changed

- Cilium now depends on `time_sleep.wait_for_api_server` instead of directly on `talos_machine_bootstrap`.
- Worker nodes in DHCP mode no longer generate a redundant `machine.network.interfaces` block in the Talos config.
- `.gitignore` pattern updated from `.talosconfig` to `.talosconfig*`.
