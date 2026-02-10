# High-Availability-HPC-Cluster-
## This project involves the manual architecture and deployment of a 6-node High-Performance Computing (HPC) cluster using Ubuntu Server. The design prioritizes High Availability (HA) through redundant master nodes and a centralized management headnode.

1. Cluster Hierarchy & Network Map
The cluster operates on a private subnet (192.168.10.0/24). The Headnode acts as the gateway, providing storage and infrastructure services to the control and compute planes.

| Node Name | IP Address | Role | Services |
| :--- | :--- | :--- | :--- |
| **headnode** | 192.168.10.1 | Management | NFS Server, DHCP, DNS, NTP, LVM Storage |
| **active-master** | 192.168.10.2 | Control Plane | Slurm Controller (Primary), DRBD Replication |
| **passive-master** | 192.168.10.5 | Control Plane | Slurm Controller (Secondary), DRBD Backup |
| **worker-1** | 192.168.10.3 | Execution | Compute Node, MPI Execution |
| **worker-2** | 192.168.10.4 | Execution | Compute Node, MPI Execution |
| **worker-3** | 192.168.10.6 | Execution | Passive/Spare Compute Node |

## 2. Storage Strategy (LVM & NFS)

The cluster utilizes a **600 GB Logical Volume Manager (LVM)** setup on the Headnode to ensure data integrity and scalable storage for cluster jobs.

### Logical Volume Segmentation
The 600 GB Physical Volume (PV) is partitioned into specific Logical Volumes (LVs) to optimize Slurm job management:

| Volume Name | Size | Purpose |
| :--- | :--- | :--- |
| `input_cluster` | 250 GB | Raw datasets, MPI source code, and job submission scripts. |
| `output_cluster` | 250 GB | Slurm stdout, stderr, log files, and processed results. |
| **Reserved** | 100 GB | OS snapshots and system-level expansion. |

### Network File System (NFS) Configuration
To ensure a unified workspace across the cluster, both primary volumes are exported via **NFSv4** from the Headnode.

* **Source:** `headnode` (192.168.10.1)
* **Targets:** All 5 cluster nodes (`active-master`, `passive-master`, `worker-1,2,3`)
* **Mount Points:** Typically mapped to `/mnt/input_cluster` and `/mnt/output_cluster` across all nodes to maintain path consistency for Slurm jobs.


## 3. Time Synchronization (Chrony)

> **Note:** Consistent time across the cluster is critical for preventing Slurm scheduling conflicts, ensuring accurate log correlation, and maintaining authentication integrity.

Chrony is implemented to handle synchronization across the private network:

* **Time Server (NTP Master):** `headnode` (192.168.10.1)
    * Acts as the local stratum-1 source.

    * Syncs externally with upstream NTP pools.
* **Time Clients:** `active-master`, `passive-master`, `workernode-1`, `workernode-2`, `passiveworker1`
    * Sync exclusively with the `headnode` over the **192.168.10.x** network.
    * Configured to allow for rapid clock correction upon node reboot.
## 4. Internal Name Resolution (DNS)

The cluster utilizes **BIND9** on the Headnode to manage a private Domain Name System (DNS). This replaces static host management with a scalable, centralized naming authority.

### DNS Configuration Details
| Property | Value |
| :--- | :--- |
| **Domain Name** | `hpcsa.cluster` (Private) |
| **Primary Name Server** | `192.168.10.1` (headnode) |
| **Listen Interface** | Internal Network (192.168.10.x) |



### Key Features
* **Forward Lookup:** Translates hostnames (e.g., `worker-node1.hpcsa.cluster`) into IPs. This is the backbone for **Slurm** and **MPI** node-to-node communication.
* **Reverse Lookup:** Translates IPs back into hostnames. This is critical for security logging, `ssh` authentication speed, and network diagnostics.
* **Service Portability:** By using **FQDNs** (Fully Qualified Domain Names) for NFS mounts and Slurm controllers, the cluster configuration remains hardware-agnostic. If an IP changes, only the DNS record needs an update.

> **Technical Note:** All cluster nodes are configured via `/etc/resolv.conf` to point to `192.168.10.1` as their primary nameserver to ensure consistent resolution across the execution environment.

