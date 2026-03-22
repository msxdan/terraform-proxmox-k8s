# Proxmox CSI Plugin — PersistentVolumes backed by Proxmox storage
#
# Creates PVs directly on Proxmox storage (LVM, ZFS, Ceph, NFS).
# Lighter alternative to Longhorn — uses existing Proxmox storage.
#
# Prerequisites:
#   1. Proxmox must be clustered (even single-node: `pvecm create my-cluster`)
#   2. API user, role, and token:
#      pveum user add kubernetes-csi@pve
#      pveum role add CSI -privs "VM.Audit VM.Config.Disk Datastore.Allocate Datastore.AllocateSpace Datastore.Audit"
#      pveum aclmod / -user kubernetes-csi@pve -role CSI
#      pveum user token add kubernetes-csi@pve csi -privsep 0

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

  proxmox_csi = {
    enabled      = true
    version      = "0.5.5"
    proxmox_url  = "https://pve-01.example.com:8006/api2/json"
    token_id     = "kubernetes-csi@pve!csi"
    token_secret = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" # use a variable or SOPS in production
    region       = "my-cluster"
    insecure     = true
    storage_classes = [
      {
        name    = "proxmox-zfs"
        storage = "local-zfs"
        ssd     = true
      },
      {
        name    = "proxmox-lvm"
        storage = "local-lvm"
        fstype  = "xfs"
      }
    ]
  }
}

# After apply, use the StorageClass in PVCs:
#
#   apiVersion: v1
#   kind: PersistentVolumeClaim
#   metadata:
#     name: my-data
#   spec:
#     accessModes: ["ReadWriteOnce"]
#     storageClassName: proxmox-zfs
#     resources:
#       requests:
#         storage: 10Gi
