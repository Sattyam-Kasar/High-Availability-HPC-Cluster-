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