## 🏗 Stack Overview
The HA architecture is built on a layered approach to ensure that if the `active-master` fails, the `passive-master` can resume operations without losing job data.

| Layer | Component | Responsibility |
| :--- | :--- | :--- |
| **Storage** | **DRBD** | Network-based RAID-1; syncs Slurm state and database files. |
| **Messaging** | **Corosync** | Handles node heartbeats and cluster membership (Quorum). |
| **Management** | **Pacemaker** | Monitors resources and manages service failover (VIP, Slurm). |

# 🛠️ HPC Cluster High Availability Stack

This document describes the integration of **Slurm, DRBD, Corosync, and Pacemaker** to provide a seamless, fail-safe workload management environment for the cluster.

---

## 1. The HA Stack Hierarchy
The cluster is built in a "4-layer cake" architecture. Stability is hierarchical; if a lower layer fails, the layers above it cannot function.

| Layer | Technology | Function |
| :--- | :--- | :--- |
| **Workload** | **Slurm** | Manages job scheduling and compute resources. |
| **Decision** | **Pacemaker** | Monitors services and triggers failover. |
| **Messaging** | **Corosync** | Provides the "heartbeat" and cluster membership (Quorum). |
| **Data** | **DRBD** | Replicates job states and database records in real-time. |



---

## 2. DRBD (Storage Layer)
**DRBD (Distributed Replicated Block Device)** acts as a network-based RAID-1.

* **Partition:** Typically a dedicated block device (e.g., `/dev/sdb1`).
* **Mount Point:** `/var/spool/slurm` (Required for `StateSaveLocation`).
* **Operation:** When the Active Master writes a file, DRBD replicates the blocks over the network to the Passive Master before the write is confirmed.

> [!IMPORTANT]
> **Critical Note:** Never mount a DRBD device on two nodes simultaneously unless using a clustered filesystem (like GFS2). Pacemaker ensures only the Active node has it mounted.

---

## 3. Corosync & Pacemaker (The Brains)
These two components manage the cluster's logic and resource allocation.

### Managed Resources
* **Virtual IP (VIP):** `192.168.100.10`. This IP "floats" to whichever node is currently the Master.
* **Filesystem:** The logic that manages the DRBD partition mount state.
* **Slurm Daemons:** Automatic management of `slurmctld` and `slurmdbd`.

### The "Colocation" Constraint
To ensure the VIP, the Disk, and Slurm are always running on the same physical node, the following constraint is used:

pcs constraint colocation add slurm-group with slurm-vip INFINITY

## 5. Daily Operations & Troubleshooting

### Check Cluster Health
To see the current status of online nodes and verify which resources (VIP, Disk, Slurm) are active on which master:

# Display the full status of the Pacemaker cluster
```bash
pcs status
```
### Verify DRBD Sync
To check the real-time replication status between the Master nodes and ensure data is being mirrored correctly:


# Check detailed DRBD resource status
```bash
drbdadm status
```

### Manual Failover (Maintenance)
Follow these steps to migrate services from the `active-master` to the `passive-master` for maintenance or updates.

**Step 1: Set the Primary Node to Standby**
This forces all managed resources (VIP, Disk, Slurm) to move to the backup node.
```bash
pcs node standby MasterNode
```
## 🚀 Slurm Quick Reference

This section provides a fast lookup for essential Slurm commands used for monitoring, job submission, and administration.

### 📊 Common Commands at a Glance

| Action | Command | Description |
| :--- | :--- | :--- |
| **Cluster Status** | `sinfo` | View partitions and node states (idle, alloc, drain). |
| **Check Queue** | `squeue` | See all running and pending jobs. |
| **Submit Job** | `sbatch <script>` | Submit a batch script to the execution queue. |
| **Cancel Job** | `scancel <id>` | Terminate a running or pending job. |
| **Job Details** | `scontrol show job <id>` | View detailed metadata and reasons for job delay. |
| **Reload Config** | `scontrol reconfigure` | Apply changes made to `slurm.conf` without a restart. |

---

### 📝 Practical Code Snippets

**1. Check Node Availability**
Use this to see which compute nodes are available for work.
```bash
sinfo
```
