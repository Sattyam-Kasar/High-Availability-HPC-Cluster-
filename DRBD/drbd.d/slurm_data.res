resource slurm_data {
    protocol C;
    device /dev/drbd0;
    meta-disk internal;

    handlers {
        split-brain "/usr/lib/drbd/notify-split-brain.sh root";
    }

    net {
        max-buffers     8000;
        max-epoch-size  8000;
        sndbuf-size     10M;
        rcvbuf-size     10M;
    }


    disk {
        resync-rate 300M;
        c-max-rate  500M;
    }

    on MasterNode.HPCCluster.com {
        address 192.168.100.2:7788;
        disk /dev/sda1;  # Use existing partition (caution: root disk)
    }
    on PassiveMaster.HPCCluster.com {
        address 192.168.100.5:7788;
        disk /dev/sda1;  # Ensure same partition exists on passive node
    }
} 
