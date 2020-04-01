#!/bin/bash

echo "**** Stopping and removing ceph packages"
salt '*' cmd.run 'systemctl stop ceph-osd.target'
salt '*' cmd.run 'systemctl stop ceph-mgr.target'
salt '*' cmd.run 'systemctl stop ceph-mon.target'
salt '*' cmd.run 'systemctl stop ceph-mds.target'
salt '*' cmd.run 'systemctl stop prometheus-ceph_exporter.service'
salt '*' cmd.run 'systemctl stop apache2'
salt '*' cmd.run 'systemctl stop ceph.target'
salt '*' cmd.run 'systemctl disable ceph.target'
salt '*' cmd.run 'systemctl disable ceph-osd.target'
salt '*' cmd.run 'systemctl disable ceph-mgr.target'
salt '*' cmd.run 'systemctl disable ceph-mon.target'
salt '*' cmd.run 'systemctl disable ceph-mds.target'
salt '*' cmd.run 'systemctl disable prometheus-ceph_exporter.service'
salt '*' cmd.run 'zypper rm -y ceph-base ceph-common deepsea golang-github-prometheus-prometheus golang-github-prometheus-node_exporter golang-github-prometheus-alertmanager grafana'
for i in `cat osdnodes.lst`;
do
	echo "copy drivewiper to $i"
	scp /root/wipedrives.sh.src root@$i:/root/wipedrives.sh
done
echo "*** Wiping non-OS drives - 5 seconds to abort ***"
salt '*' cmd.run 'if [ -e "/root/wipedrives.sh" ];then sh /root/wipedrives.sh;fi'
salt '*' cmd.run 'if [ -e "/root/wipedrives.sh" ];then rm -f /root/wipedrives.sh;fi'

for i in `cat cluster.lst`;
do
ssh root@$i "systemctl stop salt-minion"
ssh root@$i "systemctl stop salt-master"
ssh root@$i "systemctl disable salt-minion"
ssh root@$i "systemctl disable salt-master"
ssh root@$i "zypper rm -y salt-minion salt-master"
ssh root@$i "rm -rf /etc/salt"
ssh root@$i "rm -rf /etc/ceph"
ssh root@$i "rm -rf /etc/prometheus"
ssh root@$i "rm -rf /srv/pillars"
ssh root@$i "rm -rf /srv/salt"
ssh root@$i "rm -rf /srv/pillar"
ssh root@$i "rm -rf /srv/modules"
ssh root@$i "rm -rf /srv/spm"
ssh root@$i "rm -rf /var/lib/ceph"
ssh root@$i "rm -rf /var/lib/salt"
ssh root@$i "rm -rf /var/lib/prometheus"
ssh root@$i "rm -rf /var/cache/salt"

ssh root@$i "rm -f /etc/sysconfig/prometheus-node_exporter"
ssh root@$i "rm -f /etc/cron.hourly/prometheus-smartmon-exporter.sh"
#zypper in -y salt-master salt-minion
ssh root@$i "reboot"
done
