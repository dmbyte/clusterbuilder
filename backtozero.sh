#!/bin/bash
/home/ceph/donodes.sh on ALL "sudo zypper in -y ceph-radosgw"
ceph-deploy purge dl360-1 dl360-2 dl360-3 4200-1 4200-2 4200-3 4510-1
4510-2 4510-3
ceph-deploy purgedata dl360-1 dl360-2 dl360-3 4200-1 4200-2 4200-3
4510-1 4510-2 4510-3
ceph-deploy forgetkeys
rm -rf /etc/ceph/*
/home/ceph/donodes.sh on ALL "sudo umount /var/lib/ceph/osd/ceph-*"
/home/ceph/donodes.sh on ALL "sudo rm -rf /var/lib/ceph/osd/ceph-*"
sudo zypper in -y ceph ceph-deploy
/home/ceph/donodes.sh to ALL "ceph-deploy install NODE"

for i in sda sdb sdc sdd sde sdf sdg sdh sdi sdj sdk sdl sdm sdn sdo sdp
sdq sdr sds sdt sdu sdv sdw sdx sdy sdz sdaa sdab
do
         /home/ceph/donodes.sh to OSD "ceph-deploy disk zap NODE:$i"
done
echo "You are ready to perform ceph-deploy new node1 node2 node3..."
