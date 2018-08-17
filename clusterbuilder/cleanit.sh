#!/bin/bash

for i in `cat allnodes.lst`;
do
ssh root@$i "systemctl stop salt-minion"
ssh root@$i "systemctl stop salt-master"
ssh root@$i "systemctl stop ceph-osd.target"
ssh root@$i "systemctl stop ceph-mgr.target"
ssh root@$i "systemctl stop ceph-mon.target"
ssh root@$i "systemctl stop ceph-mds.target"
ssh root@$i "systemctl stop prometheus-ceph_exporter.service"
ssh root@$i "systemctl stop apache2"
ssh root@$i "systemctl stop ceph.target"
ssh root@$i "systemctl disable ceph.target"
ssh root@$i "systemctl disable salt-minion"
ssh root@$i "systemctl disable salt-master"
ssh root@$i "systemctl disable ceph-osd.target"
ssh root@$i "systemctl disable ceph-mgr.target"
ssh root@$i "systemctl disable ceph-mon.target"
ssh root@$i "systemctl disable ceph-mds.target"
#ssh root@172.16.253.244 "sh /root/cleanit.sh"

ssh root@$i "systemctl disable prometheus-ceph_exporter.service"
ssh root@$i "zypper rm -y ceph-base ceph-common deepsea salt-minion salt-master golang-github-prometheus-prometheus golang-github-prometheus-node_exporter golang-github-prometheus-alertmanager grafana "
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

